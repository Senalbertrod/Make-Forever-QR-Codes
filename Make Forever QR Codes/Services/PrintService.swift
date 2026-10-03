//
//  PrintService.swift
//  Make Forever QR Codes
//
//  Lays codes out on a page (as a PDF) and sends it to the printer with
//  Apple's built-in printing. The same PDF can be shared for print shops.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum PrintLayout: String, CaseIterable, Identifiable {
    case single, captioned, sheet
    var id: String { rawValue }
    var title: String {
        switch self {
        case .single: "One large code"
        case .captioned: "Code with a caption"
        case .sheet: "Sheet of small codes"
        }
    }
}

enum PrintSize: String, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: "Small (2 in / 5 cm)"
        case .medium: "Medium (4 in / 10 cm)"
        case .large: "Large (7 in / 18 cm)"
        }
    }
    /// Width of the code on paper, in points (72 per inch).
    var points: CGFloat {
        switch self {
        case .small: 144
        case .medium: 288
        case .large: 504
        }
    }
}

enum PrintService {
    /// US Letter. Works on A4 too: everything is centered with wide margins.
    static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 36

    static func pdf(for code: SavedCode, layout: PrintLayout, size: PrintSize, caption: String) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let side = min(size.points, page.width - margin * 2)
            guard let image = code.image(size: 1200) else { return }

            switch layout {
            case .single:
                let rect = CGRect(x: (page.width - side) / 2, y: (page.height - side) / 2, width: side, height: side)
                image.draw(in: rect)

            case .captioned:
                let nameFont = UIFont.systemFont(ofSize: 28, weight: .bold)
                let captionFont = UIFont.systemFont(ofSize: 18)
                let blockHeight = side + 20 + nameFont.lineHeight + (caption.isEmpty ? 0 : 8 + captionFont.lineHeight)
                var y = (page.height - blockHeight) / 2
                image.draw(in: CGRect(x: (page.width - side) / 2, y: y, width: side, height: side))
                y += side + 20
                drawCentered(code.name, font: nameFont, y: y)
                y += nameFont.lineHeight + 8
                if !caption.isEmpty { drawCentered(caption, font: captionFont, y: y, color: .darkGray) }

            case .sheet:
                let labelFont = UIFont.systemFont(ofSize: 9)
                let gap: CGFloat = 18
                let cellHeight = side + 4 + labelFont.lineHeight
                let usableWidth = page.width - margin * 2
                let usableHeight = page.height - margin * 2
                let columns = max(1, Int((usableWidth + gap) / (side + gap)))
                let rows = max(1, Int((usableHeight + gap) / (cellHeight + gap)))
                let gridWidth = CGFloat(columns) * side + CGFloat(columns - 1) * gap
                let gridHeight = CGFloat(rows) * cellHeight + CGFloat(rows - 1) * gap
                let startX = (page.width - gridWidth) / 2
                let startY = (page.height - gridHeight) / 2
                for row in 0..<rows {
                    for column in 0..<columns {
                        let x = startX + CGFloat(column) * (side + gap)
                        let y = startY + CGFloat(row) * (cellHeight + gap)
                        image.draw(in: CGRect(x: x, y: y, width: side, height: side))
                        let label = caption.isEmpty ? code.name : caption
                        drawCentered(label, font: labelFont, y: y + side + 4,
                                     in: CGRect(x: x, y: 0, width: side, height: 0), color: .darkGray)
                    }
                }
            }
        }
    }

    private static func drawCentered(_ text: String, font: UIFont, y: CGFloat,
                                     in area: CGRect? = nil, color: UIColor = .black) {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let x = area?.minX ?? margin
        let width = area?.width ?? (page.width - margin * 2)
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: font.lineHeight + 2),
                                withAttributes: attributes)
    }

    /// Opens Apple's print screen (printer, copies, preview).
    static func print(pdf: Data, jobName: String) {
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo(dictionary: nil)
        info.outputType = .general
        info.jobName = jobName
        controller.printInfo = info
        controller.printingItem = pdf
        controller.present(animated: true, completionHandler: nil)
    }
}

/// A PDF that can be shared or saved to Files (for print shops).
nonisolated struct PDFFile: Transferable {
    let data: Data
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0.data }
            .suggestedFileName { $0.name + ".pdf" }
    }
}

/// The code picture as a PNG for sharing.
nonisolated struct PNGFile: Transferable {
    let image: UIImage
    let name: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.image.pngData() ?? Data() }
            .suggestedFileName { $0.name + ".png" }
    }
}
