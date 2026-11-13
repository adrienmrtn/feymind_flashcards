import SwiftData
import SwiftUI

/// Le parcours d'accueil. **Une seule pile d'étapes, et une poussée native entre deux pages.**
///
/// - **La page glisse, la barre du haut ne bouge pas.** Le retour et la jauge sont posés
///   par-dessus la pile, hors de la transition : quand une page arrive par le bord de fin et
///   que l'ancienne part par le bord de début (l'inverse au retour, et en arabe), la jauge
///   avance d'un cran sur place.
/// - **Rien n'attend.** Pas de page posée hors champ puis animée au tour suivant, pas de
///   délai avant un contenu ni avant un bouton : l'étape change sous la courbe standard de
///   l'app (`OnboardingModel.move`), et la transition fait le reste. « Réduire les
///   animations » donne un fondu.
/// - **Le clavier ne déplace rien.** Le parcours l'ignore : les pages qui tapent du texte
///   sont composées pour lui (`OnbKeyboardRoom`), et aucun pied de page ne monte ni ne
///   redescend pendant qu'une page glisse.
/// - **Il reprend où il s'est arrêté** : une app fermée pendant le parcours repart de l'écran
///   quitté, réponses comprises (`OnboardingModel.resuming(in:)`).
struct OnboardingFlowView: View {
    var onFinish: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(AuthController.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: OnboardingModel

    private let library: ModelContext

    init(library: ModelContext, onFinish: @escaping () -> Void) {
        self.library = library
        self.onFinish = onFinish
        let model = OnboardingModel.resuming(in: library)
        model.animatesTransitions = true
        _model = State(initialValue: model)
    }

    var body: some View {
        ZStack(alignment: .top) {
            V3Color.bg
                .ignoresSafeArea()

            // La pile : la page de l'étape, et rien d'autre. Changer d'étape retire l'une et
            // pose l'autre ; la transition les fait glisser.
            ZStack {
                ForEach([model.step], id: \.self) { step in
                    OnboardingStepScreen(step: step, onFinish: finish)
                        .transition(push)
                }
            }

            OnboardingTopBar(model: model)
        }
        .ignoresSafeArea(.keyboard)
        .environment(model)
        .environment(\.locale, i18n.locale.foundation)
        .environment(\.layoutDirection, i18n.locale.isRightToLeft ? .rightToLeft : .leftToRight)
        // **Le compte, en languette**, posée en quittant le plan révélé : le parcours ne
        // change pas de page pour le demander. Balayée vers le bas, elle se referme sans
        // répondre, et le bouton la rouvre.
        .sheet(isPresented: Binding(
            get: { model.isAccountSheetPresented },
            set: { model.isAccountSheetPresented = $0 }
        )) {
            OnboardingAccountSheet { model.finishAccountSheet() }
                .environment(\.locale, i18n.locale.foundation)
                .environment(\.layoutDirection, i18n.locale.isRightToLeft ? .rightToLeft : .leftToRight)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(V3Color.bg)
        }
        .onChange(of: auth.isSignedIn, initial: true) { _, isSignedIn in
            model.hasAccount = isSignedIn
        }
        .onChange(of: model.step) { _, next in
            track(next)
        }
        .onAppear {
            Haptics.prepare()
            Analytics.track(.onboardingStarted, model.isResumed ? ["resumed": .flag(true)] : [:])
            track(model.step)
        }
    }

    /// La poussée latérale, ou un fondu quand le mouvement est réduit.
    private var push: AnyTransition {
        reduceMotion ? .opacity : AnyTransition(OnboardingPush(model: model))
    }

    private func track(_ step: OnboardingStep) {
        Analytics.track(.onboardingStep, [
            "step": .text(step.analyticsName),
            "index": .number(Double(step.rawValue)),
        ])
    }

    private func finish() {
        Analytics.track(.onboardingFinished)
        // Avant le drapeau : dès qu'il est posé, une synchro peut relire le profil du
        // serveur, et ce sont les réponses qu'on vient de donner qui doivent gagner.
        CloudSync.noteOnboardingAnswers()
        OnboardingPreferences.markCompleted()
        // L'app s'ouvre sur Home, qui lance la première leçon choisie (`FirstLessonIntent`).
        OnboardingPreferences.pendingFirstImport = false
        // L'examen choisi devient un examen du Calendrier, et ses rappels suivent.
        if OnboardingExamPlacement.placeIfNeeded(in: library) != nil {
            StudyNotifications.refresh(in: library)
        }
        onFinish()
    }
}

// MARK: - La poussée

/// **La poussée latérale d'une page** : en avançant, la page arrive par le bord de fin et
/// l'ancienne part par le bord de début ; au retour, l'inverse. Les bords sont ceux de la
/// langue : en arabe, tout se joue dans l'autre sens.
///
/// Le sens est lu sur le modèle **au moment où la transition se joue**, pas quand la page a
/// été posée : une page arrivée en avançant doit pouvoir repartir par le même bord si l'élève
/// revient en arrière. Le mouvement lui-même est celui du système (`MoveTransition`).
struct OnboardingPush: Transition {
    let model: OnboardingModel

