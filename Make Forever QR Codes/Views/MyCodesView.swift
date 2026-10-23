//
//  MyCodesView.swift
//  Make Forever QR Codes
//
//  Tab 3: every saved code, grouped by type (all Wi-Fi together, all Email
//  together...). Once any code is a favorite, a Favorites part shows on top
//  and the rest go under All Codes. The order of the type groups is chosen
//  with Arrange and applies to both parts. Newest first inside each group.
//
//  On iPad (when there's room):
//  - Favorites and other codes: Favorites on the left, All Codes on the right.
//  - Only favorites, or no favorites: one part using both sides, the kinds
//    side by side in the Arrange order (first kind on the left).
//

import SwiftUI
import SwiftData

struct MyCodesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedCode.createdAt, order: .reverse) private var codes: [SavedCode]
    @AppStorage("typeOrder") private var typeOrderRaw = ""
    @State private var search = ""
    @State private var codeToDelete: SavedCode?
    @State private var showArrange = false
    @Environment(\.horizontalSizeClass) private var sizeClass

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
                } else if WideLayout.isOn(sizeClass) {
                    wideList
                        .searchable(text: $search, prompt: "Search codes")
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
                ArrangeTypesView(orderRaw: $typeOrderRaw, inUse: Set(codes.map(\.type)))
            }
            .alert("Delete this code?", isPresented: Binding(
                get: { codeToDelete != nil }, set: { if !$0 { codeToDelete = nil } }
            ), presenting: codeToDelete) { code in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    withAnimation { modelContext.delete(code) }
                }
            } message: { _ in
                Text("Printed or shared copies still work.")
            }
        }
    }

    // MARK: iPad

    /// The kinds of codes in the Arrange order, each with its codes.
    private struct TypeGroup: Identifiable {
        let type: CodeType
        let codes: [SavedCode]
        var id: CodeType { type }
    }

    private func byType(_ list: [SavedCode]) -> [TypeGroup] {
        typeOrder.compactMap { type in
            let inType = list.filter { $0.type == type }
            return inType.isEmpty ? nil : TypeGroup(type: type, codes: inType)
        }
    }

    @ViewBuilder
    private var wideList: some View {
        let list = filtered
        let favorites = list.filter(\.isFavorite)
        let others = list.filter { !$0.isFavorite }
        if list.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ScrollView {
                Group {
                    if !favorites.isEmpty && !others.isEmpty {
                        // Favorites on the left, All Codes on the right
                        HStack(alignment: .top, spacing: 32) {
                            column("Favorites", favorites)
                            column("All Codes", others)
                        }
                    } else {
                        // One part, using both sides
                        let title = hasFavorites ? (favorites.isEmpty ? "All Codes" : "Favorites") : ""
                        VStack(alignment: .leading, spacing: 12) {
                            if !title.isEmpty { partTitle(title) }
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 32, alignment: .top),
                                                GridItem(.flexible(), spacing: 32, alignment: .top)],
                                      alignment: .leading, spacing: 24) {
                                ForEach(byType(list)) { group in
                                    typeGroup(group.type, group.codes)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    private func column(_ title: String, _ list: [SavedCode]) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            partTitle(title)
            ForEach(byType(list)) { group in
                typeGroup(group.type, group.codes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func partTitle(_ title: String) -> some View {
        Text(title)
            .font(.title2.weight(.bold))
            .padding(.bottom, -12)
    }

    private func typeGroup(_ type: CodeType, _ list: [SavedCode]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(type.title, systemImage: type.symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            ForEach(list) { code in
                card(code)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// One code as a card. Hold it (or right-click) to favorite or delete.
    private func card(_ code: SavedCode) -> some View {
        NavigationLink {
            CodeDetailView(code: code)
        } label: {
            HStack {
                CodeRow(code: code)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(code.isFavorite ? "Unfavorite" : "Favorite",
                   systemImage: code.isFavorite ? "star.slash" : "star") {
                withAnimation { code.isFavorite.toggle() }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                codeToDelete = code
            }
        }
    }

    // MARK: iPhone

    private func row(_ code: SavedCode) -> some View {
        NavigationLink {
            CodeDetailView(code: code)
        } label: {
            CodeRow(code: code)
        }
        .swipeActions(edge: .trailing) {
            // Not marked destructive, so the row stays put until the person confirms.
            Button("Delete", systemImage: "trash") {
                codeToDelete = code
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading) {
            Button(code.isFavorite ? "Unfavorite" : "Favorite",
                   systemImage: code.isFavorite ? "star.slash" : "star") {
                code.isFavorite.toggle()
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

/// Drag the kinds of codes into the order you want. Only kinds you have
/// codes for are listed; the others keep their place for later.
private struct ArrangeTypesView: View {
    @Binding var orderRaw: String
    let inUse: Set<CodeType>
    @Environment(\.dismiss) private var dismiss
    @State private var order: [CodeType] = []

    private var shown: [CodeType] { order.filter { inUse.contains($0) } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(shown) { type in
                        Label(type.title, systemImage: type.symbol)
                    }
                    .onMove { from, to in
                        var moved = shown
                        moved.move(fromOffsets: from, toOffset: to)
                        // Put the moved kinds back into the spots the shown kinds had.
                        var next = moved.makeIterator()
                        order = order.map { inUse.contains($0) ? (next.next() ?? $0) : $0 }
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
                    if code.onWatch {
                        Image(systemName: "applewatch").font(.caption).foregroundStyle(.green)
                            .accessibilityLabel("On Apple Watch")
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
