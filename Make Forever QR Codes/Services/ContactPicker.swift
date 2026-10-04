//
//  ContactPicker.swift
//  Make Forever QR Codes
//
//  "Fill from my contact card": Apple's contact picker. The app only sees
//  the one contact the user taps, so no Contacts permission is needed.
//

import Contacts
import ContactsUI
import SwiftUI

/// Put this in the background of a view; set `isPresented` to show the picker.
struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onPick: (CNContact) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.parent = self
        if isPresented, host.presentedViewController == nil {
            let picker = CNContactPickerViewController()
            picker.delegate = context.coordinator
            DispatchQueue.main.async { host.present(picker, animated: true) }
        }
    }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker
        init(_ parent: ContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onPick(contact)
            parent.isPresented = false
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.isPresented = false
        }
    }
}

extension CodeFields {
    /// Copies a contact's details into the contact fields.
    mutating func fill(from c: CNContact) {
        func has(_ key: String) -> Bool { c.isKeyAvailable(key) }
        if has(CNContactGivenNameKey) { firstName = c.givenName }
        if has(CNContactFamilyNameKey) { lastName = c.familyName }
        if has(CNContactOrganizationNameKey) { company = c.organizationName }
        if has(CNContactJobTitleKey) { jobTitle = c.jobTitle }
        if has(CNContactPhoneNumbersKey), !c.phoneNumbers.isEmpty {
            phones = c.phoneNumbers.prefix(ContactLimits.phones).map { item in
                let label: String
                switch item.label ?? "" {
                case CNLabelWork: label = "Work"
                case CNLabelHome: label = "Home"
                default: label = "Mobile"
                }
                return LabeledValue(label: label, value: item.value.stringValue)
            }
        }
        if has(CNContactEmailAddressesKey), !c.emailAddresses.isEmpty {
            emails = c.emailAddresses.prefix(ContactLimits.emails).map { item in
                let label: String
                switch item.label ?? "" {
                case CNLabelWork: label = "Work"
                case CNLabelHome: label = "Personal"
                default: label = "Other"
                }
                return LabeledValue(label: label, value: item.value as String)
            }
        }
        if has(CNContactUrlAddressesKey), !c.urlAddresses.isEmpty {
            websites = c.urlAddresses.prefix(ContactLimits.websites).map {
                LabeledValue(label: "Website", value: $0.value as String)
            }
        }
        if has(CNContactPostalAddressesKey), !c.postalAddresses.isEmpty {
            addresses = c.postalAddresses.prefix(ContactLimits.addresses).map { item in
                let a = item.value
                return PostalAddress(label: item.label == CNLabelHome ? "Home" : "Work",
                                     street: a.street, city: a.city, state: a.state,
                                     postalCode: a.postalCode, country: a.country)
            }
        }
        if has(CNContactSocialProfilesKey), !c.socialProfiles.isEmpty {
            socials = c.socialProfiles.prefix(ContactLimits.socials).map { item in
                let p = item.value
                let name = p.service.lowercased()
                let named = SocialService.allCases.first { $0 != .x && $0 != .other && name.contains($0.rawValue) }
                let service = named ?? ((name == "x" || name.contains("twitter")) ? .x : .other)
                let handle = p.username.isEmpty ? p.urlString : p.username
                return SocialProfile(service: service, handle: handle)
            }
        }
    }
}
