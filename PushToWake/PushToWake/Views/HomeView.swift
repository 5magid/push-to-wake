import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var alarmState: AlarmState
    @State private var alarms: [Alarm] = []
    @State private var showingAddAlarm = false

    var body: some View {
        NavigationStack {
            Group {
                if alarms.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "alarm")
                            .font(.system(size: 56))
                            .foregroundStyle(Theme.textTertiary)
                        Text("No Alarms")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Tap + to set your first alarm")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textTertiary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                } else {
                    List {
                        ForEach(alarms) { alarm in
                            AlarmRowView(
                                alarm: alarm,
                                isOn: bindingForActive(id: alarm.id)
                            )
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .onDelete(perform: deleteAlarm)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.background)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("PushToWake")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PushToWake")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddAlarm = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(Theme.textPrimary)
                            .fontWeight(.semibold)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Test") {
                        let testAlarm = Alarm(
                            time: Date(),
                            pushupCount: alarms.first?.pushupCount ?? 5,
                            label: alarms.first?.label ?? ""
                        )
                        alarmState.fireAlarm(testAlarm)
                    }
                    .foregroundStyle(Theme.accent)
                    .font(.subheadline)
                }
            }
            .fullScreenCover(isPresented: $showingAddAlarm) {
                AlarmSetupView { newAlarm in
                    alarms.append(newAlarm)
                    AlarmScheduler.shared.schedule(alarm: newAlarm)
                    saveAlarms()
                }
            }
            .onAppear {
                loadAlarms()
            }
            .onChange(of: alarmState.isAlarmFiring) { wasFiring, isFiring in
                if wasFiring && !isFiring {
                    loadAlarms()
                }
            }
        }
    }

    private func bindingForActive(id: UUID) -> Binding<Bool> {
        Binding(
            get: { alarms.first(where: { $0.id == id })?.isActive ?? false },
            set: { newValue in toggleAlarm(id: id, to: newValue) }
        )
    }

    private func toggleAlarm(id: UUID, to newValue: Bool) {
        guard let index = alarms.firstIndex(where: { $0.id == id }) else { return }
        alarms[index].isActive = newValue
        if alarms[index].isActive {
            AlarmScheduler.shared.schedule(alarm: alarms[index])
        } else {
            AlarmScheduler.shared.cancel(alarm: alarms[index])
        }
        saveAlarms()
    }

    private func deleteAlarm(at offsets: IndexSet) {
        let alarmsToCancel = offsets.compactMap { alarms.indices.contains($0) ? alarms[$0] : nil }
        alarmsToCancel.forEach { AlarmScheduler.shared.cancel(alarm: $0) }
        alarms.remove(atOffsets: offsets)
        saveAlarms()
    }

    private func saveAlarms() {
        if let encoded = try? JSONEncoder().encode(alarms) {
            UserDefaults.standard.set(encoded, forKey: "savedAlarms")
        }
    }

    private func loadAlarms() {
        if let data = UserDefaults.standard.data(forKey: "savedAlarms"),
           let decoded = try? JSONDecoder().decode([Alarm].self, from: data) {
            alarms = decoded
        }
    }
}

// MARK: - Alarm Row (card style)
struct AlarmRowView: View {
    let alarm: Alarm
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(hourMinute)
                        .font(.system(size: 44, weight: .thin))
                        .foregroundStyle(alarm.isActive ? Theme.textPrimary : Theme.textTertiary)
                    Text(" " + ampm)
                        .font(.system(size: 22, weight: .thin))
                        .foregroundStyle(alarm.isActive ? Theme.textPrimary : Theme.textTertiary)
                }

                HStack(spacing: 4) {
                    if !alarm.label.isEmpty {
                        Text(alarm.label)
                            .foregroundStyle(alarm.isActive ? Theme.textPrimary.opacity(0.8) : Theme.textTertiary)
                    }
                    Text(alarm.repeatDays.isEmpty ? "Alarm" : repeatDaysText)
                        .foregroundStyle(alarm.isActive ? Theme.textSecondary : Theme.textTertiary)
                }
                .font(.subheadline)

                HStack(spacing: 4) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption2)
                    Text("\(alarm.pushupCount) pushups to dismiss")
                        .font(.caption)
                }
                .foregroundStyle(alarm.isActive ? Theme.accent : Theme.textTertiary)
                .padding(.top, 2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .tint(Theme.accent)
                .labelsHidden()
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(alarm.isActive ? Theme.accent.opacity(0.25) : Color.clear, lineWidth: 1)
        )
    }

    private var hourMinute: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: alarm.time)
    }

    private var ampm: String {
        let f = DateFormatter()
        f.dateFormat = "a"
        return f.string(from: alarm.time)
    }

    private var repeatDaysText: String {
        alarm.repeatDays.sorted { $0.rawValue < $1.rawValue }.map { $0.shortName }.joined(separator: " ")
    }
}

#Preview {
    HomeView()
        .environmentObject(AlarmState.shared)
}
