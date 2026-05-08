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
    static let fajrColor    = Color(red: 0.28, green: 0.37, blue: 0.63)
    static let sunriseColor = Color(red: 0.78, green: 0.47, blue: 0.29)
    static let dhuhrColor   = Color(red: 0.77, green: 0.60, blue: 0.28)
    static let asrColor     = Color(red: 0.82, green: 0.58, blue: 0.33)
    static let maghribColor = Color(red: 0.58, green: 0.37, blue: 0.63)
    static let ishaColor    = Color(red: 0.24, green: 0.27, blue: 0.44)
    static let brandGreen   = Color(red: 0.18, green: 0.49, blue: 0.20)
}

extension PrayerSegment {
    var bannerGradient: LinearGradient {
        switch self {
        case .fajrToSunrise:
            return LinearGradient(colors: [Color(red: 0.23, green: 0.29, blue: 0.50), Color(red: 0.40, green: 0.51, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .sunriseToDhuhr:
            return LinearGradient(colors: [Color(red: 0.66, green: 0.37, blue: 0.19), Color(red: 0.90, green: 0.63, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .dhuhrToAsr:
            return LinearGradient(colors: [Color(red: 0.64, green: 0.49, blue: 0.20), Color(red: 0.90, green: 0.73, blue: 0.43)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .asrToMaghrib:
            return LinearGradient(colors: [Color(red: 0.71, green: 0.49, blue: 0.24), Color(red: 0.91, green: 0.72, blue: 0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .maghribToIsha:
            return LinearGradient(colors: [Color(red: 0.45, green: 0.27, blue: 0.52), Color(red: 0.73, green: 0.48, blue: 0.74)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ishaTofajr:
            return LinearGradient(colors: [Color(red: 0.18, green: 0.20, blue: 0.34), Color(red: 0.34, green: 0.37, blue: 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var bandColor: Color {
        switch self {
        case .fajrToSunrise:  return Color(red: 0.33, green: 0.43, blue: 0.68)
        case .sunriseToDhuhr: return Color(red: 0.84, green: 0.56, blue: 0.34)
        case .dhuhrToAsr:     return Color(red: 0.82, green: 0.67, blue: 0.35)
        case .asrToMaghrib:   return Color(red: 0.85, green: 0.62, blue: 0.38)
        case .maghribToIsha:  return Color(red: 0.63, green: 0.44, blue: 0.69)
        case .ishaTofajr:     return Color(red: 0.30, green: 0.34, blue: 0.52)
        }
    }

    var softFill: Color {
        bandColor.opacity(0.14)
    }

    var softStroke: Color {
        bandColor.opacity(0.28)
    }
}
