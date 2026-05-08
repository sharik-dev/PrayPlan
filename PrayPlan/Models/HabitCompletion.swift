import Foundation
import SwiftData

@Model
final class HabitCompletion {
    var id: UUID         = UUID()
    var completedOn: Date = Date()
    var habit: UserHabit?

    init(completedOn: Date = .now) {
        self.id          = UUID()
        self.completedOn = Calendar.current.startOfDay(for: completedOn)
    }
}
