//
//  MyCodesView.swift
//  Make Forever QR Codes
//
//  Tab 3: every saved code, grouped by type (all Wi-Fi together, all Email
//  together...). Once any code is a favorite, a Favorites part shows on top
//  and the rest go under All Codes. The order of the type groups is chosen
//  with Arrange and applies to both parts. Newest first inside each group.
//

import SwiftUI
import SwiftData

struct MyCodesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedCode.createdAt, order: .reverse) private var codes: [SavedCode]
    @AppStorage("typeOrder") private var typeOrderRaw = ""
    @State private var search = ""
    @State private var codeToDelete: SavedCode?
    @State private var showWatchWarning = false
    @State private var showArrange = false

    private var filtered: [SavedCode] {
        search.trimmed.isEmpty ? codes : codes.filter {
            $0.name.localizedCaseInsensitiveContains(search) || $0.type.title.localizedCaseInsensitiveContains(search)
        }
    }

    /// The type groups in the order the person chose.
    private var typeOrder: [CodeType] { TypeOrder.decode(typeOrderRaw) }

    private struct CodeGroup: Identifiable {
        let part: String
        let type: CodeType
        let codes: [SavedCode]
        let isFirstInPart: Bool
        var id: String { part + type.rawValue }
    }

    private var hasFavorites: Bool { codes.contains(where: \.isFavorite) }

    private var groups: [CodeGroup] {
        let list = filtered
        var parts: [(String, [SavedCode])] = []
        if hasFavorites {
            parts.append(("Favorites", list.filter(\.isFavorite)))
            parts.append(("All Codes", list.filter { !$0.isFavorite }))
        } else {
            parts.append(("", list))
        }
        var result: [CodeGroup] = []
        for (part, partCodes) in parts {
            var first = true
            for type in typeOrder {
                let inType = partCodes.filter { $0.type == type }
                guard !inType.isEmpty else { continue }
                result.append(CodeGroup(part: part, type: type, codes: inType, isFirstInPart: first))
                first = false
            }
        }
        return result
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
                        ForEach(groups) { group in
                            Section {
                                ForEach(group.codes) { code in
                                    row(code)
                                }
                            } header: {
                                VStack(alignment: .leading, spacing: 6) {
                                    if group.isFirstInPart && !group.part.isEmpty {
                                        Text(group.part)
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(.primary)
                                            .textCase(nil)
                                            .padding(.top, 8)
                                    }
                                    Label(group.type.title, systemImage: group.type.symbol)
                                }
                            }
                        }
                    }
                    .searchable(text: $search, prompt: "Search codes")
                }
            }
            .navigationTitle("My Codes")
            .toolbar {
                if !codes.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Arrange", systemImage: "arrow.up.arrow.down") { showArrange = true }
                    }
                }
            }
            .sheet(isPresented: $showArrange) {
                ArrangeTypesView(orderRaw: $typeOrderRaw)
            }
            .alert("This code is long", isPresented: $showWatchWarning) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Favorites also show on your Apple Watch. This code holds a lot of information, so it may be hard to scan from the small watch screen. It works fine from your iPhone.")
            }
            .alert("Delete this code?", isPresented: Binding(
                get: { codeToDelete != nil }, set: { if !$0 { codeToDelete = nil } }
            ), presenting: codeToDelete) { code in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(code)
                }
            }
        }
    }

    private func row(_ code: SavedCode) -> some View {
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

/// The saved order of the type groups, as "wifi,link,email...".
/// Types not in the saved order (new ones) go at the end.
enum TypeOrder {
    static func decode(_ raw: String) -> [CodeType] {
        var order = raw.split(separator: ",").compactMap { CodeType(rawValue: String($0)) }
        for type in CodeType.allCases where !order.contains(type) { order.append(type) }
        return order
    }

    static func encode(_ order: [CodeType]) -> String {
        order.map(\.rawValue).joined(separator: ",")
    }
}

/// Drag the kinds of codes into the order you want.
private struct ArrangeTypesView: View {
    @Binding var orderRaw: String
    @Environment(\.dismiss) private var dismiss
    @State private var order: [CodeType] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(order) { type in
                        Label(type.title, systemImage: type.symbol)
                    }
                    .onMove { from, to in
                        order.move(fromOffsets: from, toOffset: to)
                        orderRaw = TypeOrder.encode(order)
                    }
                } footer: {
                    Text("Drag a kind of code up or down. All its codes move with it, in Favorites and in All Codes.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Arrange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { order = TypeOrder.decode(orderRaw) }
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
