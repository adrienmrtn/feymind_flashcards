import SwiftUI

/// Écran 2 : où l'étudiant est scolarisé. **C'est la première question du parcours.**
///
/// Elle passe devant « tu en es où ? », et cet ordre est tout l'intérêt de l'écran : ce sont
/// les paliers du pays choisi qui deviennent les réponses de la question suivante. « Les
/// attendus du bac » ne veut rien dire pour un lycéen belge, un étudiant québécois ne passe
/// pas de concours de première année de santé, au Québec « baccalauréat » désigne un diplôme
/// universitaire, et proposer « Prépa » ou « PASS » à un Américain ne lui laisse aucune
/// réponse juste. Poser le niveau d'abord obligeait à servir les mêmes sept réponses
/// françaises à tout le monde.
///
/// **La langue se décide ici aussi**, et l'écran qui l'annonçait a disparu : il affichait
/// « Micabo parle français » avec une seule réponse cochée d'avance, ce qui est un écran
/// entier pour une information. Elle se lit maintenant sous les pastilles, à côté du système
/// scolaire retenu, là où elle est la conséquence d'un choix qu'on vient de faire.
///
/// Des pastilles à drapeau : un drapeau se reconnaît avant qu'on ait lu le nom. La France est
/// pré-choisie parce que c'est le cas de la grande majorité, et c'est ce que l'app supposait
/// déjà en silence. « Ailleurs » n'est pas un aveu d'échec : la liste ne peut pas couvrir le
/// monde, et une échelle générique vaut mieux que des paliers inventés.
struct CountryStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton école",
            title: "Tu étudies où ?",
            titleSize: 32,
            scrolls: false,
            animatesTitle: true
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
                            withAnimation(OnboardingMotion.tap) {
                                model.select(country: country)
                            }
                        }
                    }
                }

                // Les deux conséquences du choix, et rien d'autre : le système scolaire dont
                // viendront les réponses suivantes, et la langue des fiches. C'est ce qui
                // fait comprendre que la question n'est pas décorative.
                Text("\(model.country.systemHint) · \(model.language.label)")
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
