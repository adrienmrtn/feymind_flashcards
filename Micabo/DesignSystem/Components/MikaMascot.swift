import Lottie
import SwiftUI
import UIKit

// MARK: - La mise en scène de Mika (la règle)
//
// **Mika vit sur le papier de l'app, pas sur un aplat bleu.** Le jour, sur la crème et le
// blanc des cartes ; la nuit, sur le graphite. Le bleu Micabo redevient un accent : les
// boutons, les anneaux, les pastilles, et **une carte forte par écran au plus** — jamais le
// décor systématique de la mascotte.
//
// 1. **Sur le clair**, Mika est noir sur crème ou blanc, l'étincelle de son crayon en bleu,
//    une ombre très douce sous la silhouette. **La nuit**, un halo clair suit son contour
//    (`MikaHalo`) : le corps noir ne se fond pas dans le graphite.
// 2. **Les moments**, à varier d'un écran à l'autre :
//    - **Mika qui dépasse** d'une carte blanche ou d'un bouton : le buste derrière, la coupe
//      cachée par le bord (le plan du jour de Home, Concentration, la barre du nouvel élève) ;
//    - **Mika dans son nid**, un petit cadre rond clair (`MikaFrame.circle`), à côté d'une
//      bulle ou d'une phrase (les journées vides, les feuilles, les retours de quiz) ;
//    - **Mika assis sur le bord** d'une carte, en bas, à côté de ce qu'elle dit (la série du
//      Profil, la carte « Aucun examen »).
// 3. **Les tailles** : un buste de 100 à 170 points pour le héros d'un écran, 52 à 64 dans un
//    nid à côté d'un texte, jamais moins de 30.
// 4. **Deux Mika animés au plus par écran** ; les autres sont fixes (`animates: false`).
// 5. **Le bleu reste permis** comme une scène de marque rare — le lancement, l'icône
//    (`MikaFrame.rounded`), une carte forte (`MikaFrame.blueCircle`, `backdrop: .blue`) — mais
//    ce n'est plus là que Mika habite.
//
// Le détail, écran par écran : `docs/refonte-knowunity.md` § 9.

/// **Les treize humeurs de Mika**, celles du kit de marque (`design/micabo-kit-mika/`).
///
/// Chacune a son animation Lottie (`Resources/Mika/mika-<humeur>.json`) et une image fixe
/// (`Mika-<expression>-bleu|clair` dans le catalogue) : les dix expressions fixes du kit
/// couvrent les treize humeurs, les trois sans image prennent la plus proche.
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos : il respire, cligne des yeux, l'étincelle scintille. Les écrans calmes.
    case idle
    /// Coucou : il agite le crayon. Accueil, premier lancement.
    case wave
    /// Sourire : les yeux rieurs, un petit rebond. Bonne réponse, action réussie.
    case happy
    /// Sommeil : yeux fermés, « z z z ». Inactivité, liste vide, rappel.
    case sleep
    /// Réflexion : il regarde l'étincelle qui tourne. Chargement, l'IA lit le cours.
    case think
    /// Surprise : grands yeux, un sursaut. Nouveauté, récompense.
    case surprise
    /// Célébration : il saute avec des étincelles. Leçon finie, objectif atteint.
    case celebrate
    /// Tristesse : regard baissé, étincelle éteinte. Erreur, hors-ligne.
    case sad
    /// Écriture : il gribouille, des étincelles s'envolent. Génération en cours.
    case write
    /// Clin d'œil : encouragement, astuce.
    case wink
    /// Curiosité : il regarde à gauche, à droite, en haut. Écran vide, attente.
    case look
    /// Non : il secoue la tête, un « non » doux. Mauvaise réponse.
    case shake
    /// Entrée : il surgit du bas. Arrivée sur un écran.
    case appear

    var id: String { rawValue }

    /// Les humeurs qui bouclent ; les autres se jouent une fois puis rendent la main au
    /// repos (`idle`), dont elles partent et où elles finissent toutes.
    var loops: Bool {
        switch self {
        case .idle, .think, .write, .sad, .sleep: true
        default: false
        }
    }

    /// Le nom du fichier Lottie, sans extension.
    var animationName: String { "mika-\(rawValue)" }

    /// Durée de l'animation, en secondes (`tokens.json`).
    var duration: Double {
        switch self {
        case .idle, .sleep: 5
        case .happy, .write: 2
        case .wave: 2.5
        case .think, .celebrate: 3
        case .surprise, .shake: 1.67
        case .sad: 4
        case .look: 3.33
        case .appear, .wink: 1.5
        }
    }

    /// L'expression fixe la plus proche.
    var still: MikaStill {
        switch self {
        case .idle, .appear, .look: .neutral
        case .wave: .wave
        case .happy: .smile
        case .sleep: .sleep
        case .think: .think
        case .surprise: .surprise
        case .celebrate: .celebrate
        case .sad, .shake: .sad
        case .write: .write
        case .wink: .wink
        }
    }
}

