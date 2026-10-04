//
//  SavedCode.swift
//  Make Forever QR Codes
//
//  A code in "My Codes". Stored only on this device (SwiftData).
//  Every property has a default so iCloud sync can be added later.
//

import Foundation
import SwiftData
import UIKit

@Model
final class SavedCode {
    var id: UUID = UUID()
    var name: String = ""
    var typeRaw: String = CodeType.link.rawValue
    var payload: String = ""
    var fieldsData: Data = Data()
    var foregroundHex: String = "#000000"
    var backgroundHex: String = "#FFFFFF"
    var isFavorite: Bool = false
    var createdAt: Date = Date()

    init(name: String, type: CodeType, payload: String, fields: CodeFields,
         foregroundHex: String = "#000000", backgroundHex: String = "#FFFFFF") {
        self.name = name
        self.typeRaw = type.rawValue
        self.payload = payload
        self.fieldsData = fields.encoded()
        self.foregroundHex = foregroundHex
        self.backgroundHex = backgroundHex
        self.createdAt = Date()
    }

    var type: CodeType { CodeType(rawValue: typeRaw) ?? .text }
    var fields: CodeFields { CodeFields.decoded(from: fieldsData) }
    var foreground: UIColor { UIColor(hex: foregroundHex) ?? .black }
    var background: UIColor { UIColor(hex: backgroundHex) ?? .white }

    /// Long codes have tiny squares that are hard to scan from a watch screen.
    var isDenseForWatch: Bool { Data(payload.utf8).count > QRRenderer.denseBytes }

    func image(size: CGFloat) -> UIImage? {
        QRRenderer.image(for: payload, size: size, foreground: foreground, background: background)
    }
}
