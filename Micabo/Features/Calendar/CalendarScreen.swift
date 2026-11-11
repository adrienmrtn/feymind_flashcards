import SwiftUI

/// Une phrase de l'onglet, dans la langue de l'app.
func loc(_ key: String, _ vars: [String: String] = [:]) -> String {
    L10n.t(key, locale: .resolved(), vars: vars)
}

// MARK: - Le titre de section

/// Le titre d'un bloc de page : le même partout dans Calendrier et Concentration.
struct StudySectionTitle<Trailing: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MicaboFont.ui(19, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let detail {
                    Text(detail)
                        .font(MicaboFont.ui(13.5, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension StudySectionTitle where Trailing == EmptyView {
    init(title: String, detail: String? = nil) {
        self.title = title
        self.detail = detail
        self.trailing = EmptyView()
    }
}

// MARK: - L'en-tête

/// Le mois (qui ouvre la grille), « Aujourd'hui » quand on s'en est éloigné, et le « + ».
struct CalendarHeader<Accessory: View>: View {
    let month: Date
    let showsToday: Bool
    let onMonth: () -> Void
    let onToday: () -> Void
    @ViewBuilder var addMenu: Accessory

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onMonth) {
                HStack(spacing: 6) {
                    Text(MicaboCalendar.monthLabel(month))
                        .font(MicaboFont.ui(26, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MicaboColor.accentInk)
                        .padding(5)
                        .background(MicaboColor.accentSoft, in: Circle())
                }
            }
            .buttonStyle(HomePressStyle(scale: 0.97, feedback: .selection))
            .accessibilityLabel(Text(MicaboCalendar.monthLabel(month)))
            .accessibilityHint(Text(loc("ios.cal.monthHint")))

            Spacer(minLength: 4)

            if showsToday {
                Button(action: onToday) {
                    Text(loc("ios.cal.today"))
                        .font(MicaboFont.ui(14, weight: .heavy))
                        .foregroundStyle(MicaboColor.accentInk)
                        .lineLimit(1)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 36)
                        .background(MicaboColor.accentSoft, in: Capsule())
                }
                .buttonStyle(HomePressStyle(scale: 0.94, feedback: .selection))
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            addMenu
        }
    }
}

/// Le « + » rond de l'en-tête, dessiné une fois pour le menu et pour les rendus.
struct CalendarAddLabel: View {
    var body: some View {
        Image(systemName: "plus")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(Color.white)
            .frame(width: 42, height: 42)
            .background(MicaboStage.buttonFill, in: Circle())
            .shadow(color: MicaboBrand.blue.opacity(0.28), radius: 8, y: 4)
            .accessibilityLabel(Text(loc("ios.cal.add")))
    }
}

// MARK: - La semaine

/// **Une semaine**, du lundi au dimanche : le nom court du jour, son numéro, et jusqu'à trois
/// points aux couleurs de ce qui l'attend. Le jour choisi est plein, aujourd'hui est cerclé.
struct WeekStrip: View {
    let days: [Date]
    let selected: Date
    let dots: (Date) -> [Int]
    let onSelect: (Date) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days, id: \.self) { day in
                WeekDayCell(
                    day: day,
                    isSelected: MicaboCalendar.shared.isDate(day, inSameDayAs: selected),
                    isToday: MicaboCalendar.shared.isDateInToday(day),
                    dots: dots(day)
                ) {
                    onSelect(day)
                }
            }
        }
    }
}

