import SwiftUI

// MARK: - Mika se présente, et pose le cadre

/// **« Salut, moi c'est Mika ! »** Le premier moment : un grand Mika qui fait coucou, son nom,
/// et le cadre de ce qui suit — quelques questions faciles, puis le plan, puis la première
/// leçon. Trois jalons, pour que l'élève sache où il va avant de répondre à quoi que ce soit.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbScreen {
            Spacer(minLength: 8)
                .layoutPriority(-1)

            OnbHeroMika(mood: .wave, max: OnbLayout.heroWelcome)

            VStack(spacing: 10) {
                OnbTitle(i18n.t("ios.onb12.welcome.title"), size: OnbLayout.display, alignment: .center)
                Text(i18n.t("ios.onb12.welcome.sub"))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 16)

            milestones
                .padding(.top, 22)

            Spacer(minLength: 8)
                .layoutPriority(-1)
        } footer: {
            V3Button(i18n.t("ios.onb10.go")) {
                model.advance()
            }
        }
    }

    /// Les trois jalons : toi, ton plan, ta première leçon.
    private var milestones: some View {
        HStack(alignment: .top, spacing: 0) {
            milestone(.profile, i18n.t("ios.onb12.welcome.you"), tone: V3Color.iconBlue)
            arrow
            milestone(.exam, i18n.t("ios.onb12.welcome.plan"), tone: V3Color.iconYellow)
            arrow
            milestone(.book, i18n.t("ios.onb12.welcome.lesson"), tone: V3Color.iconGreen)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func milestone(_ icon: MicaboIcon, _ label: String, tone: Color) -> some View {
        VStack(spacing: 8) {
            MicaboIconView(icon: icon, size: 30 * 1.35, tint: tone)
                .frame(width: 54, height: 54)
                .background(V3Color.surface, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous)
                        .strokeBorder(V3Color.line, lineWidth: V3Metric.border)
                )
            Text(label)
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    private var arrow: some View {
        Image(systemName: "chevron.forward")
            .font(.system(size: 14, weight: .black))
            .foregroundStyle(V3Color.ink3)
            .padding(.top, 20)
            .accessibilityHidden(true)
    }
}

// MARK: - Le prénom

/// **« Comment je t'appelle ? »**
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

        OnbQuestion(i18n.t("ios.onb12.q.name"), say: say) {
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
