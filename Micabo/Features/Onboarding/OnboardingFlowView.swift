import SwiftUI

/// Parcours d'accueil complet. Strictement linéaire : chaque écran pousse le suivant,
/// il n'y a ni retour arrière ni geste de balayage.
struct OnboardingFlowView: View {
    var onFinish: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var model = OnboardingModel()

    private var surface: OnboardingSurface { model.step.surface }

    var body: some View {
        ZStack {
            // Le fond de l'écran monte jusqu'en haut de la zone d'état : la jauge et
            // l'heure du téléphone reposent sur la couleur de l'écran, jamais sur une
            // bande crème rapportée.
            surface.background
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: model.step)

            VStack(spacing: 0) {
                ZStack {
                    stepView
                        .id(model.step)
                        .transition(.onboardingPage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(OnboardingMotion.page, value: model.step)
            }
        }
        .environment(model)
        .environment(\.onboardingSurface, surface)
        .environment(\.locale, i18n.locale.foundation)
        // Sur fond sombre, l'heure et la batterie doivent passer en clair : sinon elles
        // disparaissent dans l'encre.
        .preferredColorScheme(surface.isDark ? .dark : .light)
        .onAppear {
            Haptics.prepare()
            Analytics.track(.onboardingStarted)
            Analytics.track(.onboardingStep, [
                "step": .text(model.step.analyticsName),
                "index": .number(Double(model.step.rawValue)),
            ])
        }
        // Chaque écran atteint, avec son rang : c'est de ces lignes que se tire
        // l'entonnoir, et le rang voyage avec pour que le serveur n'ait pas à tenir une
        // copie de l'ordre des écrans.
        .onChange(of: model.step) { _, step in
            Analytics.track(.onboardingStep, [
                "step": .text(step.analyticsName),
                "index": .number(Double(step.rawValue)),
            ])
        }
    }

    @ViewBuilder
    private var stepView: some View {
        switch model.step {
        case .howItWorks: WelcomeStepView()
        case .upload: UploadStepView()
        case .dates: DatesStepView()
        case .turnsInto: TurnsIntoStepView()
        case .smartFeatures: SmartFeaturesStepView()
        case .name: NameStepView()
        case .greeting: GreetingStepView()
        case .country: CountryStepView()
        case .schoolType: SchoolTypeStepView()
        case .year: SchoolYearStepView()
        case .goal: GoalStepView()
        case .currentAverage: CurrentAverageStepView()
        case .targetAverage: TargetAverageStepView()
        case .together: TogetherStepView()
        case .notifications: NotificationsStepView()
        case .subjects: SubjectsStepView()
        case .personalizing: PersonalizingStepView()
        case .signIn: SignInStepView()
        case .socialProof: SocialProofStepView()
        case .yourTurn: YourTurnStepView()
        case .trialOffer: TrialOfferStepView()
        case .trialReminder: TrialReminderStepView()
        case .paywall: PaywallStepView(onFinish: finish)
        }
    }

    private func finish() {
        Analytics.track(.onboardingFinished)
        OnboardingPreferences.markCompleted()
        onFinish()
    }
}

extension AnyTransition {
    /// Passage d'un écran au suivant : un glissement de vingt-huit points et un fondu.
    ///
    /// Pas un glissement pleine largeur. Faire traverser tout l'écran à une page donne
    /// l'impression de feuilleter un carrousel, ça attire l'œil sur le mouvement au lieu du
    /// contenu, et sur vingt écrans ça fatigue. Un décalage court suffit à dire « on
    /// avance », et le fondu fait le reste.
    static var onboardingPage: AnyTransition {
        .asymmetric(
            insertion: .offset(x: 28).combined(with: .opacity),
            removal: .offset(x: -28).combined(with: .opacity)
        )
    }
}
