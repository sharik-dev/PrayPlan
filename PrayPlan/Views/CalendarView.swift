import SwiftUI
import SwiftData

// MARK: – Constants

private let kHourHeight: CGFloat = 64   // pts per hour  → 24 × 64 = 1536pt total
private let kLabelWidth: CGFloat = 44   // left column for hour labels

// MARK: – Main View

struct CalendarView: View {
    @State private var selectedDate        = Calendar.current.startOfDay(for: Date())
    @State private var isDrawMode          = false
    @State private var isBlockInteracting  = false
    @State private var quickCreate: QuickCreateContext? = nil
    @State private var noteTarget: DayNote? = nil
    @State private var editingTask: UserTask? = nil

    @Query(sort: \UserTask.createdAt, order: .reverse) private var tasks: [UserTask]
    @Query private var habits: [UserHabit]
    @Query private var notes: [DayNote]
    @Environment(PrayerTimeService.self) private var prayerService
    @Environment(\.modelContext) private var context

    private let cal = Calendar.current
    private var isToday: Bool { cal.isDateInToday(selectedDate) }

    private var selectedSchedule: DailyPrayerSchedule? {
        prayerService.weekSchedules.first { cal.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var dayTasks: [UserTask] {
        if isToday { return tasks.filter { !$0.isCompleted } }
        return tasks.filter { t in
            guard let due = t.dueDate else { return false }
            return cal.isDate(due, inSameDayAs: selectedDate)
        }
    }

    private var dayHabits: [UserHabit] {
        habits.filter { !$0.isArchived && $0.isActiveOn(selectedDate) }
    }

    private var dayNotes: [DayNote] {
        notes.filter { cal.isDate($0.dayStart, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                WeekStripPicker(selectedDate: $selectedDate)
                Divider()

                if let schedule = selectedSchedule {
                    timelineContainer(schedule: schedule)
                } else {
                    EmptyStateView(
                        icon: "calendar.badge.clock",
                        title: "Horaires indisponibles",
                        subtitle: "Ouvrez l'onglet Prières pour calculer les horaires."
                    )
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(item: $quickCreate) { ctx in
                QuickCreateSheet(context: ctx, dayStart: selectedDate)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $noteTarget) { NoteEditSheet(note: $0) }
            .sheet(item: $editingTask) { task in
                EditTaskView(task: task)
            }
        }
    }

    // MARK: – Timeline container

    @ViewBuilder
    private func timelineContainer(schedule: DailyPrayerSchedule) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                TimelineGrid(
                    schedule: schedule,
                    dayTasks: dayTasks,
                    dayHabits: dayHabits,
                    dayNotes: dayNotes,
                    selectedDate: selectedDate,
                    isToday: isToday,
                    isDrawMode: isDrawMode,
                    onDrawSelect: { startH, endH, seg in
                        isDrawMode = false
                        quickCreate = QuickCreateContext(startMinute: startH * 60, durationMinutes: max(60, (endH - startH) * 60), segment: seg)
                    },
                    onTapMinute: { minute, seg in
                        quickCreate = QuickCreateContext(startMinute: minute, segment: seg)
                    },
                    onEditTask: { editingTask = $0 },
                    onEditNote: { noteTarget = $0 },
                    onDeleteNote: { context.delete($0) },
                    onToggleTask: { t in
                        t.isCompleted.toggle()
                        t.completedAt = t.isCompleted ? Date() : nil
                    },
                    onToggleHabit: { h in toggleHabit(h) },
                    isBlockInteracting: $isBlockInteracting
                )
            }
            .scrollDisabled(isDrawMode || isBlockInteracting)
            .onAppear {
                let target = isToday ? max(0, cal.component(.hour, from: Date()) - 2) : 5
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { proxy.scrollTo("h\(target)", anchor: .top) }
                }
            }
            .onChange(of: selectedDate) {
                let target = isToday ? max(0, cal.component(.hour, from: Date()) - 2) : 5
                withAnimation { proxy.scrollTo("h\(target)", anchor: .top) }
            }
        }
    }

