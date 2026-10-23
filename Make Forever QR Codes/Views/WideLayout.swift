//
//  WideLayout.swift
//  Make Forever QR Codes
//
//  The app decides its layout in one place, from the whole screen, all at once:
//  how big it is, which way it's turned, and (iPhone Duo) where the fold is.
//  Every screen reads that same answer, so opening, closing or turning the
//  phone or iPad switches in one step, without in-between screens.
//
//  - Wide layouts: when the screen is big both ways. That's an iPad (unless in
//    a narrow split screen) and an iPhone Duo when it's open. A closed Duo, or
//    any other iPhone (even a big one turned sideways), keeps the iPhone layout.
//  - Side by side: wide and wider than tall, or the Duo half-closed like a book.
//

import SwiftUI
import UIKit

struct ScreenLayout: Equatable {
    var size: CGSize = .zero
    /// iPhone Duo half-closed: the fold (nil otherwise).
    var fold: Fold? = nil

    /// Big both ways (iPad, open iPhone Duo).
    var isWide: Bool { fold != nil || min(size.width, size.height) >= 580 }
    /// Wider than tall.
    var isLandscape: Bool { size.width > size.height }
    /// Two sides: wide and sideways, or the Duo half-closed.
    var sideBySide: Bool { fold != nil || (isWide && isLandscape) }
}

extension EnvironmentValues {
    @Entry var screenLayout = ScreenLayout()
}

/// Measures the whole screen and hands the layout to everything inside, in the
/// same moment it changes (no waiting, no animation in between).
struct ScreenLayoutReader<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            let layout = ScreenLayout(size: proxy.size, fold: Fold.find(in: proxy))
            content
                .environment(\.screenLayout, layout)
                .transaction(value: layout) { $0.animation = nil }
        }
    }
}

/// What to call this device in the app's text: "iPad" on iPad, "iPhone" on iPhone.
enum Device {
    @MainActor
    static var name: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}
