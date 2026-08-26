import SwiftUI

/// Démonstration, 3 sur 3 : la fiche se découpe en tout ce qui sert à réviser.
///
/// L'écran s'ouvre sur **la fiche de l'écran précédent**, au même endroit et à la même
/// taille : c'est ce qui fait comprendre d'où vient le reste. Elle se défait ensuite en
/// quatre vignettes — un schéma, une carte recto verso, un QCM, un texte à trou — qui
/// sortent une à une, puis montrent chacune leur réponse toutes seules.
///
/// **On ne répond à rien ici, et c'est le point.** L'écran précédent demandait d'appuyer sur
/// une carte puis de se noter : on faisait passer un examen à quelqu'un qui n'a pas encore
/// ouvert l'app, sur un cours qui n'est pas le sien. Ce qu'il faut montrer, c'est ce que
/// Micabo produit à partir d'un cours ; le produire est le travail de l'app, y répondre
/// viendra plus tard, avec ses propres cours. L'écran se regarde donc, et le bouton attend
/// en bas.
struct DemoReviewStepView: View {
    @Environment(OnboardingModel.self) private var model

    private enum Phase {
        /// La fiche, telle qu'on l'a laissée.
        case sheet
        /// Elle se découpe en quatre vignettes.
        case split
    }

    @State private var phase: Phase = .sheet
    /// Nombre de vignettes sorties de la fiche.
    @State private var shown = 0
    /// Nombre de vignettes qui ont montré leur réponse.
    @State private var solved = 0
    @State private var didStart = false

    private var outputs: [OnboardingDemo.Output] { OnboardingDemo.Output.allCases }

    /// Le bouton s'ouvre dès que les quatre vignettes sont là. Les réponses continuent de
    /// se dévoiler derrière : personne ne doit attendre la fin d'une animation qu'il a
    /// déjà comprise.
    private var canContinue: Bool { shown >= outputs.count }

    var body: some View {
        OnboardingScaffold(
            title: "Tes cours sont transformés\nen contenus interactifs.",
            titleSize: 26,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false
        ) {
            VStack(spacing: 0) {
                stage
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } footer: {
            OnboardingContinueButton(isEnabled: canContinue) {
                model.advance()
            }
        }
        .onAppear(perform: run)
    }

    // MARK: - La scène

    /// La fiche et la grille occupent la même place : le découpage se lit comme une
    /// transformation, et non comme un changement d'écran.
    private var stage: some View {
        ZStack {
            DemoSheetPage()
                .frame(width: DemoSheetPage.width)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)
                .opacity(phase == .sheet ? 1 : 0)
                .scaleEffect(phase == .sheet ? 1 : 0.88)
                .blur(radius: phase == .sheet ? 0 : 3)

            grid
                .opacity(phase == .sheet ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .animation(OnboardingMotion.shift, value: phase)
    }

    private var grid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                tile(0)
                tile(1)
            }
            HStack(spacing: 10) {
                tile(2)
                tile(3)
            }
        }
    }

    private func tile(_ index: Int) -> some View {
        DemoOutputTile(output: outputs[index], isSolved: index < solved)
            .opacity(index < shown ? 1 : 0)
            .scaleEffect(index < shown ? 1 : 0.9)
            .offset(y: index < shown ? 0 : 10)
            .animation(OnboardingMotion.shift, value: shown)
    }

    // MARK: - Déroulé

    /// Un peu plus d'une seconde pour sortir les quatre vignettes, une de plus pour qu'elles
    /// se remplissent. Rien n'attend un geste : c'est une animation, pas un exercice.
    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            withAnimation(OnboardingMotion.shift) { phase = .split }
        }

        for index in 0..<outputs.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 + Double(index) * 0.16) {
                shown = index + 1
                Haptics.tick()
            }
        }

        for index in 0..<outputs.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.55 + Double(index) * 0.24) {
                withAnimation(OnboardingMotion.shift) { solved = index + 1 }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55 + Double(outputs.count) * 0.24) {
            Haptics.success()
        }
    }
}

// MARK: - Les quatre vignettes

/// Une des quatre formes que prend la fiche. Chacune montre sa réponse toute seule quand
/// `isSolved` passe à vrai : la vignette se résout sous les yeux, on ne la résout pas.
private struct DemoOutputTile: View {
    let output: OnboardingDemo.Output
    let isSolved: Bool

