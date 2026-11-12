import SwiftUI
import UIKit

// MARK: - La mise en scène de Mika (la règle)
//
// Mika est une petite pieuvre noire brillante : la tête, cinq tentacules, et le bras qui tient
// le crayon jaune à l'étincelle. **Trois formes, chacune à sa place, et nulle part ailleurs :**
//
// 1. **En demi, par défaut dans l'app** (`MikaPeek`) : le haut du corps — la tête, les yeux et
//    les joues, le bras au crayon, le haut des tentacules — qui **dépasse d'un bord**, coupé net
//    par lui, comme quelqu'un qui passe la tête : le haut du bouton d'une carte, le bas d'une
//    carte, une ligne sous une question, le haut de la barre de saisie. Toujours la même
//    taille pour le même rôle : `MikaPeek.card` (92 pt) dans une carte, `.line` (100 pt) sur la
//    ligne d'une question ou d'une bulle, `.hero` (124 pt) pour l'accueil de Home. Il est déjà
//    là quand l'écran arrive : il ne monte pas, il ne saute pas.
// 2. **En entier, aux moments qui comptent** (`MikaMascot`, 140 à 200 points, debout sur le
//    papier, une ombre douce dessous, au centre) : l'accueil de l'onboarding, le plan révélé,
//    la fête de l'objectif du jour et de la série, une leçon, un quiz ou un examen blanc
//    terminés, les écrans vides, l'attente d'une génération. L'expression dit exactement ce
//    qui se passe (`MikaMood`), sa bulle parle pour lui.
// 3. **En avatar** (`MikaAvatar`), son visage souriant dans un rond clair : partout où il ferait
//    moins de 40 points (l'en-tête d'une conversation, un message, une rangée).
//
// **Nulle part ailleurs** : pas sur un bouton, pas dans une liste, pas dans une pastille, jamais
// deux fois sur un écran.
//
// **Il est attachant** : ses images portent une lueur claire autour de lui (invisible sur la
// crème et le blanc, elle le détache du graphite la nuit et du bleu), une lumière de contour
// sur le noir brillant, des joues roses discrètes ; un geste se termine sur un sourire, jamais
// sur un regard vide. Tout est cuit dans les images par `scripts/mika-assets.py`.
//
// **Il est fluide, à coup sûr** (lot 9, après le build 170 : « il faut pas que tu fasses Mika sauter », « pas
// fluide ») — le moteur, plus bas (`MikaCore`) :
// - **Une image fixe nette à chaque instant** : l'expression du moment (`MikaStill`, PNG à la
//   définition du kit). Aucune vidéo : une animation précalculée à 24 images par seconde
//   saccadait à côté d'une interface à 120 Hz (mesures : `docs/refonte-knowunity.md` § 9).
// - **Tout mouvement est natif**, calculé par Core Animation à la cadence de l'écran, avec les
//   courbes de `MicaboMotion` : le **fondu enchaîné** d'une expression à l'autre (la nouvelle
//   se pose sur l'ancienne, puis l'ancienne s'efface : le corps ne devient jamais transparent),
//   une **respiration** d'échelle de 1,5 % une fois à l'arrivée, un **petit écrasement** de
//   3 % qui revient à l'appui, les **étincelles** de la fête. Jamais de saut, de rebond ni de
//   translation de Mika.
// - **Un geste, une fois** (`MikaMood.beats`) : coucou puis sourire, clin d'œil puis sourire…
//   puis il garde sa pose. Seules la réflexion et l'écriture alternent leurs deux images, le
//   temps d'une attente réseau.
// - **Un seul Mika en mouvement à la fois** dans toute l'app (`MikaStage`) : le dernier arrivé
//   joue, le précédent se pose sur son expression finale.
// - « Réduire les animations » : les fondus restent (ce sont des fondus), ni respiration, ni
//   écrasement, ni étincelles qui grandissent. `\.mikaStill`, `frozenAt`, `animates: false`,
//   les tests : l'expression fixe de l'humeur, rien d'autre.
//
// Le détail, écran par écran, et le cahier des charges d'un futur Mika :
// `docs/refonte-knowunity.md` § 9.