    // MARK: – Helpers

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 14) {
                Button {
                    withAnimation(.spring(duration: 0.3)) { isDrawMode.toggle() }
                } label: {
                    Image(systemName: isDrawMode ? "pencil.slash" : "pencil.and.outline")
                        .foregroundStyle(isDrawMode ? Color.brandGreen : Color.primary)
                }

                Menu {
                    Button {
                        quickCreate = QuickCreateContext(startMinute: currentHour * 60, segment: segmentForCurrentHour)
                    } label: {
                        Label("Nouvelle tâche", systemImage: "checklist")
                    }
                    Button {
                        quickCreate = QuickCreateContext(startMinute: currentHour * 60, segment: segmentForCurrentHour, defaultMode: .habit)
                    } label: {
                        Label("Nouvelle habitude", systemImage: "repeat.circle")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private var currentHour: Int { cal.component(.hour, from: Date()) }

    private var segmentForCurrentHour: PrayerSegment {
        selectedSchedule?.currentSegment(at: Date()) ?? .dhuhrToAsr
    }

    private var navTitle: String {
        if isToday { return "Aujourd'hui" }
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: selectedDate).capitalized
    }

    private func toggleHabit(_ habit: UserHabit) {
        if habit.isCompleted(on: selectedDate) {
            if let c = habit.completions.first(where: { cal.isDate($0.completedOn, inSameDayAs: selectedDate) }) {
                context.delete(c)
            }
        } else {
            let c = HabitCompletion(completedOn: selectedDate)
            c.habit = habit
            habit.completions.append(c)
            context.insert(c)
        }
    }
}

// MARK: – Quick Create Context

struct QuickCreateContext: Identifiable {
    let id = UUID()
    var startMinute: Int        // minutes from midnight
    var durationMinutes: Int = 60
    var segment: PrayerSegment
    var defaultMode: QuickCreateSheet.Mode = .task
}

// MARK: – Timeline Grid

private struct TimelineGrid: View {
    let schedule: DailyPrayerSchedule
    let dayTasks: [UserTask]
    let dayHabits: [UserHabit]
    let dayNotes: [DayNote]
    let selectedDate: Date
    let isToday: Bool
    let isDrawMode: Bool
    let onDrawSelect: (Int, Int, PrayerSegment) -> Void
    let onTapMinute: (Int, PrayerSegment) -> Void
    let onEditTask: (UserTask) -> Void
    let onEditNote: (DayNote) -> Void
    let onDeleteNote: (DayNote) -> Void
    let onToggleTask: (UserTask) -> Void
    let onToggleHabit: (UserHabit) -> Void
    @Binding var isBlockInteracting: Bool

    @GestureState private var drawGestureState: DrawGestureState = .idle
    private let cal = Calendar.current

    enum DrawGestureState {
        case idle
        case pressing
        case drawing(startY: CGFloat, currentY: CGFloat)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1 – Hour grid (lines + labels)
            hourGridLayer

            // 2 – Prayer segment background bands
            ForEach(PrayerSegment.allCases) { seg in
                prayerBand(seg)
            }

            // 3 – Prayer time markers
            ForEach(schedule.allPrayers, id: \.key) { prayer in
                prayerMarkerRow(prayer)
            }

            // 4 – Habits near their segment start
            ForEach(PrayerSegment.allCases) { seg in
                let segHabits = dayHabits.filter { $0.segment == seg }
                if !segHabits.isEmpty {
                    habitChips(segHabits, seg: seg)
                }
            }

            // 5 – Tasks near their segment start
            ForEach(PrayerSegment.allCases) { seg in
                let segTasks = dayTasks.filter { $0.segment == seg && $0.startMinute < 0 }
                if !segTasks.isEmpty {
                    taskChips(segTasks, seg: seg)
                }
            }

            // 6 – Notes at their hour
            ForEach(dayNotes) { note in
                noteChip(note)
            }

            // 7 – Current time red line
            if isToday { currentTimeLine }

            // 8 – Draw mode overlay
            if isDrawMode { drawModeOverlay }

            // 9 – Tap targets (non-draw mode)
            if !isDrawMode { tapTargetLayer }

            // 10 – Scheduled task blocks (on top so gestures take priority)
            if !isDrawMode { scheduledTaskBlocksLayer }
        }
        .frame(height: CGFloat(24) * kHourHeight)
        .frame(maxWidth: .infinity)
    }

    // MARK: – Layers

    private var hourGridLayer: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                for h in 0..<24 {
                    let y = CGFloat(h) * kHourHeight
                    var line = Path()
                    line.move(to: CGPoint(x: kLabelWidth - 4, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    ctx.stroke(line, with: .color(.secondary.opacity(0.13)), lineWidth: 0.5)
                    // half-hour tick
                    let yHalf = y + kHourHeight * 0.5
                    var half = Path()
                    half.move(to: CGPoint(x: kLabelWidth - 4, y: yHalf))
                    half.addLine(to: CGPoint(x: size.width, y: yHalf))
                    ctx.stroke(half, with: .color(.secondary.opacity(0.06)), lineWidth: 0.5)
                }
            }
            .frame(height: CGFloat(24) * kHourHeight)
            .overlay(
                VStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02dh", h))
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: kLabelWidth - 6, height: kHourHeight, alignment: .top)
                            .padding(.top, 3)
                            .id("h\(h)")
                    }
                },
                alignment: .topLeading
            )
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    private func prayerBand(_ seg: PrayerSegment) -> some View {
        let start = minuteY(schedule.startTime(of: seg))
        let end   = minuteY(schedule.endTime(of: seg))
        let h     = end > start ? end - start : (CGFloat(24) * kHourHeight - start + end)
        let clampedH = min(h, CGFloat(24) * kHourHeight - start)
        return GeometryReader { geo in
            Rectangle()
                .fill(seg.bandColor.opacity(0.06))
                .frame(width: geo.size.width - kLabelWidth, height: max(0, clampedH))
                .offset(x: kLabelWidth, y: start)
        }
        .frame(height: CGFloat(24) * kHourHeight)
        .allowsHitTesting(false)
    }

    private func prayerMarkerRow(_ prayer: (name: String, arabicName: String, time: Date, key: String)) -> some View {
        let y   = minuteY(prayer.time)
        let seg = segmentForKey(prayer.key)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill((seg?.bannerGradient) ?? LinearGradient(colors: [.secondary], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 3)
                HStack(spacing: 6) {
                    Image(systemName: seg?.systemIcon ?? "clock")
                        .font(.system(size: 10, weight: .bold))
                    Text(prayer.name)
                        .font(.system(size: 12, weight: .bold))
                    Text(prayer.arabicName)
                        .font(.system(size: 10))
                        .opacity(0.85)
                    Spacer()
                    Text(prayer.time, style: .time)
                        .font(.system(size: 11, design: .monospaced))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(seg?.bannerGradient ?? LinearGradient(colors: [.secondary], startPoint: .leading, endPoint: .trailing))
            }
            .frame(width: geo.size.width - kLabelWidth + 4, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .offset(x: kLabelWidth - 4, y: y - 13)
        }
        .frame(height: CGFloat(24) * kHourHeight)
        .allowsHitTesting(false)
    }

    private func habitChips(_ segHabits: [UserHabit], seg: PrayerSegment) -> some View {
        let y = minuteY(schedule.startTime(of: seg)) + 28
        return GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(segHabits) { habit in
                        HabitTimelineChip(
                            habit: habit,
                            isCompleted: habit.isCompleted(on: selectedDate),
                            onToggle: { onToggleHabit(habit) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: geo.size.width - kLabelWidth - 8)
            .offset(x: kLabelWidth + 4, y: y)
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    private func taskChips(_ segTasks: [UserTask], seg: PrayerSegment) -> some View {
        let baseY = minuteY(schedule.startTime(of: seg)) + 28 + (dayHabits.filter { $0.segment == seg }.isEmpty ? 0 : 36)
        return GeometryReader { geo in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(segTasks) { task in
                        TaskTimelineChip(
                            task: task,
                            color: seg.bandColor,
                            onToggle: { onToggleTask(task) },
                            onEdit: { onEditTask(task) }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            .frame(width: geo.size.width - kLabelWidth - 8)
            .offset(x: kLabelWidth + 4, y: baseY)
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    private func noteChip(_ note: DayNote) -> some View {
        let y = CGFloat(note.hour) * kHourHeight + 4
        return GeometryReader { geo in
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(note.content.isEmpty ? "Note vide" : note.content)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .foregroundStyle(note.content.isEmpty ? Color.secondary : Color.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: geo.size.width - kLabelWidth - 16, alignment: .leading)
            .background(Color.yellow.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .offset(x: kLabelWidth + 6, y: y)
            .onTapGesture { onEditNote(note) }
            .contextMenu {
                Button("Modifier") { onEditNote(note) }
                Button("Supprimer", role: .destructive) { onDeleteNote(note) }
            }
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    private var currentTimeLine: some View {
        let now = Date()
        let y   = minuteY(now)
        return GeometryReader { geo in
            HStack(spacing: 0) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .offset(x: kLabelWidth - 4)
                Rectangle()
                    .fill(Color.red)
                    .frame(width: geo.size.width - kLabelWidth + 4, height: 1.5)
            }
            .offset(y: y - 4)
        }
        .frame(height: CGFloat(24) * kHourHeight)
        .allowsHitTesting(false)
    }

    // MARK: – Draw mode overlay

    private var drawModeOverlay: some View {
        GeometryReader { geo in
            let longThenDrag = LongPressGesture(minimumDuration: 0.35)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                .updating($drawGestureState) { value, state, _ in
                    switch value {
                    case .first(true): state = .pressing
                    case .second(true, let drag?):
                        state = .drawing(startY: drag.startLocation.y, currentY: drag.location.y)
                    default: break
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        let yS = min(drag.startLocation.y, drag.location.y)
                        let yE = max(drag.startLocation.y, drag.location.y)
                        let startH = max(0, min(23, Int(yS / kHourHeight)))
                        let endH   = min(23, max(startH + 1, Int(yE / kHourHeight) + 1))
                        let midDate = cal.date(bySettingHour: (startH + endH) / 2, minute: 0, second: 0, of: selectedDate) ?? Date()
                        onDrawSelect(startH, endH, schedule.currentSegment(at: midDate))
                    }
                }

            ZStack(alignment: .topLeading) {
                Color.brandGreen.opacity(0.04)
                    .contentShape(Rectangle())
                    .gesture(longThenDrag)

                // hint
                if case .pressing = drawGestureState {
                    Text("Faites glisser pour créer")
                        .font(.caption.bold())
                        .foregroundStyle(Color.brandGreen)
                        .padding(8)
                        .background(Color(.systemBackground).opacity(0.9))
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                }

                // selection rect
                if case .drawing(let yStart, let yCurrent) = drawGestureState {
                    let top    = min(yStart, yCurrent)
                    let height = max(kHourHeight * 0.5, abs(yCurrent - yStart))
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.brandGreen.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.brandGreen, lineWidth: 2))
                        .frame(width: geo.size.width - kLabelWidth - 10, height: height)
                        .offset(x: kLabelWidth + 5, y: top)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: geo.size.width, height: CGFloat(24) * kHourHeight)
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    // MARK: – Tap targets

    private var tapTargetLayer: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geo.size.width - kLabelWidth, height: CGFloat(24) * kHourHeight)
                .offset(x: kLabelWidth)
                .gesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            let rawMin = Int(value.location.y / kHourHeight * 60)
                            let snapped = max(0, min(23 * 60 + 45, (rawMin / 15) * 15))
                            let h = snapped / 60, m = snapped % 60
                            let date = cal.date(bySettingHour: h, minute: m, second: 0, of: selectedDate) ?? Date()
                            onTapMinute(snapped, schedule.currentSegment(at: date))
                        }
                )
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    // MARK: – Scheduled task blocks

    private var scheduledTaskBlocksLayer: some View {
        GeometryReader { geo in
            let blockWidth = geo.size.width - kLabelWidth - 14
            ForEach(dayTasks.filter { $0.startMinute >= 0 }) { task in
                ScheduledTaskBlock(task: task, width: blockWidth, isGlobalInteracting: $isBlockInteracting)
                    .onTapGesture {
                        if !isBlockInteracting {
                            onEditTask(task)
                        }
                    }
                    .offset(x: kLabelWidth + 7)
            }
        }
        .frame(height: CGFloat(24) * kHourHeight)
    }

    // MARK: – Utility

    private func minuteY(_ date: Date) -> CGFloat {
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return CGFloat(h) * kHourHeight + CGFloat(m) / 60.0 * kHourHeight
    }

    private func segmentForKey(_ key: String) -> PrayerSegment? {
        switch key {
        case "fajr":    return .fajrToSunrise
        case "sunrise": return .sunriseToDhuhr
        case "dhuhr":   return .dhuhrToAsr
        case "asr":     return .asrToMaghrib
        case "maghrib": return .maghribToIsha
        case "isha":    return .ishaTofajr
        default:        return nil
        }
    }
}

// MARK: – Timeline item chips

private struct HabitTimelineChip: View {
    let habit: UserHabit
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 5) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : habit.iconName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isCompleted ? Color.brandGreen : habit.segment.bandColor)
                Text(habit.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isCompleted ? .secondary : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                isCompleted
                    ? Color.brandGreen.opacity(0.1)
                    : habit.segment.bandColor.opacity(0.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isCompleted ? Color.brandGreen.opacity(0.5) : habit.segment.bandColor.opacity(0.4),
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TaskTimelineChip: View {
    let task: UserTask
    let color: Color
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(task.isCompleted ? Color.brandGreen : color)
            }
            .buttonStyle(.plain)
            Text(task.title)
                .font(.system(size: 11, weight: .medium))
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
                .lineLimit(1)
            Image(systemName: task.priority.icon)
                .font(.system(size: 9))
                .foregroundStyle(
                    task.priority == .high ? .red
                    : task.priority == .medium ? .blue
                    : .secondary
                )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(task.isCompleted ? Color(.tertiarySystemFill) : color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(task.isCompleted ? Color.secondary.opacity(0.2) : color.opacity(0.4), lineWidth: 1)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onTapGesture(perform: onEdit)
    }
}

// MARK: – Scheduled Task Block

/// Gesture state shared by both move and resize interactions.
private enum BlockInteractionState: Equatable {
    case idle
    case pressing           // long-press in progress, not yet dragging
    case dragging(CGFloat)  // translation (pts)

    var isActive: Bool { if case .idle = self { return false }; return true }
    var translation: CGFloat { if case .dragging(let t) = self { return t }; return 0 }
}

private struct ScheduledTaskBlock: View {
    @Bindable var task: UserTask
    let width: CGFloat
    @Binding var isGlobalInteracting: Bool

    // Move gesture state (long press 0.28s → drag)
    @GestureState private var moveState:   BlockInteractionState = .idle
    // Resize gesture state (long press 0.12s → drag)
    @GestureState private var resizeState: BlockInteractionState = .idle

    @State private var isLifted  = false
    @State private var isResizing = false

    private var yBase: CGFloat { CGFloat(task.startMinute) / 60.0 * kHourHeight }
    private var hBase: CGFloat { max(kHourHeight * 0.5, CGFloat(task.durationMinutes) / 60.0 * kHourHeight) }

    var body: some View {
        let liveY = yBase + moveState.translation
        let liveH = max(kHourHeight * 0.5, hBase + resizeState.translation)
        let anyActive = moveState.isActive || resizeState.isActive

        ZStack(alignment: .topLeading) {
            // Ghost outline at original position while dragging
            if moveState.isActive {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(task.segment.bandColor.opacity(0.35), lineWidth: 1.5)
                    .frame(width: width, height: hBase)
                    .offset(y: yBase)
                    .allowsHitTesting(false)
            }

            // Live block
            VStack(spacing: 0) {
                // ── Move handle strip (top 22pt)
                moveHandleStrip
                // ── Main content (flex)
                blockContentArea
                    .frame(maxHeight: .infinity)
                // ── Resize handle strip (bottom 22pt)
                resizeHandleStrip
            }
            .frame(width: width, height: liveH)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                task.segment.bandColor.opacity(task.isCompleted ? 0.4 : 0.92),
                                task.segment.bandColor.opacity(task.isCompleted ? 0.3 : 0.72)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    // Left accent bar
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 3)
                    }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(
                color: task.segment.bandColor.opacity(anyActive ? 0.45 : 0.18),
                radius: anyActive ? 16 : 4,
                x: 0, y: anyActive ? 8 : 2
            )
            .scaleEffect(anyActive ? 1.025 : 1.0, anchor: .top)
            .offset(y: liveY)
            .zIndex(anyActive ? 100 : 2)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: anyActive)
        }
        // Sync global scroll-lock binding
        .onChange(of: moveState) { _, s in
            isGlobalInteracting = s.isActive || resizeState.isActive
            withAnimation(.spring(response: 0.22, dampingFraction: 0.7)) { isLifted = s.isActive }
        }
        .onChange(of: resizeState) { _, s in
            isGlobalInteracting = moveState.isActive || s.isActive
            isResizing = s.isActive
        }
    }

    // MARK: – Sub-views

    private var moveHandleStrip: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .fill(Color.white.opacity(isLifted ? 0.8 : 0.45))
                    .frame(width: 14, height: 2.5)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 22)
        .contentShape(Rectangle())
        // Long press (0.28s) → drag to MOVE
        .gesture(
            LongPressGesture(minimumDuration: 0.28)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                .updating($moveState) { value, state, _ in
                    switch value {
                    case .first(true):           state = .pressing
                    case .second(true, let d?):  state = .dragging(d.translation.height)
                    default:                     state = .idle
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        let delta = Int(round(drag.translation.height / kHourHeight * 60 / 15) * 15)
                        task.startMinute = max(0, min(23 * 60, task.startMinute + delta))
                    }
                    isGlobalInteracting = false
                }
        )
    }

    private var blockContentArea: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : task.priority.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(task.title)
                    .font(.caption.bold())
                    .lineLimit(hBase > kHourHeight ? 2 : 1)
                    .strikethrough(task.isCompleted)
            }
            .foregroundStyle(.white)
            if hBase >= kHourHeight * 0.8 {
                Text(timeRangeLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.2)) {
                task.isCompleted.toggle()
                task.completedAt = task.isCompleted ? Date() : nil
            }
        }
    }

    private var resizeHandleStrip: some View {
        HStack {
            Spacer()
            Capsule()
                .fill(Color.white.opacity(isResizing ? 0.9 : 0.5))
                .frame(width: 32, height: 3.5)
            Spacer()
        }
        .frame(height: 22)
        .background(Color.white.opacity(0.001)) // extend hit area
        .contentShape(Rectangle())
        // Long press (0.12s) → drag to RESIZE
        .gesture(
            LongPressGesture(minimumDuration: 0.12)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                .updating($resizeState) { value, state, _ in
                    switch value {
                    case .first(true):           state = .pressing
                    case .second(true, let d?):  state = .dragging(d.translation.height)
                    default:                     state = .idle
                    }
                }
                .onEnded { value in
                    if case .second(true, let drag?) = value {
                        let delta = Int(round(drag.translation.height / kHourHeight * 60 / 15) * 15)
                        task.durationMinutes = max(15, task.durationMinutes + delta)
                    }
                    isGlobalInteracting = false
                }
        )
    }

    private var timeRangeLabel: String {
        let sh = task.startMinute / 60, sm = task.startMinute % 60
        let end = task.startMinute + task.durationMinutes
        let eh  = min(23, end / 60), em = end % 60
        return String(format: "%02d:%02d – %02d:%02d", sh, sm, eh, em)
    }
}

