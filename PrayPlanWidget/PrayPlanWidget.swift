//
//  PrayPlanWidget.swift
//  PrayPlanWidget
//
//  Created by Sharik Mohamed on 08/05/2026.
//

import WidgetKit
import SwiftUI

struct PrayerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerWidgetEntry {
        PrayerWidgetEntry.placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerWidgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refreshDate = entry.payload?.nextPrayerTime.addingTimeInterval(60) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadEntry() -> PrayerWidgetEntry {
        PrayerWidgetEntry(date: Date(), payload: WidgetSnapshotStore.load())
    }
}

struct PrayerWidgetEntry: TimelineEntry {
    let date: Date
    let payload: PrayerWidgetPayload?

    static let placeholder = PrayerWidgetEntry(
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
            dataSourceLabel: "Calcul local (Adhan)",
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
}

struct PrayPlanWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    var entry: PrayerWidgetProvider.Entry

    var body: some View {
        if let payload = entry.payload {
            switch family {
            case .systemSmall:
                SmallPrayerWidgetView(payload: payload)
            case .systemMedium:
                MediumPrayerWidgetView(payload: payload)
            default:
                LargePrayerWidgetView(payload: payload)
            }
        } else {
            WidgetEmptyStateView()
        }
    }
}

struct PrayPlanWidget: Widget {
    let kind: String = "PrayPlanWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerWidgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                PrayPlanWidgetEntryView(entry: entry)
                    .containerBackground(backgroundGradient, for: .widget)
            } else {
                PrayPlanWidgetEntryView(entry: entry)
                    .padding()
                    .background(backgroundGradient)
            }
        }
        .configurationDisplayName("Prières")
        .description("Horaires de prière, prochain sala et activités de la période en cours.")
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

// MARK: - Small

private struct SmallPrayerWidgetView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeaderView(payload: payload, compact: true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Prochain sala")
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                Text(payload.nextPrayerName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                timerText
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(Color.brandGreen)
                    .lineLimit(1)
            }

            VStack(spacing: 4) {
                ForEach(highlightedPrayers, id: \.key) { prayer in
                    WidgetPrayerRow(prayer: prayer, isActive: prayer.key == payload.activePrayerKey, compact: true)
                }
            }

            if let activity = payload.activities.first {
                WidgetActivityPill(activity: activity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var highlightedPrayers: [WidgetPrayerPayload] {
        let currentIndex = payload.prayers.firstIndex { $0.key == payload.activePrayerKey } ?? 0
        let start = max(0, currentIndex)
        let end = min(payload.prayers.count, start + 3)
        return Array(payload.prayers[start..<end])
    }

    private var timerText: Text {
        Text(payload.nextPrayerTime, style: .timer)
    }
}

// MARK: - Medium

private struct MediumPrayerWidgetView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                WidgetHeaderView(payload: payload, compact: false)
                WidgetCountdownCard(payload: payload)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Activités maintenant")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.widgetMuted)

                    if payload.activities.isEmpty {
                        WidgetEmptyActivitiesView()
                    } else {
                        ForEach(Array(payload.activities.prefix(2))) { activity in
                            WidgetActivityRow(activity: activity)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(payload.prayers, id: \.key) { prayer in
                    WidgetPrayerRow(prayer: prayer, isActive: prayer.key == payload.activePrayerKey, compact: false)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Large

private struct LargePrayerWidgetView: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WidgetHeaderView(payload: payload, compact: false)

            LargeCountdownBanner(payload: payload)

            VStack(alignment: .leading, spacing: 8) {
                Label("Horaires du jour", systemImage: "clock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(payload.prayers, id: \.key) { prayer in
                        WidgetPrayerGridCard(prayer: prayer, isActive: prayer.key == payload.activePrayerKey)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Activités de cette période", systemImage: "checklist")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.widgetMuted)

                if payload.activities.isEmpty {
                    WidgetEmptyActivitiesView()
                } else {
                    ForEach(payload.activities) { activity in
                        WidgetActivityRow(activity: activity)
                    }
                }
            }
        }
    }
}

private struct LargeCountdownBanner: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Prochain sala")
                    .font(.caption)
                    .foregroundStyle(Color.widgetMuted)
                Text(payload.nextPrayerName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                Text(payload.nextPrayerTime, style: .time)
                    .font(.subheadline)
                    .foregroundStyle(Color.widgetMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("dans")
                    .font(.caption)
                    .foregroundStyle(Color.widgetMuted)
                Text(payload.nextPrayerTime, style: .timer)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(Color.brandGreen)
                    .shadow(color: Color.brandGreen.opacity(0.55), radius: 10, x: 0, y: 0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.brandGreen.opacity(0.60), Color.brandGreen.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

private struct WidgetPrayerGridCard: View {
    let prayer: WidgetPrayerPayload
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.brandGreen : Color(white: 0.22))
                .frame(width: 8, height: 8)
                .shadow(color: isActive ? Color.brandGreen.opacity(0.70) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(prayer.name)
                    .font(.caption.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : Color(white: 0.65))
                    .lineLimit(1)
                Text(prayer.time, style: .time)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isActive ? Color.brandGreen : Color.widgetMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.brandGreen.opacity(0.14) : Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            isActive ? Color.brandGreen.opacity(0.35) : Color(white: 0.12),
                            lineWidth: 0.5
                        )
                )
        )
    }
}

// MARK: - Shared components

private struct WidgetHeaderView: View {
    let payload: PrayerWidgetPayload
    let compact: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(Color.brandGreen)
                    Text(payload.cityName)
                        .font(compact ? .caption.weight(.semibold) : .headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                HStack(spacing: 5) {
                    Image(systemName: payload.currentSegmentIcon)
                    Text(payload.currentSegmentName)
                        .lineLimit(1)
                }
                .font(compact ? .caption2 : .subheadline)
                .foregroundStyle(Color.brandGreen)
            }

            Spacer(minLength: 8)

            if !compact {
                Text(payload.dataSourceLabel)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
    }
}

private struct WidgetCountdownCard: View {
    let payload: PrayerWidgetPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Prochain sala")
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
            Text(payload.nextPrayerName)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(payload.nextPrayerTime, style: .timer)
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Color.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.50), radius: 6, x: 0, y: 0)
                .lineLimit(1)
            Text(payload.nextPrayerTime, style: .time)
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.brandGreen.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

private struct WidgetPrayerRow: View {
    let prayer: WidgetPrayerPayload
    let isActive: Bool
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            if !compact && isActive {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.brandGreen)
                    .frame(width: 3, height: 28)
            } else if !compact {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.clear)
                    .frame(width: 3, height: 28)
            }

            if compact {
                Circle()
                    .fill(isActive ? Color.brandGreen : Color(white: 0.22))
                    .frame(width: 7, height: 7)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(prayer.name)
                    .font(compact
                          ? .caption.weight(isActive ? .semibold : .regular)
                          : .subheadline.weight(isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? .white : Color(white: 0.65))
                    .lineLimit(1)
                if !compact {
                    Text(prayer.arabicName)
                        .font(.caption2)
                        .foregroundStyle(Color.widgetMuted)
                }
            }

            Spacer(minLength: 8)

            Text(prayer.time, style: .time)
                .font(compact ? .caption.monospacedDigit() : .subheadline.monospacedDigit())
                .foregroundStyle(isActive ? Color.brandGreen : Color(white: 0.50))
        }
        .padding(.horizontal, compact ? 0 : 8)
        .padding(.vertical, compact ? 0 : 6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isActive ? Color.brandGreen.opacity(0.12) : .clear)
        )
    }
}

