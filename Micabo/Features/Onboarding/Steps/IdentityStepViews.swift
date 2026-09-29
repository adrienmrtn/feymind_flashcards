import SwiftUI

// MARK: - Le prénom

/// **« Comment veux-tu qu'on t'appelle ? »**
///
/// C'est la première question, avant tout ce qui trie, et elle n'est pas facultative : tout
/// ce qui suit s'adresse à quelqu'un — la bienvenue, le bravo, l'accueil — et une app qui
/// dit « bienvenue, toi » n'a rien demandé.
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
            title: i18n.t("ios.onb.name")
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
            // Le clavier arrive une fois la page posée : ouvert pendant le glissement, il
            // ferait remonter le bas de la page avant qu'elle ne soit arrivée.
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration) {
                    isFocused = true
                }
            }
        } footer: {
            OnboardingArrowButton(
                isEnabled: model.displayName.nilIfBlank != nil,
                action: advance
            )
        }
    }

    private func advance() {
        guard model.displayName.nilIfBlank != nil else { return }
        isFocused = false
        model.advance()
    }
}

// MARK: - La bienvenue

/// **« Bienvenue, {prénom}. On est ravis de t'avoir ici. Apprenons à te connaître. »**
///
/// Une page pour une phrase, entre le prénom et la première question. Elle gagne sa place
/// parce qu'elle change de registre : jusqu'ici on demandait, à partir d'ici l'app parle à
/// quelqu'un. Le prénom s'écrit en grand, la phrase se lit mot à mot en dessous, et le rond
/// n'arrive qu'une fois le dernier mot posé.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var titleRead = false
    @State private var isReady = false

    private var name: String {
        model.displayName.nilIfBlank ?? OnboardingPreferences.displayName ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                OnboardingReadingText(
                    template: i18n.t("ios.onb.welcome.title", ["name": name]),
                    size: 38,
                    wordDelay: 0.22,
                    startDelay: 0.55,
                    highlightsOnFinish: false,
                    onFinish: { titleRead = true }
                )
                .padding(.horizontal, MicaboSpacing.screen)

                if titleRead {
                    OnboardingReadingText(
                        template: i18n.t("ios.onb.welcome.sub"),
                        size: 22,
                        wordDelay: 0.14,
                        startDelay: 0.25,
                        hapticsPerWord: false,
                        highlightsOnFinish: false,
                        onFinish: {
                            withAnimation(.easeOut(duration: 0.4)) { isReady = true }
                        }
                    )
                    .padding(.horizontal, MicaboSpacing.xl)
                    .padding(.top, MicaboSpacing.lg)
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.3), value: titleRead)

            OnboardingArrowBar {
                model.advance()
            }
            .opacity(isReady ? 1 : 0)
            .allowsHitTesting(isReady)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

// MARK: - La filière

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
            OnboardingArrowButton(isEnabled: model.track != nil) { model.advance() }
        }
    }
}

// MARK: - L'année

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
            OnboardingArrowButton(isEnabled: model.year != nil) { model.advance() }
        }
    }
}
