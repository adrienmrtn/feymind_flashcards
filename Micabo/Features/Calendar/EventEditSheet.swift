import SwiftData
import SwiftUI

/// Ce que la feuille d'un événement modifie : un nouvel événement (sur un jour), ou un
/// événement existant, vu sur l'une de ses occurrences.
enum EventEditTarget: Identifiable {
    case new(day: Date)
    case edit(CalendarEvent, occurrence: Date)

    var id: String {
        switch self {
        case .new(let day): "new-\(day.timeIntervalSince1970)"
        case .edit(let event, let day): "\(event.id.uuidString)-\(day.timeIntervalSince1970)"
        }
    }
}

/// **Un événement** : le titre, le calendrier, le jour, les heures, la répétition chaque
/// semaine, la salle, une note, et une leçon liée si l'on veut l'ouvrir d'un geste.
struct EventEditSheet: View {
    let target: EventEditTarget
    let calendars: [StudyCalendar]
    let lessons: [Course]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var title = ""
    @State private var calendarID: UUID?
    @State private var day = Date()
    @State private var start = 8 * 60
    @State private var end = 9 * 60
    @State private var weekly = false
    @State private var room = ""
    @State private var notes = ""
    @State private var courseID: UUID?
    @State private var choosingLesson = false
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var saved = false

    private var existing: CalendarEvent? {
        if case .edit(let event, _) = target { return event }
        return nil
    }

