//
//  ContentView.swift
//  Make Forever QR Codes
//
//  Two tabs: Make and My Codes. Also keeps the watch's favorites up to date.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection = 0
    @Query(filter: #Predicate<SavedCode> { $0.isFavorite }, sort: \SavedCode.createdAt, order: .reverse)
    private var favorites: [SavedCode]

    /// Changes whenever anything the watch shows changes.
    private var watchSignature: String {
        favorites.map { "\($0.id)|\($0.name)|\($0.payload)|\($0.foregroundHex)|\($0.backgroundHex)" }
            .joined(separator: "\n")
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Make", systemImage: "qrcode", value: 0) {
                MakeView(onSaved: { selection = 1 })
            }
            Tab("My Codes", systemImage: "square.grid.2x2", value: 1) {
                MyCodesView()
            }
        }
        .onAppear {
            WatchSync.shared.update(favorites)
        }
        .onChange(of: watchSignature) {
            WatchSync.shared.update(favorites)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedCode.self, inMemory: true)
}
