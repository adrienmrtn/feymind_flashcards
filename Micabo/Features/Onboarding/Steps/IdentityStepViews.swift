import SwiftUI

/// **« Comment veux-tu qu'on t'appelle ? »**
///
/// La question arrive **après** les matières, et elle est **facultative**. Elle ouvrait le
/// bloc des questions, clavier levé d'office, et c'était la marche la plus perdante de tout
/// le parcours avant le compte : vingt élèves sur deux cent trente-six partis là. Un prénom
/// ne sert qu'à s'adresser à quelqu'un — il ne part ni au modèle ni au serveur —, et une
/// question dont la réponse ne sert qu'au ton n'a pas à coûter un élève. « Passer » est
/// donc en haut à droite, et l'app dira « toi » à qui l'a pris.
///
/// **L'écran « enchanté » qui suivait est parti.** Il avançait tout seul au bout de deux
/// secondes ; quatre-vingt-cinq pour cent des élèves l'avaient déjà passé au doigt. Un
/// écran qu'on ne lit pas n'a pas de raison d'être un écran.
struct NameStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model

        return OnboardingScaffold(
            title: i18n.t("ios.onb.name"),
            subtitle: i18n.t("ios.onb.name.optional"),
            animatesTitle: true,
            skip: OnboardingSkip(action: skip)
        ) {
            HStack(spacing: 10) {
                TextField(i18n.t("ios.onb.name.placeholder"), text: $model.displayName)
                    .font(MicaboFont.ui(18, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
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
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1)
            }
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

    /// Passer laisse le champ vide **et l'écrit** : on ne garde pas la moitié d'un prénom
    /// tapé puis abandonné.
    private func skip() {
        model.displayName = ""
        isFocused = false
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
            animatesTitle: true,
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
/// Elle décide des matières proposées un écran plus loin, et du niveau d'écriture des
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
            animatesTitle: true,
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
