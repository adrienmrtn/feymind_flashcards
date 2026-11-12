import SwiftUI
import UIKit

// MARK: - La mise en scène de Mika (la règle)
//
// Mika est un petit personnage **plat, dessiné dans le code** (lot 10) : un corps bleu — l'accent
// de l'app, `#5C88FF` sur le marine, `#3870FE` en thème clair —, de grands yeux, des joues
// roses, cinq tentacules et le bras qui tient le crayon jaune à l'étincelle. Son dessin est
// dans `MikaArt.swift`, sa géométrie dans `design/mika-v3/mika.js`.
//
// **Deux places, et nulle part ailleurs :**
//
// 1. **La bulle** : un petit Mika en entier (76 points) à gauche, sa bulle à droite, en
//    haut de l'écran (`MikaAsk`). C'est lui qui pose les questions, propose la séance, présente
//    l'offre ; il parle à la première personne.
// 2. **Le moment** : un grand Mika en entier (170 à 240 points) au centre — il se présente,
//    prépare le plan, fête une réussite, attend une génération, tient un écran vide. Dessiné
//    en vecteur, il est net à toutes les tailles.
//
// **Trois cadrages** : en entier (`MikaMascot`) ; en demi (`MikaPeek`), du haut de la tête
// jusque sous les joues et la bouche, coupé net par le bord où il se pose ; en avatar
// (`MikaAvatar`), le visage en gros plan dans un disque de la couleur d'une surface, partout
// où il ferait moins de 40 points.
//
// **Jamais directement sur un fond bleu** : il y disparaîtrait. Pour les rares cas,
// `MikaMascot(…).mikaBackdrop(.disc)` pose un disque derrière lui ; `backdrop: .blue` lui
// donne un liseré blanc d'autocollant.
//
// **Il vit par le visage et les bras, sur place** — ni saut, ni translation, ni apparition
// qui grandit. Le moteur, plus bas (`MikaCore`, `MikaDirector`) :
// - **Une pose est un vecteur** (`MikaPose`) : `MikaFigure` est `Animatable`, SwiftUI
//   interpole la pose à la cadence de l'écran avec les courbes de `MicaboMotion`. D'une humeur
//   à l'autre, c'est une métamorphose : l'œil s'aplatit pendant que l'arc rieur apparaît, le
//   bras tourne autour de l'épaule, la bouche s'ouvre.
// - **Un geste, une fois** (`MikaMood.beats`) : le coucou (le bras gauche se lève, balance
//   deux fois, revient), la fête (les deux bras en l'air, une gerbe de confettis de 1,2 s), le
//   clin d'œil, la surprise, la tristesse, le sommeil… puis il garde sa pose.
// - **Deux attentes seulement tournent en boucle** : l'écriture (le crayon oscille) et la
//   réflexion (ses trois points pulsent), le temps qu'une réponse arrive.
// - **À l'appui** (`reactsToTap`) : un écrasement de 3 % et un clin d'œil.
// - **La vie au repos** : un clignement toutes les 3 à 6 secondes, pour un Mika de 64 points
//   et plus, visible à l'écran.
// - **Coût nul au repos** : rien ne se redessine tant que la pose ne change pas. **Un seul
//   Mika en mouvement** à la fois (`MikaStage`). Hors écran, tout s'arrête.
// - « Réduire les animations » : ni geste, ni boucle, ni clignement ; un changement d'humeur
//   est un fondu bref. `\.mikaStill`, `frozenAt`, `animates: false`, les tests : l'expression
//   fixe de l'humeur (`MikaMood.pose`).
//
// Le détail, la règle des deux places et la façon d'ajouter une humeur :
// `docs/refonte-knowunity.md` § 9.

