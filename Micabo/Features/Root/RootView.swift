import StoreKit
import SwiftData
import SwiftUI

/// La porte du compte, et la clé qui la referme.
///
/// Le drapeau est partagé : c'est l'écran de connexion du parcours d'accueil qui le pose
/// quand on choisit de passer, et `RootView` qui le relit. Sans une clé commune, passer la
/// connexion pendant le parcours se payait par un second écran de connexion à la sortie.
enum AccountGate {
    static let skippedKey = "micabo.auth.skipped"
}

/// **La demande de note, après la première leçon terminée.**
///
/// Elle venait deux fois avant tout usage : sur la page « Soutiens-nous » du parcours, et à la
/// première apparition des onglets - au même moment que l'offre cadeau. Une note demandée à
/// quelqu'un qui n'a encore rien appris ne dit rien de l'app, et iOS n'accorde que trois
/// demandes par an. Elle vient maintenant une fois, à la fin de la première leçon
/// (`LessonPathView`), quand l'élève sait ce qu'il note.
enum InAppReviewPrompt {
    static let askedAfterFirstLessonKey = "micabo.review.askedAfterFirstLesson"

    /// Vrai la première fois seulement : la demande est réservée, et ne revient pas.
    static func claimAfterFirstLesson(defaults: UserDefaults = .standard) -> Bool {
        guard !defaults.bool(forKey: askedAfterFirstLessonKey) else { return false }
        defaults.set(true, forKey: askedAfterFirstLessonKey)
        return true
    }
}

/// Aiguillage au lancement : parcours d'accueil, puis l'application.
///
/// **Le compte se demande maintenant dans le parcours**, entre « c'est à ton tour » et
/// l'offre d'essai. Il s'est longtemps demandé ici, après le parcours, ce qui donnait deux
/// écrans de connexion à la suite : celui du parcours ne branchait rien, et celui-ci
/// reposait la question à quelqu'un qui venait d'y répondre.
///
/// L'écran ci-dessous reste, mais comme **rattrapage** : il ne s'affiche que pour quelqu'un
/// qui a fini le parcours sans compte et sans passer explicitement — un cas qui n'arrive
/// plus que sur une déconnexion depuis les réglages.
///
/// **Il ne propose plus de continuer sans compte.** Passer la connexion reste possible une
/// fois, pendant le parcours, où l'on n'a encore rien à perdre. Après une déconnexion
/// volontaire, la seule suite qui a du sens est de se reconnecter : proposer de rester
/// dehors reviendrait à proposer d'abandonner ce qu'on vient de mettre en sécurité.
struct RootView: View {
    @AppStorage(OnboardingPreferences.Key.completed) private var didCompleteOnboarding = false
    /// Vrai quand on a explicitement choisi de rester local. Le drapeau est nécessaire :
    /// sans lui, l'écran de compte reviendrait à chaque lancement.
    @AppStorage(AccountGate.skippedKey) private var didSkipAccount = false
    /// **Le premier cours se construit avant l'app.** Posé à la fin du parcours, levé quand
    /// le deck existe : entre les deux, on ne montre pas la liste vide, on montre « créons
    /// ton premier cours », puis la création elle-même, sans croix.
    @AppStorage(OnboardingPreferences.Key.pendingFirstImport) private var pendingFirstImport = false

    @Environment(AuthController.self) private var auth
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **Le rideau bleu du lancement**, levé une fois la première image posée. Voir
    /// `LaunchCurtain`.
    @State private var showsCurtain = !LaunchCurtain.hasLifted

    /// Parcours ou app : la règle est dans `LaunchGate`. Une session restaurée du trousseau
    /// n'en décide pas — seul le parcours fini sur cette installation, ou « J'ai déjà un
    /// compte » (qui le marque fini), ouvre l'app.
    private var route: LaunchRoute {
        LaunchGate.route(
            installMarked: LaunchGate.isInstallMarked(),
            onboardingDoneLocally: didCompleteOnboarding,
            hasSession: auth.isSignedIn,
            tappedHaveAccount: false
        )
    }

    private var showsAccountGate: Bool {
        didCompleteOnboarding && !auth.isSignedIn && !didSkipAccount && auth.state != .restoring
    }

    var body: some View {
        ZStack {
            if route == .onboarding {
                OnboardingFlowView(library: modelContext) {
                    didCompleteOnboarding = true
                    // Les réponses du parcours montent tout de suite (`noteOnboardingAnswers`,
                    // posé par le parcours), avant que le profil du serveur - celui d'une
                    // ancienne installation, si la session a survécu - ne redescende.
                    Task { await sync.sync(context: modelContext) }
                }
                // Un fondu, sans échelle : une page qui « respire » en arrivant fait un saut.
                .transition(.opacity)
            } else if showsAccountGate {
                AuthView()
                    .transition(.opacity)
            } else if pendingFirstImport {
                FirstDeckFlowView()
                    .transition(.opacity)
            } else {
                // Pas de demande de note ici : elle tombait avec l'offre cadeau, avant toute
                // leçon. Elle vient après la première leçon terminée (`InAppReviewPrompt`).
                RootTabView()
                    .transition(.opacity)
            }
        }
        .overlay {
            if showsCurtain {
                LaunchCurtain()
                    .transition(.opacity)
            }
        }
        // **Le rideau se lève au tour suivant de la boucle**, une fois la première image de
        // l'écran posée dessous : l'écran de lancement (le même bleu) cède la place sans
        // blanc intermédiaire, par un fondu court. Sur le parcours, le premier écran est
        // lui-même ce bleu, et le fondu ne se voit pas.
        .task {
            guard showsCurtain else { return }
            // Une seule fois par lancement : changer de langue recrée `RootView`
            // (`.id(uiLocale.locale)`), et le bleu n'a pas à repasser sur l'app.
            LaunchCurtain.hasLifted = true
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(60))
            withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion)) {
                showsCurtain = false
            }
        }
        // Le passage d'un écran racine à l'autre : la courbe commune, un fondu bref si le
        // mouvement est réduit.
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: didCompleteOnboarding)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: showsAccountGate)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: pendingFirstImport)
        // Se connecter depuis les réglages referme la porte : sans ça, le drapeau « plus
        // tard » resterait vrai et l'écran de compte ne reviendrait jamais après une
        // déconnexion.
        .onChange(of: auth.isSignedIn) { _, isSignedIn in
            if isSignedIn { didSkipAccount = false }
        }
    }
}

/// **Le bleu de l'écran de lancement, recopié en SwiftUI.**
///
/// L'écran de lancement (`UILaunchScreen` dans `Info.plist`) est un aplat
/// `LaunchBackground` - le bleu Micabo, jour comme nuit - sans image. La première image de
/// SwiftUI doit lui être identique au pixel près : ce rideau la recouvre, puis s'efface en
/// fondu sur l'écran qui suit. Il n'y a qu'un seul logo, et c'est Mika qui le porte, sur le
/// premier écran du parcours : la marque ne s'affiche plus deux fois de suite.
struct LaunchCurtain: View {
    /// Vrai une fois le rideau levé pendant ce lancement.
    nonisolated(unsafe) static var hasLifted = false

    var body: some View {
        MicaboBrand.launch
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
