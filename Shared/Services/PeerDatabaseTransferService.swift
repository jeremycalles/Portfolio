import Foundation
import MultipeerConnectivity
#if os(iOS)
import UIKit
#endif

/// Service type for Bonjour (max 15 chars, lowercase, hyphens). Must match NSBonjourServices in Info.plist.
private let kServiceType = "portfolio-db"

// MARK: - Peer Database Transfer Service
/// Discovers other app instances on the local network and sends/receives the database via MultipeerConnectivity.
@MainActor
final class PeerDatabaseTransferService: NSObject, ObservableObject {
    static let shared = PeerDatabaseTransferService()

    @Published private(set) var discoveredPeers: [MCPeerID] = []
    @Published private(set) var isSending = false
    @Published private(set) var sendError: Error?
    @Published private(set) var didReceiveDatabase = false
    @Published private(set) var receiveError: Error?
    
    /// Pending invitation requiring user confirmation (peerID, invitationHandler)
    @Published private(set) var pendingIncomingInvitation: (peerID: MCPeerID, handler: (Bool, MCSession?) -> Void)?

    private var peerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var pendingInvitationCompletions: [String: (Bool) -> Void] = [:]

    override init() {
        super.init()
        let displayName: String = {
            #if os(iOS)
            return UIDevice.current.name
            #elseif os(macOS)
            return Host.current().localizedName ?? "Mac"
            #endif
        }()
        peerID = MCPeerID(displayName: displayName)
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - Advertising (so others can find us)

    func startAdvertising() {
        guard advertiser == nil else { return }
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: kServiceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func stopAdvertising() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
    }

    // MARK: - Browsing (find others)

    func startBrowsing() {
        discoveredPeers = []
        browser?.stopBrowsingForPeers()
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: kServiceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        discoveredPeers = []
    }

    // MARK: - Send database to peer

    /// Invite a peer to the session. Call this before sendDatabase when the peer is not yet connected.
    func invitePeer(_ peer: MCPeerID, timeout: TimeInterval = 30, completion: @escaping (Bool) -> Void) {
        if session.connectedPeers.contains(where: { $0.displayName == peer.displayName }) {
            completion(true)
            return
        }
        guard browser != nil else {
            completion(false)
            return
        }
        pendingInvitationCompletions[peer.displayName] = completion
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: timeout)
    }

    func sendDatabase(to peer: MCPeerID, completion: @escaping (Error?) -> Void) {
        let path = DatabaseService.shared.getDatabasePath()
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            completion(NSError(domain: "PeerDatabaseTransfer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Database file not found"]))
            return
        }
        guard session.connectedPeers.contains(where: { $0.displayName == peer.displayName }) else {
            completion(NSError(domain: "PeerDatabaseTransfer", code: -3, userInfo: [NSLocalizedDescriptionKey: "Peer not connected. Invite the peer first."]))
            return
        }
        isSending = true
        sendError = nil

        session.sendResource(at: url, withName: "stocks.db", toPeer: peer) { [weak self] error in
            Task { @MainActor in
                self?.isSending = false
                self?.sendError = error
                completion(error)
            }
        }
    }

    func clearSendState() {
        sendError = nil
    }

    func clearReceiveState() {
        didReceiveDatabase = false
        receiveError = nil
    }
    
    /// Accept a pending incoming invitation from another peer.
    func acceptPendingInvitation() {
        guard let invitation = pendingIncomingInvitation else { return }
        invitation.handler(true, session)
        pendingIncomingInvitation = nil
    }
    
    /// Reject a pending incoming invitation from another peer.
    func rejectPendingInvitation() {
        guard let invitation = pendingIncomingInvitation else { return }
        invitation.handler(false, nil)
        pendingIncomingInvitation = nil
    }

    /// Apply received database from a temp URL (called by UI after user confirms or automatically).
    func applyReceivedDatabase(from tempURL: URL) {
        // Validate that the file is a valid SQLite database before applying
        guard isValidSQLiteDatabase(at: tempURL) else {
            receiveError = NSError(domain: "PeerDatabaseTransfer", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Received file is not a valid SQLite database"])
            try? FileManager.default.removeItem(at: tempURL)
            didReceiveDatabase = false
            return
        }
        
        let destPath = DatabaseService.shared.getDatabasePath()
        let destURL = URL(fileURLWithPath: destPath)
        let destDir = destURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: destPath) {
                let backupPath = destPath + ".backup"
                try? FileManager.default.removeItem(atPath: backupPath)
                try FileManager.default.moveItem(atPath: destPath, toPath: backupPath)
            }
            try FileManager.default.copyItem(at: tempURL, to: destURL)
            try? FileManager.default.removeItem(at: tempURL)
            NotificationCenter.default.post(name: .peerTransferDidImportDatabase, object: nil)
        } catch {
            receiveError = error
        }
        didReceiveDatabase = false
    }
    
    /// Validate that the file at the given URL is a valid SQLite database by checking the magic header.
    private func isValidSQLiteDatabase(at url: URL) -> Bool {
        // SQLite databases start with the 16-byte header "SQLite format 3\0"
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              data.count >= 16 else {
            return false
        }
        let header = String(data: data[0..<16], encoding: .utf8)
        return header == "SQLite format 3\0"
    }

    /// Store the received temp URL so UI can show "Database received" and call applyReceivedDatabase when ready.
    private var receivedDatabaseTempURL: URL?
    func consumeReceivedDatabaseURL() -> URL? {
        defer { receivedDatabaseTempURL = nil }
        return receivedDatabaseTempURL
    }
}

// MARK: - MCSessionDelegate
extension PeerDatabaseTransferService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            guard state != .connecting else { return }
            let key = peerID.displayName
            if let completion = pendingInvitationCompletions[key] {
                pendingInvitationCompletions.removeValue(forKey: key)
                completion(state == .connected)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Receiver-side progress; we only use didFinish for applying the DB.
    }

    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Copy the file synchronously before MC deletes the temp file on delegate return
        var safeCopy: URL?
        if error == nil, let url = localURL, FileManager.default.fileExists(atPath: url.path) {
            let tmp = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + "_stocks.db")
            try? FileManager.default.copyItem(at: url, to: tmp)
            safeCopy = tmp
        }
        Task { @MainActor in
            if resourceName != "stocks.db" { return }
            if let error = error {
                receiveError = error
                didReceiveDatabase = false
                return
            }
            guard let safeURL = safeCopy else {
                receiveError = NSError(domain: "PeerDatabaseTransfer", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Received file missing"])
                return
            }
            receivedDatabaseTempURL = safeURL
            didReceiveDatabase = true
            receiveError = nil
        }
    }

}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension PeerDatabaseTransferService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            // Store the invitation so the UI can show a confirmation alert
            // Any previous pending invitation is auto-rejected
            if let old = pendingIncomingInvitation {
                old.handler(false, nil)
            }
            pendingIncomingInvitation = (peerID, invitationHandler)
        }
    }

    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {}
}

// MARK: - MCNearbyServiceBrowserDelegate
extension PeerDatabaseTransferService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if !discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                discoveredPeers.append(peerID)
            }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            discoveredPeers.removeAll { $0.displayName == peerID.displayName }
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {}
}

// MARK: - Notification
extension Notification.Name {
    static let peerTransferDidImportDatabase = Notification.Name("peerTransferDidImportDatabase")
}
