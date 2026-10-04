//
//  WiFiJoiner.swift
//  Make Forever QR Codes
//
//  Joins a scanned Wi-Fi network with one tap. iPhone shows its own
//  "Join Wi-Fi network?" question first; the app never sees other networks.
//

import Foundation
import NetworkExtension

enum WiFiJoiner {
    enum Result {
        case joined
        case cancelled
        case failed(String)
    }

    static func join(_ wifi: WiFiInfo) async -> Result {
        let config: NEHotspotConfiguration
        switch wifi.security {
        case .none:
            config = NEHotspotConfiguration(ssid: wifi.ssid)
        case .wep:
            config = NEHotspotConfiguration(ssid: wifi.ssid, passphrase: wifi.password, isWEP: true)
        case .wpa:
            config = NEHotspotConfiguration(ssid: wifi.ssid, passphrase: wifi.password, isWEP: false)
        }
        config.hidden = wifi.hidden
        config.joinOnce = false

        do {
            try await NEHotspotConfigurationManager.shared.apply(config)
            return .joined
        } catch let error as NSError where error.domain == NEHotspotConfigurationErrorDomain {
            switch NEHotspotConfigurationError(rawValue: error.code) {
            case .alreadyAssociated: return .joined
            case .userDenied: return .cancelled
            case .invalidWPAPassphrase, .invalidWEPPassphrase: return .failed("The password in this code isn't valid.")
            default: return .failed("Couldn't join this network. Make sure you're close to it, or copy the password instead.")
            }
        } catch {
            return .failed("Couldn't join this network. Make sure you're close to it, or copy the password instead.")
        }
    }
}
