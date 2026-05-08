import Foundation
import CoreLocation
import Adhan

@MainActor
@Observable
final class PrayerTimeService {
    enum LoadPolicy {
        case preferCache
        case refresh
    }

    var todaySchedule: DailyPrayerSchedule?
    var weekSchedules: [DailyPrayerSchedule] = []
    var currentSegment: PrayerSegment = .dhuhrToAsr
    var nextPrayerName: String = ""
    var timeUntilNextPrayer: TimeInterval = 0
    var isLoading: Bool = false
    var dataSourceLabel: String = PrayerTimesDataSource.deviceCalculation.displayName
    var lastErrorMessage: String?

    private var countdownTimer: Timer?
    private let publicAPI = PublicPrayerTimesAPI()
    private let cacheStore = PrayerScheduleCacheStore()
    private var activeCalculationID: UInt64 = 0
    private var loadedRequestKey: String?
    private var loadedSchedulesExpiry: Date?

    func calculate(
        for location: CLLocation,
        settings: UserSettings,
        loadPolicy: LoadPolicy = .preferCache
    ) async {
        let requestKey = cacheKey(for: location, settings: settings)
        let expiry = nextDayBoundary(after: Date())

        if loadPolicy == .preferCache, hasFreshInMemorySchedules(for: requestKey, expiry: expiry) {
            lastErrorMessage = nil
            isLoading = false
            refreshCurrentState()
            return
        }

        activeCalculationID &+= 1
        let calculationID = activeCalculationID

        isLoading = true
        lastErrorMessage = nil
        var restoredFromCache = false

        if let cached = await cacheStore.loadWeek(for: location, settings: settings),
           calculationID == activeCalculationID {
            restoredFromCache = true
            applySchedules(
                cached.schedules,
                sourceLabel: cached.sourceLabel,
                requestKey: requestKey,
                expiry: expiry
            )
            isLoading = false

            if loadPolicy == .preferCache {
                refreshCurrentState()
                return
            }
        }

        do {
            let schedules = try await loadSchedules(for: location, settings: settings)
            guard calculationID == activeCalculationID else { return }

            applySchedules(
                schedules,
                sourceLabel: settings.prayerDataSource.displayName,
                requestKey: requestKey,
                expiry: expiry
            )
            await cacheStore.save(
                schedules: schedules,
                for: location,
                settings: settings,
                sourceLabel: settings.prayerDataSource.displayName
            )
        } catch {
            guard calculationID == activeCalculationID else { return }

            if restoredFromCache {
                lastErrorMessage = error.localizedDescription
                isLoading = false
                refreshCurrentState()
                return
            }

            let schedules = makeLocalSchedules(for: location, settings: settings)
            applySchedules(
                schedules,
                sourceLabel: PrayerTimesDataSource.deviceCalculation.displayName,
                requestKey: requestKey,
                expiry: expiry
            )
            lastErrorMessage = error.localizedDescription
            await cacheStore.save(
                schedules: schedules,
                for: location,
                settings: settings,
                sourceLabel: PrayerTimesDataSource.deviceCalculation.displayName
            )
        }

        guard calculationID == activeCalculationID else { return }
        isLoading = false
        refreshCurrentState()
    }

