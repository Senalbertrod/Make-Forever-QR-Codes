//
//  ScanView.swift
//  Make Forever QR Codes
//
//  Tab 2: scan a code with the camera or from a photo. Uses Apple's
//  on-device scanner; nothing the camera sees is saved or sent.
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                camera
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal)

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Scan from a photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 8)
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
        .sheet(item: $result, onDismiss: pauseBriefly) { code in
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
