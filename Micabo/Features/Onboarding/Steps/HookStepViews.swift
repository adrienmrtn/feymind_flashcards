import SwiftData
import SwiftUI

// MARK: - L'accroche : le produit en mouvement

/// **Le premier écran : un téléphone incliné qui montre une fiche en train de se
/// dérouler, et quatre mots.**
///
/// C'est l'ouverture de Cal AI et de RIZZ : pas de personnage, pas de promesse, le produit
/// lui-même, en mouvement, sur du blanc. La fiche défile lentement dans le téléphone et
/// recommence ; ce n'est pas une vidéo, c'est la vraie mise en page d'une fiche, dessinée
/// en petit, et c'est pour ça qu'elle ressemble à ce qu'on aura.
///
/// C'est aussi le seul écran qui porte une sortie : « j'ai déjà un compte ». Quelqu'un qui
/// réinstalle l'app n'a aucune raison de traverser trente écrans pour retrouver ses decks.
struct HookVideoStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext

    @State private var showLogin = false
    @State private var checkingAccount = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                LanguageSwitcher(variant: .menu)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
            .onboardingAppear(index: 0)

            Spacer(minLength: MicaboSpacing.md)

            OnboardingPhoneMockup()
                .frame(maxWidth: .infinity)
                .onboardingAppear(index: 1)

            Spacer(minLength: MicaboSpacing.lg)

            Text(i18n.t("ios.hook.title"))
                .font(OnboardingPalette.title(34))
                .foregroundStyle(OnboardingPalette.ink)
                .tracking(-0.9)
                .lineSpacing(-2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MicaboSpacing.screen)
                .onboardingAppear(index: 2)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 12) {
                    OnboardingContinueButton(title: i18n.t("common.start")) {
                        model.advance()
                    }

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
                .onboardingAppear(index: 3)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .sheet(isPresented: $showLogin) {
            loginSheet
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            guard signedIn, showLogin else { return }
            Task { await resolveLogin() }
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

/// **Un téléphone incliné, et une fiche qui se déroule dedans.**
///
/// Le cadre est noir, l'écran est blanc, et ce qui défile est une fiche telle que l'app la
/// compose : un chapitre, un titre, un paragraphe avec son passage surligné, un encadré, un
/// graphe. Elle monte lentement et recommence, sans à-coup : c'est le geste d'un écran qu'on
/// fait défiler, pas d'une animation.
private struct OnboardingPhoneMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scrolled = false

    private static let width: CGFloat = 230
    private static let height: CGFloat = 470

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(OnboardingPalette.ink)

            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(OnboardingPalette.white)
                .padding(8)
                .overlay {
                    screen
                        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .padding(8)
                }

            // L'encoche, pour qu'on lise un téléphone et pas une carte.
            VStack {
                Capsule()
                    .fill(OnboardingPalette.ink)
                    .frame(width: 70, height: 20)
                    .padding(.top, 14)
                Spacer(minLength: 0)
            }
        }
        .frame(width: Self.width, height: Self.height)
        .rotationEffect(.degrees(-6))
        .rotation3DEffect(.degrees(8), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .shadow(color: OnboardingPalette.ink.opacity(0.18), radius: 30, y: 18)
        .accessibilityHidden(true)
        .onAppear(perform: start)
    }

    /// La fiche, deux fois de suite, et la seconde copie prend la place de la première
    /// quand le défilement arrive au bout : la boucle ne se voit pas.
    private var screen: some View {
        GeometryReader { proxy in
            let travel = proxy.size.height * 1.05
            VStack(spacing: 0) {
                sheet
                sheet
            }
            .frame(width: proxy.size.width)
            .offset(y: scrolled ? -travel : 0)
        }
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.clear.frame(height: 30)

            Text("CHAPITRE 2 · 21 CARTES")
                .font(MicaboFont.ui(6.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(OnboardingPalette.accent)

            Text("La guerre froide, 1947–1991")
                .font(MicaboFont.ui(13, weight: .bold))
                .foregroundStyle(OnboardingPalette.ink)
                .tracking(-0.3)

            paragraph(lines: 3)

            // Le passage surligné.
            VStack(alignment: .leading, spacing: 4) {
                line(width: 0.92, highlighted: true)
                line(width: 0.7, highlighted: true)
            }

            paragraph(lines: 2)

            // L'encadré « à retenir ».
            VStack(alignment: .leading, spacing: 5) {
                Text("À RETENIR")
                    .font(MicaboFont.ui(6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(OnboardingPalette.accent)
                line(width: 0.85)
                line(width: 0.6)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnboardingPalette.accentWash, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            paragraph(lines: 3)

            // Un graphe : quatre barres.
            HStack(alignment: .bottom, spacing: 8) {
                ForEach([0.35, 0.6, 0.45, 0.9], id: \.self) { height in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(height > 0.8 ? OnboardingPalette.accent : OnboardingPalette.cardStrong)
                        .frame(height: 46 * height)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 46)
            .padding(8)
            .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            paragraph(lines: 4)

            // Une carte de révision.
            VStack(alignment: .leading, spacing: 5) {
                Text("QUESTION")
                    .font(MicaboFont.ui(6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(OnboardingPalette.white.opacity(0.6))
                line(width: 0.8, color: OnboardingPalette.white.opacity(0.85))
                line(width: 0.5, color: OnboardingPalette.white.opacity(0.85))
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnboardingPalette.ink, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            paragraph(lines: 3)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
    }

    private func paragraph(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<lines, id: \.self) { index in
                line(width: index == lines - 1 ? 0.55 : [0.95, 0.88, 0.97][index % 3])
            }
        }
    }

    private func line(width: CGFloat, highlighted: Bool = false, color: Color? = nil) -> some View {
        GeometryReader { proxy in
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color ?? (highlighted ? OnboardingPalette.star.opacity(0.55) : OnboardingPalette.cardStrong))
                .frame(width: proxy.size.width * width, height: 5)
        }
        .frame(height: 5)
    }

    private func start() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
            scrolled = true
        }
    }
}

// MARK: - L'accroche : la note

/// **« Noté 4,8 par 12 000 élèves. »** Le chiffre en très grand, les cinq étoiles, et trois
/// visages en initiales. C'est l'écran « rejoins 10 millions de personnes » de Cal AI,
/// réduit à ce qu'on peut affirmer.
///
/// Les chiffres viennent de `OnboardingProofFigures` : ils sont provisoires, et ils sont
/// tous au même endroit pour être remplacés d'un coup par les vrais.
struct HookRatingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.hook.rating.title", [
                "rating": OnboardingProofFigures.text(OnboardingProofFigures.rating, locale: i18n.locale),
                "n": OnboardingProofFigures.text(OnboardingProofFigures.reviews, locale: i18n.locale),
            ]),
            subtitle: i18n.t("ios.hook.rating.sub", ["n": OnboardingProofFigures.text(OnboardingProofFigures.reviews, locale: i18n.locale)]),
            scrolls: false,
            expandsContent: true,
            centered: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 18) {
                    Text(OnboardingProofFigures.text(OnboardingProofFigures.rating, locale: i18n.locale))
                        .font(MicaboFont.ui(112, weight: .bold))
                        .foregroundStyle(OnboardingPalette.ink)
                        .tracking(-6)
                        .monospacedDigit()

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

// MARK: - L'accroche : où on l'a vu

/// **« Tu nous as peut-être déjà vus. »** Quatre noms en gras, ceux des endroits où
/// Micabo circule. C'est l'écran « as featured on » de RIZZ : des logos en colonne sur
/// fond uni, et rien d'autre.
///
/// Ce sont des noms écrits, pas des logos : les marques ont des règles d'usage, et un logo
/// redessiné à la main se reconnaît comme faux au premier regard.
struct HookPressStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let names = ["TikTok", "Instagram", "YouTube", "Snapchat"]

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.hook.press.title"),
            scrolls: false,
            expandsContent: true,
            centered: true
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 26) {
                    Text(i18n.t("ios.hook.press.seenOn").uppercased())
                        .font(MicaboFont.ui(12, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(OnboardingPalette.gray)

                    ForEach(Array(Self.names.enumerated()), id: \.offset) { index, name in
                        Text(name)
                            .font(MicaboFont.ui(38, weight: .bold))
                            .foregroundStyle(OnboardingPalette.ink)
                            .tracking(-1.2)
                            .onboardingAppear(index: 4 + index, stagger: 0.08)
                    }

                    Text(i18n.t("ios.hook.press.more"))
                        .font(MicaboFont.ui(14, weight: .medium))
                        .foregroundStyle(OnboardingPalette.grayLight)
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

/// Trois ronds d'initiales qui se chevauchent, et le nombre d'élèves derrière.
struct OnboardingAvatarRow: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let initials = ["L", "M", "S"]
    private static let tints: [Color] = [
        Color(hex: 0x6D28FF), Color(hex: 0x0A0A0A), Color(hex: 0xA78BFA)
    ]

    var body: some View {
        HStack(spacing: 10) {
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

            Text(i18n.t("ios.hook.rating.students", ["n": OnboardingProofFigures.text(OnboardingProofFigures.students, locale: i18n.locale)]))
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(OnboardingPalette.gray)
        }
        .accessibilityElement(children: .combine)
    }
}
