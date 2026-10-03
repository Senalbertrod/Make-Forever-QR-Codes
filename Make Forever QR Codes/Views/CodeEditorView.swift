//
//  CodeEditorView.swift
//  Make Forever QR Codes
//
//  The form for one kind of code, with a live preview at the top.
//  Used both to make a new code and to edit a saved one.
//

import SwiftUI
import SwiftData

struct CodeEditorView: View {
    let type: CodeType
    var existing: SavedCode? = nil
    var onSaved: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var fields = CodeFields()
    @State private var foreground: Color = .black
    @State private var background: Color = .white
    @State private var askName = false
    @State private var name = ""
    @State private var showContactPicker = false
    @State private var loaded = false

    private var payload: String? { type.payload(from: fields) }
    private var fg: UIColor { UIColor(foreground) }
    private var bg: UIColor { UIColor(background) }
    private var byteCount: Int { payload.map { Data($0.utf8).count } ?? 0 }
    private var tooLong: Bool { byteCount > QRRenderer.maxBytes }

    var body: some View {
        Form {
            Section {
                QRCodeImage(payload: tooLong ? "" : payload, foreground: fg, background: bg)
                    .frame(maxWidth: 260)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("When scanned: \(type.scanResult.lowercased()).")
                    if tooLong {
                        Text("Too much text for one QR code. Make it shorter.")
                            .foregroundStyle(.red)
                    } else if byteCount > QRRenderer.denseBytes {
                        Text("This code is getting dense. It may be hard to scan from a small screen; keep it shorter if you can.")
                            .foregroundStyle(.orange)
                    }
                }
            }

            CodeFormSections(type: type, fields: $fields, showContactPicker: $showContactPicker)

            Section {
                ColorPicker("Code color", selection: $foreground, supportsOpacity: false)
                ColorPicker("Background", selection: $background, supportsOpacity: false)
                if foreground != .black || background != .white {
                    Button("Back to black and white") {
                        foreground = .black
                        background = .white
                    }
                }
            } header: {
                Text("Colors")
            } footer: {
                if let warning = QRRenderer.colorWarning(foreground: fg, background: bg) {
                    Text(warning).foregroundStyle(.orange)
                } else {
                    Text("Black on white always scans best.")
                }
            }
        }
        .navigationTitle(existing == nil ? type.title : "Edit \(type.title)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(payload == nil || tooLong)
            }
        }
        .alert("Name this code", isPresented: $askName) {
            TextField("Name", text: $name)
            Button("Save") { insertNew() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("For example \"Bakery menu\" or \"Home Wi-Fi\".")
        }
        .background(
            ContactPicker(isPresented: $showContactPicker) { contact in
                fields.fill(from: contact)
            }
            .frame(width: 0, height: 0)
        )
        .onAppear(perform: loadExisting)
    }

    private func loadExisting() {
        guard !loaded else { return }
        loaded = true
        guard let existing else { return }
        fields = existing.fields
        foreground = Color(uiColor: existing.foreground)
        background = Color(uiColor: existing.background)
    }

    private func save() {
        guard let payload, !tooLong else { return }
        if let existing {
            existing.payload = payload
            existing.fieldsData = fields.encoded()
            existing.foregroundHex = fg.hexString
            existing.backgroundHex = bg.hexString
            dismiss()
        } else {
            name = type.suggestedName(from: fields)
            askName = true
        }
    }

    private func insertNew() {
        guard let payload else { return }
        let finalName = name.trimmed.isEmpty ? type.suggestedName(from: fields) : name.trimmed
        let code = SavedCode(name: finalName, type: type, payload: payload, fields: fields,
                             foregroundHex: fg.hexString, backgroundHex: bg.hexString)
        modelContext.insert(code)
        dismiss()
        onSaved()
    }
}

/// The form fields for each kind of code.
struct CodeFormSections: View {
    let type: CodeType
    @Binding var fields: CodeFields
    @Binding var showContactPicker: Bool

    var body: some View {
        switch type {
        case .link:
            Section("Website") {
                TextField("example.com", text: $fields.url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

        case .contact:
            Section {
                Button("Fill from my contact card", systemImage: "person.crop.circle") {
                    showContactPicker = true
                }
            } footer: {
                Text("Pick a contact to fill in the form. The app only sees the contact you pick.")
            }
            Section("Name") {
                TextField("First name", text: $fields.firstName)
                    .textContentType(.givenName)
                TextField("Last name", text: $fields.lastName)
                    .textContentType(.familyName)
                TextField("Company", text: $fields.company)
                    .textContentType(.organizationName)
                TextField("Job title", text: $fields.jobTitle)
                    .textContentType(.jobTitle)
            }
            Section("Contact") {
                TextField("Phone", text: $fields.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                TextField("Email", text: $fields.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                TextField("Website", text: $fields.website)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
            }
            Section("Address") {
                TextField("Street", text: $fields.street)
                TextField("City", text: $fields.city)
                TextField("State", text: $fields.state)
                TextField("ZIP / Postal code", text: $fields.postalCode)
                TextField("Country", text: $fields.country)
            }

        case .wifi:
            Section {
                TextField("Network name", text: $fields.ssid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Security", selection: $fields.security) {
                    ForEach(WiFiSecurity.allCases) { Text($0.title).tag($0) }
                }
                if fields.security != .none {
                    TextField("Password", text: $fields.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Toggle("Hidden network", isOn: $fields.hiddenNetwork)
            } header: {
                Text("Wi-Fi")
            } footer: {
                Text("Guests scan the code and join without typing the password.")
            }

        case .text:
            Section("Text") {
                TextField("Your text", text: $fields.text, axis: .vertical)
                    .lineLimit(4...12)
            }

        case .location:
            Section {
                Picker("Find by", selection: $fields.locationMode) {
                    ForEach(LocationMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                if fields.locationMode == .address {
                    TextField("Address", text: $fields.address, axis: .vertical)
                        .lineLimit(1...3)
                } else {
                    TextField("Latitude (for example 40.7484)", text: $fields.latitude)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude (for example -73.9857)", text: $fields.longitude)
                        .keyboardType(.numbersAndPunctuation)
                }
                TextField("Place name (optional)", text: $fields.placeName)
            } header: {
                Text("Location")
            } footer: {
                Text("Opens in Maps when scanned. Viewing the map needs internet.")
            }

        case .event:
            Section("Event") {
                TextField("Title", text: $fields.eventTitle)
                Toggle("All day", isOn: $fields.eventAllDay)
                DatePicker("Starts", selection: $fields.eventStart,
                           displayedComponents: fields.eventAllDay ? [.date] : [.date, .hourAndMinute])
                DatePicker("Ends", selection: $fields.eventEnd, in: fields.eventStart...,
                           displayedComponents: fields.eventAllDay ? [.date] : [.date, .hourAndMinute])
                TextField("Location (optional)", text: $fields.eventLocation)
                TextField("Notes (optional)", text: $fields.eventNotes, axis: .vertical)
                    .lineLimit(2...6)
            }
        }
    }
}