/// **Les quatorze humeurs de Mika** : ce qui se passe, et l'expression qui le dit.
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos : son sourire, le crayon à l'étincelle.
    case idle
    /// Coucou : le bras gauche se lève, balance deux fois, puis revient. Accueil.
    case wave
    /// Joie : les yeux rieurs, la bouche ouverte. Bonne réponse, action réussie.
    case happy
    /// Sommeil : les yeux fermés, « z z ». Liste vide, la nuit.
    case sleep
    /// Réflexion : le regard en l'air, trois points qui pulsent. Chargement, l'IA lit le cours.
    case think
    /// Surprise : les yeux écarquillés, la bouche ronde. Nouveauté, récompense.
    case surprise
    /// Célébration : les deux bras en l'air, les yeux rieurs, des confettis. Leçon finie,
    /// objectif atteint.
    case celebrate
    /// Tristesse : le regard bas, le crayon rangé. Erreur, hors-ligne.
    case sad
    /// Écriture : le crayon oscille près de sa tête. Génération en cours.
    case write
    /// Clin d'œil : encouragement, astuce, « à toi ».
    case wink
    /// Attentif : il regarde de côté. Écran vide, une lecture en cours.
    case look
    /// Non : la tristesse, et la tête qui se penche d'un côté puis de l'autre. Mauvaise réponse.
    case shake
    /// Arrivée : il regarde, puis sourit.
    case appear
    /// Fierté : le crayon levé, les yeux rieurs. Un palier, un record, un plan prêt.
    case proud

    var id: String { rawValue }

    /// **L'expression qui dit l'humeur**, fixe : ce qu'on voit dans les rendus, avec
    /// `\.mikaStill`, et le temps fort du geste.
    var pose: MikaPose {
        switch self {
        case .idle, .appear: .idle
        case .wave: .wave
        case .happy: .happy
        case .sleep: .sleep
        case .think: .think
        case .surprise: .surprise
        case .celebrate: .celebrate
        case .sad, .shake: .sad
        case .write: .write
        case .wink: .wink
        case .look: .look
        case .proud: .proud
        }
    }

    /// La pose de la première image, quand Mika s'anime : il est déjà là, au repos, et son
    /// geste part de là.
    var opening: MikaPose {
        switch self {
        case .appear: .look
        default: .idle
        }
    }

    /// **Le geste**, joué une fois à l'arrivée et à chaque changement d'humeur : une suite de
    /// poses, chacune rejointe par une courbe de `MicaboMotion`. La dernière est la pose qui
    /// reste. Tout se passe sur place : aucune pose ne déplace Mika.
    var beats: [MikaBeat] {
        switch self {
        case .idle:
            return [MikaBeat(.idle, .standard)]
        case .wave:
            // Le bras gauche se lève, balance deux fois, puis revient le long du corps.
            let up = MikaPose.wave
            let out = up.with { $0.leftArm = $0.leftArm.swung(by: -14) }
            let back = up.with { $0.leftArm = $0.leftArm.swung(by: 10) }
            return [
                MikaBeat(up, .standard),
                MikaBeat(out, .quick), MikaBeat(back, .quick),
                MikaBeat(out, .quick), MikaBeat(back, .quick),
                MikaBeat(.idle, .standard, delay: 0.08),
            ]
        case .happy:
            // Un petit écrasement de joie, qui revient.
            return [MikaBeat(MikaPose.happy.with { $0.squash = 0.03 }, .quick), MikaBeat(.happy, .standard)]
        case .celebrate:
            // Les deux bras en l'air, qui s'écartent une fois ; les confettis sont une gerbe à
            // part (`MikaArt.burst`), pas les six pièces fixes de l'image.
            let up = MikaPose.celebrate.with { $0.confetti = 0 }
            let wide = up.with {
                $0.leftArm = $0.leftArm.swung(by: -12)
                $0.rightArm = $0.rightArm.swung(by: 12)
            }
            return [MikaBeat(up, .celebrate), MikaBeat(wide, .quick, delay: 0.06), MikaBeat(up, .celebrate)]
        case .wink:
            return [MikaBeat(MikaPose.wink.with { $0.tilt = 3 }, .quick), MikaBeat(.idle, .standard, delay: 0.45)]
        case .surprise:
            return [MikaBeat(.surprise, .celebrate)]
        case .sad:
            return [MikaBeat(.sad, .gentle)]
        case .shake:
            // « Non » : la tête se penche d'un côté, de l'autre, et se pose.
            let sad = MikaPose.sad
            return [
                MikaBeat(sad, .standard),
                MikaBeat(sad.with { $0.tilt = -3 }, .quick), MikaBeat(sad.with { $0.tilt = 3 }, .quick),
                MikaBeat(sad.with { $0.tilt = -2 }, .quick), MikaBeat(sad, .quick),
            ]
        case .sleep:
            return [MikaBeat(.sleep, .gentle)]
        case .think:
            return [MikaBeat(.think, .standard)]
        case .write:
            return [MikaBeat(.write, .standard)]
        case .look:
            return [MikaBeat(.look, .standard)]
        case .appear:
            return [MikaBeat(.look, .standard), MikaBeat(.idle, .standard, delay: 0.5)]
        case .proud:
            return [MikaBeat(.proud, .celebrate)]
        }
    }

    /// **La pose qui reste après le geste.**
    var rest: MikaPose { beats.last?.pose ?? pose }

    /// **L'attente** : les deux seules humeurs qui tournent en boucle, tant qu'elles durent.
    /// L'écriture fait osciller le crayon ; la réflexion fait pulser ses trois points.
    var loop: MikaLoop? {
        switch self {
        case .think:
            MikaLoop(from: .think, to: MikaPose.think.with { $0.dotsPulse = 1 }, curve: .gentle)
        case .write:
            MikaLoop(
                from: .write,
                to: MikaPose.write.with {
                    $0.pencilAngle = -15
                    $0.lines = 0.5
                    $0.pupilX = 7
                    $0.pupilY = -5
                },
                curve: .quick
            )
        default:
            nil
        }
    }

    /// Les humeurs qui tournent en boucle, le temps d'une attente.
    var loops: Bool { loop != nil }

    /// Durée du geste, en secondes : `onDone` arrive après.
    var duration: Double {
        beats.reduce(0) { $0 + $1.delay + $1.curve.duration }
    }

    /// **À l'appui** : un écrasement de 3 % et un clin d'œil, puis il revient. Les yeux déjà
    /// fermés ou la bouche triste ne font pas de clin d'œil : seul l'écrasement répond.
    static func tapBeats(from rest: MikaPose) -> [MikaBeat] {
        guard rest.eyesOpen, rest.mouthCurve >= 0 else {
            return [MikaBeat(rest.with { $0.squash = tapSquash }, .quick), MikaBeat(rest, .standard)]
        }
        let pressed = rest.with {
            $0.squash = tapSquash
            $0.eyeWink = 1
        }
        let winking = rest.with { $0.eyeWink = 1 }
        return [MikaBeat(pressed, .quick), MikaBeat(winking, .quick), MikaBeat(rest, .standard, delay: 0.3)]
    }

    /// **Le clignement** : les yeux se ferment vite, se rouvrent.
    static func blinkBeats(from rest: MikaPose) -> [MikaBeat] {
        [MikaBeat(rest.with { $0.blink = 1 }, .snap), MikaBeat(rest, .quick)]
    }

    /// L'écrasement d'un appui : 3 %.
    static let tapSquash: Double = 0.03
    /// La durée de la gerbe de confettis d'une fête.
    static let confettiSeconds: Double = 1.2
    /// En dessous, un Mika ne cligne pas des yeux.
    static let blinkingSize: CGFloat = 64
    /// Un clignement toutes les 3 à 6 secondes, au hasard.
    static let blinkEvery: ClosedRange<Double> = 3...6
}

