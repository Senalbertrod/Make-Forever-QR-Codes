//
//  CodeDetailView.swift
//  Make Forever QR Codes
//
//  One saved code: show it big, share it, save it, print it, edit it.
//  On iPad sideways: the code on the left and the buttons on the right.
//  On iPad standing up: like iPhone (the code on top, the buttons under it), just bigger.
//

import SwiftUI
import SwiftData

struct CodeDetailView: View {
    @Bindable var code: SavedCode
    /// Code on top with everything under it, even on iPad (My Codes sideways).
    var stacked = false
    /// When set, deleting hands the code to this instead of leaving the screen.
    var onDelete: ((SavedCode) -> Void)? = nil
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var isLandscape = false

    @State private var showFullScreen = false
    @State private var showPrint = false
    @State private var showRename = false
    @State private var newName = ""
    @State private var confirmDelete = false
    @State private var savedToPhotos = false
    @State private var showWatchWarning = false
    @State private var hasWatch = false

    private var image: UIImage? { code.image(size: 1024) }
    /// iPad (standing up, or beside the list): everything a bit bigger.
    private var big: Bool { stacked || WideLayout.isOn(sizeClass) }

    var body: some View {
        ScrollView {
            if WideLayout.isOn(sizeClass) && isLandscape && !stacked {
                // iPad sideways: the code on the left, the buttons on the right
                HStack(alignment: .center, spacing: 40) {
                    VStack(spacing: 20) {
                        codeImage(maxWidth: 460)
                        info
                    }
                    .frame(maxWidth: .infinity)
                    actions
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity)
                }
                .padding(32)
                .frame(maxWidth: .infinity)   // scroll from anywhere, edge to edge
            } else {
                VStack(spacing: 20) {
                    codeImage(maxWidth: big ? 460 : 320)
                    info
                    actions
                        .frame(maxWidth: big ? 560 : .infinity)
                }
                .padding()
                .padding(.vertical, big ? 12 : 0)
                .frame(maxWidth: .infinity)   // scroll from anywhere, edge to edge
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
        .navigationTitle(code.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only when an Apple Watch is paired with this iPhone.
            if hasWatch {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(code.onWatch ? "Remove from Watch" : "Send to Watch",
                           systemImage: code.onWatch ? "applewatch.watchface" : "applewatch") {
                        if !code.onWatch && !code.fitsWatch {
                            showWatchWarning = true   // too big: ask first
                        } else {
                            code.onWatch.toggle()
                        }
                    }
                    .tint(code.onWatch ? .green : .primary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(code.isFavorite ? "Unfavorite" : "Favorite",
                       systemImage: code.isFavorite ? "star.fill" : "star") {
                    code.isFavorite.toggle()
                }
                .tint(.yellow)
            }
        }
        .onAppear { hasWatch = WatchSync.shared.hasWatch }
        .alert("Too big for Apple Watch", isPresented: $showWatchWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Send Anyway") { code.onWatch = true }
        } message: {
            Text("This code has too much information to scan from the watch screen.")
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            FullScreenCodeView(code: code)
        }
        .sheet(isPresented: $showPrint) {
            PrintOptionsView(code: code)
        }
        .alert("Rename", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Save") { if !newName.trimmed.isEmpty { code.name = newName.trimmed } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete this code?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let onDelete {
                    onDelete(code)
                    return
                }
                // Leave the screen first, then delete, so nothing shows a deleted code.
                let context = modelContext
                let toDelete = code
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    context.delete(toDelete)
                }
            }
        } message: {
            Text("Printed or shared copies still work.")
        }
        .alert("Saved to Photos", isPresented: $savedToPhotos) {
            Button("OK", role: .cancel) {}
        }
    }

    private func codeImage(maxWidth: CGFloat) -> some View {
        Button { showFullScreen = true } label: {
            QRCodeImage(payload: code.payload, foreground: code.foreground, background: code.background,
                        icon: code.icon)
                .frame(maxWidth: maxWidth)
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows the code full screen")
    }

    private var info: some View {
        VStack(spacing: 4) {
            Label(code.type.title, systemImage: code.type.symbol)
                .foregroundStyle(.secondary)
            Text("When scanned: \(code.type.scanResult.lowercased()).")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if let image {
                    ShareLink(item: PNGFile(image: image, name: code.name),
                              preview: SharePreview(code.name, image: Image(uiImage: image))) {
                        ActionLabel(title: "Share", symbol: "square.and.arrow.up")
                    }
                    Button {
                        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                        savedToPhotos = true
                    } label: {
                        ActionLabel(title: "Save Image", symbol: "photo.badge.arrow.down")
                    }
                }
                Button { showPrint = true } label: {
                    ActionLabel(title: "Print", symbol: "printer")
                }
            }
            HStack(spacing: 12) {
                if code.canEdit {
                    // (My Codes opens the editor, so it can keep you there when the iPad turns.)
                    NavigationLink(value: CodeRoute.edit(code)) {
                        ActionLabel(title: "Edit", symbol: "pencil")
                    }
                }
                Button {
                    newName = code.name
                    showRename = true
                } label: {
                    ActionLabel(title: "Rename", symbol: "character.cursor.ibeam")
                }
                Button(action: duplicate) {
                    ActionLabel(title: "Duplicate", symbol: "plus.square.on.square")
                }
            }
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Delete", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }

    private func duplicate() {
        let copy = SavedCode(name: code.name + " copy", type: code.type, payload: code.payload,
                             fields: code.fields, foregroundHex: code.foregroundHex,
                             backgroundHex: code.backgroundHex, showIcon: code.showIcon,
                             isScanned: code.isScanned)
        modelContext.insert(copy)
    }
}

private struct ActionLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3)
            Text(title).font(.caption.weight(.medium))
        }
        .frame(maxWidth: .infinity, minHeight: 64)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(.tint)
    }
}
