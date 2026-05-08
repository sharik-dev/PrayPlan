import SwiftUI
import SwiftData

struct AnalyticsView: View {
    @Query private var habits: [UserHabit]
    @Query private var tasks: [UserTask]

    @State private var period: Int = 7

    private let cal = Calendar.current

    private var startDate: Date {
        cal.date(byAdding: .day, value: -(period - 1), to: cal.startOfDay(for: Date())) ?? Date()
    }

    private var activeHabits: [UserHabit] { habits.filter { !$0.isArchived } }

    private var completedInPeriod: [UserTask] {
        tasks.filter {
            $0.isCompleted &&
            ($0.completedAt ?? $0.createdAt) >= startDate
        }
    }

    private var overallHabitRate: Double {
        guard !activeHabits.isEmpty else { return 0 }
        let expected = activeHabits.reduce(0) { $0 + expectedCount(for: $1) }
        let done = activeHabits.reduce(0) { $0 + completionCount(for: $1) }
        guard expected > 0 else { return 0 }
        return Double(done) / Double(expected)
    }

    private var bestStreak: Int {
        activeHabits.map { $0.currentStreak }.max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("", selection: $period) {
                        Text(String(localized: "analytics.7days", defaultValue: "7 jours")).tag(7)
                        Text(String(localized: "analytics.30days", defaultValue: "30 jours")).tag(30)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    overviewGrid
                        .padding(.horizontal)

                    habitSection
                        .padding(.horizontal)

                    taskSegmentSection
                        .padding(.horizontal)

                    taskPrioritySection
                        .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "tab.analytics", defaultValue: "Statistiques"))
        }
    }

    // MARK: – Overview

    private var overviewGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
            spacing: 12
        ) {
            AnalyticsCard(
                value: "\(completedInPeriod.count)",
                label: "Tâches\nterminées",
                icon: "checkmark.circle.fill",
                iconColor: .brandGreen
            )
            AnalyticsCard(
                value: "\(Int(overallHabitRate * 100))%",
                label: "Taux\nhabitudes",
                icon: "repeat.circle.fill",
                iconColor: .blue
            )
            AnalyticsCard(
                value: "\(bestStreak)j",
                label: "Meilleur\nstreak",
                icon: "flame.fill",
                iconColor: .orange
            )
        }
    }

    // MARK: – Habits

    private var habitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "analytics.habits", defaultValue: "Habitudes"))
                .font(.headline)
                .padding(.leading, 4)

            if activeHabits.isEmpty {
                emptyCard(message: "Aucune habitude active")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(activeHabits.enumerated()), id: \.element.id) { idx, habit in
                        HabitStatRow(
                            habit: habit,
                            completions: completionCount(for: habit),
                            expected: expectedCount(for: habit)
                        )
                        if idx < activeHabits.count - 1 {
                            Divider().padding(.leading, 28)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: – Tasks by segment

    private var taskSegmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "analytics.bySegment", defaultValue: "Tâches par intervalle"))
                .font(.headline)
                .padding(.leading, 4)

            let data = segmentData()
            let maxVal = data.values.max() ?? 1

            VStack(spacing: 0) {
                ForEach(Array(PrayerSegment.allCases.enumerated()), id: \.element.id) { idx, segment in
                    let count = data[segment] ?? 0
                    HStack(spacing: 10) {
                        Image(systemName: segment.systemIcon)
                            .font(.caption)
                            .foregroundStyle(segment.color)
                            .frame(width: 20)

                        Text(segmentShortName(segment))
                            .font(.caption)
                            .lineLimit(1)
                            .frame(width: 72, alignment: .leading)

                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(segment.color.opacity(0.75))
                                .frame(
                                    width: maxVal > 0
                                        ? max(4, geo.size.width * CGFloat(count) / CGFloat(maxVal))
                                        : 4
                                )
                                .animation(.easeOut(duration: 0.3), value: period)
                        }
                        .frame(height: 16)

                        Text("\(count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 22, alignment: .trailing)
                    }
                    .padding(.vertical, 8)

                    if idx < PrayerSegment.allCases.count - 1 {
                        Divider().padding(.leading, 30)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: – Tasks by priority

    private var taskPrioritySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "analytics.byPriority", defaultValue: "Tâches par priorité"))
                .font(.headline)
                .padding(.leading, 4)

            HStack(spacing: 12) {
                PriorityStatCard(
                    count: completedInPeriod.filter { $0.priority == .high }.count,
                    total: completedInPeriod.count,
                    label: "Haute",
                    color: .red,
                    icon: "exclamationmark.circle.fill"
                )
                PriorityStatCard(
                    count: completedInPeriod.filter { $0.priority == .medium }.count,
                    total: completedInPeriod.count,
                    label: "Normale",
                    color: .blue,
                    icon: "minus.circle.fill"
                )
                PriorityStatCard(
                    count: completedInPeriod.filter { $0.priority == .low }.count,
                    total: completedInPeriod.count,
                    label: "Faible",
                    color: .secondary,
                    icon: "arrow.down.circle.fill"
                )
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: – Helpers

    private func completionCount(for habit: UserHabit) -> Int {
        habit.completions.filter { $0.completedOn >= startDate }.count
    }

    private func expectedCount(for habit: UserHabit) -> Int {
        var count = 0
        var day = startDate
        let today = cal.startOfDay(for: Date())
        while day <= today {
            if habit.isActiveOn(day) { count += 1 }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return count
    }

    private func segmentData() -> [PrayerSegment: Int] {
        var data: [PrayerSegment: Int] = [:]
        for s in PrayerSegment.allCases { data[s] = 0 }
        for task in completedInPeriod { data[task.segment, default: 0] += 1 }
        return data
    }

    private func segmentShortName(_ segment: PrayerSegment) -> String {
        switch segment {
        case .fajrToSunrise:  return "Fajr"
        case .sunriseToDhuhr: return "Lever"
        case .dhuhrToAsr:     return "Dhuhr"
        case .asrToMaghrib:   return "Asr"
        case .maghribToIsha:  return "Maghrib"
        case .ishaTofajr:     return "Isha"
        }
    }

    private func emptyCard(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: – Sub-views

private struct AnalyticsCard: View {
    let value: String
    let label: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.title2.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct HabitStatRow: View {
    let habit: UserHabit
    let completions: Int
    let expected: Int

    private var rate: Double {
        guard expected > 0 else { return 0 }
        return min(1, Double(completions) / Double(expected))
    }

    private var barColor: Color {
        rate >= 0.8 ? .brandGreen : rate >= 0.5 ? .yellow : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: habit.iconName)
                    .font(.subheadline)
                    .foregroundStyle(Color.brandGreen)
                    .frame(width: 20)
                Text(habit.title)
                    .font(.subheadline)
                    .lineLimit(1)
                Spacer()
                if habit.currentStreak > 0 {
                    Label("\(habit.currentStreak)j", systemImage: "flame.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                Text("\(completions)/\(expected)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: rate)
                .tint(barColor)
                .animation(.easeOut(duration: 0.4), value: rate)
        }
        .padding(.vertical, 6)
    }
}

private struct PriorityStatCard: View {
    let count: Int
    let total: Int
    let label: String
    let color: Color
    let icon: String

    private var pct: Int {
        guard total > 0 else { return 0 }
        return Int(Double(count) / Double(total) * 100)
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(count)")
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(pct)%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