    func body(content: Content, phase: TransitionPhase) -> some View {
        let entering = phase == .willAppear
        let edge: Edge = entering == model.isMovingForward ? .trailing : .leading
        MoveTransition(edge: edge).apply(content: content, phase: phase)
    }
}

// MARK: - La barre du haut

/// **Le retour et la jauge, fixes au-dessus des pages.** La barre est celle du système
/// visuel (`V3TopBar`) ; ici, seulement ce que l'étape en fait : la jauge avance, le chevron
/// part des écrans d'où l'on ne revient pas, « Passer » se pose à droite de la seule question
/// facultative, et la barre s'efface des écrans qui sont un moment à eux seuls.
struct OnboardingTopBar: View {
    let model: OnboardingModel

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La hauteur que les pages lui laissent.
    static let height: CGFloat = 44

    var body: some View {
        let step = model.step
        HStack(spacing: 14) {
            if model.canGoBack {
                Button {
                    model.goBack()
                } label: {
                    Image(systemName: "arrow.backward")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(V3Color.ink)
                        .frame(width: V3Metric.backSize, height: V3Metric.backSize)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(i18n.t("app.common.back")))
            }
            // **La jauge, en actes** (lot 12) : un segment par acte, celui en cours se remplit.
            if step.showsProgress {
                V3ActProgress(acts: OnboardingStep.actCount, act: step.act, fraction: step.actFraction)
            } else {
                Spacer(minLength: 0)
            }
            if step.isSkippable {
                Button {
                    model.skipAverages()
                } label: {
                    Text(i18n.t("common.skip"))
                        .font(V3Font.label)
                        .foregroundStyle(V3Color.ink2)
                        .frame(minHeight: Self.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(height: Self.height)
        .opacity(step.showsChrome ? 1 : 0)
        .allowsHitTesting(step.showsChrome)
        .accessibilityHidden(!step.showsChrome)
    }
}

// MARK: - Une page

/// **La page d'une étape**, sous la barre du haut quand l'étape la montre.
struct OnboardingStepScreen: View {
    let step: OnboardingStep
    var onFinish: () -> Void = {}

    var body: some View {
        content
            .padding(.top, step.showsChrome ? OnboardingTopBar.height : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(OnbCompactReader(chrome: step.showsChrome))
            .background(V3Color.bg.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case .hookLogo: StoriesStepView()
        case .welcome: WelcomeStepView()
        case .name: NameStepView()
        case .country: CountryStepView()
        case .level: LevelStepView()
        case .schoolType: SchoolTypeStepView()
        case .year: SchoolYearStepView()
        case .exam: ExamStepView()
        case .subjects: SubjectsStepView()
        case .hardestSubject: HardestSubjectStepView()
        case .goal: GoalStepView()
        case .worries: WorriesStepView()
        case .studyHours: StudyHoursStepView()
        case .studyMethod: StudyMethodStepView()
        case .solutionMap: SolutionMapStepView()
        case .lessonDemo: LessonDemoStepView()
        case .cardsDemo: CardsDemoStepView()
        case .scanDemo: ScanDemoStepView()
        case .chatDemo: ChatDemoStepView()
        case .examDemo: ExamDemoStepView()
        case .sampleCard: SampleCardStepView()
        case .currentAverage: CurrentAverageStepView()
        case .targetAverage: TargetAverageStepView()
        case .startingPoint: StartingPointStepView()
        case .dailyTime: DailyTimeStepView()
        case .planDemo: PlanDemoStepView()
        case .focusDemo: FocusDemoStepView()
        case .notifications: NotificationsStepView()
        case .commitment: CommitmentStepView()
        case .firstLesson: FirstLessonStepView()
        case .planBuilding: PlanBuildingStepView()
        case .profileSummary: ProfileSummaryStepView()
        case .freeTrialIntro: FreeTrialIntroStepView()
        case .trialOffer: TrialOfferStepView()
        case .whyNow: WhyNowStepView()
        case .paywall: PaywallStepView(onFinish: onFinish)
        }
    }
}
