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
    /// Copies a contact's details into the business card fields.
    mutating func fill(from c: CNContact) {
        func has(_ key: String) -> Bool { c.isKeyAvailable(key) }
        if has(CNContactGivenNameKey) { firstName = c.givenName }
        if has(CNContactFamilyNameKey) { lastName = c.familyName }
        if has(CNContactOrganizationNameKey) { company = c.organizationName }
        if has(CNContactJobTitleKey) { jobTitle = c.jobTitle }
        if has(CNContactPhoneNumbersKey), let p = c.phoneNumbers.first { phone = p.value.stringValue }
        if has(CNContactEmailAddressesKey), let e = c.emailAddresses.first { email = e.value as String }
        if has(CNContactUrlAddressesKey), let u = c.urlAddresses.first { website = u.value as String }
        if has(CNContactPostalAddressesKey), let a = c.postalAddresses.first?.value {
            street = a.street
            city = a.city
            state = a.state
            postalCode = a.postalCode
            country = a.country
        }
    }
}