// MARK: – Week Strip

private struct WeekStripPicker: View {
    @Binding var selectedDate: Date

    private let cal = Calendar.current
    private var days: [Date] {
        let today = cal.startOfDay(for: Date())
        return (-7...7).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(days, id: \.self) { day in
                        DayChipView(day: day, isSelected: cal.isDate(day, inSameDayAs: selectedDate))
                            .id(day)
                            .onTapGesture { selectedDate = day }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .onAppear { proxy.scrollTo(cal.startOfDay(for: Date()), anchor: .center) }
        }
        .background(Color(.secondarySystemGroupedBackground))
    }
}

private struct DayChipView: View {
    let day: Date
    let isSelected: Bool

    private let cal = Calendar.current
    private var isToday: Bool { cal.isDateInToday(day) }

    private var dayLetter: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE"
        return String(f.string(from: day).prefix(2)).uppercased()
    }
    private var dayNumber: String {
        DateFormatter().apply { $0.dateFormat = "d" }.string(from: day)
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(dayLetter)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? Color.brandGreen : .secondary)
            Text(dayNumber)
                .font(.subheadline.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? .white : isToday ? .brandGreen : .primary)
                .frame(width: 32, height: 32)
                .background(isSelected ? Color.brandGreen : (isToday ? Color.brandGreen.opacity(0.12) : Color.clear))
                .clipShape(Circle())
        }
        .frame(width: 36)
    }
}

