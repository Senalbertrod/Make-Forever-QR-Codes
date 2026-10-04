//
//  ContactParts.swift
//  Make Forever QR Codes
//
//  Contact lines that can repeat (the + button): phones, emails,
//  websites, addresses and social profiles, each with a label.
//  SocialService is also used by the Social Profile code type.
//

import Foundation

/// A phone, email or website line with its label ("Work", "Mobile"...).
struct LabeledValue: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String
    var value: String = ""
}

struct PostalAddress: Codable, Equatable, Identifiable {
    var id = UUID()
    var label: String
    var street = ""
    var city = ""
    var state = ""
    var postalCode = ""
    var country = ""

    var isEmpty: Bool {
        [street, city, state, postalCode, country].allSatisfy { $0.trimmed.isEmpty }
    }
}

enum SocialService: String, CaseIterable, Codable, Identifiable {
    case instagram, x, linkedin, tiktok, facebook, youtube, threads, other
    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagram: "Instagram"
        case .x: "X"
        case .linkedin: "LinkedIn"
        case .tiktok: "TikTok"
        case .facebook: "Facebook"
        case .youtube: "YouTube"
        case .threads: "Threads"
        case .other: "Other"
        }
    }

    /// The profile link for a username (a full link is kept as it is).
    func link(for handle: String) -> String {
        let h = handle.trimmed
        if h.contains("://") { return h }
        // A pasted link without https (usernames can have dots, so look for a slash).
        if h.contains("/") || self == .other { return "https://" + h }
        let user = h.hasPrefix("@") ? String(h.dropFirst()) : h
        switch self {
        case .instagram: return "https://instagram.com/\(user)"
        case .x: return "https://x.com/\(user)"
        case .linkedin: return "https://linkedin.com/in/\(user)"
        case .tiktok: return "https://tiktok.com/@\(user)"
        case .facebook: return "https://facebook.com/\(user)"
        case .youtube: return "https://youtube.com/@\(user)"
        case .threads: return "https://threads.net/@\(user)"
        case .other: return "https://" + user
        }
    }

    /// Just the username, when one was typed instead of a link.
    func username(from handle: String) -> String? {
        let h = handle.trimmed
        guard !h.isEmpty, !h.contains("/"), self != .other else { return nil }
        return h.hasPrefix("@") ? String(h.dropFirst()) : h
    }
}

struct SocialProfile: Codable, Equatable, Identifiable {
    var id = UUID()
    var service: SocialService
    var handle = ""
}

/// Limits and label choices for the + button.
enum ContactLimits {
    static let phones = 3
    static let emails = 3
    static let websites = 3
    static let addresses = 2
    static let socials = 3

    static let phoneLabels = ["Mobile", "Work", "Home"]
    static let emailLabels = ["Work", "Personal", "Other"]
    static let websiteLabels = ["Website", "Portfolio", "Other"]
    static let addressLabels = ["Work", "Home"]

    /// The first label not used yet, so a new line gets a sensible default.
    static func nextLabel(_ options: [String], used: [String]) -> String {
        options.first { !used.contains($0) } ?? options.last ?? ""
    }
}

extension CodeFields {
    // The lists start from the single fields of older saved codes, so those keep working.

    var phones: [LabeledValue] {
        get { phoneList ?? [LabeledValue(label: "Mobile", value: phone)] }
        set { phoneList = newValue }
    }

    var emails: [LabeledValue] {
        get { emailList ?? [LabeledValue(label: "Work", value: email)] }
        set { emailList = newValue }
    }

    var websites: [LabeledValue] {
        get { websiteList ?? [LabeledValue(label: "Website", value: website)] }
        set { websiteList = newValue }
    }

    var addresses: [PostalAddress] {
        get {
            addressList ?? [PostalAddress(label: "Work", street: street, city: city, state: state,
                                          postalCode: postalCode, country: country)]
        }
        set { addressList = newValue }
    }

    var socials: [SocialProfile] {
        get { socialList ?? [] }
        set { socialList = newValue }
    }

    // The Social Profile code type.

    var socialService: SocialService {
        get { socialServiceValue ?? .instagram }
        set { socialServiceValue = newValue }
    }

    var socialHandle: String {
        get { socialHandleValue ?? "" }
        set { socialHandleValue = newValue }
    }
}
