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
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            )
                        )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Glissement franc, sans rebond : la courbe s'arrête net à l'arrivée.
                .animation(.timingCurve(0.25, 0.1, 0.25, 1, duration: 0.38), value: model.step)
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
        case .builtByStudents: BuiltByStudentsStepView()
        case .language: LanguageStepView()
        case .personalizeIntro: PersonalizeIntroStepView()
        case .goal: GoalStepView()
        case .forgetting: ForgettingStepView()
        case .retentionChart: RetentionChartStepView()
        case .science: ScienceStepView()
        case .demoImport: DemoImportStepView()
        case .demoWrite: DemoWriteStepView()
        case .demoReview: DemoReviewStepView()
        case .subjects: SubjectsStepView()
        case .school: SchoolStepView()
        case .schoolPeers: SchoolPeersStepView()
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
