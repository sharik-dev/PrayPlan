import Foundation
import SwiftData

enum HabitFrequency: String, CaseIterable, Identifiable, Codable {
    case daily    = "daily"
    case weekdays = "weekdays"
    case weekends = "weekends"
    case custom   = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily:    return String(localized: "frequency.daily",    defaultValue: "Quotidien")
        case .weekdays: return String(localized: "frequency.weekdays", defaultValue: "Semaine")
        case .weekends: return String(localized: "frequency.weekends", defaultValue: "Week-end")
        case .custom:   return String(localized: "frequency.custom",   defaultValue: "Personnalisé")
        }
    }

    func isActive(on date: Date, customDays: Set<Int> = []) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch self {
        case .daily:    return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .custom:   return customDays.isEmpty || customDays.contains(weekday)
        }
    }
}

@Model
final class UserHabit {
    var id: UUID           = UUID()
    var title: String      = ""
    var iconName: String   = "star.fill"
    var segmentRaw: String = PrayerSegment.fajrToSunrise.rawValue
    var frequencyRaw: String = HabitFrequency.daily.rawValue
    var colorHex: String   = "#2E7D32"
    var createdAt: Date    = Date()
    var isArchived: Bool   = false
    var customDaysRaw: String = ""

    @Relationship(deleteRule: .cascade)
    var completions: [HabitCompletion] = []

    init(title: String,
         iconName: String = "star.fill",
         segment: PrayerSegment,
         frequency: HabitFrequency = .daily,
         colorHex: String = "#2E7D32") {
        self.id          = UUID()
        self.title       = title
        self.iconName    = iconName
        self.segmentRaw  = segment.rawValue
        self.frequencyRaw = frequency.rawValue
        self.colorHex    = colorHex
        self.createdAt   = Date()
    }

    var segment: PrayerSegment {
        get { PrayerSegment(rawValue: segmentRaw) ?? .fajrToSunrise }
        set { segmentRaw = newValue.rawValue }
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var customDays: Set<Int> {
        get { Set(customDaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { customDaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    func isActiveOn(_ date: Date) -> Bool {
        frequency.isActive(on: date, customDays: customDays)
    }

    func isActiveToday() -> Bool { isActiveOn(Date()) }

    func isCompleted(on date: Date) -> Bool {
        let normalized = Calendar.current.startOfDay(for: date)
        return completions.contains {
            Calendar.current.startOfDay(for: $0.completedOn) == normalized
        }
    }

    var currentStreak: Int {
        var streak = 0
        var day = Calendar.current.startOfDay(for: Date())
        while isCompleted(on: day) {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}