/// **Les treize humeurs de Mika** : ce qui se passe, et l'expression qui le dit.
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos : son sourire, les yeux plissés.
    case idle
    /// Coucou : il salue du bras, puis sourit. Accueil, premier lancement.
    case wave
    /// Joie : un sourire et un petit écrasement. Bonne réponse, action réussie.
    case happy
    /// Sommeil : yeux fermés, « z z z ». Liste vide, la nuit.
    case sleep
    /// Réflexion : l'étincelle au bout du crayon. Chargement, l'IA lit le cours.
    case think
    /// Surprise : les tentacules écartés, les yeux grands. Nouveauté, récompense. Il la garde :
    /// son corps est trop différent de celui du sourire pour un fondu sans fantôme.
    case surprise
    /// Célébration : un grand sourire et des étincelles autour de lui. Leçon finie, objectif
    /// atteint.
    case celebrate
    /// Tristesse. Erreur, hors-ligne.
    case sad
    /// Écriture : il écrit, des étincelles s'envolent du crayon. Génération en cours.
    case write
    /// Clin d'œil : encouragement, astuce, « à toi ».
    case wink
    /// Attentif : les yeux ouverts, il écoute. Écran vide, une lecture en cours.
    case look
    /// Non : la pose triste. Mauvaise réponse.
    case shake
    /// Arrivée : il regarde, puis sourit.
    case appear

    var id: String { rawValue }

    /// **L'expression qui dit l'humeur**, fixe : ce qu'on voit dans les rendus, avec
    /// `\.mikaStill`, et ce que l'animation montre au moment qui compte.
    var still: MikaStill {
        switch self {
        case .idle, .happy, .celebrate, .appear: .smile
        case .wave: .wave
        case .sleep: .sleep
        case .think: .think
        case .surprise: .surprise
        case .sad, .shake: .sad
        case .write: .write
        case .wink: .wink
        case .look: .neutral
        }
    }

    /// L'expression d'où part le geste, quand Mika s'anime.
    var opening: MikaStill {
        switch self {
        case .wink, .appear: .neutral
        default: still
        }
    }

    /// **Le geste**, joué une fois à l'arrivée et à chaque changement d'humeur : chaque temps
    /// attend `after` secondes, puis fond vers `pose`. Le dernier est la pose qui reste.
    var beats: [MikaBeat] {
        switch self {
        case .wave: [MikaBeat(after: 1.4, pose: .smile)]
        case .wink: [MikaBeat(after: 0.45, pose: .wink), MikaBeat(after: 1.3, pose: .smile)]
        case .appear: [MikaBeat(after: 0.6, pose: .smile)]
        default: []
        }
    }

    /// **La pose qui reste après le geste.**
    var rest: MikaStill { beats.last?.pose ?? opening }

    /// Les humeurs qui alternent deux images, le temps d'une attente réseau. Les autres se
    /// jouent une fois, puis Mika garde sa pose.
    var loops: Bool {
        switch self {
        case .think, .write: true
        default: false
        }
    }

    /// Les deux images d'une attente : l'étincelle seule, puis les étincelles qui s'envolent.
    var loopPoses: [MikaStill] {
        switch self {
        case .think: [.think, .write]
        case .write: [.write, .think]
        default: []
        }
    }

    /// La joie se dit aussi du corps : un petit écrasement qui revient, à l'arrivée.
    var squashes: Bool { self == .happy || self == .celebrate }

    /// À l'appui, il répond d'un clin d'œil, puis revient — seulement depuis une expression
    /// qui partage son corps avec le clin d'œil (pas la tristesse, le sommeil, la surprise :
    /// là, seul le petit écrasement répond).
    var winksOnTap: Bool {
        switch rest {
        case .smile, .neutral, .wink, .think, .write: true
        default: false
        }
    }

    /// Durée du geste, en secondes : `onDone` arrive après.
    var duration: Double {
        let gesture = beats.reduce(0) { $0 + $1.after }
        return gesture > 0 ? gesture + 0.3 : 1.2
    }
}

/// Un temps d'un geste de Mika.
struct MikaBeat: Equatable {
    var after: Double
    var pose: MikaStill
}

