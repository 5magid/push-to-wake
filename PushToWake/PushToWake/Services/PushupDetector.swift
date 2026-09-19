import Foundation
import Vision
import AVFoundation
import Combine

class PushupDetector: NSObject, ObservableObject {
    @Published var repCount: Int = 0
    @Published var isInDownPosition: Bool = false
    @Published var feedbackMessage: String = "Get into pushup position"
    @Published var cameraAuthorized: Bool = false
    @Published var detectionDebug: String = "" // Shows raw angle for debugging

    var captureSession: AVCaptureSession?

    private var isDown: Bool = false
    // Lowered thresholds — easier to trigger
    private let angleThresholdDown: Double = 100.0  // Was 90 — more forgiving
    private let angleThresholdUp: Double = 140.0    // Was 150 — more forgiving
    // Lowered confidence — don't require all joints to be perfectly visible
    private let minConfidence: Float = 0.15         // Was 0.3 — much more forgiving

    // MARK: - Camera Setup
    func startSession() {
        checkCameraPermission()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.setupSession() }
                else {
                    DispatchQueue.main.async {
                        self?.feedbackMessage = "Camera denied — enable in Settings"
                    }
                }
            }
        default:
            DispatchQueue.main.async {
                self.feedbackMessage = "Camera denied — enable in Settings"
            }
        }
    }

    private func setupSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080 // 16:9 matches iPhone screen ratio natively

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: .front
        ),
        let input = try? AVCaptureDeviceInput(device: device),
        session.canAddInput(input) else {
            DispatchQueue.main.async { self.feedbackMessage = "Camera unavailable" }
            return
        }

        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue", qos: .userInteractive))
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)

        self.captureSession = session
        DispatchQueue.main.async {
            self.cameraAuthorized = true
            self.feedbackMessage = "Point camera at your upper body"
        }
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
            self.captureSession = nil
        }
        DispatchQueue.main.async {
            self.repCount = 0
            self.isDown = false
            self.cameraAuthorized = false
            self.feedbackMessage = "Get into pushup position"
            self.detectionDebug = ""
        }
    }

    // MARK: - Angle Calculation
    private func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let cb = CGPoint(x: b.x - c.x, y: b.y - c.y)
        let dot = Double(ab.x * cb.x + ab.y * cb.y)
        let cross = Double(ab.x * cb.y - ab.y * cb.x)
        return abs(atan2(cross, dot) * 180 / .pi)
    }

    // MARK: - Rep Detection
    private func processBodyPose(_ observation: VNHumanBodyPoseObservation) {
        guard let points = try? observation.recognizedPoints(.all) else {
            DispatchQueue.main.async { self.feedbackMessage = "No body detected" }
            return
        }

        // Try to get joints — use either arm if available
        let ls = points[.leftShoulder]
        let le = points[.leftElbow]
        let lw = points[.leftWrist]
        let rs = points[.rightShoulder]
        let re = points[.rightElbow]
        let rw = points[.rightWrist]

        // Check which joints are visible above confidence threshold
        let leftVisible = [ls, le, lw].compactMap { $0 }.filter { $0.confidence > minConfidence }.count == 3
        let rightVisible = [rs, re, rw].compactMap { $0 }.filter { $0.confidence > minConfidence }.count == 3

        // Need at least one full arm visible
        guard leftVisible || rightVisible else {
            let visibleCount = [ls, le, lw, rs, re, rw]
                .compactMap { $0 }
                .filter { $0.confidence > minConfidence }
                .count
            DispatchQueue.main.async {
                self.feedbackMessage = "Can't see arms clearly (\(visibleCount)/6 joints)"
                self.detectionDebug = "Joints visible: \(visibleCount)/6"
            }
            return
        }

        // Calculate angle — prefer average of both arms, fall back to one arm
        var avgAngle: Double = 0
        var angleCount = 0

        if leftVisible, let ls = ls, let le = le, let lw = lw {
            avgAngle += angle(a: ls.location, b: le.location, c: lw.location)
            angleCount += 1
        }
        if rightVisible, let rs = rs, let re = re, let rw = rw {
            avgAngle += angle(a: rs.location, b: re.location, c: rw.location)
            angleCount += 1
        }
        avgAngle /= Double(angleCount)

        DispatchQueue.main.async {
            // Always show the angle so you can see what's being detected
            self.detectionDebug = "Angle: \(Int(avgAngle))° (down<\(Int(self.angleThresholdDown))° up>\(Int(self.angleThresholdUp))°)"

            if avgAngle < self.angleThresholdDown && !self.isDown {
                self.isDown = true
                self.isInDownPosition = true
                self.feedbackMessage = "Down ✓ — push up!"
            } else if avgAngle > self.angleThresholdUp && self.isDown {
                self.isDown = false
                self.isInDownPosition = false
                self.repCount += 1
                self.feedbackMessage = "Rep \(self.repCount) ✓ keep going!"
            } else if !self.isDown {
                self.feedbackMessage = "Go down into pushup position"
            }
        }
    }
}

// MARK: - Frame Delegate
extension PushupDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] req, _ in
            guard let self,
                  let results = req.results as? [VNHumanBodyPoseObservation],
                  let first = results.first else {
                DispatchQueue.main.async {
                    self?.feedbackMessage = "No person detected — step back"
                    self?.detectionDebug = "No body in frame"
                }
                return
            }
            self.processBodyPose(first)
        }

        // Try .up orientation — works better for front camera on most iPhones
        try? VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up
        ).perform([request])
    }
}
