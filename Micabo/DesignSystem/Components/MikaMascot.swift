import ImageIO
import SwiftUI
import UIKit

// MARK: - La mise en scène de Mika (la règle)
//
// **Mika est une petite pieuvre noire, en entier** : la tête, cinq tentacules, et le bras qui
// tient le crayon jaune à l'étincelle. Il n'est plus un buste coupé par un bord : il se tient
// debout quelque part, il entre, il sort, il traverse.
//
// **Il vit sur le papier de l'app, pas sur un aplat bleu.** Le jour, sur la crème et le blanc
// des cartes ; la nuit, sur le graphite. Le bleu Micabo redevient un accent : les boutons, les
// anneaux, les pastilles, et **une carte forte par écran au plus** — jamais le décor
// systématique de la mascotte.
//
// 1. **Sur le clair**, Mika est noir sur crème ou blanc, une ombre très douce sous la
//    silhouette. **La nuit**, un halo clair suit son contour (`MikaHalo`) : le corps noir ne se
//    fond pas dans le graphite. L'étincelle du crayon est blanche à liseré bleu : elle se lit
//    partout.
// 2. **Les moments**, à varier d'un écran à l'autre :
//    - **Mika posé sur un bord** : ses tentacules sur le haut d'un bouton ou d'une carte, ou
//      sur le bas d'une carte qui le porte (le plan du jour de Home, Concentration, la barre du
//      nouvel élève, la série du Profil, « Aucun examen ») ;
//    - **Mika dans son nid**, un petit rond clair (`MikaFrame.circle`), à côté d'une phrase
//      (les journées vides, les feuilles, les retours de quiz, les écrans vides) ;
//    - **Mika qui arrive ou s'en va** (`MikaJourney` : il entre en courant et freine, il prend
//      son élan et file, il traverse en marchant ou à la nage), pour un moment qui le mérite :
//      un objectif atteint, une attente.
// 3. **Les tailles** : 100 à 170 points pour le héros d'un écran, 52 à 88 dans un nid, jamais
//    moins de 30. Sous 64 points, Mika est une image fixe.
// 4. **Deux Mika animés au plus par écran** ; les autres sont fixes (`animates: false`).
// 5. **Le bleu reste permis** comme une scène de marque rare — le lancement, l'icône
//    (`MikaFrame.rounded`), une carte forte (`MikaFrame.blueCircle`, `backdrop: .blue`) — mais
//    ce n'est plus là que Mika habite.
//
// Le détail, écran par écran : `docs/refonte-knowunity.md` § 9.

/// **Les treize humeurs de Mika.**
///
/// Chacune a son animation (`Resources/Mika/mika-<nom>.webp`, du WebP animé transparent à 24
/// images par seconde, 512 points de côté) et une pose fixe (`Mika-<pose>` dans le catalogue).
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos : il flotte, respire, cligne des yeux. Les écrans calmes, l'attente.
    case idle
    /// Coucou : il salue d'un tentacule. Accueil, premier lancement.
    case wave
    /// Joie : un saut. Bonne réponse, action réussie.
    case happy
    /// Sommeil : yeux fermés, « z z z ». Inactivité, liste vide, rappel, la nuit.
    case sleep
    /// Réflexion : il tapote et regarde l'étincelle. Chargement, l'IA lit le cours.
    case think
    /// Surprise : un sursaut, les tentacules écartés. Nouveauté, récompense.
    case surprise
    /// Célébration : deux sauts, des étincelles. Leçon finie, objectif atteint.
    case celebrate
    /// Tristesse. Erreur, hors-ligne.
    case sad
    /// Écriture : il gribouille, des étincelles s'envolent. Génération en cours.
    case write
    /// Clin d'œil : encouragement, astuce.
    case wink
    /// Curiosité : il regarde à gauche, à droite, en haut. Écran vide, attente.
    case look
    /// Non : il secoue la tête, un « non » doux. Mauvaise réponse.
    case shake
    /// Apparition : il tombe du haut et atterrit. Arrivée sur un écran.
    case appear

    var id: String { rawValue }

    /// Le nom de l'animation, celui du fichier `mika-<nom>.webp`.
    var animationName: String {
        switch self {
        case .idle: "repos"
        case .wave: "coucou"
        case .happy: "saut"
        case .sleep: "sommeil"
        case .think: "reflexion"
        case .surprise: "surprise"
        case .celebrate: "celebration"
        case .sad: "triste"
        case .write: "ecriture"
        case .wink: "clin-doeil"
        case .look: "regard"
        case .shake: "non"
        case .appear: "apparition"
        }
    }

    /// Les humeurs qui bouclent ; les autres se jouent une fois puis Mika revient au repos.
    var loops: Bool {
        switch self {
        case .idle, .think, .write, .sad, .sleep: true
        default: false
        }
    }

    /// Durée de l'animation, en secondes (`animations.json` du kit).
    var duration: Double {
        switch self {
        case .idle, .think, .sad, .look: 3
        case .sleep: 4
        case .write: 2
        case .wave: 2.17
        case .happy: 1.58
        case .surprise, .wink: 1.5
        case .celebrate: 2.67
        case .shake: 1.67
        case .appear: 1.33
        }
    }

    /// La pose fixe la plus proche.
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

