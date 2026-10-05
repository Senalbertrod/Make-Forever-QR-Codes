//
//  Appearance.swift
//  Make Forever QR Codes
//
//  Light or dark look for the app. "Match Device" follows the iPhone's setting.
//

import SwiftUI
import UIKit

enum Appearance: String, CaseIterable, Identifiable {
    case device, light, dark
    var id: String { rawValue }

    var title: String {
        switch self {
        case .device: "Match Device"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    private var style: UIUserInterfaceStyle {
        switch self {
        case .device: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }

    /// Applies the look to every window of the app and to every screen
    /// shown on top (like Settings), so everything switches right away.
    func apply() {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
                var screen = window.rootViewController
                while let current = screen {
                    current.overrideUserInterfaceStyle = style
                    screen = current.presentedViewController
                }
            }
        }
    }
}
