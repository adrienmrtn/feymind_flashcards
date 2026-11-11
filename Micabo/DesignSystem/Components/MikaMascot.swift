import AVFoundation
import CoreMedia
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
//    ligne d'une question ou d'une bulle, `.hero` (124 pt) pour l'accueil de Home. Il monte de
//    derrière son bord en arrivant, fait son geste une fois, puis garde le sourire.
//    Home (plan du jour, nouvel élève), Concentration, Calendrier (« Aucun examen »), la série
//    du Profil, les questions de l'onboarding, le paywall, le tuteur, la feuille des supports.
// 2. **En entier, rarement, aux moments qui comptent** (`MikaMascot`) : l'accueil de
//    l'onboarding, le plan révélé, la fête de l'objectif du jour et de la série, une leçon ou un
//    examen blanc terminés, les écrans vides, l'attente d'une génération. Là il saute, fait
//    coucou, écrit — puis s'arrête, souriant. 120 à 170 points, debout sur le papier, une ombre
//    douce sous lui.
// 3. **En avatar** (`MikaAvatar`), son visage souriant dans un rond clair, image fixe : partout
//    où il ferait moins de 40 points (l'en-tête d'une conversation, un message, une rangée).
//
// **Nulle part ailleurs** : pas sur un bouton, pas dans une liste, pas dans une pastille, jamais
// deux fois sur un écran.
//
// **Il est attachant** : ses images portent une lueur claire autour de lui (invisible sur la
// crème et le blanc, elle le détache du graphite la nuit et du bleu), une lumière de contour
// sur le noir brillant, des joues roses discrètes ; un geste se termine sur un sourire
// (`MikaMood.afterglow`), jamais sur un regard vide. Tout est cuit dans les images par
// `scripts/mika-assets.py` : rien à calculer pendant l'animation.
//
// **Il est fluide** — le moteur, plus bas (`MikaClipStore`, `MikaPlayerView`, `MikaStage`) :
// - Chaque animation est une **vidéo HEVC avec alpha** (`Resources/Mika/mika-<nom>.mov`),
//   à 24 images par seconde, toutes ses images. Le lecteur est un
//   `AVSampleBufferDisplayLayer` : le **décodeur matériel** décode juste à temps et le serveur
//   d'affichage montre chaque image à son heure, sur sa propre horloge — un fil principal occupé
//   (une page qui se construit) ne fait sauter aucune image. Mémoire : la vidéo compressée
//   (quelques centaines de Ko) et deux ou trois images décodées.
// - **Démarrage instantané** : les vidéos compressées sont lues en mémoire hors du fil
//   principal dès le premier Mika affiché (toutes, 6 Mo) ; la première image de chaque vidéo
//   existe aussi en image fixe (`Mika-clip-<nom>`), au pixel près : elle est à l'écran pendant
//   que le décodeur prépare la vidéo, qui prend sa place sans flash ni saut.
// - **Fixe la plupart du temps** : il s'anime sur un événement — l'arrivée de l'écran (une
//   fois), une réponse, une réussite, l'attente d'une génération — puis garde sa pose. Seules la
//   réflexion et l'écriture bouclent, le temps d'une attente.
// - **Un seul Mika animé à la fois** dans toute l'app (`MikaStage`) : le dernier arrivé joue,
//   le précédent s'arrête sur sa pose.
// - Arrêt quand la vue quitte l'écran ou que l'app passe en arrière-plan ; « Réduire les
//   animations », une liste (`\.mikaStill`), un Mika de moins de 64 points : fixe.
// - Aucun son, aucune session audio : la musique de l'élève continue.
//
// Le détail, écran par écran : `docs/refonte-knowunity.md` § 9.

