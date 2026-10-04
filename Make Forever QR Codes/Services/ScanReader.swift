//
//  ScanReader.swift
//  Make Forever QR Codes
//
//  Works out what a scanned code holds (a website, Wi-Fi, a contact...)
//  and reads codes from photos. Everything happens on the phone.
//

import Contacts
import CoreImage
import Foundation

struct WiFiInfo: Hashable {
    var ssid = ""
    var password = ""
    var security: WiFiSecurity = .wpa
    var hidden = false
}

struct EventInfo: Hashable {
    var title = ""
    var start: Date?
    var end: Date?
    var allDay = false
    var location = ""
    var notes = ""
}

enum ScanKind {
    case link(URL)
    case social(SocialService, URL)
    case location(URL)
    case appLink(URL, appName: String)
    case contact(CNContact?)
    case event(EventInfo)
    case wifi(WiFiInfo)
    case text
}

struct ScannedCode: Identifiable {
    let id = UUID()
    let raw: String
    let kind: ScanKind

    init(raw: String) {
        self.raw = raw
        self.kind = ScanReader.kind(of: raw)
    }

    var title: String {
        switch kind {
        case .link: "Website"
        case .social(let service, _): service == .other ? "Social profile" : "\(service.title) profile"
        case .location: "Location"
        case .appLink(_, let app): "Opens \(app)"
        case .contact: "Contact"
        case .event: "Event"
        case .wifi: "Wi-Fi network"
        case .text: "Text"
        }
    }

    var symbol: String {
        switch kind {
        case .link: "link"
        case .social: "hand.thumbsup"
        case .location: "mappin.and.ellipse"
        case .appLink: "arrow.up.forward.app"
        case .contact: "person.crop.rectangle"
        case .event: "calendar"
        case .wifi: "wifi"
        case .text: "text.alignleft"
        }
    }

    /// Safety warnings, all checked on the phone.
    var warnings: [SafetyWarning] {
        switch kind {
        case .link, .social, .location: LinkSafety.check(raw)
        case .appLink(let url, let app): LinkSafety.checkAppLink(scheme: url.scheme ?? "", appName: app)
        case .wifi(let info): LinkSafety.check(wifi: info)
        case .contact, .event, .text: []
        }
    }

    // MARK: Saving to My Codes

    var savedType: CodeType {
        switch kind {
        case .link: .link
        case .social: .social
        case .location: .location
        case .contact: .contact
        case .event: .event
        case .wifi: .wifi
        case .appLink, .text: .text
        }
    }

    /// The form fields, filled in as far as possible.
    var savedFields: CodeFields {
        var f = CodeFields()
        switch kind {
        case .link:
            f.url = raw.trimmed
        case .social(let service, _):
            f.socialService = service
            f.socialHandle = raw.trimmed
        case .location:
            break
        case .contact(let contact):
            if let contact { f.fill(from: contact) }
        case .event(let e):
            f.eventTitle = e.title
            f.eventStart = e.start ?? Date()
            f.eventEnd = e.end ?? f.eventStart.addingTimeInterval(3600)
            f.eventAllDay = e.allDay
            f.eventLocation = e.location
            f.eventNotes = e.notes
        case .wifi(let w):
            f.ssid = w.ssid
            f.password = w.password
            f.security = w.security
            f.hiddenNetwork = w.hidden
        case .appLink, .text:
            f.text = raw
        }
        return f
    }

    var suggestedName: String {
        switch kind {
        case .link(let url), .location(let url):
            return LinkParts(url.absoluteString)?.site ?? title
        case .social(let service, let url):
            let user = url.path().split(separator: "/").last.map(String.init) ?? ""
            return user.isEmpty ? title : "\(service.title): \(user.hasPrefix("@") ? user : "@" + user)"
        case .contact(let c):
            guard let c else { return "Contact" }
            let name = [c.givenName, c.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            return name.isEmpty ? (c.organizationName.isEmpty ? "Contact" : c.organizationName) : name
        case .event(let e):
            return e.title.isEmpty ? "Event" : e.title
        case .wifi(let w):
            return w.ssid.isEmpty ? "Wi-Fi" : "Wi-Fi: \(w.ssid)"
        case .appLink, .text:
            return String(raw.trimmed.prefix(30))
        }
    }
}

enum ScanReader {
    static func kind(of raw: String) -> ScanKind {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = text.uppercased()

        if upper.hasPrefix("WIFI:") { return .wifi(wifi(from: text)) }
        if upper.hasPrefix("BEGIN:VCARD") { return .contact(contact(from: text)) }
        if upper.contains("BEGIN:VEVENT"), let e = event(from: text) { return .event(e) }
        if upper.hasPrefix("GEO:"), let url = mapsLink(fromGeo: text) { return .location(url) }

        guard !text.contains(where: \.isWhitespace), let url = makeURL(from: text),
              let scheme = url.scheme?.lowercased() else { return .text }

        if scheme == "http" || scheme == "https" {
            guard let parts = LinkParts(text) else { return .text }
            if isMaps(parts) { return .location(url) }
            if let service = socialService(for: parts.host) { return .social(service, url) }
            return .link(url)
        }
        if let app = appName(for: scheme) {
            return .appLink(url, appName: app)
        }
        if text.contains("://") {
            return .appLink(url, appName: "another app")
        }
        return .text
    }

    /// URL(string:) can refuse some characters, so try once more encoded.
    static func makeURL(from text: String) -> URL? {
        if let url = URL(string: text) { return url }
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else { return nil }
        return URL(string: encoded)
    }

