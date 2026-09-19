import SwiftUI
import AVFoundation

struct ActiveAlarmView: View {
    let alarm: Alarm
    var onDismiss: () -> Void

    @StateObject private var detector = PushupDetector()
    @State private var cameraStarted = false
    @State private var sessionReady = false

    var repsRemaining: Int { max(0, alarm.pushupCount - detector.repCount) }
    var progress: Double {
        guard alarm.pushupCount > 0 else { return 1.0 }
        return Double(detector.repCount) / Double(alarm.pushupCount)
    }
    var goalReached: Bool { detector.repCount >= alarm.pushupCount }

    var body: some View {
        ZStack {

            // MARK: - Background — live camera feed or black
            if cameraStarted && sessionReady, let session = detector.captureSession {
                CameraPreviewView(session: session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(.all)

                // Dark overlay so UI elements are readable on top of camera
                Color.black.opacity(0.55)
                    .ignoresSafeArea(.all)
            } else {
                Color.black.ignoresSafeArea()
            }

            // MARK: - UI Layer
            VStack(spacing: 0) {

                // Current time at top
                VStack(spacing: 4) {
                    Text(Date(), style: .time)
                        .font(.system(size: 64, weight: .thin))
                        .foregroundStyle(.white)
                        .padding(.top, 56)

                    Text(alarm.label.isEmpty ? "Time to wake up!" : alarm.label)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.5)
                        .textCase(.uppercase)
                }

                Spacer()

                // Rep counter ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 10)
                        .frame(width: 180, height: 180)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            goalReached ? Theme.success : Theme.accent,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.4), value: progress)

                    VStack(spacing: 4) {
                        Text("\(detector.repCount)")
                            .font(.system(size: 58, weight: .bold, design: .rounded))
                            .foregroundStyle(goalReached ? Theme.success : Theme.textPrimary)
                            .contentTransition(.numericText())
                            .animation(.spring(duration: 0.3), value: detector.repCount)

                        Text("of \(alarm.pushupCount)")
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                // Feedback / instruction text
                Text(goalReached ? "🎉 Goal reached!" : detector.feedbackMessage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(goalReached ? Theme.success : Theme.textPrimary.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .animation(.easeInOut, value: detector.feedbackMessage)

                // Up/down indicator — only shows when camera is running
                if cameraStarted && !goalReached {
                    HStack(spacing: 8) {
                        Image(systemName: detector.isInDownPosition ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(detector.isInDownPosition ? Theme.accent : Theme.textTertiary)
                        Text(detector.isInDownPosition ? "Push UP" : "Go DOWN")
                            .font(.subheadline.bold())
                            .foregroundStyle(detector.isInDownPosition ? Theme.accent : Theme.textSecondary)
                    }
                    .padding(.top, 12)
                    .animation(.spring(duration: 0.2), value: detector.isInDownPosition)
                }

                Spacer()

                // Bottom buttons
                VStack(spacing: 12) {

                    // Start camera button — only shows before camera is running
                    if !cameraStarted {
                        Button {
                            cameraStarted = true
                            detector.startSession()
                            // Small delay to let the session start before showing preview
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                sessionReady = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "camera.fill")
                                Text("Start Camera to Count Reps")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Theme.accent)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.horizontal, 24)
                    }

                    // Dismiss button — locked until goal reached
                    Button {
                        guard goalReached else { return }
                        detector.stopSession()
                        onDismiss()
                    } label: {
                        Text(goalReached
                             ? "Dismiss Alarm ✓"
                             : cameraStarted
                                ? "\(repsRemaining) more pushup\(repsRemaining == 1 ? "" : "s") to dismiss"
                                : "Start camera first")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(goalReached ? Theme.success : Theme.surface)
                            .foregroundStyle(goalReached ? .white : Theme.textTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .animation(.spring(duration: 0.3), value: goalReached)
                    }
                    .disabled(!goalReached)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .ignoresSafeArea()
        .interactiveDismissDisabled(true)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .onDisappear {
            detector.stopSession()
        }
    }
}

#Preview {
    ActiveAlarmView(alarm: Alarm(time: Date(), pushupCount: 10)) {}
}
