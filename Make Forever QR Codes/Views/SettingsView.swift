//
//  SettingsView.swift
//  Make Forever QR Codes
//
//  How it works and privacy. (The iCloud switch comes in a later step.)
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("How it works") {
                    InfoRow(symbol: "infinity", title: "Codes never expire",
                            text: "The information is saved on your device. No server sits in between, so nobody can switch your code off.")
                    InfoRow(symbol: "printer", title: "Print it, it's yours",
                            text: "Printed codes keep working forever. To stop using one, throw away the paper.")
                    InfoRow(symbol: "trash", title: "Deleting",
                            text: "Deleting a code only removes it from My Codes. Printed or shared copies keep working.")
                    InfoRow(symbol: "link", title: "Links",
                            text: "A link code works as long as the website exists. Every other kind works with no internet at all.")
                    InfoRow(symbol: "pencil.slash", title: "Printed codes can't change",
                            text: "Printed a code with the wrong information? Fix it in the app and print it again.")
                }
                Section("Privacy") {
                    InfoRow(symbol: "lock.shield", title: "Nothing leaves your phone",
                            text: "No account, no ads, no tracking. Your codes are saved only on this device.")
                }
                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct InfoRow: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
