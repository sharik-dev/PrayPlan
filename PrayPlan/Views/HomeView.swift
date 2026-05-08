import SwiftUI
import SwiftData
import CoreLocation

struct HomeView: View {
    @Environment(LocationService.self)   private var locationService
    @Environment(PrayerTimeService.self) private var prayerService
    @Environment(NotificationService.self) private var notifService
    @Query private var settings: [UserSettings]

    private var currentSettings: UserSettings? { settings.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if locationService.authorizationStatus == .denied
                        || locationService.authorizationStatus == .restricted {
                        LocationDeniedBanner()
                    }

                    if let schedule = prayerService.todaySchedule {
                        CurrentSegmentHero(
                            schedule: schedule,
                            segment: prayerService.currentSegment,
                            nextPrayerName: prayerService.nextPrayerName,
                            timeRemaining: prayerService.timeUntilNextPrayer
                        )
                        PrayerDataSourceCard(
                            sourceLabel: prayerService.dataSourceLabel,
                            errorMessage: prayerService.lastErrorMessage
                        )
                        PrayerTimeline(schedule: schedule, currentSegment: prayerService.currentSegment)
                    } else {
                        LoadingCard()
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(locationService.cityName.isEmpty ? "PrayPlan" : locationService.cityName)
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { bootstrap() }
        .onChange(of: currentSettings?.createdAt) { _, _ in
            bootstrap()
        }
        .onChange(of: locationService.currentLocation) { _, location in
            guard let loc = location, let s = currentSettings else { return }
            Task {
                await prayerService.calculate(for: loc, settings: s)
                notifService.scheduleForWeek(schedules: prayerService.weekSchedules, settings: s)
            }
        }
        .onAppear { prayerService.startCountdown() }
        .onDisappear { prayerService.stopCountdown() }
    }

    private func bootstrap() {
        locationService.requestAndFetch()
        if let loc = locationService.currentLocation, let s = currentSettings {
            Task {
                await prayerService.calculate(for: loc, settings: s)
                notifService.scheduleForWeek(schedules: prayerService.weekSchedules, settings: s)
            }
        } else if let s = currentSettings, !s.useAutoLocation {
            let fakeLoc = CLLocationFromSettings(s)
            Task {
                await prayerService.calculate(for: fakeLoc, settings: s)
                notifService.scheduleForWeek(schedules: prayerService.weekSchedules, settings: s)
            }
        }
    }
}

func CLLocationFromSettings(_ s: UserSettings) -> CLLocation {
    CLLocation(latitude: s.locationLat, longitude: s.locationLon)
}

struct CurrentSegmentHero: View {
    let schedule: DailyPrayerSchedule
    let segment: PrayerSegment
    let nextPrayerName: String
    let timeRemaining: TimeInterval

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: segment.systemIcon)
                    .font(.title2)
                Text(segment.displayName)
                    .font(.headline)
                Spacer()
            }
            .foregroundStyle(.primary)

            VStack(spacing: 4) {
                Text(String(localized: "home.nextPrayer", defaultValue: "Prochaine prière"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(nextPrayerName)
                    .font(.largeTitle.bold())
                Text(formattedCountdown)
                    .font(.system(.title2, design: .monospaced).weight(.medium))
                    .foregroundStyle(segment.bandColor)
            }

            ProgressView(value: schedule.progress(of: segment))
                .tint(segment.bandColor)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemGroupedBackground),
                            segment.softFill
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(segment.softStroke, lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var formattedCountdown: String {
        let total = Int(max(0, timeRemaining))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}

struct PrayerTimeline: View {
    let schedule: DailyPrayerSchedule
    let currentSegment: PrayerSegment

    var body: some View {
        VStack(spacing: 0) {
            ForEach(schedule.allPrayers, id: \.key) { prayer in
                PrayerTimeRow(
                    name: prayer.name,
                    arabicName: prayer.arabicName,
                    time: prayer.time,
                    isActive: isActive(prayer.key)
                )
                if prayer.key != schedule.allPrayers.last?.key {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func isActive(_ key: String) -> Bool {
        switch currentSegment {
        case .fajrToSunrise:  return key == "fajr"
        case .sunriseToDhuhr: return key == "sunrise"
        case .dhuhrToAsr:     return key == "dhuhr"
        case .asrToMaghrib:   return key == "asr"
        case .maghribToIsha:  return key == "maghrib"
        case .ishaTofajr:     return key == "isha"
        }
    }
}

struct PrayerDataSourceCard: View {
    let sourceLabel: String
    let errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(sourceLabel, systemImage: "antenna.radiowaves.left.and.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            if let errorMessage, !errorMessage.isEmpty {
                Text("Repli automatique sur le calcul local: \(errorMessage)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Source actuelle des horaires de prière.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct PrayerTimeRow: View {
    let name: String
    let arabicName: String
    let time: Date
    let isActive: Bool

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(isActive ? Color.brandGreen : Color(.tertiarySystemFill))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline.weight(isActive ? .semibold : .regular))
                Text(arabicName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(time, style: .time)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isActive ? Color.brandGreen.opacity(0.08) : .clear)
    }
}

struct LocationDeniedBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "location.denied.title", defaultValue: "Localisation désactivée"))
                    .font(.subheadline.bold())
                Text(String(localized: "location.denied.subtitle", defaultValue: "Activez la localisation dans Réglages."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "button.settings", defaultValue: "Réglages")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption.bold())
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct LoadingCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(String(localized: "home.loading", defaultValue: "Calcul des heures de prière…"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
