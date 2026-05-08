import SwiftUI
import SwiftData
import CoreLocation

struct SettingsView: View {
    @Query private var settings: [UserSettings]
    @Environment(\.modelContext) private var context
    @Environment(PrayerTimeService.self) private var prayerService
    @Environment(NotificationService.self) private var notifService
    @Environment(LocationService.self) private var locationService

    private var s: UserSettings? { settings.first }

    var body: some View {
        NavigationStack {
            Group {
                if let s {
                    Form {
                        locationSection(s)
                        calculationSection(s)
                        alertsSection(s)
                        qiblaSection
                        aboutSection
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(String(localized: "tab.settings", defaultValue: "Paramètres"))
        }
    }

    @ViewBuilder
    private func locationSection(_ s: UserSettings) -> some View {
        Section(String(localized: "settings.location", defaultValue: "Localisation")) {
            Toggle(
                String(localized: "settings.autoLocation", defaultValue: "Localisation automatique"),
                isOn: Binding(
                    get: { s.useAutoLocation },
                    set: { updateAutoLocation($0, settings: s) }
                )
            )
            if !locationService.cityName.isEmpty {
                LabeledContent(
                    String(localized: "settings.currentCity", defaultValue: "Ville"),
                    value: locationService.cityName
                )
            }
        }
    }

    @ViewBuilder
    private func calculationSection(_ s: UserSettings) -> some View {
        Section(String(localized: "settings.calculation", defaultValue: "Calcul")) {
            Picker(
                String(localized: "settings.dataSource", defaultValue: "Source des horaires"),
                selection: Binding(
                    get: { s.prayerDataSource },
                    set: { s.prayerDataSource = $0; recalculate(s) }
                )
            ) {
                ForEach(PrayerTimesDataSource.allCases) { source in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(source.displayName).tag(source)
                        Text(source.subtitle)
                    }
                    .tag(source)
                }
            }
            .pickerStyle(.navigationLink)

            Picker(
                String(localized: "settings.method", defaultValue: "Méthode"),
                selection: Binding(
                    get: { s.calculationMethod },
                    set: { s.calculationMethod = $0; recalculate(s) }
                )
            ) {
                ForEach(CalculationMethodOption.allCases) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .pickerStyle(.navigationLink)

            Picker(
                String(localized: "settings.madhab", defaultValue: "Madhab (Asr)"),
                selection: Binding(
                    get: { s.madhab },
                    set: { s.madhab = $0; recalculate(s) }
                )
            ) {
                ForEach(MadhabOption.allCases) { m in
                    Text(m.displayName).tag(m)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    @ViewBuilder
    private func alertsSection(_ s: UserSettings) -> some View {
        Section(String(localized: "settings.alerts", defaultValue: "Alertes")) {
            Picker(
                String(localized: "settings.sound", defaultValue: "Sonnerie"),
                selection: Binding(
                    get: { s.azanSound },
                    set: { s.azanSound = $0; reschedule(s) }
                )
            ) {
                ForEach(AzanSound.allCases) { sound in
                    Label(sound.displayName, systemImage: sound.icon).tag(sound)
                }
            }
            .pickerStyle(.navigationLink)

            ForEach(["fajr", "dhuhr", "asr", "maghrib", "isha"], id: \.self) { key in
                Toggle(prayerName(key), isOn: Binding(
                    get: { s.isPrayerEnabled(key) },
                    set: { _ in s.togglePrayer(key); reschedule(s) }
                ))
            }
        }

        if notifService.authorizationStatus == .denied {
            Section {
                HStack {
                    Image(systemName: "bell.slash.fill").foregroundStyle(.orange)
                    Text(String(localized: "settings.notifDenied",
                                defaultValue: "Notifications désactivées. Activez-les dans Réglages."))
                        .font(.footnote)
                    Spacer()
                    Button(String(localized: "button.settings", defaultValue: "Réglages")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(.caption.bold())
                }
            }
        }
    }

    @ViewBuilder
    private var qiblaSection: some View {
        Section(String(localized: "settings.tools", defaultValue: "Outils")) {
            NavigationLink {
                QiblaView()
            } label: {
                Label(
                    String(localized: "tab.qibla", defaultValue: "Qibla"),
                    systemImage: "location.north.line.fill"
                )
            }
        }
    }

    private var aboutSection: some View {
        Section(String(localized: "settings.about", defaultValue: "À propos")) {
            LabeledContent("Version", value: "1.0")
            LabeledContent(
                String(localized: "settings.engine", defaultValue: "Moteur de calcul"),
                value: "Adhan"
            )
            Link(
                "API publique AlAdhan",
                destination: URL(string: "https://aladhan.com/prayer-times-api")!
            )
            .font(.footnote)
            Link(
                String(localized: "settings.openSource", defaultValue: "Adhan open-source library"),
                destination: URL(string: "https://github.com/batoulapps/adhan-swift")!
            )
            .font(.footnote)
        }
    }

    private func recalculate(_ s: UserSettings) {
        let location = locationService.currentLocation ?? CLLocationFromSettings(s)
        Task {
            await prayerService.calculate(for: location, settings: s)
            reschedule(s)
        }
    }

    private func updateAutoLocation(_ isEnabled: Bool, settings s: UserSettings) {
        s.useAutoLocation = isEnabled

        if isEnabled {
            locationService.requestAndFetch()
            if let location = locationService.currentLocation {
                Task {
                    await prayerService.calculate(for: location, settings: s)
                    reschedule(s)
                }
            }
        } else {
            locationService.cityName = s.locationName
            let location = CLLocationFromSettings(s)
            Task {
                await prayerService.calculate(for: location, settings: s)
                reschedule(s)
            }
        }
    }

    private func reschedule(_ s: UserSettings) {
        notifService.scheduleForWeek(schedules: prayerService.weekSchedules, settings: s)
    }

    private func prayerName(_ key: String) -> String {
        switch key {
        case "fajr":    return String(localized: "prayer.fajr",    defaultValue: "Fajr")
        case "dhuhr":   return String(localized: "prayer.dhuhr",   defaultValue: "Dhuhr")
        case "asr":     return String(localized: "prayer.asr",     defaultValue: "Asr")
        case "maghrib": return String(localized: "prayer.maghrib", defaultValue: "Maghrib")
        case "isha":    return String(localized: "prayer.isha",    defaultValue: "Isha")
        default:        return key
        }
    }
}