    func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshCurrentState() }
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

    private func applySchedules(
        _ schedules: [DailyPrayerSchedule],
        sourceLabel: String,
        requestKey: String,
        expiry: Date
    ) {
        weekSchedules = schedules
        todaySchedule = schedules.first { Calendar.current.isDateInToday($0.date) } ?? schedules.first
        dataSourceLabel = sourceLabel
        loadedRequestKey = requestKey
        loadedSchedulesExpiry = expiry
    }

    private func hasFreshInMemorySchedules(for requestKey: String, expiry: Date) -> Bool {
        guard !weekSchedules.isEmpty,
              loadedRequestKey == requestKey,
              (loadedSchedulesExpiry ?? .distantPast) > Date()
        else { return false }

        if loadedSchedulesExpiry != expiry {
            loadedSchedulesExpiry = expiry
        }
        return true
    }

    private func loadSchedules(for location: CLLocation, settings: UserSettings) async throws -> [DailyPrayerSchedule] {
        switch settings.prayerDataSource {
        case .deviceCalculation:
            return makeLocalSchedules(for: location, settings: settings)
        case .alAdhanAPI:
            return try await publicAPI.fetchWeekSchedules(
                from: Date(),
                location: location,
                calculationMethod: settings.calculationMethod,
                madhab: settings.madhab
            )
        }
    }

    private func makeLocalSchedules(for location: CLLocation, settings: UserSettings) -> [DailyPrayerSchedule] {
        let today = Date()
        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            return makeSchedule(for: date, location: location, settings: settings)
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
        case .muslimWorldLeague:     return CalculationMethod.muslimWorldLeague.params
        case .northAmerica:          return CalculationMethod.northAmerica.params
        case .egyptian:              return CalculationMethod.egyptian.params
        case .ummAlQura:             return CalculationMethod.ummAlQura.params
        case .karachi:               return CalculationMethod.karachi.params
        case .dubai:                 return CalculationMethod.dubai.params
        case .kuwait:                return CalculationMethod.kuwait.params
        case .qatar:                 return CalculationMethod.qatar.params
        case .singapore:             return CalculationMethod.singapore.params
        case .moonsightingCommittee: return CalculationMethod.moonsightingCommittee.params
        case .turkey:                return CalculationMethod.turkey.params
        case .tehran:                return CalculationMethod.tehran.params
        }
    }

    private func cacheKey(for location: CLLocation, settings: UserSettings) -> String {
        let lat = roundedCoordinate(location.coordinate.latitude)
        let lon = roundedCoordinate(location.coordinate.longitude)
        return [
            settings.prayerDataSource.rawValue,
            settings.calculationMethod.rawValue,
            settings.madhab.rawValue,
            lat,
            lon
        ].joined(separator: "|")
    }

    private func roundedCoordinate(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func nextDayBoundary(after date: Date) -> Date {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86_400)
    }
}

private actor PrayerScheduleCacheStore {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxEntries = 12
    private let groupID = "group.PrayPlan"

    struct CacheHit {
        let schedules: [DailyPrayerSchedule]
        let sourceLabel: String
    }

    func loadWeek(for location: CLLocation, settings: UserSettings) -> CacheHit? {
        var snapshot = loadSnapshot()
        let now = Date()

        snapshot.entries.removeAll { $0.cleanupDeadline <= now }

        guard let index = snapshot.entries.firstIndex(where: {
            $0.requestKey == requestKey(for: location, settings: settings) && $0.expiresAt > now
        }) else {
            persist(snapshot)
            return nil
        }

        snapshot.entries[index].lastAccessedAt = now
        let entry = snapshot.entries[index]
        persist(snapshot)

        let schedules = entry.schedules.map(\.schedule)
        guard !schedules.isEmpty else { return nil }
        return CacheHit(schedules: schedules, sourceLabel: entry.sourceLabel)
    }

    func save(
        schedules: [DailyPrayerSchedule],
        for location: CLLocation,
        settings: UserSettings,
        sourceLabel: String
    ) {
        guard !schedules.isEmpty else { return }

        var snapshot = loadSnapshot()
        let now = Date()
        let key = requestKey(for: location, settings: settings)
        let expiry = nextDayBoundary(after: now)
        let cleanupDeadline = expiry.addingTimeInterval(2 * 86_400)

        snapshot.entries.removeAll {
            $0.requestKey == key || $0.cleanupDeadline <= now
        }

        snapshot.entries.append(
            PrayerScheduleCacheEntry(
                requestKey: key,
                sourceLabel: sourceLabel,
                createdAt: now,
                expiresAt: expiry,
                cleanupDeadline: cleanupDeadline,
                lastAccessedAt: now,
                schedules: schedules.map(CachedDailyPrayerSchedule.init(schedule:))
            )
        )

        snapshot.entries.sort { $0.lastAccessedAt > $1.lastAccessedAt }
        if snapshot.entries.count > maxEntries {
            snapshot.entries = Array(snapshot.entries.prefix(maxEntries))
        }

        persist(snapshot)
    }

    private func requestKey(for location: CLLocation, settings: UserSettings) -> String {
        let lat = roundedCoordinate(location.coordinate.latitude)
        let lon = roundedCoordinate(location.coordinate.longitude)
        return [
            settings.prayerDataSource.rawValue,
            settings.calculationMethod.rawValue,
            settings.madhab.rawValue,
            lat,
            lon
        ].joined(separator: "|")
    }

    private func roundedCoordinate(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func nextDayBoundary(after date: Date) -> Date {
        let startOfDay = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(86_400)
    }

    private func loadSnapshot() -> PrayerScheduleCacheSnapshot {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let snapshot = try? decoder.decode(PrayerScheduleCacheSnapshot.self, from: data) else {
            return PrayerScheduleCacheSnapshot(entries: [])
        }
        return snapshot
    }

    private func persist(_ snapshot: PrayerScheduleCacheSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }

        let directory = cacheFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        try? data.write(to: cacheFileURL, options: .atomic)
    }

    private var cacheFileURL: URL {
        let fileManager = FileManager.default
        if let container = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return container.appendingPathComponent("PrayerScheduleCache.json")
        }

        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport
            .appendingPathComponent("PrayPlan", isDirectory: true)
            .appendingPathComponent("PrayerScheduleCache.json")
    }
}

