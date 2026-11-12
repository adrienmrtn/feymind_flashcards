import SwiftData
import SwiftUI

/// **Toutes les tâches** : à faire, puis faites. Une tâche se coche d'un appui et se supprime
/// d'un balayage ; le « + » en ajoute une.
struct TasksSheet: View {
    let lessons: [Course]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StudyTask.createdAt) private var tasks: [StudyTask]
    @State private var adding = false

    private var open: [StudyTask] {
        tasks.filter { !$0.isDone }.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (left?, right?): return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.createdAt < rhs.createdAt
            }
        }
    }

    private var done: [StudyTask] {
        tasks.filter(\.isDone).sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
    }

    private var lessonTitles: [UUID: String] {
        Dictionary(lessons.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    Text(loc("ios.focus.tasksEmpty"))
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .listRowBackground(MicaboColor.surface)
                }
                if !open.isEmpty {
                    Section(loc("ios.focus.todo")) {
                        ForEach(open) { task in
                            row(task)
                        }
                        .onDelete { offsets in delete(offsets.map { open[$0] }) }
                    }
                }
                if !done.isEmpty {
                    Section(loc("ios.focus.done")) {
                        ForEach(done) { task in
                            row(task)
                        }
                        .onDelete { offsets in delete(offsets.map { done[$0] }) }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .navigationTitle(loc("ios.focus.tasks"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("ios.done", locale: .resolved())) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        adding = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text(loc("ios.focus.addTask")))
                }
            }
            .sheet(isPresented: $adding) {
                TaskEditSheet(lessons: lessons)
            }
        }
    }

    private func row(_ task: StudyTask) -> some View {
        FocusTaskRow(task: task.spec, lessonTitle: task.courseID.flatMap { lessonTitles[$0] }) {
            task.isDone.toggle()
            task.doneAt = task.isDone ? Date() : nil
            try? modelContext.save()
            if task.isDone { Haptics.success() }
        }
        .listRowBackground(MicaboColor.surface)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                delete([task])
            } label: {
                Label(loc("ios.focus.deleteTask"), systemImage: "trash")
            }
        }
    }

    private func delete(_ items: [StudyTask]) {
        for task in items { modelContext.delete(task) }
        try? modelContext.save()
        Haptics.warning()
    }
}

/// **Une nouvelle tâche** : un titre, une échéance si l'on veut (elle apparaît alors dans le
/// calendrier), une leçon si elle en parle.
struct TaskEditSheet: View {
    let lessons: [Course]
    var initialDue: Date? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var hasDue = false
    @State private var due = MicaboCalendar.shared.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var courseID: UUID?
    @State private var choosingLesson = false
    @State private var saved = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField(loc("ios.focus.taskPlaceholder"), text: $title, axis: .vertical)
                        .font(MicaboFont.ui(18, weight: .semibold))
                        .lineLimit(1...3)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(save)
                        .padding(16)
                        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))

                    VStack(spacing: 0) {
                        Toggle(isOn: $hasDue.animation(MicaboMotion.standard)) {
                            Label(loc("ios.focus.dueDate"), systemImage: "calendar")
                                .font(MicaboFont.ui(16, weight: .bold))
                                .foregroundStyle(MicaboColor.ink)
                        }
                        .tint(MicaboColor.accent)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        if hasDue {
                            MicaboHairline(inset: 14)
                            DatePicker("", selection: $due, in: MicaboCalendar.shared.startOfDay(for: Date())..., displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(MicaboColor.accent)
                                .padding(.horizontal, 8)
                        }
                    }
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))

                    Button {
                        choosingLesson = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(MicaboColor.accentInk)
                            Text(lessons.first { $0.id == courseID }?.title ?? loc("ios.cal.chooseLesson"))
                                .font(MicaboFont.ui(16, weight: .bold))
                                .foregroundStyle(courseID == nil ? MicaboColor.inkSecondary : MicaboColor.ink)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 13, weight: .heavy))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .flipsForRightToLeftLayoutDirection(true)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                    }
                    .buttonStyle(HomePressStyle(scale: 0.98))
                    .disabled(lessons.isEmpty)
                    .opacity(lessons.isEmpty ? 0.6 : 1)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(loc("ios.focus.addTask"), action: save)
                    .buttonStyle(MicaboBrandButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 8)
                    .background(MicaboColor.canvas)
            }
            .navigationTitle(loc("ios.focus.newTask"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("app.common.cancel", locale: .resolved())) { dismiss() }
                }
            }
            .navigationDestination(isPresented: $choosingLesson) {
                LessonPickerSheet(lessons: lessons, selected: courseID) { courseID = $0?.id }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let initialDue {
                hasDue = true
                due = initialDue
            }
            focused = true
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard !saved, canSave else { return }
        saved = true
        let clean = String(TextSanitizer.clean(title).trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        modelContext.insert(StudyTask(
            title: clean,
            dueDate: hasDue ? MicaboCalendar.shared.startOfDay(for: due) : nil,
            courseID: courseID
        ))
        try? modelContext.save()
        Analytics.track(.taskAdded, ["due": .flag(hasDue), "lesson": .flag(courseID != nil)])
        Haptics.success()
        dismiss()
    }
}
