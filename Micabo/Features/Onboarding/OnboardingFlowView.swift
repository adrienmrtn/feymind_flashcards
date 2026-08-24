import SwiftUI

/// Parcours d'accueil complet. Strictement linéaire : chaque écran pousse le suivant,
/// il n'y a ni retour arrière ni geste de balayage.
struct OnboardingFlowView: View {
    var onFinish: () -> Void

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
                OnboardingProgressBar(step: model.step)

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
        // Sur fond sombre, l'heure et la batterie doivent passer en clair : sinon elles
        // disparaissent dans l'encre.
        .preferredColorScheme(surface.isDark ? .dark : .light)
        .onAppear { Haptics.prepare() }
    }

    @ViewBuilder
    private var stepView: some View {
        switch model.step {
        case .welcome: WelcomeStepView()
        case .level: LevelStepView()
        case .language: LanguageStepView()
        case .personalizeIntro: PersonalizeIntroStepView()
        case .goal: GoalStepView()
        case .forgetting: ForgettingStepView()
        case .retentionChart: RetentionChartStepView()
        case .demoImport: DemoImportStepView()
        case .demoSheet: DemoSheetStepView()
        case .demoReview: DemoReviewStepView()
        case .examPromise: ExamPromiseStepView()
        case .subjects: SubjectsStepView()
        case .school: SchoolStepView()
        case .dailyTime: DailyTimeStepView()
        case .projection: ProjectionStepView()
        case .notifications: NotificationsStepView()
        case .personalizing: PersonalizingStepView()
        case .trialOffer: TrialOfferStepView()
        case .trialReminder: TrialReminderStepView()
        case .paywall: PaywallStepView(onFinish: finish)
        }
    }

    private func finish() {
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

/// Jauge fine en haut de l'écran, présente du premier écran au dernier.
///
/// Elle garde l'indigo de la progression partout où le fond est clair, et s'inverse sur
/// les écrans sombres : c'est la lisibilité qui décide, pas l'écran.
private struct OnboardingProgressBar: View {
    let step: OnboardingStep

    private var surface: OnboardingSurface { step.surface }

    var body: some View {
        MicaboProgressBar(progress: step.progress, tint: surface.progressTint, track: surface.progressTrack)
            .frame(height: 4)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboSpacing.xs)
            .animation(.easeInOut(duration: 0.38), value: step)
            .accessibilityLabel("Progression du parcours")
            .accessibilityValue("\(Int(step.progress * 100)) %")
    }
}
