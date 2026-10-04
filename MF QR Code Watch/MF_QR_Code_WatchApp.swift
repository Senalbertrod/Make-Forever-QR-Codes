//
//  MF_QR_Code_WatchApp.swift
//  MF QR Code Watch
//
//  Your favorite codes on your wrist. They come straight from your iPhone.
//

import SwiftUI

@main
struct MF_QR_Code_WatchApp: App {
    init() {
        WatchStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
