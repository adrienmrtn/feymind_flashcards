import SwiftData
import SwiftUI

/// **Les écrans de création d'un deck, dans l'ordre où ils se posent.**
///
/// Le parcours a des branches, et c'est la seule raison pour laquelle ce n'est pas une
/// simple liste : on ne demande pas de note visée à quelqu'un qui ne passe pas d'épreuve, et
/// on ne demande pas de documents à quelqu'un qui n'en a pas. `next(for:)` est donc écrit à
/// la main plutôt que déduit d'un rang — un `rawValue + 1` qui saute des cas selon l'état
/// est un graphe déguisé en liste, et il devient faux au premier écran inséré.
///
/// **Une question par écran.** Le tri « tu étudies où ? et en quelle année ? » posé sur la
/// même page fait répondre à la première sans lire la seconde. C'est vrai ici aussi : la
/// matière, le nom et l'échéance ont chacun leur page.
enum DeckSetupStep: Hashable {
    case subject
    case name
    case source
    case materials
    case topic
    case purpose
    case grade
    case deadline
    case confidence
    case building

    /// L'écran suivant, selon ce qui a déjà été répondu.
    func next(for setup: DeckSetup) -> DeckSetupStep? {
        switch self {
        case .subject: .name
        case .name: .source
        case .source: setup.source == .generated ? .topic : .materials
        case .materials: .purpose
        case .topic: .purpose
        // La note visée ne se demande qu'à qui passe une épreuve. « Quelle note vises-tu
        // pour ton apprentissage personnel ? » n'a pas de réponse.
        case .purpose: (setup.purpose?.isExam ?? false) ? .grade : .deadline
        case .grade: .deadline
        case .deadline: .confidence
        case .confidence: .building
        case .building: nil
        }
    }

    /// Ce que la jauge montre. Les valeurs sont écrites à la main parce que le parcours n'a
    /// pas la même longueur selon la branche : une fraction calculée sur un rang reculerait
    /// visiblement quand l'étudiant répond « j'apprends, c'est tout ».
    var progress: Double {
        switch self {
        case .subject: 0.1
        case .name: 0.22
        case .source: 0.34
        case .materials, .topic: 0.46
        case .purpose: 0.58
        case .grade: 0.68
        case .deadline: 0.78
        case .confidence: 0.9
        case .building: 1
        }
    }

    var analyticsName: String { String(describing: self) }
}

/// **La création d'un deck, du choix de la matière au plan construit.**
///
/// Ce parcours remplace l'écran d'import pour tout ce qui est un deck. L'ancien demandait un
/// document et rien d'autre, puis rendait la main sur une fiche ; celui-ci demande ce qu'il
/// faut pour poser un plan de travail, et rend la main sur ce plan.
///
/// Il est présenté en `fullScreenCover` et non poussé dans la pile : il a sa propre jauge,
/// son propre rythme, et une barre de navigation par-dessus donnerait deux façons de revenir
/// en arrière qui ne font pas la même chose.
struct DeckSetupFlowView: View {
    /// La matière, quand elle est déjà connue — création depuis un dossier de matière, par
    /// exemple. L'écran de la matière est alors sauté.
    var presetSubject: String?
    var onCreated: (Course) -> Void
    var onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var setup: DeckSetup
    @State private var step: DeckSetupStep

    init(
        presetSubject: String? = nil,
        onCreated: @escaping (Course) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.presetSubject = presetSubject
        self.onCreated = onCreated
        self.onCancel = onCancel
        let model = DeckSetup(subject: presetSubject)
        _setup = State(initialValue: model)
        _step = State(initialValue: model.hasSubject ? .name : .subject)
    }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    stepView
                        .id(step)
                        .transition(.onboardingPage)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(OnboardingMotion.page, value: step)
            }
        }
        .environment(\.onboardingSurface, .canvas)
        .preferredColorScheme(.light)
        .onAppear {
            Haptics.prepare()
            Analytics.track(.deckSetupStep, ["step": .text(step.analyticsName)])
        }
        .onChange(of: step) { _, value in
            Analytics.track(.deckSetupStep, ["step": .text(value.analyticsName)])
        }
    }

    /// **La jauge, et une sortie.**
    ///
    /// La croix disparaît sur l'écran de construction : à ce moment-là une génération est
    /// lancée et payée, et un bouton qui laisse croire qu'on peut l'annuler sans rien perdre
    /// mentirait. L'écran de construction a sa propre façon de finir.
    private var header: some View {
        HStack(spacing: MicaboSpacing.sm) {
            MicaboProgressBar(
                progress: step.progress,
                tint: MicaboColor.accent,
                track: MicaboColor.stroke
            )
            .frame(height: 4)

            if step != .building {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .frame(width: 28, height: 28)
                        .background(MicaboColor.surfaceMuted, in: Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityLabel(i18n.t("app.a11y.close"))
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, MicaboSpacing.xs)
        .animation(.easeInOut(duration: 0.38), value: step)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .subject: DeckSubjectStepView(setup: setup, onNext: advance)
        case .name: DeckNameStepView(setup: setup, onNext: advance)
        case .source: DeckSourceStepView(setup: setup, onNext: advance)
        case .materials: DeckMaterialsStepView(setup: setup, onNext: advance)
        case .topic: DeckTopicStepView(setup: setup, onNext: advance)
        case .purpose: DeckPurposeStepView(setup: setup, onNext: advance)
        case .grade: DeckGradeStepView(setup: setup, onNext: advance)
        case .deadline: DeckDeadlineStepView(setup: setup, onNext: advance)
        case .confidence: DeckConfidenceStepView(setup: setup, onNext: advance)
        case .building:
            DeckBuildingStepView(setup: setup, onCreated: onCreated, onFailed: { step = .source })
        }
    }

    private func advance() {
        guard let next = step.next(for: setup) else { return }
        step = next
    }
}
