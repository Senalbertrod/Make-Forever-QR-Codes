//
//  CodeType.swift
//  Make Forever QR Codes
//
//  The 9 kinds of codes the app can make, and how each one turns its
//  form fields into the text stored inside the QR code.
//

import Foundation

enum CodeType: String, CaseIterable, Identifiable, Codable {
    case link, contact, wifi, text, phone, message, email, location, event

    var id: String { rawValue }

    var title: String {
        switch self {
        case .link: "Link"
        case .contact: "Business Card"
        case .wifi: "Wi-Fi"
        case .text: "Text"
        case .phone: "Phone"
        case .message: "Message"
        case .email: "Email"
        case .location: "Location"
        case .event: "Event"
        }
    }

    var symbol: String {
        switch self {
        case .link: "link"
        case .contact: "person.crop.rectangle"
        case .wifi: "wifi"
        case .text: "text.alignleft"
        case .phone: "phone"
        case .message: "message"
        case .email: "envelope"
        case .location: "mappin.and.ellipse"
        case .event: "calendar"
        }
    }

    /// What happens when someone scans this kind of code.
    var scanResult: String {
        switch self {
        case .link: "Opens the website"
        case .contact: "Offers to add the contact"
        case .wifi: "Joins the Wi-Fi network"
        case .text: "Shows the text"
        case .phone: "Offers to call the number"
        case .message: "Opens a text message, ready to send"
        case .email: "Opens a new email, ready to send"
        case .location: "Opens the spot in Maps"
        case .event: "Offers to add the event to the calendar"
        }
    }

    // MARK: - Building the text inside the code