/// Les expressions, en PNG transparent rogné autour de Mika (`MikaArt.stills` dit où chacune
/// se place). Toutes debout, les tentacules au même endroit : deux expressions se superposent.
enum MikaStill: String, CaseIterable {
    case neutral = "neutre"
    case smile = "sourire"
    case wink = "clin-doeil"
    case wave = "coucou"
    case surprise
    case think = "reflexion"
    case write = "ecriture"
    case sad = "triste"
    case sleep = "sommeil"

    /// Le nom de l'image dans le catalogue.
    var imageName: String { "Mika-\(rawValue)" }

    /// Gardé pour les appelants d'avant : il n'y a qu'une image par expression.
    func imageName(sparkle: MikaSparkle) -> String { imageName }

    /// Où l'expression se place dans le canevas de 512 du kit.
    var rect: CGRect { MikaArt.stills[rawValue] ?? CGRect(x: 74, y: 157, width: 370, height: 358) }
}

/// La couleur de l'étincelle au bout du crayon : blanche à liseré bleu, lisible partout. La
/// valeur reste pour les appelants.
enum MikaSparkle: Equatable {
    case white
    case blue
}

/// Ce qu'il y a derrière Mika.
enum MikaBackdrop: Equatable {
    /// Le papier de l'app, qui suit le thème : une ombre douce le jour, une lueur la nuit.
    case surface
    /// Un fond clair quel que soit le thème.
    case light
    /// Le bleu Micabo, ou un fond sombre et saturé : ni ombre ni lueur ajoutées (la lueur de
    /// ses images suffit).
    case blue
}

/// Le cadre de Mika en entier.
enum MikaFrame: Equatable {
    /// Aucun cadre : Mika debout, ses tentacules sur le bas du carré, une ombre douce dessous.
    case none
    /// **Le nid** : un rond clair — blanc bleuté le jour, graphite éclairé la nuit —, Mika au
    /// milieu.
    case circle
    /// La pastille ronde bleu Micabo, pour une carte forte de la marque.
    case blueCircle
    /// Un carré arrondi bleu Micabo, comme l'icône de l'app.
    case rounded
}

// MARK: - Le cadrage

/// **Où le canevas de 512 du kit tombe dans la vue** : `scale` points par unité du canevas,
/// et le point du canevas qui tombe au coin haut-gauche de la vue.
struct MikaPlacement: Equatable {
    var scale: CGFloat
    var origin: CGPoint

    func frame(of rect: CGRect) -> CGRect {
        CGRect(
            x: (rect.minX - origin.x) * scale,
            y: (rect.minY - origin.y) * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )
    }

    func point(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) * scale, y: (point.y - origin.y) * scale)
    }

    /// Mika debout dans un carré de `side` : ses tentacules au bas du carré, l'étincelle au
    /// haut.
    static func standing(side: CGFloat) -> MikaPlacement {
        let units: CGFloat = 330
        return MikaPlacement(scale: side / units, origin: CGPoint(x: 255 - units / 2, y: 493 - units))
    }

    /// Mika en entier au milieu d'un rond de `side`.
    static func nested(side: CGFloat) -> MikaPlacement {
        let units: CGFloat = 440
        return MikaPlacement(scale: side / units, origin: CGPoint(x: 255 - units / 2, y: 332 - units / 2))
    }
}

// MARK: - Mika en entier

/// **Mika en entier**, pour les moments qui comptent (règle 2).
///
/// Fixe — l'expression de son humeur — quand le mouvement n'a pas sa place : `frozenAt` donné
/// (les rendus), `animates` faux, `\.mikaStill`, sous XCTest. Sinon il respire une fois en
/// arrivant et joue le geste de son humeur (`MikaMood.beats`), puis garde sa pose. Un appui, si
/// `reactsToTap`, le fait sourire d'un clin d'œil avec un petit écrasement. `onDone` arrive à
/// la fin du geste.
///
/// `size` est le côté du carré qu'il occupe.
struct MikaMascot: View {
    var mood: MikaMood
    var size: CGFloat
    var reactsToTap: Bool
    /// Fige Mika sur l'expression de son humeur (rendus, aperçus).
    var frozenAt: Double?
    var backdrop: MikaBackdrop
    var frame: MikaFrame
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

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        switch frame {
        case .none:
            core(.standing(side: size))
                .background(alignment: .bottom) { ground }
        case .circle:
            let night = colorScheme == .dark
            ZStack {
                Circle().fill(MikaNest.fill(night: night))
                Circle().fill(RadialGradient(
                    colors: [MikaNest.light(night: night), MikaNest.light(night: night).opacity(0)],
                    center: .center, startRadius: 0, endRadius: size * 0.5
                ))
                core(.nested(side: size))
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(MikaNest.rim(night: night), lineWidth: max(1, size * 0.014)))
        case .blueCircle:
            pastille(Circle())
        case .rounded:
            pastille(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
        }
    }

