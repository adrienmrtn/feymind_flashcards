import SwiftUI

/// **Le calendrier d'une épreuve : ce que chaque jour demande, d'ici le jour J.**
///
/// La page d'examen portait un bouton « passer un examen blanc » et la liste des blancs déjà
/// passés. Elle disait donc ce qui était derrière et ce qu'on pouvait faire maintenant, et rien
/// de ce qui vient — alors que c'est la seule question qu'on se pose en ouvrant une épreuve :
/// **qu'est-ce qui m'attend, et quand.**
///
/// Un mois tient dans un écran, et une grille de sept colonnes dit d'un coup d'œil ce qu'une
/// liste de rendez-vous demanderait de reconstruire : les jours chargés, les jours vides, et où
/// tombent les mesures.
///
/// ## Ce qu'une case porte
///
/// Le chiffre du jour, et sous lui le nombre de cartes que le plan y pose. Une case sans carte
/// reste vide plutôt que d'afficher un zéro : une grille pleine de zéros se lit moins bien
/// qu'une grille trouée, et le trou dit la même chose.
///
/// La teinte porte la mesure qui tombe ce jour-là — bleu pour un examen blanc, ambre pour un
/// test de parcours — parce qu'une pastille de plus dans une case de quarante points ne se voit
/// pas, alors qu'un fond se repère en diagonale.
struct ExamAgendaCalendar: View {
    let exam: Exam
    let events: [AgendaEvent]
    /// Cartes prévues, par décalage depuis aujourd'hui. C'est `ExamProjection.load`.
    let load: [Int]
    /// Appelé quand on touche un rendez-vous. La page ouvre la fiche de déplacement.
    var onPick: (AgendaEvent) -> Void

    var now: Date = Date()
    private let calendar = MicaboCalendar.shared

    private var today: Date { calendar.startOfDay(for: now) }
    private var examDay: Date { calendar.startOfDay(for: exam.date) }

    /// Les mois à dessiner : celui d'aujourd'hui jusqu'à celui de l'épreuve.
    ///
    /// Bornés à trois. Une échéance à six mois donnerait six grilles à faire défiler pour voir
    /// deux rendez-vous, et les rendez-vous se concentrent de toute façon sur les dernières
    /// semaines : au-delà, la grille montrerait surtout du vide.
    private var months: [Date] {
        guard let start = calendar.dateInterval(of: .month, for: today)?.start else { return [] }
        var result: [Date] = [start]

        while let last = result.last,
              result.count < 3,
              let next = calendar.date(byAdding: .month, value: 1, to: last),
              next <= examDay {
            result.append(next)
        }

        return result
    }

