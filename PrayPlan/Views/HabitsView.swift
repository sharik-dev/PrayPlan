import SwiftUI
import SwiftData

struct HabitsView: View {
    @Query private var habits: [UserHabit]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false

    private var todayActive: [UserHabit] {
        habits.filter { !$0.isArchived && $0.isActiveToday() }
    }

    private var grouped: [(PrayerSegment, [UserHabit])] {
        PrayerSegment.allCases.compactMap { seg in
            let items = todayActive.filter { $0.segment == seg }
            return items.isEmpty ? nil : (seg, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if todayActive.isEmpty {
                    EmptyStateView(
                        icon: "repeat.circle.fill",
                        title: String(localized: "habits.empty.title",    defaultValue: "Aucune habitude"),
                        subtitle: String(localized: "habits.empty.subtitle", defaultValue: "Créez des habitudes pour chaque bloc de prière.")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.0) { segment, items in
                            Section {
                                ForEach(items) { habit in
                                    HabitRowView(habit: habit) {
                                        toggleCompletion(habit)
                                    }
                                }
                                .onDelete { delete(items: items, offsets: $0) }
                            } header: {
                                SegmentBadge(segment: segment)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.habits", defaultValue: "Habitudes"))
            .toolbar {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) { AddHabitView() }
        }
    }

    private func toggleCompletion(_ habit: UserHabit) {
        if habit.isCompleted(on: Date()) {
            if let completion = habit.completions.first(where: {
                Calendar.current.isDateInToday($0.completedOn)
            }) {
                context.delete(completion)
            }
        } else {
            let completion = HabitCompletion(completedOn: Date())
            completion.habit = habit
            habit.completions.append(completion)
            context.insert(completion)
        }
    }

    private func delete(items: [UserHabit], offsets: IndexSet) {
        for i in offsets { items[i].isArchived = true }
    }
}

struct HabitRowView: View {
    let habit: UserHabit
    let onToggle: () -> Void

    private var isCompletedToday: Bool { habit.isCompleted(on: Date()) }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(isCompletedToday ? .brandGreen : Color(.tertiarySystemFill))
                        .frame(width: 40, height: 40)
                    Image(systemName: habit.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(isCompletedToday ? .white : .secondary)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.subheadline.weight(isCompletedToday ? .regular : .medium))
                    .foregroundStyle(isCompletedToday ? .secondary : .primary)

                let streak = habit.currentStreak
                if streak > 0 {
                    Label("\(streak) \(String(localized: "habit.days", defaultValue: "jours"))", systemImage: "flame.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            if isCompletedToday {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(Color.brandGreen)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title      = ""
    @State private var iconName   = "star.fill"
    @State private var segment    = PrayerSegment.fajrToSunrise
    @State private var frequency  = HabitFrequency.daily
    @State private var customDays = Set<Int>()
    @State private var showIconPicker = false

    private let iconOptions = [
        "star.fill", "heart.fill", "book.fill", "figure.walk", "drop.fill",
        "moon.fill", "sun.max.fill", "brain.fill", "dumbbell.fill",
        "leaf.fill", "pencil", "music.note", "fork.knife", "house.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "addHabit.section.info", defaultValue: "Informations")) {
                    HStack {
                        Button { showIconPicker.toggle() } label: {
                            Image(systemName: iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(Color(.tertiarySystemFill))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                        TextField(String(localized: "addHabit.title", defaultValue: "Nom de l'habitude"), text: $title)
                    }

                    if showIconPicker {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                            ForEach(iconOptions, id: \.self) { icon in
                                Button {
                                    iconName = icon
                                    showIconPicker = false
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 36, height: 36)
                                        .background(iconName == icon ? Color.brandGreen.opacity(0.2) : Color(.tertiarySystemFill))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(String(localized: "addHabit.section.segment", defaultValue: "Bloc de prière")) {
                    Picker(String(localized: "addHabit.segment", defaultValue: "Segment"), selection: $segment) {
                        ForEach(PrayerSegment.allCases) { seg in
                            Label(seg.displayName, systemImage: seg.systemIcon).tag(seg)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section(String(localized: "addHabit.section.frequency", defaultValue: "Récurrence")) {
                    Picker(String(localized: "addHabit.frequency", defaultValue: "Fréquence"), selection: $frequency) {
                        ForEach(HabitFrequency.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: frequency) { _, new in
                        if new != .custom { customDays = [] }
                    }

                    if frequency == .custom {
                        CustomDaysPicker(selectedDays: $customDays)
                            .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(String(localized: "addHabit.title.nav", defaultValue: "Nouvelle habitude"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel", defaultValue: "Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "button.add", defaultValue: "Ajouter")) { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let habit = UserHabit(
            title: title.trimmingCharacters(in: .whitespaces),
            iconName: iconName,
            segment: segment,
            frequency: frequency
        )
        if frequency == .custom { habit.customDays = customDays }
        context.insert(habit)
        dismiss()
    }
}
