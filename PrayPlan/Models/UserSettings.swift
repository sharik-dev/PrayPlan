import Foundation
import SwiftData

enum CalculationMethodOption: String, CaseIterable, Identifiable {
    case muslimWorldLeague     = "muslimWorldLeague"
    case northAmerica          = "northAmerica"
    case egyptian              = "egyptian"
    case ummAlQura             = "ummAlQura"
    case karachi               = "karachi"
    case dubai                 = "dubai"
    case kuwait                = "kuwait"
    case qatar                 = "qatar"
    case singapore             = "singapore"
    case moonsightingCommittee = "moonsightingCommittee"
    case turkey                = "turkey"
    case tehran                = "tehran"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .muslimWorldLeague:     return "Muslim World League"
        case .northAmerica:          return "ISNA (Amérique du Nord)"
        case .egyptian:              return "Autorité Égyptienne"
        case .ummAlQura:             return "Umm Al-Qura (La Mecque)"
        case .karachi:               return "Université de Karachi"
        case .dubai:                 return "Dubaï"
        case .kuwait:                return "Koweït"
        case .qatar:                 return "Qatar"
        case .singapore:             return "Singapour (MUIS)"
        case .moonsightingCommittee: return "Moonsighting Committee"
        case .turkey:                return "Turquie"
        case .tehran:                return "Téhéran"
        }
    }
}

enum MadhabOption: String, CaseIterable, Identifiable {
    case shafi  = "shafi"
    case hanafi = "hanafi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .shafi:  return "Shafi'i / Maliki / Hanbali"
        case .hanafi: return "Hanafi"
        }
    }
}

enum AzanSound: String, CaseIterable, Identifiable {
    case azan   = "azan"
    case beep   = "beep"
    case silent = "silent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .azan:   return String(localized: "sound.azan",   defaultValue: "Azan")
        case .beep:   return String(localized: "sound.beep",   defaultValue: "Bip")
        case .silent: return String(localized: "sound.silent", defaultValue: "Silencieux")
        }
    }

    var icon: String {
        switch self {
        case .azan:   return "speaker.wave.3.fill"
        case .beep:   return "bell.fill"
        case .silent: return "bell.slash.fill"
        }
    }

    var soundFileName: String? {
        switch self {
        case .azan:   return "azan.caf"
        case .beep:   return "beep.caf"
        case .silent: return nil
        }
    }
}

@Model
final class UserSettings {
    var calculationMethodRaw: String = CalculationMethodOption.muslimWorldLeague.rawValue
    var madhabRaw: String            = MadhabOption.shafi.rawValue
    var azanSoundRaw: String         = AzanSound.azan.rawValue
    var enabledPrayers: [String]     = ["fajr", "dhuhr", "asr", "maghrib", "isha"]
    var locationLat: Double          = 48.8566
    var locationLon: Double          = 2.3522
    var locationName: String         = "Paris"
    var useAutoLocation: Bool        = true
    var createdAt: Date              = Date()

    init() {}

    var calculationMethod: CalculationMethodOption {
        get { CalculationMethodOption(rawValue: calculationMethodRaw) ?? .muslimWorldLeague }
        set { calculationMethodRaw = newValue.rawValue }
    }

    var madhab: MadhabOption {
        get { MadhabOption(rawValue: madhabRaw) ?? .shafi }
        set { madhabRaw = newValue.rawValue }
    }

    var azanSound: AzanSound {
        get { AzanSound(rawValue: azanSoundRaw) ?? .azan }
        set { azanSoundRaw = newValue.rawValue }
    }

    func isPrayerEnabled(_ key: String) -> Bool {
        enabledPrayers.contains(key)
    }

    func togglePrayer(_ key: String) {
        if enabledPrayers.contains(key) {
            enabledPrayers.removeAll { $0 == key }
        } else {
            enabledPrayers.append(key)
        }
    }
}