/// **Les treize humeurs de Mika.**
///
/// Chacune a une pose fixe (`Mika-<pose>` dans le catalogue) et, sauf le repos et le « non »,
/// une animation (`Resources/Mika/mika-<nom>.mov`).
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos : son sourire, les yeux plissés. Toujours fixe.
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

    /// L'animation de l'humeur (`mika-<nom>.mov`), `nil` pour une humeur toujours fixe.
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
    /// jouent une fois, puis Mika garde sa pose (`afterglow`).
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

    /// **La pose qui reste après le geste** : un sourire, les yeux plissés, pour tous les gestes
    /// joyeux ; `nil` pour la tristesse, le sommeil et l'attente, qui restent sur la première
    /// image de leur animation.
    var afterglow: MikaStill? {
        switch self {
        case .wave, .happy, .celebrate, .wink, .surprise, .appear, .look: .smile
        case .idle, .shake, .sad, .sleep, .think, .write: nil
        }
    }

    /// La pose fixe la plus proche : ce qu'on voit quand il ne s'anime pas (rendus, « Réduire
    /// les animations », petit Mika).
    var still: MikaStill {
        switch self {
        // Au repos, il sourit : jamais un regard vide.
        case .idle: .smile
        case .appear, .look: .neutral
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
/// d'humeur, puis garde le sourire ; la réflexion et l'écriture bouclent. Un appui, si
/// `reactsToTap`, lui fait un saut de joie. `onDone` arrive à la fin d'une humeur jouée une
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

    /// Sous ses tentacules : une ombre douce, posée sur le papier ; la nuit, une lumière douce
    /// derrière lui en plus de la lueur de ses images. Des dégradés, pas de flou : rien à
    /// recalculer pendant l'animation.
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

    /// **Ce qui dépasse**, dans le canevas de 512 : de l'étincelle au haut des tentacules,
    /// coupé à `window.maxY` — sous les joues et la naissance des bras, jamais à ras des yeux.
    static let window = CGRect(x: 99, y: 174, width: 312, height: 260)
    /// L'air au-dessus de lui pour un saut, en unités du canevas.
    static let headroom: CGFloat = 130
    /// Ce que sa lueur déborde sur les côtés, en unités du canevas.
    static let bleed: CGFloat = 48

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
                animates: animates && width >= MikaMascot.minimumAnimatedSize,
                reactsToTap: reactsToTap,
                playDelay: moves ? 0.3 : 0,
                onDone: onDone
            )
            .offset(y: risen || !moves ? 0 : height * 0.92)
        }
        .frame(width: width, height: height + air, alignment: .bottom)
        // Coupé net en bas, par son bord ; sur les côtés, sa lueur déborde librement.
        .mask(alignment: .bottom) {
            Rectangle().frame(width: width + Self.bleed * scale * 2, height: height + air)
        }
        .frame(width: width, height: height, alignment: .bottom)
        .onAppear {
            guard moves, !risen else { return }
            withAnimation(MicaboMotion.standard.delay(0.08)) { risen = true }
        }
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

// MARK: - Le cœur : la pose, la vidéo, le temps

