import Foundation
import MultipeerConnectivity
import Network
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

// MARK: - Multipeer & Direct TCP Dual-Engine Live Companion Manager
class LiveCompanionSyncManager: NSObject, ObservableObject {
    static let shared = LiveCompanionSyncManager()
    
    // 1. Multipeer Service
    private let serviceType = "fb-sync"
    let myPeerID: MCPeerID
    let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private var reconnectTimer: Timer?
    
    // 2. Direct TCP / Network.framework Engine (Bypasses all router multicast issues)
    private var tcpListener: NWListener?
    private var activeTCPConnections: [NWConnection] = []
    private var clientTCPConnection: NWConnection?
    let defaultTCPPort: UInt16 = 8099
    
    @Published var connectionState: PeerSyncState = .disconnected
    @Published var isSessionActive: Bool = false
    @Published var connectedPeers: [MCPeerID] = []
    @Published var discoveredPeers: [MCPeerID] = []
    @Published var localIP: String = "127.0.0.1"
    @Published var manualConnectIP: String = ""
    @Published var isDirectTCPConnected: Bool = false
    
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
        
        // Fetch local Wi-Fi IP
        if let ip = getLocalIPAddress() {
            self.localIP = ip
        }
        
        // Restore last known server IP
        if let savedIP = UserDefaults.standard.string(forKey: "last_known_sync_ip"), !savedIP.isEmpty {
            self.manualConnectIP = savedIP
        }
        
        // Auto-start engines on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startSyncSession()
            self?.startTCPServer()
            