    private var occurrence: Date? {
        if case .edit(_, let day) = target { return day }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        StudyFieldLabel(text: loc("ios.cal.eventTitle"))
                        StudyTextField(placeholder: loc("ios.cal.eventPlaceholder"), text: $title)
                    }
                    calendarPicker
                    timeBlock
                    VStack(alignment: .leading, spacing: 10) {
                        StudyFieldLabel(text: loc("ios.cal.details"))
                        StudyTextField(placeholder: loc("ios.cal.roomPlaceholder"), text: $room)
                        StudyTextField(placeholder: loc("ios.cal.notesPlaceholder"), text: $notes, axis: .vertical)
                    }
                    lessonRow
                    if existing != nil {
                        Button(role: .destructive) {
                            confirmDelete = true
                        } label: {
                            Label(loc("ios.cal.deleteEvent"), systemImage: "trash")
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
            .scrollDismissesKeyboard(.interactively)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(loc("ios.cal.save"), action: save)
                    .buttonStyle(MicaboBrandButtonStyle())
                    .disabled(!canSave)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 8)
                    .background(MicaboColor.canvas)
            }
            .navigationTitle(loc(existing == nil ? "ios.cal.newEvent" : "ios.cal.editEvent"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("app.common.cancel", locale: .resolved())) { dismiss() }
                }
            }
            .sheet(isPresented: $choosingLesson) {
                LessonPickerSheet(lessons: lessons, selected: courseID) { course in
                    courseID = course?.id
                    if title.trimmingCharacters(in: .whitespaces).isEmpty, let course {
                        title = course.title
                    }
                }
            }
            .confirmationDialog(loc("ios.cal.deleteEventQ"), isPresented: $confirmDelete, titleVisibility: .visible) {
                if existing?.repeatsWeekly == true {
                    Button(loc("ios.cal.deleteOne"), role: .destructive) { delete(all: false) }
                    Button(loc("ios.cal.deleteAll"), role: .destructive) { delete(all: true) }
                } else {
                    Button(loc("ios.cal.deleteEvent"), role: .destructive) { delete(all: true) }
                }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Les blocs

    private var calendarPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudyFieldLabel(text: loc("ios.cal.calendar"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(calendars) { calendar in
                        let isOn = calendar.id == calendarID
                        Button {
                            calendarID = calendar.id
                        } label: {
                            HStack(spacing: 6) {
                                Text(calendar.emoji)
                                Text(calendar.name)
                                    .font(MicaboFont.ui(14.5, weight: .black))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(isOn ? Color.white : MicaboColor.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .background(isOn ? calendar.tint.color : calendar.tint.wash, in: Capsule())
                        }
                        .buttonStyle(HomePressStyle(scale: 0.94, feedback: .selection))
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var timeBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudyFieldLabel(text: loc("ios.cal.when"))
            VStack(spacing: 0) {
                row(loc("ios.cal.day")) {
                    DatePicker("", selection: $day, displayedComponents: .date)
                        .labelsHidden()
                }
                MicaboHairline(inset: 14)
                row(loc("ios.cal.start")) {
                    DatePicker("", selection: minuteBinding($start), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                MicaboHairline(inset: 14)
                row(loc("ios.cal.end")) {
                    DatePicker("", selection: minuteBinding($end), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                }
                MicaboHairline(inset: 14)
                Toggle(isOn: $weekly) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("ios.cal.weekly"))
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                        Text(loc("ios.cal.weeklySub", ["day": MicaboCalendar.weekdayName(MicaboCalendar.isoWeekday(of: day))]))
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                }
                .tint(MicaboColor.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .tint(MicaboColor.accent)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if end <= start {
                Text(loc("ios.cal.timeInvalid"))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.wrongInk)
            }
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(MicaboFont.ui(16, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
            Spacer()
            content()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
    }

    private var lessonRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            StudyFieldLabel(text: loc("ios.cal.linkedLesson"))
            Button {
                choosingLesson = true
            } label: {
                HStack(spacing: 12) {
                    if let course = lessons.first(where: { $0.id == courseID }) {
                        MicaboIconView(icon: course.icon, size: 34)
                        Text(course.title)
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "book.closed")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(MicaboColor.accentInk)
                            .frame(width: 34, height: 34)
                            .background(MicaboColor.accentSoft, in: Circle())
                        Text(loc("ios.cal.chooseLesson"))
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 56)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(HomePressStyle(scale: 0.98))
            .disabled(lessons.isEmpty)
            .opacity(lessons.isEmpty ? 0.6 : 1)
        }
    }

    private func minuteBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { CalendarTime.date(minute: minute.wrappedValue, on: day) },
            set: { minute.wrappedValue = CalendarTime.minute(of: $0) }
        )
    }

    // MARK: Charger, enregistrer, supprimer

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && end > start && calendarID != nil
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing {
            title = existing.title
            calendarID = existing.calendarID
            day = existing.repeatsWeekly ? existing.day : (occurrence ?? existing.day)
            start = existing.startMinute
            end = existing.endMinute
            weekly = existing.repeatsWeekly
            room = existing.room
            notes = existing.notes
            courseID = existing.courseID
        } else {
            if case .new(let wanted) = target { day = wanted }
            calendarID = (calendars.first { $0.kind == .classes } ?? calendars.first)?.id
            // Le prochain quart d'heure plein si c'est aujourd'hui, 8 h sinon.
            if MicaboCalendar.shared.isDateInToday(day) {
                let now = CalendarTime.minute(of: Date()) + 15
                start = min(22 * 60, Int((Double(now) / 15).rounded(.up)) * 15)
            }
            end = min(CalendarTime.dayMinutes - 1, start + 60)
        }
    }

    private func save() {
        guard !saved, canSave, let calendarID else { return }
        saved = true
        let cleanTitle = String(TextSanitizer.clean(title).trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let first = MicaboCalendar.shared.startOfDay(for: day)
        if let existing {
            existing.title = cleanTitle
            existing.calendarID = calendarID
            existing.day = first
            existing.startMinute = start
            existing.endMinute = end
            existing.repeatsWeekly = weekly
            existing.room = room.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.courseID = courseID
            existing.updatedAt = Date()
        } else {
            modelContext.insert(CalendarEvent(
                calendarID: calendarID,
                title: cleanTitle,
                day: first,
                startMinute: start,
                endMinute: end,
                repeatsWeekly: weekly,
                room: room.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                courseID: courseID,
                kind: calendars.first { $0.id == calendarID }?.kind == .classes ? .lesson : .custom
            ))
            Analytics.track(.calendarEventAdded, ["weekly": .flag(weekly)])
        }
        try? modelContext.save()
        StudyNotifications.refresh(in: modelContext)
        Haptics.success()
        dismiss()
    }

    private func delete(all: Bool) {
        guard let existing else { return }
        if all || !existing.repeatsWeekly {
            modelContext.delete(existing)
        } else if let occurrence {
            existing.skippedDays.append(MicaboCalendar.shared.startOfDay(for: occurrence))
            existing.updatedAt = Date()
        }
        try? modelContext.save()
        StudyNotifications.refresh(in: modelContext)
        dismiss()
    }
}

/// **Choisir une leçon** : la liste des leçons, avec une recherche. « Aucune » retire le lien.
struct LessonPickerSheet: View {
    let lessons: [Course]
    let selected: UUID?
    let onPick: (Course?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Course] {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return lessons }
        return lessons.filter { $0.title.localizedCaseInsensitiveContains(wanted) || ($0.subject ?? "").localizedCaseInsensitiveContains(wanted) }
    }

    var body: some View {
        NavigationStack {
            List {
                if selected != nil {
                    Button {
                        onPick(nil)
                        dismiss()
                    } label: {
                        Label(loc("ios.cal.noLesson"), systemImage: "xmark.circle")
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(MicaboColor.wrongInk)
                    }
                }
                ForEach(filtered) { course in
                    Button {
                        onPick(course)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            MicaboIconView(icon: course.icon, size: 36)
                            Text(course.title)
                                .font(MicaboFont.ui(16, weight: .bold))
                                .foregroundStyle(MicaboColor.ink)
                                .lineLimit(2)
                            Spacer()
                            if course.id == selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(MicaboColor.accent)
                            }
                        }
                    }
                }
                if filtered.isEmpty {
                    Text(loc("ios.cal.noLessonFound"))
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text(loc("ios.cal.searchLesson")))
            .navigationTitle(loc("ios.cal.chooseLesson"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("app.common.cancel", locale: .resolved())) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
