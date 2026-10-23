//
//  MakeView.swift
//  Make Forever QR Codes
//
//  Tab 1: pick what kind of code to make. On iPad: 5 tiles per row.
//

import SwiftUI

struct MakeView: View {
    var onSaved: () -> Void = {}
    @State private var showSettings = false
    @State private var showAbout = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var columns: [GridItem] {
        WideLayout.isOn(sizeClass)
            ? Array(repeating: GridItem(.flexible(), spacing: 16), count: 5)
            : [GridItem(.adaptive(minimum: 100), spacing: 12)]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: columns, spacing: WideLayout.isOn(sizeClass) ? 16 : 12) {
                        ForEach(CodeType.allCases) { type in
                            NavigationLink {
                                CodeEditorView(type: type, onSaved: onSaved)
                            } label: {
                                TypeTile(type: type, tall: WideLayout.isOn(sizeClass))
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
    var tall = false

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
        .frame(maxWidth: .infinity, minHeight: tall ? 130 : 100)
        .padding(8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}
