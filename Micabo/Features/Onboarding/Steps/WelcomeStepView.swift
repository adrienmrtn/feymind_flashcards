import SwiftData
import SwiftUI

/// **L'accroche : la mascotte, ses decks, et une promesse en quatre mots.**
///
/// C'est le premier des écrans d'ouverture, et le seul qui porte une sortie : « j'ai déjà
/// un compte ». Elle doit rester là et nulle part ailleurs — quelqu'un qui réinstalle l'app
/// n'a aucune raison de traverser vingt-deux écrans pour retrouver ses decks, et la
/// reléguer plus loin revient à la cacher.
///
/// **Le paquet de cartes qui se rebattait est parti.** Trois cartes de révision qui se
/// mélangeaient toutes seules montraient l'app de l'intérieur avant qu'on sache ce qu'elle
/// est, et elles se lisaient de loin comme un écran de jeu. Les applications de référence
/// (Ahead, Hablo) ouvrent toutes de la même façon : le personnage, au milieu, avec ce qui
/// gravite autour de lui — puis le nom, la promesse, le bouton. Ici, c'est la mascotte qui
/// salue, et quatre decks pastel qui flottent autour d'elle : les mêmes tuiles que celles
/// de l'app, avec les mêmes matières. On voit ce qu'on va avoir, et qui va nous aider.
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

            Spacer(minLength: MicaboSpacing.sm)

            WelcomeScene()

            Spacer(minLength: MicaboSpacing.md)

            titleBlock
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
            .onboardingAppear(index: 1, stagger: 0.1)

            Text(i18n.t("ios.intro.tagline"))
                .font(MicaboFont.ui(36, weight: .bold))
                .foregroundStyle(surface.title)
                .tracking(-1.1)
                .lineSpacing(-2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingAppear(index: 2, stagger: 0.1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, MicaboSpacing.lg)
    }

    /// Deux boutons de la même largeur : commencer, en violet plein ; le compte, en violet
    /// lavé. Un lien souligné sous un bouton se lisait comme une note de bas de page, et
    /// ceux qui reviennent le cherchaient.
    private var continueBar: some View {
        MicaboBottomBar(background: surface.background) {
            VStack(spacing: 10) {
                OnboardingContinueButton(title: i18n.t("common.start"), isShiny: true) {
                    model.advance()
                }

                Button {
                    showLogin = true
                } label: {
                    Text(i18n.t("common.alreadyAccount"))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            MicaboColor.accentSoft,
                            in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                        )
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
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

// MARK: - La scène

/// **La mascotte au milieu, et quatre decks qui flottent autour d'elle.**
///
/// Les tuiles sont celles de la grille des decks — même rayon, mêmes pastels, un emoji de
/// matière — posées en orbite à des hauteurs différentes. Chacune respire à son rythme,
/// décalée des autres, pour que la scène ne monte pas et ne descende pas d'un bloc. À
/// l'ouverture, elles arrivent l'une après l'autre en grandissant, la mascotte en dernier :
/// c'est elle qu'on doit regarder à la fin.
private struct WelcomeScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drift = false
    @State private var shown = false

    private struct Orbit {
        let emoji: String
        let x: CGFloat
        let y: CGFloat
        let side: CGFloat
        let tilt: Double
        let pastel: Int
        let delay: Double
    }

    private static let orbits: [Orbit] = [
        Orbit(emoji: "🏛️", x: -118, y: -66, side: 64, tilt: -8, pastel: 0, delay: 0),
        Orbit(emoji: "🧬", x: 122, y: -38, side: 58, tilt: 7, pastel: 1, delay: 0.55),
        Orbit(emoji: "📐", x: -100, y: 76, side: 54, tilt: 6, pastel: 3, delay: 1.1),
        Orbit(emoji: "🤔", x: 110, y: 84, side: 50, tilt: -6, pastel: 2, delay: 1.65),
    ]

    var body: some View {
        let mascotScale: CGFloat = shown ? 1 : 0.6
        let mascotAlpha: Double = shown ? 1 : 0

        return ZStack {
            ForEach(Array(Self.orbits.enumerated()), id: \.offset) { index, orbit in
                tile(orbit, index: index)
            }

            MicaboMascot(mood: .waving, size: 150)
                .scaleEffect(mascotScale)
                .opacity(mascotAlpha)
                .animation(OnboardingMotion.enter.delay(0.32), value: shown)
        }
        .frame(height: 300)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear(perform: start)
        .task { await feel() }
    }

    /// **La scène se sent arriver.** Un petit coup par tuile, au rythme où elles se
    /// posent, puis un plus doux quand la mascotte atterrit : le premier écran de l'app
    /// répond au doigt avant même qu'on l'ait touché.
    @MainActor
    private func feel() async {
        guard !reduceMotion else { return }
        try? await Task.sleep(for: .milliseconds(320))
        for _ in Self.orbits {
            guard !Task.isCancelled else { return }
            Haptics.tick()
            try? await Task.sleep(for: .milliseconds(90))
        }
        try? await Task.sleep(for: .milliseconds(180))
        guard !Task.isCancelled else { return }
        Haptics.soft()
    }

    private func tile(_ orbit: Orbit, index: Int) -> some View {
        let lift: CGFloat = drift ? -6 : 6
        let turn: Double = drift ? orbit.tilt : -orbit.tilt
        let scale: CGFloat = shown ? 1 : 0.4
        let alpha: Double = shown ? 1 : 0
        let arrival: Double = 0.1 + Double(index) * 0.09
        let corner: CGFloat = orbit.side * 0.34
        let glyph: CGFloat = orbit.side * 0.5

        return Text(orbit.emoji)
            .font(.system(size: glyph))
            .frame(width: orbit.side, height: orbit.side)
            .background(
                MicaboColor.pastel(at: orbit.pastel),
                in: RoundedRectangle(cornerRadius: corner, style: .continuous)
            )
            .rotationEffect(.degrees(turn))
            .offset(x: orbit.x, y: orbit.y + lift)
            .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true).delay(orbit.delay), value: drift)
            .scaleEffect(scale)
            .opacity(alpha)
            .animation(OnboardingMotion.enter.delay(arrival), value: shown)
    }

    private func start() {
        shown = true
        guard !reduceMotion else { return }
        drift = true
    }
}
