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
enum DeckSetupStep: Hashable, CaseIterable {
    case subject
    case name
    /// La langue du cours. Celle de l'interface est proposée d'office.
    case language
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
        case .name: .language
        case .language: .source
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
        case .subject: 0.08
        case .name: 0.18
        case .language: 0.27
        case .source: 0.36
        case .materials, .topic: 0.47
        case .purpose: 0.58
        case .grade: 0.68
        case .deadline: 0.78
        case .confidence: 0.9
        case .building: 1
        }
    }

    var analyticsName: String { String(describing: self) }

    /// Le rang de l'écran dans l'entonnoir. Il voyage avec l'événement pour que le
    /// tableau de bord ordonne les écrans sans recopier la liste ; les deux branches
    /// (documents ou sujet) partagent le même rang.
    var analyticsIndex: Int {
        switch self {
        case .subject: 0
        case .name: 1
        case .language: 2
        case .source: 3
        case .materials, .topic: 4
        case .purpose: 5
        case .grade: 6
        case .deadline: 7
        case .confidence: 8
        case .building: 9
        }
    }
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
    /// **Faux pour le premier cours.** À la sortie du parcours d'accueil, l'app n'a rien
    /// d'autre à montrer qu'un deck qui n'existe pas encore : la croix mènerait sur une
    /// liste vide, et elle disparaît.
    var isDismissable: Bool = true
    var onCreated: (Course) -> Void
    var onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var setup: DeckSetup
    @State private var step: DeckSetupStep
    /// Les écrans déjà traversés, pour le retour. Voir `goBack`.
    @State private var history: [DeckSetupStep] = []

    init(
        presetSubject: String? = nil,
        isDismissable: Bool = true,
        onCreated: @escaping (Course) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.presetSubject = presetSubject
        self.isDismissable = isDismissable
        self.onCreated = onCreated
        self.onCancel = onCancel
        let model = DeckSetup(subject: presetSubject)
        _setup = State(initialValue: model)
        _step = State(initialValue: model.hasSubject ? .name : .subject)
    }

    var body: some View {
        ZStack {
            // Le blanc du parcours d'accueil : ces écrans en ont la charte, et un fond
            // crème sous des pages blanches faisait une bande à chaque passage.
            OnboardingPalette.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ZStack {
                    stepView
                        .id(step)
                        .transition(.onboardingFade)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(OnboardingMotion.page, value: step)
            }
        }
        .environment(\.onboardingSurface, .canvas)
        .preferredColorScheme(.light)
        .onAppear {
            Haptics.prepare()
            Analytics.track(.deckSetupStep, ["step": .text(step.analyticsName), "index": .number(Double(step.analyticsIndex)), "first": .flag(!isDismissable)])
        }
        .onChange(of: step) { _, value in
            Analytics.track(.deckSetupStep, ["step": .text(value.analyticsName), "index": .number(Double(value.analyticsIndex)), "first": .flag(!isDismissable)])
            // La page qui se pose se sent — à l'atterrissage, comme sur le parcours
            // d'accueil. Voir `OnboardingFlowView`.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                Haptics.tick()
            }
        }
    }

    /// **La jauge, le retour, et la sortie quand elle a un sens.**
    ///
    /// Le même chrome que le parcours d'accueil : la jauge sur toute la largeur, puis une
    /// rangée avec le rond du retour à gauche et la croix à droite. Plus de mascotte : neuf
    /// questions posées par une page blanche se lisent mieux que par un personnage qui
    /// change de tête.
    ///
    /// **L'en-tête reste en place pendant la construction, invisible.** Retiré de la pile,
    /// il faisait remonter tout l'écran au moment où la page arrivait. Masqué, rien ne
    /// bouge.
    private var header: some View {
        let isBuilding = step == .building

        return VStack(alignment: .leading, spacing: 10) {
            MicaboProgressBar(
                progress: step.progress,
                tint: OnboardingPalette.ink,
                track: OnboardingPalette.cardStrong
            )
            .frame(height: 3)
            .animation(OnboardingMotion.shift, value: step)

            HStack(alignment: .center, spacing: 10) {
                Button(action: goBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                        .frame(width: 40, height: 40)
                        .background(OnboardingPalette.card, in: Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .opacity(history.isEmpty ? 0 : 1)
                .disabled(history.isEmpty)
                .accessibilityLabel(i18n.t("app.common.back"))

                Spacer(minLength: 0)

                if isDismissable {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.ink)
                            .frame(width: 40, height: 40)
                            .background(OnboardingPalette.card, in: Circle())
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .accessibilityLabel(i18n.t("app.a11y.close"))
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.sm)
        .opacity(isBuilding ? 0 : 1)
        .allowsHitTesting(!isBuilding)
        .animation(.easeInOut(duration: 0.25), value: isBuilding)
    }

    @ViewBuilder
    private var stepView: some View {
        switch step {
        case .subject: DeckSubjectStepView(setup: setup, onNext: advance)
        case .name: DeckNameStepView(setup: setup, onNext: advance)
        case .language: DeckLanguageStepView(setup: setup, onNext: advance)
        case .source: DeckSourceStepView(setup: setup, onNext: advance)
        case .materials: DeckMaterialsStepView(setup: setup, onNext: advance)
        case .topic: DeckTopicStepView(setup: setup, onNext: advance)
        case .purpose: DeckPurposeStepView(setup: setup, onNext: advance)
        case .grade: DeckGradeStepView(setup: setup, onNext: advance)
        case .deadline: DeckDeadlineStepView(setup: setup, onNext: advance)
        case .confidence: DeckConfidenceStepView(setup: setup, onNext: advance)
        case .building:
            DeckBuildingStepView(setup: setup, onCreated: onCreated, onFailed: { history.removeAll(); step = .source })
        }
    }

    private func advance() {
        guard let next = step.next(for: setup) else { return }
        history.append(step)
        step = next
    }

    /// **On revient par où l'on est venu**, et non par un `previous(for:)` symétrique de
    /// `next(for:)`.
    ///
    /// Le parcours a des branches, et une branche ne se remonte pas en la recalculant :
    /// quelqu'un qui arrive sur l'échéance depuis « j'apprends, c'est tout » doit retomber
    /// sur le type d'épreuve, pas sur la note visée qu'on ne lui a jamais demandée. Or
    /// l'écran d'où il vient dépend d'une réponse qu'il est justement en train de défaire.
    /// La pile, elle, ne se trompe pas : elle ne déduit rien, elle se souvient.
    private func goBack() {
        guard let previous = history.popLast() else { return }
        step = previous
    }
}
