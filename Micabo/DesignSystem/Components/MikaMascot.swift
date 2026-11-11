import ImageIO
import SwiftUI
import UIKit

// MARK: - La mise en scène de Mika (la règle)
//
// Mika est une petite pieuvre noire brillante : la tête, cinq tentacules, et le bras qui tient
// le crayon jaune à l'étincelle. **Trois formes, chacune à sa place, et nulle part ailleurs :**
//
// 1. **En demi, par défaut dans l'app** (`MikaPeek`) : le haut du corps — la tête, les yeux, le
//    bras au crayon, la naissance des tentacules — qui **dépasse d'un bord**, coupé net par lui,
//    comme quelqu'un qui passe la tête : le haut du bouton d'une carte, le bas d'une carte, une
//    ligne sous une question, le haut de la barre de saisie. Toujours la même taille pour le
//    même rôle : `MikaPeek.card` (92 pt) dans une carte, `.line` (100 pt) sur la ligne d'une
//    question ou d'une bulle, `.hero` (124 pt) pour l'accueil de Home. Il monte de derrière son
//    bord en arrivant, fait son geste une fois, puis reste immobile.
//    Home (plan du jour, nouvel élève), Concentration, Calendrier (« Aucun examen »), la série
//    du Profil, les questions de l'onboarding, le paywall, le tuteur, la feuille des supports.
// 2. **En entier, rarement, aux moments qui comptent** (`MikaMascot`) : l'accueil de
//    l'onboarding, le plan révélé, la fête de l'objectif du jour et de la série, une leçon ou un
//    examen blanc terminés, les écrans vides, l'attente d'une génération. Là il saute, fait
//    coucou, écrit — puis s'arrête. 120 à 170 points, debout sur le papier, une ombre douce
//    sous lui.
// 3. **En avatar** (`MikaAvatar`), sa tête dans un rond clair, image fixe : partout où il
//    ferait moins de 40 points (l'en-tête d'une conversation, un message, une rangée).
//
// **Nulle part ailleurs** : pas sur un bouton, pas dans une liste, pas dans une pastille, jamais
// deux fois sur un écran.
//
// **Il vit sur le papier de l'app** : la crème et le blanc des cartes le jour, le graphite la
// nuit, où une lueur discrète derrière lui garde le corps noir lisible. Jamais de scène bleue
// pour lui seul.
//
// **Il est léger** — le moteur, plus bas (`MikaClipStore`, `MikaPlayerView`, `MikaStage`) :
// - **Fixe la plupart du temps** : une pose du catalogue, une image SwiftUI. Il s'anime sur un
//   événement — l'arrivée de l'écran (une fois), une réponse, une réussite, l'attente d'une
//   génération — puis revient à une pose fixe. Seules la réflexion et l'écriture bouclent, le
//   temps d'une attente.
// - **Un seul Mika animé à la fois** dans toute l'app (`MikaStage`) : le dernier arrivé joue,
//   le précédent s'arrête sur sa pose.
// - Les images d'une animation sont **décodées hors du fil principal**, une seule fois, à la
//   taille où elles s'affichent, puis gardées dans un `NSCache` (vidé si la mémoire manque).
//   Core Animation les fait défiler (`CAKeyframeAnimation` sur `contents`) : aucun calcul
//   SwiftUI ni UIKit par image.
// - Arrêt quand la vue quitte l'écran ou que l'app passe en arrière-plan ; « Réduire les
//   animations », une liste (`\.mikaStill`), un Mika de moins de 64 points : fixe.
//
// Le détail, écran par écran : `docs/refonte-knowunity.md` § 9.