private struct WeekDayCell: View {
    let day: Date
    let isSelected: Bool
    let isToday: Bool
    let dots: [Int]
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                Text(MicaboCalendar.shortWeekday(day))
                    .font(MicaboFont.ui(12, weight: .heavy))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : MicaboColor.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(MicaboCalendar.dayNumber(day))
                    .font(MicaboFont.number(18))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? MicaboColor.accentInk : MicaboColor.ink))
                    .monospacedDigit()
                HStack(spacing: 3) {
                    ForEach(dots, id: \.self) { tint in
                        Circle()
                            .fill(isSelected ? Color.white : CalendarTint.at(tint).color)
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(MicaboStage.fill) : AnyShapeStyle(Color.clear))
            }
            .overlay {
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(MicaboColor.accent.opacity(0.55), lineWidth: 1.5)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(HomePressStyle(scale: 0.93, feedback: .selection))
        .accessibilityLabel(Text(MicaboCalendar.dayLabel(day)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// **Les semaines, qu'on fait glisser.** Un `TabView` en pages, une page par semaine autour
/// d'aujourd'hui ; les rendus, qui ne dessinent pas de `TabView`, posent la semaine seule.
struct WeekPager: View {
    @Binding var weekOffset: Int
    let selected: Date
    let dots: (Date) -> [Int]
    let onSelect: (Date) -> Void

    @Environment(\.homeStill) private var still
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 76

    static let range = -104...104

    var body: some View {
        if still {
            strip(for: weekOffset)
        } else {
            TabView(selection: $weekOffset) {
                ForEach(Self.range, id: \.self) { offset in
                    strip(for: offset)
                        .padding(.horizontal, 1)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: height)
        }
    }

    private func strip(for offset: Int) -> some View {
        WeekStrip(days: Self.days(offset: offset), selected: selected, dots: dots, onSelect: onSelect)
    }

    static func days(offset: Int, now: Date = Date()) -> [Date] {
        let calendar = MicaboCalendar.shared
        let base = calendar.date(byAdding: .weekOfYear, value: offset, to: now) ?? now
        return MicaboCalendar.week(of: base, calendar: calendar)
    }

    /// Le rang de la semaine d'un jour, compté depuis celle d'aujourd'hui.
    static func offset(of day: Date, now: Date = Date()) -> Int {
        let calendar = MicaboCalendar.shared
        guard let thisMonday = MicaboCalendar.week(of: now, calendar: calendar).first,
              let monday = MicaboCalendar.week(of: day, calendar: calendar).first else { return 0 }
        let days = calendar.dateComponents([.day], from: thisMonday, to: monday).day ?? 0
        return max(range.lowerBound, min(range.upperBound, Int((Double(days) / 7).rounded())))
    }
}

// MARK: - Le prochain examen

/// Ce que la carte du prochain examen affiche, tout calculé.
struct NextExamSummary: Equatable {
    var examID: UUID
    var name: String
    var date: Date
    var daysLeft: Int
    var lessonTitles: [String]
    /// La maîtrise des cartes de l'examen, sur cent ; `nil` tant qu'on ne la connaît pas.
    var readiness: Int?
    var plannedCount: Int
    var nextSession: String?
    var hasLessons: Bool
}

/// **Le prochain examen, épinglé en haut du calendrier** : le compte à rebours, la date, les
/// leçons, la préparation, et les trois gestes qui comptent — réviser, passer un examen blanc,
/// laisser Mika planifier les révisions.
struct NextExamCard: View {
    let summary: NextExamSummary
    let onRevise: () -> Void
    let onMock: () -> Void
    let onPlan: () -> Void
    let onPlanMenu: () -> Void
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            top
            if !summary.lessonTitles.isEmpty {
                lessons
            }
            if let readiness = summary.readiness {
                readinessBar(readiness)
            }
            actions
            planRow
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Une carte claire, comme le plan du jour de Home : le bleu reste aux pastilles et au
        // bouton « Réviser ».
        .homeCard()
    }

    private var top: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onEdit) {
                titleBlock
            }
            .buttonStyle(HomePressStyle(scale: 0.98))
            .accessibilityHint(Text(loc("ios.cal.editExam")))
            Spacer(minLength: 4)
            HomeCountdownBadge(daysLeft: summary.daysLeft, side: 72)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(loc("ios.cal.nextExam"))
                .font(MicaboFont.ui(12, weight: .black))
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.accentInk)
            Text(summary.name)
                .font(MicaboFont.ui(23, weight: .black))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(MicaboCalendar.dayLabel(summary.date).capitalizedFirstLetter)
                .font(MicaboFont.ui(14.5, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var lessons: some View {
        MicaboFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(summary.lessonTitles.prefix(3).enumerated()), id: \.offset) { _, title in
                chip(title)
            }
            if summary.lessonTitles.count > 3 {
                chip("+\(summary.lessonTitles.count - 3)")
            }
        }
    }

    private func chip(_ title: String) -> some View {
        Text(title)
            .font(MicaboFont.ui(13, weight: .heavy))
            .foregroundStyle(MicaboColor.accentInk)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MicaboColor.accentWash, in: Capsule())
    }

    private func readinessBar(_ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(loc("ios.cal.readiness"))
                    .font(MicaboFont.ui(13, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkSecondary)
                Spacer()
                Text(L10n.percent(value, locale: .resolved()))
                    .font(MicaboFont.ui(13, weight: .black))
                    .foregroundStyle(MicaboColor.accentInk)
                    .monospacedDigit()
            }
            HomeBar(percent: value, height: 7)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onRevise) {
                Label(loc("ios.cal.revise"), systemImage: "brain.head.profile")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .buttonStyle(MicaboBrandButtonStyle(minHeight: 46, fontSize: 15.5))
            .disabled(!summary.hasLessons)

            Button(action: onMock) {
                Label(loc("ios.cal.mock"), systemImage: "stopwatch")
                    .font(MicaboFont.ui(15.5, weight: .black))
                    .foregroundStyle(MicaboColor.accentInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboStage.buttonRadius, style: .continuous))
            }
            .buttonStyle(HomePressStyle(scale: 0.96, feedback: .medium))
            .disabled(!summary.hasLessons)
            .opacity(summary.hasLessons ? 1 : 0.6)
        }
    }

    @ViewBuilder
    private var planRow: some View {
        if summary.plannedCount > 0 {
            Button(action: onPlanMenu) {
                planLabel(
                    title: loc("ios.cal.planned", ["count": "\(summary.plannedCount)"]),
                    detail: summary.nextSession,
                    trailing: "ellipsis"
                )
            }
            .buttonStyle(HomePressStyle(scale: 0.98, feedback: .light))
        } else {
            Button(action: onPlan) {
                planLabel(title: loc("ios.cal.plan"), detail: loc("ios.cal.planSub"), trailing: "chevron.forward")
            }
            .buttonStyle(HomePressStyle(scale: 0.98, feedback: .medium))
        }
    }

    private func planLabel(title: String, detail: String?, trailing: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MicaboBrand.pencil)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(MicaboFont.ui(14.5, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 4)
            Image(systemName: trailing)
                .font(.system(size: trailing == "ellipsis" ? 15 : 13, weight: .heavy))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - L'agenda du jour

/// **L'agenda d'un jour** : ce qui dure toute la journée en haut (l'examen, l'examen blanc
/// conseillé, les tâches à rendre), puis les heures, dans l'ordre.
struct DayAgendaSection: View {
    let day: Date
    let items: [AgendaItem]
    let onTap: (AgendaItem) -> Void
    let onStart: (AgendaItem) -> Void
    let onToggleTask: (AgendaItem) -> Void
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: title, detail: detail)
            if items.isEmpty {
                DayEmptyState(onAdd: onAdd)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        AgendaRow(item: item, onTap: { onTap(item) }, onStart: { onStart(item) }, onToggle: { onToggleTask(item) })
                    }
                }
            }
        }
    }

    private var title: String {
        let calendar = MicaboCalendar.shared
        if calendar.isDateInToday(day) { return loc("ios.cal.today") }
        if calendar.isDateInTomorrow(day) { return loc("ios.cal.tomorrow") }
        if calendar.isDateInYesterday(day) { return loc("ios.cal.yesterday") }
        return MicaboCalendar.dayLabel(day).capitalizedFirstLetter
    }

    private var detail: String? {
        let calendar = MicaboCalendar.shared
        guard calendar.isDateInToday(day) || calendar.isDateInTomorrow(day) || calendar.isDateInYesterday(day) else { return nil }
        return MicaboCalendar.dayLabel(day).capitalizedFirstLetter
    }
}

