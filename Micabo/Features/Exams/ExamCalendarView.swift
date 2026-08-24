import SwiftUI

/// Le calendrier des examens : un mois, ses échéances, et de quoi les déplacer.
///
/// Un examen se **prend dans la liste et se pose sur un jour**. C'est le geste de
/// déplacement : le calendrier est la cible, la liste est la source. L'inverse, glisser
/// depuis une pastille de trois points de large, serait injouable au doigt, et un examen
/// déplacé par erreur emporte tout un planning de révision.
struct ExamCalendarView: View {
    /// N'importe quelle date du mois affiché.
    let month: Date
    let selectedDay: Date?
    /// Les examens par jour, les clés ramenées au début de journée.
    let examsByDay: [Date: [Exam]]
    var onSelect: (Date) -> Void
    var onStep: (Int) -> Void
    /// Rend vrai quand le dépôt a été accepté.
    var onDrop: (UUID, Date) -> Bool

    private let calendar = MicaboCalendar.shared
    private let now = Date()

    var body: some View {
        VStack(spacing: MicaboSpacing.sm) {
            monthHeader
            weekdayHeader
            grid
        }
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }

    // MARK: - En-tête

    private var monthHeader: some View {
        HStack(spacing: MicaboSpacing.xs) {
            Text(MicaboCalendar.monthLabel(month))
                .font(MicaboFont.hanken(17, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)

            Spacer(minLength: 0)

            stepButton(systemImage: "chevron.left", step: -1, title: "Mois précédent")
            stepButton(systemImage: "chevron.right", step: 1, title: "Mois suivant")
        }
    }

    private func stepButton(systemImage: String, step: Int, title: String) -> some View {
        Button {
            Haptics.selection()
            onStep(step)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(width: 32, height: 32)
                .background(MicaboColor.surfaceMuted, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel(title)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(MicaboCalendar.weekdayInitials.enumerated()), id: \.offset) { _, initial in
                Text(initial)
                    .font(MicaboFont.hanken(11, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Grille

    private var grid: some View {
        VStack(spacing: 4) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 4) {
                    ForEach(week, id: \.timeIntervalSince1970) { day in
                        cell(for: day)
                    }
                }
            }
        }
    }

    private func cell(for day: Date) -> some View {
        let exams = examsByDay[day] ?? []
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        let isOutside = !calendar.isDate(day, equalTo: month, toGranularity: .month)

        return Button {
            Haptics.selection()
            onSelect(day)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(MicaboFont.hanken(14, weight: isToday || isSelected ? .semibold : .regular))
                    .foregroundStyle(numberColor(isSelected: isSelected, isOutside: isOutside))
                    .monospacedDigit()

                // Trois points au maximum : au delà, la case devient illisible et le compte
                // se lit dans la liste, pas dans la grille.
                HStack(spacing: 2) {
                    ForEach(0..<min(exams.count, 3), id: \.self) { index in
                        Circle()
                            .fill(dotColor(for: exams[index], isSelected: isSelected))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(background(isSelected: isSelected, isToday: isToday))
            .contentShape(RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .dropDestination(for: ExamTransfer.self) { items, _ in
            guard let id = items.first?.id else { return false }
            return onDrop(id, day)
        }
        .accessibilityLabel(accessibilityLabel(for: day, exams: exams))
    }

    @ViewBuilder
    private func background(isSelected: Bool, isToday: Bool) -> some View {
        if isSelected {
            RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
                .fill(MicaboColor.accent)
        } else if isToday {
            RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
                .fill(MicaboColor.accentSoft)
        } else {
            Color.clear
        }
    }

    private func numberColor(isSelected: Bool, isOutside: Bool) -> Color {
        if isSelected { return MicaboColor.onInk }
        return isOutside ? MicaboColor.inkTertiary.opacity(0.5) : MicaboColor.ink
    }

    /// Ocre pour une échéance à venir, gris pour un examen passé : c'est le code de
    /// couleur des pastilles d'état de l'app, et un examen est une échéance.
    private func dotColor(for exam: Exam, isSelected: Bool) -> Color {
        if isSelected { return MicaboColor.onInk }
        return exam.isPast(from: now) ? MicaboColor.inkTertiary : MicaboColor.caution
    }

    private func accessibilityLabel(for day: Date, exams: [Exam]) -> String {
        let date = MicaboCalendar.dayLabel(day)
        guard !exams.isEmpty else { return date }
        return "\(date), \(exams.count) examen\(exams.count > 1 ? "s" : "")"
    }

    /// Les semaines affichées, débords des mois voisins compris pour que la grille soit
    /// pleine.
    private var weeks: [[Date]] {
        guard let monthRange = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthRange.start) else {
            return []
        }

        var days: [Date] = []
        var cursor = calendar.startOfDay(for: firstWeek.start)

        while days.count < 42 {
            days.append(cursor)
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            if cursor >= monthRange.end, days.count % 7 == 0 { break }
        }

        return stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }
    }
}