    private func core(_ placement: MikaPlacement) -> some View {
        MikaCore(
            mood: mood,
            placement: placement,
            canvas: CGSize(width: size, height: size),
            lives: animates && frozenAt == nil,
            reactsToTap: reactsToTap,
            onDone: onDone
        )
    }

    private func pastille<S: Shape>(_ shape: S) -> some View {
        ZStack {
            shape.fill(MicaboBrand.blue)
            core(.nested(side: size))
        }
        .frame(width: size, height: size)
        .clipShape(shape)
    }

    /// Sous ses tentacules : une ombre douce, posée sur le papier ; la nuit, une lumière douce
    /// derrière lui en plus de la lueur de ses images. Des dégradés, pas de flou.
    @ViewBuilder
    private var ground: some View {
        if backdrop != .blue {
            let night = colorScheme == .dark && backdrop == .surface
            ZStack(alignment: .bottom) {
                if night {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.09), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.5))
                        .frame(width: size, height: size)
                        .offset(y: -size * 0.1)
                }
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.black.opacity(night ? 0.4 : 0.14), Color.black.opacity(0)],
                        center: .center, startRadius: 0, endRadius: size * 0.36
                    ))
                    .frame(width: size * 0.74, height: size * 0.1)
                    .offset(y: size * 0.03)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Mika en demi

/// **Mika en demi**, la forme de tous les jours (règle 1) : le haut de son corps dépasse du
/// bord sur lequel on pose le bas de la vue, coupé net par lui. La vue fait `width` sur
/// `MikaPeek.height(for:)` ; les étincelles d'une fête débordent au-dessus, jamais en dessous.
///
/// Il est déjà là quand l'écran arrive — il ne monte pas de derrière son bord —, respire une
/// fois et joue le geste de son humeur.
struct MikaPeek: View {
    var mood: MikaMood = .idle
    var width: CGFloat = MikaPeek.card
    var reactsToTap = false
    /// Gardé pour les appelants : Mika ne monte plus de derrière son bord.
    var rises = true
    var backdrop: MikaBackdrop = .surface
    var animates = true
    var onDone: (() -> Void)?

    /// Dans une carte : derrière le haut de son bouton, ou au bas de la carte.
    static let card: CGFloat = 92
    /// Sur la ligne d'une question, à côté d'une bulle.
    static let line: CGFloat = 100
    /// L'accueil de Home, au-dessus de la barre de saisie.
    static let hero: CGFloat = 124

    /// **Ce qui dépasse**, dans le canevas de 512 : de l'étincelle au haut des tentacules,
    /// coupé à `window.maxY` — sous les joues et la naissance des bras, jamais à ras des yeux.
    static let window = CGRect(x: 99, y: 174, width: 312, height: 260)
    /// L'air au-dessus de lui (les étincelles d'une fête), en unités du canevas.
    static let headroom: CGFloat = 60
    /// Ce que sa lueur déborde sur les côtés, en unités du canevas.
    static let bleed: CGFloat = 48

    static func height(for width: CGFloat) -> CGFloat { width * window.height / window.width }

    @Environment(\.colorScheme) private var colorScheme

    private var scale: CGFloat { width / Self.window.width }
    private var height: CGFloat { Self.height(for: width) }