/// Les douze poses fixes du kit, en PNG transparent.
enum MikaStill: String, CaseIterable {
    case neutral = "neutre"
    case wave = "coucou"
    case smile = "sourire"
    case sleep = "sommeil"
    case think = "reflexion"
    case surprise
    /// Le saut de joie, en l'air.
    case celebrate = "saut"
    case sad = "triste"
    case write = "ecriture"
    case wink = "clin-doeil"
    case run = "course"
    case swim = "nage"

    /// Le nom de l'image dans le catalogue.
    var imageName: String { "Mika-\(rawValue)" }

    /// Gardé pour les appelants d'avant : l'étincelle du nouveau Mika se lit sur tous les fonds,
    /// il n'y a plus qu'une image par pose.
    func imageName(sparkle: MikaSparkle) -> String { imageName }
}

/// La couleur de l'étincelle au bout du crayon. Le nouveau Mika a une étincelle blanche à
/// liseré bleu, lisible partout : la valeur ne choisit plus d'image, elle reste pour les
/// appelants.
enum MikaSparkle: Equatable {
    case white
    case blue
}

/// Ce qu'il y a derrière Mika, d'où se déduit son halo.
enum MikaBackdrop: Equatable {
    /// Le papier de l'app, qui suit le thème : une ombre douce le jour, un halo clair la nuit.
    case surface
    /// Un fond clair quel que soit le thème : l'ombre douce.
    case light
    /// Le bleu Micabo, ou un fond sombre et saturé : ni ombre ni halo.
    case blue
}

/// Le cadre de Mika.
enum MikaFrame: Equatable {
    /// Aucun cadre : Mika debout, ses tentacules sur le bord bas du carré — à poser sur un
    /// bord (le haut d'un bouton, le bas d'une carte), ou sur une ligne.
    case none
    /// **Le nid** : une pastille ronde claire — blanc bleuté le jour, graphite éclairé la nuit,
    /// un filet fin —, Mika en entier au milieu. Le cadre de tous les jours.
    case circle
    /// La pastille ronde bleu Micabo, pour une carte forte de la marque.
    case blueCircle
    /// Un carré arrondi bleu Micabo, comme l'icône de l'app.
    case rounded
}

/// **Mika, la mascotte** : la petite pieuvre noire aux yeux blancs, crayon à la main.
///
/// Animé (`MikaLibrary`, le WebP animé du kit lu par ImageIO), ou fixe — une pose du
/// catalogue — quand l'animation n'a pas sa place :
/// - `frozenAt` est donné (les rendus de la CI : `ImageRenderer` ne dessine pas UIKit),
///   ou `animates` est faux (règle 4 : deux Mika animés au plus par écran) ;
/// - « Réduire les animations » est actif, ou `\.mikaStill` est posé ;
/// - Mika fait moins de 64 points ;
/// - on tourne sous XCTest.
///
/// Les humeurs qui bouclent (`idle`, `think`, `write`, `sad`, `sleep`) bouclent ; les autres
/// se jouent une fois puis Mika revient au repos, et `onDone` est appelé. Un appui, si
/// `reactsToTap`, lui fait un saut de joie puis il revient à son humeur.
///
/// `size` est le côté du carré qu'il occupe ; sans cadre, ses tentacules touchent le bas du
/// carré et sa tête monte aux quatre cinquièmes.
struct MikaMascot: View {
    var mood: MikaMood
    var size: CGFloat
    var reactsToTap: Bool
    /// Fige Mika sur la pose de son humeur (rendus, aperçus). La valeur n'est plus lue :
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

    /// Sous cette taille, une image fixe.
    static let minimumAnimatedSize: CGFloat = 64
    /// **L'échelle du dessin sans cadre** : l'image du kit garde un grand vide au-dessus de
    /// Mika (pour ses sauts). Dessinée à 1,3 fois le carré, posée par le bas, elle met ses
    /// tentacules au bord bas et l'étincelle juste sous le bord haut ; un saut déborde au-dessus.
    static let bareScale: CGFloat = 1.3
    /// Dans un rond : Mika en entier, centré, un peu remonté.
    static let framedScale: CGFloat = 1.04

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill
    @Environment(\.colorScheme) private var colorScheme

