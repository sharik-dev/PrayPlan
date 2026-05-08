import SwiftUI
import SwiftData

// MARK: – Theme presets

struct GoalThemePreset: Identifiable {
    let id   = UUID()
    let name: String
    let icon: String
    let hex:  String
    var color: Color { Color(hex: hex) }
}

let kGoalThemes: [GoalThemePreset] = [
    .init(name: "Travail",        icon: "briefcase.fill",             hex: "#1565C0"),
    .init(name: "Apprentissage",  icon: "book.fill",                  hex: "#2E7D32"),
    .init(name: "Sport",          icon: "figure.run",                 hex: "#BF360C"),
    .init(name: "Détente",        icon: "leaf.fill",                  hex: "#00695C"),
    .init(name: "Famille",        icon: "house.fill",                 hex: "#6A1B9A"),
    .init(name: "Spiritualité",   icon: "moon.stars.fill",            hex: "#283593"),
    .init(name: "Créativité",     icon: "paintbrush.fill",            hex: "#AD1457"),
    .init(name: "Repos",          icon: "moon.zzz.fill",              hex: "#37474F"),
    .init(name: "Nutrition",      icon: "fork.knife",                 hex: "#558B2F"),
    .init(name: "Social",         icon: "person.2.fill",              hex: "#0277BD"),
    .init(name: "Finance",        icon: "chart.line.uptrend.xyaxis",  hex: "#4E342E"),
    .init(name: "Méditation",     icon: "brain.head.profile",         hex: "#4527A0"),
]

// MARK: – Main view

struct GoalsView: View {
    @Query(sort: \SegmentGoal.sortIndex) private var goals: [SegmentGoal]
    @Environment(PrayerTimeService.self) private var prayerService
    @State private var editingGoal: SegmentGoal?

    private var currentGoal: SegmentGoal? { goal(for: prayerService.currentSegment) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    currentSection
                    arcSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Mes Objectifs")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(item: $editingGoal) { GoalEditSheet(goal: $0) }
    }

    // MARK: – Current segment card

    @ViewBuilder
    private var currentSection: some View {
        if let g = currentGoal, g.hasContent {
            activeHeroCard(g)
        } else {
            emptyHeroCard
        }
    }