/// Les dix expressions fixes du kit, dans les deux versions de l'étincelle.
enum MikaStill: String, CaseIterable {
    case neutral = "neutre"
    case wave = "coucou"
    case smile = "sourire"
    case sleep = "sommeil"
    case think = "reflexion"
    case surprise
    case celebrate = "celebration"
    case sad = "triste"
    case write = "ecriture"
    case wink = "clin-doeil"

    /// Le nom de l'image dans le catalogue : étincelle blanche (`bleu`, pour un fond bleu ou
    /// sombre) ou bleue (`clair`, pour un fond clair).
    func imageName(sparkle: MikaSparkle) -> String {
        "Mika-\(rawValue)-\(sparkle == .white ? "bleu" : "clair")"
    }
}

/// La couleur de l'étincelle au bout du crayon. Blanche sur le bleu, elle disparaîtrait sur
/// un fond clair : elle y devient bleue (règle 3 du kit).
enum MikaSparkle: Equatable {
    case white
    case blue
}

/// Ce qu'il y a derrière Mika, d'où se déduit son étincelle.
enum MikaBackdrop: Equatable {
    /// Le papier de l'app, qui suit le thème : étincelle bleue le jour, blanche la nuit.
    case surface
    /// Un fond clair quel que soit le thème : étincelle bleue.
    case light
    /// Le bleu Micabo, ou un fond sombre et saturé : étincelle blanche.
    case blue
}

/// Le cadre de Mika. **Mika est un buste** (règle 1 du kit) : sans cadre, il doit être collé
/// au bord bas de ce qui le porte — une carte, un bouton, l'écran — et coupé par lui. Pour le
/// poser n'importe où, on le met dans un cadre, d'où il sort par le bas.
enum MikaFrame: Equatable {
    /// Aucun cadre : le bas de l'image est la coupe du buste, à poser sur un bord bas.
    case none
    /// **Le nid** : une pastille ronde claire — blanc bleuté le jour, graphite éclairé la nuit,
    /// un filet fin. C'est le cadre de tous les jours.
    case circle
    /// La pastille ronde bleu Micabo, pour une carte forte de la marque.
    case blueCircle
    /// Un carré arrondi bleu Micabo, comme l'icône de l'app.
    case rounded
}

