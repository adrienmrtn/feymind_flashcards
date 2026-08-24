import SwiftUI

/// **Ce que la replanification va coûter, annoncé avant de l'accepter.**
///
/// Un mode qui réorganise tout un planning de révision ne se lance pas sur un bouton
/// « Activer ». Quatre chiffres suffisent à décider : combien de cartes sont en jeu, combien
/// de jours il reste, ce que ça fait par jour, et à quoi ressemblera le pire jour. Le
/// dernier est le plus utile : c'est celui qui fait reculer d'une intensité.
struct ExamProjectionView: View {
    let plan: ExamPlan

    private var projection: ExamProjection { plan.projection }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            MicaboSectionCaption(text: "Ce que ça donne")

            VStack(spacing: 0) {
                figures
                MicaboHairline(inset: MicaboSpacing.md)
                chart
            }
            .micaboGroup()

            MicaboSectionFootnote(text: footnote)
        }
    }

    private var figures: some View {
        VStack(spacing: 0) {
            figure(
                label: "Cartes concernées",
                value: MicaboCopy.cards(projection.cardCount)
            )
            MicaboHairline(inset: MicaboSpacing.md)
            figure(
                label: "Jours restants",
                value: daysLabel
            )
            MicaboHairline(inset: MicaboSpacing.md)
            figure(
                label: "Charge quotidienne moyenne",
                value: "≈ \(MicaboCopy.cards(projection.averageDailyLoad))"
            )
            MicaboHairline(inset: MicaboSpacing.md)
            figure(
                label: "Jour le plus chargé",
                value: busiestLabel,
                tone: .warm
            )
        }
    }

    private func figure(label: String, value: String, tone: MicaboBadgeTone = .neutral) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.xs) {
            Text(label)
                .font(MicaboFont.hanken(14, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: MicaboSpacing.xs)

            Text(value)
                .font(MicaboFont.hanken(14, weight: .semibold))
                .foregroundStyle(tone == .warm ? MicaboColor.caution : MicaboColor.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, MicaboSpacing.md)
    }

    private var daysLabel: String {
        switch projection.daysRemaining {
        case ..<0: "examen passé"
        case 0: "aujourd'hui"
        case 1: "demain"
        default: "\(projection.daysRemaining) jours"
        }
    }

    private var busiestLabel: String {
        guard let busiest = projection.busiest else { return "aucun" }
        let date = plan.date(atOffset: busiest.offset)
        return "\(MicaboCalendar.shortDayLabel(date)), \(busiest.count)"
    }

    /// L'histogramme dit en un coup d'œil ce que quatre chiffres ne disent pas : si la
    /// charge est plate, ou si elle s'écrase sur les derniers jours.
    @ViewBuilder
    private var chart: some View {
        if projection.load.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                ExamLoadChart(plan: plan)

                HStack {
                    Text("aujourd'hui")
                    Spacer(minLength: MicaboSpacing.xs)
                    Text("veille de l'examen")
                }
                .font(MicaboFont.hanken(10, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(MicaboSpacing.md)
        }
    }

    private var footnote: String {
        guard projection.daysRemaining > 1 else {
            return "L'examen est trop proche pour étaler les révisions : toutes les cartes passeront aujourd'hui."
        }
        return "Chaque carte repasse plusieurs fois d'ici l'examen, le dernier passage dans les trois derniers jours. Aucune carte concernée ne sera replanifiée au delà du jour J."
    }
}

/// Histogramme de la charge quotidienne. Une barre par jour, la plus haute en ocre :
/// c'est le jour dont il faut se méfier.
struct ExamLoadChart: View {
    let plan: ExamPlan

    private var load: [Int] { plan.projection.load }

    private var maximum: Int {
        max(1, load.max() ?? 1)
    }

    var body: some View {
        GeometryReader { proxy in
            // Les barres se resserrent quand les jours sont nombreux : un mois de révisions
            // dans la largeur d'un téléphone ne laisse pas trois points entre chaque.
            let spacing: CGFloat = load.count > 24 ? 1.5 : 3
            let gaps = spacing * CGFloat(max(0, load.count - 1))
            let width = max(2, (proxy.size.width - gaps) / CGFloat(max(1, load.count)))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(load.enumerated()), id: \.offset) { offset, count in
                    Capsule()
                        .fill(color(for: offset, count: count))
                        .frame(width: width, height: height(for: count, in: proxy.size.height))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
        }
        .frame(height: 56)
    }

    private func height(for count: Int, in available: CGFloat) -> CGFloat {
        guard count > 0 else { return 2 }
        return max(3, available * CGFloat(count) / CGFloat(maximum))
    }

    private func color(for offset: Int, count: Int) -> Color {
        guard count > 0 else { return MicaboColor.surfaceSunken.opacity(0.6) }
        return offset == plan.projection.busiest?.offset ? MicaboColor.caution : MicaboColor.accent.opacity(0.8)
    }
}
