//
//  PrayPlanWidget.swift
//  PrayPlanWidget
//
//  Created by Sharik Mohamed on 08/05/2026.
//

import WidgetKit
import SwiftUI

private protocol SharedPrayerWidgetProvider: TimelineProvider where Entry == PrayerWidgetEntry {
    var previewEntry: PrayerWidgetEntry { get }
}

extension SharedPrayerWidgetProvider {
    func placeholder(in context: Context) -> PrayerWidgetEntry {
        previewEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        if context.isPreview {
            completion(previewEntry)
        } else {
            completion(loadLiveEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        let entry = loadLiveEntry()
        let refreshDate = entry.payload?.nextPrayerTime.addingTimeInterval(60) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadLiveEntry() -> PrayerWidgetEntry {
        PrayerWidgetEntry(date: Date(), payload: WidgetSnapshotStore.load())
    }
}

struct PrayerTimesWidgetProvider: SharedPrayerWidgetProvider {
    let previewEntry = PrayerWidgetEntry.prayerPreview
}

struct CurrentGoalWidgetProvider: SharedPrayerWidgetProvider {
    let previewEntry = PrayerWidgetEntry.goalPreview
}

struct PeriodActivitiesWidgetProvider: SharedPrayerWidgetProvider {
    let previewEntry = PrayerWidgetEntry.activitiesPreview
}

struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let payload: PrayerWidgetPayload?

    static let prayerPreview = PrayerWidgetEntry(
        date: Date(),
        payload: PrayerWidgetPayload(
            generatedAt: Date(),
            cityName: "Paris",
            currentSegmentRaw: "dhuhrToAsr",
            currentSegmentName: "Dhuhr → Asr",
            currentSegmentIcon: "sun.max.fill",
            currentSegmentColorHex: "#34C759",
            activePrayerKey: "dhuhr",
            nextPrayerName: "Asr",
            nextPrayerTime: Date().addingTimeInterval(3600),
            dataSourceLabel: "Calcul local",
            currentGoalTitle: "Deep Work",
            currentGoalIcon: "briefcase.fill",
            currentGoalColorHex: "#4C7DFF",
            currentGoalIntention: "Produire sans distraction pendant cette période.",
            currentGoalRules: ["Pas de réseaux sociaux", "1 tâche prioritaire", "Téléphone en silencieux"],
            prayers: [
                WidgetPrayerPayload(key: "fajr",    name: "Fajr",    arabicName: "الفجر",  time: Date().addingTimeInterval(-18000)),
                WidgetPrayerPayload(key: "sunrise",  name: "Lever",   arabicName: "الشروق", time: Date().addingTimeInterval(-14400)),
                WidgetPrayerPayload(key: "dhuhr",   name: "Dhuhr",   arabicName: "الظهر",  time: Date().addingTimeInterval(-600)),
                WidgetPrayerPayload(key: "asr",     name: "Asr",     arabicName: "العصر",  time: Date().addingTimeInterval(3600)),
                WidgetPrayerPayload(key: "maghrib", name: "Maghrib", arabicName: "المغرب", time: Date().addingTimeInterval(14400)),
                WidgetPrayerPayload(key: "isha",    name: "Isha",    arabicName: "العشاء", time: Date().addingTimeInterval(18000))
            ],
            activities: [
                WidgetActivityPayload(title: "Lecture du Coran", subtitle: "Quotidien", systemIcon: "book.fill",                  isCompleted: false, kind: "habit"),
                WidgetActivityPayload(title: "Appeler la famille", subtitle: "Haute",  systemIcon: "exclamationmark.circle.fill", isCompleted: false, kind: "task")
            ]
        )
    )

    static let goalPreview = PrayerWidgetEntry(
        date: Date(),
        payload: PrayerWidgetPayload(
            generatedAt: Date(),
            cityName: "Lyon",
            currentSegmentRaw: "maghribToIsha",
            currentSegmentName: "Maghrib → Isha",
            currentSegmentIcon: "sunset.fill",
            currentSegmentColorHex: "#FF9F0A",
            activePrayerKey: "maghrib",
            nextPrayerName: "Isha",
            nextPrayerTime: Date().addingTimeInterval(3200),
            dataSourceLabel: "API AlAdhan",
            currentGoalTitle: "Famille et apaisement",
            currentGoalIcon: "house.fill",
            currentGoalColorHex: "#FF7A59",
            currentGoalIntention: "Profiter du foyer, couper le bruit extérieur et finir la journée avec présence.",
            currentGoalRules: ["Téléphone loin de la table", "Discussion calme", "Révision des priorités du soir"],
            prayers: [
                WidgetPrayerPayload(key: "fajr",    name: "Fajr",    arabicName: "الفجر",  time: Date().addingTimeInterval(-43200)),
                WidgetPrayerPayload(key: "sunrise",  name: "Lever",   arabicName: "الشروق", time: Date().addingTimeInterval(-39600)),
                WidgetPrayerPayload(key: "dhuhr",   name: "Dhuhr",   arabicName: "الظهر",  time: Date().addingTimeInterval(-21600)),
                WidgetPrayerPayload(key: "asr",     name: "Asr",     arabicName: "العصر",  time: Date().addingTimeInterval(-10800)),
                WidgetPrayerPayload(key: "maghrib", name: "Maghrib", arabicName: "المغرب", time: Date().addingTimeInterval(-1200)),
                WidgetPrayerPayload(key: "isha",    name: "Isha",    arabicName: "العشاء", time: Date().addingTimeInterval(3200))
            ],
            activities: [
                WidgetActivityPayload(title: "Préparer demain", subtitle: "Priorité", systemIcon: "list.bullet.clipboard.fill", isCompleted: false, kind: "task")
            ]
        )
    )

    static let activitiesPreview = PrayerWidgetEntry(
        date: Date(),
        payload: PrayerWidgetPayload(
            generatedAt: Date(),
            cityName: "Marseille",
            currentSegmentRaw: "fajrToSunrise",
            currentSegmentName: "Fajr → Sunrise",
            currentSegmentIcon: "sunrise.fill",
            currentSegmentColorHex: "#64D2FF",
            activePrayerKey: "fajr",
            nextPrayerName: "Lever",
            nextPrayerTime: Date().addingTimeInterval(5400),
            dataSourceLabel: "Calcul local",
            currentGoalTitle: "Routine du matin",
            currentGoalIcon: "bolt.heart.fill",
            currentGoalColorHex: "#30D158",
            currentGoalIntention: "Installer une matinée propre avant le reste de la journée.",
            currentGoalRules: ["Pas d'écran au réveil", "Lecture 10 min", "Plan du jour"],
            prayers: [
                WidgetPrayerPayload(key: "fajr",    name: "Fajr",    arabicName: "الفجر",  time: Date().addingTimeInterval(-900)),
                WidgetPrayerPayload(key: "sunrise",  name: "Lever",   arabicName: "الشروق", time: Date().addingTimeInterval(5400)),
                WidgetPrayerPayload(key: "dhuhr",   name: "Dhuhr",   arabicName: "الظهر",  time: Date().addingTimeInterval(25200)),
                WidgetPrayerPayload(key: "asr",     name: "Asr",     arabicName: "العصر",  time: Date().addingTimeInterval(39600)),
                WidgetPrayerPayload(key: "maghrib", name: "Maghrib", arabicName: "المغرب", time: Date().addingTimeInterval(57600)),
                WidgetPrayerPayload(key: "isha",    name: "Isha",    arabicName: "العشاء", time: Date().addingTimeInterval(63000))
            ],
            activities: [
                WidgetActivityPayload(title: "Dhikr du matin", subtitle: "Quotidien", systemIcon: "sparkles", isCompleted: true, kind: "habit"),
                WidgetActivityPayload(title: "Lecture", subtitle: "10 min", systemIcon: "book.fill", isCompleted: false, kind: "habit"),
                WidgetActivityPayload(title: "Planifier 3 priorités", subtitle: "Matin", systemIcon: "checklist", isCompleted: false, kind: "task")
            ]
        )
    )
}

struct PrayPlanWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    var entry: PrayerWidgetEntry

    var body: some View {
        if let payload = entry.payload {
            switch family {
            case .systemSmall:  SmallPrayerWidgetView(payload: payload)
            case .systemMedium: MediumPrayerWidgetView(payload: payload)
            default:            LargePrayerWidgetView(payload: payload)
            }
        } else {
            WidgetEmptyStateView()
        }
    }
}

struct PrayPlanWidget: Widget {
    let kind: String = "PrayPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerTimesWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                PrayPlanWidgetEntryView(entry: entry)
                    .containerBackground(backgroundGradient, for: .widget)
            } else {
                PrayPlanWidgetEntryView(entry: entry)
                    .padding()
                    .background(backgroundGradient)
            }
        }
        .configurationDisplayName("Horaires des prières")
        .description("Affiche la prochaine salat, le compte à rebours et les horaires du jour.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [Color.black, Color(red: 0.02, green: 0.09, blue: 0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct CurrentGoalWidget: Widget {
    let kind: String = "CurrentGoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentGoalWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                CurrentGoalWidgetEntryView(entry: entry)
                    .containerBackground(goalBackground, for: .widget)
            } else {
                CurrentGoalWidgetEntryView(entry: entry)
                    .padding()
                    .background(goalBackground)
            }
        }
        .configurationDisplayName("Objectif du moment")
        .description("Met en avant l'objectif actif, son intention et ses règles.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    private var goalBackground: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.06, green: 0.08, blue: 0.14), Color(red: 0.10, green: 0.12, blue: 0.20)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct PeriodActivitiesWidget: Widget {
    let kind: String = "PeriodActivitiesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PeriodActivitiesWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                PeriodActivitiesWidgetEntryView(entry: entry)
                    .containerBackground(activityBackground, for: .widget)
            } else {
                PeriodActivitiesWidgetEntryView(entry: entry)
                    .padding()
                    .background(activityBackground)
            }
        }
        .configurationDisplayName("Tâches et habitudes")
        .description("Liste les activités prévues dans la période actuelle.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    private var activityBackground: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.10), Color(red: 0.07, green: 0.10, blue: 0.14)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Small  (~158×158pt → ~126×136pt content)

private struct SmallPrayerWidgetView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SmallHeader(payload: payload)

            VStack(alignment: .leading, spacing: 2) {
                Text("Prochain sala")
                .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                Text(payload.nextPrayerName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    Text(payload.nextPrayerTime, style: .timer)
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Color.brandGreen)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(payload.nextPrayerTime, style: .time)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Color.widgetMuted)
                        .lineLimit(1)
                }
            }

            VStack(spacing: 3) {
                ForEach(nextVisiblePrayers, id: \.key) { prayer in
                    CompactPrayerRow(prayer: prayer, isActive: prayer.key == payload.activePrayerKey)
                }
            }

            Spacer(minLength: 0)

            if let activity = payload.activities.first {
                WidgetActivityPill(activity: activity, compact: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var nextVisiblePrayers: [WidgetPrayerPayload] {
        let idx = payload.prayers.firstIndex { $0.key == payload.activePrayerKey } ?? 0
        let end = min(payload.prayers.count, idx + 2)
        return Array(payload.prayers[idx..<end])
    }
}

private struct SmallHeader: View {
    let payload: PrayerWidgetPayload
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "moon.stars.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.brandGreen)
                Text(payload.cityName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(spacing: 3) {
                Image(systemName: payload.currentSegmentIcon)
                    .lineLimit(1)
                Text(payload.currentSegmentName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.caption2)
            .foregroundStyle(Color.brandGreen)
        }
    }
}

// MARK: - Medium  (~338×158pt → ~306×136pt content)

private struct MediumPrayerWidgetView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                SmallHeader(payload: payload)
                MediumCountdownCard(payload: payload)

                Spacer(minLength: 0)

                if let activity = payload.activities.first {
                    WidgetActivityPill(activity: activity, compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.brandGreen.opacity(0.18))
                .frame(width: 1)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 3) {
                ForEach(payload.prayers, id: \.key) { prayer in
                    CompactPrayerRow(prayer: prayer, isActive: prayer.key == payload.activePrayerKey)
                }
            }
            .frame(width: 126, alignment: .leading)
        }
    }
}

