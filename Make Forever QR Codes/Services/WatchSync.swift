//
//  WatchSync.swift
//  Make Forever QR Codes
//
//  Sends your favorite codes to the Apple Watch, straight from the iPhone
//  (no iCloud, no server). The iPhone draws each code as a picture and
//  sends one small file; the watch keeps the latest copy.
//

import Foundation
import UIKit
import WatchConnectivity

/// One favorite as the watch sees it. The same struct lives in the watch app.
struct WatchCode: Codable, Identifiable {
    var id: UUID
    var name: String
    var symbol: String
    var png: Data
}

final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    /// The latest favorites, kept so they can be sent once the watch is ready.
    private var pending: [WatchCode]?
    private var lastSent: Data?

    /// True when an Apple Watch is paired with this iPhone.
    var hasWatch: Bool {
        WCSession.isSupported() && WCSession.default.activationState == .activated && WCSession.default.isPaired
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Call with the current favorites whenever they change.
    func update(_ codes: [SavedCode]) {
        pending = codes.compactMap { code in
            guard let png = code.image(size: 396)?.pngData() else { return nil }
            return WatchCode(id: code.id, name: code.name, symbol: code.type.symbol, png: png)
        }
        sendIfReady()
    }

    private func sendIfReady() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated,
              session.isPaired, session.isWatchAppInstalled,
              let codes = pending,
              let data = try? PropertyListEncoder().encode(codes) else { return }
        guard data != lastSent else { return }

        // Only the newest list matters, so cancel older transfers still waiting.
        for transfer in session.outstandingFileTransfers { transfer.cancel() }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("favorites.plist")
        do {
            try data.write(to: url, options: .atomic)
            session.transferFile(url, metadata: ["kind": "favorites"])
            lastSent = data
        } catch {
            // Try again the next time favorites change.
        }
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in self.sendIfReady() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        // The watch app was just installed, or a different watch was paired.
        Task { @MainActor in
            self.lastSent = nil
            self.sendIfReady()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // The watch asks for a fresh copy when it opens and has nothing.
        Task { @MainActor in
            self.lastSent = nil
            self.sendIfReady()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Switching to another watch: get ready for it.
        session.activate()
    }
}