    private func activeHeroCard(_ goal: SegmentGoal) -> some View {
        Button { editingGoal = goal } label: {
            VStack(alignment: .leading, spacing: 14) {
                // Badge row
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption2.bold())
                    Text("En ce moment")
                        .font(.caption.bold())
                    Spacer()
                    Text(goal.segment.displayName)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(.white.opacity(0.18))
                        .clipShape(Capsule())
                }
                .foregroundStyle(.white.opacity(0.85))

                // Theme + intention
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.18))
                            .frame(width: 54, height: 54)
                        Image(systemName: goal.themeIcon.isEmpty ? goal.segment.systemIcon : goal.themeIcon)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(goal.themeName.isEmpty ? goal.segment.displayName : goal.themeName)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        if !goal.intention.isEmpty {
                            Text(goal.intention)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.82))
                                .lineLimit(2)
                        }
                    }
                }

                // Rules preview
                if !goal.rules.isEmpty {
                    Divider().overlay(.white.opacity(0.25))
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(goal.rules.prefix(3), id: \.self) { rule in
                            HStack(spacing: 9) {
                                Circle().fill(.white.opacity(0.55)).frame(width: 5, height: 5)
                                Text(rule)
                                    .font(.caption)
                                    .foregroundStyle(.white.opacity(0.88))
                                    .lineLimit(1)
                            }
                        }
                        if goal.rules.count > 3 {
                            Text("+\(goal.rules.count - 3) règle\(goal.rules.count - 3 > 1 ? "s" : "") supplémentaire\(goal.rules.count - 3 > 1 ? "s" : "")")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.55))
                                .padding(.leading, 14)
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(goal.segment.bannerGradient)
                    .shadow(color: goal.segment.bandColor.opacity(0.4), radius: 12, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyHeroCard: some View {
        let seg = prayerService.currentSegment
        return Button { editingGoal = goal(for: seg) } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(seg.bandColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: seg.systemIcon)
                        .font(.title3)
                        .foregroundStyle(seg.bandColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Définir l'objectif de maintenant")
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(seg.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.brandGreen)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(seg.bandColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: – Daily arc

    private var arcSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Arc de la journée")
                .font(.headline)
                .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(Array(PrayerSegment.allCases.enumerated()), id: \.element) { idx, seg in
                    if let g = goal(for: seg) {
                        arcRow(g, isLast: idx == PrayerSegment.allCases.count - 1)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    private func arcRow(_ goal: SegmentGoal, isLast: Bool) -> some View {
        let isCurrent = goal.segment == prayerService.currentSegment
        return Button { editingGoal = goal } label: {
            HStack(spacing: 0) {
                // Left timeline line + dot
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(isLast ? Color.clear : goal.segment.bandColor.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 18)

                // Segment icon
                ZStack {
                    Circle()
                        .fill(goal.segment.bandColor.opacity(isCurrent ? 0.2 : 0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: goal.segment.systemIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(goal.segment.bandColor)
                }
                .padding(.horizontal, 10)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(goal.segment.displayName)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        if isCurrent {
                            Text("maintenant")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.brandGreen.opacity(0.12))
                                .foregroundStyle(Color.brandGreen)
                                .clipShape(Capsule())
                        }
                    }

                    if goal.hasContent {
                        HStack(spacing: 5) {
                            if !goal.themeIcon.isEmpty {
                                Image(systemName: goal.themeIcon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(goal.themeColor)
                            }
                            Text(goal.themeName.isEmpty ? goal.intention : goal.themeName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if !goal.rules.isEmpty {
                                Text("· \(goal.rules.count) règle\(goal.rules.count > 1 ? "s" : "")")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } else {
                        Text("Aucun objectif défini")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.trailing, 14)
            }
            .padding(.vertical, 11)
            .background(isCurrent ? goal.segment.bandColor.opacity(0.05) : Color.clear)
            .overlay(alignment: .bottom) {
                if !isLast {
                    Divider().padding(.leading, 18 + 36 + 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func goal(for segment: PrayerSegment) -> SegmentGoal? {
        goals.first { $0.segment == segment }
    }
}

// MARK: – Edit Sheet

struct GoalEditSheet: View {
    @Bindable var goal: SegmentGoal
    @Environment(\.dismiss) private var dismiss

    @State private var showThemePicker = false
    @FocusState private var focusedRule: Int?

    var body: some View {
        NavigationStack {
            Form {
                segmentHeaderSection
                themeSection
                intentionSection
                rulesSection
                if goal.hasContent {
                    resetSection
                }
            }
            .navigationTitle(goal.segment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        goal.rules = goal.rules.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }

    // MARK: – Sections

    private var segmentHeaderSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(goal.segment.bandColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: goal.themeIcon.isEmpty ? goal.segment.systemIcon : goal.themeIcon)
                        .font(.title2)
                        .foregroundStyle(goal.themeIcon.isEmpty ? goal.segment.bandColor : goal.themeColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.segment.displayName)
                        .font(.headline)
                    Text(goal.hasContent
                         ? (goal.themeName.isEmpty ? "Intention définie" : goal.themeName)
                         : "Aucun objectif pour ce segment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var themeSection: some View {
        Section("Thème principal") {
            if showThemePicker {
                themePicker
            } else {
                themePickerButton
            }
        }
    }

    private var themePickerButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { showThemePicker = true }
        } label: {
            if goal.themeName.isEmpty {
                Label("Choisir un thème", systemImage: "plus.circle")
                    .foregroundStyle(Color.brandGreen)
            } else {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(goal.themeColor.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: goal.themeIcon)
                            .font(.system(size: 16))
                            .foregroundStyle(goal.themeColor)
                    }
                    Text(goal.themeName)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("Changer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var themePicker: some View {
        VStack(spacing: 0) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                spacing: 12
            ) {
                ForEach(kGoalThemes) { preset in
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            goal.themeName     = preset.name
                            goal.themeIcon     = preset.icon
                            goal.themeColorHex = preset.hex
                            showThemePicker    = false
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11)
                                    .fill(preset.color.opacity(goal.themeName == preset.name ? 0.25 : 0.1))
                                    .frame(width: 46, height: 46)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11)
                                            .strokeBorder(
                                                goal.themeName == preset.name ? preset.color : Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                                Image(systemName: preset.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(preset.color)
                            }
                            Text(preset.name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
        }
    }

    private var intentionSection: some View {
        Section {
            TextField(
                "Ex : Je produis, je ne consomme pas",
                text: $goal.intention,
                axis: .vertical
            )
            .lineLimit(2...4)
        } header: {
            Text("Mon intention")
        } footer: {
            Text("Une phrase courte qui oriente ton comportement pendant ce segment.")
        }
    }

    private var rulesSection: some View {
        Section {
            ForEach(goal.rules.indices, id: \.self) { i in
                HStack(spacing: 10) {
                    Circle()
                        .fill(goal.segment.bandColor.opacity(0.65))
                        .frame(width: 6, height: 6)
                    TextField("Règle \(i + 1)", text: ruleBinding(for: i))
                        .focused($focusedRule, equals: i)
                        .submitLabel(.done)
                        .onSubmit {
                            let next = i + 1
                            if next < goal.rules.count {
                                focusedRule = next
                            } else {
                                goal.rules = goal.rules + [""]
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    focusedRule = next
                                }
                            }
                        }
                }
            }
            .onDelete { offsets in
                var r = goal.rules
                r.remove(atOffsets: offsets)
                goal.rules = r
            }

            Button {
                let idx = goal.rules.count
                goal.rules = goal.rules + [""]
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { focusedRule = idx }
            } label: {
                Label("Ajouter une règle", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.brandGreen)
            }
        } header: {
            Text("Règles de conduite")
        } footer: {
            Text("Des engagements concrets qui définissent ce que tu fais — et ce que tu évites — pendant ce bloc.")
        }
    }

    private var resetSection: some View {
        Section {
            Button("Réinitialiser cet objectif", role: .destructive) {
                goal.themeName     = ""
                goal.themeIcon     = ""
                goal.themeColorHex = ""
                goal.intention     = ""
                goal.rules         = []
            }
        }
    }

    private func ruleBinding(for index: Int) -> Binding<String> {
        Binding(
            get: { index < goal.rules.count ? goal.rules[index] : "" },
            set: { val in
                var r = goal.rules
                guard index < r.count else { return }
                r[index] = val
                goal.rules = r
            }
        )
    }
}

// MARK: – SegmentGoal SwiftUI helpers

extension SegmentGoal {
    var themeColor: Color {
        Color(hex: themeColorHex.isEmpty ? "#2E7D32" : themeColorHex)
    }
}

// MARK: – Color(hex:)

private extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let v = UInt64(h, radix: 16) ?? 0
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8)  & 0xFF) / 255,
            blue:  Double(v & 0xFF)         / 255
        )
    }
}