    private static func appName(for scheme: String) -> String? {
        switch scheme {
        case "tel", "telprompt": "Phone"
        case "sms", "smsto", "imessage": "Messages"
        case "mailto": "Mail"
        case "facetime", "facetime-audio": "FaceTime"
        case "maps": "Maps"
        case "shortcuts": "Shortcuts"
        case "itms-apps", "itms-appss": "App Store"
        default: nil
        }
    }

    private static func isMaps(_ link: LinkParts) -> Bool {
        let host = link.host
        return host == "maps.apple.com" || host == "maps.google.com" || host == "maps.app.goo.gl"
            || ((host == "google.com" || host == "www.google.com") && link.path.hasPrefix("/maps"))
    }

    private static func socialService(for host: String) -> SocialService? {
        var h = host
        for prefix in ["www.", "m.", "mobile.", "vm."] where h.hasPrefix(prefix) {
            h = String(h.dropFirst(prefix.count))
        }
        switch h {
        case "instagram.com": return .instagram
        case "x.com", "twitter.com": return .x
        case "tiktok.com": return .tiktok
        case "linkedin.com": return .linkedin
        case "facebook.com", "fb.com": return .facebook
        case "youtube.com", "youtu.be": return .youtube
        case "threads.net", "threads.com": return .threads
        default: return nil
        }
    }

    // MARK: Wi-Fi

    static func wifi(from text: String) -> WiFiInfo {
        var parts: [String] = []
        var current = ""
        var escaping = false
        for ch in text.dropFirst(5) {
            if escaping {
                current.append(ch)
                escaping = false
            } else if ch == "\\" {
                escaping = true
            } else if ch == ";" {
                parts.append(current)
                current = ""
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { parts.append(current) }

        var info = WiFiInfo()
        var type: String?
        for part in parts {
            guard let colon = part.firstIndex(of: ":") else { continue }
            let key = part[..<colon].uppercased()
            let value = String(part[part.index(after: colon)...])
            switch key {
            case "S": info.ssid = value
            case "P": info.password = value
            case "T": type = value.uppercased()
            case "H": info.hidden = value.lowercased() == "true"
            default: break
            }
        }
        if let type {
            switch type {
            case "WEP": info.security = .wep
            case "NOPASS", "": info.security = .none
            default: info.security = .wpa
            }
        } else {
            info.security = info.password.isEmpty ? .none : .wpa
        }
        return info
    }

    // MARK: Contact

    static func contact(from text: String) -> CNContact? {
        // Contact cards officially use \r\n line endings.
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\n", with: "\r\n")
        return (try? CNContactVCardSerialization.contacts(with: Data(normalized.utf8)))?.first
    }

    // MARK: Event

    static func event(from text: String) -> EventInfo? {
        let unfolded = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
        var info = EventInfo()
        var inside = false
        var found = false
        for line in unfolded.split(separator: "\n") {
            let upper = line.uppercased()
            if upper.hasPrefix("BEGIN:VEVENT") { inside = true; found = true; continue }
            if upper.hasPrefix("END:VEVENT") { break }
            guard inside, let colon = line.firstIndex(of: ":") else { continue }
            let head = line[..<colon].uppercased()
            let name = head.split(separator: ";").first.map(String.init) ?? head
            let value = String(line[line.index(after: colon)...])
            switch name {
            case "SUMMARY": info.title = unescape(value)
            case "LOCATION": info.location = unescape(value)
            case "DESCRIPTION": info.notes = unescape(value)
            case "DTSTART":
                info.start = date(value)
                info.allDay = head.contains("VALUE=DATE") || value.count == 8
            case "DTEND": info.end = date(value)
            default: break
            }
        }
        guard found, !info.title.isEmpty || info.start != nil else { return nil }
        if info.allDay, let start = info.start, let end = info.end, end > start {
            // In codes the end day is the day after; the calendar wants the last day.
            info.end = end.addingTimeInterval(-1)
        }
        return info
    }

    private static func date(_ value: String) -> Date? {
        let v = value.trimmed
        if v.count == 8 { return DateFormat.day.date(from: v) }
        if v.hasSuffix("Z") { return utc.date(from: String(v.dropLast())) }
        return DateFormat.time.date(from: v)
    }

    private static let utc: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss"
        return f
    }()

    private static func unescape(_ s: String) -> String {
        var out = ""
        var escaping = false
        for ch in s {
            if escaping {
                out.append(ch == "n" || ch == "N" ? "\n" : ch)
                escaping = false
            } else if ch == "\\" {
                escaping = true
            } else {
                out.append(ch)
            }
        }
        return out
    }

    // MARK: Location

    /// "geo:40.7,-73.9" becomes an Apple Maps link.
    private static func mapsLink(fromGeo text: String) -> URL? {
        let body = text.dropFirst(4).split(separator: "?").first ?? ""
        let numbers = body.split(separator: ";").first?.split(separator: ",").compactMap { Double($0) } ?? []
        guard numbers.count >= 2 else { return nil }
        return URL(string: "https://maps.apple.com/?ll=\(numbers[0]),\(numbers[1])")
    }

    // MARK: Photos

    /// Finds a QR code in a picture (a photo or a screenshot).
    static func readCode(fromImageData data: Data) -> String? {
        guard let image = CIImage(data: data, options: [.applyOrientationProperty: true]) else { return nil }
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil,
                                  options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: image) ?? []
        return features.compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
    }
}
