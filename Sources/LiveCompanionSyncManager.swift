import Foundation
import MultipeerConnectivity
import SwiftUI

// MARK: - Peer Connection State
enum PeerSyncState: Equatable {
    case disconnected
    case searching
    case connecting(peerName: String)
    case connected(peerName: String)
    
    var title: String {
        switch self {
        case .disconnected: return "Chưa kết nối"
        case .searching: return "Đang tìm kiếm iPad/Mac..."
        case .connecting(let name): return "Đang kết nối: \(name)"
        case .connected(let name): return "Đã kết nối: \(name)"
        }
    }
}

// MARK: - Multipeer Live Companion & Library Sync Manager
class LiveCompanionSyncManager: NSObject, ObservableObject {
    static let shared = LiveCompanionSyncManager()
    
    // Short 7-char service type for maximum compatibility across macOS & iOS Bonjour
    private let serviceType = "fb-sync"
    let myPeerID: MCPeerID
    let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private var reconnectTimer: Timer?
    
    @Published var connectionState: PeerSyncState = .disconnected
    @Published var isSessionActive: Bool = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    
    // Inked strokes storage (Page Index -> [LiveInkStroke])
    @Published var pageStrokes: [Int: [LiveInkStroke]] = [:]
    
    // File Transfer State
    @Published var activeTransfer: FileTransferStatus? = nil
    @Published var newlyReceivedBookURL: URL? = nil
    @Published var remoteCatalog: [BookMetadataPayload] = []
    @Published var remoteReadingStatus: (bookName: String, pageIndex: Int)? = nil
    
    // Callbacks
    var onRemotePageJump: ((Int) -> Void)? = nil
    var onRemoteOpenBookRequest: ((String, Int) -> Void)? = nil
    var onBookReceived: ((URL) -> Void)? = nil
    