/// **Les treize humeurs de Mika.**
///
/// Chacune a une pose fixe (`Mika-<pose>` dans le catalogue) et, sauf le repos et le « non »,
/// une animation (`Resources/Mika/mika-<nom>.webp`).
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos. Toujours fixe.
    case idle
    /// Coucou : il salue d'un tentacule. Accueil, premier lancement.
    case wave
    /// Joie : un saut. Bonne réponse, action réussie.
    case happy
    /// Sommeil : yeux fermés, « z z z ». Liste vide, la nuit.
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
    /// Non : la pose triste, fixe. Mauvaise réponse.
    case shake
    /// Apparition : il tombe du haut et atterrit. Arrivée sur un écran.
    case appear

    var id: String { rawValue }

    /// L'animation de l'humeur (`mika-<nom>.webp`), `nil` pour une humeur toujours fixe.
    var clip: String? {
        switch self {
        case .idle, .shake: nil
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
        case .appear: "apparition"
        }
    }

    /// Les humeurs qui bouclent : l'attente d'une génération, et elle seule. Les autres se
    /// jouent une fois, puis Mika reste sur sa dernière image.
    var loops: Bool {
        switch self {
        case .think, .write: true
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
        case .surprise, .wink, .shake: 1.5
        case .celebrate: 2.67
        case .appear: 1.33
        }
    }

    /// La pose fixe la plus proche.
    var still: MikaStill {
        switch self {
        case .idle, .appear, .look: .neutral
        case .wave: .wave
        // La fête, fixe, est un grand sourire debout : la pose du saut est en l'air.
        case .happy, .celebrate: .smile
        case .sleep: .sleep
        case .think: .think
        case .surprise: .surprise
        case .sad, .shake: .sad
        case .write: .write
        case .wink: .wink
        }
    }
}

/// Les poses fixes, en PNG transparent rogné autour de Mika (`MikaArt.stills` dit où chacune
/// se place).
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

    /// Le nom de l'image dans le catalogue.
    var imageName: String { "Mika-\(rawValue)" }

    /// Gardé pour les appelants d'avant : il n'y a qu'une image par pose.
    func imageName(sparkle: MikaSparkle) -> String { imageName }

    /// Où la pose se place dans le canevas de 512 du kit.
    var rect: CGRect { MikaArt.stills[rawValue] ?? CGRect(x: 101, y: 180, width: 308, height: 312) }
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
    /// Le bleu Micabo, ou un fond sombre et saturé : ni ombre ni lueur.
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

    /// Mika debout dans un carré de `side` : ses tentacules au bas du carré, l'étincelle au
    /// haut ; un saut déborde au-dessus.
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
/// Fixe — la pose de son humeur — quand l'animation n'a pas sa place : `frozenAt` donné (les
/// rendus), `animates` faux, « Réduire les animations », `\.mikaStill`, moins de 64 points,
/// sous XCTest. Sinon il joue son humeur **une fois** en arrivant, puis à chaque changement
/// d'humeur, et reste sur sa dernière image ; la réflexion et l'écriture bouclent. Un appui,
/// si `reactsToTap`, lui fait un saut de joie. `onDone` arrive à la fin d'une humeur jouée une
/// fois (fixe : après sa durée).
///
/// `size` est le côté du carré qu'il occupe.
struct MikaMascot: View {
    var mood: MikaMood
    var size: CGFloat
    var reactsToTap: Bool
    /// Fige Mika sur la pose de son humeur (rendus, aperçus).
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

    /// Sous cette taille, une image fixe.
    static let minimumAnimatedSize: CGFloat = 64

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
            animates: animates && frozenAt == nil && size >= Self.minimumAnimatedSize,
            reactsToTap: reactsToTap,
            playDelay: 0,
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