private struct MediumCountdownCard: View {
    let payload: PrayerWidgetPayload
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Prochain sala")
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
            Text(payload.nextPrayerName)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(payload.nextPrayerTime, style: .timer)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Color.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.40), radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(payload.nextPrayerTime, style: .time)
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.brandGreen.opacity(0.30), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Large  (~338×354pt → ~306×332pt content)

private struct LargePrayerWidgetView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header ≈ 34pt
            LargeHeader(payload: payload)

            // Countdown banner ≈ 50pt
            LargeCountdownBanner(payload: payload)

            // Prayer grid 2 cols × 3 rows ≈ 100pt
            VStack(alignment: .leading, spacing: 5) {
                Text("Horaires du jour")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)],
                    spacing: 6
                ) {
                    ForEach(payload.prayers, id: \.key) { prayer in
                        PrayerGridCard(prayer: prayer, isActive: prayer.key == payload.activePrayerKey)
                    }
                }
            }

            // Activities ≈ 88pt
            VStack(alignment: .leading, spacing: 5) {
                Text("Cette période")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)
                if payload.activities.isEmpty {
                    WidgetEmptyActivitiesView()
                } else {
                    ForEach(Array(payload.activities.prefix(2))) { activity in
                        LargeActivityRow(activity: activity)
                    }
                }
            }
        }
    }
}

