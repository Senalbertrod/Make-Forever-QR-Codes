//
//  SettingsView.swift
//  Make Forever QR Codes
//
//  How it works, scanning and privacy. (The iCloud switch comes in a later step.)
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
                Section("Scanning") {
                    InfoRow(symbol: "qrcode.viewfinder", title: "Scanned on your phone",
                            text: "The Scan tab reads codes with the camera or from a photo, right on your iPhone. Nothing is saved unless you tap Save.")
                    InfoRow(symbol: "exclamationmark.shield", title: "Safety checks",
                            text: "Before anything opens, the app checks links for common scam tricks, like look-alike letters, hidden addresses and short links. It can't know every bad website, so only open links you trust.")
                }
                Section("Privacy") {
                    InfoRow(symbol: "lock.shield", title: "Nothing leaves your phone",
                            text: "No account, no ads, no tracking. The camera is only used to read codes, and nothing it sees is saved or sent. Your codes are saved only on this device.")
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