/// **Mika, la mascotte** : le personnage noir aux yeux blancs, crayon à la main.
///
/// Animé par Lottie (`mika-<humeur>.json`, les treize animations du kit), ou fixe — une
/// image du catalogue — quand l'animation n'a pas sa place :
/// - `frozenAt` est donné (les rendus de la CI : `ImageRenderer` ne dessine pas Lottie),
///   ou `animates` est faux (règle 5 : deux Mika animés au plus par écran) ;
/// - « Réduire les animations » est actif, ou `\.mikaStill` est posé ;
/// - Mika fait moins de 64 points (règle 4) ;
/// - on tourne sous XCTest.
///
/// Les humeurs qui bouclent (`idle`, `think`, `write`, `sad`, `sleep`) bouclent ; les autres
/// se jouent une fois puis Mika revient au repos, et `onDone` est appelé. Un appui, si
/// `reactsToTap`, lui fait un sourire puis il revient à son humeur.
struct MikaMascot: View {
    var mood: MikaMood
    var size: CGFloat
    var reactsToTap: Bool
    /// Fige Mika sur l'image de son humeur (rendus, aperçus). La valeur n'est plus lue :
    /// une image fixe n'a pas d'instant.
    var frozenAt: Double?
    var backdrop: MikaBackdrop
    var frame: MikaFrame
    /// Faux pour un Mika de plus sur un écran qui en anime déjà deux.
    var animates: Bool
    var onDone: (() -> Void)?

    init(
        mood: MikaMood = .idle,
        size: CGFloat = 120,
        reactsToTap: Bool = false,
        frozenAt: Double? = nil,
        backdrop: MikaBackdrop = .surface,
        frame: MikaFrame = .none,
        animates: Bool = true,
        onDone: (() -> Void)? = nil
    ) {
        self.mood = mood
        self.size = size
        self.reactsToTap = reactsToTap
        self.frozenAt = frozenAt
        self.backdrop = backdrop
        self.frame = frame
        self.animates = animates
        self.onDone = onDone
    }

    /// Sous cette taille, une image fixe (règle 4 du kit).
    static let minimumAnimatedSize: CGFloat = 64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill
    @Environment(\.colorScheme) private var colorScheme

    /// Le sourire d'un appui, joué par-dessus l'humeur.
    @State private var reaction: MikaMood?
    /// L'humeur ponctuelle a fini de se jouer : Mika est revenu au repos.
    @State private var settled = false
    /// Change à chaque nouvelle lecture, pour rejouer la même humeur.
    @State private var take = 0
    @State private var stillTask: Task<Void, Never>?

    private var isAnimated: Bool {
        animates && frozenAt == nil && !reduceMotion && !forcedStill
            && size >= Self.minimumAnimatedSize && !MikaLibrary.isRunningTests
    }

    /// Ce que Mika joue en ce moment.
    private var shown: MikaMood {
        if let reaction { return reaction }
        return settled && !mood.loops ? .idle : mood
    }

    private var sparkle: MikaSparkle {
        switch frame {
        case .blueCircle, .rounded: return .white
        // Le nid est clair le jour, graphite la nuit : l'étincelle suit le papier.
        case .circle: return colorScheme == .dark ? .white : .blue
        case .none: break
        }
        switch backdrop {
        case .blue: return .white
        case .light: return .blue
        case .surface: return colorScheme == .dark ? .white : .blue
        }
    }

    var body: some View {
        framed
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onTapGesture { react() }
            .allowsHitTesting(reactsToTap)
            .onChange(of: mood) { _, _ in
                reaction = nil
                settled = false
                take += 1
                scheduleStillDone()
            }
            .onAppear { scheduleStillDone() }
            .onDisappear { stillTask?.cancel() }
            .accessibilityHidden(true)
    }

    // MARK: Le cadre

