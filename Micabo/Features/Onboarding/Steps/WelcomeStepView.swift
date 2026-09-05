import SwiftData
import SwiftUI

/// L'accroche. Un paquet de cartes se rebat tout seul, et rien d'autre.
///
/// Le paragraphe d'explication qui vivait ici est parti. Sur le premier écran d'une app,
/// personne ne lit trois lignes sur le fonctionnement d'un algorithme : on regarde. Les
/// cartes disent déjà ce que fait Micabo, et **elles montrent les trois formats** — recto
/// verso, QCM, texte à trou — ce qu'aucune phrase ne faisait.
///
/// « J'ai déjà un compte » ouvre Apple, Google ou le courriel. Une session Supabase
/// *est* le compte : on entre dans l'app, on ne recommence pas l'accueil.
///
/// Le paquet vit dans `WelcomeDeck.swift`. Le laisser ici faisait abandonner le
/// compilateur : trop d'expressions, et une `Face` privée que la carte ne pouvait pas lire.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext

    @State private var showLogin = false
    @State private var checkingAccount = false

    private let surface = OnboardingStep.welcome.surface

    var body: some View {
        layout
            .background(surface.background.ignoresSafeArea(edges: .bottom))
            .environment(\.onboardingSurface, surface)
            .sheet(isPresented: $showLogin) {
                loginSheet
            }
            .onChange(of: auth.isSignedIn) { _, signedIn in
                guard signedIn, showLogin else { return }
                Task { await resolveLogin() }
            }
    }

    private var layout: some View {
        VStack(spacing: 0) {
            LanguageSwitcher(variant: .flags)
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .onboardingAppear(index: 0, stagger: 0.1)
            Spacer(minLength: MicaboSpacing.sm)
            deck
            Spacer(minLength: MicaboSpacing.md)
            titleBlock
            continueBar
        }
    }

    private var deck: some View {
        WelcomeDeck()
            .frame(height: 220)
            .padding(.horizontal, MicaboSpacing.xl)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MICABO")
                .font(MicaboFont.hanken(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(surface.eyebrow)
                .onboardingAppear(index: 1, stagger: 0.1)

            Text(i18n?.t("ios.welcomeTitle") ?? "Apprends tout,\nplus vite.")
                .font(MicaboFont.hanken(40, weight: .bold))
                .foregroundStyle(surface.title)
                .tracking(-1.2)
                .lineSpacing(-3)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingAppear(index: 2, stagger: 0.1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, MicaboSpacing.lg)
    }

    private var continueBar: some View {
        MicaboBottomBar(background: surface.background) {
            VStack(spacing: 12) {
                OnboardingContinueButton(title: i18n?.t("common.start") ?? "Commencer") {
                    model.advance()
                }
                Button {
                    showLogin = true
                } label: {
                    Text(i18n?.t("common.alreadyAccount") ?? "J'ai déjà un compte")
                        .font(MicaboFont.hanken(14.5, weight: .medium))
                        .foregroundStyle(surface.prose)
                        .underline()
                }
                .buttonStyle(.plain)
                .disabled(auth.isWorking || checkingAccount)
            }
            .onboardingAppear(index: 3, stagger: 0.1)
        }
    }

    private var loginSheet: some View {
        SignInScreen(
            placement: .sheet,
            onDismiss: { showLogin = false },
            onCreateAccount: {
                showLogin = false
                model.advance()
            },
            isResolving: checkingAccount
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
        .presentationBackground(MicaboColor.canvas)
        .interactiveDismissDisabled(auth.isWorking || checkingAccount)
    }

    @MainActor
    private func resolveLogin() async {
        checkingAccount = true
        _ = await sync.recognizeExistingAccount()
        OnboardingPreferences.markCompleted()
        checkingAccount = false
        showLogin = false
        await sync.sync(context: modelContext)
    }
}
