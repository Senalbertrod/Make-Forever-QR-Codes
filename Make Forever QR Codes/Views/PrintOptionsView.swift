//
//  PrintOptionsView.swift
//  Make Forever QR Codes
//
//  Choose a layout and size, see a preview, then print or save a PDF.
//

import SwiftUI

struct PrintOptionsView: View {
    let code: SavedCode
    @Environment(\.dismiss) private var dismiss

    @State private var layout: PrintLayout = .single
    @State private var size: PrintSize = .large
    @State private var caption = ""
    /// The page, made again only when a choice changes (not on every redraw).
    @State private var pdf = Data()

    private func makePDF() {
        pdf = PrintService.pdf(for: code, layout: layout, size: size, caption: caption.trimmed)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Layout") {
                    Picker("Layout", selection: $layout) {
                        ForEach(PrintLayout.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                Section("Code size") {
                    Picker("Size", selection: $size) {
                        ForEach(PrintSize.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
                if layout != .single {
                    Section {
                        TextField(layout == .captioned ? "For example \"Scan for our menu\"" : "Label under each code",
                                  text: $caption)
                    } header: {
                        Text("Caption")
                    } footer: {
                        Text(layout == .captioned
                             ? "Shown under the code's name."
                             : "Leave empty to use the code's name.")
                    }
                }
                Section {
                    PagePreview(pdf: pdf)
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Preview")
                }
                Section {
                    Button("Print…", systemImage: "printer") {
                        // The print screen opens on top of this one. Close this only
                        // after printing; Cancel comes back here to change something.
                        PrintService.print(pdf: pdf, jobName: code.name) { printed in
                            if printed { dismiss() }
                        }
                    }
                    ShareLink(item: PDFFile(data: pdf, name: code.name),
                              preview: SharePreview(code.name + ".pdf")) {
                        Label("Save or share as PDF", systemImage: "doc.richtext")
                    }
                } footer: {
                    Text("The printer screen lets you pick the printer and the number of copies. A PDF is handy for print shops.")
                }
            }
            .onChange(of: "\(layout.rawValue)|\(size.rawValue)|\(caption.trimmed)", initial: true) {
                makePDF()
            }
            .navigationTitle("Print")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

/// Draws page 1 of the PDF as a small paper preview.
private struct PagePreview: View {
    let pdf: Data

    var body: some View {
        if let image = render() {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(PrintService.page.width / PrintService.page.height, contentMode: .fit)
                .border(Color.gray.opacity(0.4))
                .shadow(radius: 3)
        }
    }

    private func render() -> UIImage? {
        guard let provider = CGDataProvider(data: pdf as CFData),
              let document = CGPDFDocument(provider),
              let page = document.page(at: 1) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: box.width * scale, height: box.height * scale))
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: box.width * scale, height: box.height * scale)))
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: box.height * scale)
            cg.scaleBy(x: scale, y: -scale)
            cg.drawPDFPage(page)
        }
    }
}