private extension DateFormatter {
    func apply(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        configure(self)
        return self
    }
}

// MARK: – Quick Create Sheet

struct QuickCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let context2: QuickCreateContext
    let dayStart: Date

    init(context ctx: QuickCreateContext, dayStart: Date) {
        self.context2 = ctx
        self.dayStart = dayStart
        _mode = State(initialValue: ctx.defaultMode)
        _selectedSegment = State(initialValue: ctx.segment)
        _startMinute = State(initialValue: ctx.startMinute)
        _durationMinutes = State(initialValue: ctx.durationMinutes)
    }

    enum Mode: String, CaseIterable {
        case task = "Tâche"
        case habit = "Habitude"
    }

    @State private var mode: Mode
    @State private var title = ""
    @State private var selectedSegment: PrayerSegment
    @State private var startMinute: Int
    @State private var durationMinutes: Int
    @State private var priority: TaskPriority = .medium
    @State private var frequency: HabitFrequency = .daily
    @State private var customDays: Set<Int> = []
    @State private var iconName = "star.fill"
    @State private var showIconPicker = false

    private let iconOptions = [
        "star.fill", "heart.fill", "book.fill", "figure.walk", "drop.fill",
        "moon.fill", "sun.max.fill", "brain.fill", "dumbbell.fill",
        "leaf.fill", "pencil", "music.note", "fork.knife", "house.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // Type picker
                Section {
                    Picker("", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // Title + icon (habit only)
                Section {
                    if mode == .habit {
                        HStack {
                            Button { showIconPicker.toggle() } label: {
                                Image(systemName: iconName)
                                    .font(.title3)
                                    .frame(width: 40, height: 40)
                                    .background(Color(.tertiarySystemFill))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            TextField("Titre", text: $title)
                        }
                        if showIconPicker {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                                ForEach(iconOptions, id: \.self) { icon in
                                    Button { iconName = icon; showIconPicker = false } label: {
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
                    } else {
                        TextField("Titre", text: $title)
                    }
                }

                // Time slot (tâche uniquement)
                if mode == .task {
                    Section("Créneau horaire") {
                        HStack {
                            Label(
                                String(format: "%02d:%02d → %02d:%02d",
                                       startMinute / 60, startMinute % 60,
                                       (startMinute + durationMinutes) / 60, (startMinute + durationMinutes) % 60),
                                systemImage: "clock"
                            )
                            Spacer()
                            Stepper("", value: $startMinute, in: 0...(23 * 60 + 45), step: 15)
                                .labelsHidden()
                        }
                        HStack {
                            Label(durationLabel, systemImage: "timer")
                            Spacer()
                            Stepper("", value: $durationMinutes, in: 15...480, step: 15)
                                .labelsHidden()
                        }
                    }
                }

                // Segment
                Section("Bloc de prière") {
                    Picker("Segment", selection: $selectedSegment) {
                        ForEach(PrayerSegment.allCases) { seg in
                            Label(seg.displayName, systemImage: seg.systemIcon).tag(seg)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Task: priority
                if mode == .task {
                    Section("Priorité") {
                        Picker("", selection: $priority) {
                            ForEach(TaskPriority.allCases) { p in
                                Label(p.displayName, systemImage: p.icon).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Habit: recurrence
                if mode == .habit {
                    Section("Récurrence") {
                        HStack(spacing: 0) {
                            ForEach(HabitFrequency.allCases) { f in
                                Button {
                                    frequency = f
                                    if f != .custom { customDays = [] }
                                } label: {
                                    Text(f.displayName)
                                        .font(.caption.weight(frequency == f ? .bold : .regular))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(frequency == f ? Color.brandGreen : Color.clear)
                                        .foregroundStyle(frequency == f ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        if frequency == .custom {
                            CustomDaysPicker(selectedDays: $customDays)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle(mode == .task ? "Nouvelle tâche" : "Nouvelle habitude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
    }

    private var durationLabel: String {
        let h = durationMinutes / 60, m = durationMinutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h)h" }
        return "\(h)h\(String(format: "%02d", m))"
    }

    private func save() {
        let clean = title.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        if mode == .task {
            let task = UserTask(title: clean, segment: selectedSegment, priority: priority)
            task.startMinute    = startMinute
            task.durationMinutes = durationMinutes
            if !Calendar.current.isDateInToday(dayStart) { task.dueDate = dayStart }
            context.insert(task)
        } else {
            let habit = UserHabit(title: clean, iconName: iconName, segment: selectedSegment, frequency: frequency)
            if frequency == .custom { habit.customDays = customDays }
            context.insert(habit)
        }
        dismiss()
    }
}

// MARK: – Custom days picker

struct CustomDaysPicker: View {
    @Binding var selectedDays: Set<Int>

    // weekday: 1=Sun 2=Mon 3=Tue 4=Wed 5=Thu 6=Fri 7=Sat
    private let days: [(Int, String)] = [(2,"L"),(3,"M"),(4,"M"),(5,"J"),(6,"V"),(7,"S"),(1,"D")]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(days, id: \.0) { wd, label in
                let on = selectedDays.contains(wd)
                Button {
                    if on { selectedDays.remove(wd) } else { selectedDays.insert(wd) }
                } label: {
                    Text(label)
                        .font(.caption.bold())
                        .frame(width: 34, height: 34)
                        .background(on ? Color.brandGreen : Color(.tertiarySystemFill))
                        .foregroundStyle(on ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: – Note edit sheet (kept from previous version)

private struct NoteEditSheet: View {
    @Bindable var note: DayNote
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Heure") {
                    Picker("Heure", selection: $note.hour) {
                        ForEach(4..<24, id: \.self) { h in
                            Text(String(format: "%02d:00", h)).tag(h)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
                Section("Note") {
                    TextEditor(text: $note.content)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle("Modifier la note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
    }
}

private extension DailyPrayerSchedule {
    func currentSegment() -> PrayerSegment { currentSegment(at: Date()) }
}
