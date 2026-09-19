//
//  PushToWakeApp.swift
//  PushToWake
//
//  Created by Magid Ismail on 2026-04-28.
//

import SwiftUI
import UserNotifications

@main
struct PushToWakeApp: App {
    @StateObject private var alarmState = AlarmState.shared

    init() {
        requestNotificationPermission()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .environmentObject(alarmState)

                // Full screen alarm takeover — appears once the fake call is answered
                if alarmState.isAlarmFiring, let alarm = alarmState.activeAlarm {
                    ActiveAlarmView(alarm: alarm) {
                        alarmState.dismissAlarm()
                    }
                    .transition(.opacity)
                    .zIndex(999)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: alarmState.isAlarmFiring)
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                alarmState.checkForFiringAlarms()
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
}