private struct LargeHeader: View {
    let payload: PrayerWidgetPayload
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(Color.brandGreen)
                    Text(payload.cityName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 4) {
                    Image(systemName: payload.currentSegmentIcon)
                    Text(payload.currentSegmentName)
                }
                .font(.caption)
                .foregroundStyle(Color.brandGreen)
            }
            Spacer()
            Text(payload.dataSourceLabel)
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(1)
        }
    }
}

private struct LargeCountdownBanner: View {
    let payload: PrayerWidgetPayload
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prochain sala")
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                Text(payload.nextPrayerName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(payload.nextPrayerTime, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
            }
            Spacer()
            Text(payload.nextPrayerTime, style: .timer)
                .font(.system(.title, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.50), radius: 8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.brandGreen.opacity(0.55), Color.brandGreen.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

private struct PrayerGridCard: View {
    let prayer: WidgetPrayerPayload
    let isActive: Bool
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.brandGreen : Color(white: 0.22))
                .frame(width: 6, height: 6)
                .shadow(color: isActive ? Color.brandGreen.opacity(0.70) : .clear, radius: 3)
            Text(prayer.name)
                .font(.caption.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : Color(white: 0.62))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(prayer.time, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isActive ? Color.brandGreen : Color.widgetMuted)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color.brandGreen.opacity(0.14) : Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.brandGreen.opacity(0.30) : Color(white: 0.10),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

private struct LargeActivityRow: View {
    let activity: WidgetActivityPayload
    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.brandGreen.opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: activity.systemIcon)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(activity.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(activity.isCompleted ? Color.widgetMuted : .white)
                    .lineLimit(1)
                Text(activity.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
            }
            Spacer(minLength: 4)
            if activity.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandGreen)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.08))
        )
    }
}

