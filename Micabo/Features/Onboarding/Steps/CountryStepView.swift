import SwiftUI

/// Écran 4 : où l'étudiant est scolarisé.
///
/// Elle vient juste après la langue, et pour la même raison : **parler français ne dit pas
/// dans quel système on étudie.** « Les attendus du bac » ne veut rien dire pour un lycéen
/// belge, un étudiant québécois ne passe pas de concours de première année de santé, et au
/// Québec « baccalauréat » désigne un diplôme universitaire. Une fiche qui renvoie à un
/// examen qui n'existe pas là où on étudie perd sa raison d'être, et c'est cette question
/// qui l'évite.
///
/// Dix pays, en pastilles à drapeau : ce sont ceux où l'on étudie en français, et un drapeau
/// se reconnaît avant qu'on ait lu le nom. La France est pré-choisie parce que c'est le cas
/// de la grande majorité, et c'est ce que l'app supposait déjà en silence.
struct CountryStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton école",
            title: "Tu étudies où ?",
            titleSize: 32,
            scrolls: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
                MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(SchoolingCountry.allCases) { country in
                        OnboardingChoiceChip(
                            title: country.name,
                            emoji: country.flag,
                            isSelected: model.country == country
                        ) {
                            Haptics.selection()
                            model.country = country
                        }
                    }
                }

                // La conséquence du choix, et rien d'autre : le nom du système scolaire
                // retenu. C'est ce qui fait comprendre que la question n'est pas décorative.
                Text(model.country.systemHint)
                    .font(MicaboFont.hanken(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .contentTransition(.opacity)
                    .animation(OnboardingMotion.tap, value: model.country)
            }
        } footer: {
            OnboardingContinueButton { model.advance() }
        }
    }
}
