//
//  LinkSafety.swift
//  Make Forever QR Codes
//
//  Helps show a scanned link clearly: the real website name (in lowercase,
//  so a fake capital I shows as an i) and the link without invisible characters.
//

import Foundation

/// The pieces of a link, read straight from the scanned text.
struct LinkParts {
    var scheme: String
    var userInfo: String?
    var host: String
    var path: String

    init?(_ text: String) {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let marker = s.range(of: "://") else { return nil }
        scheme = String(s[..<marker.lowerBound]).lowercased()
        let rest = s[marker.upperBound...]
        // Browsers treat a backslash like a slash, so it also ends the address.
        let end = rest.firstIndex(where: { "/?#\\".contains($0) }) ?? rest.endIndex
        var authority = String(rest[..<end])
        path = String(rest[end...])
        if let at = authority.lastIndex(of: "@") {
            userInfo = String(authority[..<at])
            authority = String(authority[authority.index(after: at)...])
        }
        if authority.hasPrefix("["), let close = authority.firstIndex(of: "]") {
            authority = String(authority[...close])            // IPv6 address
        } else if let colon = authority.lastIndex(of: ":") {
            authority = String(authority[..<colon])            // drop the port
        }
        while authority.hasSuffix(".") { authority.removeLast() }
        host = authority.lowercased()
        guard !host.isEmpty else { return nil }
    }

    var isNumberAddress: Bool {
        if host.hasPrefix("[") { return true }
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        if parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) { return true }   // 192.168.1.1 or 3232235777
        return host.hasPrefix("0x")
    }

    /// The real website, like "paypal.com" for "login.paypal.com".
    var site: String {
        guard !isNumberAddress else { return host }
        let labels = host.split(separator: ".").map(String.init)
        guard labels.count > 2 else { return host }
        let second = labels[labels.count - 2]
        let twoLetterCountry = labels[labels.count - 1].count == 2
        let shared = ["co", "com", "org", "net", "gov", "ac", "edu", "ne", "or", "go", "gob"]
        let keep = twoLetterCountry && shared.contains(second) ? 3 : 2
        return labels.suffix(keep).joined(separator: ".")
    }

    /// The name part of the site ("paypal" for "paypal.com").
    var siteName: String { site.split(separator: ".").first.map(String.init) ?? site }
}

enum LinkSafety {
    /// Invisible characters that have no place in a real web address.
    private static let hiddenScalars: [ClosedRange<UInt32>] = [
        0x200B...0x200F,   // zero-width spaces and direction marks
        0x202A...0x202E,   // text direction overrides
        0x2060...0x2064,   // invisible joiners
        0x2066...0x2069,   // direction isolates
        0xFEFF...0xFEFF,   // zero-width no-break space
        0x00AD...0x00AD,   // soft hyphen
    ]

    private static func isHidden(_ scalar: Unicode.Scalar) -> Bool {
        hiddenScalars.contains { $0.contains(scalar.value) }
    }

    static func hasHiddenCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { isHidden($0) }
    }

    /// The text with invisible characters removed, for showing on screen.
    static func visible(_ text: String) -> String {
        String(text.unicodeScalars.filter { !isHidden($0) })
    }
}
