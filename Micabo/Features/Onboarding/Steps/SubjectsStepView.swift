import SwiftUI

/// **« Quelles matières on travaille ensemble ? »** Choix multiple.
///
/// L'écran propose **les matières de la classe qu'on vient de déclarer** : un élève de
/// terminale voit les siennes et coche en trois secondes. Le catalogue général reste à un
/// appui (« Autres matières ») : quelqu'un suit une option que sa classe ne liste pas, et lui
/// cacher le reste serait lui dire que sa matière n'existe pas. Sans classe connue, c'est le
/// catalogue qui s'affiche.
///
/// **Mika réagit dès la première matière cochée** : sa bulle change, et il se met à écrire.
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

    var body: some View {
        OnbQuestion(
            i18n.t(hasAnswer ? "ios.onb10.react.subjects" : "ios.onb10.q.subjects"),
            mood: hasAnswer ? .write : .idle,
            anchored: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if !mine.isEmpty {
                    if let label = model.classLabel {
                        caption(i18n.t("ios.onb10.subjects.of", ["class": label]))
                    }
                    chips(mine)
                }

                if showsOthers {
                    if !mine.isEmpty {
                        caption(i18n.t("ios.onb10.subjects.more"))
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

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(V3Font.caption)
            .foregroundStyle(V3Color.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func chips(_ subjects: [String]) -> some View {
        MicaboFlowLayout(spacing: 8, lineSpacing: 10) {
            ForEach(subjects, id: \.self) { subject in
                V3Chip(
                    SubjectDisplay.subject(subject, locale: i18n.locale),
                    isSelected: model.subjects.contains(subject)
                ) {
                    toggle(subject)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toggle(_ subject: String) {
        if model.subjects.contains(subject) {
            model.subjects.remove(subject)
        } else {
            model.subjects.insert(subject)
        }
    }
}
