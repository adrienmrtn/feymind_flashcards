import SwiftUI

/// Parcours d'accueil complet. Strictement linéaire : chaque écran pousse le suivant,
/// il n'y a ni retour arrière ni geste de balayage.
struct OnboardingFlowView: View {
    var onFinish: () -> Void

    @State private var model = OnboardingModel()

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()

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
                .animation(.spring(response: 0.5, dampingFraction: 0.88), value: model.step)
            }
        }
        .environment(model)
        .preferredColorScheme(.light)
        .onAppear(perform: Haptics.prepare)
    }

    @ViewBuilder
    private var stepView: some View {
        switch model.step {
        case .welcome: WelcomeStepView()
        case .language: LanguageStepView()
        case .personalizeIntro: PersonalizeIntroStepView()
        case .goal: GoalStepView()
        case .forgetting: ForgettingStepView()
        case .retentionChart: RetentionChartStepView()
        case .science: ScienceStepView()
        case .demoImport: DemoImportStepView()
        case .demoWrite: DemoWriteStepView()
        case .demoReview: DemoReviewStepView()
        case .video: VideoStepView()
        case .generatedCards: GeneratedCardsStepView()
        case .subjects: SubjectsStepView()
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

/// Jauge fine en haut de l'écran, masquée sur les écrans d'accroche.
private struct OnboardingProgressBar: View {
    let step: OnboardingStep

    var body: some View {
        MicaboProgressBar(
            progress: step.showsProgress ? step.progress : 0,
            tint: MicaboColor.ink,
            track: MicaboColor.surfaceSunken
        )
        .frame(height: 4)
        .opacity(step.showsProgress ? 1 : 0)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.xs)
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: step)
    }
}
