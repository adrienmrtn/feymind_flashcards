import SwiftUI

/// **« Tes matières cette année ? »** Choix multiple.
///
/// L'écran propose **les matières de la classe qu'on vient de déclarer** : un élève de
/// terminale voit les siennes et coche en trois secondes. Le catalogue général reste à un
/// appui (« Autres matières »). Mika reprend la classe, puis réagit dès la première coche.
struct SubjectsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var showsCatalog = false

    /// Les matières de la classe déclarée, vides quand on n'en sait pas assez.
    private var mine: [String] {
        Self.classSubjects(for: model)
    }

    /// Le catalogue général, sans ce que la classe propose déjà.
    private var others: [String] {
        let known = Set(mine)
        return SubjectCatalog.allSubjects.filter { !known.contains($0) }
    }

    /// Le catalogue se montre quand la classe n'a pas de liste, quand l'élève le demande, ou
    /// quand une matière déjà cochée s'y trouve (un retour sur l'écran).
    private var showsOthers: Bool {
        mine.isEmpty || showsCatalog || !model.subjects.isSubset(of: Set(mine))
    }

    private var hasAnswer: Bool {
        !model.subjects.isEmpty
    }

    private var say: OnbSay {
        if hasAnswer {
            return OnbSay(i18n.t("ios.onb10.react.subjects"), mood: .write)
        }
        if !mine.isEmpty, let label = model.classLabel {
            return OnbSay(i18n.t("ios.onb12.say.subjectsOf", ["class": label]), mood: .idle)
        }
        return OnbSay(i18n.t("ios.onb12.say.subjects"), mood: .idle)
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb12.q.subjects"), say: say) {
            VStack(alignment: .leading, spacing: 14) {
                if !mine.isEmpty {
                    chips(mine)
                }

                if showsOthers {
                    if !mine.isEmpty {
                        Text(i18n.t("ios.onb10.subjects.more"))
                            .font(V3Font.caption)
                            .foregroundStyle(V3Color.ink3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)
                    }
                    chips(others)
                } else {
                    V3Chip(i18n.t("ios.onb10.subjects.more"), systemImage: "plus") {
                        withAnimation(MicaboMotion.standard) { showsCatalog = true }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: hasAnswer) {
                model.advance()
            }
        }
    }

    /// **Les matières de la classe de l'élève** (`SchoolSubjects.forYear`), ou rien quand le
    /// pays n'est pas décrit : on ne rend pas une liste inventée.
    static func classSubjects(for model: OnboardingModel) -> [String] {
        guard SchoolSystem.isDetailed(model.country, custom: model.customCountry) else { return [] }
        return SchoolSubjects.forYear(
            trackID: model.track?.id,
            yearID: model.year?.id,
            country: model.country
        ) ?? []
    }

    private func chips(_ subjects: [String]) -> some View {
        MicaboFlowLayout(spacing: 8, lineSpacing: 10) {
            ForEach(subjects, id: \.self) { subject in
                OnbSubjectChip(
                    title: SubjectDisplay.subject(subject, locale: i18n.locale),
                    isSelected: model.subjects.contains(subject)
                ) {
                    toggle(subject)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ subject: String) {
        withAnimation(MicaboMotion.quick) {
            if model.subjects.contains(subject) {
                model.subjects.remove(subject)
            } else {
                model.subjects.insert(subject)
            }
        }
    }
}

/// **Une matière en puce, qui saute quand on la coche.**
struct OnbSubjectChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let calm = reduceMotion
        let selected = isSelected
        V3Chip(title, isSelected: isSelected, action: action)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: isSelected) { content, scale in
                content.scaleEffect(calm || !selected ? 1 : scale)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.08, duration: 0.1)
                    SpringKeyframe(1.0, duration: 0.25)
                }
            }
    }
}

// MARK: - La matière la plus dure

/// **« Laquelle te donne le plus de fil à retordre ? »** (lot 12) Une réponse, parmi ses
/// matières. C'est elle que prennent ensuite les démonstrations et la question d'essai : la
/// douleur est nommée, et la réponse de l'app y revient tout de suite.
struct HardestSubjectStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb12.q.hardest"),
            say: OnbSay(i18n.t("ios.onb12.say.hardest"), mood: .wink)
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.subjects.sorted(), id: \.self) { subject in
                    OnbOption(
                        title: SubjectDisplay.subject(subject, locale: i18n.locale),
                        icon: MicaboIcon.subjectIcon(subject) ?? .book,
                        isSelected: model.hardestSubject == subject
                    ) {
                        OnbPick.choose(on: .hardestSubject, model: model) { model.hardestSubject = subject }
                    }
                }
            }
        } footer: {
            // Un appui suffit (la page part à la fin du ressort) ; le bouton reste à sa place,
            // le même que partout, pour qui revient sur l'écran.
            V3Button(i18n.t("common.continue"), isEnabled: model.hardestSubject != nil) {
                model.advance()
            }
        }
    }
}
