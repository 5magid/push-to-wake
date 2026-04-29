import Foundation

struct Alarm: Identifiable, Codable {
    var id: UUID = UUID()
    var time: Date
    var pushupCount: Int
    var isActive: Bool = true
    var repeatDays: Set<Weekday> = []
    var label: String = ""

    enum Weekday: Int, Codable, CaseIterable {
        case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

        var shortName: String {
            switch self {
            case .sunday: return "Su"
            case .monday: return "Mo"
            case .tuesday: return "Tu"
            case .wednesday: return "We"
            case .thursday: return "Th"
            case .friday: return "Fr"
            case .saturday: return "Sa"
            }
        }
    }
}
