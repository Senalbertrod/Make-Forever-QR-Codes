//
//  LinkSafety.swift
//  Make Forever QR Codes
//
//  Checks a scanned link for strong scam signs, entirely on the phone.
//  No website, no list downloaded from anywhere: it only looks at the link
//  itself. Safari's own Fraudulent Website Warning still runs when it opens.
//

import Foundation

struct SafetyWarning: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
}

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
    /// Warnings for a website link (empty when nothing looks wrong).
    /// `text` is the link as scanned; `url` is the link that will really open.
    /// Only strong scam signs are checked. Things Safari and iPhone already
    /// warn about (known bad sites, downloads, profiles, http, open Wi-Fi)
    /// are left to them, so honest codes open without fuss.
    static func check(_ text: String, opening url: URL) -> [SafetyWarning] {
        var warnings: [SafetyWarning] = []

        // 1. The address shown must be the one that opens.
        if let shown = LinkParts(text)?.host, let real = openedHost(url),
           shown.unicodeScalars.allSatisfy(\.isASCII), shown != real {
            warnings.append(SafetyWarning(
                title: "Written in an unusual way",
                detail: "The link looks like it goes to \(shown), but it really opens \(real)."))
        }

        // 2. Invisible characters that hide or flip parts of the link.
        if hasHiddenCharacters(text) {
            warnings.append(SafetyWarning(
                title: "Hidden characters",
                detail: "This link contains invisible characters that can make it look like something else."))
        }

        // Look at both the scanned text and the link that will open.
        for candidate in [text, url.absoluteString] {
            guard let link = LinkParts(candidate) else { continue }
            for warning in patternWarnings(link) where !warnings.contains(where: { $0.title == warning.title }) {
                warnings.append(warning)
            }
        }
        return warnings
    }

    private static func patternWarnings(_ link: LinkParts) -> [SafetyWarning] {
        var warnings: [SafetyWarning] = []
        if let user = link.userInfo, !user.isEmpty {
            warnings.append(SafetyWarning(
                title: "Hidden real address",
                detail: "The part before the “@” is only decoration. This link really goes to \(link.host)."))
        }
        if link.host.contains("xn--") || link.host.unicodeScalars.contains(where: { !$0.isASCII }) {
            warnings.append(SafetyWarning(
                title: "Look-alike letters",
                detail: "The address uses letters from another alphabet that can look like normal English letters."))
        }
        if let brand = lookAlike(link) {
            warnings.append(brand)
        }
        if link.isNumberAddress {
            warnings.append(SafetyWarning(
                title: "Number instead of a name",
                detail: "Real businesses almost always use a website name, not a number address."))
        }
        return warnings
    }

    /// The website iPhone will really open.
    private static func openedHost(_ url: URL) -> String? {
        guard var host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else { return nil }
        while host.hasSuffix(".") { host.removeLast() }
        if host.contains(":") && !host.hasPrefix("[") { host = "[\(host)]" }   // IPv6, as LinkParts writes it
        return host
    }

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

    /// Spots names made to look like a well-known company.
    private static func lookAlike(_ link: LinkParts) -> SafetyWarning? {
        let name = link.siteName
        let tokens = link.host.split(whereSeparator: { $0 == "." || $0 == "-" }).map(String.init)
        for (brand, title) in brands {
            if name == brand { return nil }   // the real company
            if normalized(name) == normalized(brand) {
                return SafetyWarning(
                    title: "Looks like \(title), but isn't",
                    detail: "“\(link.site)” uses letters or numbers that look like “\(brand)”.")
            }
            if tokens.contains(brand) {
                return SafetyWarning(
                    title: "Uses the name \(title)",
                    detail: "The real website is \(link.site), which isn't \(title)'s own website.")
            }
        }
        return nil
    }

    /// Turns look-alike characters into the letters they imitate.
    private static func normalized(_ s: String) -> String {
        var out = s.lowercased()
        for (fake, real) in [("rn", "m"), ("vv", "w"), ("0", "o"), ("1", "l"), ("i", "l"),
                             ("3", "e"), ("5", "s"), ("$", "s"), ("@", "a")] {
            out = out.replacingOccurrences(of: fake, with: real)
        }
        return out
    }

    /// Warnings for a code that opens another app instead of a website.
    static func checkAppLink(scheme: String, appName: String) -> [SafetyWarning] {
        [SafetyWarning(
            title: "Opens \(appName)",
            detail: "This code opens \(appName) instead of a website. Only continue if you trust where the code came from.")]
    }

    // MARK: - Built-in lists (part of the app, never downloaded)

    private static let brands: [(String, String)] = [
        ("apple", "Apple"), ("icloud", "iCloud"), ("paypal", "PayPal"), ("google", "Google"),
        ("gmail", "Gmail"), ("amazon", "Amazon"), ("microsoft", "Microsoft"),
        ("netflix", "Netflix"), ("facebook", "Facebook"), ("instagram", "Instagram"),
        ("whatsapp", "WhatsApp"), ("tiktok", "TikTok"), ("linkedin", "LinkedIn"), ("youtube", "YouTube"),
        ("chase", "Chase"), ("bankofamerica", "Bank of America"), ("wellsfargo", "Wells Fargo"),
        ("citibank", "Citibank"), ("capitalone", "Capital One"), ("usps", "USPS"), ("fedex", "FedEx"),
        ("dhl", "DHL"), ("irs", "IRS"), ("coinbase", "Coinbase"), ("binance", "Binance"),
        ("venmo", "Venmo"), ("cashapp", "Cash App"), ("zelle", "Zelle"), ("walmart", "Walmart"),
        ("ebay", "eBay"), ("spotify", "Spotify"), ("dropbox", "Dropbox"),
    ]
}
