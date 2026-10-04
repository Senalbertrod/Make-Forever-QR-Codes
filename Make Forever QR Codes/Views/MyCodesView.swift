//
//  MyCodesView.swift
//  Make Forever QR Codes
//
//  Tab 2: every saved code. Favorites first, newest first.
//

import SwiftUI
import SwiftData

struct MyCodesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedCode.createdAt, order: .reverse) private var codes: [SavedCode]
    @State private var search = ""
    @State private var codeToDelete: SavedCode?
    @State private var showWatchWarning = false

    private var shown: [SavedCode] {
        let filtered = search.trimmed.isEmpty ? codes : codes.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.type.title.localizedCaseInsensitiveContains(search)
        }
        return filtered.filter(\.isFavorite) + filtered.filter { !$0.isFavorite }
    }

    var body: some View {
        NavigationStack {
            Group {
                if codes.isEmpty {
                    ContentUnavailableView("No codes yet",
                                           systemImage: "qrcode",
                                           description: Text("Codes you make are saved here."))
                } else {
                    List {
                        ForEach(shown) { code in
                            NavigationLink {
                                CodeDetailView(code: code)
                            } label: {
                                CodeRow(code: code)
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    codeToDelete = code
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button(code.isFavorite ? "Unfavorite" : "Favorite",
                                       systemImage: code.isFavorite ? "star.slash" : "star") {
                                    code.isFavorite.toggle()
                                    if code.isFavorite && code.isDenseForWatch && WatchSync.shared.hasWatch { showWatchWarning = true }
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                    .searchable(text: $search, prompt: "Search codes")
                }
            }
            .navigationTitle("My Codes")
            .alert("This code is long", isPresented: $showWatchWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Favorites also show on your Apple Watch. This code holds a lot of information, so it may be hard to scan from the small watch screen. It works fine from your iPhone.")
            }
            .confirmationDialog("Delete this code?", isPresented: Binding(
                get: { codeToDelete != nil }, set: { if !$0 { codeToDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let codeToDelete { modelContext.delete(codeToDelete) }
                    codeToDelete = nil
                }
            } message: {
                Text("It's removed from this list only. Printed or shared copies keep working.")
            }
        }
    }
}

private struct CodeRow: View {
    let code: SavedCode

    var body: some View {
        HStack(spacing: 14) {
            if let image = code.image(size: 180) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(code.name).font(.headline).lineLimit(1)
                    if code.isFavorite {
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                    }
                }
                Label(code.type.title, systemImage: code.type.symbol)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(code.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
