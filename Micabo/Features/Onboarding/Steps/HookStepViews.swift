import SwiftData
import SwiftUI

// MARK: - Le premier écran

/// **Le premier écran : le bleu du lancement, d'où Mika monte.**
///
/// Il partait d'un blanc avec le monogramme et le mot « Micabo » qui se posaient en fondu,
/// juste après un écran de lancement qui montrait déjà l'icône : deux logos à la suite, et un
/// saut entre les deux. L'écran de lancement est maintenant un aplat bleu Micabo
/// (`LaunchBackground`), et cet écran **commence sur ce même aplat**, sans rien dessus : la
/// première image SwiftUI est identique au lancement, au pixel près.
///
/// Puis, d'un seul mouvement :
///
/// 1. le panneau du bas monte du bord de l'écran, Mika assis derrière lui ;
/// 2. Mika sort de derrière le panneau (`appear`), puis fait coucou (`wave`) — un buste,
///    collé au bord du panneau comme le veut le kit (règle 1) ;
/// 3. le titre, le bouton et « J'ai déjà un compte » se posent sur le panneau, en fondu.
///
/// Avec « Réduire les animations », tout est là d'emblée, Mika en image fixe.
///
/// C'est aussi le seul écran qui porte une sortie : « J'ai déjà un compte ». C'est **la seule
/// façon de sauter le parcours** sur une installation neuve (`LaunchGate`) : une connexion
/// qui aboutit depuis ici ouvre l'app sur les cours du compte.
struct HookLogoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var showLogin = false
    @State private var checkingAccount = false
    /// L'élève a choisi « J'ai déjà un compte » : la prochaine connexion qui aboutit ouvre
    /// l'app. Levé s'il choisit finalement de créer un compte.
    @State private var wantsExistingAccount = false

    /// Le panneau du bas est monté.
    @State private var panelUp = HookIntro.played
    /// Mika est posé derrière le panneau. Il n'entre qu'après la première image : son
    /// animation n'a pas à peser sur elle.
    @State private var showsMika = HookIntro.played
    @State private var mikaMood: MikaMood = HookIntro.played ? .idle : .appear
    /// Le titre et les boutons se sont posés.
    @State private var contentVisible = HookIntro.played

    /// Ce qui dépasse de Mika sous le bord du panneau : la coupe du buste se cache derrière.
    private static let mikaTuck: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                MicaboBrand.launch
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    mika(width: proxy.size.width)
                        .padding(.bottom, -Self.mikaTuck)
                    panel
                        .zIndex(1)
                }
                // Le panneau part du bas de l'écran, Mika avec lui.
                .offset(y: isPanelUp ? 0 : proxy.size.height + proxy.safeAreaInsets.bottom)

                topBar
            }
        }
        .environment(\.onboardingSurface, .canvas)
        .task { await enter() }
        .sheet(isPresented: $showLogin) {
            loginSheet
        }
        .onChange(of: auth.completedSignIns) { _, _ in
            guard wantsExistingAccount else { return }
            Task { await resolveLogin() }
        }
    }

    private var isPanelUp: Bool { panelUp || still }
    private var isContentVisible: Bool { contentVisible || still }

    // MARK: - Mika

    /// Mika, en buste, posé sur le bord haut du panneau. La place est tenue avant son
    /// arrivée : rien ne bouge quand il entre.
    private func mika(width: CGFloat) -> some View {
        let size = min(width * 0.74, 320)
        return ZStack {
            if showsMika || still {
                MikaMascot(
                    mood: still ? .wave : mikaMood,
                    size: size,
                    reactsToTap: true,
                    backdrop: .blue
                ) {
                    // `appear` le sort de derrière le panneau, `wave` fait coucou, puis il
                    // revient au repos de lui-même.
                    if mikaMood == .appear { mikaMood = .wave }
                }
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    // MARK: - Le haut

    /// Le menu de langue, en blanc sur le bleu.
    private var topBar: some View {
        HStack {
            Spacer(minLength: 0)
            LanguageSwitcher(variant: .menu)
                .environment(\.onboardingSurface, .ink)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.sm)
        .opacity(isContentVisible ? 1 : 0)
        .animation(reveal(index: 3), value: isContentVisible)
    }

    // MARK: - Le panneau

    private var panel: some View {
        VStack(spacing: 0) {
            // « Apprends » prend le dégradé de l'app, sur le blanc du panneau.
            OnboardingAccentText(template: i18n.t("ios.hook.title"), size: 36, alignment: .center)
                .padding(.horizontal, MicaboSpacing.md)
                .padding(.top, MicaboSpacing.xl)
                .modifier(HookReveal(isVisible: isContentVisible, animation: reveal(index: 0)))

            VStack(spacing: 12) {
                OnboardingContinueButton(title: i18n.t("ios.hook.next")) {
                    model.advance()
                }

                Button {
                    wantsExistingAccount = true
                    showLogin = true
                } label: {
                    Text(i18n.t("common.alreadyAccount"))
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.gray)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .disabled(auth.isWorking || checkingAccount)
            }
            .padding(.top, MicaboSpacing.lg)
            .modifier(HookReveal(isVisible: isContentVisible, animation: reveal(index: 1)))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, MicaboSpacing.sm)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: MicaboRadius.sheet,
                topTrailingRadius: MicaboRadius.sheet,
                style: .continuous
            )
            .fill(OnboardingPalette.white)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    /// L'entrée d'un élément du panneau : un fondu qui monte, décalé du précédent.
    private func reveal(index: Int) -> Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return .easeOut(duration: 0.45).delay(0.12 + Double(index) * 0.08)
    }

    // MARK: - Le mouvement

    /// **Un seul mouvement, depuis le bleu du lancement.** Une seule fois par lancement :
    /// changer de langue recrée l'écran, et revenir en arrière aussi — l'écran y est alors
    /// posé d'emblée.
    @MainActor
    private func enter() async {
        guard !HookIntro.played, !still else { return }
        HookIntro.played = true

        if reduceMotion {
            mikaMood = .wave
            showsMika = true
            withAnimation(.easeOut(duration: 0.25)) {
                panelUp = true
                contentVisible = true
            }
            return
        }

        // Le temps que la première image soit posée et que le rideau du lancement se lève
        // (`LaunchCurtain`) : jusque-là, l'écran est l'aplat bleu, comme le lancement.
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else {
            panelUp = true
            showsMika = true
            contentVisible = true
            return
        }

        withAnimation(.spring(duration: 0.65, bounce: 0.16)) { panelUp = true }
        try? await Task.sleep(for: .milliseconds(300))

        Haptics.soft()
        showsMika = true
        contentVisible = true
    }

    private var loginSheet: some View {
        SignInScreen(
            placement: .sheet,
            onDismiss: { showLogin = false },
            onCreateAccount: {
                wantsExistingAccount = false
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

    /// **« J'ai déjà un compte », et la connexion a abouti** : le profil du compte remplace
    /// le parcours, le parcours est marqué fini sur cette installation, et l'app s'ouvre sur
    /// les cours du compte, synchronisés.
    ///
    /// La connexion se guette par `completedSignIns` et non par `isSignedIn` : une session
    /// restée dans le trousseau depuis l'installation précédente est déjà ouverte, et se
    /// reconnecter au même compte ne ferait pas changer `isSignedIn`.
    @MainActor
    private func resolveLogin() async {
        guard !checkingAccount else { return }
        let route = LaunchGate.route(
            installMarked: LaunchGate.isInstallMarked(),
            onboardingDoneLocally: OnboardingPreferences.isCompleted,
            hasSession: auth.isSignedIn,
            tappedHaveAccount: wantsExistingAccount
        )
        guard route == .home else { return }
        checkingAccount = true
        _ = await sync.recognizeExistingAccount()
        OnboardingPreferences.markCompleted()
        checkingAccount = false
        wantsExistingAccount = false
        showLogin = false
        await sync.sync(context: modelContext)
    }
}

/// L'entrée du premier écran ne se joue qu'une fois par lancement.
enum HookIntro {
    /// Lu et écrit depuis le fil principal seulement (la vue).
    nonisolated(unsafe) static var played = false
}

/// Un élément du panneau qui se pose : un fondu, et une petite montée.
private struct HookReveal: ViewModifier {
    let isVisible: Bool
    let animation: Animation

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(animation, value: isVisible)
    }
}

// MARK: - La maquette de la première page

/// **Une leçon de l'app, telle qu'elle est aujourd'hui** : son en-tête, son chemin, la barre
/// Notes · Quiz · Flashcards — dessinée avec les composants mêmes du parcours, pas une
/// capture. Elle parle donc la langue choisie sur cette page, et ne vieillit pas quand l'app
/// change.
struct OnboardingHookMockup: View {
    var body: some View {
        OnboardingLessonPhone(fades: true)
    }
}