private struct PrayerScheduleCacheSnapshot: Codable {
    var entries: [PrayerScheduleCacheEntry]
}

private struct PrayerScheduleCacheEntry: Codable {
    var requestKey: String
    var sourceLabel: String
    var createdAt: Date
    var expiresAt: Date
    var cleanupDeadline: Date
    var lastAccessedAt: Date
    var schedules: [CachedDailyPrayerSchedule]
}

private struct CachedDailyPrayerSchedule: Codable {
    var date: Date
    var fajr: Date
    var sunrise: Date
    var dhuhr: Date
    var asr: Date
    var maghrib: Date
    var isha: Date

    init(schedule: DailyPrayerSchedule) {
        date = schedule.date
        fajr = schedule.fajr
        sunrise = schedule.sunrise
        dhuhr = schedule.dhuhr
        asr = schedule.asr
        maghrib = schedule.maghrib
        isha = schedule.isha
    }

    var schedule: DailyPrayerSchedule {
        DailyPrayerSchedule(
            date: date,
            fajr: fajr,
            sunrise: sunrise,
            dhuhr: dhuhr,
            asr: asr,
            maghrib: maghrib,
            isha: isha
        )
    }
}

private struct PublicPrayerTimesAPI {
    private let session: URLSession
    private let calendar = Calendar.current

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeekSchedules(
        from startDate: Date,
        location: CLLocation,
        calculationMethod: CalculationMethodOption,
        madhab: MadhabOption
    ) async throws -> [DailyPrayerSchedule] {
        let dates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate)
        }

        var schedules: [DailyPrayerSchedule] = []
        schedules.reserveCapacity(dates.count)

        for date in dates {
            schedules.append(
                try await fetchSchedule(
                    for: date,
                    location: location,
                    calculationMethod: calculationMethod,
                    madhab: madhab
                )
            )
        }

        return schedules
    }

    private func fetchSchedule(
        for date: Date,
        location: CLLocation,
        calculationMethod: CalculationMethodOption,
        madhab: MadhabOption
    ) async throws -> DailyPrayerSchedule {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "dd-MM-yyyy"

        var components = URLComponents(string: "https://api.aladhan.com/v1/timings/\(formatter.string(from: date))")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(location.coordinate.longitude)),
            URLQueryItem(name: "method", value: String(calculationMethod.alAdhanMethodID)),
            URLQueryItem(name: "school", value: madhab == .hanafi ? "1" : "0")
        ]

        guard let url = components?.url else {
            throw PrayerTimesAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw PrayerTimesAPIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AlAdhanTimingsResponse.self, from: data)
        guard decoded.code == 200 else {
            throw PrayerTimesAPIError.apiFailure(decoded.status)
        }

        return try decoded.data.toSchedule(for: date)
    }
}

