import SwiftUI

// MARK: - Mika se présente

/// **« Salut, moi c'est Mika ! »** Un moment, avant la première question : un grand Mika au
/// centre, qui fait coucou, son nom, ce qu'il va faire, et un bouton. Rien ne défile tout
/// seul.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        V3Screen {
            // Mika prend d'abord sa place ; l'air qui reste se partage au-dessus et en dessous.
            Spacer(minLength: 12)
                .layoutPriority(-1)

            OnbHeroMika(mood: .wave, max: OnbLayout.heroWelcome)

            VStack(spacing: 12) {
                OnbTitle(i18n.t("ios.onb10.welcome.title"), size: OnbLayout.display, alignment: .center)
                Text(i18n.t("ios.onb10.welcome.sub"))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 20)

            Spacer(minLength: 12)
                .layoutPriority(-1)
        } footer: {
            V3Button(i18n.t("ios.onb10.go")) {
                model.advance()
            }
        }
    }
}

// MARK: - Le prénom

/// **« Comment je t'appelle ? »**
///
/// La première question, avant tout ce qui trie, et elle n'est pas facultative : tout ce qui
/// suit s'adresse à quelqu'un. Le prénom se tape en très grand, au centre ; le clavier est
/// ouvert d'emblée, et le bouton est actif dès la première lettre.
///
/// **Le clavier ne fait rien bouger.** La page est composée depuis le haut : la bulle, le
/// prénom, le bouton juste dessous. Le clavier monte et redescend sous eux, que la page
/// glisse ou non.
///
/// **Le prénom ne sert à rien d'autre.** Il ne part pas au modèle, il ne part pas au
/// serveur, il n'entre dans aucune consigne de génération.
struct NameStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @FocusState private var isFocused: Bool

    private var canContinue: Bool {
        model.displayName.nilIfBlank != nil
    }

    var body: some View {
        @Bindable var model = model

        OnbQuestion(i18n.t("ios.onb10.q.name"), mood: .wave, anchored: false) {
            VStack(spacing: 12) {
                field($model.displayName)
                Text(i18n.t("ios.onb10.name.hint"))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)

            V3Button(i18n.t("common.continue"), isEnabled: canContinue) {
                advance()
            }
            .padding(.top, 36)

            OnbKeyboardRoom(isActive: self.model.step == .name)
        }
        .onAppear { isFocused = true }
    }

    /// Le prénom, en très grand. Les rendus ne dessinent pas un champ du système : le prénom
    /// y est écrit.
    @ViewBuilder
    private func field(_ text: Binding<String>) -> some View {
        let placeholder = i18n.t("ios.onb.name.placeholder")
        if still {
            Text(text.wrappedValue.nilIfBlank ?? placeholder)
                .font(V3Font.display())
                .foregroundStyle(text.wrappedValue.nilIfBlank == nil ? V3Color.ink3 : V3Color.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        } else {
            TextField("", text: text, prompt: Text(placeholder).foregroundStyle(V3Color.ink3))
                .font(V3Font.display())
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .tint(V3Color.accent)
                .textInputAutocapitalization(.words)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.continue)
                .onSubmit { advance() }
                .accessibilityLabel(Text(placeholder))
        }
    }

    private func advance() {
        guard canContinue else { return }
        model.advance()
    }
}
