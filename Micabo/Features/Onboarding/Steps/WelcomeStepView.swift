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
            Spacer(minLength: MicaboSpacing.md)
            deck
            Spacer(minLength: MicaboSpacing.lg)
            titleBlock
            continueBar
        }
    }

    private var deck: some View {
        WelcomeDeck()
            .frame(height: 250)
            .padding(.horizontal, MicaboSpacing.xl)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MICABO")
                .font(MicaboFont.hanken(11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(surface.eyebrow)
                .onboardingAppear(index: 0, stagger: 0.1)

            Text("Apprends tout,\nplus vite.")
                .font(MicaboFont.hanken(40, weight: .bold))
                .foregroundStyle(surface.title)
                .tracking(-1.2)
                .lineSpacing(-3)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingAppear(index: 1, stagger: 0.1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, MicaboSpacing.lg)
    }

    private var continueBar: some View {
        MicaboBottomBar(background: surface.background) {
            VStack(spacing: 12) {
                OnboardingContinueButton(title: "Commencer") {
                    model.advance()
                }
                Button {
                    showLogin = true
                } label: {
                    Text("J'ai déjà un compte")
                        .font(MicaboFont.hanken(14.5, weight: .medium))
                        .foregroundStyle(surface.prose)
                        .underline()
                }
                .buttonStyle(.plain)
                .disabled(auth.isWorking || checkingAccount)
            }
            .onboardingAppear(index: 2, stagger: 0.1)
        }
    }

    private var loginSheet: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            Text("Content de te revoir.")
                .font(MicaboFont.hanken(28, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text("Connecte-toi pour retrouver tes cours, tes cartes et ta série.")
                .font(MicaboFont.hanken(15))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            SignInFailureNote()

            if checkingAccount {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("On cherche ton compte…")
                        .font(MicaboFont.hanken(14.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }

            Spacer(minLength: 0)

            SignInProviderButtons()
        }
        .padding(MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xl)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