    /// Sous ses tentacules : une ombre douce le jour, une lueur et une ombre légère la nuit.
    /// Des dégradés, pas de flou : rien à recalculer à chaque image.
    @ViewBuilder
    private var ground: some View {
        if backdrop != .blue {
            let night = colorScheme == .dark && backdrop == .surface
            ZStack(alignment: .bottom) {
                if night {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.13), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.5))
                        .frame(width: size, height: size)
                        .offset(y: -size * 0.08)
                }
                Ellipse()
                    .fill(RadialGradient(
                        colors: [Color.black.opacity(night ? 0.35 : 0.13), Color.black.opacity(0)],
                        center: .center, startRadius: 0, endRadius: size * 0.36
                    ))
                    .frame(width: size * 0.78, height: size * 0.11)
                    .offset(y: size * 0.035)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Mika en demi

/// **Mika en demi**, la forme de tous les jours (règle 1) : le haut de son corps dépasse du
/// bord sur lequel on pose le bas de la vue, coupé net par lui. La vue fait `width` sur
/// `MikaPeek.height(for:)` ; un saut déborde au-dessus, jamais en dessous.
///
/// En arrivant, il monte de derrière son bord, puis joue son humeur une fois.
struct MikaPeek: View {
    var mood: MikaMood = .idle
    var width: CGFloat = MikaPeek.card
    var reactsToTap = false
    /// Faux : il est déjà là (un écran où il ne fait que changer d'humeur).
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

    /// **Ce qui dépasse**, dans le canevas de 512 : de l'étincelle à la naissance des
    /// tentacules, coupé à `window.maxY`.
    static let window = CGRect(x: 99, y: 174, width: 312, height: 236)
    /// L'air au-dessus de lui pour un saut, en unités du canevas.
    static let headroom: CGFloat = 130

    static func height(for width: CGFloat) -> CGFloat { width * window.height / window.width }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill
    @State private var risen = false

    private var scale: CGFloat { width / Self.window.width }
    private var height: CGFloat { Self.height(for: width) }
    private var moves: Bool { rises && !reduceMotion && !forcedStill && !MikaLibrary.isRunningTests }

