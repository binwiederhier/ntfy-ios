import AVFoundation
import SwiftUI
import UIKit

struct SubscriptionQRScannerView: View {
    private enum CameraState {
        case checking
        case ready
        case denied
        case unavailable
    }

    @Environment(\.presentationMode) private var presentationMode
    @State private var cameraState: CameraState = .checking
    @State private var scanError: String?

    let onScan: (NtfyDeepLink) -> Void

    var body: some View {
        NavigationView {
            Group {
                switch cameraState {
                case .checking:
                    ProgressView("Preparing camera…")
                case .ready:
                    scanner
                case .denied:
                    cameraMessage(
                        title: "Camera access is off",
                        message: "Allow camera access in Settings to scan a subscription QR code.",
                        showSettingsButton: true
                    )
                case .unavailable:
                    cameraMessage(
                        title: "Camera unavailable",
                        message: "This device does not have a camera available for scanning.",
                        showSettingsButton: false
                    )
                }
            }
            .navigationTitle("Scan QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear(perform: prepareCamera)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            prepareCamera()
        }
    }

    private var scanner: some View {
        ZStack {
            QRScannerCaptureView(onCode: handleCode) {
                cameraState = .unavailable
            }
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.6), radius: 4)

            VStack {
                Spacer()
                Text("Point the camera at an ntfy topic QR code")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(10)

                if let scanError {
                    Text(scanError)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(12)
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }

    private func cameraMessage(title: String, message: String, showSettingsButton: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if showSettingsButton {
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }

    private func prepareCamera() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            cameraState = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraState = .ready
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    cameraState = granted ? .ready : .denied
                }
            }
        case .denied, .restricted:
            cameraState = .denied
        @unknown default:
            cameraState = .unavailable
        }
    }

    private func handleCode(_ value: String) -> Bool {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedValue),
              let deepLink = NtfyDeepLink(qrCodeURL: url) else {
            scanError = "This QR code is not an ntfy topic link."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return false
        }

        scanError = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScan(deepLink)
        return true
    }
}

private struct QRScannerCaptureView: UIViewControllerRepresentable {
    let onCode: (String) -> Bool
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        QRScannerViewController(onCode: onCode, onFailure: onFailure)
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: QRScannerViewController, coordinator: ()) {
        uiViewController.stopCapture()
    }
}

private final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "io.heckel.ntfy.qr-session")
    private let metadataQueue = DispatchQueue(label: "io.heckel.ntfy.qr-metadata")
    private let onCode: (String) -> Bool
    private let onFailure: () -> Void

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var isProcessing = false
    private var didFinish = false

    init(onCode: @escaping (String) -> Bool, onFailure: @escaping () -> Void) {
        self.onCode = onCode
        self.onFailure = onFailure
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        configureCapture()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCapture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCapture()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func stopCapture() {
        sessionQueue.async { [captureSession] in
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
        }
    }

    private func configureCapture() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            failCapture()
            return
        }

        let output = AVCaptureMetadataOutput()
        captureSession.beginConfiguration()
        guard captureSession.canAddInput(input), captureSession.canAddOutput(output) else {
            captureSession.commitConfiguration()
            failCapture()
            return
        }
        captureSession.addInput(input)
        captureSession.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: metadataQueue)
        output.metadataObjectTypes = [.qr]
        captureSession.commitConfiguration()

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        self.previewLayer = previewLayer
        isConfigured = true
    }

    private func startCapture() {
        guard isConfigured else {
            return
        }
        sessionQueue.async { [captureSession] in
            if !captureSession.isRunning {
                captureSession.startRunning()
            }
        }
    }

    @objc private func applicationDidBecomeActive() {
        startCapture()
    }

    @objc private func applicationDidEnterBackground() {
        stopCapture()
    }

    private func failCapture() {
        DispatchQueue.main.async(execute: onFailure)
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didFinish,
              !isProcessing,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr,
              let value = object.stringValue else {
            return
        }

        isProcessing = true
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            let accepted = self.onCode(value)
            self.metadataQueue.async {
                if accepted {
                    self.didFinish = true
                    self.stopCapture()
                } else {
                    self.metadataQueue.asyncAfter(deadline: .now() + 1) {
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}