// MARK: - Goal widget

struct CurrentGoalWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerWidgetEntry

    var body: some View {
        if let payload = entry.payload {
            switch family {
            case .systemSmall:
                CurrentGoalSmallView(payload: payload)
            default:
                CurrentGoalMediumView(payload: payload)
            }
        } else {
            WidgetEmptyStateView()
        }
    }
}

private struct CurrentGoalSmallView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: payload.goalIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(payload.goalColor)
                Text(payload.currentSegmentName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)
                    .lineLimit(1)
            }

            Text(payload.goalTitle)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)

            Text(payload.goalIntention)
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(4)

            Spacer(minLength: 0)
        }
    }
}

private struct CurrentGoalMediumView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(payload.goalColor.opacity(0.14))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(payload.goalColor.opacity(0.28), lineWidth: 1)
                            )
                        Image(systemName: payload.goalIcon)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(payload.goalColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Objectif actuel")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.widgetMuted)
                        Text(payload.goalTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                }

                Text(payload.goalIntention)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(3)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text(payload.currentGoalRules.isEmpty ? "Segment actuel" : "Règles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)

                if payload.currentGoalRules.isEmpty {
                    Label(payload.currentSegmentName, systemImage: payload.currentSegmentIcon)
                        .font(.caption)
                        .foregroundStyle(payload.goalColor)
                        .lineLimit(2)
                } else {
                    ForEach(Array(payload.currentGoalRules.prefix(3).enumerated()), id: \.offset) { _, rule in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(payload.goalColor.opacity(0.75))
                                .frame(width: 5, height: 5)
                                .padding(.top, 5)
                            Text(rule)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.86))
                                .lineLimit(2)
                        }
                    }
                }
            }
            .frame(maxWidth: 120, alignment: .leading)
        }
    }
}

// MARK: - Current activities widget

struct PeriodActivitiesWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerWidgetEntry

    var body: some View {
        if let payload = entry.payload {
            switch family {
            case .systemSmall:
                PeriodActivitiesSmallView(payload: payload)
            case .systemMedium:
                PeriodActivitiesMediumView(payload: payload)
            default:
                PeriodActivitiesLargeView(payload: payload)
            }
        } else {
            WidgetEmptyStateView()
        }
    }
}

private struct PeriodActivitiesSmallView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: payload.currentSegmentIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
                Text(payload.currentSegmentName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)
                    .lineLimit(1)
            }

            Text("Maintenant")
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            if let first = payload.activities.first {
                WidgetActivityPill(activity: first, compact: true)
            }

            if let second = payload.activities.dropFirst().first {
                WidgetActivityPill(activity: second, compact: true)
            }

            Spacer(minLength: 0)

            Text("\(payload.activities.count) activité\(payload.activities.count > 1 ? "s" : "")")
                .font(.caption2)
                .foregroundStyle(Color.widgetMuted)
        }
    }
}