    @ViewBuilder
    private var framed: some View {
        switch frame {
        case .none:
            figure(side: size)
                .background {
                    // Sur le papier, une ombre douce le jour, un halo clair la nuit, qui suit
                    // la silhouette : derrière lui, jamais sur lui. Sur le bleu, rien.
                    if backdrop != .blue {
                        MikaHalo(still: shown.still, side: size, night: colorScheme == .dark && backdrop == .surface)
                    }
                }
        case .circle:
            nest
        case .blueCircle:
            pastille(Circle(), scale: 0.94)
        case .rounded:
            pastille(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous), scale: 1)
        }
    }

    /// **Le nid** : Mika dans son rond clair, sorti du bas et coupé par lui.
    private var nest: some View {
        let night = colorScheme == .dark
        return ZStack(alignment: .bottom) {
            Circle().fill(MikaNest.fill(night: night))
            // Une lumière derrière la tête : le noir s'y détache, de jour comme de nuit.
            Circle()
                .fill(RadialGradient(
                    colors: [MikaNest.light(night: night), MikaNest.light(night: night).opacity(0)],
                    center: UnitPoint(x: 0.45, y: 0.58),
                    startRadius: 0,
                    endRadius: size * 0.5
                ))
            figure(side: size * 0.94)
                // Mika est un peu à gauche dans son image (le crayon est à droite) : dans un
                // rond, on le recentre d'un cheveu pour que le crayon ne touche pas le bord.
                .offset(x: -size * 0.02)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(MikaNest.rim(night: night), lineWidth: max(1, size * 0.014)))
    }

    /// Mika dans sa pastille bleue, sorti de son bord bas et coupé par elle.
    private func pastille<S: Shape>(_ shape: S, scale: CGFloat) -> some View {
        ZStack(alignment: .bottom) {
            shape.fill(MicaboBrand.blue)
            figure(side: size * scale)
                .offset(x: frame == .blueCircle ? -size * 0.02 : 0)
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }

    // MARK: Le dessin

    @ViewBuilder
    private func figure(side: CGFloat) -> some View {
        if isAnimated {
            MikaLottieView(
                mood: shown,
                take: take,
                sparkle: sparkle == .white ? .white : UIColor(MicaboBrand.blue)
            ) { finished in
                finish(finished)
            }
            .frame(width: side, height: side)
        } else {
            Image(shown.still.imageName(sparkle: sparkle))
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: side, height: side)
        }
    }

    // MARK: Le temps

    private func react() {
        guard reactsToTap else { return }
        Haptics.selection()
        reaction = .happy
        take += 1
        guard !isAnimated else { return }
        // Fixe : le sourire reste le temps de l'animation, puis Mika revient.
        stillTask?.cancel()
        let current = take
        stillTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, current == take else { return }
            reaction = nil
        }
    }

    /// La fin d'une lecture ponctuelle.
    private func finish(_ mood: MikaMood) {
        if reaction != nil, mood == reaction {
            reaction = nil
            return
        }
        guard mood == self.mood, !mood.loops else { return }
        settled = true
        onDone?()
    }

    /// Fixe, une humeur ponctuelle n'a pas de fin à guetter : `onDone` arrive après sa durée,
    /// comme si elle s'était jouée.
    private func scheduleStillDone() {
        guard !isAnimated, let onDone, !mood.loops else { return }
        stillTask?.cancel()
        let duration = mood.duration
        stillTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            onDone()
        }
    }
}

// MARK: - Le nid et le halo

/// **Les couleurs du nid** de Mika (`MikaFrame.circle`) : clair le jour — du blanc au bleu le
/// plus pâle de la gamme —, graphite éclairé la nuit. Des constantes, pas les jetons du
/// thème : le nid doit se lire pareil sur la crème, le blanc d'une carte et le bleu.
enum MikaNest {
    static func fill(night: Bool) -> LinearGradient {
        night
            ? LinearGradient(colors: [Color(hex: 0x363946), Color(hex: 0x272933)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white, MicaboBrand.blue50], startPoint: .top, endPoint: .bottom)
    }

    /// La lumière derrière la tête.
    static func light(night: Bool) -> Color {
        night ? Color.white.opacity(0.14) : MicaboBrand.blue100
    }

    /// Le filet du bord : il tient le rond sur un fond du même ton.
    static func rim(night: Bool) -> Color {
        night ? Color.white.opacity(0.10) : MicaboBrand.blue100
    }
}