    var body: some View {
        let air = Self.headroom * scale
        let placement = MikaPlacement(scale: scale, origin: CGPoint(x: Self.window.minX, y: Self.window.minY - Self.headroom))
        ZStack(alignment: .bottom) {
            if backdrop == .surface, colorScheme == .dark {
                // La nuit, une lumière douce derrière sa tête, en plus de la lueur de ses
                // images : le noir se détache du graphite.
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: width * 0.5))
                    .frame(width: width * 1.05, height: width * 1.05)
                    .offset(y: width * 0.3)
            }
            MikaCore(
                mood: mood,
                placement: placement,
                canvas: CGSize(width: width, height: height + air),
                lives: animates,
                reactsToTap: reactsToTap,
                onDone: onDone
            )
        }
        .frame(width: width, height: height + air, alignment: .bottom)
        // Coupé net en bas, par son bord ; sur les côtés, sa lueur déborde librement.
        .mask(alignment: .bottom) {
            Rectangle().frame(width: width + Self.bleed * scale * 2, height: height + air)
        }
        .frame(width: width, height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }
}

// MARK: - Mika en avatar

/// **Le visage souriant de Mika dans un rond clair**, image fixe : là où il ferait moins de
/// 40 points.
struct MikaAvatar: View {
    var size: CGFloat = 32

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let night = colorScheme == .dark
        Image("Mika-tete")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .background(Circle().fill(MikaNest.fill(night: night)))
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(MikaNest.rim(night: night), lineWidth: 1))
            .accessibilityHidden(true)
    }
}

// MARK: - Le cœur : l'expression, le fondu, le geste

/// **Ce qu'on voit de Mika** : l'image de son expression, et, le temps d'un fondu, l'image
/// d'avant dessous. Tout ce qui bouge est une propriété animée par SwiftUI (opacité, échelle) :
/// Core Animation l'interpole à la cadence de l'écran, hors du fil principal.
private struct MikaCore: View {
    let mood: MikaMood
    let placement: MikaPlacement
    let canvas: CGSize
    /// Le parent permet le mouvement (`animates`, pas de `frozenAt`).
    let lives: Bool
    let reactsToTap: Bool
    let onDone: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill

    /// L'expression à l'écran (`nil` : celle d'où part le geste de l'humeur).
    @State private var pose: MikaStill?
    /// L'expression d'avant, gardée opaque dessous pendant que la nouvelle se pose dessus.
    @State private var under: MikaStill?
    @State private var poseOpacity: Double = 1
    @State private var underOpacity: Double = 1
    @State private var breathed = false
    @State private var squashed = false
    @State private var sparkled = false
    @State private var arrived = false
    @State private var script: Task<Void, Never>?
    @State private var doneTask: Task<Void, Never>?
    @State private var fades = 0
    @State private var token = UUID()

    /// Les expressions changent (des fondus : « Réduire les animations » les garde).
    private var alive: Bool { lives && !forcedStill && !MikaLibrary.isRunningTests }
    /// Le corps bouge (respiration, écrasement, étincelles qui grandissent).
    private var moves: Bool { alive && !reduceMotion }

    private var shown: MikaStill { alive ? (pose ?? mood.opening) : mood.still }

