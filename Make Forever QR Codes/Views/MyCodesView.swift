//
//  MyCodesView.swift
//  Make Forever QR Codes
//
//  Tab 3: every saved code, grouped by type (all Wi-Fi together, all Email
//  together...). Once any code is a favorite, a Favorites part shows on top
//  and the rest go under All Codes. The order of the type groups is chosen
//  with Arrange and applies to both parts. Newest first inside each group.
//
//  iPad standing up: the same list as iPhone, filling the screen.
//  iPad sideways: the list on the left; the code you pick shows big on the
//  right (ready to be scanned), with its details and buttons under it.
//

import SwiftUI
import SwiftData

struct MyCodesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \SavedCode.createdAt, order: .reverse) private var codes: [SavedCode]
    @AppStorage("typeOrder") private var typeOrderRaw = ""
    @State private var search = ""
    @State private var codeToDelete: SavedCode?
    @State private var showArrange = false

    /// Wider than tall (iPad sideways, or a big window).
    @State private var isLandscape = false
    /// The code open in the list (standing up) ...
    @State private var path: [SavedCode] = []
    /// ... or picked on the left (sideways). Kept when the iPad turns.
    @State private var picked: PersistentIdentifier?
    /// Codes on their way out (hidden first, then deleted, so nothing shows a deleted code).
    @State private var removing: Set<PersistentIdentifier> = []

    private var sideBySide: Bool { WideLayout.isOn(sizeClass) && isLandscape }
    private var bigRows: Bool { WideLayout.isOn(sizeClass) }

    private var filtered: [SavedCode] {
        let codes = self.codes.filter { !removing.contains($0.persistentModelID) }
        return search.trimmed.isEmpty ? codes : codes.filter {
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

    /// Sideways: the code shown on the right. The one you picked, or else
    /// the first one in the list (your first favorite, if you have any).
    private var shownCode: SavedCode? {
        if let picked, !removing.contains(picked),
           let code = codes.first(where: { $0.persistentModelID == picked }) {
            return code
        }
        return groups.first?.codes.first
    }

    var body: some View {
        Group {
            if sideBySide {
                NavigationSplitView(columnVisibility: .constant(.all)) {
                    codeList
                        .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 460)
                        .toolbar(removing: .sidebarToggle)
                } detail: {
                    NavigationStack {
                        if let code = shownCode {
                            CodeDetailView(code: code, stacked: true, onDelete: remove)
                                .id(code.persistentModelID)
                        } else {
                            ContentUnavailableView("Pick a code", systemImage: "qrcode",
                                                   description: Text("It shows here, big enough to scan."))
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack(path: $path) {
                    codeList
                        .navigationDestination(for: SavedCode.self) { code in
                            CodeDetailView(code: code)
                        }
                }
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
        // Turning the iPad keeps the code you had open.
        .onChange(of: sideBySide) { _, nowSideBySide in
            if nowSideBySide {
                if let open = path.first { picked = open.persistentModelID }
                path = []
            } else if let picked, let code = codes.first(where: { $0.persistentModelID == picked }) {
                path = [code]
            }
        }
        .sheet(isPresented: $showArrange) {
            ArrangeTypesView(orderRaw: $typeOrderRaw, inUse: Set(codes.map(\.type)))
        }
        .alert("Delete this code?", isPresented: Binding(
            get: { codeToDelete != nil }, set: { if !$0 { codeToDelete = nil } }
        ), presenting: codeToDelete) { code in
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { remove(code) }
        } message: { _ in
            Text("Printed or shared copies still work.")
        }
    }

    /// Stops showing a code, then deletes it.
    private func remove(_ code: SavedCode) {
        let id = code.persistentModelID
        withAnimation {
            removing.insert(id)
            if picked == id { picked = nil }
            path.removeAll { $0 == code }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            modelContext.delete(code)
            removing.remove(id)
        }
    }

    @ViewBuilder
    private var sections: some View {
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

    @ViewBuilder
    private var codeList: some View {
        Group {
            if codes.isEmpty {
                ContentUnavailableView("No codes yet",
                                       systemImage: "qrcode",
                                       description: Text("Codes you make are saved here."))
            } else {
                Group {
                    if sideBySide {
                        // Sideways: the picked code is highlighted and shows on the right.
                        List(selection: Binding(get: { shownCode?.persistentModelID },
                                                set: { picked = $0 })) {
                            sections
                        }
                    } else {
                        List { sections }
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
    }

    @ViewBuilder
    private func row(_ code: SavedCode) -> some View {
        if sideBySide {
            // Sideways: tapping shows the code on the right.
            CodeRow(code: code, big: bigRows)
                .tag(code.persistentModelID)
                .modifier(RowActions(code: code, codeToDelete: $codeToDelete))
        } else {
            NavigationLink(value: code) {
                CodeRow(code: code, big: bigRows)
            }
            .modifier(RowActions(code: code, codeToDelete: $codeToDelete))
        }
    }
}

/// Swipe (or hold) a code to favorite or delete it.
private struct RowActions: ViewModifier {
    let code: SavedCode
    @Binding var codeToDelete: SavedCode?

    func body(content: Content) -> some View {
        content
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
            .contextMenu {
                Button(code.isFavorite ? "Unfavorite" : "Favorite",
                       systemImage: code.isFavorite ? "star.slash" : "star") {
                    code.isFavorite.toggle()
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    codeToDelete = code
                }
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
    /// Bigger code pictures (iPad).
    var big = false

    var body: some View {
        HStack(spacing: 14) {
            if let image = code.image(size: big ? 240 : 180) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: big ? 76 : 52, height: big ? 76 : 52)
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
        .padding(.vertical, big ? 8 : 4)
    }
}
