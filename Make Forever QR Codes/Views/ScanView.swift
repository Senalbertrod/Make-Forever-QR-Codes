//
//  ScanView.swift
//  Make Forever QR Codes
//
//  Tab 2: scan a code with the camera or from a photo. Uses Apple's
//  on-device scanner; nothing the camera sees is saved or sent.
//  On iPad sideways: the camera is big in the middle. When a code is found,
//  the camera slides to the left and the result shows on the right.
//  On iPad standing up: like iPhone (the result slides up from the bottom).
//

import AVFoundation
import PhotosUI
import SwiftUI
import Vision
import VisionKit

struct ScanView: View {
    @State private var result: ScannedCode?
    @State private var isVisible = false
    @State private var paused = false
    @State private var cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var photoItem: PhotosPickerItem?
    @State private var noCodeInPhoto = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var isLandscape = false

    private var wide: Bool { WideLayout.isOn(sizeClass) && isLandscape }

    var body: some View {
        NavigationStack {
            Group {
                if wide { wideScan } else { phoneScan }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            isVisible = true
            if cameraStatus == .notDetermined {
                Task {
                    _ = await AVCaptureDevice.requestAccess(for: .video)
                    cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                }
            }
        }
        .onDisappear { isVisible = false }
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { isLandscape = $0 }
        // iPhone: the result slides up. (On iPad it shows beside the camera instead.)
        .sheet(item: Binding(get: { wide ? nil : result },
                             set: { if !wide { result = $0 } }),
               onDismiss: { if !wide { pauseBriefly() } }) { code in
            ScanResultView(code: code)
        }
        .sensoryFeedback(.success, trigger: result?.id)
        .onChange(of: photoItem) {
            guard let item = photoItem else { return }
            photoItem = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                if let data, let text = ScanReader.readCode(fromImageData: data) {
                    result = ScannedCode(raw: text)
                } else {
                    noCodeInPhoto = true
                }
            }
        }
        .alert("No QR code found", isPresented: $noCodeInPhoto) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try a picture where the code is clear and not cut off.")
        }
    }

    private var photoButton: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            Label("Scan from a photo", systemImage: "photo.on.rectangle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    /// iPad: the camera in the middle; once a code is found, camera left and result right.
    private var wideScan: some View {
        GeometryReader { geo in
            let cameraWidth = result == nil
                ? min(geo.size.width - 64, 720)
                : (geo.size.width - 72) * 0.5
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 16) {
                    camera
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    photoButton
                }
                .frame(width: cameraWidth)

                if let result {
                    ScanResultView(code: result) {
                        withAnimation(.spring(duration: 0.45)) { self.result = nil }
                        pauseBriefly()
                    }
                    .id(result.id)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .animation(.spring(duration: 0.45), value: result?.id)
    }

    private var phoneScan: some View {
        VStack(spacing: 16) {
            camera
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)

            photoButton
                .padding(.horizontal)
                // Keeps the same layout as when there was a line of text here.
                .padding(.bottom, 60)
        }
    }

    @ViewBuilder
    private var camera: some View {
        if !DataScannerViewController.isSupported {
            unavailable("Camera scanning isn't available on this device",
                        symbol: "camera.metering.unknown",
                        text: "You can still scan from a photo or screenshot.")
        } else {
            switch cameraStatus {
            case .authorized:
                QRScannerView(isScanning: isVisible && result == nil && !paused) { text in
                    if result == nil { result = ScannedCode(raw: text) }
                }
                .overlay(alignment: .bottom) {
                    Text("Point the camera at a QR code")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                }
            case .notDetermined:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.secondarySystemBackground))
            default:
                VStack(spacing: 12) {
                    unavailable("Camera is off for Make Forever QR", symbol: "camera.fill",
                                text: "Turn on the camera in Settings to scan, or scan from a photo.")
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
                .background(Color(.secondarySystemBackground))
            }
        }
    }

    private func unavailable(_ title: String, symbol: String, text: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    /// Wait a moment after closing a result, so the same code isn't read again right away.
    private func pauseBriefly() {
        paused = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            paused = false
        }
    }
}

/// Apple's live camera scanner, set to QR codes only.
private struct QRScannerView: UIViewControllerRepresentable {
    let isScanning: Bool
    let onFound: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        context.coordinator.onFound = onFound
        let shouldScan = isScanning
        // Wait until the camera view is on screen before starting.
        DispatchQueue.main.async {
            if shouldScan, !scanner.isScanning {
                try? scanner.startScanning()
            } else if !shouldScan, scanner.isScanning {
                scanner.stopScanning()
            }
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator { Coordinator(onFound: onFound) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onFound: (String) -> Void
        init(onFound: @escaping (String) -> Void) { self.onFound = onFound }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            report(addedItems)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            report([item])
        }

        private func report(_ items: [RecognizedItem]) {
            for item in items {
                if case .barcode(let code) = item, let text = code.payloadStringValue, !text.isEmpty {
                    onFound(text)
                    return
                }
            }
        }
    }
}
