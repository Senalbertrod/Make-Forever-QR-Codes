//
//  ContentView.swift
//  Make Forever QR Codes
//
//  Three tabs: Make, Scan and My Codes. Also keeps the watch's codes up to date.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection = 0
    /// Codes the person sent to the Apple Watch with the watch button.
    @Query(filter: #Predicate<SavedCode> { $0.onWatch }, sort: \SavedCode.createdAt, order: .reverse)
    private var watchCodes: [SavedCode]

    /// Changes whenever anything the watch shows changes.
    private var watchSignature: String {
        watchCodes.map { "\($0.id)|\($0.name)|\($0.payload)|\($0.foregroundHex)|\($0.backgroundHex)|\($0.showIcon)" }
            .joined(separator: "\n")
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Make", systemImage: "qrcode", value: 0) {
                MakeView(onSaved: { selection = 2 })
            }
            Tab("Scan", systemImage: "qrcode.viewfinder", value: 1) {
                ScanView()
            }
            Tab("My Codes", systemImage: "square.grid.2x2", value: 2) {
                MyCodesView()
            }
        }
        .onAppear {
            WatchSync.shared.update(watchCodes)
        }
        .onChange(of: watchSignature) {
            WatchSync.shared.update(watchCodes)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedCode.self, inMemory: true)
}
