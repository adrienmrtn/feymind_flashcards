import SwiftData
import SwiftUI

// MARK: - Le splash, puis la première page

/// **Le premier écran : un splash simple, puis une page.**
///
/// Le monogramme et le mot apparaissent au milieu du blanc, en fondu, un peu plus grands
/// qu'à l'arrivée pour se poser ; ils tiennent une seconde ; puis le splash s'efface et la
/// page prend sa place, en fondu elle aussi. Rien ne voyage, rien ne se transforme : un
/// logo qui traverse l'écran pour aller se ranger dans un coin attire l'œil sur lui-même,
/// et c'est la page qu'on veut regarder.
///
/// **La page** : le nom en haut, centré ; la maquette du téléphone au milieu ; un titre en
/// gros, une ligne dessous ; le bouton, en pilule, centré. La maquette est une image du
/// catalogue (`OnboardingHookMockup.imageName`), fournie à part ; en attendant, le téléphone
/// dessiné de la fiche tient sa place. Le menu de langue reste en haut à droite.
///
/// C'est aussi le seul écran qui porte une sortie : « j'ai déjà un compte ». Quelqu'un qui
/// réinstalle l'app n'a aucune raison de traverser trente écrans pour retrouver ses decks.
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

    /// Le temps du splash, avant que la page ne se pose.
    private static let splashDuration = 1.4

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

    /// Le monogramme et le mot, seuls, qui se posent en fondu.
    private var splash: some View {
        VStack(spacing: 18) {
            MicaboBrandMark(size: 120)
                .shadow(color: OnboardingPalette.ink.opacity(0.12), radius: 24, y: 12)

            Text("Micabo")
                .font(MicaboFont.ui(30, weight: .bold))
                .tracking(-1)
                .foregroundStyle(OnboardingPalette.ink)
        }
        .scaleEffect(hasLanded ? 1 : 1.08)
        .opacity(hasLanded ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    // MARK: - La page

    private var page: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 8) {
                    MicaboBrandMark(size: 26)
                    Text("Micabo")
                        .font(MicaboFont.ui(24, weight: .bold))
                        .tracking(-0.8)
                        .foregroundStyle(OnboardingPalette.ink)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Micabo")

                HStack {
                    Spacer(minLength: 0)
                    LanguageSwitcher(variant: .menu)
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
            .onboardingAppear(index: 1)

            OnboardingHookMockup()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, MicaboSpacing.lg)
                .onboardingAppear(index: 2)

            VStack(spacing: 12) {
                Text(i18n.t("ios.hook.title"))
                    .font(OnboardingPalette.title(36))
                    .foregroundStyle(OnboardingPalette.ink)
                    .tracking(-1.1)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(i18n.t("ios.hook.sub"))
                    .font(MicaboFont.ui(17, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, MicaboSpacing.xl)
            .onboardingAppear(index: 3)

            Spacer(minLength: MicaboSpacing.lg)
                .frame(maxHeight: MicaboSpacing.xxl)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 14) {
                    // La pilule, centrée et pas pleine largeur : c'est la seule page où
                    // le bouton est un objet au milieu de la composition et non une barre.
                    OnboardingContinueButton(title: i18n.t("ios.hook.next")) {
                        model.advance()
                    }
                    .frame(width: 168)

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
                }
                .onboardingAppear(index: 4)
            }
        }
    }

    /// **Le logo se pose, tient, puis la page arrive.** Deux vibrations : une douce quand
    /// le logo apparaît, un coup quand la page se pose.
    @MainActor
    private func land() async {
        if reduceMotion {
            hasLanded = true
            isReady = true
            return
        }

        Haptics.soft()
        withAnimation(.easeOut(duration: 0.7)) { hasLanded = true }

        try? await Task.sleep(for: .seconds(Self.splashDuration))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.55)) { isReady = true }

        try? await Task.sleep(for: .milliseconds(450))
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

/// **L'image du catalogue si elle existe, le téléphone dessiné sinon**, entière, centrée.
/// L'image s'appelle `OnboardingHook`, et se dépose dans `Assets.xcassets`.
struct OnboardingHookMockup: View {
    static let imageName = "OnboardingHook"

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La capture dans la langue choisie (`OnboardingHook-fr`…), sinon l'anglaise. La langue
    /// se change sur cette page même : la maquette suit.
    private var imageName: String? {
        let localized = "\(Self.imageName)-\(i18n.locale.rawValue)"
        if UIImage(named: localized) != nil { return localized }
        return UIImage(named: Self.imageName) != nil ? Self.imageName : nil
    }

    var body: some View {
        Group {
            if let imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                OnboardingPhoneSketch(feature: .sheets)
                    .aspectRatio(0.49, contentMode: .fit)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 72)
        .accessibilityHidden(true)
    }
}