/// Les courbes de Mika : celles de `MicaboMotion`, et le battement rapide d'une paupière.
enum MikaCurve: Equatable {
    /// Une paupière qui se ferme : `quick`, deux fois plus vite.
    case snap
    case quick
    case standard
    case gentle
    /// Le seul rebond : les bras d'une fête, des yeux qui s'écarquillent.
    case celebrate

    var animation: Animation {
        switch self {
        case .snap: MicaboMotion.quick.speed(2)
        case .quick: MicaboMotion.quick
        case .standard: MicaboMotion.standard
        case .gentle: MicaboMotion.gentle
        case .celebrate: MicaboMotion.celebrate
        }
    }

    /// La durée de la courbe, en secondes.
    var duration: Double {
        switch self {
        case .snap: 0.11
        case .quick: 0.22
        case .standard: 0.35
        case .gentle: 0.45
        case .celebrate: 0.5
        }
    }
}

/// Un temps d'un geste de Mika : la pose à rejoindre, la courbe du trajet, et le temps que la
/// pose d'avant tient avant de partir.
struct MikaBeat: Equatable {
    var pose: MikaPose
    var curve: MikaCurve
    var delay: Double

    init(_ pose: MikaPose, _ curve: MikaCurve, delay: Double = 0) {
        self.pose = pose
        self.curve = curve
        self.delay = delay
    }
}

/// Une attente : l'aller-retour sans fin entre deux poses, tant que l'humeur dure.
struct MikaLoop: Equatable {
    var from: MikaPose
    var to: MikaPose
    var curve: MikaCurve
}

/// Ce qu'il y a derrière Mika.
enum MikaBackdrop: Equatable {
    /// Le fond de l'app, qui suit le thème.
    case surface
    /// Un fond clair quel que soit le thème.
    case light
    /// Un fond bleu (l'accent de l'app) : Mika prend un liseré blanc d'autocollant, il ne
    /// se pose jamais directement sur du bleu.
    case blue
    /// Un disque de la couleur d'une surface derrière lui, pour un fond bleu ou chargé.
    case disc
    /// Le liseré blanc d'autocollant, quel que soit le fond.
    case sticker

