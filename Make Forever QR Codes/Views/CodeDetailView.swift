//
//  CodeDetailView.swift
//  Make Forever QR Codes
//
//  One saved code: show it big, share it, save it, print it, edit it.
//

import SwiftUI
import SwiftData

struct CodeDetailView: View {
    @Bindable var code: SavedCode
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showFullScreen = false
    @State private var showPrint = false
    @State private var showRename = false
    @State private var newName = ""
    @State private var confirmDelete = false
    @State private var savedToPhotos = false
    @State private var showWatchWarning = false

    private var image: UIImage? { code.image(size: 1024) }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Button { showFullScreen = true } label: {
                    QRCodeImage(payload: code.payload, foreground: code.foreground, background: code.background,
                                icon: code.icon)
                        .frame(maxWidth: 320)
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows the code full screen")

                VStack(spacing: 4) {
                    Label(code.type.title, systemImage: code.type.symbol)
                        .foregroundStyle(.secondary)
                    Text("When scanned: \(code.type.scanResult.lowercased()).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                actions
            }
            .padding()
        }
        .navigationTitle(code.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(code.isFavorite ? "Unfavorite" : "Favorite",
                       systemImage: code.isFavorite ? "star.fill" : "star") {
                    code.isFavorite.toggle()
                    if code.isFavorite && code.isDenseForWatch && WatchSync.shared.hasWatch { showWatchWarning = true }
                }
                .tint(.yellow)
            }
        }
        .alert("This code is long", isPresented: $showWatchWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Favorites also show on your Apple Watch. This code holds a lot of information, so it may be hard to scan from the small watch screen. It works fine from your iPhone.")
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
                // Leave the screen first, then delete, so nothing shows a deleted code.
                let context = modelContext
                let toDelete = code
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    context.delete(toDelete)
                }
            }
        }
        .alert("Saved to Photos", isPresented: $savedToPhotos) {
            Button("OK", role: .cancel) {}
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
                    NavigationLink {
                        CodeEditorView(type: code.type, existing: code)
                    } label: {
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

            Text(code.canEdit
                 ? "Editing changes this saved code. Copies you already printed or shared stay the same."
                 : "This code was saved from a scan exactly as it was, so it can be renamed but not edited.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
