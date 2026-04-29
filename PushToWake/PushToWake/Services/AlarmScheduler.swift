import Foundation
import UserNotifications

class AlarmScheduler: ObservableObject {
    static let shared = AlarmScheduler()

    // Ask user for permission to send notifications (called once on first launch)
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
            print("Notification permission granted: \(granted)")
        }
    }

    // Schedule an alarm for a given Alarm object
    func schedule(alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = alarm.label.isEmpty ? "PushToWake" : alarm.label
        content.body = "Complete \(alarm.pushupCount) pushups to dismiss"
        content.sound = UNNotificationSound.defaultCritical
        content.interruptionLevel = .critical  // Bypasses Do Not Disturb

        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: alarm.time)

        if alarm.repeatDays.isEmpty {
            // One-time alarm — fires once at the set time
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components,
                repeats: false
            )
            addNotification(id: alarm.id.uuidString, content: content, trigger: trigger)
        } else {
            // Repeating alarm — schedule one notification per selected day
            for day in alarm.repeatDays {
                var repeatingComponents = components
                repeatingComponents.weekday = day.rawValue
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: repeatingComponents,
                    repeats: true
                )
                let notifID = "\(alarm.id.uuidString)-\(day.rawValue)"
                addNotification(id: notifID, content: content, trigger: trigger)
            }
        }
    }

    // Cancel a scheduled alarm by its ID
    func cancel(alarm: Alarm) {
        var ids = [alarm.id.uuidString]
        for day in Alarm.Weekday.allCases {
            ids.append("\(alarm.id.uuidString)-\(day.rawValue)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    // Internal helper to register a notification with the system
    private func addNotification(id: String, content: UNMutableNotificationContent, trigger: UNCalendarNotificationTrigger) {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule alarm: \(error.localizedDescription)")
            }
        }
    }
}
