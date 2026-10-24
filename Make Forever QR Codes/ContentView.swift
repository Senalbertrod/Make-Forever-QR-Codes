//
//  ContentView.swift
//  Make Forever QR Codes
//
//  Three tabs: Make, Scan and My Codes. Also keeps the watch's codes up to date.
//  The tabs sit at the bottom on iPad too, like on iPhone.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selection = 0
    /// Goes up by one each time My Codes is tapped while it's already open,
    /// so My Codes goes back to its list (see MyCodesView).
    @State private var myCodesTappedAgain = 0
    /// The real width class. The tab bar is told it's narrow (so it sits at the
    /// bottom), and each tab gets the real one back.
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Codes the person sent to the Apple Watch with the watch button.
    @Query(filter: #Predicate<SavedCode> { $0.onWatch }, sort: \SavedCode.createdAt, order: .reverse)
    private var watchCodes: [SavedCode]

    /// Changes whenever anything the watch shows changes.
    private var watchSignature: String {
        watchCodes.map { "\($0.id)|\($0.name)|\($0.payload)|\($0.foregroundHex)|\($0.backgroundHex)|\($0.showIcon)" }
            .joined(separator: "\n")
    }

    var body: some View {
        // The layout is decided once, here, for every screen (see WideLayout.swift).
        ScreenLayoutReader {
            TabView(selection: Binding(get: { selection }, set: { tab in
                if tab == selection, tab == 2 { myCodesTappedAgain += 1 }
                selection = tab
            })) {
                Tab("Make", systemImage: "qrcode", value: 0) {
                    MakeView(onSaved: { selection = 2 })
                        .environment(\.horizontalSizeClass, sizeClass)
                }
                Tab("Scan", systemImage: "qrcode.viewfinder", value: 1) {
                    ScanView()
                        .environment(\.horizontalSizeClass, sizeClass)
                }
                Tab("My Codes", systemImage: "square.grid.2x2", value: 2) {
                    MyCodesView(tappedAgain: myCodesTappedAgain)
                        .environment(\.horizontalSizeClass, sizeClass)
                }
            }
            .environment(\.horizontalSizeClass, .compact)
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
