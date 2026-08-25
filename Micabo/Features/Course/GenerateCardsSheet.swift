import SwiftUI

/// Le panneau qui précède une génération de cartes.
///
/// Les cartes ne sont plus une conséquence de l'import : ce sont désormais une demande, et
/// une demande se règle. Le volume et les formats vivaient jusqu'ici sur l'écran d'import,
/// juste au-dessus du bouton qui les utilisait ; ils l'ont suivi jusqu'ici, où ce bouton
/// se trouve maintenant.
///
/// **On règle un nombre par format, plus un volume et des interrupteurs.** Les
/// interrupteurs disaient « j'accepte des QCM » et laissaient le modèle décider combien :
/// on demandait vingt cartes et on en recevait deux à trous. Trois compteurs disent
/// exactement ce qu'on veut réviser, et le total se lit dessous.
struct GenerateCardsSheet: View {
    let course: Course
    var onGenerate: (CardGeneration.Options) -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage(QuestionQuotaPreferences.Key.basic) private var basic = QuestionQuota.default.basic
    @AppStorage(QuestionQuotaPreferences.Key.cloze) private var cloze = QuestionQuota.default.cloze
    @AppStorage(QuestionQuotaPreferences.Key.choice) private var choice = QuestionQuota.default.choice

    private var existingCount: Int {
        course.cards.count
    }

    /// Ce que les compteurs affichent, tel quel. Aucun rattrapage ici : un chiffre corrigé
    /// dans le dos de l'utilisateur ferait sauter le compteur sous son doigt.
    private var quota: QuestionQuota {
        QuestionQuota(basic: basic, cloze: cloze, choice: choice)
    }

    /// Le plafond se lit sur les compteurs, pas après coup : plutôt que de rogner un format
    /// après validation, le bouton « plus » s'éteint quand le total est atteint.
    private var isAtCap: Bool {
        quota.total >= QuestionQuota.totalRange.upperBound
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    MicaboScreenHeader(
                        title: existingCount > 0 ? "Nouvelles cartes" : MicaboCopy.cardsButton,
                        eyebrow: course.title,
                        back: MicaboHeaderBack.close { dismiss() }
                    )
                    .padding(.top, MicaboSpacing.xs)

                    Text(intro)
                        .font(MicaboFont.body)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    formatSection
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()

            MicaboBottomBar {
                Button {
                    let chosen = CardGeneration.Options(quota: quota.clamped())
                    dismiss()
                    onGenerate(chosen)
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text(MicaboCopy.cardsButton)
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle(tint: quota.total > 0 ? MicaboColor.ink : MicaboColor.strokeStrong))
                .disabled(quota.total == 0)
            }
        }
        .onAppear(perform: adoptRememberedQuota)
        .onChange(of: quota) { _, newValue in
            QuestionQuotaPreferences.save(newValue)
        }
    }

    private var intro: String {
        existingCount > 0
            ? "Micabo relit la fiche et écrit des cartes qui ne répètent pas les \(MicaboCopy.cards(existingCount)) déjà là."
            : "Micabo relit la fiche et en tire des cartes à réviser. Tu pourras les modifier, en ajouter et en supprimer."
    }

    /// Un compteur par format, dans l'ordre où ils se comprennent. Le recto verso reste en
    /// tête : c'est le format qui marche sur n'importe quel cours, et c'est celui qu'on
    /// diminue en dernier.
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Combien de cartes, par format")

            VStack(spacing: 0) {
                counterRow(
                    emoji: "🗂️",
                    background: MicaboColor.tilePastels[0],
                    title: CardKind.basic.label,
                    detail: "Une question, une réponse.",
                    value: $basic
                )

                MicaboHairline(inset: 71)

                counterRow(
                    emoji: "✏️",
                    background: MicaboColor.tilePastels[2],
                    title: CardKind.cloze.label,
                    detail: "Une phrase du cours, un terme à retrouver.",
                    value: $cloze
                )

                MicaboHairline(inset: 71)

                counterRow(
                    emoji: "🔤",
                    background: MicaboColor.tilePastels[4],
                    title: CardKind.choice.label,
                    detail: "Une question, trois ou quatre propositions.",
                    value: $choice
                )
            }
            .micaboGroup()
        }
    }

    private func counterRow(
        emoji: String,
        background: Color,
        title: String,
        detail: String,
        value: Binding<Int>
    ) -> some View {
        HStack(spacing: 13) {
            MicaboTile(glyph: .emoji(emoji), background: background)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MicaboFont.rowTitle)
                    .foregroundStyle(MicaboColor.ink)
                Text(detail)
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: MicaboSpacing.xs)

            MicaboStepper(
                value: value,
                range: QuestionQuota.perFormatRange,
                canIncrement: !isAtCap,
                label: title
            )
        }
        .padding(.vertical, 11)
        .padding(.horizontal, MicaboSpacing.md)
    }

    /// Reprend le quota retenu, y compris celui traduit depuis les anciens réglages.
    ///
    /// `@AppStorage` lit les nouvelles clés et retombe sur ses valeurs par défaut quand
    /// elles n'existent pas : sans cette reprise, un utilisateur qui avait coupé les QCM
    /// les retrouverait au premier lancement.
    private func adoptRememberedQuota() {
        let remembered = QuestionQuotaPreferences.current
        guard remembered != quota else { return }
        basic = remembered.basic
        cloze = remembered.cloze
        choice = remembered.choice
    }
}

/// Compteur à deux boutons, pour les réglages où le nombre exact compte.
///
/// Le `Stepper` du système traîne son propre intitulé et ses marges de formulaire : sur une
/// rangée à tuile, il ne s'aligne sur rien. Celui-ci ne dessine que ce qu'on lui demande, et
/// grise le bouton qui ne mène nulle part au lieu de le laisser réagir dans le vide.
struct MicaboStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    /// Faux quand une contrainte extérieure au compteur, un total plafonné par exemple,
    /// interdit d'augmenter.
    var canIncrement: Bool = true
    /// Ce que le lecteur d'écran annonce avant le nombre.
    var label: String

    var body: some View {
        HStack(spacing: 2) {
            button(systemImage: "minus", isEnabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }

            Text("\(value)")
                .font(MicaboFont.number(16, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .frame(minWidth: 26)

            button(systemImage: "plus", isEnabled: canIncrement && value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(MicaboColor.surfaceMuted, in: Capsule())
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            guard direction == .decrement || canIncrement else { return }
            let step = direction == .increment ? 1 : -1
            value = min(range.upperBound, max(range.lowerBound, value + step))
        }
    }

    private func button(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isEnabled ? MicaboColor.ink : MicaboColor.inkTertiary.opacity(0.4))
                .frame(width: 28, height: 28)
                .background(isEnabled ? MicaboColor.surface : Color.clear, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .disabled(!isEnabled)
    }
}