private enum PrayerTimesAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiFailure(String)
    case invalidTime(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL API invalide."
        case .invalidResponse:
            return "Réponse API invalide."
        case .apiFailure(let status):
            return "L'API a échoué: \(status)"
        case .invalidTime(let prayer):
            return "Horaire invalide pour \(prayer)."
        }
    }
}

private struct AlAdhanTimingsResponse: Decodable {
    let code: Int
    let status: String
    let data: AlAdhanTimingData
}

private struct AlAdhanTimingData: Decodable {
    let timings: AlAdhanTimings
    let meta: AlAdhanMeta

    func toSchedule(for date: Date) throws -> DailyPrayerSchedule {
        let timeZone = TimeZone(identifier: meta.timezone) ?? .current
        return DailyPrayerSchedule(
            date: date,
            fajr: try timings.date(for: .fajr, on: date, timeZone: timeZone),
            sunrise: try timings.date(for: .sunrise, on: date, timeZone: timeZone),
            dhuhr: try timings.date(for: .dhuhr, on: date, timeZone: timeZone),
            asr: try timings.date(for: .asr, on: date, timeZone: timeZone),
            maghrib: try timings.date(for: .maghrib, on: date, timeZone: timeZone),
            isha: try timings.date(for: .isha, on: date, timeZone: timeZone)
        )
    }
}

private struct AlAdhanMeta: Decodable {
    let timezone: String
}

private struct AlAdhanTimings: Decodable {
    let fajr: String
    let sunrise: String
    let dhuhr: String
    let asr: String
    let maghrib: String
    let isha: String

    enum CodingKeys: String, CodingKey {
        case fajr = "Fajr"
        case sunrise = "Sunrise"
        case dhuhr = "Dhuhr"
        case asr = "Asr"
        case maghrib = "Maghrib"
        case isha = "Isha"
    }

    func date(for prayer: PrayerField, on date: Date, timeZone: TimeZone) throws -> Date {
        let rawValue: String
        switch prayer {
        case .fajr:
            rawValue = fajr
        case .sunrise:
            rawValue = sunrise
        case .dhuhr:
            rawValue = dhuhr
        case .asr:
            rawValue = asr
        case .maghrib:
            rawValue = maghrib
        case .isha:
            rawValue = isha
        }

        let cleaned = rawValue
            .components(separatedBy: " ")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? rawValue

        let pieces = cleaned.split(separator: ":")
        guard pieces.count >= 2,
              let hour = Int(pieces[0]),
              let minute = Int(pieces[1]) else {
            throw PrayerTimesAPIError.invalidTime(prayer.rawValue)
        }

        var calendar = Calendar.current
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = timeZone

        guard let result = calendar.date(from: components) else {
            throw PrayerTimesAPIError.invalidTime(prayer.rawValue)
        }

        return result
    }
}

private enum PrayerField: String {
    case fajr = "Fajr"
    case sunrise = "Sunrise"
    case dhuhr = "Dhuhr"
    case asr = "Asr"
    case maghrib = "Maghrib"
    case isha = "Isha"
}

private extension CalculationMethodOption {
    var alAdhanMethodID: Int {
        switch self {
        case .karachi:               return 1
        case .northAmerica:          return 2
        case .muslimWorldLeague:     return 3
        case .ummAlQura:             return 4
        case .egyptian:              return 5
        case .tehran:                return 7
        case .kuwait:                return 9
        case .qatar:                 return 10
        case .singapore:             return 11
        case .turkey:                return 13
        case .moonsightingCommittee: return 15
        case .dubai:                 return 16
        }
    }
}
