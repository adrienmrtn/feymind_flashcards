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

// MARK: - L'accroche : la note

/// **« Rejoins plus de 100 000 élèves qui apprennent grâce à Micabo. »** La phrase en
/// titre, puis le chiffre en très grand, les cinq étoiles, et trois visages en initiales.
/// Rien d'autre : le titre dit déjà combien ils sont.
///
/// Les chiffres viennent de `OnboardingProofFigures` : ils sont provisoires, et ils sont
/// tous au même endroit pour être remplacés d'un coup par les vrais.
struct HookRatingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.hook.rating.title", [
                "n": OnboardingProofFigures.text(OnboardingProofFigures.students, locale: i18n.locale),
            ]),
            scrolls: false,
            expandsContent: true,
            centered: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    // Pas d'interlettrage négatif : il rognait le dernier chiffre à droite.
                    Text(OnboardingProofFigures.text(OnboardingProofFigures.rating, locale: i18n.locale))
                        .font(MicaboFont.ui(112, weight: .bold))
                        .foregroundStyle(OnboardingPalette.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 8)

                    OnboardingStars(size: 26)

                    OnboardingAvatarRow()
                        .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

// MARK: - Les briques

/// Cinq étoiles, or.
struct OnboardingStars: View {
    var size: CGFloat = 14
    var spacing: CGFloat = 4

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<5, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .font(.system(size: size))
                    .foregroundStyle(OnboardingPalette.star)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(i18n.t("ios.starsA11y"))
    }
}

/// Trois ronds d'initiales qui se chevauchent.
struct OnboardingAvatarRow: View {
    private static let initials = ["L", "M", "S"]
    private static let tints: [Color] = [
        Color(hex: 0x6D28FF), Color(hex: 0x0A0A0A), Color(hex: 0xA78BFA)
    ]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(Self.initials.enumerated()), id: \.offset) { index, initial in
                Text(initial)
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(OnboardingPalette.white)
                    .frame(width: 34, height: 34)
                    .background(Self.tints[index % Self.tints.count], in: Circle())
                    .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}
