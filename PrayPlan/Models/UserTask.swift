import Foundation
import SwiftData

enum TaskPriority: String, CaseIterable, Identifiable, Codable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .low:    return String(localized: "priority.low",    defaultValue: "Faible")
        case .medium: return String(localized: "priority.medium", defaultValue: "Normale")
        case .high:   return String(localized: "priority.high",   defaultValue: "Haute")
        }
    }

    var icon: String {
        switch self {
        case .low:    return "arrow.down.circle"
        case .medium: return "minus.circle"
        case .high:   return "exclamationmark.circle.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .low:    return "secondary"
        case .medium: return "blue"
        case .high:   return "red"
        }
    }
}

@Model
final class UserTask {
    var id: UUID         = UUID()
    var title: String    = ""
    var notes: String    = ""
    var segmentRaw: String   = PrayerSegment.dhuhrToAsr.rawValue
    var priorityRaw: String  = TaskPriority.medium.rawValue
    var isCompleted: Bool    = false
    var dueDate: Date?       = nil
    var createdAt: Date      = Date()
    var completedAt: Date?   = nil

    init(title: String,
         segment: PrayerSegment,
         priority: TaskPriority = .medium,
         notes: String = "",
         dueDate: Date? = nil) {
        self.id          = UUID()
        self.title       = title
        self.segmentRaw  = segment.rawValue
        self.priorityRaw = priority.rawValue
        self.notes       = notes
        self.dueDate     = dueDate
        self.createdAt   = Date()
    }

    var segment: PrayerSegment {
        get { PrayerSegment(rawValue: segmentRaw) ?? .dhuhrToAsr }
        set { segmentRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .medium }
        set { priorityRaw = newValue.rawValue }
    }
}