    /// Mika prend son liseré blanc.
    var outlines: Bool { self == .blue || self == .sticker }
}

/// Le cadre de Mika en entier.
enum MikaFrame: Equatable {
    /// Aucun cadre : Mika debout, ses tentacules vers le bas du carré.
    case none
    /// **Le nid** : un disque de la couleur d'une surface, Mika en entier au milieu.
    case circle
    /// Gardé pour les appelants d'avant (une pastille bleue) : le nid.
    case blueCircle
    /// Le nid, en carré arrondi.
    case rounded
}

// MARK: - Mika en entier

/// **Mika en entier** : la bulle (76 points, à côté de ce qu'il dit) et le moment (170 à
/// 240 points, au centre).
///
/// Fixe — l'expression de son humeur — quand le mouvement n'a pas sa place : `frozenAt` donné
/// (les rendus), `animates` faux, `\.mikaStill`, sous XCTest. Sinon il joue le geste de son
/// humeur (`MikaMood.beats`) sur place, puis garde sa pose et cligne des yeux de temps en
/// temps. Un appui, si `reactsToTap`, lui tire un clin d'œil avec un petit écrasement.
/// `onDone` arrive à la fin du geste.
///
/// `size` est le côté du carré qu'il occupe : la fenêtre de la maquette
/// (`viewBox="-10 -30 420 420"`), où son corps tient les trois quarts de la hauteur.
struct MikaMascot: View {
    var mood: MikaMood
    var size: CGFloat
    var reactsToTap: Bool
    /// Fige Mika sur l'expression de son humeur (rendus, aperçus).
    var frozenAt: Double?
    var backdrop: MikaBackdrop
    var frame: MikaFrame
    var animates: Bool
    /// L'ombre plate au sol, sous ses tentacules.
    var shadow: Bool
    var onDone: (() -> Void)?

    init(
        mood: MikaMood = .idle,
        size: CGFloat = 120,
        reactsToTap: Bool = false,
        frozenAt: Double? = nil,
        backdrop: MikaBackdrop = .surface,
        frame: MikaFrame = .none,
        animates: Bool = true,
        shadow: Bool = false,
        onDone: (() -> Void)? = nil
    ) {
        self.mood = mood
        self.size = size
        self.reactsToTap = reactsToTap
        self.frozenAt = frozenAt
        self.backdrop = backdrop
        self.frame = frame
        self.animates = animates
        self.shadow = shadow
        self.onDone = onDone
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.mikaBackdrop) private var placed

    var body: some View {
        let behind = placed ?? backdrop
        if frame == .none, behind != .disc {
            core(.full, shadow: shadow && !behind.outlines, sticker: behind.outlines)
        } else {
            // Le nid : un disque (ou un carré arrondi), Mika en entier au milieu.
            let night = colorScheme == .dark
            let shape = frame == .rounded
                ? AnyShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
                : AnyShape(Circle())
            core(.nest, shadow: false, sticker: false)
                .background(behind == .disc ? MikaPalette.plate(night: night) : MikaPalette.disc(night: night))
                .clipShape(shape)
        }
    }

    private func core(_ framing: MikaFraming, shadow: Bool, sticker: Bool) -> MikaCore {
        MikaCore(
            mood: mood,
            framing: framing,
            width: size,
            lives: animates && frozenAt == nil,
            reactsToTap: reactsToTap,
            shadow: shadow,
            sticker: sticker,
            onDone: onDone
        )
    }
}

// MARK: - Mika en demi

/// **Mika en demi** : du haut de la tête jusque sous les joues et la bouche, coupé net par le
/// bord sur lequel on pose le bas de la vue (une carte, une ligne, le bas de l'écran). La vue
/// fait `width` sur `MikaPeek.height(for:)` ; le crayon d'une fête et ses confettis débordent
/// au-dessus, jamais en dessous.
///
/// Il est déjà là quand l'écran arrive — il ne monte pas de derrière son bord — et joue le
/// geste de son humeur.
struct MikaPeek: View {
    var mood: MikaMood = .idle
    var width: CGFloat = MikaPeek.card
    var reactsToTap = false
    /// Gardé pour les appelants : Mika ne monte pas de derrière son bord.
    var rises = true
    var backdrop: MikaBackdrop = .surface
    var animates = true
    var onDone: (() -> Void)?

    /// Dans une carte : derrière le haut de son bouton, ou au bas de la carte.
    static let card: CGFloat = 92
    /// Sur la ligne d'une question, à côté d'une bulle.
    static let line: CGFloat = 100
    /// L'accueil d'un écran, au-dessus d'une barre.
    static let hero: CGFloat = 124

