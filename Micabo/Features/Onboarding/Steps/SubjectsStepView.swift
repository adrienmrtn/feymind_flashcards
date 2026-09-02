import SwiftUI

/// Choix des matières. Sélection multiple, catalogue volontairement large.
///
/// Le catalogue vit dans `SubjectCatalog`, hors de la vue : c'est ce qui permet de vérifier
/// qu'aucune matière d'une même famille ne porte l'emoji d'une autre.
struct SubjectsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.subjectsTitle") ?? "Tu révises quoi ?",
            titleSize: 28,
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(SubjectCatalog.families) { family in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(SubjectDisplay.family(family.name, locale: i18n?.locale ?? .resolved()).uppercased())
                            .font(MicaboFont.hanken(10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(MicaboColor.inkTertiary)

                        MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(family.subjects, id: \.self) { subject in
                                SubjectChip(
                                    title: SubjectDisplay.subject(subject, locale: i18n?.locale ?? .resolved()),
                                    // L'emoji d'une matière vient d'où viennent ceux des
                                    // cours : une table unique, et pas une deuxième liste à
                                    // maintenir en parallèle de celle-ci.
                                    emoji: SubjectCatalog.emoji(for: subject),
                                    isSelected: model.subjects.contains(subject)
                                ) {
                                    toggle(subject)
                                }
                            }
                        }
                    }
                }
            }
        } footer: {
            OnboardingContinueButton(
                title: subjectsContinueTitle,
                isEnabled: !model.subjects.isEmpty
            ) {
                model.advance()
            }
        }
    }

    private var subjectsContinueTitle: String {
        if model.subjects.isEmpty {
            return i18n?.t("ios.subjectsNeedOne") ?? "Choisis au moins une matière"
        }
        if model.subjects.count == 1 {
            return i18n?.t("onboarding.continueOne") ?? "Continuer avec 1 matière"
        }
        return i18n?.t("onboarding.continueMany", ["n": "\(model.subjects.count)"])
            ?? "Continuer avec \(model.subjects.count) matières"
    }

    private func toggle(_ subject: String) {
        withAnimation(OnboardingMotion.tap) {
            if model.subjects.contains(subject) {
                model.subjects.remove(subject)
            } else {
                model.subjects.insert(subject)
            }
        }
    }
}

private struct SubjectChip: View {
    let title: String
    var emoji: String?
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                } else if let emoji {
                    Text(emoji)
                        .font(.system(size: 13))
                }
                Text(title)
                    .font(MicaboFont.hanken(13, weight: .medium))
            }
            .foregroundStyle(isSelected ? MicaboColor.onInk : MicaboColor.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 13)
            .background(isSelected ? MicaboColor.accent : MicaboColor.surface, in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : MicaboColor.strokeStrong, lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1.03 : 1)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
    }
}
