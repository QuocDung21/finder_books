import Foundation
import MultipeerConnectivity
import SwiftUI

// MARK: - Peer Connection State
enum PeerSyncState {
    case disconnected
    case searching
    case connecting(peerName: String)
    case connected(peerName: String)
    
    var title: String {
        switch self {
        case .disconnected: return "Chưa kết nối"
        case .searching: return "Đang tìm kiếm iPad/Mac..."
        case .connecting(let name): return "Đang ghép nối: \(name)"
        case .connected(let name): return "Đã kết nối: \(name)"
        }
    }
}

// MARK: - Multipeer Live Companion Sync Manager
class LiveCompanionSyncManager: NSObject, ObservableObject {
    static let shared = LiveCompanionSyncManager()
    
    private let serviceType = "finderbooks-pen"
    private var myPeerID: MCPeerID
    let session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    
    @Published var connectionState: PeerSyncState = .disconnected
    @Published var isSessionActive: Bool = false
    @Published var connectedPeers: [MCPeerID] = []
    
    // Inked strokes storage (Page Index -> [LiveInkStroke])
    @Published var pageStrokes: [Int: [LiveInkStroke]] = [:]
    
    // External Page Jump callback
    var onRemotePageJump: ((Int) -> Void)? = nil
    
    override init() {
        #if os(macOS)
        let deviceName = Host.current().localizedName ?? "Mac"
        #elseif os(iOS)
        let deviceName = UIDevice.current.name
        #endif
        
        let peerID = MCPeerID(displayName: deviceName)
        let mSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
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
    }
    
    // MARK: - Start / Stop Service
    @MainActor
    func startSyncSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        connectionState = .searching
        
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }
    
    @MainActor
    func stopSyncSession() {
        isSessionActive = false
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
        connectedPeers.removeAll()
        connectionState = .disconnected
    }
    
    // MARK: - Send Drawing Stroke (Real-Time Live Stream)
    @MainActor
    func broadcastNewStroke(_ stroke: LiveInkStroke) {
        // 1. Add locally
        var current = pageStrokes[stroke.pageIndex] ?? []
        current.append(stroke)
        pageStrokes[stroke.pageIndex] = current
        
        // 2. Broadcast to connected peers
        guard !session.connectedPeers.isEmpty else { return }
        
        let payload = LiveDrawingPayload(
            action: .addStroke,
            stroke: stroke,
            pageIndex: stroke.pageIndex,
            allStrokes: nil,
            senderName: myPeerID.displayName
        )
        
        sendPayload(payload)
    }
    
    // MARK: - Broadcast Clear Page
    @MainActor
    func broadcastClearPage(pageIndex: Int) {
        pageStrokes[pageIndex] = []
        
        let payload = LiveDrawingPayload(
            action: .clearPage,
            stroke: nil,
            pageIndex: pageIndex,
            allStrokes: nil,
            senderName: myPeerID.displayName
        )
        sendPayload(payload)
    }
    
    // MARK: - Broadcast Page Jump
    @MainActor
    func broadcastPageJump(pageIndex: Int) {
        let payload = LiveDrawingPayload(
            action: .jumpToPage,
            stroke: nil,
            pageIndex: pageIndex,
            allStrokes: nil,
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
                // Sync all current strokes with new peer
                let allFlatStrokes = self.pageStrokes.values.flatMap { $0 }
                let payload = LiveDrawingPayload(
                    action: .syncAllStrokes,
                    stroke: nil,
                    pageIndex: nil,
                    allStrokes: allFlatStrokes,
                    senderName: self.myPeerID.displayName
                )
                self.sendPayload(payload)
                
            case .connecting:
                self.connectionState = .connecting(peerName: peerID.displayName)
                
            case .notConnected:
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
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension LiveCompanionSyncManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept invitation from trusted peer on same network
        invitationHandler(true, self.session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension LiveCompanionSyncManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        // Auto-invite discovered peer
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
