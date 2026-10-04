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
    init() {
        // Lock saved codes whenever the phone is locked.
        StoreProtection.apply()
        // Get ready to send favorites to the Apple Watch.
        WatchSync.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Saved codes stay on this device.
        .modelContainer(for: SavedCode.self)
    }
}
