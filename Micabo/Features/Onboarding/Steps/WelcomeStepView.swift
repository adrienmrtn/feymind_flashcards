import SwiftData
import SwiftUI

/// **L'accroche : la promesse, et de quoi la croire.**
///
/// C'est le premier écran, et le seul qui porte une sortie : « j'ai déjà un compte ». Elle
/// doit rester là et nulle part ailleurs — quelqu'un qui réinstalle l'app n'a aucune raison
/// de traverser vingt-six écrans pour retrouver ses decks, et la reléguer plus loin revient à
/// la cacher.
///
/// **Les quatre decks pastel qui flottaient autour de la mascotte sont partis.** Ils
/// montaient et descendaient en boucle, chacun à son rythme, et c'est le premier mouvement
/// qu'on voyait de l'app : une scène de jeu, avant d'avoir lu un mot. La mascotte reste,
/// seule, plus petite, immobile à part sa respiration — c'est ici qu'elle salue, et c'est
/// l'une des deux seules fois où elle apparaît. Sous la promesse, une ligne de preuve : la
/// note, les avis, les inscrits de la semaine. Ce qu'on demande de croire est écrit à côté
/// de ce qui permet de le croire.
///
/// « J'ai déjà un compte » ouvre Apple, Google ou le courriel. Une session Supabase
/// *est* le compte : on entre dans l'app, on ne recommence pas l'accueil.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext

    @State private var showLogin = false
    @State private var checkingAccount = false

    private let surface = OnboardingStep.howItWorks.surface

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
            // **La langue est un menu, pas une rangée de drapeaux.**
            //
            // Cinq pavés alignés en haut du premier écran pesaient autant que le titre, et
            // le premier écran d'une app a une seule chose à faire : donner envie d'entrer.
            // Un menu dit la même chose en une ligne, et il se déroule pour qui en a besoin.
            HStack {
                Spacer(minLength: 0)
                LanguageSwitcher(variant: .menu)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
            .onboardingAppear(index: 0, stagger: 0.1)

            Spacer(minLength: MicaboSpacing.md)

            MicaboMascot(mood: .waving, size: 112)
                .onboardingAppear(index: 1, stagger: 0.1)

            Spacer(minLength: MicaboSpacing.md)

            titleBlock
            proofStrip
            continueBar
        }
    }

    /// Le nom, puis la promesse. Centrés : c'est une affiche, pas une page de question.
    private var titleBlock: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                MicaboBrandMark(size: 24)
                Text("Micabo")
                    .font(MicaboFont.ui(17, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(MicaboColor.accent)
            }
            .onboardingAppear(index: 2, stagger: 0.1)

            Text(i18n.t("ios.intro.tagline"))
                .font(MicaboFont.ui(36, weight: .bold))
                .foregroundStyle(surface.title)
                .tracking(-1.1)
                .lineSpacing(-2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingAppear(index: 3, stagger: 0.1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MicaboSpacing.screen)
    }

    /// **La preuve, sous la promesse.** Les étoiles et leur nombre d'avis, puis les
    /// inscrits de la semaine : deux lignes courtes, en gris, que l'œil lit après le titre
    /// sans qu'on les lui impose.
    private var proofStrip: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(MicaboColor.caution)
                    }
                }
                .accessibilityElement()
                .accessibilityLabel(i18n.t("ios.starsA11y"))

                Text(i18n.t("ios.welcome.rating", [
                    "rating": OnboardingNumbers.text(OnboardingProofFigures.rating, locale: i18n.locale),
                    "n": OnboardingNumbers.text(OnboardingProofFigures.reviews, locale: i18n.locale),
                ]))
                .font(MicaboFont.ui(13, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
            }

            Text(i18n.t("ios.welcome.students", [
                "n": OnboardingNumbers.text(OnboardingProofFigures.studentsThisWeek, locale: i18n.locale),
            ]))
            .font(MicaboFont.ui(13, weight: .medium))
            .foregroundStyle(MicaboColor.inkSecondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 18)
        .padding(.bottom, MicaboSpacing.lg)
        .onboardingAppear(index: 4, stagger: 0.1)
    }

    /// Un bouton, et une ligne grise dessous. Le compte est une sortie pour ceux qui
    /// reviennent, pas une seconde proposition : un second bouton de la même largeur
    /// faisait hésiter entre deux portes, alors qu'il n'y en a qu'une pour qui arrive.
    ///
    /// Le bouton se remplit pendant deux secondes : le temps de lire la promesse et la
    /// preuve. La sortie, elle, répond tout de suite — quelqu'un qui revient n'a rien à
    /// lire.
    private var continueBar: some View {
        MicaboBottomBar(background: surface.background) {
            VStack(spacing: 14) {
                OnboardingContinueButton(title: i18n.t("common.start"), gate: 2.0) {
                    model.advance()
                }

                Button {
                    showLogin = true
                } label: {
                    Text(i18n.t("common.alreadyAccount"))
                        .font(MicaboFont.ui(13.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .disabled(auth.isWorking || checkingAccount)
            }
            .onboardingAppear(index: 5, stagger: 0.1)
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
