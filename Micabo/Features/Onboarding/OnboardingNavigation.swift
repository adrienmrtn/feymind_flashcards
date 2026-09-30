import SwiftUI

// MARK: - Le glissement d'une page à l'autre

/// **Les deux pages qu'on voit pendant qu'une page glisse, et où elles en sont.**
///
/// Le parcours ne se feuillette pas au doigt : c'est le bouton qui avance, et c'est le
/// glissement qui dit qu'on avance. La page qui arrive entre par la droite, sur toute la
/// largeur ; celle qui part recule d'un tiers sous elle, et se voile d'un rien. C'est le
/// geste d'une page poussée, celui que tout iPhone fait, et il se lit sans qu'on y pense.
/// Au retour, tout se joue à l'envers : la page du dessus s'en va par la droite, celle du
/// dessous revient à sa place.
///
/// Les deux pages sont tenues ici, par leur étape, et **gardent leur identité** : la page
/// qui part est celle qu'on vient de quitter, avec son état, pas une copie qui rejouerait
/// ses animations d'entrée pendant qu'elle sort.
struct OnboardingPager {
    enum Direction {
        case forward
        case backward
    }

    var current: OnboardingStep
    var outgoing: OnboardingStep?
    var direction: Direction = .forward
    var currentOffset: CGFloat = 0
    var outgoingOffset: CGFloat = 0
    /// Le voile posé sur la page qui recule, pour qu'elle se lise « dessous ».
    var veil: Double = 0
    /// Le fondu qui remplace le glissement quand le mouvement est réduit.
    var currentOpacity: Double = 1

    init(current: OnboardingStep) {
        self.current = current
    }

    /// **Les pages à dessiner, de dessous vers dessus.** En avançant, la nouvelle page passe
    /// sur l'ancienne ; en reculant, c'est l'ancienne qui reste dessus et s'en va.
    var pages: [OnboardingStep] {
        guard let outgoing else { return [current] }
        return direction == .forward ? [outgoing, current] : [current, outgoing]
    }

    func offset(for step: OnboardingStep) -> CGFloat {
        step == current ? currentOffset : outgoingOffset
    }

    func opacity(for step: OnboardingStep) -> Double {
        step == current ? currentOpacity : 1
    }

    /// **La page du dessous**, celle que le voile couvre : en avançant, l'ancienne recule
    /// sous la nouvelle ; en reculant, c'est la nouvelle qui attend dessous que l'ancienne
    /// s'en aille.
    var beneath: OnboardingStep? {
        guard outgoing != nil else { return nil }
        return direction == .forward ? outgoing : current
    }

    func veilOpacity(for step: OnboardingStep) -> Double {
        step == beneath ? veil : 0
    }
}

extension OnboardingMotion {
    /// Le glissement d'une page : quatre dixièmes, sur une courbe qui part vite et se pose
    /// sans rebondir. C'est la courbe de la pile de navigation du système, à peu de chose
    /// près, et c'est pour ça qu'elle passe inaperçue.
    static let slideDuration = 0.42
    static let slide = Animation.timingCurve(0.22, 0.9, 0.24, 1, duration: slideDuration)
    /// Ce dont la page qui part recule, en fraction de la largeur.
    static let slideParallax: CGFloat = 0.32
}

// MARK: - La barre du haut

/// **La pilule de retour et la jauge, sur une même ligne, fixes au-dessus des pages.**
///
/// Elle ne fait pas partie de ce qui glisse : les pages passent dessous, la barre reste, et
/// la jauge avance d'un cran pendant que la page arrive. **Sans retour, la jauge prend toute
/// la largeur** : la pilule n'existe que sur les écrans où l'on revient, et quand elle
/// arrive, au pays, la jauge se resserre d'un mouvement pour lui faire place. Une pilule
/// invisible qui garderait sa place laisserait la jauge décalée sur les premiers écrans, où
/// il n'y a rien à côté d'elle.
struct OnboardingTopBar: View {
    /// La hauteur que les pages lui laissent, sous la zone sûre.
    static let height: CGFloat = 56

    var progress: Double
    var showsBack: Bool
    var isVisible: Bool
    var onBack: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(spacing: 14) {
            if showsBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                        .frame(width: 64, height: 40)
                        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                .accessibilityLabel(i18n.t("app.common.back"))
                .transition(.opacity.combined(with: .scale(scale: 0.86)))
            }

            MicaboProgressBar(
                progress: progress,
                tint: OnboardingPalette.ink,
                track: OnboardingPalette.cardStrong
            )
            .frame(height: 4)
            .animation(OnboardingMotion.slide, value: progress)
        }
        .animation(OnboardingMotion.shift, value: showsBack)
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
        .frame(height: Self.height, alignment: .top)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .animation(.easeInOut(duration: 0.25), value: isVisible)
    }
}

// MARK: - Le rond fléché