    override init() {
        #if os(macOS)
        let rawName = Host.current().localizedName ?? "Mac"
        #elseif os(iOS)
        let rawName = UIDevice.current.name
        #endif
        
        let deviceName = rawName.isEmpty ? "Apple Device" : rawName
        let peerID = MCPeerID(displayName: deviceName)
        let mSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        let mAdvertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        let mBrowser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        
        self.myPeerID = peerID
        self.session = mSession
        self.advertiser = mAdvertiser
        self.browser = mBrowser
        
        super.init()
        
        self.session.delegate = self
        self.advertiser.delegate = self
        self.browser.delegate = self
        
        // Auto-start on initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startSyncSession()
        }
    }
    
    // MARK: - Start / Stop Service
    @MainActor
    func startSyncSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        connectionState = .searching
        discoveredPeers.removeAll()
        
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        
        // Start background heartbeat reconnect timer
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isSessionActive else { return }
                if self.connectedPeers.isEmpty {
                    // Refresh browsing to discover freshly opened peers
                    self.browser.stopBrowsingForPeers()
                    self.browser.startBrowsingForPeers()
                }
            }
        }
    }
    
    @MainActor
    func restartDiscovery() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        connectedPeers.removeAll()
        discoveredPeers.removeAll()
        connectionState = .searching
        
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }
    
    @MainActor
    func connectToPeer(_ peer: MCPeerID) {
        connectionState = .connecting(peerName: peer.displayName)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    @MainActor
    func stopSyncSession() {
        isSessionActive = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        connectedPeers.removeAll()
        discoveredPeers.removeAll()
        connectionState = .disconnected
    }
    
    // MARK: - 1. Send Book File Directly (AirDrop-like P2P Stream)
    @MainActor
    func sendBookFile(url: URL, to targetPeer: MCPeerID? = nil) {
        guard let peer = targetPeer ?? connectedPeers.first else {
            print("No peer available to send book")
            return
        }
        
        let filename = url.lastPathComponent
        self.activeTransfer = FileTransferStatus(
            filename: filename,
            progress: 0.05,
            isReceiving: false,
            statusText: "Đang gửi sang \(peer.displayName)..."
        )
        
        let progress = session.sendResource(at: url, withName: filename, toPeer: peer) { [weak self] error in
            Task { @MainActor in
                if let error = error {
                    print("Failed to send book: \(error)")
                    self?.activeTransfer = FileTransferStatus(
                        filename: filename,
                        progress: 0.0,
                        isReceiving: false,
                        statusText: "Lỗi gửi: \(error.localizedDescription)"
                    )
                } else {
                    self?.activeTransfer = FileTransferStatus(
                        filename: filename,
                        progress: 1.0,
                        isReceiving: false,
                        statusText: "Đã gửi thành công sang \(peer.displayName)!"
                    )
                }
                
                // Clear after 4 seconds
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self?.activeTransfer = nil
            }
        }
        
        // Observe progress
        if let p = progress {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    if p.isFinished || p.isCancelled {
                        timer.invalidate()
                    } else {
                        self.activeTransfer?.progress = p.fractionCompleted
                    }
                }
            }
        }
    }
    
    // MARK: - 2. Broadcast Reading Progress / Request Open on Peer
    @MainActor
    func requestOpenBookOnPeer(bookName: String, pageIndex: Int) {
        let payload = LiveDrawingPayload(
            action: .openBookOnPeer,
            stroke: nil,
            pageIndex: pageIndex,
            allStrokes: nil,
            catalog: nil,
            targetBookName: bookName,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    @MainActor
    func broadcastReadingProgress(bookName: String, pageIndex: Int) {
        let payload = LiveDrawingPayload(
            action: .syncReadingProgress,
            stroke: nil,
            pageIndex: pageIndex,
            allStrokes: nil,
            catalog: nil,
            targetBookName: bookName,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    // MARK: - 3. Broadcast Library Catalog Summary
    @MainActor
    func broadcastCatalog(books: [BookItem]) {
        let list = books.map {
            BookMetadataPayload(
                filename: $0.name,
                fileSizeMB: $0.fileSizeMB,
                pageCount: $0.pageCount,
                categoryName: $0.folderName
            )
        }
        
        let payload = LiveDrawingPayload(
            action: .syncCatalog,
            stroke: nil,
            pageIndex: nil,
            allStrokes: nil,
            catalog: list,
            targetBookName: nil,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    // MARK: - 4. Live Drawing Stroke Stream
    @MainActor
    func broadcastNewStroke(_ stroke: LiveInkStroke) {
        var current = pageStrokes[stroke.pageIndex] ?? []
        current.append(stroke)
        pageStrokes[stroke.pageIndex] = current
        
        guard !session.connectedPeers.isEmpty else { return }
        
        let payload = LiveDrawingPayload(
            action: .addStroke,
            stroke: stroke,
            pageIndex: stroke.pageIndex,
            allStrokes: nil,
            catalog: nil,
            targetBookName: nil,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    @MainActor
    func broadcastClearPage(pageIndex: Int) {
        pageStrokes[pageIndex] = []
        
        let payload = LiveDrawingPayload(
            action: .clearPage,
            stroke: nil,
            pageIndex: pageIndex,
            allStrokes: nil,
            catalog: nil,
            targetBookName: nil,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    @MainActor
    func broadcastPageJump(pageIndex: Int) {
        let payload = LiveDrawingPayload(
            action: .jumpToPage,
            stroke: nil,
            pageIndex: pageIndex,
            allStrokes: nil,
            catalog: nil,
            targetBookName: nil,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    private func sendPayload(_ payload: LiveDrawingPayload) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONEncoder().encode(payload) else { return }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Failed to send live drawing payload: \(error)")
        }
    }
}

// MARK: - MCSessionDelegate
extension LiveCompanionSyncManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            switch state {
            case .connected:
                self.connectionState = .connected(peerName: peerID.displayName)
                print("🟢 Multipeer Connected to: \(peerID.displayName)")
                
                // Sync all current strokes with new peer
                let allFlatStrokes = self.pageStrokes.values.flatMap { $0 }
                let payload = LiveDrawingPayload(
                    action: .syncAllStrokes,
                    stroke: nil,
                    pageIndex: nil,
                    allStrokes: allFlatStrokes,
                    catalog: nil,
                    targetBookName: nil,
                    senderName: self.myPeerID.displayName
                )
                self.sendPayload(payload)
                
            case .connecting:
                self.connectionState = .connecting(peerName: peerID.displayName)
                print("🟡 Multipeer Connecting to: \(peerID.displayName)...")
                
            case .notConnected:
                print("🔴 Multipeer Disconnected from: \(peerID.displayName)")
                if session.connectedPeers.isEmpty {
                    self.connectionState = self.isSessionActive ? .searching : .disconnected
                } else {
                    self.connectionState = .connected(peerName: session.connectedPeers.first?.displayName ?? "Peer")
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let payload = try? JSONDecoder().decode(LiveDrawingPayload.self, from: data) else { return }
        
        Task { @MainActor in
            switch payload.action {
            case .addStroke:
                if let stroke = payload.stroke {
                    var list = self.pageStrokes[stroke.pageIndex] ?? []
                    if !list.contains(where: { $0.id == stroke.id }) {
                        list.append(stroke)
                        self.pageStrokes[stroke.pageIndex] = list
                    }
                }
                
            case .clearPage:
                if let page = payload.pageIndex {
                    self.pageStrokes[page] = []
                }
                
            case .jumpToPage:
                if let page = payload.pageIndex {
                    self.onRemotePageJump?(page)
                }
                
            case .syncAllStrokes:
                if let all = payload.allStrokes {
                    for s in all {
                        var list = self.pageStrokes[s.pageIndex] ?? []
                        if !list.contains(where: { $0.id == s.id }) {
                            list.append(s)
                            self.pageStrokes[s.pageIndex] = list
                        }
                    }
                }
                
            case .syncCatalog:
                if let cat = payload.catalog {
                    self.remoteCatalog = cat
                }
                
            case .openBookOnPeer:
                if let bName = payload.targetBookName, let page = payload.pageIndex {
                    self.onRemoteOpenBookRequest?(bName, page)
                }
                
            case .syncReadingProgress:
                if let bName = payload.targetBookName, let page = payload.pageIndex {
                    self.remoteReadingStatus = (bookName: bName, pageIndex: page)
                }
                
            case .requestBook:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    // MARK: - Incoming Resource / File Transfer Callbacks
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        Task { @MainActor in
            self.activeTransfer = FileTransferStatus(
                filename: resourceName,
                progress: 0.05,
                isReceiving: true,
                statusText: "Đang nhận từ \(peerID.displayName)..."
            )
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                Task { @MainActor in
                    if progress.isFinished || progress.isCancelled {
                        timer.invalidate()
                    } else {
                        self.activeTransfer?.progress = progress.fractionCompleted
                    }
                }
            }
        }
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("Error receiving resource: \(error)")
                self.activeTransfer = FileTransferStatus(
                    filename: resourceName,
                    progress: 0.0,
                    isReceiving: true,
                    statusText: "Lỗi nhận file: \(error.localizedDescription)"
                )
                return
            }
            
            guard let tempURL = localURL else { return }
            
            // Save received book file to local Documents directory
            let fileManager = FileManager.default
            let documentsDir: URL
            #if os(macOS)
            documentsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
            #elseif os(iOS)
            documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            #endif
            
            let destURL = documentsDir.appendingPathComponent(resourceName)
            
            do {
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: tempURL, to: destURL)
                
                self.activeTransfer = FileTransferStatus(
                    filename: resourceName,
                    progress: 1.0,
                    isReceiving: true,
                    statusText: "Đã nhận thành công \(resourceName)!"
                )
                self.newlyReceivedBookURL = destURL
                self.onBookReceived?(destURL)
                
                // Clear banner after 4s
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                self.activeTransfer = nil
            } catch {
                print("Failed to save received file: \(error)")
            }
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension LiveCompanionSyncManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📨 Received invitation from: \(peerID.displayName) ➔ Accepting...")
        invitationHandler(true, self.session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ Advertiser failed: \(error.localizedDescription)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension LiveCompanionSyncManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("🔍 Discovered nearby peer: \(peerID.displayName)")
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
            
            // Avoid invitation collision: Peer with lower hash sends the invite
            if self.myPeerID.displayName.hashValue < peerID.displayName.hashValue {
                print("🚀 Auto-inviting: \(peerID.displayName)...")
                browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("💨 Lost peer: \(peerID.displayName)")
        Task { @MainActor in
            self.discoveredPeers.removeAll(where: { $0 == peerID })
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Browser failed: \(error.localizedDescription)")
    }
}
