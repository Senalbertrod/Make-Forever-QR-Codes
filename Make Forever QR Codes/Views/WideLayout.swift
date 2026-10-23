//
//  WideLayout.swift
//  Make Forever QR Codes
//
//  When to use the wide layouts: on iPad, whenever the app has room
//  (full screen, either way up). In a narrow split screen, and on iPhone,
//  the app keeps its regular one-column layout.
//

import SwiftUI
import UIKit

enum WideLayout {
    @MainActor
    static func isOn(_ sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular && UIDevice.current.userInterfaceIdiom == .pad
    }
}

/// What to call this device in the app's text: "iPad" on iPad, "iPhone" on iPhone.
enum Device {
    @MainActor
    static var name: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}