/// Ce qu'on voit de Mika : une image fixe — sa pose, ou la première image de sa vidéo, ou son
/// sourire après un geste — et par-dessus, quand l'animation a sa place, le lecteur vidéo.
/// L'image fixe s'efface quand la vidéo joue et revient, en fondu, quand elle s'arrête.
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
    /// La pose gardée après un geste (`MikaMood.afterglow`).
    @State private var rest: MikaStill?
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
            base
                .opacity(showsPlayer ? 0 : 1)
            if isAnimated {
                MikaPlayer(request: request, placement: placement) { event in
                    switch event {
                    case .started:
                        showsPlayer = true
                    case .interrupted:
                        showsPlayer = false
                    case .ended(let played, let finished):
                        withAnimation(MicaboMotion.quick) {
                            rest = played.afterglow
                            showsPlayer = false
                        }
                        if finished { finish(played) }
                    }
                }
                .frame(width: canvas.width, height: canvas.height)
                .opacity(showsPlayer ? 1 : 0)
            }
        }
        .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
        // Le dessin de Mika ne se retourne pas en arabe : son crayon reste dans sa main droite.
        .environment(\.layoutDirection, .leftToRight)
        .contentShape(Rectangle())
        .onTapGesture { react() }
        .allowsHitTesting(reactsToTap)
        .onAppear {
            if isAnimated { MikaClipStore.warm() }
            // Une fois par vie de la vue : revenir sur un onglet ne rejoue pas l'arrivée.
            guard !arrived else { return }
            arrived = true
            take += 1
            scheduleStillDone()
        }
        .onChange(of: mood) { _, _ in
            reaction = nil
            rest = nil
            take += 1
            scheduleStillDone()
        }
        .onDisappear { stillTask?.cancel() }
        .accessibilityHidden(true)
    }

    /// L'image fixe : la pose de l'humeur sans animation ; sinon le sourire gardé après un
    /// geste, ou la première image de la vidéo qui va jouer (au pixel près).
    @ViewBuilder
    private var base: some View {
        if isAnimated, let rest {
            still(rest)
        } else if isAnimated, let clip = shown.clip, let info = MikaArt.clips[clip] {
            image("Mika-clip-\(clip)", at: info.rect)
        } else {
            still(shown.still)
        }
    }

    private func still(_ pose: MikaStill) -> some View {
        image(pose.imageName, at: pose.rect)
    }

    private func image(_ name: String, at rect: CGRect) -> some View {
        let frame = placement.frame(of: rect)
        return Image(name)
            .resizable()
            .interpolation(.high)
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
    }

    private func react() {
        guard reactsToTap else { return }
        Haptics.selection()
        reaction = .happy
        rest = nil
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

    /// La fin d'une lecture « une fois ».
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

// MARK: - Le moteur

enum MikaLibrary {
    /// Vrai dans le processus des tests : ni animation, ni minuterie, des images fixes.
    static let isRunningTests: Bool =
        NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    /// L'adresse d'une animation dans l'app, `nil` si elle n'y est pas.
    static func url(for name: String) -> URL? {
        Bundle.main.url(forResource: "mika-\(name)", withExtension: "mov")
    }
}

/// **Une animation prête à jouer** : les images compressées de sa vidéo (HEVC avec alpha), en
/// mémoire — quelques centaines de Ko. Le décodeur matériel les décode au moment de les
/// montrer.
final class MikaClip {
    let name: String
    let samples: [CMSampleBuffer]
    let fps: Int32
    /// Le rectangle de la vidéo dans le canevas de 512.
    let rect: CGRect
    let bytes: Int

    init(name: String, samples: [CMSampleBuffer], fps: Int32, rect: CGRect) {
        self.name = name
        self.samples = samples
        self.fps = fps
        self.rect = rect
        bytes = samples.reduce(0) { $0 + CMSampleBufferGetTotalSampleSize($1) }
    }

    var duration: Double { Double(samples.count) / Double(fps) }

    /// L'image `index` de la lecture (au-delà de la fin : la boucle recommence), à son heure.
    func sample(_ index: Int) -> CMSampleBuffer? {
        guard !samples.isEmpty else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: fps),
            presentationTimeStamp: CMTime(value: CMTimeValue(index), timescale: fps),
            decodeTimeStamp: .invalid
        )
        var copy: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault, sampleBuffer: samples[index % samples.count],
            sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleBufferOut: &copy
        )
        return copy
    }
}

