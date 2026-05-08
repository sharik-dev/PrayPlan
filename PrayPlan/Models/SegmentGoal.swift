import Foundation
import SwiftData

@Model
final class SegmentGoal {
    var segmentRaw: String    = ""
    var themeName: String     = ""
    var themeIcon: String     = ""
    var themeColorHex: String = ""
    var intention: String     = ""
    var rulesRaw: String      = ""        // newline-separated rules
    var sortIndex: Int        = 0

    init(segment: PrayerSegment) {
        self.segmentRaw = segment.rawValue
        self.sortIndex  = PrayerSegment.allCases.firstIndex(of: segment) ?? 0
    }

    var segment: PrayerSegment {
        PrayerSegment(rawValue: segmentRaw) ?? .fajrToSunrise
    }

    var rules: [String] {
        get { rulesRaw.split(separator: "\n", omittingEmptySubsequences: true).map(String.init) }
        set { rulesRaw = newValue.joined(separator: "\n") }
    }

    var hasContent: Bool { !themeName.isEmpty || !intention.isEmpty }
}
