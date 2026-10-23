//
//  Fold.swift
//  Make Forever QR Codes
//
//  iPhone Duo, half-closed like a book: where the fold is, so a screen can
//  split exactly on it (one page on each side). When the phone is closed,
//  flat open, or it's any other device, there's no fold and nothing changes.
//

import SwiftUI

/// The fold, across the width of a view (in that view's own space).
struct Fold: Equatable {
    /// Where the fold starts and ends, measured from the view's left edge
    /// (including the room to keep clear around it).
    var start: CGFloat
    var end: CGFloat
    /// The whole width of the view.
    var total: CGFloat

    /// The page on the left of the fold, the gap, and the page on the right.
    var leftWidth: CGFloat { max(0, start) }
    var gap: CGFloat { max(0, end - start) }
    var rightWidth: CGFloat { max(0, total - end) }
    /// The middle of the fold.
    var center: CGFloat { (start + end) / 2 }

    /// The active up-and-down fold inside this view, if there is one.
    @MainActor
    static func find(in proxy: GeometryProxy) -> Fold? {
        guard #available(iOS 27.1, *) else { return nil }
        let width = proxy.size.width
        for region in proxy.reservedRegions(kind: .division) where region.isActive {
            let frame = region.frame
            // Only a fold that runs top to bottom, with room for a page on each side.
            guard frame.height > frame.width,
                  frame.minX > 120, frame.maxX < width - 120 else { continue }
            return Fold(start: frame.minX, end: frame.maxX, total: width)
        }
        return nil
    }
}

private struct FoldReader: ViewModifier {
    @Binding var fold: Fold?

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                let found = Fold.find(in: proxy)
                Color.clear
                    .onAppear { fold = found }
                    .onChange(of: found) { _, new in
                        withAnimation(.spring(duration: 0.4)) { fold = new }
                    }
            }
        }
    }
}

extension View {
    /// Keeps `fold` up to date with the iPhone Duo's fold (nil when there isn't one).
    func readFold(_ fold: Binding<Fold?>) -> some View {
        modifier(FoldReader(fold: fold))
    }
}