/// **La réserve des animations** : chaque vidéo est lue une fois, hors du fil principal, et
/// gardée compressée dans un `NSCache` (vidé si la mémoire manque). Les onze tiennent en
/// quelques Mo ; dès le premier Mika affiché, toutes se lisent en tâche de fond (`warm`) : la
/// première lecture d'une humeur n'attend rien.
enum MikaClipStore {
    private static let cache: NSCache<NSString, MikaClip> = {
        let cache = NSCache<NSString, MikaClip>()
        cache.name = "Mika"
        cache.totalCostLimit = 24 << 20
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil
        ) { _ in cache.removeAllObjects() }
        return cache
    }()

    private static let queue = DispatchQueue(label: "app.micabo.mika.clips", qos: .userInitiated)
    private static let lock = NSLock()
    private static var waiting: [String: [(MikaClip?) -> Void]] = [:]
    private static var warmed = false

    /// Les plus vues d'abord : l'arrivée sur Home, la fête, l'attente.
    static let warmOrder = ["coucou", "clin-doeil", "saut", "celebration", "reflexion", "ecriture",
                            "surprise", "apparition", "regard", "triste", "sommeil"]

    /// Déjà lue ?
    static func cached(_ name: String) -> MikaClip? {
        cache.object(forKey: name as NSString)
    }

    /// Lit toutes les animations en tâche de fond, une fois par lancement.
    static func warm() {
        lock.lock()
        let first = !warmed
        warmed = true
        lock.unlock()
        guard first else { return }
        for name in warmOrder where MikaArt.clips[name] != nil {
            load(name) { _ in }
        }
    }

    /// L'animation `name`, sur le fil principal, dès qu'elle est prête. Plusieurs Mika qui
    /// demandent la même attendent la même lecture.
    static func load(_ name: String, completion: @escaping (MikaClip?) -> Void) {
        if let clip = cache.object(forKey: name as NSString) {
            if Thread.isMainThread { completion(clip) } else { DispatchQueue.main.async { completion(clip) } }
            return
        }
        lock.lock()
        if waiting[name] != nil {
            waiting[name]?.append(completion)
            lock.unlock()
            return
        }
        waiting[name] = [completion]
        lock.unlock()
        queue.async {
            let clip = Self.cached(name) ?? Self.read(name)
            if let clip { Self.cache.setObject(clip, forKey: name as NSString, cost: clip.bytes) }
            Self.lock.lock()
            let callbacks = Self.waiting.removeValue(forKey: name) ?? []
            Self.lock.unlock()
            DispatchQueue.main.async {
                for callback in callbacks { callback(clip) }
            }
        }
    }

    /// **La lecture**, jamais sur le fil principal : les images compressées de la vidéo, telles
    /// quelles (aucun décodage ici).
    static func read(_ name: String) -> MikaClip? {
        #if DEBUG
        dispatchPrecondition(condition: .notOnQueue(.main))
        #endif
        guard let info = MikaArt.clips[name], let url = MikaLibrary.url(for: name) else { return nil }
        let asset = AVURLAsset(url: url)
        let loaded = DispatchSemaphore(value: 0)
        var track: AVAssetTrack?
        asset.loadTracks(withMediaType: .video) { tracks, _ in
            track = tracks?.first
            loaded.signal()
        }
        loaded.wait()
        guard let track, let reader = try? AVAssetReader(asset: asset) else { return nil }
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
        output.alwaysCopiesSampleData = true
        guard reader.canAdd(output) else { return nil }
        reader.add(output)
        guard reader.startReading() else { return nil }
        var samples: [CMSampleBuffer] = []
        while let sample = output.copyNextSampleBuffer() {
            if CMSampleBufferGetNumSamples(sample) > 0 { samples.append(sample) }
        }
        guard reader.status == .completed, !samples.isEmpty else { return nil }
        return MikaClip(name: name, samples: samples, fps: Int32(info.fps), rect: info.rect)
    }

    /// Vide la réserve (les tests, la mémoire).
    static func purge() {
        cache.removeAllObjects()
        lock.lock()
        warmed = false
        lock.unlock()
    }
}

/// **La scène** : un seul Mika animé à la fois dans l'app. Le dernier qui commence à jouer
/// arrête le précédent, qui revient à sa pose fixe.
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
    /// La vidéo joue : l'image fixe dessous s'efface.
    case started
    /// Une lecture remplacée par une autre : l'image fixe revient, sans changer de pose.
    case interrupted
    /// La lecture s'arrête — finie (`finished`), ou arrêtée par un autre Mika, l'arrière-plan,
    /// la sortie de l'écran : la pose d'après le geste revient, en fondu.
    case ended(MikaMood, finished: Bool)
}

/// **Les mesures du lecteur**, pour les tests et le journal : le temps entre la demande et la
/// première image qui bouge (sans le délai voulu de la montée).
enum MikaPerf {
    private static let lock = NSLock()
    private static var _startLatencies: [Double] = []

