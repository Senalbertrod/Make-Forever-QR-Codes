//
//  Appearance.swift
//  Make Forever QR Codes
//
//  Light or dark look for the app. "Match Device" follows the iPhone's setting.
//

import SwiftUI

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

    /// nil means: follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .device: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