    /// **Ce qui dépasse**, dans le dessin : de l'air au-dessus de la tête (l'étincelle) jusqu'à
    /// la coupe, sous les joues et la bouche.
    static let window = MikaFraming.peek.window

    static func height(for width: CGFloat) -> CGFloat { width * window.height / window.width }

    @Environment(\.mikaBackdrop) private var placed

    var body: some View {
        let behind = placed ?? backdrop
        MikaCore(
            mood: mood,
            framing: .peek,
            width: width,
            lives: animates,
            reactsToTap: reactsToTap,
            shadow: false,
            // Coupé par un bord, un disque n'a pas de sens : le liseré fait le même travail.
            sticker: behind.outlines || behind == .disc,
            onDone: onDone
        )
    }
}

// MARK: - Mika en avatar

/// **Le visage de Mika en gros plan dans un disque** de la couleur d'une surface, fixe : là
/// où il ferait moins de 40 points (un message, une rangée, une notification).
struct MikaAvatar: View {
    var size: CGFloat = 32

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let night = colorScheme == .dark
        MikaFigure(pose: .face, framing: .avatar, scale: size / MikaFraming.avatar.window.width, night: night)
            .frame(width: size, height: size)
            .background(MikaPalette.disc(night: night))
            .clipShape(Circle())
            // Le dessin de Mika ne se retourne pas en arabe.
            .environment(\.layoutDirection, .leftToRight)
            .accessibilityHidden(true)
    }
}

// MARK: - La figure : une pose, dessinée

/// **Mika dans une pose**, dessiné dans un `Canvas`. La vue est `Animatable` : quand la pose
/// change dans une animation, SwiftUI recalcule la pose intermédiaire à chaque image et le
/// canevas se redessine — une métamorphose, à la cadence de l'écran. Tant que la pose ne
/// change pas, rien ne se redessine.
struct MikaFigure: View, Animatable {
    var pose: MikaPose
    var framing: MikaFraming
    /// Points par unité du dessin.
    var scale: CGFloat
    /// Le marine (thème sombre) ou le thème clair.
    var night = false
    var shadow = false
    /// Le liseré blanc d'autocollant.
    var sticker = false

    var animatableData: MikaPose {
        get { pose }
        set { pose = newValue }
    }

    var body: some View {
        let drawn = self.pose
        let palette = MikaPalette.resolved(night: night)
        let ground = shadow
        let outline: Double = sticker ? MikaArt.stickerWidth : 0
        let toView = framing.toView(scale: scale)
        let size = framing.canvasSize(scale: scale)
        Canvas { context, _ in
            let pieces = MikaArt.scene(drawn, palette: palette, shadow: ground, sticker: outline)
            MikaArt.paint(pieces, pose: drawn, in: &context, toView: toView)
        }
        .frame(width: size.width, height: size.height)
        // Rien ne se dessine hors du canevas : c'est son bord bas qui coupe le demi-Mika.
        .clipped()
    }
}

/// La gerbe de confettis d'une fête, à un instant donné (`progress` de 0 à 1).
private struct MikaBurst: View {
    var progress: Double
    var framing: MikaFraming
    var scale: CGFloat
    var night: Bool

    var body: some View {
        let moment = progress
        let palette = MikaPalette.resolved(night: night)
        let toView = framing.toView(scale: scale)
        let size = framing.canvasSize(scale: scale)
        Canvas { context, _ in
            let pieces = MikaArt.burst(moment, palette: palette)
            MikaArt.paint(pieces, pose: .idle, in: &context, toView: toView)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .allowsHitTesting(false)
    }
}

// MARK: - Le cœur : la pose à l'écran, le geste, la vie

/// **Ce qu'on voit de Mika, et ce qui le fait bouger.** La pose à l'écran est un état ; le
/// metteur en scène (`MikaDirector`) dit vers quelle pose aller, par quelle courbe, et la vue
/// l'anime. Rien d'autre ne tourne : pas d'horloge d'images, pas de minuterie hors du
/// clignement.
private struct MikaCore: View {
    let mood: MikaMood
    let framing: MikaFraming
    /// La largeur de mise en page, en points.
    let width: CGFloat
    /// Le parent permet le mouvement (`animates`, pas de `frozenAt`).
    let lives: Bool
    let reactsToTap: Bool
    let shadow: Bool
    let sticker: Bool
    let onDone: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill
    @Environment(\.colorScheme) private var colorScheme

    /// La pose à l'écran (`nil` : celle d'où part le geste de l'humeur).
    @State private var pose: MikaPose?
    @State private var director = MikaDirector()
    /// La vue est dans la partie visible de sa page.
    @State private var onScreen = true
    /// Une fête de plus : la gerbe de confettis part.
    @State private var bursts = 0

