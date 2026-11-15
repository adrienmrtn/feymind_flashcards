import SwiftUI

// MARK: - Mika se présente, et pose le cadre

/// **« Faisons connaissance. »** L'ouverture du premier chapitre (lot 15) : la grille de tous
/// les écrans, et Mika en grand qui fait coucou et se présente dans sa bulle (« Salut, moi
/// c'est Mika ! … »).
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbChapterOpener(
            title: i18n.t("ios.onb15.open.welcome.title"),
            say: i18n.t("ios.onb15.open.welcome.say"),
            mood: .wave,
            cta: i18n.t("ios.onb10.go")
        ) {
            model.advance()
        }
    }
}

// MARK: - Le prénom

/// **« Comment tu t'appelles ? »** (lot 15 : le titre ne dit jamais « je »)
///
/// La première question, et elle n'est pas facultative : tout ce qui suit s'adresse à
/// quelqu'un. Le prénom se tape en très grand ; **Mika réagit dès la première lettre**
/// (« Enchanté, Lina ! », il sourit) : la première réponse reçoit sa récompense tout de suite.
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

    private var say: OnbSay {
        guard let name = model.displayName.nilIfBlank else {
            return OnbSay(i18n.t("ios.onb12.say.name"), mood: .wave)
        }
        return OnbSay(i18n.t("ios.onb12.react.name", ["name": name]), mood: .happy)
    }

    var body: some View {
        @Bindable var model = model

        OnbQuestion(i18n.t("ios.onb15.q.name"), say: say) {
            VStack(spacing: 0) {
                field($model.displayName)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .v3Card(selected: canContinue)

                V3Button(i18n.t("common.continue"), isEnabled: canContinue) {
                    advance()
                }
                .padding(.top, 20)

                OnbKeyboardRoom(isActive: self.model.step == .name)
            }
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