    var body: some View {
        let air = Self.headroom * scale
        let placement = MikaPlacement(scale: scale, origin: CGPoint(x: Self.window.minX, y: Self.window.minY - Self.headroom))
        ZStack(alignment: .bottom) {
            if backdrop == .surface, colorScheme == .dark {
                // La nuit, une lueur derrière sa tête : le noir se détache du graphite.
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0)], center: .center, startRadius: 0, endRadius: width * 0.5))
                    .frame(width: width * 1.05, height: width * 1.05)
                    .offset(y: width * 0.22)
            }
            MikaCore(
                mood: mood,
                placement: placement,
                canvas: CGSize(width: width, height: height + air),
                animates: animates && width >= MikaMascot.minimumAnimatedSize,
                reactsToTap: reactsToTap,
                playDelay: moves ? 0.35 : 0,
                onDone: onDone
            )
            .offset(y: risen || !moves ? 0 : height * 0.92)
        }
        .frame(width: width, height: height + air, alignment: .bottom)
        .clipped()
        .frame(width: width, height: height, alignment: .bottom)
        .onAppear {
            guard moves, !risen else { return }
            withAnimation(.spring(duration: 0.55, bounce: 0.3).delay(0.12)) { risen = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Mika en avatar

/// **La tête de Mika dans un rond clair**, image fixe : là où il ferait moins de 40 points.
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

// MARK: - Le cœur : la pose, l'animation, le temps

/// La pose fixe, et par-dessus, quand l'animation a sa place, le lecteur Core Animation. La
/// pose s'efface dès que le lecteur montre sa première image et revient quand il se vide.
private struct MikaCore: View {
    let mood: MikaMood
    let placement: MikaPlacement
    let canvas: CGSize
    let animates: Bool
    let reactsToTap: Bool
    /// Le temps de monter de derrière son bord, avant de jouer.
    let playDelay: Double
    let onDone: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mikaStill) private var forcedStill

    /// Le saut d'un appui, joué par-dessus l'humeur.
    @State private var reaction: MikaMood?
    /// Change à chaque nouvelle lecture : l'arrivée, une nouvelle humeur, un appui.
    @State private var take = 0
    @State private var arrived = false
    @State private var showsPlayer = false
    @State private var stillTask: Task<Void, Never>?

    private var isAnimated: Bool {
        animates && !reduceMotion && !forcedStill && !MikaLibrary.isRunningTests
    }

    /// Ce que Mika joue en ce moment.
    private var shown: MikaMood { reaction ?? mood }

    private var request: MikaPlayRequest? {
        guard isAnimated, take > 0, let clip = shown.clip, MikaArt.clips[clip] != nil else { return nil }
        return MikaPlayRequest(clip: clip, loops: reaction == nil && shown.loops, take: take, mood: shown, delay: take == 1 ? playDelay : 0)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            still(shown.still)
                .opacity(showsPlayer ? 0 : 1)
            if isAnimated {
                MikaPlayer(request: request, placement: placement) { event in
                    switch event {
                    case .showing(let showing):
                        if showsPlayer != showing { showsPlayer = showing }
                    case .finished(let played):
                        finish(played)
                    }
                }
                .frame(width: canvas.width, height: canvas.height)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        // Le dessin de Mika ne se retourne pas en arabe : son crayon reste dans sa main droite.
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onTapGesture { react() }
        .allowsHitTesting(reactsToTap)
        .onAppear {
            // Une fois par vie de la vue : revenir sur un onglet ne rejoue pas l'arrivée.
            guard !arrived else { return }
            arrived = true
            take += 1
            scheduleStillDone()
        }
        .onChange(of: mood) { _, _ in
            reaction = nil
            take += 1
            scheduleStillDone()
        }
        .onDisappear { stillTask?.cancel() }
        .accessibilityHidden(true)
    }

    private func still(_ pose: MikaStill) -> some View {
        let frame = placement.frame(of: pose.rect)
        return Image(pose.imageName)
            .resizable()
            .interpolation(.high)
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
    }

    private func react() {
        guard reactsToTap else { return }
        Haptics.selection()
        reaction = .happy
        take += 1
        guard !isAnimated else { return }
        // Fixe : la joie reste un instant, puis Mika revient.
        stillTask?.cancel()
        let current = take
        stillTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled, current == take else { return }
            reaction = nil
        }
    }

    /// La fin d'une lecture « une fois ». La dernière image reste : Mika est revenu à sa pose.
    private func finish(_ played: MikaMood) {
        if let reaction, played == reaction {
            self.reaction = nil
            return
        }
        guard played == mood, !mood.loops else { return }
        onDone?()
    }

    /// Fixe (ou une humeur sans animation), une humeur ponctuelle n'a pas de fin à guetter :
    /// `onDone` arrive après sa durée, comme si elle s'était jouée.
    private func scheduleStillDone() {
        guard onDone != nil, !mood.loops else { return }
        guard !isAnimated || mood.clip == nil else { return }
        stillTask?.cancel()
        let duration = mood.duration
        stillTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            onDone?()
        }
    }
}

// MARK: - Le nid

/// **Les couleurs du nid** (`MikaFrame.circle`) et de l'avatar : clair le jour, graphite
/// éclairé la nuit. Des constantes, pas les jetons du thème : le rond se lit pareil sur la
/// crème, le blanc d'une carte et le bleu.
enum MikaNest {
    static func fill(night: Bool) -> LinearGradient {
        night
            ? LinearGradient(colors: [Color(hex: 0x3A3D4A), Color(hex: 0x2A2C36)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color.white, MicaboBrand.blue50], startPoint: .top, endPoint: .bottom)
    }

    /// La lumière derrière lui.
    static func light(night: Bool) -> Color {
        night ? Color.white.opacity(0.14) : MicaboBrand.blue100
    }

    /// Le filet du bord.
    static func rim(night: Bool) -> Color {
        night ? Color.white.opacity(0.12) : MicaboBrand.blue100
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

// MARK: - Le moteur

enum MikaLibrary {
    /// Vrai dans le processus des tests : ni animation, ni minuterie, des images fixes.
    static let isRunningTests: Bool =
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// L'adresse d'une animation dans l'app, `nil` si elle n'y est pas.
    static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: "mika-\(name)", withExtension: "webp")
    }
}

