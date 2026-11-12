import SwiftUI

/// Un jour de la semaine à flammes.
struct V3WeekDay: Equatable {
    /// L'initiale du jour, dans la langue de l'élève (« L », « M »…).
    let letter: String
    /// Le quantième.
    let number: Int
    /// Le jour a été tenu : une flamme jaune remplace sa date.
    var isDone: Bool
    /// Aujourd'hui : un rond bleu plein, avec sa date.
    var isToday: Bool
    /// Un examen ou une tâche ce jour-là : une pastille rose dessous.
    var hasEvent: Bool

    init(letter: String, number: Int, isDone: Bool = false, isToday: Bool = false, hasEvent: Bool = false) {
        self.letter = letter
        self.number = number
        self.isDone = isDone
        self.isToday = isToday
        self.hasEvent = hasEvent
    }
}

/// **La semaine à flammes** — l'une des signatures de Micabo : sept ronds, du premier au dernier
/// jour de la semaine. Une **flamme jaune** sur les jours tenus, **aujourd'hui en rond bleu
/// plein** avec sa date, les jours à venir en gris, et une **pastille rose** sous les jours qui
/// ont un examen ou une tâche.
///
/// Elle prend toute la largeur qu'on lui donne et répartit ses jours. En arabe, la semaine se
/// lit de droite à gauche. Sa géométrie est fixe : sept ronds de 34 pt tiennent sur 375 pt, et
/// ne grossissent pas avec « Taille du texte » — VoiceOver lit chaque jour en toutes lettres.
struct V3WeekStrip: View {
    private let days: [V3WeekDay]

    init(days: [V3WeekDay]) {
        self.days = days
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                V3WeekDayCell(day: day)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct V3WeekDayCell: View {
    let day: V3WeekDay

    private var fill: Color {
        if day.isToday { return V3Color.accent }
        return day.isDone ? V3Color.yellowWash : V3Color.soft
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(day.letter)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(day.isToday ? V3Color.ink : V3Color.ink3)
            ZStack {
                Circle().fill(fill)
                if day.isDone, !day.isToday {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(V3Color.yellow)
                } else {
                    Text("\(day.number)")
                        .font(.system(size: 14, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(day.isToday ? V3Color.onAccent : V3Color.ink2)
                }
            }
            .frame(width: 34, height: 34)
            .padding(.top, 5)
            Circle()
                .fill(day.hasEvent ? V3Color.pink : Color.clear)
                .frame(width: 5, height: 5)
                .padding(.top, 4)
        }
        .frame(minWidth: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(spoken))
    }

    /// Le jour, dit en toutes lettres : « L 9, jour tenu », « J 12, aujourd'hui, un événement ».
    private var spoken: String {
        var parts = ["\(day.letter) \(day.number)"]
        if day.isToday { parts.append(L10n.t("ios.look10.week.today", locale: .resolved())) }
        if day.isDone { parts.append(L10n.t("ios.look10.week.done", locale: .resolved())) }
        if day.hasEvent { parts.append(L10n.t("ios.look10.week.event", locale: .resolved())) }
        return parts.joined(separator: ", ")
    }
}