    /// The text stored in the QR code, or nil if a required field is empty.
    func payload(from f: CodeFields) -> String? {
        switch self {
        case .link:
            let url = f.url.trimmed
            guard !url.isEmpty else { return nil }
            return url.contains("://") ? url : "https://" + url

        case .contact:
            guard !(f.firstName.trimmed + f.lastName.trimmed + f.company.trimmed).isEmpty else { return nil }
            var lines = ["BEGIN:VCARD", "VERSION:3.0"]
            lines.append("N:\(f.lastName.vcard);\(f.firstName.vcard);;;")
            let fullName = [f.firstName.trimmed, f.lastName.trimmed].filter { !$0.isEmpty }.joined(separator: " ")
            lines.append("FN:\((fullName.isEmpty ? f.company.trimmed : fullName).vcard)")
            if !f.company.trimmed.isEmpty { lines.append("ORG:\(f.company.vcard)") }
            if !f.jobTitle.trimmed.isEmpty { lines.append("TITLE:\(f.jobTitle.vcard)") }
            if !f.phone.trimmed.isEmpty { lines.append("TEL;TYPE=CELL:\(f.phone.trimmed)") }
            if !f.email.trimmed.isEmpty { lines.append("EMAIL:\(f.email.trimmed)") }
            if !f.website.trimmed.isEmpty { lines.append("URL:\(f.website.vcard)") }
            let address = [f.street, f.city, f.state, f.postalCode, f.country].map(\.trimmed)
            if address.contains(where: { !$0.isEmpty }) {
                lines.append("ADR;TYPE=WORK:;;\(f.street.vcard);\(f.city.vcard);\(f.state.vcard);\(f.postalCode.vcard);\(f.country.vcard)")
            }
            lines.append("END:VCARD")
            return lines.joined(separator: "\n")

        case .wifi:
            guard !f.ssid.trimmed.isEmpty else { return nil }
            var s = "WIFI:T:\(f.security.code);S:\(f.ssid.wifi);"
            if f.security != .none { s += "P:\(f.password.wifi);" }
            if f.hiddenNetwork { s += "H:true;" }
            return s + ";"

        case .text:
            return f.text.trimmed.isEmpty ? nil : f.text

        case .phone:
            let number = f.phoneNumber.dialable
            return number.isEmpty ? nil : "tel:" + number

        case .message:
            let number = f.messageNumber.dialable
            guard !number.isEmpty else { return nil }
            return "SMSTO:\(number):\(f.messageText)"

        case .email:
            let to = f.emailTo.trimmed
            guard !to.isEmpty else { return nil }
            var parts = URLComponents()
            parts.scheme = "mailto"
            parts.path = to
            var items: [URLQueryItem] = []
            if !f.emailSubject.trimmed.isEmpty { items.append(URLQueryItem(name: "subject", value: f.emailSubject)) }
            if !f.emailBody.trimmed.isEmpty { items.append(URLQueryItem(name: "body", value: f.emailBody)) }
            if !items.isEmpty { parts.queryItems = items }
            return parts.string

        case .location:
            var parts = URLComponents(string: "https://maps.apple.com/")!
            var items: [URLQueryItem] = []
            switch f.locationMode {
            case .address:
                guard !f.address.trimmed.isEmpty else { return nil }
                items.append(URLQueryItem(name: "address", value: f.address.trimmed))
            case .coordinates:
                guard let lat = Double(f.latitude.trimmed), let lon = Double(f.longitude.trimmed),
                      (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
                items.append(URLQueryItem(name: "ll", value: "\(lat),\(lon)"))
            }
            if !f.placeName.trimmed.isEmpty { items.append(URLQueryItem(name: "q", value: f.placeName.trimmed)) }
            parts.queryItems = items
            return parts.string

        case .event:
            guard !f.eventTitle.trimmed.isEmpty else { return nil }
            var lines = ["BEGIN:VEVENT", "SUMMARY:\(f.eventTitle.vcard)"]
            if f.eventAllDay {
                let day = Calendar.current.startOfDay(for: f.eventStart)
                let endDay = Calendar.current.date(byAdding: .day, value: 1,
                                                   to: Calendar.current.startOfDay(for: max(f.eventEnd, f.eventStart))) ?? day
                lines.append("DTSTART;VALUE=DATE:\(DateFormat.day.string(from: day))")
                lines.append("DTEND;VALUE=DATE:\(DateFormat.day.string(from: endDay))")
            } else {
                lines.append("DTSTART:\(DateFormat.time.string(from: f.eventStart))")
                lines.append("DTEND:\(DateFormat.time.string(from: max(f.eventEnd, f.eventStart)))")
            }
            if !f.eventLocation.trimmed.isEmpty { lines.append("LOCATION:\(f.eventLocation.vcard)") }
            if !f.eventNotes.trimmed.isEmpty { lines.append("DESCRIPTION:\(f.eventNotes.vcard)") }
            lines.append("END:VEVENT")
            return lines.joined(separator: "\n")
        }
    }

    /// A good starting name when saving.
    func suggestedName(from f: CodeFields) -> String {
        switch self {
        case .link:
            let url = f.url.trimmed
            let full = url.contains("://") ? url : "https://" + url
            return URL(string: full)?.host() ?? "Link"
        case .contact:
            let name = [f.firstName.trimmed, f.lastName.trimmed].filter { !$0.isEmpty }.joined(separator: " ")
            return name.isEmpty ? (f.company.trimmed.isEmpty ? "Business Card" : f.company.trimmed) : name
        case .wifi: return f.ssid.trimmed.isEmpty ? "Wi-Fi" : "Wi-Fi: \(f.ssid.trimmed)"
        case .text: return String(f.text.trimmed.prefix(30))
        case .phone: return "Call \(f.phoneNumber.trimmed)"
        case .message: return "Text \(f.messageNumber.trimmed)"
        case .email: return "Email \(f.emailTo.trimmed)"
        case .location: return f.placeName.trimmed.isEmpty ? "Location" : f.placeName.trimmed
        case .event: return f.eventTitle.trimmed.isEmpty ? "Event" : f.eventTitle.trimmed
        }
    }
}

enum DateFormat {
    static let day: DateFormatter = make("yyyyMMdd")
    static let time: DateFormatter = make("yyyyMMdd'T'HHmmss")

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Escapes text for contact cards and calendar events.
    var vcard: String {
        trimmed
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Escapes text for Wi-Fi codes.
    var wifi: String {
        var out = ""
        for ch in self {
            if "\\;,:\"".contains(ch) { out.append("\\") }
            out.append(ch)
        }
        return out
    }

    /// Keeps only characters a phone can dial.
    var dialable: String { filter { "+0123456789*#".contains($0) } }
}
