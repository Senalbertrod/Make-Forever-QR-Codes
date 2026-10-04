//
//  FullScreenCodeView.swift
//  Make Forever QR Codes
//
//  The code as big as possible on white, for someone to scan. Tap to close.
//

import SwiftUI

struct FullScreenCodeView: View {
    let code: SavedCode
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                QRCodeImage(payload: code.payload, foreground: code.foreground, background: code.background,
                            icon: code.icon)
                    .padding(24)
                Text(code.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.black)
                Spacer()
                Text("Tap anywhere to close · Turn up brightness for easier scanning")
                    .font(.footnote)
                    .foregroundStyle(.gray)
                    .padding(.bottom)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .statusBarHidden()
    }
}
