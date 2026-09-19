import Foundation
import AVFoundation
import AudioToolbox
import Combine

// AlarmState is the single source of truth for whether an alarm is currently firing.
@MainActor
class AlarmState: ObservableObject {
    static let shared = AlarmState()

    @Published var isAlarmFiring: Bool = false
    @Published var activeAlarm: Alarm? = nil

    private var audioPlayer: AVAudioPlayer?
    private var keepAlivePlayer: AVAudioPlayer? // Silent loop — keeps app alive in background
    private var alarmTimer: Timer?
    private var vibrationTimer: Timer?
    private var checkTimer: Timer?
    private var pendingAlarm: Alarm? // Alarm waiting for the user to "answer" the fake call

    init() {
        // Hook up CallKit callbacks
        CallKitAlarmManager.shared.onAnswered = { [weak self] in
            guard let self, let alarm = self.pendingAlarm else { return }
            self.fireAlarm(alarm)
        }
        CallKitAlarmManager.shared.onDeclined = { [weak self] in
            self?.pendingAlarm = nil
        }

        startKeepAliveAudio()

        // Check every 15 seconds if an alarm should fire.
        // We reference the singleton directly (AlarmState.shared) instead of
        // capturing `self` weakly — reading a weak-captured self across a
        // Task boundary is what Swift 6 flags as unsafe concurrent access.
        checkTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
            Task { @MainActor in
                AlarmState.shared.checkForFiringAlarms()
            }
        }
        checkForFiringAlarms()
    }

    // Called on a timer and on foreground — checks if any saved alarm should fire now
    func checkForFiringAlarms() {
        guard !isAlarmFiring, pendingAlarm == nil else { return }

        var alarms = loadAlarms()
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        let currentMinute = calendar.component(.minute, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)

        for i in alarms.indices where alarms[i].isActive {
            let alarm = alarms[i]
            let alarmHour = calendar.component(.hour, from: alarm.time)
            let alarmMinute = calendar.component(.minute, from: alarm.time)
            let timeMatches = alarmHour == currentHour && alarmMinute == currentMinute
            let dayMatches = alarm.repeatDays.isEmpty || alarm.repeatDays.contains { $0.rawValue == currentWeekday }

            if timeMatches && dayMatches {
                if alarm.repeatDays.isEmpty {
                    alarms[i].isActive = false
                    saveAlarms(alarms)
                }
                pendingAlarm = alarm
                // Present as an incoming call — this is what wakes the phone
                // and breaks through the lock screen / silent switch.
                CallKitAlarmManager.shared.presentAlarmCall(label: alarm.label)
                return
            }
        }
    }

    // Called once the user "answers" the fake call — shows the full pushup screen
    func fireAlarm(_ alarm: Alarm) {
        activeAlarm = alarm
        isAlarmFiring = true
        pendingAlarm = nil
        startSound()
        startVibration()
    }

    func dismissAlarm() {
        isAlarmFiring = false
        activeAlarm = nil
        stopSound()
        stopVibration()
        CallKitAlarmManager.shared.finishAlarmCall()
    }

    // MARK: - Background keep-alive
    // Loops a silent audio track continuously. Without this, iOS suspends the
    // app within seconds of backgrounding it, and neither our alarm-check timer
    // nor the ability to present the fake incoming call would work at all.
    // This is the same technique every third-party alarm app on the App Store uses.
    private func startKeepAliveAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Keep-alive audio session error: \(error.localizedDescription)")
        }

        guard let silentData = Self.makeSilentWAVData(seconds: 1) else { return }
        keepAlivePlayer = try? AVAudioPlayer(data: silentData)
        keepAlivePlayer?.numberOfLoops = -1
        keepAlivePlayer?.volume = 0.0
        keepAlivePlayer?.play()
    }

    // Generates a tiny silent WAV file in memory — no bundled audio asset needed
    private static func makeSilentWAVData(seconds: Double) -> Data? {
        let sampleRate: Int32 = 8000
        let numSamples = Int32(sampleRate) * Int32(seconds)
        let byteRate = sampleRate * 2
        let dataSize = numSamples * 2

        var data = Data()
        func appendUInt32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func appendUInt16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(16)
        appendUInt16(1)  // PCM format
        appendUInt16(1)  // mono
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(2)  // block align
        appendUInt16(16) // bits per sample
        data.append(contentsOf: "data".utf8)
        appendUInt32(UInt32(dataSize))
        data.append(Data(count: Int(dataSize))) // all zero bytes = silence

        return data
    }

    // MARK: - Alarm Sound (once the fake call is answered)
    private func startSound() {
        let systemSoundPaths = [
            "/System/Library/Audio/UISounds/alarm.caf",
            "/System/Library/Audio/UISounds/Alarm.caf",
            "/System/Library/Audio/UISounds/classic/alarm.caf"
        ]
        for path in systemSoundPaths {
            let url = URL(fileURLWithPath: path)
            if let player = try? AVAudioPlayer(contentsOf: url) {
                audioPlayer = player
                audioPlayer?.numberOfLoops = -1
                audioPlayer?.volume = 1.0
                audioPlayer?.play()
                return
            }
        }
        alarmTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            AudioServicesPlaySystemSound(1304)
        }
        AudioServicesPlaySystemSound(1304)
    }

    private func stopSound() {
        audioPlayer?.stop()
        audioPlayer = nil
        alarmTimer?.invalidate()
        alarmTimer = nil
    }

    // MARK: - Vibration
    private func startVibration() {
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    // MARK: - Persistence
    private func loadAlarms() -> [Alarm] {
        if let data = UserDefaults.standard.data(forKey: "savedAlarms"),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            return decoded
        }
        return []
    }

    private func saveAlarms(_ alarms: [Alarm]) {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "savedAlarms")
        }
    }
}
