import SwiftUI

struct AlarmSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (Alarm) -> Void

    @State private var selectedTime = Date()
    @State private var pushupCount = 10
    @State private var label = ""
    @State private var repeatDays: Set<Alarm.Weekday> = []

    let pushupOptions = [5, 10, 15, 20, 25, 30, 40, 50]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // MARK: Time Picker
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "WAKE TIME")
                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .colorScheme(.dark)
                                .frame(maxWidth: .infinity)
                        }

                        Divider().background(Theme.separator)

                        // MARK: Pushup Count
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "PUSHUPS REQUIRED")
                            LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 4), spacing: 10) {
                                ForEach(pushupOptions, id: \.self) { count in
                                    Button {
                                        withAnimation(.spring(duration: 0.25)) {
                                            pushupCount = count
                                        }
                                    } label: {
                                        Text("\(count)")
                                            .font(.system(size: 18, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(pushupCount == count ? Theme.accent : Theme.surface)
                                            .foregroundStyle(pushupCount == count ? .white : Theme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .scaleEffect(pushupCount == count ? 1.03 : 1.0)
                                    }
                                }
                            }

                            HStack {
                                Text("Custom:")
                                    .foregroundStyle(Theme.textSecondary)
                                    .font(.subheadline)
                                Spacer()
                                Stepper("\(pushupCount) reps", value: $pushupCount, in: 1...100)
                                    .foregroundStyle(Theme.textPrimary)
                                    .colorScheme(.dark)
                            }
                            .padding(.top, 4)
                        }

                        Divider().background(Theme.separator)

                        // MARK: Repeat Days
                        VStack(alignment: .leading, spacing: 12) {
                            SectionLabel(text: "REPEAT")
                            HStack(spacing: 8) {
                                ForEach(Alarm.Weekday.allCases, id: \.self) { day in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) {
                                            if repeatDays.contains(day) {
                                                repeatDays.remove(day)
                                            } else {
                                                repeatDays.insert(day)
                                            }
                                        }
                                    } label: {
                                        Text(day.shortName)
                                            .font(.system(size: 13, weight: .medium))
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 40)
                                            .background(repeatDays.contains(day) ? Theme.accent : Theme.surface)
                                            .foregroundStyle(repeatDays.contains(day) ? .white : Theme.textPrimary)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }

                        Divider().background(Theme.separator)

                        // MARK: Label
                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel(text: "LABEL (OPTIONAL)")
                            TextField("e.g. Morning Grind", text: $label)
                                .padding(14)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(Theme.textPrimary)
                                .colorScheme(.dark)
                        }

                        // MARK: Save Button
                        Button {
                            let alarm = Alarm(
                                time: selectedTime,
                                pushupCount: pushupCount,
                                isActive: true,
                                repeatDays: repeatDays,
                                label: label
                            )
                            onSave(alarm)
                            dismiss()
                        } label: {
                            Text("Set Alarm")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Theme.accent)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Section Label Helper
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(Theme.textTertiary)
            .tracking(1.2)
    }
}

#Preview {
    AlarmSetupView { _ in }
}
