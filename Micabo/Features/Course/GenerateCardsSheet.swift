import SwiftUI

/// Le panneau qui précède une génération de cartes.
///
/// Les cartes ne sont plus une conséquence de l'import : ce sont désormais une demande, et
/// une demande se règle. Le volume et les formats vivaient jusqu'ici sur l'écran d'import,
/// juste au-dessus du bouton qui les utilisait ; ils l'ont suivi jusqu'ici, où ce bouton
/// se trouve maintenant.
struct GenerateCardsSheet: View {
    let course: Course
    var onGenerate: (CardGeneration.Options) -> Void

    @Environment(\.dismiss) private var dismiss

    @AppStorage(QuestionMixPreferences.Key.cloze) private var includesCloze = true
    @AppStorage(QuestionMixPreferences.Key.choice) private var includesChoice = true
    @AppStorage(QuestionMixPreferences.Key.count) private var count = QuestionMixPreferences.defaultCount

    private var existingCount: Int {
        course.cards.count
    }

    private var options: CardGeneration.Options {
        CardGeneration.Options(
            count: QuestionMixPreferences.countChoices.contains(count) ? count : QuestionMixPreferences.defaultCount,
            mix: QuestionMix(includesCloze: includesCloze, includesChoice: includesChoice)
        )
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

                    volumeSection
                    formatSection
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboLayout.bottomBarClearance)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()

            MicaboBottomBar {
                Button {
                    let chosen = options
                    dismiss()
                    onGenerate(chosen)
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text(MicaboCopy.cardsButton)
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }
        }
    }

    private var intro: String {
        existingCount > 0
            ? "Micabo relit la fiche et écrit des cartes qui ne répètent pas les \(MicaboCopy.cards(existingCount)) déjà là."
            : "Micabo relit la fiche et en tire des cartes à réviser. Tu pourras les modifier, en ajouter et en supprimer."
    }

    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Combien de cartes")

            HStack(spacing: MicaboSpacing.xs) {
                ForEach(QuestionMixPreferences.countChoices, id: \.self) { value in
                    MicaboSelectChip(title: "\(value)", isSelected: value == count) {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) { count = value }
                    }
                }
            }

            MicaboSectionFootnote(
                text: "Un chapitre tient en général en douze cartes. Tu peux en redemander plus tard."
            )
        }
    }

    /// Le recto verso ne se coupe pas : c'est le format qui marche sur n'importe quel
    /// cours, les deux autres viennent en plus quand le passage s'y prête.
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Types de questions")

            VStack(spacing: 0) {
                formatToggle(
                    title: "Textes à trou",
                    detail: "Une phrase du cours, un terme à retrouver.",
                    isOn: $includesCloze
                )

                MicaboHairline(inset: MicaboSpacing.md)

                formatToggle(
                    title: "QCM",
                    detail: "Une question, trois ou quatre propositions, une seule bonne.",
                    isOn: $includesChoice
                )
            }
            .micaboGroup()

            MicaboSectionFootnote(text: "Le recto verso est toujours de la partie.")
        }
    }

    private func formatToggle(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MicaboFont.rowTitle)
                    .foregroundStyle(MicaboColor.ink)
                Text(detail)
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(MicaboColor.accent)
        .padding(.vertical, 12)
        .padding(.horizontal, MicaboSpacing.md)
    }
}