/// **Le bouton d'avancement du parcours : un rond d'encre, une flèche blanche, en bas à
/// droite.** Éteint, il est gris clair et garde sa flèche : il se lit comme « pas encore »,
/// pas comme « cassé ». Il occupe la même place sur tous les écrans, pour que le pouce n'ait
/// jamais à le chercher.
struct OnboardingArrowButton: View {
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    @Environment(\.onboardingSurface) private var surface
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    static let size: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Button {
                guard isEnabled, !isLoading else { return }
                action()
            } label: {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(surface.buttonForeground)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 23, weight: .bold))
                    }
                }
                .foregroundStyle(surface.buttonForeground)
                .frame(width: Self.size, height: Self.size)
                .background(isEnabled ? surface.buttonTint : surface.disabledButtonTint, in: Circle())
                .shadow(color: OnboardingPalette.ink.opacity(isEnabled && !surface.isDark ? 0.18 : 0), radius: 14, y: 6)
                .contentShape(Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
            .disabled(!isEnabled || isLoading)
            .animation(OnboardingMotion.select, value: isEnabled)
            .animation(OnboardingMotion.select, value: isLoading)
            .accessibilityLabel(i18n.t("common.continue"))
        }
    }
}

/// Le rond fléché dans sa barre du bas, pour les écrans composés hors du gabarit.
struct OnboardingArrowBar: View {
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var action: () -> Void

    var body: some View {
        MicaboBottomBar(background: OnboardingPalette.white) {
            OnboardingArrowButton(isEnabled: isEnabled, isLoading: isLoading, action: action)
        }
    }
}

// MARK: - L'étape d'une page

private struct OnboardingStepKey: EnvironmentKey {
    static let defaultValue: OnboardingStep? = nil
}

extension EnvironmentValues {
    /// **L'étape que la page dessine**, posée par le parcours sur chacune de ses pages. Elle
    /// diffère de `OnboardingModel.step` le temps d'un glissement : la page qui part reste
    /// celle de son étape, et garde la place de la barre si elle la montrait.
    var onboardingStep: OnboardingStep? {
        get { self[OnboardingStepKey.self] }
        set { self[OnboardingStepKey.self] = newValue }
    }
}

// MARK: - L'espace de la barre

extension View {
    /// **La place de la barre du haut**, sur les écrans qui la montrent.
    ///
    /// La barre est posée par-dessus les pages, hors du glissement ; chaque page qui la
    /// montre commence donc en dessous d'elle. Le gabarit le fait de lui-même ; les écrans
    /// composés à la main l'appellent en tête de leur pile.
    func onboardingChromeInset(_ shows: Bool = true) -> some View {
        padding(.top, shows ? OnboardingTopBar.height : 0)
    }

    /// **Le clavier, sans que la page ne change de forme.** Voir `OnboardingKeyboardLift`.
    func onboardingKeyboardLift() -> some View {
        modifier(OnboardingKeyboardLift())
    }
}

// MARK: - Le clavier

/// **La page lève son pied au-dessus du clavier, elle-même, et ne le rebaisse pas en
/// partant.**
///
/// La pile des pages ignore le clavier (`OnboardingFlowView`) : sans ça, chaque page était
/// redimensionnée par le système à l'arrivée et au départ du clavier, et la page du prénom
/// **changeait de forme au moment de l'appui** — le clavier se rangeait, son pied
/// redescendait — avant que la page suivante ne glisse dessus. Ici, c'est la page qui
/// écoute le clavier et se rembourre du bas de sa hauteur, avec son animation ; et dès
/// qu'elle n'est plus l'étape du modèle, elle **se fige** : elle part telle qu'elle était,
/// le clavier descend sous la page qui arrive.
///
/// Le rembourrage est la part du clavier qui dépasse de la zone sûre du bas : la page
/// s'arrête déjà au-dessus de l'indicateur d'accueil.
struct OnboardingKeyboardLift: ViewModifier {
    @Environment(OnboardingModel.self) private var model: OnboardingModel?
    @Environment(\.onboardingStep) private var step: OnboardingStep?

    @State private var lift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, lift)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard isLive else { return }
                move(to: Self.lift(for: note), with: note)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { note in
                guard isLive else { return }
                move(to: 0, with: note)
            }
    }

    /// Vrai tant que la page est celle du modèle. Le modèle est lu au moment de l'avis, pas
    /// à la construction de la vue : l'étape change avant que le clavier ne bouge, et c'est
    /// ce qui fige la page qui part.
    ///
    /// **Le verrou du glissement n'entre pas en jeu.** Le prénom demande son clavier à la
    /// fin du glissement, à quelques millisecondes près du moment où le verrou se lève :
    /// un avis reçu pendant le verrou serait perdu, et rien ne le réémet — la page resterait
    /// sous le clavier pour toute l'étape. L'étape suffit : la page qui part n'est plus
    /// celle du modèle, et celle qui arrive ne reçoit qu'un « se range » sans effet.
    ///
    /// **Le clavier d'une feuille n'est pas celui de la page.** Les avis du clavier sont
    /// ceux de toute l'app : quand une feuille posée par-dessus le parcours prend le
    /// clavier — le lien ou le texte des supports —, la page dessous ne bouge pas.
    private var isLive: Bool {
        guard let model else { return false }
        if let step, step != model.step { return false }
        if MicaboScreen.keyWindow?.rootViewController?.presentedViewController != nil { return false }
        return true
    }

    private func move(to target: CGFloat, with note: Notification) {
        guard target != lift else { return }
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        withAnimation(.easeOut(duration: max(0.15, duration))) { lift = target }
    }

    /// Ce que le clavier couvre de la page : sa hauteur sur l'écran, moins la zone sûre du
    /// bas, que la page laisse déjà libre.
    private static func lift(for note: Notification) -> CGFloat {
        guard let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let window = MicaboScreen.keyWindow else { return 0 }
        let covered = max(0, window.bounds.maxY - end.minY)
        return max(0, covered - window.safeAreaInsets.bottom)
    }
}
