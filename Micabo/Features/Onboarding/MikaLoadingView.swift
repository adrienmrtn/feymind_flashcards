import SwiftUI

/// **Ce qu'on regarde pendant que Mika travaille.**
///
/// Le blob en haut, qui respire ; « Salut, je suis Mika » ; ce qu'il fait, peint du
/// dégradé ; le pourcentage ; puis une grille de points qui se remplit de gauche à droite,
/// colonne par colonne, et la ligne qui dit l'étape en cours. Le même écran sert deux
/// fois : quand le profil se prépare, sur un temps joué, et quand un cours se construit
/// pour de vrai, sur un temps mesuré — c'est le parent qui donne l'avancement, la vue ne
/// fait que le montrer.
///
/// **Les points plutôt qu'une barre.** Une barre lisse se lit comme une animation ; une
/// grille qui se remplit par colonnes avance par petits sauts, et c'est ce qui la fait
/// lire comme un travail — sans les à-coups exagérés de l'ancien écran.
struct MikaLoadingView: View {
    /// Entre 0 et 1.
    var progress: Double
    var title: String
    var subtitle: String
    /// L'étape en cours, sous la grille.
    var stepLabel: String
    /// Le blob rapetisse un peu à la fin : c'est le geste qui prépare la page suivante, où
    /// il attend en haut, en petit.
    var isDone: Bool = false

    private static let rows = 4
    private static let columns = 28

    private var percent: Int {
        Int((min(1, max(0, progress)) * 100).rounded())
    }

    /// Les colonnes de points que l'avancement a remplies.
    private var filledColumns: Int {
        Int((min(1, max(0, progress)) * Double(Self.columns)).rounded(.down))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            MikaBlob(size: 224)
                .scaleEffect(isDone ? 0.86 : 1)
                .animation(.easeInOut(duration: 0.6), value: isDone)
                .padding(.bottom, 34)

            Text(title)
                .font(MicaboFont.ui(34, weight: .bold))
                .tracking(-0.9)
                .foregroundStyle(OnboardingPalette.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            MikaGradientText(text: subtitle, size: 24, weight: .bold)
                .padding(.top, 10)
                .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)
                .frame(maxHeight: MicaboSpacing.xxl)

            percentLabel

            dots
                .padding(.top, 18)
                .padding(.horizontal, MicaboSpacing.screen)

            Text(stepLabel)
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(OnboardingPalette.gray)
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.25), value: stepLabel)
                .padding(.top, 16)
                .frame(minHeight: 40, alignment: .top)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OnboardingPalette.white.ignoresSafeArea())
        // **Le travail se sent.** Un coup doux à chaque colonne qui s'allume — vingt-huit sur
        // le chargement, à un rythme qui suit les ralentissements de la jauge — et un coup
        // plus net à chaque étape franchie. C'est ce qui fait lire un travail qui avance
        // plutôt qu'une animation qu'on regarde.
        .onChange(of: filledColumns) { previous, next in
            guard next > previous else { return }
            Haptics.soft()
        }
        .onChange(of: stepLabel) { _, _ in
            Haptics.light()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(stepLabel)")
        .accessibilityValue("\(percent) %")
    }

    // MARK: - Le pourcentage

    /// **Le chiffre a une largeur fixe, celle de « 100 % », et s'y aligne à droite.** Un
    /// texte centré qui passe de « 9 % » à « 10 % » puis à « 100 % » s'élargit et se
    /// recentre à chaque chiffre gagné : ça tremblait à l'arrivée de la page, quand les
    /// unités deviennent des dizaines, et à la fin, quand elles deviennent des centaines.
    /// Ici, le signe ne bouge jamais, et les chiffres roulent sur place.
    private var percentLabel: some View {
        ZStack(alignment: .trailing) {
            Text("100 %")
                .hidden()

            Text("\(percent) %")
                .contentTransition(.numericText(value: Double(percent)))
                .animation(.easeOut(duration: 0.2), value: percent)
        }
        .font(MicaboFont.ui(40, weight: .bold))
        .tracking(-1.2)
        .foregroundStyle(OnboardingPalette.ink)
        .monospacedDigit()
        .fixedSize()
    }

    // MARK: - La grille de points

    /// Quatre rangées de points. Ceux que l'avancement a dépassés sont en violet, la
    /// colonne qu'il vient d'atteindre s'allume en orange, le reste attend en gris.
    private var dots: some View {
        let filled = filledColumns

        return VStack(spacing: 5) {
            ForEach(0..<Self.rows, id: \.self) { _ in
                HStack(spacing: 0) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        Circle()
                            .fill(Self.color(column: column, filled: filled))
                            .frame(width: 4, height: 4)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .animation(.easeOut(duration: 0.18), value: filled)
        .accessibilityHidden(true)
    }

    private static func color(column: Int, filled: Int) -> Color {
        if column < filled - 2 { return OnboardingPalette.mikaGradient[0] }
        if column < filled { return OnboardingPalette.mikaGradient[2] }
        return OnboardingPalette.cardStrong
    }
}