    /// Les poses changent en fondu (« Réduire les animations » le garde).
    private var alive: Bool { lives && !forcedStill && !MikaLibrary.isRunningTests }
    /// Les gestes, les boucles et le clignement jouent.
    private var moves: Bool { alive && !reduceMotion }

    private var scale: CGFloat { width / framing.window.width }
    private var height: CGFloat { framing.window.height * scale }
    private var night: Bool { colorScheme == .dark }

    private var shown: MikaPose {
        guard alive else { return mood.pose }
        return pose ?? (moves ? mood.opening : mood.pose)
    }

    /// L'horloge du clignement tourne : un Mika assez grand, visible, les yeux ouverts.
    private var blinkClock: Bool {
        moves && onScreen && width >= MikaMood.blinkingSize && mood.rest.eyesOpen
    }

    var body: some View {
        MikaFigure(pose: shown, framing: framing, scale: scale, night: night, shadow: shadow, sticker: sticker)
            .overlay(alignment: .bottom) { confetti }
            // Le canevas déborde de la mise en page, en haut et sur les côtés : un bras qui se
            // lève, le crayon d'une fête. En bas, il s'arrête au bord (la coupe du demi).
            .frame(width: width, height: height, alignment: .bottom)
            // Le dessin de Mika ne se retourne pas en arabe : son crayon reste dans sa main droite.
            .environment(\.layoutDirection, .leftToRight)
            .contentShape(Rectangle())
            .onTapGesture { react() }
            .allowsHitTesting(reactsToTap)
            .onGeometryChange(for: Bool.self) { proxy in
                // Dans une page qui défile : visible tant qu'il croise ce qu'elle montre.
                guard let port = proxy.bounds(of: .scrollView) else { return true }
                return port.intersects(CGRect(origin: .zero, size: proxy.size))
            } action: { visible in
                onScreen = visible
            }
            .onAppear { arrive() }
            .onDisappear { director.leave() }
            .onChange(of: mood) { _, next in change(to: next) }
            .onChange(of: onScreen) { _, visible in
                if visible {
                    arrive()
                } else {
                    director.leave()
                }
            }
            .onChange(of: moves) { _, allowed in
                if allowed {
                    arrive()
                } else {
                    settle()
                }
            }
            .task(id: blinkClock) { await blinkWhileResting() }
            .task(id: mood) { await reportDoneWhenStill() }
            .accessibilityHidden(true)
    }

    /// La gerbe de confettis d'une fête : jouée une fois par fête, sur 1,2 seconde, puis plus
    /// rien ne se dessine.
    @ViewBuilder
    private var confetti: some View {
        if moves, mood == .celebrate {
            KeyframeAnimator(initialValue: 1.0, trigger: bursts) { progress in
                MikaBurst(progress: progress, framing: framing.burst, scale: scale, night: night)
            } keyframes: { _ in
                KeyframeTrack {
                    MoveKeyframe(0.0)
                    LinearKeyframe(1.0, duration: MikaMood.confettiSeconds)
                }
            }
        }
    }

    // MARK: Le temps

    private func arrive() {
        guard alive, onScreen else { return }
        guard moves else {
            // « Réduire les animations » : l'expression de l'humeur, posée.
            if pose == nil { pose = mood.pose }
            return
        }
        wire()
        director.appear(mood)
    }

    private func change(to next: MikaMood) {
        guard alive else { return }
        guard moves else {
            withAnimation(MicaboMotion.reduced) { pose = next.pose }
            return
        }
        wire()
        director.change(to: next)
    }

    /// Le mouvement n'est plus permis : tout s'arrête sur l'expression de l'humeur.
    private func settle() {
        director.moves = false
        director.halt()
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { pose = alive ? mood.pose : nil }
    }

    private func react() {
        guard reactsToTap else { return }
        Haptics.selection()
        guard moves else { return }
        wire()
        director.tap()
    }

    /// Branche le metteur en scène sur cette vue : ce qu'il décide, elle l'anime.
    private func wire() {
        director.moves = moves
        director.blinks = width >= MikaMood.blinkingSize
        director.apply = { cue in perform(cue) }
        director.done = onDone
    }

    /// **Joue un temps** : la pose change dans une animation, SwiftUI interpole.
    private func perform(_ cue: MikaCue) {
        if cue.confetti { bursts += 1 }
        guard let curve = cue.curve else {
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { pose = cue.pose }
            return
        }
        var animation = curve.animation
        if cue.delay > 0 { animation = animation.delay(cue.delay) }
        if cue.repeats { animation = animation.repeatForever(autoreverses: true) }
        guard cue.awaits else {
            withAnimation(animation) { pose = cue.pose }
            return
        }
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            pose = cue.pose
        } completion: {
            director.finished(cue)
        }
    }

