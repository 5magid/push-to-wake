import Foundation
import Vision
import AVFoundation
import Combine

class PushupDetector: NSObject, ObservableObject {
    @Published var repCount: Int = 0
    @Published var isInDownPosition: Bool = false
    @Published var feedbackMessage: String = "Get into pushup position"

    private var captureSession: AVCaptureSession?
    private var isDown: Bool = false
    private let angleThresholdDown: Double = 90.0   // Elbows bent = down
    private let angleThresholdUp: Double = 150.0    // Elbows straight = up

    // MARK: - Camera Setup
    func startSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              captureSession?.canAddInput(input) == true else {
            feedbackMessage = "Camera unavailable"
            return
        }

        captureSession?.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "cameraQueue"))
        captureSession?.addOutput(output)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }

    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
    }

    func reset() {
        repCount = 0
        isDown = false
        feedbackMessage = "Get into pushup position"
    }

    // MARK: - Angle Calculation
    // Calculates the angle at point B, formed by points A-B-C
    // This is how we measure elbow bend: shoulder(A) - elbow(B) - wrist(C)
    private func angle(a: CGPoint, b: CGPoint, c: CGPoint) -> Double {
        let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
        let cb = CGPoint(x: b.x - c.x, y: b.y - c.y)
        let dot = ab.x * cb.x + ab.y * cb.y
        let cross = ab.x * cb.y - ab.y * cb.x
        return abs(atan2(cross, dot) * 180 / .pi)
    }

    // MARK: - Rep Detection
    private func processBodyPose(_ observation: VNHumanBodyPoseObservation) {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return }

        // Get left arm joints
        let leftShoulder = recognizedPoints[.leftShoulder]
        let leftElbow    = recognizedPoints[.leftElbow]
        let leftWrist    = recognizedPoints[.leftWrist]

        // Get right arm joints
        let rightShoulder = recognizedPoints[.rightShoulder]
        let rightElbow    = recognizedPoints[.rightElbow]
        let rightWrist    = recognizedPoints[.rightWrist]

        // Only proceed if all joints are detected with high confidence
        let minConfidence: Float = 0.3
        guard
            let ls = leftShoulder,  ls.confidence > minConfidence,
            let le = leftElbow,     le.confidence > minConfidence,
            let lw = leftWrist,     lw.confidence > minConfidence,
            let rs = rightShoulder, rs.confidence > minConfidence,
            let re = rightElbow,    re.confidence > minConfidence,
            let rw = rightWrist,    rw.confidence > minConfidence
        else {
            DispatchQueue.main.async {
                self.feedbackMessage = "Position yourself so camera sees your full body"
            }
            return
        }

        // Calculate elbow angles for both arms
        let leftAngle  = angle(a: ls.location, b: le.location, c: lw.location)
        let rightAngle = angle(a: rs.location, b: re.location, c: rw.location)
        let avgAngle   = (leftAngle + rightAngle) / 2

        DispatchQueue.main.async {
            if avgAngle < self.angleThresholdDown && !self.isDown {
                // Arms bent — went DOWN
                self.isDown = true
                self.isInDownPosition = true
                self.feedbackMessage = "Down ✓ — now push up!"

            } else if avgAngle > self.angleThresholdUp && self.isDown {
                // Arms straight — came back UP — that's 1 rep!
                self.isDown = false
                self.isInDownPosition = false
                self.repCount += 1
                self.feedbackMessage = "Rep \(self.repCount) ✓ — keep going!"
            }
        }
    }
}

// MARK: - Camera Frame Delegate
// This runs every time a new camera frame arrives (~30 times per second)
extension PushupDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNHumanBodyPoseObservation],
                  let firstPerson = results.first else { return }
            self.processBodyPose(firstPerson)
        }

        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                   orientation: .leftMirrored,
                                   options: [:]).perform([request])
    }
}