    static var startLatencies: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return _startLatencies
    }

    static func record(_ seconds: Double) {
        lock.lock()
        _startLatencies.append(seconds)
        if _startLatencies.count > 200 { _startLatencies.removeFirst(100) }
        lock.unlock()
    }
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

/// **Le lecteur** : un `AVSampleBufferDisplayLayer` à qui l'on donne les images compressées de
/// la vidéo, avec sa propre horloge (`controlTimebase`). Le décodeur matériel décode juste à
/// temps, le serveur d'affichage montre chaque image à son heure : rien ne tourne sur le fil
/// principal pendant la lecture, rien ne dépend de lui.
final class MikaPlayerView: UIView {
    var onEvent: ((MikaPlayerEvent) -> Void)?
    var placement = MikaPlacement(scale: 1, origin: .zero) {
        didSet { if placement != oldValue { setNeedsLayout() } }
    }

    /// Le temps laissé au décodeur pour préparer la première image, montrée immobile sur la
    /// même image fixe, avant que l'horloge parte : deux images d'écran.
    static let decodeLead: Double = 0.05

    private let display = AVSampleBufferDisplayLayer()
    private let timebase: CMTimebase?
    private let feedQueue = DispatchQueue(label: "app.micabo.mika.feed", qos: .userInteractive)
    private var take: Int?
    private var token = 0
    private var rect: CGRect?
    private var playing: (clip: MikaClip, loops: Bool, mood: MikaMood)?
    private var pending: (clip: MikaClip, request: MikaPlayRequest)?
    /// Une attente coupée par l'arrière-plan ou un changement d'écran.
    private var resumable: (clip: MikaClip, mood: MikaMood)?
    private var work: [DispatchWorkItem] = []
    private var requestedAt: CFTimeInterval = 0
    private var clearWork: DispatchWorkItem?

