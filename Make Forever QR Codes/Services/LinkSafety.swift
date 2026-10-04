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

    /// Spots names made to look like a company on the built-in list.
    /// - Look-alike letters (paypa1, app1e) are checked for every company.
    /// - "Uses the name" (paypal-login.com) only for unique names. Everyday words
    ///   like Apple or Discover are left alone, so apple-farm.com is fine.
    private static func lookAlike(_ link: LinkParts) -> SafetyWarning? {
        let site = link.site
        let words = wordsIn(link)
        for known in knownSites {
            if known.domains.contains(site) { continue }   // the company's real website
            // Very short names (UPS, DHL, IRS) would match too many honest words.
            if known.key.count > 3 {
                let target = normalized(known.key)
                if words.contains(where: { $0 != known.key && normalized($0) == target }) {
                    return SafetyWarning(
                        title: "Looks like \(known.title), but isn't",
                        detail: "“\(site)” uses letters or numbers that look like “\(known.key)”.")
                }
            }
            if known.kind == .unique && words.contains(known.key) {
                return SafetyWarning(
                    title: "Uses the name \(known.title)",
                    detail: "The real website is \(site), which isn't \(known.title)'s own website.")
            }
        }
        return nil
    }

    /// The words in an address, split at dots and dashes, plus 2 or 3 of them
    /// joined (so "bank-of-america" also reads as "bankofamerica").
    private static func wordsIn(_ link: LinkParts) -> [String] {
        let parts = link.host.split(whereSeparator: { $0 == "." || $0 == "-" }).map(String.init)
        var words = parts
        for size in 2...3 where parts.count >= size {
            for start in 0...(parts.count - size) {
                words.append(parts[start..<(start + size)].joined())
            }
        }
        return words
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

    /// True when the link opens the real website of a company on the built-in list
    /// (like paypal.com). Only these get the green "No warning signs found".
    static func isKnownSite(_ url: URL) -> Bool {
        guard let link = LinkParts(url.absoluteString) else { return false }
        return knownSites.contains { $0.domains.contains(link.site) }
    }

    /// Warnings for a code that opens another app instead of a website.
    static func checkAppLink(scheme: String, appName: String) -> [SafetyWarning] {
        [SafetyWarning(
            title: "Opens \(appName)",
            detail: "This code opens \(appName) instead of a website. Only continue if you trust where the code came from.")]
    }

    // MARK: - Built-in list (part of the app, never downloaded)

    struct KnownSite {
        enum Kind {
            /// An invented name only that company uses (PayPal, Netflix).
            case unique
            /// A normal word other honest sites also use (Apple, Discover).
            case everyday
        }
        let key: String
        let title: String
        let kind: Kind
        /// The company's real website addresses.
        let domains: [String]

        init(_ key: String, _ title: String, _ kind: Kind, _ domains: [String]) {
            self.key = key
            self.title = title
            self.kind = kind
            self.domains = domains
        }
    }

    /// 100 companies scammers copy most, from security reports (Check Point,
    /// Guardio Labs) and the most-visited sites (Tranco).
    static let knownSites: [KnownSite] = [
        // Tech and email
        KnownSite("apple", "Apple", .everyday, ["apple.com", "icloud.com"]),
        KnownSite("icloud", "iCloud", .unique, ["icloud.com", "apple.com"]),
        KnownSite("microsoft", "Microsoft", .unique, ["microsoft.com", "live.com", "office.com", "microsoftonline.com", "outlook.com", "xbox.com"]),
        KnownSite("outlook", "Outlook", .everyday, ["outlook.com", "live.com", "office.com", "microsoft.com"]),
        KnownSite("google", "Google", .unique, ["google.com", "gmail.com", "youtube.com"]),
        KnownSite("gmail", "Gmail", .unique, ["gmail.com", "google.com"]),
        KnownSite("yahoo", "Yahoo", .unique, ["yahoo.com"]),
        KnownSite("aol", "AOL", .unique, ["aol.com"]),
        KnownSite("chatgpt", "ChatGPT", .unique, ["chatgpt.com", "openai.com"]),
        KnownSite("openai", "OpenAI", .unique, ["openai.com", "chatgpt.com"]),
        KnownSite("adobe", "Adobe", .unique, ["adobe.com"]),
        KnownSite("dropbox", "Dropbox", .unique, ["dropbox.com"]),
        KnownSite("docusign", "DocuSign", .unique, ["docusign.com", "docusign.net"]),
        KnownSite("zoom", "Zoom", .everyday, ["zoom.us", "zoom.com"]),
        KnownSite("norton", "Norton", .everyday, ["norton.com"]),
        KnownSite("mcafee", "McAfee", .unique, ["mcafee.com"]),
        // Social and messaging
        KnownSite("facebook", "Facebook", .unique, ["facebook.com", "fb.com", "meta.com", "messenger.com"]),
        KnownSite("meta", "Meta", .everyday, ["meta.com", "facebook.com"]),
        KnownSite("instagram", "Instagram", .unique, ["instagram.com"]),
        KnownSite("whatsapp", "WhatsApp", .unique, ["whatsapp.com"]),
        KnownSite("messenger", "Messenger", .everyday, ["messenger.com", "facebook.com"]),
        KnownSite("tiktok", "TikTok", .unique, ["tiktok.com"]),
        KnownSite("linkedin", "LinkedIn", .unique, ["linkedin.com"]),
        KnownSite("snapchat", "Snapchat", .unique, ["snapchat.com"]),
        KnownSite("telegram", "Telegram", .everyday, ["telegram.org", "t.me"]),
        KnownSite("discord", "Discord", .everyday, ["discord.com", "discord.gg"]),
        KnownSite("twitter", "X (Twitter)", .unique, ["twitter.com", "x.com"]),
        KnownSite("reddit", "Reddit", .unique, ["reddit.com"]),
        KnownSite("pinterest", "Pinterest", .unique, ["pinterest.com"]),
        // Shopping
        KnownSite("amazon", "Amazon", .unique, ["amazon.com", "amazon.ca", "amazon.co.uk", "amazon.com.mx", "primevideo.com"]),
        KnownSite("walmart", "Walmart", .unique, ["walmart.com"]),
        KnownSite("ebay", "eBay", .unique, ["ebay.com"]),
        KnownSite("costco", "Costco", .unique, ["costco.com"]),
        KnownSite("target", "Target", .everyday, ["target.com"]),
        KnownSite("bestbuy", "Best Buy", .unique, ["bestbuy.com"]),
        KnownSite("homedepot", "The Home Depot", .unique, ["homedepot.com"]),
        KnownSite("lowes", "Lowe's", .unique, ["lowes.com"]),
        KnownSite("etsy", "Etsy", .unique, ["etsy.com"]),
        KnownSite("temu", "Temu", .unique, ["temu.com"]),
        KnownSite("shein", "Shein", .unique, ["shein.com"]),
        KnownSite("aliexpress", "AliExpress", .unique, ["aliexpress.com"]),
        KnownSite("wayfair", "Wayfair", .unique, ["wayfair.com"]),
        KnownSite("macys", "Macy's", .unique, ["macys.com"]),
        KnownSite("shopify", "Shopify", .unique, ["shopify.com"]),
        // Banks and payments
        KnownSite("paypal", "PayPal", .unique, ["paypal.com", "paypal.me"]),
        KnownSite("venmo", "Venmo", .unique, ["venmo.com"]),
        KnownSite("cashapp", "Cash App", .unique, ["cash.app", "cashapp.com"]),
        KnownSite("zelle", "Zelle", .unique, ["zellepay.com", "zelle.com"]),
        KnownSite("chase", "Chase", .everyday, ["chase.com"]),
        KnownSite("bankofamerica", "Bank of America", .unique, ["bankofamerica.com"]),
        KnownSite("wellsfargo", "Wells Fargo", .unique, ["wellsfargo.com", "wf.com"]),
        KnownSite("citibank", "Citibank", .unique, ["citibank.com", "citi.com"]),
        KnownSite("capitalone", "Capital One", .unique, ["capitalone.com"]),
        KnownSite("americanexpress", "American Express", .unique, ["americanexpress.com", "amex.com"]),
        KnownSite("amex", "American Express", .unique, ["amex.com", "americanexpress.com"]),
        KnownSite("discover", "Discover", .everyday, ["discover.com"]),
        KnownSite("usbank", "U.S. Bank", .unique, ["usbank.com"]),
        KnownSite("truist", "Truist", .unique, ["truist.com"]),
        KnownSite("navyfederal", "Navy Federal", .unique, ["navyfederal.org"]),
        KnownSite("schwab", "Charles Schwab", .unique, ["schwab.com"]),
        KnownSite("fidelity", "Fidelity", .everyday, ["fidelity.com"]),
        KnownSite("robinhood", "Robinhood", .everyday, ["robinhood.com"]),
        KnownSite("mastercard", "Mastercard", .unique, ["mastercard.com"]),
        KnownSite("visa", "Visa", .everyday, ["visa.com"]),
        // Crypto
        KnownSite("coinbase", "Coinbase", .unique, ["coinbase.com"]),
        KnownSite("binance", "Binance", .unique, ["binance.com", "binance.us"]),
        KnownSite("kraken", "Kraken", .everyday, ["kraken.com"]),
        KnownSite("ledger", "Ledger", .everyday, ["ledger.com"]),
        KnownSite("metamask", "MetaMask", .unique, ["metamask.io"]),
        // Delivery
        KnownSite("usps", "USPS", .unique, ["usps.com"]),
        KnownSite("ups", "UPS", .everyday, ["ups.com"]),
        KnownSite("fedex", "FedEx", .unique, ["fedex.com"]),
        KnownSite("dhl", "DHL", .unique, ["dhl.com", "dhl.de"]),
        // Phone and internet
        KnownSite("xfinity", "Xfinity", .unique, ["xfinity.com", "comcast.com", "comcast.net"]),
        KnownSite("comcast", "Comcast", .unique, ["comcast.com", "comcast.net", "xfinity.com"]),
        KnownSite("verizon", "Verizon", .unique, ["verizon.com", "verizonwireless.com"]),
        KnownSite("att", "AT&T", .everyday, ["att.com"]),
        KnownSite("tmobile", "T-Mobile", .unique, ["t-mobile.com"]),
        KnownSite("spectrum", "Spectrum", .everyday, ["spectrum.com", "spectrum.net"]),
        // Streaming and games
        KnownSite("netflix", "Netflix", .unique, ["netflix.com"]),
        KnownSite("disneyplus", "Disney+", .unique, ["disneyplus.com"]),
        KnownSite("hulu", "Hulu", .unique, ["hulu.com"]),
        KnownSite("spotify", "Spotify", .unique, ["spotify.com"]),
        KnownSite("youtube", "YouTube", .unique, ["youtube.com", "youtu.be"]),
        KnownSite("steam", "Steam", .everyday, ["steampowered.com", "steamcommunity.com"]),
        KnownSite("roblox", "Roblox", .unique, ["roblox.com"]),
        KnownSite("playstation", "PlayStation", .unique, ["playstation.com"]),
        KnownSite("xbox", "Xbox", .unique, ["xbox.com", "microsoft.com"]),
        KnownSite("nintendo", "Nintendo", .unique, ["nintendo.com"]),
        KnownSite("epicgames", "Epic Games", .unique, ["epicgames.com"]),
        // Government and travel
        KnownSite("irs", "IRS", .unique, ["irs.gov"]),
        KnownSite("socialsecurity", "Social Security", .everyday, ["ssa.gov"]),
        KnownSite("medicare", "Medicare", .everyday, ["medicare.gov"]),
        KnownSite("ezpass", "E-ZPass", .unique, ["e-zpassny.com", "ezpassnj.com", "ezpassva.com", "ezpassmd.com", "e-zpassiag.com"]),
        KnownSite("airbnb", "Airbnb", .unique, ["airbnb.com"]),
        KnownSite("booking", "Booking.com", .everyday, ["booking.com"]),
        KnownSite("expedia", "Expedia", .unique, ["expedia.com"]),
        KnownSite("uber", "Uber", .everyday, ["uber.com"]),
        KnownSite("doordash", "DoorDash", .unique, ["doordash.com"]),
        KnownSite("delta", "Delta Air Lines", .everyday, ["delta.com"]),
    ]
}
