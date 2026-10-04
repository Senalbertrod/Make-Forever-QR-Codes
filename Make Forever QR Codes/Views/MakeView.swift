//
//  MakeView.swift
//  Make Forever QR Codes
//
//  Tab 1: pick what kind of code to make.
//

import SwiftUI

struct MakeView: View {
    var onSaved: () -> Void = {}
    @State private var showSettings = false
    @State private var showAbout = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Codes that never expire. Nothing is uploaded.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CodeType.allCases) { type in
                            NavigationLink {
                                CodeEditorView(type: type, onSaved: onSaved)
                            } label: {
                                TypeTile(type: type)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Make a Code")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("About", systemImage: "info.circle") { showAbout = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAbout) { AboutView() }
        }
    }
}

private struct TypeTile: View {
    let type: CodeType

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: type.symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.tint)
                .frame(height: 34)
            Text(type.title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