    override init(frame: CGRect) {
        var timebase: CMTimebase?
        _ = CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        self.timebase = timebase
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
        display.videoGravity = .resize
        display.isOpaque = false
        display.backgroundColor = UIColor.clear.cgColor
        display.preventsDisplaySleepDuringVideoPlayback = false
        display.actions = ["bounds": NSNull(), "position": NSNull(), "frame": NSNull(), "contents": NSNull()]
        if let timebase {
            CMTimebaseSetRate(timebase, rate: 0)
            CMTimebaseSetTime(timebase, time: .zero)
            display.controlTimebase = timebase
        }
        layer.addSublayer(display)
        NotificationCenter.default.addObserver(self, selector: #selector(background), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(foreground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(failed), name: .AVSampleBufferDisplayLayerFailedToDecode, object: display)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
        display.stopRequestingMediaData()
    }

    /// Une animation tourne sur ce lecteur.
    var isPlaying: Bool { playing != nil }

    func apply(_ request: MikaPlayRequest?) {
        guard let request else {
            guard take != nil else { return }
            take = nil
            token += 1
            resumable = nil
            stop()
            return
        }
        guard request.take != take else { return }
        take = request.take
        token += 1
        resumable = nil
        requestedAt = CACurrentMediaTime()
        if playing != nil {
            halt()
            send(.interrupted)
        }
        let token = token
        MikaClipStore.load(request.clip) { [weak self] clip in
            guard let self, self.token == token, let clip else { return }
            if self.window == nil || UIApplication.shared.applicationState == .background {
                // Pas encore à l'écran : il jouera en y arrivant.
                self.pending = (clip, request)
                return
            }
            self.start(clip, request: request)
        }
    }

    /// **Une lecture** : la vidéo part de sa première image, l'horloge arrêtée ; le décodeur la
    /// prépare (sous l'image fixe identique) ; puis l'horloge part et l'image fixe s'efface.
    private func start(_ clip: MikaClip, request: MikaPlayRequest) {
        pending = nil
        cancelWork()
        clearWork?.cancel()
        MikaStage.shared.begin(self)
        playing = (clip, request.loops, request.mood)
        rect = clip.rect
        layoutDisplay()
        if let timebase {
            CMTimebaseSetRate(timebase, rate: 0)
            CMTimebaseSetTime(timebase, time: .zero)
        }
        feed(clip, loops: request.loops)
        let token = token
        let lead = max(request.delay, Self.decodeLead)
        schedule(after: lead) { [weak self] in
            guard let self, self.token == token, self.playing != nil else { return }
            if let timebase = self.timebase { CMTimebaseSetRate(timebase, rate: 1) }
            MikaPerf.record(CACurrentMediaTime() - self.requestedAt - request.delay)
            self.send(.started)
            guard !request.loops else { return }
            self.schedule(after: clip.duration + 0.02) { [weak self] in
                guard let self, self.token == token, self.playing != nil else { return }
                self.end(finished: true)
            }
        }
    }

    /// Donne au lecteur les images compressées, à mesure qu'il en veut : toute la vidéo pour
    /// une lecture, sans fin pour une boucle.
    private func feed(_ clip: MikaClip, loops: Bool) {
        let display = display
        var index = 0
        let count = clip.samples.count
        feedQueue.async {
            display.stopRequestingMediaData()
            if display.status == .failed { display.flush() }
            display.flushAndRemoveImage()
            display.requestMediaDataWhenReady(on: self.feedQueue) {
                while display.isReadyForMoreMediaData {
                    guard loops || index < count, let sample = clip.sample(index) else {
                        display.stopRequestingMediaData()
                        return
                    }
                    display.enqueue(sample)
                    index += 1
                }
            }
        }
    }

    /// Arrête la lecture, l'image en cours reste le temps du fondu.
    private func halt() {
        cancelWork()
        if let timebase { CMTimebaseSetRate(timebase, rate: 0) }
        let display = display
        feedQueue.async { display.stopRequestingMediaData() }
        playing = nil
        MikaStage.shared.end(self)
    }

    /// La fin d'une lecture : la pose d'après le geste revient en fondu, puis le lecteur se vide.
    private func end(finished: Bool) {
        guard let playing else { return }
        halt()
        send(.ended(playing.mood, finished: finished))
        let clear = DispatchWorkItem { [weak self] in
            guard let self, self.playing == nil else { return }
            let display = self.display
            self.feedQueue.async { display.flushAndRemoveImage() }
        }
        clearWork = clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: clear)
    }

    /// Arrête la lecture. `resumes` : une attente (la réflexion, l'écriture) reprendra quand
    /// la vue revient à l'écran ou l'app au premier plan.
    func stop(resumes: Bool = false) {
        cancelWork()
        pending = nil
        guard let playing else { return }
        if resumes, playing.loops {
            resumable = (playing.clip, playing.mood)
        }
        end(finished: false)
    }

    /// Toujours au tour suivant du fil principal : un événement ne change jamais l'état de
    /// SwiftUI pendant qu'il met la vue à jour (`apply` est appelé de `updateUIView`).
    private func send(_ event: MikaPlayerEvent) {
        DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
    }

    private func schedule(after seconds: Double, _ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)
        work.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    private func cancelWork() {
        work.forEach { $0.cancel() }
        work.removeAll()
    }

    @objc private func background() { stop(resumes: true) }

    @objc private func foreground() { resume() }

    /// Le décodeur a refusé la vidéo : Mika reste sur sa pose, sans rien montrer de cassé.
    @objc private func failed() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.playing != nil else { return }
            self.resumable = nil
            self.end(finished: true)
        }
    }

    private func resume() {
        guard let resumable, window != nil, playing == nil else { return }
        self.resumable = nil
        requestedAt = CACurrentMediaTime()
        start(resumable.clip, request: MikaPlayRequest(clip: resumable.clip.name, loops: true, take: take ?? 0, mood: resumable.mood))
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stop(resumes: true)
        } else if let pending {
            start(pending.clip, request: pending.request)
        } else {
            resume()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutDisplay()
    }

    private func layoutDisplay() {
        guard let rect else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        display.frame = placement.frame(of: rect)
        CATransaction.commit()
    }
}
