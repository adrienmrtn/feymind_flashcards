import SwiftUI

/// **« Comment veux-tu qu'on t'appelle ? »**
///
/// C'est la première question du parcours, et elle est posée avant celles qui servent à
/// quelque chose. Ce n'est pas un ordre arbitraire : elle est la seule à laquelle on répond
/// sans effort, et elle change la nature de ce qui suit. Après elle, l'app s'adresse à
/// quelqu'un ; avant elle, elle remplit un formulaire.
///
/// **Le prénom ne sert à rien d'autre.** Rien ne le lit à part l'écran suivant et l'accueil.
/// Il ne part pas au modèle, il ne part pas au serveur, il n'entre dans aucune consigne de
/// génération — et c'est bien pour ça qu'on peut le demander sans rien expliquer.
struct NameStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @FocusState private var isFocused: Bool

    var body: some View {
        @Bindable var model = model

        return OnboardingScaffold(
            title: i18n.t("ios.onb.name"),
            animatesTitle: true
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
}

/// **« Enchanté, Adrien. »**
///
/// Un écran entier pour une phrase, et il se traverse en une seconde. Il gagne sa place
/// parce qu'il est le seul du parcours à ne rien demander : tout ce qui précède était une
/// démonstration, tout ce qui suit est une question, et sans lui le prénom qu'on vient de
/// donner disparaîtrait sans que personne l'utilise.
///
/// Il avance **tout seul** après deux secondes, et le bouton reste pour qui va plus vite.
/// Un écran qui n'a rien à demander et qui attend quand même un appui fait douter d'avoir
/// manqué quelque chose.
struct GreetingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isVisible = false
    /// **Le garde-fou de l'écran qui avance tout seul.**
    ///
    /// Il part au bout de deux secondes et il part aussi au bouton. Quelqu'un qui appuie à
    /// la seconde et neuf dixièmes déclencherait les deux, et `advance()` appelé deux fois
    /// saute un écran — ici, la question du pays, qui ne se reposerait jamais.
    @State private var didAdvance = false

    private var name: String {
        model.displayName.nilIfBlank ?? i18n.t("ios.onb.greeting.fallback")
    }

    var body: some View {
        VStack(spacing: MicaboSpacing.md) {
            Spacer(minLength: 0)

            Text("👋")
                .font(.system(size: 64))
                .scaleEffect(isVisible ? 1 : 0.6)
                .opacity(isVisible ? 1 : 0)

            Text(i18n.t("ios.onb.greeting", ["name": name]))
                .font(MicaboFont.ui(34, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.8)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 10)

            Text(i18n.t("ios.onb.greeting.body"))
                .font(MicaboFont.ui(15, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(isVisible ? 1 : 0)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, MicaboSpacing.xl)
        .safeAreaInset(edge: .bottom) {
            MicaboBottomBar {
                OnboardingContinueButton(action: advance)
            }
        }
        .task {
            withAnimation(OnboardingMotion.enter) { isVisible = true }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            advance()
        }
    }

    private func advance() {
        guard !didAdvance else { return }
        didAdvance = true
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
