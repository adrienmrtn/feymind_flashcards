import SwiftData
import SwiftUI

// MARK: - Le splash, puis le logo

/// **Le premier écran : le logo seul, puis la phrase et le bouton qui se posent.**
///
/// C'est un splash qui devient une page. Pendant un peu plus d'une seconde, il n'y a que
/// le monogramme et le mot, au milieu du blanc ; puis, sans que rien ne bouge, la phrase
/// arrive dessous, le bouton en bas, le menu de langue en haut. Le logo ne se déplace
/// pas : il était déjà à sa place, et c'est ce qui rend le passage fluide — un élément qui
/// glisse pour faire de la place se lit comme deux écrans, un élément qui reste se lit
/// comme un seul.
///
/// C'est aussi le seul écran qui porte une sortie : « j'ai déjà un compte ». Quelqu'un qui
/// réinstalle l'app n'a aucune raison de traverser trente écrans pour retrouver ses decks.
///
/// **Le bouton dit « Commencer »**, en toutes lettres : c'est le seul écran où avancer est
/// une décision qu'on prend, et pas la suite d'une réponse. Partout ailleurs, le rond
/// fléché suffit.
struct HookLogoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLogin = false
    @State private var checkingAccount = false
    /// Faux pendant le splash, vrai quand la page est posée.
    @State private var isReady = false
    @State private var hasLanded = false

    /// Le temps du splash, avant que la page ne se pose.
    private static let splashDuration = 1.3

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                LanguageSwitcher(variant: .menu)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
            .opacity(isReady ? 1 : 0)

            Spacer(minLength: 0)

            VStack(spacing: 18) {
                MicaboBrandMark(size: 128)
                    .shadow(color: OnboardingPalette.ink.opacity(0.12), radius: 24, y: 12)
                    .scaleEffect(hasLanded ? 1 : 0.86)

                Text("Micabo")
                    .font(MicaboFont.ui(30, weight: .bold))
                    .tracking(-1)
                    .foregroundStyle(OnboardingPalette.ink)
            }
            .opacity(hasLanded ? 1 : 0)

            Spacer(minLength: 0)

            Text(i18n.t("ios.hook.title"))
                .font(OnboardingPalette.title(34))
                .foregroundStyle(OnboardingPalette.ink)
                .tracking(-0.9)
                .lineSpacing(-2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MicaboSpacing.screen)
                .opacity(isReady ? 1 : 0)

            Spacer(minLength: MicaboSpacing.md)
                .frame(maxHeight: MicaboSpacing.xl)

            MicaboBottomBar(background: OnboardingPalette.white) {
                // Le lien **au-dessus** du bouton : le bouton reste ainsi à la même hauteur
                // que sur l'écran suivant, et il ne saute pas d'une page à l'autre.
                VStack(spacing: 14) {
                    Button {
                        showLogin = true
                    } label: {
                        Text(i18n.t("common.alreadyAccount"))
                            .font(MicaboFont.ui(14, weight: .medium))
                            .foregroundStyle(OnboardingPalette.gray)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                    .disabled(auth.isWorking || checkingAccount)

                    OnboardingContinueButton(title: i18n.t("common.start")) {
                        model.advance()
                    }
                }
                .opacity(isReady ? 1 : 0)
                .allowsHitTesting(isReady)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .task { await land() }
        .sheet(isPresented: $showLogin) {
            loginSheet
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            guard signedIn, showLogin else { return }
            Task { await resolveLogin() }
        }
    }

    /// Le logo se pose, on le laisse seul, puis la page arrive autour de lui.
    @MainActor
    private func land() async {
        if reduceMotion {
            hasLanded = true
            isReady = true
            return
        }
        withAnimation(.easeOut(duration: 0.6)) { hasLanded = true }
        try? await Task.sleep(for: .seconds(Self.splashDuration))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.5)) { isReady = true }
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
