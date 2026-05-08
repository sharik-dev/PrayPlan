import SwiftUI
import SwiftData

struct TasksView: View {
    @Query(sort: \UserTask.createdAt, order: .reverse) private var tasks: [UserTask]
    @Environment(\.modelContext) private var context
    @State private var showingAdd = false
    @State private var editingTask: UserTask? = nil
    @State private var segmentFilter: PrayerSegment? = nil
    @State private var showCompleted = false

    private var filtered: [UserTask] {
        tasks.filter { t in
            (segmentFilter == nil || t.segment == segmentFilter!)
            && (showCompleted || !t.isCompleted)
        }
    }

    private var grouped: [(PrayerSegment, [UserTask])] {
        PrayerSegment.allCases.compactMap { seg in
            let items = filtered.filter { $0.segment == seg }
            return items.isEmpty ? nil : (seg, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty {
                    EmptyStateView(
                        icon: "checklist",
                        title: String(localized: "tasks.empty.title",    defaultValue: "Aucune tâche"),
                        subtitle: String(localized: "tasks.empty.subtitle", defaultValue: "Ajoutez des tâches liées à vos prières.")
                    )
                } else {
                    List {
                        ForEach(grouped, id: \.0) { segment, items in
                            Section {
                                ForEach(items) { task in
                                    TaskRowView(
                                        task: task,
                                        onToggle: { toggle(task) },
                                        onEdit: { editingTask = task }
                                    )
                                }
                                .onDelete { delete(items: items, offsets: $0) }
                            } header: {
                                SegmentBadge(segment: segment)
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.tasks", defaultValue: "Tâches"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker(String(localized: "filter.segment", defaultValue: "Segment"), selection: $segmentFilter) {
                            Text(String(localized: "filter.all", defaultValue: "Tous")).tag(Optional<PrayerSegment>.none)
                            ForEach(PrayerSegment.allCases) { seg in
                                Text(seg.displayName).tag(Optional(seg))
                            }
                        }
                        Toggle(String(localized: "filter.showCompleted", defaultValue: "Afficher terminées"), isOn: $showCompleted)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) { AddTaskView() }
            .sheet(item: $editingTask) { task in
                EditTaskView(task: task)
            }
        }
    }

    private func toggle(_ task: UserTask) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
    }

    private func delete(items: [UserTask], offsets: IndexSet) {
        for i in offsets { context.delete(items[i]) }
    }
}

struct TaskRowView: View {
    let task: UserTask
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let due = task.dueDate {
                    Text(due, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: task.priority.icon)
                    .font(.caption)
                    .foregroundStyle(task.priority == .high ? .red : task.priority == .medium ? .blue : .secondary)

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title    = ""
    @State private var notes    = ""
    @State private var segment  = PrayerSegment.dhuhrToAsr
    @State private var priority = TaskPriority.medium
    @State private var hasDate  = false
    @State private var dueDate  = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "addTask.section.info", defaultValue: "Informations")) {
                    TextField(String(localized: "addTask.title", defaultValue: "Titre"), text: $title)
                    TextField(String(localized: "addTask.notes", defaultValue: "Notes"), text: $notes, axis: .vertical)
                        .lineLimit(3)
                }

                Section(String(localized: "addTask.section.segment", defaultValue: "Bloc de prière")) {
                    Picker(String(localized: "addTask.segment", defaultValue: "Segment"), selection: $segment) {
                        ForEach(PrayerSegment.allCases) { seg in
                            Label(seg.displayName, systemImage: seg.systemIcon)
                                .tag(seg)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section(String(localized: "addTask.section.priority", defaultValue: "Priorité")) {
                    Picker(String(localized: "addTask.priority", defaultValue: "Priorité"), selection: $priority) {
                        ForEach(TaskPriority.allCases) { p in
                            Label(p.displayName, systemImage: p.icon).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "addTask.section.date", defaultValue: "Échéance")) {
                    Toggle(String(localized: "addTask.hasDate", defaultValue: "Date limite"), isOn: $hasDate)
                    if hasDate {
                        DatePicker("", selection: $dueDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }
            }
            .navigationTitle(String(localized: "addTask.title.nav", defaultValue: "Nouvelle tâche"))
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
        let task = UserTask(
            title: title.trimmingCharacters(in: .whitespaces),
            segment: segment,
            priority: priority,
            notes: notes,
            dueDate: hasDate ? dueDate : nil
        )
        context.insert(task)
        dismiss()
    }
}

struct EditTaskView: View {
    @Bindable var task: UserTask
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var hasDate = false

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "addTask.section.info", defaultValue: "Informations")) {
                    TextField(String(localized: "addTask.title", defaultValue: "Titre"), text: $task.title)
                    TextField(String(localized: "addTask.notes", defaultValue: "Notes"), text: $task.notes, axis: .vertical)
                        .lineLimit(3)
                }

                Section(String(localized: "addTask.section.segment", defaultValue: "Bloc de prière")) {
                    Picker(String(localized: "addTask.segment", defaultValue: "Segment"), selection: $task.segment) {
                        ForEach(PrayerSegment.allCases) { seg in
                            Label(seg.displayName, systemImage: seg.systemIcon)
                                .tag(seg)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                Section(String(localized: "addTask.section.priority", defaultValue: "Priorité")) {
                    Picker(String(localized: "addTask.priority", defaultValue: "Priorité"), selection: $task.priority) {
                        ForEach(TaskPriority.allCases) { p in
                            Label(p.displayName, systemImage: p.icon).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(String(localized: "addTask.section.date", defaultValue: "Échéance")) {
                    Toggle(String(localized: "addTask.hasDate", defaultValue: "Date limite"), isOn: $hasDate)
                    if hasDate {
                        DatePicker("", selection: dueDateBinding, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                    }
                }

                Section {
                    Button("Supprimer la tâche", role: .destructive) {
                        context.delete(task)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Modifier la tâche")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                hasDate = task.dueDate != nil
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "button.cancel", defaultValue: "Annuler")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        task.title = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !hasDate {
                            task.dueDate = nil
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { task.dueDate ?? Date() },
            set: { task.dueDate = $0 }
        )
    }
}