/// **Le halo de Mika sans cadre** : la silhouette de son image fixe, floutée derrière lui. Le
/// jour, une ombre très douce qui le pose sur la crème ; la nuit, un contour clair qui garde
/// le corps noir lisible sur le graphite.
struct MikaHalo: View {
    let still: MikaStill
    let side: CGFloat
    let night: Bool

    var body: some View {
        Image(still.imageName(sparkle: .blue))
            .resizable()
            .renderingMode(.template)
            .interpolation(.medium)
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(night ? Color.white.opacity(0.24) : MicaboBrand.blue900.opacity(0.14))
            .blur(radius: max(2, side * (night ? 0.035 : 0.05)))
            .offset(y: night ? 0 : side * 0.025)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Le figé

private struct MikaStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Mika en images fixes**, partout dessous : les rendus de la CI le posent, comme un
    /// écran qui veut retenir son mouvement.
    var mikaStill: Bool {
        get { self[MikaStillKey.self] }
        set { self[MikaStillKey.self] = newValue }
    }
}

// MARK: - Les animations

/// Les treize animations, décodées une fois et gardées par le cache de Lottie : changer
/// d'humeur ne repasse pas par le disque, et rien ne clignote.
enum MikaLibrary {
    /// Vrai dans le processus des tests : ni Lottie, ni minuterie, des images fixes.
    static let isRunningTests: Bool =
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    static func animation(for mood: MikaMood) -> LottieAnimation? {
        LottieAnimation.named(mood.animationName)
    }

    /// Décode les animations en tâche de fond, au lancement : la première apparition de Mika
    /// n'attend pas le décodage de son fichier.
    static func preload() {
        guard !isRunningTests else { return }
        Task.detached(priority: .utility) {
            for mood in MikaMood.allCases {
                _ = LottieAnimation.named(mood.animationName)
            }
        }
    }
}

/// Le lecteur Lottie. Une humeur (ou une nouvelle `take`) recharge l'animation et la joue :
/// en boucle si elle boucle, une fois sinon, et la fin est signalée à `onFinish`.
private struct MikaLottieView: UIViewRepresentable {
    let mood: MikaMood
    let take: Int
    let sparkle: UIColor
    let onFinish: (MikaMood) -> Void

    /// Les étincelles du kit sont des calques de forme nommés « sparkle », à remplissage plein.
    private static let sparkleKeypath = AnimationKeypath(keypath: "sparkle.**.Color")

    final class Coordinator {
        var mood: MikaMood?
        var take = -1
        var sparkle: UIColor?
        var onFinish: (MikaMood) -> Void = { _ in }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        container.isUserInteractionEnabled = false
        let animationView = LottieAnimationView(configuration: .shared)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: container.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let animationView = container.subviews.first as? LottieAnimationView else { return }
        let coordinator = context.coordinator
        coordinator.onFinish = onFinish

        if coordinator.sparkle != sparkle {
            coordinator.sparkle = sparkle
            animationView.setValueProvider(
                ColorValueProvider(sparkle.lottieColorValue),
                keypath: Self.sparkleKeypath
            )
        }

        guard coordinator.mood != mood || coordinator.take != take else { return }
        coordinator.mood = mood
        coordinator.take = take
        // L'animation vient du cache : elle remplace la précédente dans la même passe,
        // sans image vide entre les deux.
        animationView.animation = MikaLibrary.animation(for: mood)
        let played = mood
        let playedTake = take
        animationView.play(
            fromProgress: 0,
            toProgress: 1,
            loopMode: mood.loops ? .loop : .playOnce
        ) { [weak coordinator] completed in
            guard completed, let coordinator,
                  coordinator.mood == played, coordinator.take == playedTake
            else { return }
            coordinator.onFinish(played)
        }
    }

    static func dismantleUIView(_ container: UIView, coordinator: Coordinator) {
        (container.subviews.first as? LottieAnimationView)?.stop()
    }
}
