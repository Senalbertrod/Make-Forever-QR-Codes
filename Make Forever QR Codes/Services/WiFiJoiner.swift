//
//  WiFiJoiner.swift
//  Make Forever QR Codes
//
//  Joins a scanned Wi-Fi network with one tap, on iPhone and iPad. The system
//  asks the person first ("Join Wi-Fi Network?"), so nothing joins by itself.
//  Needs the Hotspot Configuration permission (paid developer team).
//

import Foundation
import NetworkExtension

enum WiFiJoiner {
    enum Outcome: Equatable {
        /// The iPhone or iPad is now on the network.
        case joined
        /// It was already on this network.
        case alreadyJoined
        /// The person tapped Cancel on the system question.
        case cancelled
        /// The system took the network but couldn't confirm it's connected
        /// (most often a wrong password inside the code).
        case notConfirmed
        case failed(String)
    }

    static func join(_ wifi: WiFiInfo) async -> Outcome {
        let config: NEHotspotConfiguration
        switch wifi.security {
        case .none: config = NEHotspotConfiguration(ssid: wifi.ssid)
        case .wpa: config = NEHotspotConfiguration(ssid: wifi.ssid, passphrase: wifi.password, isWEP: false)
        case .wep: config = NEHotspotConfiguration(ssid: wifi.ssid, passphrase: wifi.password, isWEP: true)
        }
        config.hidden = wifi.hidden
        // Kept like a network joined in Settings, so it rejoins next time.
        config.joinOnce = false

        do {
            try await NEHotspotConfigurationManager.shared.apply(config)
        } catch let error as NSError where error.domain == NEHotspotConfigurationErrorDomain {
            switch NEHotspotConfigurationError(rawValue: error.code) {
            case .alreadyAssociated: return .alreadyJoined
            case .userDenied: return .cancelled
            case .invalidWPAPassphrase, .invalidWEPPassphrase:
                return .failed("The password in this code isn't a valid Wi-Fi password.")
            case .invalidSSID, .invalidSSIDPrefix:
                return .failed("The network name in this code isn't valid.")
            default:
                return .failed(error.localizedDescription)
            }
        } catch {
            return .failed(error.localizedDescription)
        }

        // The system can say yes even when the password is wrong, so check
        // which network it's really on (it can take a moment to connect).
        for _ in 0..<6 {
            if await NEHotspotNetwork.fetchCurrent()?.ssid == wifi.ssid { return .joined }
            try? await Task.sleep(for: .milliseconds(500))
        }
        return .notConfirmed
    }
}
