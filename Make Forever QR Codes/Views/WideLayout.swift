//
//  WideLayout.swift
//  Make Forever QR Codes
//
//  When to use the wide layouts: whenever the screen is big in both
//  directions. That's an iPad (unless in a narrow split screen) and an
//  iPhone Duo when it's open. A closed Duo, or any other iPhone (even a big
//  one turned sideways, which is short top to bottom), keeps the iPhone layout.
//  Opening or closing the Duo switches right away, keeping your place.
//

import SwiftUI
import UIKit

enum WideLayout {
    static func isOn(_ width: UserInterfaceSizeClass?, _ height: UserInterfaceSizeClass?) -> Bool {
        width == .regular && height == .regular
    }
}

/// What to call this device in the app's text: "iPad" on iPad, "iPhone" on iPhone.
enum Device {
    @MainActor
    static var name: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
    }
}
