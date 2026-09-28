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

            Spacer(minLength: MicaboSpacing.sm)

            OnboardingPhoneMockup()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .onboardingAppear(index: 1)

            Spacer(minLength: MicaboSpacing.md)

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

/// **Un téléphone incliné, et une vraie fiche qui se déroule dedans.**
///
/// Le cadre est noir, l'écran est blanc, et ce qui défile est une fiche telle que l'app la
/// compose, **avec ses vrais mots** : un chapitre, un titre, un paragraphe avec son
/// passage surligné, un encadré, un graphe, une carte. Le texte est traduit : la fiche
/// suit la langue choisie dans le menu du haut, comme le reste de l'écran. Elle monte
/// lentement et recommence, sans à-coup : c'est le geste d'un écran qu'on fait défiler.
struct OnboardingPhoneMockup: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var scrolled = false

    private static let width: CGFloat = 250
    private static let height: CGFloat = 500

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 42, style: .continuous)
                .fill(OnboardingPalette.ink)

            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(OnboardingPalette.white)
                .padding(8)
                .overlay {
                    screen
                        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
                        .padding(8)
                }

            // L'encoche, pour qu'on lise un téléphone et pas une carte.
            VStack {
                Capsule()
                    .fill(OnboardingPalette.ink)
                    .frame(width: 74, height: 22)
                    .padding(.top, 16)
                Spacer(minLength: 0)
            }
        }
        .frame(width: Self.width, height: Self.height)
        .rotationEffect(.degrees(-5))
        .rotation3DEffect(.degrees(7), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .shadow(color: OnboardingPalette.ink.opacity(0.18), radius: 30, y: 18)
        .accessibilityHidden(true)
        .onAppear(perform: start)
        // Changer de langue recompose la fiche : on repart du haut.
        .id(i18n.locale)
    }

    /// La fiche, deux fois de suite, et la seconde copie prend la place de la première
    /// quand le défilement arrive au bout : la boucle ne se voit pas.
    private var screen: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                sheet
                sheet
            }
            .frame(width: proxy.size.width)
            .background {
                // La hauteur d'une fiche décide de la course : on la mesure sur la
                // première copie, et la seconde vient exactement la remplacer.
                GeometryReader { inner in
                    Color.clear.preference(key: SheetHeightKey.self, value: inner.size.height / 2)
                }
            }
            .offset(y: scrolled ? -sheetHeight : 0)
        }
        .onPreferenceChange(SheetHeightKey.self) { sheetHeight = $0 }
    }

    @State private var sheetHeight: CGFloat = 600

    private struct SheetHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 600
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    private func t(_ key: String) -> String { i18n.t(key) }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 9) {
            Color.clear.frame(height: 34)

            Text(t("ios.hook.sheet.chapter").uppercased())
                .font(MicaboFont.ui(6.5, weight: .semibold))
                .tracking(1)
                .foregroundStyle(OnboardingPalette.accent)

            Text(t("ios.hook.sheet.title"))
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(OnboardingPalette.ink)
                .tracking(-0.3)
                .fixedSize(horizontal: false, vertical: true)

            paragraph(t("ios.hook.sheet.p1"))

            // Le passage surligné, au marqueur jaune.
            Text(t("ios.hook.sheet.highlight"))
                .font(MicaboFont.reading(8, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .lineSpacing(2)
                .padding(.horizontal, 3)
                .padding(.vertical, 2)
                .background(OnboardingPalette.star.opacity(0.4), in: RoundedRectangle(cornerRadius: 3, style: .continuous))
                .fixedSize(horizontal: false, vertical: true)

            paragraph(t("ios.hook.sheet.p2"))

            // L'encadré « à retenir ».
            VStack(alignment: .leading, spacing: 4) {
                Text(t("ios.hook.sheet.keyLabel").uppercased())
                    .font(MicaboFont.ui(6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(OnboardingPalette.accent)
                Text(t("ios.hook.sheet.key"))
                    .font(MicaboFont.reading(8, weight: .medium))
                    .foregroundStyle(OnboardingPalette.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnboardingPalette.accentWash, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            // La frise : quatre dates.
            VStack(alignment: .leading, spacing: 6) {
                Text(t("ios.hook.sheet.chart").uppercased())
                    .font(MicaboFont.ui(6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(OnboardingPalette.gray)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(1...4, id: \.self) { index in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(index == 3 ? OnboardingPalette.accent : OnboardingPalette.ink)
                                .frame(width: 6, height: 6)
                            Text(t("ios.hook.sheet.date\(index)"))
                                .font(MicaboFont.ui(6, weight: .semibold))
                                .foregroundStyle(OnboardingPalette.ink)
                            Text(t("ios.hook.sheet.event\(index)"))
                                .font(MicaboFont.ui(5.5, weight: .regular))
                                .foregroundStyle(OnboardingPalette.gray)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(alignment: .top) {
                    Rectangle()
                        .fill(OnboardingPalette.cardStrong)
                        .frame(height: 1)
                        .padding(.top, 2.5)
                        .padding(.horizontal, 20)
                }
            }
            .padding(9)
            .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            paragraph(t("ios.hook.sheet.p3"))

            // Une carte de révision, tirée de la fiche.
            VStack(alignment: .leading, spacing: 4) {
                Text(t("ios.hook.sheet.cardLabel").uppercased())
                    .font(MicaboFont.ui(6, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(OnboardingPalette.white.opacity(0.6))
                Text(t("ios.hook.sheet.card"))
                    .font(MicaboFont.ui(8.5, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OnboardingPalette.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            paragraph(t("ios.hook.sheet.p4"))
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.reading(8, weight: .regular))
            .foregroundStyle(OnboardingPalette.ink.opacity(0.8))
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func start() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 16).repeatForever(autoreverses: false)) {
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
