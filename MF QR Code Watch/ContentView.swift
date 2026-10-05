//
//  ContentView.swift
//  MF QR Code Watch
//
//  The codes sent from the iPhone with the watch button. Tap one to show it full screen.
//

import SwiftUI
import WatchKit

struct ContentView: View {
    private var store = WatchStore.shared
    @State private var shown: WatchCode?

    var body: some View {
        NavigationStack {
            Group {
                if store.codes.isEmpty {
                    ContentUnavailableView {
                        Label("No codes yet", systemImage: "applewatch")
                    } description: {
                        Text("On your iPhone, open Make Forever QR and tap the watch button on a code.")
                    }
                } else {
                    List(store.codes) { code in
                        Button {
                            shown = code
                        } label: {
                            Label(code.name, systemImage: code.symbol)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("Make Forever QR")
        }
        .fullScreenCover(item: $shown) { code in
            CodeScreen(code: code)
        }
    }
}

/// The code as big as the screen allows, on white so it scans well.
private struct CodeScreen: View {
    let code: WatchCode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            if let image = UIImage(data: code.png) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel("QR code for \(code.name)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .toolbar(.hidden, for: .navigationBar)
        .persistentSystemOverlays(.hidden)
        .onAppear { WKInterfaceDevice.current().play(.click) }
    }
}

#Preview {
    ContentView()
}