/// **Les images d'une animation, prêtes à montrer** : décodées, à la taille de l'écran.
final class MikaFrames {
    let images: [CGImage]
    let fps: Double
    /// Le rectangle des images dans le canevas de 512.
    let rect: CGRect
    let bytes: Int

    init(images: [CGImage], fps: Double, rect: CGRect) {
        self.images = images
        self.fps = fps
        self.rect = rect
        bytes = images.reduce(0) { $0 + $1.bytesPerRow * $1.height }
    }

    var duration: Double { Double(images.count) / fps }
}

/// **La réserve des animations** : chaque animation est décodée une fois, hors du fil
/// principal, à la taille où elle s'affiche (pixels par unité du canevas, arrondis), puis
/// gardée dans un `NSCache` — vidé quand la mémoire manque.
enum MikaClipStore {
    /// Le plafond d'une animation décodée : au-delà, une image sur deux, puis plus petit.
    static let budget = 14 << 20

    private static let cache: NSCache<NSString, MikaFrames> = {
        let cache = NSCache<NSString, MikaFrames>()
        cache.name = "Mika"
        cache.totalCostLimit = 40 << 20
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { _ in cache.removeAllObjects() }
        return cache
    }()

    private static let queue = DispatchQueue(label: "app.micabo.mika.frames", qos: .userInitiated)
    private static let lock = NSLock()
    private static var waiting: [String: [(MikaFrames?) -> Void]] = [:]

    /// La finesse demandée, arrondie au dixième (une clé de cache stable), plafonnée à celle
    /// des fichiers : un pixel par unité du canevas.
    static func resolution(_ pixelsPerUnit: CGFloat) -> CGFloat {
        min(1, max(0.2, (pixelsPerUnit * 10).rounded(.up) / 10))
    }

    private static func key(_ name: String, _ resolution: CGFloat) -> String {
        "\(name)@\(Int(resolution * 100))"
    }

    /// Déjà décodée ?
    static func cached(_ name: String, pixelsPerUnit: CGFloat) -> MikaFrames? {
        cache.object(forKey: key(name, resolution(pixelsPerUnit)) as NSString)
    }

    /// Les images de `name`, sur le fil principal, dès qu'elles sont prêtes. Plusieurs Mika qui
    /// demandent la même animation attendent le même décodage.
    static func load(_ name: String, pixelsPerUnit: CGFloat, completion: @escaping (MikaFrames?) -> Void) {
        let resolution = resolution(pixelsPerUnit)
        let key = key(name, resolution)
        if let frames = cache.object(forKey: key as NSString) {
            DispatchQueue.main.async { completion(frames) }
            return
        }
        lock.lock()
        if waiting[key] != nil {
            waiting[key]?.append(completion)
            lock.unlock()
            return
        }
        waiting[key] = [completion]
        lock.unlock()
        queue.async {
            let frames = Self.decode(name, resolution: resolution)
            if let frames {
                Self.cache.setObject(frames, forKey: key as NSString, cost: frames.bytes)
            }
            Self.lock.lock()
            let callbacks = Self.waiting.removeValue(forKey: key) ?? []
            Self.lock.unlock()
            DispatchQueue.main.async {
                for callback in callbacks { callback(frames) }
            }
        }
    }

    /// **Le décodage**, jamais sur le fil principal : chaque image du WebP est lue, puis
    /// redessinée dans un bitmap à sa taille d'affichage — Core Animation n'a plus rien à
    /// décoder au moment de la montrer.
    static func decode(_ name: String, resolution: CGFloat) -> MikaFrames? {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif
        guard let info = MikaArt.clips[name], let url = MikaLibrary.url(for: name),
              let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }

