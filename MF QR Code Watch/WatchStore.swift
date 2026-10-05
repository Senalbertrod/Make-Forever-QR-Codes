//
//  WatchStore.swift
//  MF QR Code Watch
//
//  Keeps the favorites the iPhone sends. They are saved on the watch,
//  so they still show when the iPhone is far away or switched off.
//

import Foundation
import Observation
import WatchConnectivity
import WatchKit

/// One favorite, already drawn as a picture by the iPhone.
struct WatchCode: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var symbol: String
    var png: Data
}

@Observable
final class WatchStore: NSObject, WCSessionDelegate {
    static let shared = WatchStore()

    private(set) var codes: [WatchCode] = []

    private var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "favorites.plist")
    }

    override init() {
        super.init()
        if let data = try? Data(contentsOf: fileURL) { apply(data, save: false) }
    }

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func apply(_ data: Data, save: Bool) {
        guard let list = try? PropertyListDecoder().decode([WatchCode].self, from: data) else { return }
        codes = list
        guard save else { return }
        try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
        // Locked whenever the watch is locked.
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    /// With nothing saved yet, ask the iPhone for a copy.
    private func askIfEmpty() {
        let session = WCSession.default
        guard codes.isEmpty, session.activationState == .activated, session.isReachable else { return }
        session.sendMessage(["want": "favorites"], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        Task { @MainActor in
            self.reportScreenSize()
            self.askIfEmpty()
        }
    }

    /// Tells the iPhone how wide this watch's screen is (in pixels), so it can
    /// check whether a code is small enough to scan from this watch.
    private func reportScreenSize() {
        let device = WKInterfaceDevice.current()
        let pixels = Int((device.screenBounds.width * device.screenScale).rounded())
        try? WCSession.default.updateApplicationContext(["screenPixels": pixels])
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.askIfEmpty() }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // The file is removed once this returns, so read it now.
        guard let data = try? Data(contentsOf: file.fileURL) else { return }
        Task { @MainActor in self.apply(data, save: true) }
    }
}