            #if os(iOS)
            // On iPad, if there's a saved Mac IP, attempt direct connect immediately
            if let lastIP = self?.manualConnectIP, !lastIP.isEmpty {
                self?.connectDirectIP(ip: lastIP)
            }
            #endif
        }
    }
    
    // MARK: - Start / Stop Service
    @MainActor
    func startSyncSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        connectionState = .searching
        discoveredPeers.removeAll()
        
        if let ip = getLocalIPAddress() {
            self.localIP = ip
        }
        
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        
        // Start background heartbeat reconnect timer
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isSessionActive else { return }
                if self.connectedPeers.isEmpty && !self.isDirectTCPConnected {
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
        
        if !manualConnectIP.isEmpty {
            connectDirectIP(ip: manualConnectIP)
        }
    }
    
    @MainActor
    func connectToPeer(_ peer: MCPeerID) {
        connectionState = .connecting(peerName: peer.displayName)
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
    }
    
    // MARK: - Direct TCP Server Engine (Mac & iPad)
    func startTCPServer() {
        do {
            let port = NWEndpoint.Port(rawValue: defaultTCPPort)!
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 2
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true
            params.includePeerToPeer = true
            
            let listener = try NWListener(using: params, on: port)
            
            listener.newConnectionHandler = { [weak self] newConnection in
                self?.handleIncomingTCPConnection(newConnection)
            }
            
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("🚀 Direct TCP Server listening on port \(self.defaultTCPPort)")
                case .failed(let err):
                    print("❌ TCP Server failed: \(err)")
                default:
                    break
                }
            }
            
            listener.start(queue: .main)
            self.tcpListener = listener
        } catch {
            print("Failed to start TCP listener: \(error)")
        }
    }
    
    private func handleIncomingTCPConnection(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    let remoteHost = conn.endpoint.debugDescription
                    print("🟢 Direct TCP Peer connected: \(remoteHost)")
                    self?.activeTCPConnections.append(conn)
                    self?.isDirectTCPConnected = true
                    self?.connectionState = .connected(peerName: "Thiết Bị (IP Direct)")
                    self?.receiveNextTCPPacket(from: conn)
                case .failed, .cancelled:
                    self?.activeTCPConnections.removeAll(where: { $0 === conn })
                    if self?.activeTCPConnections.isEmpty == true && self?.clientTCPConnection == nil {
                        self?.isDirectTCPConnected = false
                    }
                default:
                    break
                }
            }
        }
        conn.start(queue: .main)
    }
    
    // MARK: - Direct TCP Client Connect (IP Input)
    @MainActor
    func connectDirectIP(ip: String) {
        let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        UserDefaults.standard.set(trimmed, forKey: "last_known_sync_ip")
        self.manualConnectIP = trimmed
        
        clientTCPConnection?.cancel()
        
        guard let port = NWEndpoint.Port(rawValue: defaultTCPPort) else { return }
        let host = NWEndpoint.Host(trimmed)
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveIdle = 2
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.allowLocalEndpointReuse = true
        params.includePeerToPeer = true
        
        let conn = NWConnection(host: host, port: port, using: params)
        
        connectionState = .connecting(peerName: trimmed)
        
        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    print("🟢 Successfully connected to IP: \(trimmed)")
                    self?.clientTCPConnection = conn
                    self?.isDirectTCPConnected = true
                    self?.connectionState = .connected(peerName: "\(trimmed)")
                    self?.receiveNextTCPPacket(from: conn)
                case .failed(let err):
                    print("❌ Direct connect failed: \(err)")
                    self?.isDirectTCPConnected = false
                    if self?.connectedPeers.isEmpty == true {
                        self?.connectionState = .disconnected
                    }
                default:
                    break
                }
            }
        }
        
        conn.start(queue: .main)
    }
    
    // MARK: - Receive Loop for TCP Packets
    private func receiveNextTCPPacket(from conn: NWConnection) {
        // Read 4-byte header length
        conn.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] headerData, _, isComplete, error in
            guard let self = self, let data = headerData, data.count == 4, error == nil else {
                return
            }
            
            let length = data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            
            // Read exact payload bytes
            conn.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] bodyData, _, isComplete, err in
                guard let self = self, let bData = bodyData, err == nil else { return }
                
                if let payload = try? JSONDecoder().decode(LiveDrawingPayload.self, from: bData) {
                    Task { @MainActor in
                        self.processIncomingPayload(payload)
                    }
                }
                
                // Continue loop
                self.receiveNextTCPPacket(from: conn)
            }
        }
    }
    
    // MARK: - Universal Send Payload (Broadcasts to Multipeer & TCP Sockets)
    private func sendPayload(_ payload: LiveDrawingPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        
        // 1. Multipeer
        if !session.connectedPeers.isEmpty {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }
        
        // 2. Direct TCP Connections
        var length = UInt32(data.count).bigEndian
        var packetData = Data(bytes: &length, count: 4)
        packetData.append(data)
        
        for conn in activeTCPConnections {
            conn.send(content: packetData, completion: .idempotent)
        }
        
        clientTCPConnection?.send(content: packetData, completion: .idempotent)
    }
    
    // MARK: - 1. Send Book File Directly
    @MainActor
    func sendBookFile(url: URL, to targetPeer: MCPeerID? = nil) {
        let filename = url.lastPathComponent
        let targetName = targetPeer?.displayName ?? (isDirectTCPConnected ? "Thiết Bị Qua IP" : "iPad/Mac")
        
        self.activeTransfer = FileTransferStatus(
            filename: filename,
            progress: 0.05,
            isReceiving: false,
            statusText: "Đang gửi sang \(targetName)..."
        )
        
        if let peer = targetPeer ?? connectedPeers.first {
            let progress = session.sendResource(at: url, withName: filename, toPeer: peer) { [weak self] error in
                Task { @MainActor in
                    if let error = error {
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
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    self?.activeTransfer = nil
                }
            }
            
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
    }
    
    // MARK: - 2. Broadcast Reading Progress
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
    
    // MARK: - Payload Processing Pipeline
    @MainActor
    private func processIncomingPayload(_ payload: LiveDrawingPayload) {
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

// MARK: - MCSessionDelegate
extension LiveCompanionSyncManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            switch state {
            case .connected:
                self.connectionState = .connected(peerName: peerID.displayName)
                print("🟢 Multipeer Connected to: \(peerID.displayName)")
                
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
                
            case .notConnected:
                if session.connectedPeers.isEmpty && !self.isDirectTCPConnected {
                    self.connectionState = self.isSessionActive ? .searching : .disconnected
                }
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let payload = try? JSONDecoder().decode(LiveDrawingPayload.self, from: data) else { return }
        Task { @MainActor in
            self.processIncomingPayload(payload)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
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
                self.activeTransfer = FileTransferStatus(
                    filename: resourceName,
                    progress: 0.0,
                    isReceiving: true,
                    statusText: "Lỗi nhận file: \(error.localizedDescription)"
                )
                return
            }
            
            guard let tempURL = localURL else { return }
            
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
        print("📨 Received Multipeer invitation from: \(peerID.displayName) ➔ Accepting...")
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
            
            if self.myPeerID.displayName.hashValue < peerID.displayName.hashValue {
                print("🚀 Auto-inviting: \(peerID.displayName)...")
                browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll(where: { $0 == peerID })
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ Browser failed: \(error.localizedDescription)")
    }
}