        var resolution = resolution
        var stride = 1
        func bytes(_ resolution: CGFloat, _ stride: Int) -> Int {
            let width = Int((info.rect.width * resolution).rounded())
            let height = Int((info.rect.height * resolution).rounded())
            return (count + stride - 1) / stride * width * height * 4
        }
        // Au-delà du budget : 12 images par seconde, puis une image plus petite.
        if bytes(resolution, stride) > budget, info.fps > 12 { stride = 2 }
        while bytes(resolution, stride) > budget, resolution > 0.3 { resolution -= 0.05 }

        let width = max(1, Int((info.rect.width * resolution).rounded()))
        let height = max(1, Int((info.rect.height * resolution).rounded()))
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmap = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        var images: [CGImage] = []
        images.reserveCapacity(count / stride + 1)
        for index in Swift.stride(from: 0, to: count, by: stride) {
            guard let frame = CGImageSourceCreateImageAtIndex(source, index, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: bitmap)
            else { continue }
            context.interpolationQuality = .high
            context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
            if let image = context.makeImage() { images.append(image) }
        }
        guard !images.isEmpty else { return nil }
        return MikaFrames(images: images, fps: info.fps / Double(stride), rect: info.rect)
    }

    /// Vide la réserve (les tests, la mémoire).
    static func purge() {
        cache.removeAllObjects()
    }
}

/// **La scène** : un seul Mika animé à la fois dans l'app. Le dernier qui commence à jouer
/// arrête le précédent, qui reste sur sa dernière image.
final class MikaStage {
    static let shared = MikaStage()

    private weak var current: MikaPlayerView?

    var isPlaying: Bool { current != nil }

    func begin(_ player: MikaPlayerView) {
        if let current, current !== player { current.stop() }
        current = player
    }

    func end(_ player: MikaPlayerView) {
        if current === player { current = nil }
    }
}

struct MikaPlayRequest: Equatable {
    let clip: String
    let loops: Bool
    /// Une nouvelle valeur rejoue ; la même ne fait rien.
    let take: Int
    let mood: MikaMood
    /// Le temps d'attendre avant la première image (Mika monte de derrière son bord).
    var delay: Double = 0
}

enum MikaPlayerEvent {
    /// Le lecteur montre une image (la pose dessous s'efface), ou plus rien.
    case showing(Bool)
    /// Une lecture « une fois » est finie, ou a été arrêtée.
    case finished(MikaMood)
}

/// Le lecteur, côté SwiftUI : une vue UIKit sans taille propre, que SwiftUI ne remet jamais en
/// page pendant la lecture.
private struct MikaPlayer: UIViewRepresentable {
    let request: MikaPlayRequest?
    let placement: MikaPlacement
    let onEvent: (MikaPlayerEvent) -> Void

    func makeUIView(context: Context) -> MikaPlayerView { MikaPlayerView() }

    func updateUIView(_ view: MikaPlayerView, context: Context) {
        view.onEvent = onEvent
        view.placement = placement
        view.apply(request)
    }

    static func dismantleUIView(_ view: MikaPlayerView, coordinator: Void) {
        view.stop()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MikaPlayerView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions(by: .zero)
    }
}

/// **Le lecteur** : un calque dont Core Animation fait défiler les images (`contents`, en
/// mode discret). Rien ne tourne sur le fil principal pendant la lecture.
final class MikaPlayerView: UIView, CAAnimationDelegate {
    var onEvent: ((MikaPlayerEvent) -> Void)?
    var placement = MikaPlacement(scale: 1, origin: .zero) {
        didSet { if placement != oldValue { setNeedsLayout() } }
    }