    /// **La vie au repos** : un clignement toutes les 3 à 6 secondes. C'est la seule horloge de
    /// Mika (un clignement n'a pas d'autre déclencheur que le temps qui passe) ; elle ne
    /// tourne que pour un Mika visible, au repos, et la tâche s'arrête dès que la vue quitte
    /// l'écran ou que le mouvement n'est plus permis.
    private func blinkWhileResting() async {
        guard blinkClock else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: MikaMood.blinkEvery)))
            guard !Task.isCancelled else { return }
            wire()
            director.blink()
        }
    }

    /// Figé (les rendus, « Réduire les animations ») : il n'y a pas de geste à attendre,
    /// `onDone` arrive tout de suite.
    private func reportDoneWhenStill() async {
        guard !moves, let onDone, mood.loop == nil else { return }
        onDone()
    }
}

// MARK: - Le metteur en scène

/// Un temps à jouer : la pose à rejoindre et la façon d'y aller.
struct MikaCue: Equatable {
    /// Le numéro du geste en cours : la fin d'un geste abandonné ne compte plus.
    var run: Int
    var pose: MikaPose
    /// La courbe du trajet ; `nil` : posé d'un coup, sans animation.
    var curve: MikaCurve?
    var delay: Double = 0
    /// L'aller-retour sans fin d'une attente.
    var repeats = false
    /// La fin de ce temps est attendue (`MikaDirector.finished`).
    var awaits = true
    /// La gerbe de confettis part avec ce temps.
    var confetti = false
}

/// **Le metteur en scène d'un Mika** : quel geste joue, où il en est, et ce qui doit
/// s'arrêter. Il ne dessine rien et n'attend rien : il reçoit des événements (l'arrivée, un
/// changement d'humeur, un appui, la fin d'un temps, la sortie de l'écran) et rend les temps à
/// jouer par `apply`. C'est lui que les tests interrogent : un seul Mika en mouvement, rien
/// qui tourne hors écran. Lu et écrit sur le fil principal seulement (les vues).
final class MikaDirector {
    enum Activity: Equatable {
        /// Hors écran : rien ne tourne.
        case offstage
        /// À l'écran, immobile (« Réduire les animations »).
        case still
        /// Au repos sur la pose de son humeur : il peut cligner.
        case resting
        /// Le geste de son humeur.
        case gesturing
        /// L'attente : écriture ou réflexion.
        case looping
        /// La réponse à un appui.
        case reacting
        /// Un clignement.
        case blinking
    }

    private(set) var activity: Activity = .offstage
    private(set) var mood: MikaMood = .idle
    /// Le mouvement est permis : ni figé, ni sous test, ni « Réduire les animations ».
    var moves = false
    /// Assez grand pour cligner des yeux.
    var blinks = false
    /// Où partent les temps à jouer : la vue les anime.
    var apply: ((MikaCue) -> Void)?
    /// La fin du geste d'une humeur ponctuelle.
    var done: (() -> Void)?

    /// Son nom sur la scène.
    let token = UUID()
    private let stage: MikaStage
    private var script: [MikaBeat] = []
    private var step = 0
    private var run = 0
    /// Le geste d'arrivée de l'humeur a été joué : revenir à l'écran ne le rejoue pas.
    private var played = false

    init(stage: MikaStage = .shared) {
        self.stage = stage
    }

    /// Quelque chose tourne : un geste, une attente, une réponse, un clignement.
    var isBusy: Bool {
        switch activity {
        case .gesturing, .looping, .reacting, .blinking: true
        case .offstage, .still, .resting: false
        }
    }

    // MARK: Les événements

    /// Mika arrive à l'écran (ou y revient).
    func appear(_ mood: MikaMood) {
        guard activity == .offstage || activity == .still else { return }
        self.mood = mood
        guard moves else {
            activity = .still
            return
        }
        activity = .resting
        if played {
            // De retour à l'écran : une attente reprend ; un geste déjà joué ne se rejoue pas.
            startLoop()
            return
        }
        played = true
        play(mood.beats, as: .gesturing)
    }

    /// L'humeur change : le geste de la nouvelle part de la pose du moment.
    func change(to mood: MikaMood) {
        self.mood = mood
        guard activity != .offstage else {
            // Hors écran, rien ne joue : le geste attendra le retour.
            played = false
            return
        }
        guard moves else {
            halt()
            return
        }
        played = true
        play(mood.beats, as: .gesturing)
    }

