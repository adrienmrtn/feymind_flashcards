import SwiftUI

/// **« Dernière question : comment tu t'appelles ? »**
///
/// C'est la dernière question du quiz, le titre le dit, et elle est facultative : on la pose quand l'élève
/// a déjà donné quatorze réponses, au moment où l'app va lui dire merci et construire son
/// plan. Après elle, l'app s'adresse à quelqu'un.
///
/// **Le prénom ne sert à rien d'autre.** Il ne part pas au modèle, il ne part pas au
/// serveur, il n'entre dans aucune consigne de génération.
struct NameStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model

        return OnboardingScaffold(
            title: i18n.t("ios.onb.name.last"),
            subtitle: i18n.t("ios.onb.name.optional"),
            skip: OnboardingSkip(action: { model.advance() })
        ) {
            HStack(spacing: 10) {
                TextField(i18n.t("ios.onb.name.placeholder"), text: $model.displayName)
                    .font(MicaboFont.ui(20, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .textInputAutocapitalization(.words)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { advance() }

                if !model.displayName.isEmpty {
                    Button {
                        model.displayName = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17))
                            .foregroundStyle(OnboardingPalette.gray)
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear { isFocused = true }
        } footer: {
            OnboardingContinueButton(
                isEnabled: model.displayName.nilIfBlank != nil,
                action: advance
            )
        }
    }

    private func advance() {
        guard model.displayName.nilIfBlank != nil else { return }
        model.advance()
    }
}

/// **« Tu es dans quel type d'établissement ? »**
///
/// « Lycée » ne dit pas ce qu'on étudie. Un élève de terminale STMG et un élève de terminale
/// générale n'ont ni les mêmes matières, ni la même épreuve, ni le même niveau d'écriture
/// attendu — et c'est la différence entre une fiche qui sert et une fiche à côté.
///
/// L'écran ne s'affiche que dans les pays décrits assez finement pour qu'il ait de vraies
/// réponses (`SchoolSystem`). Ailleurs, il se saute et le palier large suffit : inventer
/// « lycée technologique » pour un pays qui n'en a pas produirait une réponse fausse, et une
/// réponse fausse coûte plus cher qu'une réponse large.
struct SchoolTypeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb.schoolType"),
            expandsContent: true
        ) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(model.tracks.enumerated()), id: \.element.id) { rank, track in
                        OnboardingChoiceRow(
                            title: track.title,
                            emoji: track.emoji,
                            isSelected: model.track?.id == track.id,
                            rank: rank
                        ) {
                            model.track = track
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        } footer: {
            OnboardingContinueButton(isEnabled: model.track != nil) { model.advance() }
        }
    }
}

/// **« Tu es en quelle année ? »**
///
/// Elle décide des matières proposées deux écrans plus loin, et du niveau d'écriture des
/// cours générés. C'est la question la plus précise du parcours, et la dernière sur le
/// « où j'en suis ».
struct SchoolYearStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var years: [SchoolYear] { model.track?.years ?? [] }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb.year"),
            subtitle: model.track?.title,
            expandsContent: true
        ) {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(Array(years.enumerated()), id: \.element.id) { rank, year in
                        OnboardingChoiceRow(
                            title: year.title,
                            isSelected: model.year?.id == year.id,
                            rank: rank
                        ) {
                            model.year = year
                        }
                    }
                }
            }
            .scrollIndicators(.hidden)
        } footer: {
            OnboardingContinueButton(isEnabled: model.year != nil) { model.advance() }
        }
    }
}
