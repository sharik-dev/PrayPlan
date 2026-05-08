import SwiftUI
import SwiftData
import WidgetKit

struct ContentView: View {
    @Query private var settings: [UserSettings]
    @Query private var blockingProfiles: [AppBlockingProfile]
    @Query private var goals: [SegmentGoal]
    @Query(sort: \UserTask.createdAt, order: .reverse) private var tasks: [UserTask]
    @Query private var habits: [UserHabit]
    @Environment(\.modelContext) private var context
    @Environment(PrayerTimeService.self) private var prayerService
    @Environment(AppBlockingService.self) private var blockingService
    @Environment(LocationService.self) private var locationService

    private var currentSettings: UserSettings? { settings.first }

    private var widgetSyncSignature: String {
        [
            prayerSignature,
            taskSignature,
            habitSignature,
            goalSignature,
            prayerService.dataSourceLabel,
            currentSettings?.locationName ?? "",
            locationService.cityName
        ].joined(separator: "||")
    }

    var body: some View {
        TabView {
            CalendarView()
                .tabItem { Label(String(localized: "tab.agenda",    defaultValue: "Agenda"),     systemImage: "calendar") }
            HomeView()
                .tabItem { Label(String(localized: "tab.prayer",    defaultValue: "Prières"),    systemImage: "moon.stars.fill") }
            GoalsView()
                .tabItem { Label(String(localized: "tab.goals",     defaultValue: "Objectifs"),  systemImage: "target") }
            AppBlockingView()
                .tabItem { Label(String(localized: "tab.dopamine",  defaultValue: "Dopamine"),   systemImage: "shield.lefthalf.filled") }
            SettingsView()
                .tabItem { Label(String(localized: "tab.settings",  defaultValue: "Paramètres"), systemImage: "gearshape.fill") }
        }
        .tint(.brandGreen)
        .onAppear {
            ensureDefaultSettings()
            ensureBlockingProfiles()
            ensureGoals()
            applyCurrentBlocking()
            syncWidgetSnapshot()
        }
        .onChange(of: prayerService.currentSegment) { _, segment in
            let profile = blockingProfiles.first { $0.segment == segment }
            blockingService.applyBlocking(profile: profile)
            syncWidgetSnapshot()
        }
        .onChange(of: widgetSyncSignature) { _, _ in
            syncWidgetSnapshot()
        }
    }

    private func ensureDefaultSettings() {
        guard settings.isEmpty else { return }
        context.insert(UserSettings())
    }

    private func ensureBlockingProfiles() {
        let existing = Set(blockingProfiles.map { $0.segmentRaw })
        for segment in PrayerSegment.allCases where !existing.contains(segment.rawValue) {
            context.insert(AppBlockingProfile(segment: segment))
        }
    }

    private func ensureGoals() {
        let existing = Set(goals.map { $0.segmentRaw })
        for segment in PrayerSegment.allCases where !existing.contains(segment.rawValue) {
            context.insert(SegmentGoal(segment: segment))
        }
    }

    private func applyCurrentBlocking() {
        let profile = blockingProfiles.first { $0.segment == prayerService.currentSegment }
        blockingService.applyBlocking(profile: profile)
    }

    private var prayerSignature: String {
        guard let schedule = prayerService.todaySchedule else { return "no-prayer-data" }
        return [
            prayerService.currentSegment.rawValue,
            prayerService.nextPrayerName,
            String(schedule.fajr.timeIntervalSince1970),
            String(schedule.sunrise.timeIntervalSince1970),
            String(schedule.dhuhr.timeIntervalSince1970),
            String(schedule.asr.timeIntervalSince1970),
            String(schedule.maghrib.timeIntervalSince1970),
            String(schedule.isha.timeIntervalSince1970)
        ].joined(separator: "|")
    }

    private var taskSignature: String {
        tasks.map {
            [
                $0.id.uuidString,
                $0.title,
                $0.segmentRaw,
                $0.priorityRaw,
                $0.isCompleted.description,
                $0.notes,
                $0.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? ""
            ].joined(separator: "~")
        }
        .joined(separator: "|")
    }

    private var habitSignature: String {
        habits.map { habit in
            let completionSignature = habit.completions
                .map { String($0.completedOn.timeIntervalSince1970) }
                .sorted()
                .joined(separator: ",")

            return [
                habit.id.uuidString,
                habit.title,
                habit.segmentRaw,
                habit.frequencyRaw,
                habit.iconName,
                habit.isArchived.description,
                completionSignature
            ].joined(separator: "~")
        }
        .joined(separator: "|")
    }

    private var goalSignature: String {
        goals.map {
            [
                $0.segmentRaw,
                $0.themeName,
                $0.themeIcon,
                $0.themeColorHex,
                $0.intention,
                $0.rulesRaw
            ].joined(separator: "~")
        }
        .joined(separator: "|")
    }

