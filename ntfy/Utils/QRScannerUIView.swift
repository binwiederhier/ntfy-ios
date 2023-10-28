import AVFoundation
import SwiftUI

struct QRScannerUIView: UIViewRepresentable {
    var onCodeDetected: (String) -> Void

    func makeUIView(context: Context) -> some UIView {
        let view = QRScannerUIViewContainer()
        
        let captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice),
              captureSession.canAddInput(videoInput) else {
            return view
        }
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(metadataOutput)
        
        metadataOutput.setMetadataObjectsDelegate(context.coordinator, queue: DispatchQueue.main)
        metadataOutput.metadataObjectTypes = [.qr]
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)
        
        // Move the startRunning call to a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            captureSession.startRunning()
        }
        
        view.previewLayer = previewLayer
        view.captureSession = captureSession
        return view
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeDetected: onCodeDetected)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        var onCodeDetected: (String) -> Void

        init(onCodeDetected: @escaping (String) -> Void) {
            self.onCodeDetected = onCodeDetected
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject, let stringValue = metadataObject.stringValue {
                onCodeDetected(stringValue)
            }
        }
    }
}


class QRScannerUIViewContainer: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var captureSession: AVCaptureSession?

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = self.bounds
    }
}