    /// Un appui : l'écrasement et le clin d'œil.
    func tap() {
        guard moves, activity != .offstage, activity != .still else { return }
        play(MikaMood.tapBeats(from: mood.rest), as: .reacting)
    }

    /// L'horloge du clignement a sonné. Il ne cligne qu'au repos, les yeux ouverts, et si
    /// aucun autre Mika n'est en mouvement.
    func blink() {
        guard moves, blinks, activity == .resting, mood.rest.eyesOpen, stage.performer == nil else { return }
        play(MikaMood.blinkBeats(from: mood.rest), as: .blinking)
    }

    /// Un temps est fini : le suivant, ou la fin du geste.
    func finished(_ cue: MikaCue) {
        guard cue.run == run, cue.awaits else { return }
        guard activity == .gesturing || activity == .reacting || activity == .blinking else { return }
        step += 1
        if step < script.count {
            emit()
            return
        }
        let ended = activity
        script = []
        activity = .resting
        if mood.loop != nil {
            startLoop()
        } else {
            stage.end(token)
            if ended == .gesturing { done?() }
        }
    }

    /// Un autre Mika prend la scène : celui-ci se pose sur la fin de son geste.
    func settle() {
        guard isBusy else { return }
        run += 1
        script = []
        activity = .resting
        apply?(MikaCue(run: run, pose: mood.rest, curve: .standard, awaits: false))
    }

    /// Hors écran : tout s'arrête, Mika est posé sur la fin de son geste. Un geste coupé avant
    /// sa fin (personne ne l'a vu) se rejouera au retour.
    func leave() {
        guard activity != .offstage else { return }
        if activity == .gesturing { played = false }
        stop(as: .offstage)
    }

    /// Le mouvement n'est plus permis : même arrêt, il reste à l'écran.
    func halt() {
        stop(as: .still)
    }

    // MARK: Le geste

    private func stop(as next: Activity) {
        let wasBusy = isBusy
        run += 1
        script = []
        activity = next
        stage.end(token)
        if wasBusy {
            apply?(MikaCue(run: run, pose: mood.rest, curve: nil, awaits: false))
        }
    }

    /// Joue une suite de temps. Il prend la scène : un autre Mika en mouvement se pose.
    private func play(_ beats: [MikaBeat], as next: Activity) {
        guard !beats.isEmpty else { return }
        run += 1
        script = beats
        step = 0
        activity = next
        stage.begin(token) { [weak self] in self?.settle() }
        emit()
    }

    private func emit() {
        let beat = script[step]
        var cue = MikaCue(run: run, pose: beat.pose, curve: beat.curve, delay: beat.delay)
        cue.confetti = activity == .gesturing && step == 0 && mood == .celebrate
        apply?(cue)
    }

    /// L'attente de l'humeur : un aller-retour sans fin, jusqu'au prochain événement.
    private func startLoop() {
        guard let loop = mood.loop else { return }
        run += 1
        activity = .looping
        stage.begin(token) { [weak self] in self?.settle() }
        apply?(MikaCue(run: run, pose: loop.to, curve: loop.curve, repeats: true, awaits: false))
    }
}

// MARK: - Le figé, le fond

private struct MikaStillKey: EnvironmentKey {
    static let defaultValue = false
}

private struct MikaBackdropKey: EnvironmentKey {
    static let defaultValue: MikaBackdrop? = nil
}

extension EnvironmentValues {
    /// **Mika en images fixes**, partout dessous : les rendus de la CI, une liste, un écran qui
    /// veut retenir son mouvement.
    var mikaStill: Bool {
        get { self[MikaStillKey.self] }
        set { self[MikaStillKey.self] = newValue }
    }

    /// Ce qu'il y a derrière les Mika du dessous (`View.mikaBackdrop`).
    var mikaBackdrop: MikaBackdrop? {
        get { self[MikaBackdropKey.self] }
        set { self[MikaBackdropKey.self] = newValue }
    }
}

extension View {
    /// **Dit sur quoi Mika est posé.** `MikaMascot(…).mikaBackdrop(.disc)` glisse un disque de
    /// la couleur d'une surface derrière lui : la seule façon de le poser sur un fond bleu.
    func mikaBackdrop(_ backdrop: MikaBackdrop) -> some View {
        environment(\.mikaBackdrop, backdrop)
    }
}

// MARK: - La scène

enum MikaLibrary {
    /// Vrai dans le processus des tests : ni geste, ni minuterie, l'expression fixe.
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
