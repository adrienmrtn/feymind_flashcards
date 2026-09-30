import SwiftData
import SwiftUI

// MARK: - Le splash, puis la première page

/// **Le premier écran : un splash qui devient une page.**
///
/// Le monogramme arrive seul, au milieu du blanc, poussé par un ressort, avec une onde qui
/// s'élargit derrière lui et le mot qui se resserre dessous ; il se sent se poser. Puis,
/// d'un seul mouvement, il **rapetisse et monte** dans le coin de la page, où il reste, et
/// la page arrive autour : la maquette du téléphone en haut, la phrase, le bouton. C'est
/// le même objet du début à la fin — un logo qui se déplace se lit comme un seul écran, un
/// logo qui disparaît puis réapparaît ailleurs se lit comme deux.
///
/// **La page suit la référence** : une maquette de téléphone qui prend le haut, coupée en
/// fondu, un titre, une ligne, et le bouton. La maquette est une image du catalogue
/// (`OnboardingHookMockup.imageName`), fournie à part ; en attendant, le téléphone dessiné
/// de la fiche tient sa place. Le menu de langue reste en haut à droite.
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
    /// Le logo s'est posé au milieu.
    @State private var hasLanded = false
    /// L'onde derrière le logo, partie.
    @State private var hasRippled = false
    /// Le logo voyage du milieu du splash au coin de la page : même identité, deux places.
    @Namespace private var brand

    /// Le temps du splash, avant que la page ne se pose.
    private static let splashDuration = 1.45

    var body: some View {
        ZStack {
            if isReady {
                page
                    .transition(.opacity)
            } else {
                splash
                    .transition(.opacity)
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

    // MARK: - Le splash

    /// Le monogramme et le mot, seuls. L'onde part du logo et s'efface en s'élargissant :
    /// c'est ce qui fait sentir le logo se poser, sans rien ajouter à la page.
    private var splash: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(OnboardingPalette.accentWash)
                    .frame(width: 128, height: 128)
                    .scaleEffect(hasRippled ? 1.7 : 0.6)
                    .opacity(hasRippled ? 0 : 0.9)

                Circle()
                    .strokeBorder(OnboardingPalette.accent.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 128, height: 128)
                    .scaleEffect(hasRippled ? 2.1 : 0.6)
                    .opacity(hasRippled ? 0 : 0.7)

                MicaboBrandMark(size: 128)
                    .shadow(color: OnboardingPalette.ink.opacity(0.14), radius: 26, y: 12)
                    .matchedGeometryEffect(id: Self.markID, in: brand)
                    .scaleEffect(hasLanded ? 1 : 0.5)
                    .opacity(hasLanded ? 1 : 0)
            }

            Text("Micabo")
                .font(MicaboFont.ui(30, weight: .bold))
                .tracking(hasLanded ? -1 : 8)
                .foregroundStyle(OnboardingPalette.ink)
                .opacity(hasLanded ? 1 : 0)
                .matchedGeometryEffect(id: Self.nameID, in: brand)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    private static let markID = "hook.brand.mark"
    private static let nameID = "hook.brand.name"

    // MARK: - La page

    private var page: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                MicaboBrandMark(size: 30)
                    .matchedGeometryEffect(id: Self.markID, in: brand)

                Text("Micabo")
                    .font(MicaboFont.ui(17, weight: .bold))
                    .tracking(-0.4)
                    .foregroundStyle(OnboardingPalette.ink)
                    .matchedGeometryEffect(id: Self.nameID, in: brand)

                Spacer(minLength: 0)

                LanguageSwitcher(variant: .menu)
                    .onboardingAppear(index: 1)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)

            OnboardingHookMockup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onboardingAppear(index: 2)

            VStack(spacing: 10) {
                Text(i18n.t("ios.hook.title"))
                    .font(OnboardingPalette.title(32))
                    .foregroundStyle(OnboardingPalette.ink)
                    .tracking(-0.9)
                    .lineSpacing(-2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(i18n.t("ios.hook.sub"))
                    .font(MicaboFont.ui(16, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, MicaboSpacing.xl)
            .padding(.top, MicaboSpacing.sm)
            .onboardingAppear(index: 3)

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
                .onboardingAppear(index: 4)
            }
        }
    }

    /// **Le logo se pose, l'onde part, le mot se resserre ; puis le logo monte dans son coin
    /// et la page arrive.** Trois vibrations : une douce quand le logo apparaît, une légère
    /// quand il est posé, un coup quand la page se pose autour.
    @MainActor
    private func land() async {
        if reduceMotion {
            hasLanded = true
            hasRippled = true
            isReady = true
            return
        }

        Haptics.soft()
        withAnimation(.spring(response: 0.62, dampingFraction: 0.68)) { hasLanded = true }
        withAnimation(.easeOut(duration: 1.15)) { hasRippled = true }

        try? await Task.sleep(for: .milliseconds(380))
        guard !Task.isCancelled else { return }
        Haptics.light()

        try? await Task.sleep(for: .seconds(Self.splashDuration - 0.38))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.72, dampingFraction: 0.86)) { isReady = true }

        try? await Task.sleep(for: .milliseconds(520))
        guard !Task.isCancelled else { return }
        Haptics.tick()
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

// MARK: - La maquette de la première page

/// **L'image du catalogue si elle existe, le téléphone dessiné sinon**, coupée en fondu vers
/// le bas comme les maquettes des cinq écrans de fonctionnalités : c'est le titre qui la
/// termine. L'image s'appelle `OnboardingHook`, et se dépose dans `Assets.xcassets`.
struct OnboardingHookMockup: View {
    static let imageName = "OnboardingHook"

    var body: some View {
        Group {
            if UIImage(named: Self.imageName) != nil {
                Image(Self.imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, MicaboSpacing.xxl)
            } else {
                OnboardingPhoneSketch(feature: .sheets)
                    .padding(.horizontal, 64)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, MicaboSpacing.md)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.7),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .accessibilityHidden(true)
    }
}