    /// L'échelle du corps, ancrée sous ses tentacules : une respiration de 1,5 % à l'arrivée,
    /// un écrasement de 3 % à l'appui. Jamais de translation.
    private var scaleX: CGFloat { (moves && !breathed ? 0.985 : 1) * (squashed ? 1.03 : 1) }
    private var scaleY: CGFloat { (moves && !breathed ? 0.985 : 1) * (squashed ? 0.97 : 1) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if alive, let under {
                image(under).opacity(underOpacity)
            }
            image(shown).opacity(alive ? poseOpacity : 1)
            if mood == .celebrate {
                MikaSparkles(placement: placement, shown: alive ? sparkled : true, reduceMotion: reduceMotion)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        .scaleEffect(x: scaleX, y: scaleY, anchor: .bottom)
        // Le dessin de Mika ne se retourne pas en arabe : son crayon reste dans sa main droite.
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onTapGesture { react() }
        .allowsHitTesting(reactsToTap)
        .onAppear(perform: arrive)
        .onChange(of: mood) { _, next in
            scheduleDone()
            guard alive else { return }
            if next == .celebrate { sparkled = false }
            play(next)
        }
        .onDisappear {
            script?.cancel()
            doneTask?.cancel()
            MikaStage.shared.end(token)
        }
        .accessibilityHidden(true)
    }

    private func image(_ still: MikaStill) -> some View {
        let frame = placement.frame(of: still.rect)
        return Image(still.imageName)
            .resizable()
            .interpolation(.high)
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
    }

    // MARK: Le temps

    private func arrive() {
        scheduleDone()
        guard alive else { return }
        if arrived {
            // De retour à l'écran : une attente reprend ; un geste joué ne se rejoue pas.
            if mood.loops { play(mood) }
            return
        }
        arrived = true
        // L'expression devient explicite : un changement d'humeur fondra depuis elle.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { pose = mood.opening }
        if moves {
            withAnimation(MicaboMotion.standard.delay(0.05)) { breathed = true }
        }
        play(mood)
    }

    /// **Le geste de l'humeur** : fondu vers l'expression d'où il part, puis ses temps ; une
    /// attente alterne ses deux images. Il prend la scène : un autre Mika en mouvement se pose.
    private func play(_ next: MikaMood) {
        script?.cancel()
        // Un changement d'humeur peut passer d'un corps à un autre (la surprise, le sommeil) :
        // un fondu bref.
        show(next.opening, quick: true)
        if next.squashes { squash(after: 0.12) }
        if next == .celebrate {
            withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion).delay(0.1)) { sparkled = true }
        }
        guard !next.beats.isEmpty || next.loops else { return }
        let token = token
        MikaStage.shared.begin(token) { settle() }
        script = Task { @MainActor in
            if next.loops {
                var index = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1.6))
                    guard !Task.isCancelled else { return }
                    index += 1
                    show(next.loopPoses[index % next.loopPoses.count], slow: true)
                }
            } else {
                for beat in next.beats {
                    try? await Task.sleep(for: .seconds(beat.after))
                    guard !Task.isCancelled else { return }
                    show(beat.pose)
                }
                MikaStage.shared.end(token)
            }
        }
    }

    /// Un autre Mika prend la scène : celui-ci se pose sur la fin de son geste, sans bouger.
    private func settle() {
        script?.cancel()
        script = nil
        if !mood.loops { show(mood.rest) }
    }

    /// **Le fondu enchaîné** : la nouvelle expression se pose sur l'ancienne, qui reste opaque
    /// dessous ; puis l'ancienne s'efface. Le corps, commun aux deux, ne pâlit jamais.
    private func show(_ next: MikaStill, slow: Bool = false, quick: Bool = false) {
        guard next != shown else { return }
        fades += 1
        let fade = fades
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            under = shown
            underOpacity = 1
            pose = next
            poseOpacity = 0
        }
        let curve = slow ? MicaboMotion.gentle : quick ? MicaboMotion.quick : MicaboMotion.standard
        withAnimation(curve, completionCriteria: .logicallyComplete) {
            poseOpacity = 1
        } completion: {
            guard fade == fades else { return }
            withAnimation(MicaboMotion.quick, completionCriteria: .logicallyComplete) {
                underOpacity = 0
            } completion: {
                guard fade == fades else { return }
                under = nil
            }
        }
    }

    /// Le petit écrasement : 3 % plus large, 3 % plus bas, ancré au sol, puis il revient.
    private func squash(after delay: Double = 0) {
        guard moves else { return }
        withAnimation(MicaboMotion.quick.delay(delay)) { squashed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.13) {
            withAnimation(MicaboMotion.standard) { squashed = false }
        }
    }

    private func react() {
        guard reactsToTap else { return }
        Haptics.selection()
        guard alive else { return }
        squash()
        script?.cancel()
        let token = token
        MikaStage.shared.begin(token) { settle() }
        guard mood.winksOnTap else { return }
        let back = mood.loops ? mood.opening : mood.rest
        show(shown == .wink ? .smile : .wink, quick: true)
        script = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            guard !Task.isCancelled else { return }
            show(back, quick: true)
            MikaStage.shared.end(token)
            if mood.loops { play(mood) }
        }
    }

    /// `onDone` arrive à la fin du geste d'une humeur ponctuelle.
    private func scheduleDone() {
        guard onDone != nil, !mood.loops else { return }
        doneTask?.cancel()
        let duration = mood.duration
        doneTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            onDone?()
        }
    }
}

