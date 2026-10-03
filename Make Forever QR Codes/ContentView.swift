//
//  ContentView.swift
//  Make Forever QR Codes
//
//  Two tabs: Make and My Codes.
//

import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            Tab("Make", systemImage: "qrcode", value: 0) {
                MakeView(onSaved: { selection = 1 })
            }
            Tab("My Codes", systemImage: "square.grid.2x2", value: 1) {
                MyCodesView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedCode.self, inMemory: true)
}