    private let figure = CALayer()
    private var take: Int?
    private var token = 0
    /// Le numéro de l'animation en cours : la fin d'une animation remplacée ne compte pas.
    private var animationID = 0
    private var rect: CGRect?
    private var playing: (frames: MikaFrames, loops: Bool, mood: MikaMood)?
    private var pending: (frames: MikaFrames, request: MikaPlayRequest)?
    private var delayTask: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
        figure.contentsGravity = .resize
        figure.actions = ["contents": NSNull(), "bounds": NSNull(), "position": NSNull()]
        layer.addSublayer(figure)
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Une animation tourne sur ce lecteur.
    var isPlaying: Bool { playing != nil }

    private var pixelsPerUnit: CGFloat {
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        return placement.scale * scale
    }

    func apply(_ request: MikaPlayRequest?) {
        guard let request else {
            guard take != nil else { return }
            take = nil
            token += 1
            stop()
            figure.contents = nil
            onEvent?(.showing(false))
            return
        }
        guard request.take != take else { return }
        take = request.take
        token += 1
        let token = token
        delayTask?.cancel()
        MikaClipStore.load(request.clip, pixelsPerUnit: pixelsPerUnit) { [weak self] frames in
            guard let self, self.token == token, let frames else { return }
            if self.window == nil || UIApplication.shared.applicationState == .background {
                // Pas encore à l'écran : il jouera en y arrivant.
                self.pending = (frames, request)
                return
            }
            self.start(frames, request: request, token: token)
        }
    }

    private func start(_ frames: MikaFrames, request: MikaPlayRequest, token: Int) {
        pending = nil
        guard request.delay > 0 else {
            play(frames, loops: request.loops, mood: request.mood)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.token == token, self.window != nil else { return }
            self.play(frames, loops: request.loops, mood: request.mood)
        }
        delayTask = work
        DispatchQueue.main.asyncAfter(deadline: .now() + request.delay, execute: work)
    }

    private func play(_ frames: MikaFrames, loops: Bool, mood: MikaMood) {
        MikaStage.shared.begin(self)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        figure.removeAnimation(forKey: "mika")
        rect = frames.rect
        layoutFigure()
        // La valeur du modèle : ce qui reste quand l'animation se termine.
        figure.contents = loops ? frames.images.first : frames.images.last
        let animation = CAKeyframeAnimation(keyPath: "contents")
        animation.values = frames.images
        animation.calculationMode = .discrete
        let count = frames.images.count
        animation.keyTimes = (0...count).map { NSNumber(value: Double($0) / Double(count)) }
        animation.duration = frames.duration
        animation.repeatCount = loops ? .greatestFiniteMagnitude : 1
        animation.delegate = MikaAnimationDelegate(self)
        animationID += 1
        animation.setValue(animationID, forKey: "mikaID")
        figure.add(animation, forKey: "mika")
        CATransaction.commit()
        playing = (frames, loops, mood)
        onEvent?(.showing(true))
    }

    /// Arrête la lecture : Mika reste sur l'image du modèle (la dernière, ou la première d'une
    /// boucle), et la mémoire des autres images est rendue au cache.
    func stop() {
        delayTask?.cancel()
        pending = nil
        guard playing != nil else { return }
        figure.removeAnimation(forKey: "mika")
    }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard let playing, (anim.value(forKey: "mikaID") as? Int) == animationID else { return }
        self.playing = nil
        MikaStage.shared.end(self)
        if !playing.loops { onEvent?(.finished(playing.mood)) }
    }

    @objc private func background() { stop() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stop()
        } else if let pending {
            start(pending.frames, request: pending.request, token: token)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutFigure()
    }

    private func layoutFigure() {
        guard let rect else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        figure.frame = placement.frame(of: rect)
        figure.contentsScale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        CATransaction.commit()
    }
}

/// Core Animation retient le délégué d'une animation : celui-ci ne retient pas le lecteur.
private final class MikaAnimationDelegate: NSObject, CAAnimationDelegate {
    weak var player: MikaPlayerView?

    init(_ player: MikaPlayerView) { self.player = player }

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        player?.animationDidStop(anim, finished: flag)
    }
}