    private func syncWidgetSnapshot() {
        guard let schedule = prayerService.todaySchedule else { return }

        let segment = prayerService.currentSegment
        let currentGoal = goals.first { $0.segment == segment }
        let cityName = locationService.cityName.isEmpty
            ? (currentSettings?.locationName ?? "PrayPlan")
            : locationService.cityName

        let nextPrayerTime = schedule.nextPrayer(after: Date())?.time
            ?? schedule.fajr.addingTimeInterval(86_400)

        let pendingTasks = tasks
            .filter { !$0.isCompleted && $0.segment == segment }
            .sorted {
                if $0.priority != $1.priority {
                    return taskPriorityRank($0.priority) > taskPriorityRank($1.priority)
                }
                return $0.createdAt < $1.createdAt
            }
            .map {
                WidgetActivityPayload(
                    title: $0.title,
                    subtitle: $0.notes.isEmpty ? $0.priority.displayName : $0.notes,
                    systemIcon: $0.priority.icon,
                    isCompleted: false,
                    kind: "task"
                )
            }

        let segmentHabits = habits
            .filter { !$0.isArchived && $0.segment == segment && $0.isActiveToday() }
            .sorted { lhs, rhs in
                if lhs.isCompleted(on: Date()) != rhs.isCompleted(on: Date()) {
                    return !lhs.isCompleted(on: Date())
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            .map {
                WidgetActivityPayload(
                    title: $0.title,
                    subtitle: $0.isCompleted(on: Date())
                        ? "Déjà complétée aujourd'hui"
                        : $0.frequency.displayName,
                    systemIcon: $0.iconName,
                    isCompleted: $0.isCompleted(on: Date()),
                    kind: "habit"
                )
            }

        let payload = PrayerWidgetPayload(
            generatedAt: Date(),
            cityName: cityName,
            currentSegmentRaw: segment.rawValue,
            currentSegmentName: segment.displayName,
            currentSegmentIcon: segment.systemIcon,
            currentSegmentColorHex: widgetColorHex(for: segment),
            activePrayerKey: activePrayerKey(for: segment),
            nextPrayerName: prayerService.nextPrayerName,
            nextPrayerTime: nextPrayerTime,
            dataSourceLabel: prayerService.dataSourceLabel,
            currentGoalTitle: currentGoal?.themeName ?? "",
            currentGoalIcon: currentGoal?.themeIcon ?? "",
            currentGoalColorHex: currentGoal?.themeColorHex ?? "",
            currentGoalIntention: currentGoal?.intention ?? "",
            currentGoalRules: currentGoal?.rules ?? [],
            prayers: schedule.allPrayers.map {
                WidgetPrayerPayload(
                    key: $0.key,
                    name: $0.name,
                    arabicName: $0.arabicName,
                    time: $0.time
                )
            },
            activities: Array((segmentHabits + pendingTasks).prefix(4))
        )

        WidgetSnapshotStore.save(payload)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func taskPriorityRank(_ priority: TaskPriority) -> Int {
        switch priority {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private func activePrayerKey(for segment: PrayerSegment) -> String {
        switch segment {
        case .fajrToSunrise: return "fajr"
        case .sunriseToDhuhr: return "sunrise"
        case .dhuhrToAsr: return "dhuhr"
        case .asrToMaghrib: return "asr"
        case .maghribToIsha: return "maghrib"
        case .ishaTofajr: return "isha"
        }
    }

    private func widgetColorHex(for segment: PrayerSegment) -> String {
        switch segment {
        case .fajrToSunrise: return "#1A247D"
        case .sunriseToDhuhr: return "#E65200"
        case .dhuhrToAsr: return "#CC8500"
        case .asrToMaghrib: return "#F59900"
        case .maghribToIsha: return "#6B1C99"
        case .ishaTofajr: return "#0D0D2B"
        }
    }
}

private struct PrayerWidgetPayload: Codable {
    let generatedAt: Date
    let cityName: String
    let currentSegmentRaw: String
    let currentSegmentName: String
    let currentSegmentIcon: String
    let currentSegmentColorHex: String
    let activePrayerKey: String
    let nextPrayerName: String
    let nextPrayerTime: Date
    let dataSourceLabel: String
    let currentGoalTitle: String
    let currentGoalIcon: String
    let currentGoalColorHex: String
    let currentGoalIntention: String
    let currentGoalRules: [String]
    let prayers: [WidgetPrayerPayload]
    let activities: [WidgetActivityPayload]
}

private struct WidgetPrayerPayload: Codable {
    let key: String
    let name: String
    let arabicName: String
    let time: Date
}

private struct WidgetActivityPayload: Codable {
    let title: String
    let subtitle: String
    let systemIcon: String
    let isCompleted: Bool
    let kind: String
}

private enum WidgetSnapshotStore {
    static let suiteName = "group.PrayPlan"
    static let snapshotKey = "prayer_widget_snapshot"

    static func save(_ payload: PrayerWidgetPayload) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: snapshotKey)
    }
}
