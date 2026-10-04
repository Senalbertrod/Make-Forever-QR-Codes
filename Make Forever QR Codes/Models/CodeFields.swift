//
//  CodeFields.swift
//  Make Forever QR Codes
//
//  Everything a person can type into the code forms. Saved with each code
//  (as JSON) so the code can be opened and edited later.
//

import Foundation

enum WiFiSecurity: String, CaseIterable, Codable, Identifiable {
    case wpa, wep, none
    var id: String { rawValue }
    var title: String {
        switch self {
        case .wpa: "WPA / WPA2 / WPA3"
        case .wep: "WEP (old)"
        case .none: "None (open network)"
        }
    }
    /// The value used inside Wi-Fi QR codes.
    var code: String {
        switch self {
        case .wpa: "WPA"
        case .wep: "WEP"
        case .none: "nopass"
        }
    }
}

enum LocationMode: String, CaseIterable, Codable, Identifiable {
    case address, coordinates
    var id: String { rawValue }
    var title: String { self == .address ? "Address" : "Coordinates" }
}

struct CodeFields: Codable, Equatable {
    // Link
    var url = ""

    // Contact
    var firstName = ""
    var lastName = ""
    var company = ""
    var jobTitle = ""
    var phone = ""
    var email = ""
    var website = ""
    var street = ""
    var city = ""
    var state = ""
    var postalCode = ""
    var country = ""
    // Lists for the + button (nil in codes saved before lists existed).
    var phoneList: [LabeledValue]? = nil
    var emailList: [LabeledValue]? = nil
    var websiteList: [LabeledValue]? = nil
    var addressList: [PostalAddress]? = nil
    var socialList: [SocialProfile]? = nil

    // Social profile (optional so codes saved before it existed still load)
    var socialServiceValue: SocialService? = nil
    var socialHandleValue: String? = nil

    // Phone, message and email (optional so codes saved without them still load)
    var phoneNumberValue: String? = nil
    var messageNumberValue: String? = nil
    var messageTextValue: String? = nil
    var emailToValue: String? = nil
    var emailSubjectValue: String? = nil
    var emailBodyValue: String? = nil

    // Wi-Fi
    var ssid = ""
    var password = ""
    var security: WiFiSecurity = .wpa
    var hiddenNetwork = false

    // Text
    var text = ""

    // Location
    var locationMode: LocationMode = .address
    var address = ""
    var latitude = ""
    var longitude = ""
    var placeName = ""

    // Event
    var eventTitle = ""
    var eventStart = Date()
    var eventEnd = Date().addingTimeInterval(3600)
    var eventAllDay = false
    var eventLocation = ""
    var eventNotes = ""

    var phoneNumber: String {
        get { phoneNumberValue ?? "" }
        set { phoneNumberValue = newValue }
    }
    var messageNumber: String {
        get { messageNumberValue ?? "" }
        set { messageNumberValue = newValue }
    }
    var messageText: String {
        get { messageTextValue ?? "" }
        set { messageTextValue = newValue }
    }
    var emailTo: String {
        get { emailToValue ?? "" }
        set { emailToValue = newValue }
    }
    var emailSubject: String {
        get { emailSubjectValue ?? "" }
        set { emailSubjectValue = newValue }
    }
    var emailBody: String {
        get { emailBodyValue ?? "" }
        set { emailBodyValue = newValue }
    }

    func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    static func decoded(from data: Data) -> CodeFields {
        (try? JSONDecoder().decode(CodeFields.self, from: data)) ?? CodeFields()
    }
}
