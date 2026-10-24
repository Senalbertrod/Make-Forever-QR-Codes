//
//  MyCodesView.swift
//  Make Forever QR Codes
//
//  Tab 3: every saved code, grouped by type (all Wi-Fi together, all Email
//  together...). Once any code is a favorite, a Favorites part shows on top
//  and the rest go under All Codes. The order of the type groups is chosen
//  with Arrange and applies to both parts. Newest first inside each group.
//
//  One screen that changes shape by itself (Apple's split view):
//  - Narrow (iPhone, iPhone Duo closed, iPad standing up): one column. Tap a
//    code and it opens on top of the list.
//  - Wide and sideways (iPad sideways, Duo open), or the Duo half-closed:
//    the list on the left, the code you pick big on the right.
//  Because it's always the same screen, opening, closing or turning the device
//  keeps your place: the code you had open, and Edit with what you typed.
//

import SwiftUI
import SwiftData

/// Screens My Codes can open on top of a saved code: its editor.
enum CodeRoute: Hashable {
    case detail(SavedCode)
    case edit(SavedCode)

    var code: SavedCode {
        switch self {
        case .detail(let code), .edit(let code): code
        }
    }
}

/// What's typed on an open Edit screen, kept while the device turns or folds.
private final class EditDrafts {
    private var drafts: [PersistentIdentifier: EditDraft] = [:]

    func draft(for code: SavedCode) -> EditDraft {
        if let draft = drafts[code.persistentModelID] { return draft }
        let draft = EditDraft()
        drafts[code.persistentModelID] = draft
        return draft
    }

    /// Forgets drafts for Edit screens that are closed.
    func keepOnly(_ open: Set<PersistentIdentifier>) {
        drafts = drafts.filter { open.contains($0.key) }
    }
}

struct MyCodesView: View {
    @Environment(\.modelContext) private var modelContext
    /// The screen's shape and the Duo's fold, decided once for the whole app.
    @Environment(\.screenLayout) private var layout
    @Query(sort: \SavedCode.createdAt, order: .reverse) private var codes: [SavedCode]
    @AppStorage("typeOrder") private var typeOrderRaw = ""
    @State private var search = ""
    @State private var codeToDelete: SavedCode?
    @State private var showArrange = false

    /// The code you picked (nil: none, the list shows on its own when narrow).
    @State private var selection: PersistentIdentifier?
    /// What's open on top of that code: its Edit screen, or nothing.
    @State private var detailPath: [CodeRoute] = []
    @State private var drafts = EditDrafts()
    /// Codes on their way out (hidden first, then deleted, so nothing shows a deleted code).
    @State private var removing: Set<PersistentIdentifier> = []

    /// Two sides (list and code), or one column.
    private var sideBySide: Bool { layout.sideBySide }
    private var bigRows: Bool { layout.isWide }
    /// iPhone Duo half-closed: the list and the code each get a page.
    private var fold: Fold? { layout.fold }

    /// The code you picked (nil if none, or it's being deleted).
    private var pickedCode: SavedCode? {
        guard let selection, !removing.contains(selection) else { return nil }
        return codes.first { $0.persistentModelID == selection }
    }

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

    /// The code on the right: the one you picked, or else (side by side, so the
    /// right isn't empty) the first one in the list, your first favorite if any.
    private var shownCode: SavedCode? {
        pickedCode ?? (sideBySide ? groups.first?.codes.first : nil)
    }

    /// Side by side with nothing picked: the code to pick (the first in the list).
    private var autoPick: PersistentIdentifier? {
        guard sideBySide, pickedCode == nil else { return nil }
        return groups.first?.codes.first?.persistentModelID
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            Group {
                if let fold {
                    // Half-closed: the list fills the left page, up to the middle of the fold.
                    codeList
                        .safeAreaPadding(.trailing, fold.gap / 2)
                        .navigationSplitViewColumnWidth(fold.center)
                } else {
                    codeList
                        .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 460)
                }
            }
            .toolbar(removing: .sidebarToggle)
        } detail: {
            // Narrow with no code picked: nothing here, so the list shows.
            // (Side by side, or once a code is picked, it's the same screen
            // the whole time, so closing or turning keeps your place.)
            if sideBySide || selection != nil {
                NavigationStack(path: $detailPath) {
                    Group {
                        if let code = shownCode {
                            CodeDetailView(code: code, stacked: sideBySide, onDelete: remove)
                                .id(code.persistentModelID)
                        } else {
                            ContentUnavailableView("Pick a code", systemImage: "qrcode",
                                                   description: Text("It shows here, big enough to scan."))
                        }
                    }
                    .navigationDestination(for: CodeRoute.self) { route in
                        CodeEditorView(type: route.code.type, existing: route.code, inColumn: sideBySide,
                                       draft: drafts.draft(for: route.code))
                    }
                    // Half-closed: the code starts after the fold, on the right page.
                    .safeAreaPadding(.leading, (fold?.gap ?? 0) / 2)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        // The split view changes shape by itself: two sides when there's room,
        // one column otherwise. (It's always the same screen, so nothing is lost.)
        .environment(\.horizontalSizeClass, sideBySide ? .regular : .compact)
        // (Narrow: Apple's split view shows the list when no code is picked, and
        // the code on top of it when one is. Back un-picks it.)
        // Side by side, the code showing on the right counts as picked (even
        // your first favorite, shown on its own), so closing the phone or
        // turning the iPad opens that code instead of the list.
        .onChange(of: autoPick, initial: true) {
            if let autoPick { selection = autoPick }
        }
        .onChange(of: selection) { old, new in
            // Picking another code (or going back to the list) closes the Edit
            // screen of the old one.
            if old != nil, old != new { detailPath = [] }
        }
        .onChange(of: detailPath) {
            // Editing the code shown on its own (side by side, nothing picked):
            // count it as picked, so closing the phone stays on it.
            if !detailPath.isEmpty, selection == nil {
                selection = shownCode?.persistentModelID
            }
            // A closed Edit screen forgets what was typed in it.
            var open = Set<PersistentIdentifier>()
            for route in detailPath { open.insert(route.code.persistentModelID) }
            drafts.keepOnly(open)
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
            if selection == id || shownCode == nil || selection == nil {
                detailPath = []
            }
            if selection == id { selection = nil }
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
                // Side by side, the code on the right is highlighted.
                List(selection: Binding(get: { selection ?? (sideBySide ? shownCode?.persistentModelID : nil) },
                                        set: { selection = $0 })) {
                    sections
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

    private func row(_ code: SavedCode) -> some View {
        NavigationLink(value: code.persistentModelID) {
            CodeRow(code: code, big: bigRows)
        }
        .modifier(RowActions(code: code, codeToDelete: $codeToDelete))
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