private struct PeriodActivitiesMediumView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Période actuelle")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.widgetMuted)
                    Text(payload.currentSegmentName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text(payload.goalTitle)
                    .font(.caption)
                    .foregroundStyle(payload.goalColor)
                    .lineLimit(1)
            }

            if payload.activities.isEmpty {
                WidgetEmptyActivitiesView()
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(payload.activities.prefix(4))) { activity in
                        LargeActivityRow(activity: activity)
                    }
                }
            }
        }
    }
}

private struct PeriodActivitiesLargeView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("En ce moment")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.widgetMuted)
                    Text(payload.currentSegmentName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                if !payload.currentGoalTitle.isEmpty {
                    Label(payload.goalTitle, systemImage: payload.goalIcon)
                        .font(.caption)
                        .foregroundStyle(payload.goalColor)
                        .lineLimit(1)
                }
            }

            Text(payload.goalIntention)
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
                .lineLimit(2)

            if payload.activities.isEmpty {
                WidgetEmptyActivitiesView()
            } else {
                ForEach(payload.activities) { activity in
                    LargeActivityRow(activity: activity)
                }
            }
        }
    }
}

// MARK: - Shared small components

private struct CompactPrayerRow: View {
    let prayer: WidgetPrayerPayload
    let isActive: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isActive ? Color.brandGreen : Color(white: 0.22))
                .frame(width: 5, height: 5)
            Text(prayer.name)
                .font(.caption2.weight(isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : Color(white: 0.60))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 3)
            Text(prayer.time, style: .time)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isActive ? Color.brandGreen : Color.widgetMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, isActive ? 5 : 0)
        .padding(.vertical, isActive ? 2 : 0)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isActive ? Color.brandGreen.opacity(0.12) : .clear)
        )
    }
}

private struct WidgetActivityPill: View {
    let activity: WidgetActivityPayload
    let compact: Bool

    private var titleFont: Font {
        compact ? .system(size: 10, weight: .semibold) : .caption2.weight(.semibold)
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: activity.systemIcon)
                .font(compact ? .system(size: 9, weight: .semibold) : .caption2)
            Text(activity.title)
                .font(titleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 0)
            if activity.isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(activity.isCompleted ? Color.brandGreen : .white)
        .padding(.horizontal, compact ? 6 : 7)
        .padding(.vertical, compact ? 4 : 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.brandGreen.opacity(activity.isCompleted ? 0.22 : 0.12))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.brandGreen.opacity(0.28), lineWidth: 0.5)
                )
        )
    }
}

private struct WidgetEmptyActivitiesView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.brandGreen.opacity(0.55))
            Text("Aucune activité planifiée")
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
        }
    }
}

private struct WidgetEmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(Color.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.50), radius: 8)
            Text("PrayPlan")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Ouvrez l'app pour calculer les horaires.")
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Data models

struct PrayerWidgetPayload: Codable {
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

    var segmentColor: Color { Color(hex: currentSegmentColorHex) }
    var goalColor: Color { Color(hex: currentGoalColorHex.isEmpty ? currentSegmentColorHex : currentGoalColorHex) }
    var goalIcon: String { currentGoalIcon.isEmpty ? currentSegmentIcon : currentGoalIcon }
    var goalTitle: String { currentGoalTitle.isEmpty ? currentSegmentName : currentGoalTitle }
    var goalIntention: String {
        currentGoalIntention.isEmpty ? "Aucune intention définie pour cette période." : currentGoalIntention
    }
}

struct WidgetPrayerPayload: Codable {
    let key: String
    let name: String
    let arabicName: String
    let time: Date
}

struct WidgetActivityPayload: Codable, Identifiable {
    let title: String
    let subtitle: String
    let systemIcon: String
    let isCompleted: Bool
    let kind: String
    var id: String { "\(kind)|\(title)|\(subtitle)" }
}

private enum WidgetSnapshotStore {
    static let suiteName   = "group.PrayPlan"
    static let snapshotKey = "prayer_widget_snapshot"

    static func load() -> PrayerWidgetPayload? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(PrayerWidgetPayload.self, from: data)
    }
}

// MARK: - Color palette

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >>  8) & 0xFF) / 255.0,
            blue:  Double( value        & 0xFF) / 255.0
        )
    }

    static let brandGreen = Color(red: 0.20, green: 0.82, blue: 0.40)
    static let widgetMuted = Color(white: 0.48)
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PrayPlanWidget()
} timeline: {
    PrayerWidgetEntry.prayerPreview
}

#Preview(as: .systemMedium) {
    PrayPlanWidget()
} timeline: {
    PrayerWidgetEntry.prayerPreview
}

#Preview(as: .systemLarge) {
    PrayPlanWidget()
} timeline: {
    PrayerWidgetEntry.prayerPreview
}
