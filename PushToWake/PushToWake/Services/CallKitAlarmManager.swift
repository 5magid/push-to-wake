import Foundation
import CallKit
import AVFoundation

// Uses CallKit to present the alarm as an incoming phone call.
// This is the technique real wake-up apps (like Alarmy) use — it's the ONLY
// mechanism iOS gives third-party apps that can take over a LOCKED screen,
// ring loudly past the silent switch, and keep ringing until answered.
// A normal notification can never do any of that.
class CallKitAlarmManager: NSObject {
    static let shared = CallKitAlarmManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var currentCallUUID: UUID?

    // Set by AlarmState — called when the user taps "Answer" on the call screen
    var onAnswered: (() -> Void)?
    // Called when the user taps "Decline"
    var onDeclined: (() -> Void)?

    override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = false
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic]
        provider = CXProvider(configuration: configuration)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    // Triggers the "incoming call" screen — this is what actually wakes the
    // phone and breaks through the lock screen, even if the app was backgrounded.
    func presentAlarmCall(label: String) {
        let uuid = UUID()
        currentCallUUID = uuid

        let displayName = label.isEmpty ? "PushToWake Alarm" : label
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: displayName)
        update.localizedCallerName = displayName
        update.hasVideo = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("Failed to present alarm call: \(error.localizedDescription)")
            }
        }
    }

    private func endCall() {
        guard let uuid = currentCallUUID else { return }
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        callController.request(transaction) { error in
            if let error = error {
                print("Failed to end call: \(error.localizedDescription)")
            }
        }
        currentCallUUID = nil
    }

    // Call once the user dismisses the alarm properly (after pushups)
    func finishAlarmCall() {
        endCall()
    }
}

// MARK: - CXProviderDelegate
// iOS calls these methods in response to system call actions.
extension CallKitAlarmManager: CXProviderDelegate {
    func providerDidReset(_ provider: CXProvider) {
        currentCallUUID = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        action.fulfill()
        DispatchQueue.main.async {
            self.onAnswered?()
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        action.fulfill()
        currentCallUUID = nil
        DispatchQueue.main.async {
            self.onDeclined?()
        }
    }

    // Required by the protocol — we manage alarm sound separately in AlarmState
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}
}