private struct WidgetActivityRow: View {
    let activity: WidgetActivityPayload

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.brandGreen.opacity(activity.isCompleted ? 0.25 : 0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: activity.systemIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.brandGreen)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(activity.isCompleted ? Color(white: 0.50) : .white)
                    .lineLimit(1)
                Text(activity.subtitle)
                    .font(.caption2)
                    .foregroundStyle(Color.widgetMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if activity.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandGreen)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.09))
        )
    }
}

private struct WidgetActivityPill: View {
    let activity: WidgetActivityPayload

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: activity.systemIcon)
                .font(.caption2)
            Text(activity.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
            if activity.isCompleted {
                Image(systemName: "checkmark")
                    .font(.caption2.bold())
            }
        }
        .foregroundStyle(activity.isCompleted ? Color.brandGreen : .white)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.brandGreen.opacity(activity.isCompleted ? 0.22 : 0.14))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.brandGreen.opacity(0.30), lineWidth: 0.5)
                )
        )
    }
}

private struct WidgetEmptyActivitiesView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.brandGreen.opacity(0.60))
            Text("Aucune activité planifiée")
                .font(.caption)
                .foregroundStyle(Color.widgetMuted)
        }
        .padding(.vertical, 6)
    }
}

private struct WidgetEmptyStateView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.title2)
                .foregroundStyle(Color.brandGreen)
                .shadow(color: Color.brandGreen.opacity(0.50), radius: 8, x: 0, y: 0)
            Text("PrayPlan")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Ouvrez l'app pour calculer les horaires et remplir le widget.")
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
    let prayers: [WidgetPrayerPayload]
    let activities: [WidgetActivityPayload]

    var segmentColor: Color {
        Color(hex: currentSegmentColorHex)
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
    static let suiteName = "group.PrayPlan"
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

    // Vibrant green for dark backgrounds
    static let brandGreen = Color(red: 0.20, green: 0.82, blue: 0.40)
    // Muted text on black
    static let widgetMuted = Color(white: 0.48)
}

// MARK: - Previews

#Preview(as: .systemSmall) {
    PrayPlanWidget()
} timeline: {
    PrayerWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    PrayPlanWidget()
} timeline: {
    PrayerWidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    PrayPlanWidget()
} timeline: {
    PrayerWidgetEntry.placeholder
}
