import SwiftData
import SwiftUI

/// **L'onglet Examen** : le prochain examen en grand, avec son compte à rebours, les autres en
/// dessous, et l'examen blanc chronométré, sur une ou plusieurs leçons, noté dans le barème du
/// pays.
///
/// Un examen se déclare ici ou à la création d'une leçon (sa date). Un examen blanc se lance
/// depuis un examen (ses leçons sont déjà choisies) ou seul. Le premier est offert, les
/// suivants sont dans Pro (`ExamAllowance`, `begin_extra` côté serveur).
struct ExamsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @Query(sort: \Exam.date) private var exams: [Exam]
    @Query(sort: \Course.updatedAt, order: .reverse) private var courses: [Course]

    @State private var path = NavigationPath()
    @State private var editing: ExamEditTarget?
    @State private var mock: MockExamStart?
    @State private var history: [ExamPaperResult] = []
    @State private var shown = false

    private var lessons: [Course] { courses.filter { $0.isLesson && $0.source != .deck } }
    private var upcoming: [Exam] { exams.filter { !$0.isPast() } }
    private var past: [Exam] { exams.filter { $0.isPast() }.reversed() }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    MicaboPageHeading(title: i18n.t("lesson.tab.exams"), subtitle: subtitle) {
                        MicaboCircleButton(systemImage: "plus", style: .dark, size: 44, accessibilityTitle: i18n.t("lesson.exam.new")) {
                            editing = .new
                        }
                    }
                    .padding(.top, MicaboSpacing.xs)

                    if let next = upcoming.first {
                        ExamHero(exam: next, lessons: lessonsOf(next), best: bestResult(for: next)) {
                            mock = MockExamStart(exam: next)
                        } onEdit: {
                            editing = .edit(next)
                        }
                        .slideIn(shown, delay: 0.05)
                    } else {
                        emptyCard
                            .slideIn(shown, delay: 0.05)
                    }

                    mockCard
                        .slideIn(shown, delay: 0.12)

                    if upcoming.count > 1 {
                        section(i18n.t("lesson.exam.upcoming"))
                        VStack(spacing: 12) {
                            ForEach(Array(upcoming.dropFirst())) { exam in
                                ExamRow(exam: exam, lessonCount: lessonsOf(exam).count) { editing = .edit(exam) }
                            }
                        }
                        .slideIn(shown, delay: 0.18)
                    }

                    if !history.isEmpty {
                        section(i18n.t("lesson.exam.history"))
                        VStack(spacing: 10) {
                            ForEach(history.prefix(8)) { result in
                                MockResultRow(result: result)
                            }
                        }
                        .slideIn(shown, delay: 0.22)
                    }

                    if !past.isEmpty {
                        section(i18n.t("lesson.exam.past"))
                        VStack(spacing: 10) {
                            ForEach(past.prefix(6)) { exam in
                                ExamRow(exam: exam, lessonCount: lessonsOf(exam).count) { editing = .edit(exam) }
                                    .opacity(0.6)
                            }
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .exams, depth: path.count)
            .returnsHome(path: $path)
        }
        .sheet(item: $editing) { target in
            ExamEditSheet(target: target, lessons: lessons)
        }
        .fullScreenCover(item: $mock, onDismiss: reloadHistory) { start in
            MockExamFlow(start: start, lessons: lessons)
        }
        .onAppear {
            reloadHistory()
            withAnimation(.spring(duration: 0.6)) { shown = true }
        }
    }

    private var subtitle: String {
        switch upcoming.count {
        case 0: i18n.t("lesson.exam.none")
        case 1: i18n.t("lesson.exam.countOne")
        default: i18n.t("lesson.exam.count", ["count": "\(upcoming.count)"])
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(MicaboFont.ui(20, weight: .heavy))
            .foregroundStyle(MicaboColor.ink)
            .padding(.top, 4)
    }

    private func lessonsOf(_ exam: Exam) -> [Course] {
        let wanted = Set(exam.courseIDs)
        return lessons.filter { wanted.contains($0.id) }
    }

    private func bestResult(for exam: Exam) -> ExamPaperResult? {
        history.filter { $0.examID == exam.id }.max { $0.fraction < $1.fraction }
    }

    private func reloadHistory() {
        history = ExamHistory.all()
    }

    // MARK: Sans examen

    private var emptyCard: some View {
        VStack(spacing: 14) {
            MikaMascot(mood: .wave, size: 120)
            Text(i18n.t("lesson.exam.emptyTitle"))
                .font(MicaboFont.ui(22, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Text(i18n.t("lesson.exam.emptyBody"))
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
            Button {
                editing = .new
            } label: {
                Label(i18n.t("lesson.exam.new"), systemImage: "calendar.badge.plus")
            }
            .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }

    // MARK: L'examen blanc

    private var mockCard: some View {
        Button {
            Haptics.medium()
            mock = MockExamStart(exam: nil)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(MicaboColor.accentSoft)
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(MicaboColor.accent)
                        .symbolEffect(.bounce, value: shown)
                }
                .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(i18n.t("lesson.exam.mockTitle"))
                        .font(MicaboFont.ui(19, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                    Text(i18n.t("lesson.exam.mockBody"))
                        .font(MicaboFont.ui(14.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(18)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            .micaboElevation(.card)
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .disabled(lessons.isEmpty)
        .opacity(lessons.isEmpty ? 0.5 : 1)
    }
}

// MARK: - Le prochain examen

/// **Le prochain examen, en grand** : le compte à rebours qui se lit d'abord (« J-12 »), le
/// nom, le jour, les leçons, la meilleure note d'examen blanc, et le bouton qui en lance un.
struct ExamHero: View {
    let exam: Exam
    let lessons: [Course]
    let best: ExamPaperResult?
    let onMock: () -> Void
    let onEdit: () -> Void

    @State private var pulse = false

    private var days: Int { max(0, exam.daysRemaining()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("lesson.exam.upNext", locale: .resolved()))
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(MicaboColor.onInk.opacity(0.8))
                    Text(exam.name)
                        .font(MicaboFont.display(28))
                        .foregroundStyle(MicaboColor.onInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(MicaboCalendar.dayLabel(exam.date).capitalizedFirstLetter)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.onInk.opacity(0.85))
                }
                Spacer(minLength: 8)
                Button(action: onEdit) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(MicaboColor.onInk)
                        .frame(width: 38, height: 38)
                        .background(MicaboColor.onInk.opacity(0.18), in: Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("lesson.exam.edit", locale: .resolved())))
            }

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                Text(days == 0 ? L10n.t("app.exams.countdown.today", locale: .resolved()) : "J-\(days)")
                    .font(MicaboFont.number(days == 0 ? 44 : 64))
                    .foregroundStyle(MicaboColor.onInk)
                    .contentTransition(.numericText())
                    .scaleEffect(pulse ? 1.04 : 1, anchor: .leading)
                if days > 0 {
                    Text(L10n.t(days == 1 ? "lesson.exam.dayLeft" : "lesson.exam.daysLeft", locale: .resolved()))
                        .font(MicaboFont.ui(17, weight: .bold))
                        .foregroundStyle(MicaboColor.onInk.opacity(0.85))
                }
                Spacer(minLength: 0)
                if let best {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(ExamGrade.label(best.fraction, country: OnboardingPreferences.schoolingCountry))
                            .font(MicaboFont.number(22))
                            .foregroundStyle(MicaboColor.onInk)
                        Text(L10n.t("lesson.exam.best", locale: .resolved()))
                            .font(MicaboFont.ui(12, weight: .bold))
                            .foregroundStyle(MicaboColor.onInk.opacity(0.8))
                    }
                }
            }

            if !lessons.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(lessons) { course in
                            HStack(spacing: 6) {
                                MicaboIconView(icon: course.icon, size: 22)
                                Text(course.title)
                                    .font(MicaboFont.ui(13.5, weight: .bold))
                                    .foregroundStyle(MicaboColor.ink)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(MicaboColor.surface, in: Capsule())
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            Button(action: onMock) {
                Label(L10n.t("lesson.exam.startMock", locale: .resolved()), systemImage: "stopwatch")
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(MicaboColor.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .disabled(lessons.isEmpty)
            .opacity(lessons.isEmpty ? 0.6 : 1)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [MicaboColor.accent, MicaboColor.accentVivid], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(MicaboColor.onInk.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .offset(x: 70, y: -90)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
        .shadow(color: MicaboColor.accent.opacity(0.3), radius: 20, x: 0, y: 12)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

/// Un examen dans la liste : le compte à rebours en pastille, le nom, le jour.
struct ExamRow: View {
    let exam: Exam
    let lessonCount: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(exam.countdownLabel())
                    .font(MicaboFont.number(15))
                    .foregroundStyle(MicaboColor.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: 70, height: 50)
                    .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(exam.name)
                        .font(MicaboFont.ui(17, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                    Text("\(MicaboCalendar.shortDayLabel(exam.date)) · \(L10n.t("lesson.exam.lessonCount", locale: .resolved(), vars: ["count": "\(lessonCount)"]))")
                        .font(MicaboFont.ui(14, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(14)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}

/// Un examen blanc rendu : la note dans le barème du pays, le titre, le jour.
struct MockResultRow: View {
    let result: ExamPaperResult

    var body: some View {
        let passes = ExamGrade.passes(result.fraction)
        HStack(spacing: 14) {
            Text(ExamGrade.label(result.fraction, country: OnboardingPreferences.schoolingCountry))
                .font(MicaboFont.number(16))
                .foregroundStyle(passes ? MicaboColor.correctInk : MicaboColor.wrongInk)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 70, height: 46)
                .background(passes ? MicaboColor.correctSoft : MicaboColor.wrongSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(result.title)
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                Text("\(MicaboCalendar.shortDayLabel(result.date)) · \(result.correct)/\(result.total) · \(result.minutes) min")
                    .font(MicaboFont.ui(13.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
    }
}

// MARK: - Déclarer un examen

enum ExamEditTarget: Identifiable {
    case new
    case edit(Exam)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let exam): exam.id.uuidString
        }
    }
}

/// **Un examen** : son nom, son jour, ses leçons. On peut le modifier ou le supprimer.
struct ExamEditSheet: View {
    let target: ExamEditTarget
    let lessons: [Course]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var selected: Set<UUID> = []
    @State private var confirmDelete = false
    @State private var loaded = false

    private var existing: Exam? {
        if case .edit(let exam) = target { return exam }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    field(L10n.t("lesson.exam.name", locale: .resolved())) {
                        TextField(L10n.t("lesson.exam.namePlaceholder", locale: .resolved()), text: $name)
                            .font(MicaboFont.ui(18, weight: .semibold))
                            .padding(16)
                            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                    }

                    field(L10n.t("lesson.exam.date", locale: .resolved())) {
                        DatePicker("", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(MicaboColor.accent)
                            .padding(8)
                            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                    }

                    field(L10n.t("lesson.exam.lessons", locale: .resolved())) {
                        LessonChecklist(lessons: lessons, selected: $selected)
                    }

                    if existing != nil {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label(L10n.t("lesson.exam.delete", locale: .resolved()), systemImage: "trash")
                                .font(MicaboFont.ui(16, weight: .bold))
                                .foregroundStyle(MicaboColor.wrongInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(MicaboPressableButtonStyle())
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(L10n.t("lesson.exam.save", locale: .resolved()), action: save)
                    .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent, enabled: canSave))
                    .disabled(!canSave)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.bottom, 8)
                    .background(MicaboColor.canvas)
            }
            .navigationTitle(L10n.t(existing == nil ? "lesson.exam.new" : "lesson.exam.edit", locale: .resolved()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("app.common.cancel", locale: .resolved())) { dismiss() }
                }
            }
            .confirmationDialog(
                L10n.t("lesson.exam.deleteConfirm", locale: .resolved()),
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button(L10n.t("lesson.exam.delete", locale: .resolved()), role: .destructive) {
                    if let existing { try? ExamRepository.delete(existing, in: modelContext) }
                    dismiss()
                }
            }
        }
        .onAppear(perform: load)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(MicaboFont.ui(15, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
            content()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            name = existing.name
            date = existing.date
            selected = Set(existing.courseIDs)
        } else if let first = lessons.first {
            selected = [first.id]
        }
    }

    private func save() {
        let ids = lessons.map(\.id).filter(selected.contains)
        if let existing {
            try? ExamRepository.update(existing, name: name, date: date, courseIDs: ids, intensity: existing.intensity, in: modelContext)
        } else {
            _ = try? ExamRepository.create(name: name, date: date, courseIDs: ids, intensity: .standard, in: modelContext)
        }
        Haptics.success()
        dismiss()
    }
}

/// Les leçons à cocher, avec leur icône.
struct LessonChecklist: View {
    let lessons: [Course]
    @Binding var selected: Set<UUID>

    var body: some View {
        if lessons.isEmpty {
            Text(L10n.t("lesson.exam.noLessons", locale: .resolved()))
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
        } else {
            VStack(spacing: 10) {
                ForEach(lessons) { course in
                    let isOn = selected.contains(course.id)
                    Button {
                        Haptics.selection()
                        if isOn { selected.remove(course.id) } else { selected.insert(course.id) }
                    } label: {
                        HStack(spacing: 12) {
                            MicaboIconView(icon: course.icon, size: 38)
                            Text(course.title)
                                .font(MicaboFont.ui(16, weight: .bold))
                                .foregroundStyle(MicaboColor.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(isOn ? MicaboColor.accent : MicaboColor.inkTertiary)
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .padding(12)
                        .background(isOn ? MicaboColor.accentSoft : MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isOn ? MicaboColor.accent : MicaboColor.stroke, lineWidth: isOn ? 2 : 1.5))
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                }
            }
        }
    }
}

extension View {
    /// Apparaît en glissant d'un peu plus bas, avec un léger retard.
    func slideIn(_ shown: Bool, delay: Double) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .animation(.spring(duration: 0.55).delay(delay), value: shown)
    }
}
