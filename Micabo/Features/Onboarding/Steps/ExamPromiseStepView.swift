import SwiftUI

/// Après la démonstration : ce que Micabo fait des examens.
///
/// L'écran arrive là parce qu'on vient de voir le cycle complet, dépôt, fiche, cartes, et
/// que la question suivante est naturellement « et pour mon contrôle de jeudi ? ».
///
/// Le calendrier ne se contente pas d'entourer une date : les jours qui la précèdent se
/// remplissent un à un de points de révision. C'est exactement ce que fait le mode examen,
/// et le voir vaut mieux que le lire.
struct ExamPromiseStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Mode examen",
            title: "Un parcours pour\nchaque examen.",
            titleSize: 30
        ) {
            ExamCountdownCalendar()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Calendrier de démonstration : une date d'examen entourée, et les révisions qui y mènent.
///
/// **C'est la seule illustration animée du parcours à s'autoriser des ressorts.** La règle
/// du tunnel — rien ne rebondit — protège les transitions d'écran et les entrées de
/// contenu, où un dépassement se lit comme un tremblement. Ici, on regarde un planificateur
/// travailler : les points de révision se posent, et un point qui se pose a le droit de
/// tomber. C'est aussi le seul moyen de faire lire six événements en une seconde et demie.
private struct ExamCountdownCalendar: View {
    /// Position de l'examen dans la grille. Vingt-huit cases, quatre semaines : la date
    /// tombe en fin de troisième semaine, ce qui laisse de la place devant pour les points
    /// de révision et derrière pour que la grille reste une grille.
    private let examIndex = 18
    private let columns = 7
    private let dayCount = 28

    /// Les jours qui portent une révision, dans l'ordre où ils s'allument. Ils se resserrent
    /// à l'approche de l'examen, comme le fait le planificateur.
    private let reviewDays = [4, 7, 11, 14, 16, 17]

    /// Jours restants annoncés par l'étiquette. Il descend de 28 à 19 en égrenant les
    /// chiffres : un compte à rebours qui s'affiche d'un coup n'est pas un compte à rebours.
    private static let startingDaysLeft = 28
    private static let finalDaysLeft = 19

    @State private var litReviews = 0
    /// Avancement du tracé du cercle, de 0 à 1 : il se dessine, il n'apparaît pas.
    @State private var circleTrim: CGFloat = 0
    @State private var examScale: CGFloat = 0.55
    @State private var daysLeft = Self.startingDaysLeft
    @State private var showsLabel = false
    @State private var showsFooter = false
    /// Onde rouge qui repart en boucle sous la date : c'est elle qui garde l'œil sur le
    /// jour J pendant que les révisions se posent devant.
    @State private var pings = false
    @State private var didStart = false

    var body: some View {
        VStack(spacing: 14) {
            grid
            label
            footer
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .onAppear(perform: run)
    }

    private var grid: some View {
        VStack(spacing: 7) {
            HStack(spacing: 0) {
                ForEach(Array(MicaboCalendar.weekdayInitials.enumerated()), id: \.offset) { _, initial in
                    Text(initial)
                        .font(MicaboFont.hanken(10, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<(dayCount / columns), id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<columns, id: \.self) { column in
                        cell(at: row * columns + column)
                    }
                }
            }
        }
    }

    private func cell(at index: Int) -> some View {
        let isExam = index == examIndex
        let reviewRank = reviewDays.firstIndex(of: index)
        let isLit = reviewRank.map { $0 < litReviews } ?? false

        return ZStack {
            if isExam {
                ping
                examRing
            }

            if isLit {
                Circle()
                    .fill(MicaboColor.accentSoft)
                    .frame(width: 27, height: 27)
            }

            VStack(spacing: 3) {
                Text("\(index + 1)")
                    .font(MicaboFont.hanken(12, weight: isExam ? .bold : .regular))
                    .foregroundStyle(dayTint(isExam: isExam, isLit: isLit))
                    .monospacedDigit()
                    .scaleEffect(isExam ? examScale : 1)

                Circle()
                    .fill(isLit ? MicaboColor.accent : Color.clear)
                    .frame(width: 4, height: 4)
                    .scaleEffect(isLit ? 1 : 0.2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        // Le point tombe sur sa case : c'est un ressort court, et il ne concerne que la
        // pastille et son halo, jamais la grille autour.
        .animation(.spring(response: 0.32, dampingFraction: 0.58), value: isLit)
        .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.55), value: circleTrim)
        .animation(.spring(response: 0.42, dampingFraction: 0.5), value: examScale)
    }

    private func dayTint(isExam: Bool, isLit: Bool) -> Color {
        if isExam { return MicaboColor.negative }
        return isLit ? MicaboColor.ink : MicaboColor.inkSecondary
    }

    /// Le cercle du jour J se trace depuis midi, comme au stylo.
    private var examRing: some View {
        Circle()
            .trim(from: 0, to: circleTrim)
            .stroke(MicaboColor.negative, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 30, height: 30)
    }

    private var ping: some View {
        Circle()
            .fill(MicaboColor.negative.opacity(0.16))
            .frame(width: 30, height: 30)
            .scaleEffect(pings ? 1.75 : 0.85)
            .opacity(pings ? 0 : 0.9)
    }

    /// L'étiquette de l'examen, avec sa matière et son épreuve : une date entourée sans nom
    /// ne dit pas ce qu'on prépare. Elle entre par la gauche, et son filet rouge se déplie
    /// de haut en bas plutôt que d'apparaître à sa taille.
    private var label: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(MicaboColor.negative)
                .frame(width: 3, height: showsLabel ? 26 : 0)

            VStack(alignment: .leading, spacing: 1) {
                Text("EXAMEN")
                    .font(MicaboFont.hanken(9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(MicaboColor.negative)

                Text("Maths DS sur table")
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
            }

            Spacer(minLength: MicaboSpacing.xs)

            Text("J-\(daysLeft)")
                .font(MicaboFont.number(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeOut(duration: 0.12), value: daysLeft)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.negativeSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        .opacity(showsLabel ? 1 : 0)
        .offset(x: showsLabel ? 0 : -14)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: showsLabel)
    }

    /// Ce que le planificateur vient de faire, dit une fois les points posés. Le chiffre
    /// n'est pas écrit en dur : il compte les révisions qu'on a vues arriver.
    private var footer: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))

            Text("\(reviewDays.count) révisions placées avant le jour J")
                .font(MicaboFont.hanken(12, weight: .semibold))
        }
        .foregroundStyle(MicaboColor.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.accentSoft, in: Capsule())
        .opacity(showsFooter ? 1 : 0)
        .scaleEffect(showsFooter ? 1 : 0.94)
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: showsFooter)
    }

    /// Le cercle se trace, la date prend son nom, le compte à rebours s'égrène, puis les
    /// révisions se posent une à une et l'écran dit ce qu'il vient de faire.
    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            circleTrim = 1
            examScale = 1
            Haptics.tick()
        }

        // L'onde ne part qu'une fois le cercle tracé : elle se lit alors comme une alarme
        // posée sur la date, et non comme une tache qui bat sous un chiffre.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                pings = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showsLabel = true
        }

        for (offset, value) in stride(from: Self.startingDaysLeft - 1, through: Self.finalDaysLeft, by: -1).enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.72 + Double(offset) * 0.05) {
                daysLeft = value
            }
        }

        let dotsStart = 1.3
        for rank in reviewDays.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + dotsStart + Double(rank) * 0.15) {
                litReviews = rank + 1
                Haptics.tick()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dotsStart + Double(reviewDays.count) * 0.15) {
            showsFooter = true
            Haptics.success()
        }
    }
}
