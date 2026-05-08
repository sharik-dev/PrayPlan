import Foundation
import CoreLocation
import Adhan

@Observable
final class PrayerTimeService {
    var todaySchedule: DailyPrayerSchedule?
    var weekSchedules: [DailyPrayerSchedule] = []
    var currentSegment: PrayerSegment = .dhuhrToAsr
    var nextPrayerName: String = ""
    var timeUntilNextPrayer: TimeInterval = 0
    var isLoading: Bool = false

    private var countdownTimer: Timer?

    func calculate(for location: CLLocation, settings: UserSettings) {
        isLoading = true
        let today = Date()
        weekSchedules = (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: today)
            else { return nil }
            return makeSchedule(for: date, location: location, settings: settings)
        }
        todaySchedule = weekSchedules.first
        isLoading = false
        refreshCurrentState()
    }

    func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refreshCurrentState()
        }
    }

    func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func refreshCurrentState() {
        guard let schedule = todaySchedule else { return }
        let now = Date()
        currentSegment = schedule.currentSegment(at: now)
        if let next = schedule.nextPrayer(after: now) {
            nextPrayerName = next.name
            timeUntilNextPrayer = next.time.timeIntervalSince(now)
        } else {
            nextPrayerName = String(localized: "prayer.fajr", defaultValue: "Fajr")
            timeUntilNextPrayer = schedule.fajr.addingTimeInterval(86400).timeIntervalSince(now)
        }
    }

    private func makeSchedule(for date: Date,
                               location: CLLocation,
                               settings: UserSettings) -> DailyPrayerSchedule? {
        let coords = Coordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        var params = adhanParams(for: settings.calculationMethod)
        params.madhab = settings.madhab == .hanafi ? .hanafi : .shafi

        let dc = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let times = PrayerTimes(coordinates: coords, date: dc, calculationParameters: params)
        else { return nil }

        return DailyPrayerSchedule(
            date: date,
            fajr:    times.fajr,
            sunrise: times.sunrise,
            dhuhr:   times.dhuhr,
            asr:     times.asr,
            maghrib: times.maghrib,
            isha:    times.isha
        )
    }

    private func adhanParams(for method: CalculationMethodOption) -> CalculationParameters {
        switch method {
        case .muslimWorldLeague:     return CalculationMethod.muslimWorldLeague.calculationParameters()
        case .northAmerica:          return CalculationMethod.northAmerica.calculationParameters()
        case .egyptian:              return CalculationMethod.egyptian.calculationParameters()
        case .ummAlQura:             return CalculationMethod.ummAlQura.calculationParameters()
        case .karachi:               return CalculationMethod.karachi.calculationParameters()
        case .dubai:                 return CalculationMethod.dubai.calculationParameters()
        case .kuwait:                return CalculationMethod.kuwait.calculationParameters()
        case .qatar:                 return CalculationMethod.qatar.calculationParameters()
        case .singapore:             return CalculationMethod.singapore.calculationParameters()
        case .moonsightingCommittee: return CalculationMethod.moonsightingCommittee.calculationParameters()
        case .turkey:                return CalculationMethod.turkey.calculationParameters()
        case .tehran:                return CalculationMethod.tehran.calculationParameters()
        }
    }
}
