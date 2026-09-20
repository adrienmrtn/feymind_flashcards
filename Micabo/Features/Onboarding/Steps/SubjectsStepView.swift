import SwiftUI

/// **Les matières qu'on suit.** Sélection multiple.
///
/// L'écran propose d'abord **les matières de l'année qu'on vient de déclarer**, et le
/// catalogue général en dessous. C'est ce que change la question de la filière et de
/// l'année : un terminale générale voit ses huit matières et coche en trois secondes, là où
/// le catalogue entier — trente-huit pastilles en sept familles — l'oblige à chercher les
/// siennes parmi celles de la médecine et du droit.
///
/// Le catalogue reste dessous et n'est pas replié : quelqu'un suit une option que son année
/// ne liste pas, ou révise pour un concours qui n'a rien à voir, et lui cacher le reste
/// serait lui dire que sa matière n'existe pas.
///
/// Les emojis viennent de `CourseEmoji`, la même table que les cours importés : une seconde
/// liste tenue en parallèle finirait par donner à une matière un emoji que ses cours n'ont
/// pas.
struct SubjectsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.subjectsTitle"),
            titleSize: 26,
            animatesTitle: true
        ) {
            VStack(alignment: .leading, spacing: 20) {
                if !mine.isEmpty {
                    section(title: i18n.t("ios.onb.subjects.mine"), subjects: mine)
                }

                ForEach(SubjectCatalog.families) { family in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(SubjectDisplay.family(family.name, locale: i18n.locale).uppercased())
                            .font(MicaboFont.ui(10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(MicaboColor.inkTertiary)

                        MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(family.subjects, id: \.self) { subject in
                                SubjectChip(
                                    title: SubjectDisplay.subject(subject, locale: i18n.locale),
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

    /// Les matières de l'année déclarée, vides quand on n'en sait pas assez.
    ///
    /// Le repli sur le catalogue entier est **silencieux** : on ne rend rien plutôt que de
    /// répéter les trente-huit pastilles une seconde fois sous un intitulé « tes matières »
    /// qui serait alors un mensonge.
    private var mine: [String] {
        guard SchoolSystem.isDetailed(model.country) else { return [] }
        return SchoolSubjects.forYear(
            trackID: model.track?.id,
            yearID: model.year?.id,
            country: model.country
        ) ?? []
    }

    private func section(title: String, subjects: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(MicaboFont.ui(10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(MicaboColor.accent)

            MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(subjects, id: \.self) { subject in
                    SubjectChip(
                        title: subject,
                        emoji: SubjectCatalog.emoji(for: subject),
                        isSelected: model.subjects.contains(subject)
                    ) {
                        toggle(subject)
                    }
                }
            }
        }
    }

    private var subjectsContinueTitle: String {
        if model.subjects.isEmpty {
            return i18n.t("ios.subjectsNeedOne")
        }
        if model.subjects.count == 1 {
            return i18n.t("onboarding.continueOne")
        }
        return i18n.t("onboarding.continueMany", ["n": "\(model.subjects.count)"])
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
                    .font(MicaboFont.ui(13, weight: .medium))
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
