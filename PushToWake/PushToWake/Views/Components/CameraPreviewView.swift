import SwiftUI
import AVFoundation
import UIKit

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraView {
        let view = CameraView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraView, context: Context) {}
}

final class CameraView: UIView {
    var session: AVCaptureSession? {
        didSet { updateSession() }
    }

    override class var layerClass: AnyClass {
        // Tell UIKit to use AVCaptureVideoPreviewLayer as this view's backing layer
        // This is the cleanest way — no sublayer, no frame math needed
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private func updateSession() {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