    /// Le saut d'un appui, joué par-dessus l'humeur.
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
            figure(side: size * Self.bareScale)
                .background {
                    // Sur le papier, une ombre douce le jour, un halo clair la nuit, qui suit
                    // la silhouette : derrière lui, jamais sur lui. Sur le bleu, rien.
                    if backdrop != .blue {
                        MikaHalo(still: shown.still, side: size * Self.bareScale, night: colorScheme == .dark && backdrop == .surface)
                    }
                }
                .frame(width: size, height: size, alignment: .bottom)
        case .circle:
            nest
        case .blueCircle:
            pastille(Circle())
        case .rounded:
            pastille(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        }
    }

    /// Mika au milieu d'un rond : tout le corps, un peu remonté pour que les tentacules ne
    /// touchent pas le bord.
    private var centered: some View {
        figure(side: size * Self.framedScale)
            .offset(y: -size * 0.14)
            .frame(width: size, height: size)
    }

    /// **Le nid** : Mika dans son rond clair.
    private var nest: some View {
        let night = colorScheme == .dark
        return ZStack {
            Circle().fill(MikaNest.fill(night: night))
            // Une lumière derrière lui : le noir s'y détache, de jour comme de nuit.
            Circle()
                .fill(RadialGradient(
                    colors: [MikaNest.light(night: night), MikaNest.light(night: night).opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.5),
                    startRadius: 0,
                    endRadius: size * 0.5
                ))
            centered
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(MikaNest.rim(night: night), lineWidth: max(1, size * 0.014)))
    }

    /// Mika dans une pastille bleue.
    private func pastille<S: Shape>(_ shape: S) -> some View {
        ZStack {
            shape.fill(MicaboBrand.blue)
            centered
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }

    // MARK: Le dessin

    @ViewBuilder
    private func figure(side: CGFloat) -> some View {
        if isAnimated {
            MikaAnimationView(name: shown.animationName, take: take, loops: shown.loops) {
                finish(shown)
            }
            .frame(width: side, height: side)
        } else {
            Image(shown.still.imageName)
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
        // Fixe : la joie reste le temps de l'animation, puis Mika revient.
        stillTask?.cancel()
        let current = take
        stillTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, current == take else { return }
            reaction = nil
        }
    }

    /// La fin d'une lecture ponctuelle.
    private func finish(_ played: MikaMood) {
        if reaction != nil, played == reaction {
            reaction = nil
            take += 1
            return
        }
        guard played == mood, !mood.loops else { return }
        settled = true
        take += 1
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

// MARK: - Mika qui arrive, qui part, qui traverse

/// **Les voyages de Mika**, sur un cadre large (680 × 440 dans le kit) : il arrive en
/// courant et freine au milieu, il prend son élan et file à droite, il traverse en marchant ou
/// à la nage. Pour un moment qui le mérite — un objectif atteint, une attente —, jamais en
/// décor permanent.
///
/// Fixe (rendus, « Réduire les animations ») : `enter` le montre arrivé, debout au milieu ;
/// les traversées le montrent en route ; `exit` ne montre rien.
struct MikaJourney: View {
    enum Kind: String {
        case enter = "entree"
        case exit = "sortie"
        case walkAcross = "traversee-marche"

        var loops: Bool { self == .walkAcross }

        /// La pose fixe, et où la poser (la part de la largeur, depuis le bord de tête).
        var still: (MikaStill, CGFloat)? {
            switch self {
            case .enter: (.neutral, 0.5)
            case .exit: nil
            case .walkAcross: (.run, 0.5)
            }
        }
    }

    let kind: Kind
    /// La hauteur du cadre : Mika y a la taille d'un `MikaMascot` de ce côté.
    var height: CGFloat = 140
    var onDone: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill
    @Environment(\.colorScheme) private var colorScheme
    @State private var done = false

    static let aspect: CGFloat = 680 / 440

    private var isAnimated: Bool { !reduceMotion && !forcedStill && !MikaLibrary.isRunningTests }

    var body: some View {
        let width = height * Self.aspect
        Group {
            if isAnimated, !done {
                MikaAnimationView(name: kind.rawValue, take: 0, loops: kind.loops) {
                    done = true
                    onDone?()
                }
            } else if let still = kind.still {
                // Dans le cadre large, Mika a 0,6 de la hauteur et ses tentacules à 0,89 ;
                // dans la pose carrée, son corps fait 0,59 du côté, tentacules à 0,95 : la
                // pose, du côté de la hauteur, se pose 0,06 plus haut que le bas du cadre.
                Image(still.0.imageName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: height, height: height)
                    .background {
                        MikaHalo(still: still.0, side: height, night: colorScheme == .dark)
                    }
                    .position(x: width * still.1, y: height * (0.5 - 0.06))
            } else {
                Color.clear
            }
        }
        .frame(width: width, height: height)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
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

    /// La lumière derrière lui.
    static func light(night: Bool) -> Color {
        night ? Color.white.opacity(0.14) : MicaboBrand.blue100
    }

    /// Le filet du bord : il tient le rond sur un fond du même ton.
    static func rim(night: Bool) -> Color {
        night ? Color.white.opacity(0.10) : MicaboBrand.blue100
    }
}

/// **Le halo de Mika sans cadre** : la silhouette de sa pose fixe, floutée derrière lui. Le
/// jour, une ombre très douce qui le pose sur la crème ; la nuit, un contour clair qui garde
/// le corps noir lisible sur le graphite.
struct MikaHalo: View {
    let still: MikaStill
    let side: CGFloat
    let night: Bool

    var body: some View {
        Image(still.imageName)
            .resizable()
            .renderingMode(.template)
            .interpolation(.medium)
            .scaledToFit()
            .frame(width: side, height: side)
            .foregroundStyle(night ? Color.white.opacity(0.24) : MicaboBrand.blue900.opacity(0.14))
            .blur(radius: max(2, side * (night ? 0.03 : 0.04)))
            .offset(y: night ? 0 : side * 0.02)
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

/// **Les animations de Mika** : du WebP animé transparent (`Resources/Mika/mika-<nom>.webp`),
/// lu par ImageIO (`CGAnimateImageAtURLWithBlock`). Le système décode chaque image au moment
/// de la montrer, à son rythme : un Mika animé ne garde pas soixante-douze images en mémoire,
/// et deux Mika sur un écran restent légers.
enum MikaLibrary {
    /// Vrai dans le processus des tests : ni animation, ni minuterie, des images fixes.
    static let isRunningTests: Bool =
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// L'adresse d'une animation dans l'app, `nil` si elle n'y est pas.
    static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: "mika-\(name)", withExtension: "webp")
    }

    /// Le nombre d'images d'une animation, lu une fois.
    @MainActor private static var frameCounts: [String: Int] = [:]

    @MainActor static func frameCount(of name: String) -> Int {
        if let count = frameCounts[name] { return count }
        guard let url = url(for: name), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return 0 }
        let count = CGImageSourceGetCount(source)
        frameCounts[name] = count
        return count
    }

    /// Lit le nombre d'images de chaque animation au lancement, en tâche de fond : la première
    /// apparition de Mika n'attend pas l'ouverture de son fichier.
    static func preload() {
        guard !isRunningTests else { return }
        Task { @MainActor in
            for mood in MikaMood.allCases {
                _ = frameCount(of: mood.animationName)
            }
        }
    }
}

/// Le lecteur : une `UIImageView` que ImageIO nourrit image par image. Une nouvelle `take`
/// (ou un autre nom) arrête la lecture en cours et en lance une autre ; une lecture « une
/// fois » s'arrête sur sa dernière image et le signale à `onFinish`.
private struct MikaAnimationView: UIViewRepresentable {
    let name: String
    let take: Int
    let loops: Bool
    let onFinish: () -> Void

    final class Coordinator {
        var name: String?
        var take = -1
        /// Le jeton de la lecture en cours : une lecture remplacée s'arrête d'elle-même.
        var token = 0
        var onFinish: () -> Void = {}

        deinit { token += 1 }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onFinish = onFinish
        guard coordinator.name != name || coordinator.take != take else { return }
        coordinator.name = name
        coordinator.take = take
        coordinator.token += 1
        let token = coordinator.token
        guard let url = MikaLibrary.url(for: name) else { return }
        let last = MikaLibrary.frameCount(of: name) - 1
        let loops = loops
        // Les fichiers du kit bouclent tous : une lecture « une fois » s'arrête elle-même sur
        // sa dernière image.
        let options = [kCGImageAnimationLoopCount: loops ? 100_000 : 1] as CFDictionary
        CGAnimateImageAtURLWithBlock(url as CFURL, options) { [weak view, weak coordinator] index, image, stop in
            guard let view, let coordinator, coordinator.token == token else {
                stop.pointee = true
                return
            }
            view.image = UIImage(cgImage: image)
            if !loops, index >= last {
                stop.pointee = true
                coordinator.onFinish()
            }
        }
    }

    static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) {
        coordinator.token += 1
    }
}
