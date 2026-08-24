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
            subtitle: "Affronte tes examens avec moins de stress et plus de préparation.",
            titleSize: 30,
            scrolls: false
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

    @State private var litReviews = 0
    @State private var isCircled = false
    @State private var showsLabel = false
    @State private var didStart = false

    var body: some View {
        VStack(spacing: 16) {
            grid
            label
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
            if isExam, isCircled {
                Circle()
                    .strokeBorder(MicaboColor.negative, lineWidth: 2)
                    .frame(width: 30, height: 30)
                    .transition(.opacity)
            }

            VStack(spacing: 3) {
                Text("\(index + 1)")
                    .font(MicaboFont.hanken(12, weight: isExam ? .bold : .regular))
                    .foregroundStyle(isExam ? MicaboColor.negative : MicaboColor.inkSecondary)
                    .monospacedDigit()

                Circle()
                    .fill(isLit ? MicaboColor.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .animation(OnboardingMotion.tap, value: isLit)
        .animation(OnboardingMotion.shift, value: isCircled)
    }

    /// L'étiquette de l'examen, avec sa matière et son chapitre : une date entourée sans nom
    /// ne dit pas ce qu'on prépare.
    private var label: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(MicaboColor.negative)
                .frame(width: 3, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("EXAMEN")
                    .font(MicaboFont.hanken(9, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(MicaboColor.negative)

                Text("Maths · vecteurs")
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
            }

            Spacer(minLength: MicaboSpacing.xs)

            Text("J-19")
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.negativeSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        .opacity(showsLabel ? 1 : 0)
        .offset(y: showsLabel ? 0 : 6)
        .animation(OnboardingMotion.shift, value: showsLabel)
    }

    /// La date s'entoure, son nom apparaît, puis les révisions se posent une à une.
    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            isCircled = true
            Haptics.tick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showsLabel = true
        }

        for rank in reviewDays.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1 + Double(rank) * 0.16) {
                litReviews = rank + 1
                Haptics.tick()
            }
        }
    }
}
