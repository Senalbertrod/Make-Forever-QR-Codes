//
//  LinkSafety.swift
//  Make Forever QR Codes
//
//  Checks a scanned link for common scam tricks, entirely on the phone.
//  No website, no list downloaded from anywhere: it only looks at the link
//  itself. It can't know every bad website, so it warns about warning signs.
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
    static func check(_ text: String) -> [SafetyWarning] {
        guard let link = LinkParts(text) else { return [] }
        var warnings: [SafetyWarning] = []
        let site = link.site

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

        if shorteners.contains(site) || shorteners.contains(link.host) {
            warnings.append(SafetyWarning(
                title: "Short link",
                detail: "Short links hide where they really go. You won't see the real website until it opens."))
        }

        if let tld = link.host.split(separator: ".").last, ["zip", "mov"].contains(String(tld)) {
            warnings.append(SafetyWarning(
                title: "Looks like a file name",
                detail: "This website ends in “.\(tld)”, which can be mistaken for a file."))
        }

        let path = (link.path.split(whereSeparator: { "?#".contains($0) }).first.map(String.init) ?? "").lowercased()
        if path.hasSuffix(".mobileconfig") {
            warnings.append(SafetyWarning(
                title: "iPhone profile",
                detail: "This downloads a profile that can change your iPhone's settings. Only install profiles from your work or school."))
        } else if let ext = riskyFiles.first(where: { path.hasSuffix("." + $0) }) {
            warnings.append(SafetyWarning(
                title: "Download",
                detail: "This link downloads a “.\(ext)” file instead of opening a web page."))
        }

        if link.scheme == "http" {
            warnings.append(SafetyWarning(
                title: "Not secure",
                detail: "This link uses “http” without the “s”, so anything you type there isn't protected."))
        }

        return warnings
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

    static func check(wifi: WiFiInfo) -> [SafetyWarning] {
        switch wifi.security {
        case .none:
            [SafetyWarning(title: "Open network",
                           detail: "This network has no password. People nearby may be able to see what you send on it.")]
        case .wep:
            [SafetyWarning(title: "Old security",
                           detail: "This network uses WEP, an old kind of security that is easy to break.")]
        case .wpa:
            []
        }
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

    private static let shorteners: Set<String> = [
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly", "is.gd", "buff.ly", "rebrand.ly",
        "cutt.ly", "shorturl.at", "rb.gy", "tiny.cc", "bl.ink", "t.ly", "s.id", "v.gd", "qrco.de",
        "short.io", "shorturl.com", "lnkd.in", "trib.al", "soo.gd", "clck.ru", "u.to", "x.co",
    ]

    private static let riskyFiles = ["apk", "ipa", "exe", "msi", "dmg", "pkg", "bat", "scr", "jar", "zip", "rar", "7z"]
}
