//
//  QRRenderer.swift
//  Make Forever QR Codes
//
//  Makes the QR code picture on the device with Apple's built-in generator.
//  No internet, no server: the information lives inside the squares.
//

import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// The squares of a QR code: `size` x `size`, true = dark square.
struct QRMatrix {
    let size: Int
    let dark: [Bool]

    func isDark(row: Int, column: Int) -> Bool { dark[row * size + column] }
}

enum QRRenderer {
    /// The most bytes a code can hold with the error correction we use ("M").
    static let maxBytes = 2331
    /// Above this, codes get dense and harder to scan from a watch screen.
    static let denseBytes = 300

    private static let context = CIContext()

    static func matrix(for payload: String) -> QRMatrix? {
        let data = Data(payload.utf8)
        guard !data.isEmpty, data.count <= maxBytes else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage,
              let cg = context.createCGImage(output, from: output.extent) else { return nil }

        // Read one pixel per square.
        let width = cg.width, height = cg.height
        guard width == height, width > 0 else { return nil }
        var pixels = [UInt8](repeating: 255, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        return QRMatrix(size: width, dark: pixels.map { $0 < 128 })
    }

    /// A square picture of the code with a white (or chosen) border around it.
    static func image(for payload: String, size: CGFloat,
                      foreground: UIColor = .black, background: UIColor = .white,
                      quietZone: Int = 3) -> UIImage? {
        guard let m = matrix(for: payload) else { return nil }
        let total = CGFloat(m.size + quietZone * 2)
        let module = size / total

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        return renderer.image { ctx in
            background.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
            foreground.setFill()
            for row in 0..<m.size {
                for column in 0..<m.size where m.isDark(row: row, column: column) {
                    let x = (CGFloat(column + quietZone) * module).rounded(.down)
                    let y = (CGFloat(row + quietZone) * module).rounded(.down)
                    let x2 = (CGFloat(column + quietZone + 1) * module).rounded(.down)
                    let y2 = (CGFloat(row + quietZone + 1) * module).rounded(.down)
                    ctx.fill(CGRect(x: x, y: y, width: x2 - x, height: y2 - y))
                }
            }
        }
    }

    // MARK: - Color checks

    /// Contrast ratio between two colors (1 = none, 21 = black on white).
    static func contrast(_ a: UIColor, _ b: UIColor) -> CGFloat {
        let la = a.luminance, lb = b.luminance
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// A warning to show under the color pickers, or nil if the colors are fine.
    static func colorWarning(foreground: UIColor, background: UIColor) -> String? {
        if contrast(foreground, background) < 3 {
            return "These colors are too similar. Some phones won't be able to scan this code."
        }
        if foreground.luminance > background.luminance {
            return "Light squares on a dark background can't be read by some scanners. Dark on light is safest."
        }
        return nil
    }
}

extension UIColor {
    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}
