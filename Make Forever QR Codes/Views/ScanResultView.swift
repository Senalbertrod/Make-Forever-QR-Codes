//
//  ScanResultView.swift
//  Make Forever QR Codes
//
//  What a scanned code holds, any safety warnings, and what to do with it.
//  Nothing opens by itself, and nothing is kept unless the person taps Save.
//

import Contacts
import SwiftData
import SwiftUI

struct ScanResultView: View {
    let code: ScannedCode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    @State private var confirmOpen = false
    @State private var showAddContact = false
    @State private var showAddEvent = false
    @State private var askName = false
    @State private var name = ""
    @State private var saved = false
    @State private var copied: String?

    private var warnings: [SafetyWarning] { code.warnings }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(code.title, systemImage: code.symbol)
                        .font(.headline)
                    content
                }

                // Only where a scam is possible: red whenever there are warning
                // signs, green only for website links (not maps, profiles, apps,
                // Wi-Fi, contacts, events or text).
                if !warnings.isEmpty {
                    Section {
                        Label("Warning: this could be a scam", systemImage: "xmark.shield.fill")
                            .foregroundStyle(.red)
                    }
                } else if isWebsite {
                    Section {
                        Label("No warning signs found", systemImage: "checkmark.shield")
                            .foregroundStyle(.green)
                    }
                }

                Section { actions }

                Section {
                    if saved {
                        Label("Saved to My Codes", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("Save to My Codes", systemImage: "square.and.arrow.down") {
                            name = code.suggestedName
                            askName = true
                        }
                    }
                } footer: {
                    if !saved { Text("Not saved unless you tap Save.") }
                }
            }
            .navigationTitle("Scanned Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Name this code", isPresented: $askName) {
                TextField("Name", text: $name)
                Button("Save") { save() }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Open anyway?", isPresented: $confirmOpen, titleVisibility: .visible) {
                Button("Open", role: .destructive) { openLink() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This code has warning signs. Only open it if you trust where it came from.")
            }
            .sheet(isPresented: $showAddContact) {
                if case .contact(let contact?) = code.kind {
                    ContactAdder(contact: contact) { showAddContact = false }
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showAddEvent) {
                if case .event(let info) = code.kind {
                    EventAdder(info: info) { showAddEvent = false }
                        .ignoresSafeArea()
                }
            }
            .sensoryFeedback(.success, trigger: copied)
        }
    }

    private var isWebsite: Bool {
        if case .link = code.kind { return true }
        return false
    }

    // MARK: What's inside

    @ViewBuilder
    private var content: some View {
        switch code.kind {
        case .link(let url), .social(_, let url), .location(let url), .appLink(let url, _):
            // The site name comes from the link that will really open.
            if let parts = LinkParts(url.absoluteString) {
                VStack(alignment: .leading, spacing: 4) {
                    // A font where I, l, 1, 0 and O all look different, so swapped
                    // letters are easy to spot.
                    Text(parts.site)
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(warnings.isEmpty ? Color.primary : Color.red)
                        .textSelection(.enabled)
                    Text(LinkSafety.visible(code.raw.trimmed))
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text(url.absoluteString)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
            }

        case .contact(let contact):
            if let contact {
                ContactSummary(contact: contact)
            } else {
                Text(code.raw).font(.footnote.monospaced()).textSelection(.enabled)
            }

        case .event(let e):
            VStack(alignment: .leading, spacing: 4) {
                Text(e.title.isEmpty ? "Event" : e.title).font(.title3.weight(.semibold))
                if let start = e.start {
                    Text(e.allDay ? start.formatted(date: .complete, time: .omitted)
                                  : start.formatted(date: .complete, time: .shortened))
                }
                if !e.location.isEmpty { Text(e.location).foregroundStyle(.secondary) }
                if !e.notes.isEmpty { Text(e.notes).font(.footnote).foregroundStyle(.secondary) }
            }

        case .wifi(let w):
            LabeledContent("Network", value: w.ssid.isEmpty ? "No name" : w.ssid)
            LabeledContent("Security", value: w.security.title)
            if w.security != .none {
                LabeledContent("Password", value: w.password)
                    .textSelection(.enabled)
            }
            if w.hidden { LabeledContent("Hidden network", value: "Yes") }

        case .text:
            Text(LinkSafety.visible(code.raw))
                .textSelection(.enabled)
        }
    }

    // MARK: Buttons

    @ViewBuilder
    private var actions: some View {
        switch code.kind {
        case .link, .social, .location, .appLink:
            Button(openTitle, systemImage: "arrow.up.forward.square") {
                if warnings.isEmpty { openLink() } else { confirmOpen = true }
            }
            Button("Copy Link", systemImage: "doc.on.doc") { copy(code.raw.trimmed) }

        case .contact(let contact):
            if contact != nil {
                Button("Add to Contacts", systemImage: "person.crop.circle.badge.plus") { showAddContact = true }
            }
            Button("Copy", systemImage: "doc.on.doc") { copy(code.raw) }

        case .event:
            Button("Add to Calendar", systemImage: "calendar.badge.plus") { showAddEvent = true }

        case .wifi(let w):
            // REMINDER: when the Apple Developer Program is joined (before the App Store
            // upload), add a one-tap "Join Network" button here with NEHotspotConfiguration.
            // It needs the Hotspot Configuration permission, which free accounts can't use.
            if !w.password.isEmpty {
                Button("Copy Password", systemImage: "key") { copy(w.password) }
            }
            Button("Copy Network Name", systemImage: "doc.on.doc") { copy(w.ssid) }
            Text("To join, go to Settings › Wi-Fi, pick the network and paste the password.")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .text:
            Button("Copy", systemImage: "doc.on.doc") { copy(code.raw) }
        }

        if let copied {
            Label("Copied \(copied)", systemImage: "checkmark")
                .font(.footnote)
                .foregroundStyle(.green)
        }
    }

    private var openTitle: String {
        switch code.kind {
        case .social: "Open Profile"
        case .location: "Open in Maps"
        case .appLink(_, let app): app == "another app" ? "Open" : "Open in \(app)"
        default: "Open Website"
        }
    }

    private func openLink() {
        switch code.kind {
        case .link(let url), .social(_, let url), .location(let url), .appLink(let url, _):
            openURL(url)
        default:
            break
        }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        switch code.kind {
        case .wifi(let w) where text == w.password && !text.isEmpty: copied = "password"
        case .wifi: copied = "network name"
        case .link, .social, .location, .appLink: copied = "link"
        default: copied = "text"
        }
    }

    private func save() {
        let finalName = name.trimmed.isEmpty ? code.suggestedName : name.trimmed
        let newCode = SavedCode(name: finalName, type: code.savedType, payload: code.raw.trimmed,
                                fields: code.savedFields, isScanned: true)
        modelContext.insert(newCode)
        saved = true
    }
}

private struct ContactSummary: View {
    let contact: CNContact

    private func has(_ key: String) -> Bool { contact.isKeyAvailable(key) }

    private var name: String {
        let parts = [has(CNContactGivenNameKey) ? contact.givenName : "",
                     has(CNContactFamilyNameKey) ? contact.familyName : ""]
        let full = parts.filter { !$0.isEmpty }.joined(separator: " ")
        return full.isEmpty ? "No name" : full
    }

    private var company: String {
        has(CNContactOrganizationNameKey) ? contact.organizationName : ""
    }

    private var lines: [String] {
        var out: [String] = []
        if has(CNContactPhoneNumbersKey) { out += contact.phoneNumbers.map { $0.value.stringValue } }
        if has(CNContactEmailAddressesKey) { out += contact.emailAddresses.map { $0.value as String } }
        if has(CNContactUrlAddressesKey) { out += contact.urlAddresses.map { $0.value as String } }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.title3.weight(.semibold))
            if !company.isEmpty { Text(company).foregroundStyle(.secondary) }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