    private static let height: CGFloat = 156

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Self.height)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 9, x: 0, y: 4)
        .animation(OnboardingMotion.tap, value: isSolved)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Image(systemName: output.systemImage)
                .font(.system(size: 8.5, weight: .bold))

            Text(output.label.uppercased())
                .font(MicaboFont.hanken(8, weight: .bold))
                .tracking(0.9)
                .lineLimit(1)
        }
        .foregroundStyle(OnboardingDemo.accent)
    }

    @ViewBuilder
    private var content: some View {
        switch output {
        case .schema: DemoSchemaMini(showsLoop: isSolved)
        case .flashcard: flashcard
        case .quiz: quiz
        case .gap: gap
        }
    }

    // MARK: Recto verso

    private var flashcard: some View {
        let card = OnboardingDemo.cards[0]

        return VStack(alignment: .leading, spacing: 6) {
            Text(card.front)
                .font(MicaboFont.hanken(10.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(MicaboColor.hairline)
                .frame(height: 1)

            Text(isSolved ? card.back : "…")
                .font(MicaboFont.hanken(10, weight: .medium))
                .foregroundStyle(isSolved ? OnboardingDemo.accent : MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: QCM

    private var quiz: some View {
        let card = OnboardingDemo.cards[1]

        return VStack(alignment: .leading, spacing: 5) {
            Text(card.front)
                .font(MicaboFont.hanken(9.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
                let isAnswer = isSolved && index == card.answerIndex

                HStack(spacing: 4) {
                    Text(choice)
                        .font(MicaboFont.hanken(8.5, weight: .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 0)

                    if isAnswer {
                        Image(systemName: "checkmark")
                            .font(.system(size: 7, weight: .bold))
                    }
                }
                .foregroundStyle(isAnswer ? MicaboColor.positive : MicaboColor.inkSecondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isAnswer ? MicaboColor.positiveSoft : MicaboColor.surfaceMuted,
                    in: Capsule()
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Texte à trou

    /// La phrase est composée d'un seul tenant : le mot manquant remplace le blanc à sa
    /// place, sans que le paragraphe se recompose autour.
    private var gap: some View {
        gapText
            .font(MicaboFont.hanken(10.5, weight: .medium))
            .foregroundStyle(MicaboColor.inkReading)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
    }

    private var gapText: Text {
        let filled = Text(OnboardingDemo.gapAnswer)
            .font(MicaboFont.hanken(10.5, weight: .bold))
            .foregroundStyle(OnboardingDemo.accent)

        let blank = Text("________")
            .font(MicaboFont.hanken(10.5, weight: .bold))
            .foregroundStyle(MicaboColor.inkTertiary)

        return Text(OnboardingDemo.gapBefore + " ")
            + (isSolved ? filled : blank)
            + Text(OnboardingDemo.gapAfter)
    }
}

/// Le schéma du cycle de l'eau en vignette : trois temps empilés, et la boucle du retour
/// à la mer qui se ferme à la fin.
///
/// C'est une composition verticale, et non la figure de la fiche réduite : à cette largeur,
/// trois étiquettes côte à côte tombent sous la taille où un mot se lit encore.
private struct DemoSchemaMini: View {
    let showsLoop: Bool

    private let stages: [(symbol: String, label: String, tint: Color)] = [
        ("sun.max.fill", "Évaporation", MicaboColor.caution),
        ("cloud.fill", "Condensation", MicaboColor.inkSecondary),
        ("cloud.rain.fill", "Précipitations", OnboardingDemo.accent)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                HStack(spacing: 6) {
                    Image(systemName: stage.symbol)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(stage.tint)
                        .frame(width: 13)

                    Text(stage.label)
                        .font(MicaboFont.hanken(9, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }

                if index < stages.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 6.5, weight: .bold))
                        .foregroundStyle(OnboardingDemo.accent.opacity(0.55))
                        .frame(width: 13)
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 7, weight: .bold))

                Text("retour à la mer")
                    .font(MicaboFont.hanken(8, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(OnboardingDemo.accent)
            .padding(.vertical, 2.5)
            .padding(.horizontal, 6)
            .background(OnboardingDemo.accent.opacity(0.14), in: Capsule())
            .opacity(showsLoop ? 1 : 0)
            .padding(.top, 2)
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            OnboardingDemo.accent.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }
}
