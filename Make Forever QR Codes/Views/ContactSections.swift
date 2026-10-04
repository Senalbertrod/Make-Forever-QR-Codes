//
//  ContactSections.swift
//  Make Forever QR Codes
//
//  Business card form sections with a + button: phones, emails, websites,
//  addresses and social profiles. The + disappears at the limit.
//

import SwiftUI

enum LineKind {
    case phone, email, link
}

/// Phones, emails or websites: a label menu and a text field per line.
struct LabeledLinesSection: View {
    let title: String
    let addTitle: String
    let placeholder: String
    @Binding var lines: [LabeledValue]
    let labels: [String]
    let max: Int
    let kind: LineKind

    var body: some View {
        Section(title) {
            ForEach($lines) { $line in
                HStack(spacing: 10) {
                    LabelMenu(label: $line.label, options: labels)
                    field(text: $line.value)
                    if lines.count > 1 {
                        RemoveButton { remove(line.id) }
                    }
                }
            }
            if lines.count < max {
                AddButton(title: addTitle) {
                    lines.append(LabeledValue(label: ContactLimits.nextLabel(labels, used: lines.map(\.label))))
                }
            }
        }
    }

    @ViewBuilder
    private func field(text: Binding<String>) -> some View {
        switch kind {
        case .phone:
            TextField(placeholder, text: text)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
        case .email:
            TextField(placeholder, text: text)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        case .link:
            TextField(placeholder, text: text)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private func remove(_ id: UUID) {
        withAnimation { lines.removeAll { $0.id == id } }
    }
}

struct AddressesSection: View {
    @Binding var addresses: [PostalAddress]

    var body: some View {
        ForEach($addresses) { $address in
            Section {
                TextField("Street", text: $address.street)
                    .textContentType(.fullStreetAddress)
                TextField("City", text: $address.city)
                    .textContentType(.addressCity)
                TextField("State", text: $address.state)
                    .textContentType(.addressState)
                TextField("ZIP / Postal code", text: $address.postalCode)
                    .textContentType(.postalCode)
                TextField("Country", text: $address.country)
                    .textContentType(.countryName)
            } header: {
                HStack {
                    Text("Address")
                    LabelMenu(label: $address.label, options: ContactLimits.addressLabels)
                        .textCase(nil)
                    Spacer()
                    if addresses.count > 1 {
                        RemoveButton {
                            let id = address.id
                            withAnimation { addresses.removeAll { $0.id == id } }
                        }
                        .textCase(nil)
                    }
                }
            }
        }
        if addresses.count < ContactLimits.addresses {
            Section {
                AddButton(title: "Add address") {
                    addresses.append(PostalAddress(label: ContactLimits.nextLabel(ContactLimits.addressLabels,
                                                                                  used: addresses.map(\.label))))
                }
            }
        }
    }
}

struct SocialProfilesSection: View {
    @Binding var profiles: [SocialProfile]

    var body: some View {
        Section {
            ForEach($profiles) { $profile in
                HStack(spacing: 10) {
                    Menu {
                        ForEach(SocialService.allCases) { service in
                            Button(service.title) { profile.service = service }
                        }
                    } label: {
                        MenuLabelText(text: profile.service.title)
                    }
                    TextField("Username or link", text: $profile.handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    RemoveButton {
                        let id = profile.id
                        withAnimation { profiles.removeAll { $0.id == id } }
                    }
                }
            }
            if profiles.count < ContactLimits.socials {
                AddButton(title: "Add social profile") {
                    let used = Set(profiles.map(\.service))
                    let next = SocialService.allCases.first { !used.contains($0) } ?? .other
                    profiles.append(SocialProfile(service: next))
                }
            }
        } header: {
            Text("Social profiles")
        } footer: {
            Text("iPhones show these as social profiles. Some Android phones may not, so add the link under Website too if it must work everywhere.")
        }
    }
}

// MARK: - Small pieces

struct LabelMenu: View {
    @Binding var label: String
    let options: [String]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) { label = option }
            }
        } label: {
            MenuLabelText(text: label)
        }
    }
}

private struct MenuLabelText: View {
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Text(text)
            Image(systemName: "chevron.up.chevron.down").font(.caption2)
        }
        .font(.subheadline)
        .foregroundStyle(.tint)
        .frame(minWidth: 76, alignment: .leading)
    }
}

private struct AddButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
        }
    }
}

private struct RemoveButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove")
    }
}
