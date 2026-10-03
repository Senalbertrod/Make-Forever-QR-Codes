//
//  QRCodeImage.swift
//  Make Forever QR Codes
//
//  Shows a QR code sharply at any size.
//

import SwiftUI

struct QRCodeImage: View {
    let payload: String?
    var foreground: UIColor = .black
    var background: UIColor = .white
    var pixelSize: CGFloat = 1024

    var body: some View {
        if let payload, let image = QRRenderer.image(for: payload, size: pixelSize,
                                                     foreground: foreground, background: background) {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .accessibilityLabel("QR code")
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 44))
                        Text(payload == nil ? "Fill in the form to see your code" : "Too much text for one code")
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.secondary)
                    .padding()
                }
        }
    }
}
