import SwiftUI

enum PrayerSegment: String, CaseIterable, Identifiable, Codable {
    case fajrToSunrise   = "fajrToSunrise"
    case sunriseToDhuhr  = "sunriseToDhuhr"
    case dhuhrToAsr      = "dhuhrToAsr"
    case asrToMaghrib    = "asrToMaghrib"
    case maghribToIsha   = "maghribToIsha"
    case ishaTofajr      = "ishaTofajr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fajrToSunrise:  return String(localized: "segment.fajrToSunrise", defaultValue: "Fajr → Lever")
        case .sunriseToDhuhr: return String(localized: "segment.sunriseToDhuhr", defaultValue: "Lever → Dhuhr")
        case .dhuhrToAsr:     return String(localized: "segment.dhuhrToAsr",     defaultValue: "Dhuhr → Asr")
        case .asrToMaghrib:   return String(localized: "segment.asrToMaghrib",   defaultValue: "Asr → Maghrib")
        case .maghribToIsha:  return String(localized: "segment.maghribToIsha",  defaultValue: "Maghrib → Isha")
        case .ishaTofajr:     return String(localized: "segment.ishaTofajr",     defaultValue: "Isha → Fajr")
        }
    }

    var color: Color {
        switch self {
        case .fajrToSunrise:  return .fajrColor
        case .sunriseToDhuhr: return .sunriseColor
        case .dhuhrToAsr:     return .dhuhrColor
        case .asrToMaghrib:   return .asrColor
        case .maghribToIsha:  return .maghribColor
        case .ishaTofajr:     return .ishaColor
        }
    }

    var systemIcon: String {
        switch self {
        case .fajrToSunrise:  return "moon.stars.fill"
        case .sunriseToDhuhr: return "sunrise.fill"
        case .dhuhrToAsr:     return "sun.max.fill"
        case .asrToMaghrib:   return "sun.haze.fill"
        case .maghribToIsha:  return "sunset.fill"
        case .ishaTofajr:     return "moon.fill"
        }
    }
}

struct DailyPrayerSchedule {
    let date: Date
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    func currentSegment(at now: Date = .now) -> PrayerSegment {
        if now < fajr    { return .ishaTofajr }
        if now < sunrise { return .fajrToSunrise }
        if now < dhuhr   { return .sunriseToDhuhr }
        if now < asr     { return .dhuhrToAsr }
        if now < maghrib { return .asrToMaghrib }
        if now < isha    { return .maghribToIsha }
        return .ishaTofajr
    }

    func startTime(of segment: PrayerSegment) -> Date {
        switch segment {
        case .fajrToSunrise:  return fajr
        case .sunriseToDhuhr: return sunrise
        case .dhuhrToAsr:     return dhuhr
        case .asrToMaghrib:   return asr
        case .maghribToIsha:  return maghrib
        case .ishaTofajr:     return isha
        }
    }

    func endTime(of segment: PrayerSegment) -> Date {
        switch segment {
        case .fajrToSunrise:  return sunrise
        case .sunriseToDhuhr: return dhuhr
        case .dhuhrToAsr:     return asr
        case .asrToMaghrib:   return maghrib
        case .maghribToIsha:  return isha
        case .ishaTofajr:     return Calendar.current.date(byAdding: .day, value: 1, to: fajr) ?? fajr
        }
    }

    func progress(of segment: PrayerSegment, at now: Date = .now) -> Double {
        let start = startTime(of: segment)
        let end   = endTime(of: segment)
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return max(0, min(1, now.timeIntervalSince(start) / total))
    }

    var allPrayers: [(name: String, arabicName: String, time: Date, key: String)] {
        [
            (String(localized: "prayer.fajr",    defaultValue: "Fajr"),    "الفجر",  fajr,    "fajr"),
            (String(localized: "prayer.sunrise",  defaultValue: "Lever"),   "الشروق", sunrise, "sunrise"),
            (String(localized: "prayer.dhuhr",    defaultValue: "Dhuhr"),   "الظهر",  dhuhr,   "dhuhr"),
            (String(localized: "prayer.asr",      defaultValue: "Asr"),     "العصر",  asr,     "asr"),
            (String(localized: "prayer.maghrib",  defaultValue: "Maghrib"), "المغرب", maghrib, "maghrib"),
            (String(localized: "prayer.isha",     defaultValue: "Isha"),    "العشاء", isha,    "isha"),
        ]
    }

    func nextPrayer(after now: Date = .now) -> (name: String, time: Date, key: String)? {
        allPrayers.first { $0.time > now }.map { ($0.name, $0.time, $0.key) }
    }
}

extension Color {
    static let fajrColor    = Color(red: 0.10, green: 0.14, blue: 0.49)
    static let sunriseColor = Color(red: 0.90, green: 0.32, blue: 0.00)
    static let dhuhrColor   = Color(red: 0.80, green: 0.52, blue: 0.00)
    static let asrColor     = Color(red: 0.96, green: 0.60, blue: 0.00)
    static let maghribColor = Color(red: 0.42, green: 0.11, blue: 0.60)
    static let ishaColor    = Color(red: 0.05, green: 0.05, blue: 0.17)
    static let brandGreen   = Color(red: 0.18, green: 0.49, blue: 0.20)
}
