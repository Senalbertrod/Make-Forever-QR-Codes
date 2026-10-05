//
//  Make_Forever_QR_CodesApp.swift
//  Make Forever QR Codes
//
//  Created by Senalbert Rodriguez on 10/3/26.
//

import SwiftUI
import SwiftData

@main
struct Make_Forever_QR_CodesApp: App {
    @AppStorage("appearance") private var appearance: Appearance = .device
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Lock saved codes whenever the phone is locked.
        StoreProtection.apply()
        // Get ready to send codes to the Apple Watch.
        WatchSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Set on the window itself, so open screens (like Settings)
                // switch right away, and Match Device switches back correctly.
                .onChange(of: appearance, initial: true) {
                    appearance.apply()
                }
                .onChange(of: scenePhase) {
                    if scenePhase == .active { appearance.apply() }
                }
        }
        // Saved codes stay on this device.
        .modelContainer(for: SavedCode.self)
    }
}
