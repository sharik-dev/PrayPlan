import Foundation
import SwiftData

@Model
final class AppBlockingProfile {
    var segmentRaw: String = ""
    var isEnabled: Bool = false
    var selectionData: Data?

    init(segment: PrayerSegment) {
        self.segmentRaw = segment.rawValue
    }

    var segment: PrayerSegment {
        PrayerSegment(rawValue: segmentRaw) ?? .fajrToSunrise
    }

    // 0 = aucun accès (matin), 5 = accès total (soir)
    var dopamineLevel: Int {
        switch segment {
        case .fajrToSunrise:  return 0
        case .sunriseToDhuhr: return 1
        case .dhuhrToAsr:     return 2
        case .asrToMaghrib:   return 3
        case .maghribToIsha:  return 4
        case .ishaTofajr:     return 5
        }
    }

    var hasAppsSelected: Bool {
        selectionData != nil
    }
}