// MARK: - Les étincelles de la fête

/// **Les étincelles autour de Mika qui fête** : des étoiles à quatre branches, comme celle de
/// son crayon — blanches à liseré bleu, et deux jaunes comme le crayon. Dessinées en vecteur,
/// nettes à toutes les tailles ; elles grandissent une fois à l'arrivée, puis restent.
private struct MikaSparkles: View {
    let placement: MikaPlacement
    let shown: Bool
    let reduceMotion: Bool

    /// Centre et rayon dans le canevas de 512, jaune ou blanche : dans l'air autour de sa tête
    /// et de son crayon, jamais sur son visage.
    static let spots: [(x: CGFloat, y: CGFloat, radius: CGFloat, yellow: Bool)] = [
        (104, 196, 19, false),
        (72, 292, 10, true),
        (292, 168, 9, true),
        (452, 268, 14, false),
        (446, 372, 8, true),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.spots.indices, id: \.self) { index in
                let spot = Self.spots[index]
                let center = placement.point(CGPoint(x: spot.x, y: spot.y))
                let radius = spot.radius * placement.scale
                MikaSparkleShape()
                    .fill(spot.yellow ? MicaboBrand.pencil : Color.white)
                    .overlay(
                        MikaSparkleShape()
                            .stroke(spot.yellow ? Color(hex: 0xC98A00) : MicaboBrand.blue, lineWidth: max(1, radius * 0.16))
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.3)
                    .opacity(shown ? 1 : 0)
                    .animation(
                        MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion).delay(Double(index) * 0.05),
                        value: shown
                    )
                    .offset(x: center.x - radius, y: center.y - radius)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Une étoile à quatre branches aux côtés creusés.
struct MikaSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * 0.2
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: c.y - r))
        path.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        path.closeSubpath()
        return path
    }
}

// MARK: - Le nid

/// **Les couleurs du nid** (`MikaFrame.circle`) et de l'avatar : clair le jour, graphite
/// éclairé la nuit. Des constantes, pas les jetons du thème : le rond se lit pareil sur la
/// crème, le blanc d'une carte et le bleu.
enum MikaNest {
    static func fill(night: Bool) -> LinearGradient {
        night
            ? LinearGradient(colors: [Color(hex: 0x41455A), Color(hex: 0x2C2F3B)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white, MicaboBrand.blue50], startPoint: .top, endPoint: .bottom)
    }

    /// La lumière derrière lui.
    static func light(night: Bool) -> Color {
        night ? Color.white.opacity(0.14) : MicaboBrand.blue100
    }

    /// Le filet du bord.
    static func rim(night: Bool) -> Color {
        night ? Color.white.opacity(0.16) : MicaboBrand.blue100
    }
}

// MARK: - Le figé

private struct MikaStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Mika en images fixes**, partout dessous : les rendus de la CI, une liste, un écran qui
    /// veut retenir son mouvement.
    var mikaStill: Bool {
        get { self[MikaStillKey.self] }
        set { self[MikaStillKey.self] = newValue }
    }
}

// MARK: - La scène

enum MikaLibrary {
    /// Vrai dans le processus des tests : ni geste, ni minuterie, des images fixes.
    static let isRunningTests: Bool =
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

/// **La scène** : un seul Mika en mouvement à la fois dans l'app. Le dernier qui commence un
/// geste pose le précédent sur son expression finale. Lue et écrite sur le fil principal
/// seulement (les vues).
final class MikaStage {
    static let shared = MikaStage()

    private var current: (id: UUID, settle: () -> Void)?

    /// Le Mika en mouvement, s'il y en a un.
    var performer: UUID? { current?.id }

    func begin(_ id: UUID, settle: @escaping () -> Void) {
        if let current, current.id != id { current.settle() }
        current = (id, settle)
    }

    func end(_ id: UUID) {
        if current?.id == id { current = nil }
    }
}