    /// Les rendez-vous d'un jour, indexés une fois pour toutes.
    ///
    /// La grille dessine une centaine de cases ; chercher dans la liste à chaque case ferait
    /// une centaine de parcours pour une poignée de rendez-vous.
    private var byDay: [Date: [AgendaEvent]] {
        Dictionary(grouping: events) { calendar.startOfDay(for: $0.date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            weekdayHeader

            ForEach(months, id: \.self) { month in
                monthGrid(month)
            }

            legend
        }
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }

    // MARK: - L'en-tête des jours

    /// Les initiales des sept jours, dans l'ordre de la semaine de l'utilisateur.
    ///
    /// `veryShortWeekdaySymbols` commence au dimanche quel que soit le réglage ; on le fait
    /// tourner de `firstWeekday`, sinon la colonne du lundi porterait un D.
    private var weekdayHeader: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        let rotated = Array(symbols[(calendar.firstWeekday - 1)...] + symbols[..<(calendar.firstWeekday - 1)])

        return HStack(spacing: 0) {
            ForEach(Array(rotated.enumerated()), id: \.offset) { _, symbol in
                Text(symbol.uppercased())
                    .font(MicaboFont.ui(10, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Un mois

    private func monthGrid(_ month: Date) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.xs) {
            if months.count > 1 {
                Text(monthLabel(month))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                // Les cases vides du début de mois : la grille doit tomber sur la bonne colonne.
                ForEach(0 ..< leadingBlanks(month), id: \.self) { index in
                    Color.clear.frame(height: 44).id("blank-\(month.timeIntervalSince1970)-\(index)")
                }

                ForEach(days(of: month), id: \.self) { day in
                    cell(day)
                }
            }
        }
    }

    private func monthLabel(_ month: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: UiLocale.resolved().rawValue)
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: month).capitalized
    }

    private func leadingBlanks(_ month: Date) -> Int {
        let weekday = calendar.component(.weekday, from: month)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func days(of month: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    // MARK: - Une case

    private func cell(_ day: Date) -> some View {
        let start = calendar.startOfDay(for: day)
        let event = pick(byDay[start] ?? [])
        let cards = cardCount(on: start)
        let isExamDay = start == examDay
        let isToday = start == today

        return Button {
            if let event { onPick(event) }
        } label: {
            VStack(spacing: 1) {
                Text("\(calendar.component(.day, from: day))")
                    .font(MicaboFont.ui(13, weight: isExamDay || event != nil ? .semibold : .regular))
                    .foregroundStyle(ink(event: event, isExamDay: isExamDay, day: start))
                    // Un rendez-vous manqué se barre : c'est le jour qui est passé, pas le
                    // travail qui a disparu.
                    .strikethrough(event?.status == .missed, color: MicaboColor.inkTertiary)

                // Une case sans carte reste vide : une grille pleine de zéros se lit moins
                // bien qu'une grille trouée, et le trou dit la même chose.
                if cards > 0 {
                    Text("\(cards)")
                        .font(MicaboFont.ui(9, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(background(event: event, isExamDay: isExamDay), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(MicaboColor.ink.opacity(0.45), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(event == nil)
        .accessibilityLabel(label(day: start, event: event, cards: cards, isExamDay: isExamDay))
    }

    /// Le rendez-vous qui donne sa couleur à la case quand il y en a plusieurs.
    ///
    /// Le blanc l'emporte : c'est le rendez-vous qui compte, et l'agenda l'écarte déjà des
    /// parcours, donc ce cas ne survient que sur un déplacement fait à la main.
    private func pick(_ events: [AgendaEvent]) -> AgendaEvent? {
        events.first { $0.kind == .mock } ?? events.first
    }

    private func cardCount(on day: Date) -> Int {
        let offset = calendar.dateComponents([.day], from: today, to: day).day ?? 0
        guard offset >= 0, load.indices.contains(offset) else { return 0 }
        return load[offset]
    }

    private func background(event: AgendaEvent?, isExamDay: Bool) -> Color {
        if isExamDay { return MicaboColor.ink.opacity(0.08) }
        guard let event else { return .clear }
        switch event.status {
        case .missed: return MicaboColor.surfaceMuted
        case .done: return MicaboColor.positiveSoft
        case .upcoming: return event.kind == .mock ? MicaboColor.accentSoft : MicaboColor.cautionSoft
        }
    }

    private func ink(event: AgendaEvent?, isExamDay: Bool, day: Date) -> Color {
        if isExamDay { return MicaboColor.ink }
        guard let event else {
            return day < today ? MicaboColor.inkTertiary : MicaboColor.inkSecondary
        }
        switch event.status {
        case .missed: return MicaboColor.inkTertiary
        case .done: return MicaboColor.positive
        case .upcoming: return event.kind == .mock ? MicaboColor.accent : MicaboColor.caution
        }
    }

    private func label(day: Date, event: AgendaEvent?, cards: Int, isExamDay: Bool) -> String {
        var parts = [day.formatted(date: .long, time: .omitted)]
        if isExamDay { parts.append(L10n.t("app.agenda.examDay")) }
        if cards > 0 { parts.append(L10n.t("app.agenda.cards", ["count": "\(cards)"])) }
        if let event { parts.append(L10n.t("app.agenda.kind.\(event.kind.rawValue)")) }
        return parts.joined(separator: ", ")
    }

    // MARK: - La légende

    /// Trois pastilles, et elles sont nécessaires.
    ///
    /// Une couleur ne dit rien d'elle-même la première fois qu'on la voit, et celle-ci porte la
    /// différence entre une mesure de cinq minutes et une de vingt-cinq.
    private var legend: some View {
        HStack(spacing: MicaboSpacing.sm) {
            legendItem(MicaboColor.accentSoft, MicaboColor.accent, L10n.t("app.mock.blockTitle"))
            legendItem(MicaboColor.cautionSoft, MicaboColor.caution, L10n.t("app.parcours.blockTitle"))
            Spacer(minLength: 0)
        }
    }

    private func legendItem(_ background: Color, _ tint: Color, _ text: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(background)
                .frame(width: 12, height: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                }
            Text(text)
                .font(MicaboFont.ui(11, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - La fiche d'un rendez-vous

/// **Ce qu'est ce rendez-vous, et quand on le veut.**
///
/// Elle ne propose pas de lancer le test, et c'est délibéré : la page d'une épreuve dit ce qui
/// est prévu, pas où l'on travaille. Le travail se lance depuis « Au programme », le jour venu,
/// avec le reste de la journée — sinon deux écrans proposent la même chose et l'étudiant se
/// demande lequel est le bon.
struct AgendaEventSheet: View {
    let event: AgendaEvent
    let examDay: Date
    /// Le jour qu'aurait donné la dérivation. `nil` quand on n'a pas déplacé ce rendez-vous.
    var plannedDate: Date?
    /// Rend la date choisie, ou `nil` pour remettre celle du plan.
    var onMove: (Date?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var chosen: Date

    private let calendar = MicaboCalendar.shared

    init(
        event: AgendaEvent,
        examDay: Date,
        plannedDate: Date? = nil,
        onMove: @escaping (Date?) -> Void
    ) {
        self.event = event
        self.examDay = examDay
        self.plannedDate = plannedDate
        self.onMove = onMove
        _chosen = State(initialValue: event.date)
    }

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, vars, locale: .resolved())
    }

    private var title: String {
        t(event.kind == .mock ? "app.mock.blockTitle" : "app.parcours.blockTitle")
    }

    /// Jusqu'à la veille, et pas au-delà.
    ///
    /// Le jour de l'épreuve ne sert plus à mesurer, et un rendez-vous posé après elle ne veut
    /// rien dire. Vers l'arrière, aujourd'hui : on ne replanifie pas le passé.
    private var range: ClosedRange<Date> {
        let first = calendar.startOfDay(for: Date())
        let last = calendar.date(byAdding: .day, value: -1, to: examDay) ?? examDay
        return first <= last ? first...last : first...first
    }

    private var isMoved: Bool { event.moved }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    summary

                    VStack(alignment: .leading, spacing: MicaboSpacing.xs) {
                        MicaboSectionCaption(text: t("app.agenda.moveTitle"))

                        DatePicker(
                            t("app.agenda.moveTitle"),
                            selection: $chosen,
                            in: range,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(MicaboColor.accent)
                        .micaboGroup()
                    }

                    VStack(spacing: MicaboSpacing.xs) {
                        Button {
                            onMove(calendar.startOfDay(for: chosen))
                            dismiss()
                        } label: {
                            Text(t("app.agenda.move"))
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle())
                        .disabled(calendar.startOfDay(for: chosen) == calendar.startOfDay(for: event.date))

                        // Ne s'affiche que si on a déplacé : proposer de « remettre » un
                        // rendez-vous qui n'a jamais bougé ne veut rien dire.
                        if isMoved {
                            Button {
                                onMove(nil)
                                dismiss()
                            } label: {
                                Text(t("app.agenda.reset"))
                                    .font(MicaboFont.ui(14, weight: .medium))
                                    .foregroundStyle(MicaboColor.inkSecondary)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, MicaboSpacing.xxs)
                        }
                    }
                }
                .padding(MicaboSpacing.screen)
            }
            .micaboScreenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("app.common.cancel")) { dismiss() }
                }
            }
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.xs) {
            Text(t(
                event.kind == .mock ? "app.chart.load.mockLine" : "app.parcours.line",
                [
                    "exam": event.examName,
                    "questions": "\(event.questionCount)",
                    "minutes": "\(event.minutes)",
                ]
            ))
            .font(MicaboFont.caption)
            .foregroundStyle(MicaboColor.inkSecondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: MicaboSpacing.xs) {
                MicaboBadge(text: statusLabel, tone: statusTone)

                if isMoved, let plannedDate {
                    // D'où il vient : sans ça, « déplacé » ne dit pas de combien.
                    MicaboBadge(
                        text: t("app.agenda.movedFrom", ["date": MicaboCalendar.shortDayLabel(plannedDate)]),
                        tone: .neutral
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }

    private var statusLabel: String {
        t("app.agenda.status.\(event.status.rawValue)")
    }

    private var statusTone: MicaboBadgeTone {
        switch event.status {
        case .done: .positive
        case .missed: .neutral
        case .upcoming: event.kind == .mock ? .neutral : .warm
        }
    }
}