/// Un jour vide : le calendrier, une phrase, et de quoi le remplir. Pas de Mika dans l'agenda
/// (la règle de mise en scène, `MikaMascot.swift`) : il est déjà sur la carte d'examen.
struct DayEmptyState: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            MicaboIconView(icon: .exam, size: 30)
                .frame(width: 52, height: 52)
                .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(loc("ios.cal.emptyDay"))
                    .font(MicaboFont.ui(16, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAdd) {
                    Label(loc("ios.cal.addEvent"), systemImage: "plus")
                        .font(MicaboFont.ui(14, weight: .heavy))
                        .foregroundStyle(MicaboColor.accentInk)
                }
                .buttonStyle(HomePressStyle(scale: 0.95))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .homeCard(radius: MicaboStage.tileRadius)
    }
}

/// **Une ligne de l'agenda** : l'heure à gauche, la barre de la couleur du calendrier, le
/// titre et ce qui le précise, et le geste qui va avec à droite.
struct AgendaRow: View {
    let item: AgendaItem
    let onTap: () -> Void
    let onStart: () -> Void
    let onToggle: () -> Void

    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = 50

    private var tint: CalendarTint { CalendarTint.at(item.tintIndex) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            timeColumn
            HStack(spacing: 10) {
                Capsule()
                    .fill(tint.color)
                    .frame(width: 4)
                    .padding(.vertical, 2)
                // Le geste principal et celui de droite sont deux boutons côte à côte : un
                // bouton dans un bouton ne reçoit pas toujours son appui.
                Button(action: item.kind == .task ? onToggle : onTap) {
                    HStack(spacing: 10) {
                        leading
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(MicaboFont.ui(15.5, weight: .black))
                                .foregroundStyle(item.isDone && item.kind != .focus ? MicaboColor.inkSecondary : MicaboColor.ink)
                                .strikethrough(item.isDone && item.kind == .task, color: MicaboColor.inkTertiary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            if let subtitle {
                                Text(subtitle)
                                    .font(MicaboFont.ui(13, weight: .bold))
                                    .foregroundStyle(MicaboColor.inkSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        // Le texte passe avant l'espace : mesuré sur une largeur et posé sur
                        // une autre, il débordait de sa ligne.
                        .layoutPriority(1)
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(HomePressStyle(scale: 0.98, feedback: item.kind == .task ? .selection : .light))
                .layoutPriority(1)
                trailing
                    .fixedSize()
            }
            .padding(.vertical, 10)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(tint.wash, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(item.isDone && item.kind != .focus ? 0.75 : 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var timeColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let start = item.startMinute {
                Text(CalendarTime.label(minute: start))
                    .font(MicaboFont.ui(13, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                if let end = item.endMinute, end > start {
                    Text(CalendarTime.label(minute: end))
                        .font(MicaboFont.ui(12, weight: .bold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            } else {
                Text(loc("ios.cal.allDay"))
                    .font(MicaboFont.ui(11.5, weight: .black))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(width: timeWidth, alignment: .trailing)
    }

    @ViewBuilder
    private var leading: some View {
        switch item.kind {
        case .task:
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(item.isDone ? MicaboColor.correctInk : tint.color)
                .contentTransition(.symbolEffect(.replace))
        case .exam:
            Text("🎓").font(.system(size: 20))
        case .milestone:
            Image(systemName: item.milestone == .mock ? "stopwatch.fill" : "flag.checkered")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint.color)
                .frame(width: 24)
        case .revision:
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "sparkles")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(item.isDone ? MicaboColor.correctInk : tint.color)
                .frame(width: 24)
        case .focus:
            Image(systemName: "timer")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(tint.color)
                .frame(width: 24)
        case .lesson, .custom:
            if let emoji = item.emoji, !emoji.isEmpty {
                Text(emoji).font(.system(size: 19))
            }
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch item.kind {
        case .revision where !item.isDone:
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(MicaboStage.buttonFill, in: Circle())
            }
            .buttonStyle(HomePressStyle(scale: 0.9, feedback: .medium))
            .accessibilityLabel(Text(loc("ios.cal.startSession")))
        case .milestone where !item.isDone:
            Button(action: onTap) {
                Image(systemName: "play.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 34, height: 34)
                    .background(tint.color, in: Circle())
            }
            .buttonStyle(HomePressStyle(scale: 0.9, feedback: .medium))
            .accessibilityLabel(Text(loc("ios.cal.go")))
        case .focus:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MicaboColor.correctInk)
        default:
            EmptyView()
        }
    }

    private var title: String {
        switch item.kind {
        case .exam: loc("ios.cal.examDay", ["name": item.title])
        case .milestone: loc(item.milestone == .mock ? "ios.cal.milestoneMock" : "ios.cal.milestoneCheck")
        case .revision: loc("ios.cal.revisionTitle", ["title": item.title])
        case .focus: loc("ios.cal.focusDone", ["minutes": CalendarTime.duration(minutes: item.minutes)])
        default: item.title
        }
    }

    private var subtitle: String? {
        switch item.kind {
        case .exam: return loc("ios.cal.examDaySub")
        case .milestone:
            return "\(item.title) · \(CalendarTime.duration(minutes: item.minutes))"
        case .task:
            return item.isDone ? loc("ios.cal.taskDone") : loc("ios.cal.taskDue")
        case .revision:
            guard let start = item.startMinute, let end = item.endMinute else { return nil }
            return CalendarTime.duration(minutes: end - start)
        case .focus:
            return nil
        case .lesson, .custom:
            let parts = [item.room, item.calendarName ?? ""].filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " · ")
        }
    }
}

// MARK: - Les examens

/// La ligne qui mène à « Mes examens » : le nombre d'examens à venir et les examens blancs.
struct ExamsSummaryRow: View {
    let upcoming: Int
    let onOpen: () -> Void
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(CalendarTint.at(StudyAgenda.examTint).wash)
                        Text("🎓").font(.system(size: 22))
                    }
                    .frame(width: 46, height: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("ios.cal.myExams"))
                            .font(MicaboFont.ui(16, weight: .black))
                            .foregroundStyle(MicaboColor.ink)
                        Text(upcoming == 0 ? loc("ios.cal.examsNone") : loc("ios.cal.examsCount", ["count": "\(upcoming)"]))
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.forward")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HomePressStyle(scale: 0.98))

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(MicaboColor.accentInk)
                    .frame(width: 38, height: 38)
                    .background(MicaboColor.accentSoft, in: Circle())
            }
            .buttonStyle(HomePressStyle(scale: 0.9))
            .accessibilityLabel(Text(loc("ios.cal.newExam")))
        }
        .padding(14)
        .homeCard(radius: MicaboStage.tileRadius)
    }
}

/// Pas encore d'examen : Mika invite à déclarer le prochain.
struct NoExamCard: View {
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text(loc("ios.cal.noExamTitle"))
                    .font(MicaboFont.ui(18, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(loc("ios.cal.noExamBody"))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onAdd) {
                    Label(loc("ios.cal.newExam"), systemImage: "calendar.badge.plus")
                        .font(MicaboFont.ui(15, weight: .black))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(MicaboStage.buttonFill, in: Capsule())
                }
                .buttonStyle(HomePressStyle(scale: 0.95, feedback: .medium))
                .padding(.top, 4)
            }
            .padding(.vertical, 18)
            .padding(.leading, 18)
            Spacer(minLength: 0)
            // Mika, en demi, dépasse du bas de la carte (la règle de mise en scène).
            MikaPeek(mood: .wave, width: MikaPeek.card)
                .padding(.trailing, 12)
        }
        .homeCardClipped()
    }
}

// MARK: - Les calendriers

/// Une ligne de « Mes calendriers » : l'emoji, le nom, la couleur, l'œil qui le montre ou le
/// cache.
struct CalendarListRow: View {
    let calendar: AgendaCalendarInfo
    let eventCount: Int
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous).fill(CalendarTint.at(calendar.tintIndex).wash)
                        Text(calendar.emoji).font(.system(size: 21))
                    }
                    .frame(width: 44, height: 44)
                    .overlay(alignment: .bottomTrailing) {
                        Circle()
                            .fill(CalendarTint.at(calendar.tintIndex).color)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(MicaboColor.surface, lineWidth: 2))
                            .offset(x: 3, y: 3)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(calendar.name)
                            .font(MicaboFont.ui(16, weight: .black))
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(1)
                        Text(loc("ios.cal.eventCount", ["count": "\(eventCount)"]))
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(HomePressStyle(scale: 0.98))

            Button(action: onToggle) {
                Image(systemName: calendar.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(calendar.isVisible ? MicaboColor.accentInk : MicaboColor.inkTertiary)
                    .frame(width: 38, height: 38)
                    .background(calendar.isVisible ? MicaboColor.accentSoft : MicaboColor.surfaceMuted, in: Circle())
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(HomePressStyle(scale: 0.9, feedback: .selection))
            .accessibilityLabel(Text(loc(calendar.isVisible ? "ios.cal.hide" : "ios.cal.show")))
        }
        .opacity(calendar.isVisible ? 1 : 0.6)
    }
}

/// **« Scanne ton emploi du temps »** : une carte claire, l'appareil photo, et le geste qui
/// remplit le calendrier « Cours » d'un coup.
struct TimetableScanPromo: View {
    let onScan: () -> Void

    var body: some View {
        Button(action: onScan) {
            HStack(alignment: .bottom, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("ios.cal.scanPromoTitle"))
                        .font(MicaboFont.ui(18, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(loc("ios.cal.scanPromoBody"))
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                        Text(loc("ios.cal.scanCta"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .font(MicaboFont.ui(14.5, weight: .black))
                    .foregroundStyle(MicaboColor.accentInk)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(MicaboColor.accentSoft, in: Capsule())
                    .padding(.top, 4)
                }
                .multilineTextAlignment(.leading)
                .padding(.vertical, 18)
                .padding(.leading, 18)
                Spacer(minLength: 0)
                // L'appareil photo, pas Mika : il est déjà sur la carte d'examen, juste au-dessus
                // (jamais deux fois sur un écran).
                MicaboIconView(icon: .photo, size: 58)
                    .padding(.trailing, 18)
                    .padding(.bottom, 20)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .homeCardClipped()
        }
        .buttonStyle(HomePressStyle(scale: 0.98, feedback: .medium))
    }
}
