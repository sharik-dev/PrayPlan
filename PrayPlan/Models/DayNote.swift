import Foundation
import SwiftData

@Model
final class DayNote {
    var id: UUID = UUID()
    var content: String = ""
    var dayStart: Date = Date()
    var hour: Int = 8
    var createdAt: Date = Date()

    init(hour: Int, dayStart: Date, content: String = "") {
        self.hour     = hour
        self.dayStart = Calendar.current.startOfDay(for: dayStart)
        self.content  = content
    }
}
