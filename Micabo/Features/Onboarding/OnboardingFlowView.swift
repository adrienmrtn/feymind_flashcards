import SwiftUI

/// Parcours d'accueil complet. Strictement linéaire : chaque écran pousse le suivant au
/// bouton, on revient par la pilule du haut là où c'est permis, et rien ne se feuillette au
/// doigt.
///
/// **La barre du haut ne bouge pas, les pages glissent dessous.** La jauge et la pilule de
/// retour sont posées par-dessus la pile des pages, hors du glissement : quand une page
/// arrive, la jauge avance d'un cran sur place, et c'est ce qui fait lire un seul parcours
/// plutôt qu'une suite d'écrans.
struct OnboardingFlowView: View {
    var onFinish: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(AuthController.self) private var auth
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = OnboardingModel()
    @State private var pager = OnboardingPager(current: .hookLogo)

    private var surface: OnboardingSurface { model.step.surface }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                surface.background
                    .ignoresSafeArea()

                // **Pas de rognage.** Une page qui glisse sort par le bord de l'écran, qui la
                // coupe déjà ; rogner la pile à la zone sûre coupait en plus ce que les pages
                // étendent sous la barre d'état — le bandeau d'un cours s'arrêtait sous elle,
                // avec une bande blanche au-dessus.
                ZStack(alignment: .top) {
                    ForEach(pager.pages, id: \.self) { step in
                        page(for: step, size: proxy.size)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                OnboardingTopBar(
                    progress: model.step.progress,
                    showsBack: model.canGoBack,
                    isVisible: model.step.showsChrome,
                    onBack: { model.goBack() }
                )
            }
            .onChange(of: model.step) { previous, next in
                slide(from: previous, to: next, width: proxy.size.width)
            }
        }
        // **Le clavier ne redimensionne pas les pages.** Laissé au système, il rétrécissait
        // la pile à son arrivée et la rallongeait à son départ : la page du prénom changeait
        // de forme à l'appui, avant même que la suivante ne glisse. Chaque page qui prend
        // le clavier lève son pied elle-même (`OnboardingKeyboardLift`).
        .ignoresSafeArea(.keyboard)
        .environment(model)
        .environment(\.onboardingSurface, surface)
        .environment(\.locale, i18n.locale.foundation)
        .preferredColorScheme(.light)
        // **Le compte, en languette**, posée sur l'annonce de la fiche : le parcours ne
        // change pas de page pour le demander. Balayée vers le bas, elle se referme sans
        // répondre, et la flèche la rouvre.
        .sheet(isPresented: Binding(
            get: { model.isAccountSheetPresented },
            set: { model.isAccountSheetPresented = $0 }
        )) {
            OnboardingAccountSheet { model.finishAccountSheet() }
                .environment(\.locale, i18n.locale.foundation)
                .presentationDetents([.height(480), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
                .presentationBackground(OnboardingPalette.white)
                .preferredColorScheme(.light)
        }
        .onChange(of: auth.isSignedIn, initial: true) { _, isSignedIn in
            model.hasAccount = isSignedIn
        }
        .onAppear {
            Haptics.prepare()
            Analytics.track(.onboardingStarted)
            Analytics.track(.onboardingStep, [
                "step": .text(model.step.analyticsName),
                "index": .number(Double(model.step.rawValue)),
            ])
        }
    }

    /// Une page de la pile : l'écran de l'étape, à la taille de l'écran, décalé par le
    /// glissement en cours. Pendant qu'une page glisse, aucune des deux ne répond au doigt.
    private func page(for step: OnboardingStep, size: CGSize) -> some View {
        stepView(step)
            .environment(\.onboardingStep, step)
            .frame(width: size.width, height: size.height)
            .overlay {
                OnboardingPalette.ink
                    .opacity(pager.veilOpacity(for: step))
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .opacity(pager.opacity(for: step))
            .offset(x: pager.offset(for: step))
            .allowsHitTesting(step == pager.current && pager.outgoing == nil)
    }

    // MARK: - Le glissement

    /// **Chaque changement d'étape est un glissement**, et il se joue en deux temps : la
    /// nouvelle page est d'abord posée hors champ, puis, au tour de boucle suivant, les deux
    /// pages sont animées vers leur place. Poser et animer dans le même tour ne glisserait
    /// rien : la nouvelle page n'aurait jamais été vue ailleurs qu'à l'arrivée.
    ///
    /// Le verrou du modèle tient le temps du glissement : un second appui pendant qu'une
    /// page arrive n'en empile pas une troisième.
    private func slide(from previous: OnboardingStep, to next: OnboardingStep, width: CGFloat) {
        Analytics.track(.onboardingStep, [
            "step": .text(next.analyticsName),
            "index": .number(Double(next.rawValue)),
        ])

        let forward = next.rawValue > previous.rawValue
        let duration = reduceMotion ? 0.25 : OnboardingMotion.slideDuration
        model.transitionLock = true

        var staged = OnboardingPager(current: next)
        staged.outgoing = previous
        staged.direction = forward ? .forward : .backward
        if reduceMotion {
            staged.currentOpacity = 0
        } else {
            staged.currentOffset = forward ? width : -width * OnboardingMotion.slideParallax
            staged.veil = forward ? 0 : OnboardingMotion.slideVeil
        }
        pager = staged

        DispatchQueue.main.async {
            if reduceMotion {
                withAnimation(.easeInOut(duration: duration)) {
                    pager.currentOpacity = 1
                }
            } else {
                withAnimation(OnboardingMotion.slide) {
                    pager.currentOffset = 0
                    pager.outgoingOffset = forward ? -width * OnboardingMotion.slideParallax : width
                    pager.veil = forward ? OnboardingMotion.slideVeil : 0
                }
            }
        }

        // **La page qui se pose se sent**, aux trois quarts du glissement, quand elle
        // freine : c'est l'atterrissage, pas le départ.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration * 0.75) {
            Haptics.tick()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.03) {
            if pager.current == next {
                pager.outgoing = nil
                pager.veil = 0
                pager.currentOpacity = 1
            }
            model.transitionLock = false
        }
    }

    // MARK: - Les écrans

    @ViewBuilder
    private func stepView(_ step: OnboardingStep) -> some View {
        switch step {
        case .hookLogo: HookLogoStepView()
        case .name: NameStepView()
        case .welcome: WelcomeStepView()
        case .country: CountryStepView()
        case .level: LevelStepView()
        case .schoolType: SchoolTypeStepView()
        case .year: SchoolYearStepView()
        case .subjects: SubjectsStepView()
        case .worries: WorriesStepView()
        case .goal: GoalStepView()
        case .proofRetention: ProofRetentionStepView()
        case .currentAverage: CurrentAverageStepView()
        case .targetAverage: TargetAverageStepView()
        case .dailyTime: DailyTimeStepView()
        case .studyTime: StudyTimeStepView()
        case .notifications: NotificationsStepView()
        case .building: BuildingStepView()
        case .featuresIntro: MikaSpeaksStepView(text: i18n.t("ios.onb.features.intro"))
        case .featureSheets: FeatureStepView(feature: .sheets)
        case .featurePlan: FeatureStepView(feature: .plan)
        case .featureCards: FeatureStepView(feature: .cards)
        case .featurePocket: FeatureStepView(feature: .pocket)
        case .featureMika: FeatureStepView(feature: .mika)
        case .sheetIntro: MikaSpeaksStepView(text: i18n.t("ios.onb.sheetIntro"))
        case .materials: OnboardingMaterialsStepView()
        case .demoCourse: DemoCourseStepView()
        case .courseBuilding: CourseBuildingStepView()
        case .courseReview: CourseReviewStepView()
        case .trainPrompt: TrainPromptStepView()
        case .trainCards: TrainCardsStepView()
        case .wellDone: WellDoneStepView()
        case .socialProof: SocialProofStepView()
        case .trialOffer: TrialOfferStepView()
        case .trialReminder: TrialReminderStepView()
        case .paywall: PaywallStepView(onFinish: finish)
        }
    }

    private func finish() {
        Analytics.track(.onboardingFinished)
        OnboardingPreferences.markCompleted()
        if let course = model.builtCourse {
            // **Le cours du parcours est le premier cours de l'app.** Il est déjà dans la
            // bibliothèque ; l'app s'ouvre sur Decks, où il attend en tête — sans s'ouvrir
            // de lui-même : l'élève vient de le parcourir.
            FirstDeckHandoff.course = course
        }
        // Sans cours construit — la construction a raté et l'élève a continué —, l'app
        // s'ouvre sur Decks vide, dont la tuile « importer un deck » fait le même travail
        // que « créons ton premier cours ». Ce dernier écran n'a pas de croix, et générer
        // un cours est dans Pro : quelqu'un qui n'a pas pris l'abonnement y resterait
        // enfermé.
        OnboardingPreferences.pendingFirstImport = false
        onFinish()
    }
}

extension OnboardingMotion {
    /// Le voile posé sur la page qui recule sous la nouvelle : six centièmes, juste ce
    /// qu'il faut pour qu'elle se lise dessous.
    static let slideVeil: Double = 0.06
}

extension AnyTransition {
    /// **Un fondu, pour ce qui change à l'intérieur d'un écran** — les étapes d'un deck qui
    /// se crée, les deux paywalls. Le glissement est réservé aux pages du parcours, et il
    /// n'est pas une transition : voir `OnboardingPager`.
    static var onboardingFade: AnyTransition {
        .opacity
    }
}
