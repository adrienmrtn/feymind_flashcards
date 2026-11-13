import SwiftUI

// MARK: - Le dessin de Mika
//
// Mika est **dessiné dans le code** (lot 10) : plus aucune image d'expression. Ce fichier est
// son dessin, repris trait pour trait de la maquette `design/mika-v3/mika.js` (un viewBox de
// 400 × 400, les pieds posés vers y = 344) :
//
// 1. **Une pose** (`MikaPose`) : une quarantaine de nombres — l'ouverture des yeux, les yeux
//    rieurs, les yeux écarquillés, le clin d'œil, le regard, la courbure, la largeur et
//    l'ouverture de la bouche, la bouche ronde, le penché, l'écrasement, le crayon (angle,
//    pivot, prise), l'étincelle, ce qui flotte autour de lui, et ses deux bras, chacun en cinq
//    points de contrôle. C'est un **vecteur** (`VectorArithmetic`) : SwiftUI interpole deux
//    poses, et passer d'une humeur à l'autre est une vraie métamorphose, pas un fondu.
// 2. **Une scène** (`MikaArt.scene`) : la pose devient une liste de pièces peintes (un chemin,
//    une couleur), dans l'ordre du dessin. Les tests lisent cette liste sans rien dessiner.
// 3. **Le rendu** (`MikaArt.paint`) : les pièces partent dans un `Canvas`, à la cadence de
//    l'écran. Tout est vectoriel : Mika est net à 30 points comme à 500.
//
// La mise en scène (les humeurs, les gestes, les trois cadrages) est dans `MikaMascot.swift` ;
// la règle et la façon d'ajouter une humeur, dans `docs/refonte-knowunity.md` § 9.

// MARK: - Les outils

private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

private func unit(_ x: Double) -> Double { Swift.min(1, Swift.max(0, x)) }

/// De 0 à 1 entre `from` et `to`, en douceur aux deux bouts.
private func ramp(_ from: Double, _ to: Double, _ x: Double) -> Double {
    let t = unit((x - from) / (to - from))
    return t * t * (3 - 2 * t)
}

private func radians(_ degrees: Double) -> Double { degrees * Double.pi / 180 }

private func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

private func ellipse(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double) -> Path {
    Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
}

/// `transform`, appliquée autour du point (x, y).
private func about(_ transform: CGAffineTransform, x: Double, y: Double) -> CGAffineTransform {
    CGAffineTransform(translationX: CGFloat(-x), y: CGFloat(-y))
        .concatenating(transform)
        .concatenating(CGAffineTransform(translationX: CGFloat(x), y: CGFloat(y)))
}

// MARK: - Un bras

/// **Un bras de Mika** : cinq points de contrôle — l'épaule, puis deux courbes bout à bout
/// (un contrôle, le coude, un contrôle, la main), tracées d'un trait rond de 46.
///
/// Les quatre points après l'épaule sont rangés **en polaire autour d'elle** (un angle, un
/// rayon) : entre deux poses, le bras tourne autour de l'épaule comme un vrai bras, au lieu de
/// se raccourcir en ligne droite. Chaque bras a sa plage d'angles, pour ne jamais passer à
/// travers le corps.
struct MikaArm: Equatable {
    enum Side {
        case left
        case right

        /// Le début de la plage d'angles du bras (un tour complet à partir de là).
        var floor: Double {
            switch self {
            case .left: -Double.pi / 6
            case .right: -Double.pi * 5 / 6
            }
        }
    }

    /// Dix nombres : l'épaule (x, y), puis quatre fois (angle en radians, rayon). L'angle 0
    /// pointe vers la droite, il grandit vers le bas (le sens des aiguilles à l'écran).
    var lanes: [Double]

    init(lanes: [Double]) {
        self.lanes = lanes
    }

    /// Depuis cinq points du dessin : l'épaule, un contrôle, le coude, un contrôle, la main.
    init(_ side: Side, _ points: [CGPoint]) {
        let shoulder = points[0]
        var lanes: [Double] = [Double(shoulder.x), Double(shoulder.y)]
        for point in points.dropFirst() {
            let dx = Double(point.x - shoulder.x)
            let dy = Double(point.y - shoulder.y)
            var angle = atan2(dy, dx)
            while angle < side.floor { angle += 2 * Double.pi }
            while angle >= side.floor + 2 * Double.pi { angle -= 2 * Double.pi }
            lanes.append(angle)
            lanes.append((dx * dx + dy * dy).squareRoot())
        }
        self.lanes = lanes
    }

    /// Une seule courbe de la maquette (épaule, contrôle, main), coupée en deux en son milieu :
    /// le même trait, en cinq points.
    static func curve(_ side: Side, from start: CGPoint, control: CGPoint, to end: CGPoint) -> MikaArm {
        let first = CGPoint(x: (start.x + control.x) / 2, y: (start.y + control.y) / 2)
        let second = CGPoint(x: (control.x + end.x) / 2, y: (control.y + end.y) / 2)
        let middle = CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
        return MikaArm(side, [start, first, middle, second, end])
    }

    /// Les cinq points, dans le dessin.
    var points: [CGPoint] {
        let x = lanes[0]
        let y = lanes[1]
        var out = [CGPoint(x: x, y: y)]
        for index in 0..<4 {
            let angle = lanes[2 + index * 2]
            let radius = lanes[3 + index * 2]
            out.append(CGPoint(x: x + radius * cos(angle), y: y + radius * sin(angle)))
        }
        return out
    }

    /// La main : le bout du bras.
    var hand: CGPoint { points[4] }

    /// La longueur du bras, de l'épaule à la main en passant par le coude.
    var reach: Double {
        let p = points
        let upper = hypot(Double(p[2].x - p[0].x), Double(p[2].y - p[0].y))
        let lower = hypot(Double(p[4].x - p[2].x), Double(p[4].y - p[2].y))
        return upper + lower
    }

    /// Le même bras, l'avant-bras tourné de `degrees` (positif : dans le sens des aiguilles) :
    /// le balancement d'un coucou.
    func swung(by degrees: Double) -> MikaArm {
        let turn = radians(degrees)
        let shares: [Double] = [0.35, 0.8, 1, 1.1]
        var copy = self
        for index in 0..<4 {
            copy.lanes[2 + index * 2] += turn * shares[index]
        }
        return copy
    }

    // Les bras de la maquette (`left` et `rightArmPath` dans `mika.js`).
    static let leftRest = MikaArm(.left, [pt(110, 232), pt(66, 250), pt(60, 298), pt(58, 318), pt(76, 316)])
    static let leftWave = MikaArm(.left, [pt(106, 214), pt(58, 196), pt(50, 142), pt(48, 124), pt(64, 122)])
    static let leftUp = MikaArm.curve(.left, from: pt(112, 200), control: pt(70, 150), to: pt(74, 96))
    static let rightPencil = MikaArm.curve(.right, from: pt(290, 232), control: pt(340, 240), to: pt(346, 192))
    static let rightUp = MikaArm.curve(.right, from: pt(288, 200), control: pt(330, 150), to: pt(326, 96))
    static let rightRest = MikaArm(.right, [pt(290, 232), pt(334, 250), pt(340, 298), pt(342, 318), pt(324, 316)])
}

// MARK: - Une pose

/// **Une pose de Mika** : tout ce qui change d'une expression à l'autre, en nombres.
///
/// C'est un vecteur : `a + (b - a) * t` est la pose entre `a` et `b`, et c'est ce que SwiftUI
/// calcule à chaque image d'une animation (`MikaFigure.animatableData`). Les valeurs des
/// expressions sont celles de la table `set` de la maquette.
struct MikaPose: Equatable, VectorArithmetic {
    /// Les nombres, rangés par `Lane`.
    var values: [Double]

    private enum Lane {
        static let eyeOpen = 0
        static let eyeHappy = 1
        static let eyeWide = 2
        static let eyeWink = 3
        static let pupilX = 4
        static let pupilY = 5
        static let mouthCurve = 6
        static let mouthWidth = 7
        static let mouthOpen = 8
        static let mouthRound = 9
        static let tilt = 10
        static let squash = 11
        static let pencil = 12
        static let pencilAngle = 13
        static let pencilPivot = 14
        static let pencilLift = 15
        static let spark = 16
        static let sparkX = 17
        static let sparkY = 18
        static let dots = 19
        static let dotsPulse = 20
        static let lines = 21
        static let zzz = 22
        static let confetti = 23
        static let blink = 24
        static let leftArm = 25
        static let rightArm = 35
        static let count = 45
    }

    /// Le nombre de valeurs d'une pose.
    static let count = Lane.count

    init(values: [Double]) {
        self.values = values
    }

    /// **Le repos** : les yeux ouverts, le sourire, le bras gauche le long du corps, le crayon
    /// à l'étincelle dans la main droite (l'expression `idle` de la maquette).
    init() {
        values = [Double](repeating: 0, count: Lane.count)
        eyeOpen = 1
        mouthCurve = 1
        mouthWidth = 16
        pencil = 1
        pencilAngle = 14
        pencilPivot = 42
        pencilLift = 18
        spark = 1
        sparkX = 320
        sparkY = 44
        leftArm = .leftRest
        rightArm = .rightPencil
    }

    // MARK: Le visage

    /// Les yeux : 1 ouverts, 0 fermés (l'arc du sommeil, courbé vers le bas).
    var eyeOpen: Double {
        get { values[Lane.eyeOpen] }
        set { values[Lane.eyeOpen] = newValue }
    }

    /// Les yeux rieurs : à 1, deux arcs courbés vers le haut.
    var eyeHappy: Double {
        get { values[Lane.eyeHappy] }
        set { values[Lane.eyeHappy] = newValue }
    }

    /// Les yeux écarquillés de la surprise.
    var eyeWide: Double {
        get { values[Lane.eyeWide] }
        set { values[Lane.eyeWide] = newValue }
    }

    /// Le clin d'œil : à 1, l'œil droit est un arc rieur, le gauche reste ouvert.
    var eyeWink: Double {
        get { values[Lane.eyeWink] }
        set { values[Lane.eyeWink] = newValue }
    }

    /// Le regard : le décalage des pupilles, en unités du dessin.
    var pupilX: Double {
        get { values[Lane.pupilX] }
        set { values[Lane.pupilX] = newValue }
    }

    var pupilY: Double {
        get { values[Lane.pupilY] }
        set { values[Lane.pupilY] = newValue }
    }

    /// La courbure de la bouche : 1 le sourire, 0,5 le petit sourire, 0 plate, −1 triste.
    var mouthCurve: Double {
        get { values[Lane.mouthCurve] }
        set { values[Lane.mouthCurve] = newValue }
    }

    /// La demi-largeur de la bouche fermée, en unités du dessin.
    var mouthWidth: Double {
        get { values[Lane.mouthWidth] }
        set { values[Lane.mouthWidth] = newValue }
    }

    /// La bouche ouverte : à 1, le grand sourire ouvert, la langue au fond.
    var mouthOpen: Double {
        get { values[Lane.mouthOpen] }
        set { values[Lane.mouthOpen] = newValue }
    }

    /// La bouche ronde de la surprise.
    var mouthRound: Double {
        get { values[Lane.mouthRound] }
        set { values[Lane.mouthRound] = newValue }
    }

    // MARK: Le corps

    /// Le penché, en degrés : la tête glisse de côté, les pieds ne bougent pas.
    var tilt: Double {
        get { values[Lane.tilt] }
        set { values[Lane.tilt] = newValue }
    }

    /// L'écrasement : 0,03 le tasse de 3 % (et l'élargit d'autant), ancré au sol.
    var squash: Double {
        get { values[Lane.squash] }
        set { values[Lane.squash] = newValue }
    }

    /// Le bras gauche, celui du coucou.
    var leftArm: MikaArm {
        get { MikaArm(lanes: Array(values[Lane.leftArm..<Lane.leftArm + 10])) }
        set { values.replaceSubrange(Lane.leftArm..<Lane.leftArm + 10, with: newValue.lanes) }
    }

    /// Le bras droit, celui du crayon.
    var rightArm: MikaArm {
        get { MikaArm(lanes: Array(values[Lane.rightArm..<Lane.rightArm + 10])) }
        set { values.replaceSubrange(Lane.rightArm..<Lane.rightArm + 10, with: newValue.lanes) }
    }

    // MARK: Le crayon et l'étincelle

    /// Le crayon dans la main droite : 1 tenu, 0 rangé (il rentre dans le poing).
    var pencil: Double {
        get { values[Lane.pencil] }
        set { values[Lane.pencil] = newValue }
    }

    /// L'angle du crayon, en degrés (positif : penché vers la droite).
    var pencilAngle: Double {
        get { values[Lane.pencilAngle] }
        set { values[Lane.pencilAngle] = newValue }
    }

    /// Le point autour duquel le crayon tourne : sa hauteur au-dessus du poing.
    var pencilPivot: Double {
        get { values[Lane.pencilPivot] }
        set { values[Lane.pencilPivot] = newValue }
    }

    /// La prise : la hauteur du bas de la gomme au-dessus du centre du poing.
    var pencilLift: Double {
        get { values[Lane.pencilLift] }
        set { values[Lane.pencilLift] = newValue }
    }

    /// L'étincelle : sa taille (1 entière) et sa place dans le dessin.
    var spark: Double {
        get { values[Lane.spark] }
        set { values[Lane.spark] = newValue }
    }

    var sparkX: Double {
        get { values[Lane.sparkX] }
        set { values[Lane.sparkX] = newValue }
    }

    var sparkY: Double {
        get { values[Lane.sparkY] }
        set { values[Lane.sparkY] = newValue }
    }

    // MARK: Autour de lui

    /// Les trois points de la réflexion.
    var dots: Double {
        get { values[Lane.dots] }
        set { values[Lane.dots] = newValue }
    }

    /// L'onde qui passe d'un point à l'autre, de 0 à 1 : l'attente.
    var dotsPulse: Double {
        get { values[Lane.dotsPulse] }
        set { values[Lane.dotsPulse] = newValue }
    }

    /// Les trois traits jaunes de l'écriture.
    var lines: Double {
        get { values[Lane.lines] }
        set { values[Lane.lines] = newValue }
    }

    /// Les deux « z » du sommeil.
    var zzz: Double {
        get { values[Lane.zzz] }
        set { values[Lane.zzz] = newValue }
    }

    /// Les six confettis fixes de la fête (l'image posée : en mouvement, c'est une gerbe).
    var confetti: Double {
        get { values[Lane.confetti] }
        set { values[Lane.confetti] = newValue }
    }

    /// Le clignement, par-dessus l'expression : à 1, les deux yeux sont fermés.
    var blink: Double {
        get { values[Lane.blink] }
        set { values[Lane.blink] = newValue }
    }

    // MARK: Lire une pose

    /// Les yeux sont ouverts : il peut cligner, faire un clin d'œil.
    var eyesOpen: Bool { eyeOpen > 0.5 && eyeHappy < 0.5 }

    /// La même pose, retouchée.
    func with(_ change: (inout MikaPose) -> Void) -> MikaPose {
        var copy = self
        change(&copy)
        return copy
    }

    /// La pose entre `a` et `b` : `t` = 0 donne `a`, 1 donne `b`.
    static func between(_ a: MikaPose, _ b: MikaPose, _ t: Double) -> MikaPose {
        var step = b - a
        step.scale(by: t)
        return a + step
    }

    // MARK: Le vecteur

    static let zero = MikaPose(values: [Double](repeating: 0, count: Lane.count))

    static func + (lhs: MikaPose, rhs: MikaPose) -> MikaPose {
        var out = lhs
        for index in 0..<Swift.min(out.values.count, rhs.values.count) {
            out.values[index] += rhs.values[index]
        }
        return out
    }

    static func - (lhs: MikaPose, rhs: MikaPose) -> MikaPose {
        var out = lhs
        for index in 0..<Swift.min(out.values.count, rhs.values.count) {
            out.values[index] -= rhs.values[index]
        }
        return out
    }

    mutating func scale(by rhs: Double) {
        for index in values.indices {
            values[index] *= rhs
        }
    }

    var magnitudeSquared: Double {
        var sum = 0.0
        for value in values {
            sum += value * value
        }
        return sum
    }
}

extension MikaPose {
    // **Les douze expressions de la maquette** (la table `set`), une par humeur.

    /// Au repos : le sourire, le crayon à l'étincelle.
    static let idle = MikaPose()

    /// La joie : les yeux rieurs, la bouche ouverte.
    static let happy = idle.with {
        $0.eyeHappy = 1
        $0.mouthOpen = 1
    }

    /// Le coucou : le bras gauche levé, la bouche ouverte.
    static let wave = idle.with {
        $0.leftArm = .leftWave
        $0.mouthOpen = 1
    }

    /// Le clin d'œil.
    static let wink = idle.with { $0.eyeWink = 1 }

    /// La fête : les deux bras en l'air, les yeux rieurs, la bouche ouverte, des confettis.
    static let celebrate = idle.with {
        $0.eyeHappy = 1
        $0.mouthOpen = 1
        $0.leftArm = .leftUp
        $0.raisePencil()
        $0.confetti = 1
    }

    /// La réflexion : le regard en l'air, trois points.
    static let think = idle.with {
        $0.pupilX = 8
        $0.pupilY = -13
        $0.smallMouth()
        $0.dots = 1
        $0.spark = 0
    }

    /// L'écriture : le crayon penché vers la tête, trois traits jaunes.
    static let write = idle.with {
        $0.pupilX = 9
        $0.pupilY = -3
        $0.smallMouth()
        $0.pencilAngle = -24
        $0.pencilPivot = 0
        $0.lines = 1
        $0.spark = 0
    }

    /// La surprise : les yeux écarquillés, la bouche ronde.
    static let surprise = idle.with {
        $0.eyeWide = 1
        $0.mouthRound = 1
    }

    /// La tristesse : le regard bas, la bouche à l'envers, le crayon rangé.
    static let sad = idle.with {
        $0.pupilY = 6
        $0.mouthCurve = -1
        $0.mouthWidth = 14
        $0.lowerPencil()
    }

    /// Le sommeil : les yeux fermés, la bouche plate, « z z ».
    static let sleep = idle.with {
        $0.eyeOpen = 0
        $0.mouthCurve = 0
        $0.mouthWidth = 12
        $0.lowerPencil()
        $0.zzz = 1
    }

    /// Attentif : le regard de côté.
    static let look = idle.with {
        $0.pupilX = 10
        $0.pupilY = -2
        $0.smallMouth()
    }

    /// La fierté : le crayon levé, les yeux rieurs.
    static let proud = idle.with {
        $0.eyeHappy = 1
        $0.raisePencil()
    }

    /// Le visage de l'avatar : le repos, sans crayon (à 30 points, il ne serait qu'un trait).
    static let face = idle.with { $0.lowerPencil() }

    /// Le petit sourire des expressions attentives.
    mutating func smallMouth() {
        mouthCurve = 0.5
        mouthWidth = 10
    }

    /// Le bras droit en l'air, le crayon pointé vers le haut, l'étincelle à côté.
    mutating func raisePencil() {
        rightArm = .rightUp
        pencilAngle = -12
        pencilPivot = 36
        pencilLift = 0
        sparkX = 372
        sparkY = 30
    }

    /// Le bras droit le long du corps, sans crayon ni étincelle.
    mutating func lowerPencil() {
        rightArm = .rightRest
        pencil = 0
        spark = 0
    }
}

// MARK: - Les couleurs

/// Une couleur du dessin : un hexadécimal et une opacité.
struct MikaTint: Equatable {
    var hex: UInt32
    var opacity: Double = 1

    var color: Color { Color(hex: hex).opacity(opacity) }
}

/// **Les couleurs de Mika**, dans les deux thèmes : le corps est l'accent de l'app (plus
/// clair sur le marine), les tentacules arrière un cran plus sombres ; le reste ne change pas.
struct MikaPalette: Equatable {
    var body = MikaTint(hex: 0x3870FE)
    var shade = MikaTint(hex: 0x2A5BE0)
    /// L'encre des pupilles, de la bouche et de la mine.
    var ink = MikaTint(hex: 0x14182B)
    var white = MikaTint(hex: 0xFFFFFF)
    var cheek = MikaTint(hex: 0xFF8FA8, opacity: 0.8)
    var pencil = MikaTint(hex: 0xF7B41F)
    var eraser = MikaTint(hex: 0xE3596C)
    var wood = MikaTint(hex: 0xF6DDB6)
    var spark = MikaTint(hex: 0xF7B41F)
    /// Le reflet sur le haut de la tête.
    var shine = MikaTint(hex: 0xFFFFFF, opacity: 0.26)
    var tongue = MikaTint(hex: 0xFF7A8F)
    /// Les points de la réflexion et les « z » du sommeil.
    var air = MikaTint(hex: 0x8FA9FF)
    var green = MikaTint(hex: 0x35C28B)
    /// L'ombre au sol, plate.
    var shadow = MikaTint(hex: 0x14182B, opacity: 0.07)
    /// Le liseré de l'autocollant, pour un fond bleu.
    var sticker = MikaTint(hex: 0xFFFFFF)

    /// Le thème clair.
    static let light = MikaPalette()

    /// Le marine, thème par défaut de l'app.
    static let marine: MikaPalette = {
        var palette = MikaPalette()
        palette.body = MikaTint(hex: 0x5C88FF)
        palette.shade = MikaTint(hex: 0x3F6BE8)
        palette.shadow = MikaTint(hex: 0x000000, opacity: 0.3)
        return palette
    }()

    static func resolved(night: Bool) -> MikaPalette { night ? .marine : .light }

    /// Le disque de l'avatar et du nid : une surface de l'app.
    static func disc(night: Bool) -> Color { Color(hex: night ? 0x171C2C : 0xE4ECFF) }

    /// Le disque posé sous Mika quand le fond est bleu : la surface la plus contrastée.
    static func plate(night: Bool) -> Color { Color(hex: night ? 0x171C2C : 0xFFFFFF) }
}

// MARK: - Les pièces

/// **Une pièce du dessin** : un chemin, rempli ou tracé d'un trait rond.
struct MikaPiece {
    enum Part: Equatable {
        case shadow, sticker, back, limb, head, shine, pencil, fist, spark
        case eye, pupil, glint, lid, cheek, mouth, tongue
        case dots, lines, zzz, confetti
    }

    var part: Part
    var path: Path
    var fill: MikaTint?
    var stroke: MikaTint?
    var lineWidth: Double = 0
    /// Ce qui dépasse de ce chemin n'est pas dessiné (la langue, dans la bouche).
    var clip: Path?
    /// La pièce suit le corps (penché, écrasement) ; sinon elle flotte autour de lui.
    var isBody = true

    static func filled(_ part: Part, _ path: Path, _ tint: MikaTint, body: Bool = true) -> MikaPiece {
        MikaPiece(part: part, path: path, fill: tint, stroke: nil, lineWidth: 0, clip: nil, isBody: body)
    }

    static func stroked(_ part: Part, _ path: Path, _ tint: MikaTint, width: Double, body: Bool = true) -> MikaPiece {
        MikaPiece(part: part, path: path, fill: nil, stroke: tint, lineWidth: width, clip: nil, isBody: body)
    }
}

// MARK: - Le cadrage

/// **Ce qu'on voit du dessin** : une fenêtre dans le viewBox de la maquette, que la vue occupe,
/// et ce que le canevas dessine au-delà (un bras qui se lève, le crayon d'une fête) sans que
/// la mise en page en tienne compte.
struct MikaFraming: Equatable {
    /// La fenêtre de mise en page, en unités du dessin.
    var window: CGRect
    /// Ce que le canevas dessine au-dessus de la fenêtre, en unités.
    var bleedTop: CGFloat = 0
    /// Ce qu'il dessine de chaque côté.
    var bleedSide: CGFloat = 0

    /// **En entier** : la fenêtre de la maquette (`viewBox="-10 -30 420 420"`), les pieds vers
    /// le bas du carré.
    static let full = MikaFraming(window: CGRect(x: -10, y: -30, width: 420, height: 420), bleedTop: 14, bleedSide: 34)

    /// **En demi** : du haut de la tête (et de l'étincelle) jusque sous les joues et la
    /// bouche, coupé net à y = 248 par le bord où il se pose.
    static let peek = MikaFraming(window: CGRect(x: 44, y: -12, width: 312, height: 260), bleedTop: 32, bleedSide: 88)

    /// **En avatar** : le visage en gros plan, que son disque rogne.
    static let avatar = MikaFraming(window: CGRect(x: 50, y: 16, width: 300, height: 300))

    /// **Dans un disque** : Mika en entier, plus petit, la fête comprise.
    static let nest = MikaFraming(window: CGRect(x: -60, y: -82, width: 520, height: 520))

    /// Le cadre de la gerbe de confettis : la même fenêtre, beaucoup d'air autour.
    var burst: MikaFraming {
        MikaFraming(window: window, bleedTop: 180, bleedSide: 150)
    }

    /// La taille du canevas, pour `scale` points par unité.
    func canvasSize(scale: CGFloat) -> CGSize {
        CGSize(width: (window.width + bleedSide * 2) * scale, height: (window.height + bleedTop) * scale)
    }

    /// Du dessin vers le canevas.
    func toView(scale: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: -(window.minX - bleedSide), y: -(window.minY - bleedTop))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
    }
}

// MARK: - Le dessin

/// **Le dessin de Mika** : de la pose aux pièces, des pièces au canevas.
enum MikaArt {
    /// Le sol : le bas de ses tentacules. Rien ne le déplace : le penché et l'écrasement
    /// partent de cette ligne.
    static let ground: Double = 355
    /// L'épaisseur des tentacules et des bras.
    static let limbWidth: Double = 46
    /// L'épaisseur du liseré blanc de l'autocollant (`sticker: 9` dans la maquette).
    static let stickerWidth: Double = 9
    /// Sous cette ligne, le demi-Mika est coupé.
    static let peekCut: Double = Double(MikaFraming.peek.window.maxY)

    // MARK: Ce qui ne bouge pas

    static let head: Path = {
        var path = Path()
        path.move(to: pt(200, 44))
        path.addCurve(to: pt(326, 174), control1: pt(282, 44), control2: pt(326, 104))
        path.addCurve(to: pt(200, 288), control1: pt(326, 244), control2: pt(274, 288))
        path.addCurve(to: pt(74, 174), control1: pt(126, 288), control2: pt(74, 244))
        path.addCurve(to: pt(200, 44), control1: pt(74, 104), control2: pt(118, 44))
        path.closeSubpath()
        return path
    }()

    static let backLeft: Path = {
        var path = Path()
        path.move(to: pt(152, 262))
        path.addQuadCurve(to: pt(134, 326), control: pt(144, 300))
        return path
    }()

    static let backRight: Path = {
        var path = Path()
        path.move(to: pt(248, 262))
        path.addQuadCurve(to: pt(266, 326), control: pt(256, 300))
        return path
    }()

    static let middle: Path = {
        var path = Path()
        path.move(to: pt(200, 270))
        path.addLine(to: pt(200, 332))
        return path
    }()

    static let shine: Path = ellipse(144, 94, 32, 15)
        .applying(about(CGAffineTransform(rotationAngle: CGFloat(radians(-28))), x: 144, y: 94))

    // MARK: Le corps penché, écrasé

    /// **Ce que la pose fait au corps entier** : le penché (la tête glisse de côté, chaque
    /// point reste à sa hauteur) puis l'écrasement (vers le sol). Jamais de translation : un
    /// point posé au sol y reste, aucun point ne monte.
    static func bodyTransform(for pose: MikaPose) -> CGAffineTransform {
        let lean = tan(radians(pose.tilt))
        let shear = CGAffineTransform(a: 1, b: 0, c: CGFloat(-lean), d: 1, tx: CGFloat(lean * ground), ty: 0)
        let squash = pose.squash
        let press = about(CGAffineTransform(scaleX: CGFloat(1 + squash), y: CGFloat(1 - squash)), x: 200, y: ground)
        return shear.concatenating(press)
    }

    // MARK: La scène

    /// **La pose, en pièces peintes**, dans l'ordre du dessin : l'ombre, le liseré, les
    /// tentacules arrière, les bras et le tentacule du milieu, la tête, le reflet, le crayon
    /// et le poing, l'étincelle, les yeux, les joues, la bouche, puis ce qui flotte autour.
    static func scene(_ pose: MikaPose, palette: MikaPalette = .light, shadow: Bool = false, sticker: Double = 0) -> [MikaPiece] {
        var pieces: [MikaPiece] = []
        pieces.reserveCapacity(40)
        let right = pose.rightArm
        let leftLimb = limb(pose.leftArm)
        let rightLimb = limb(right)

        if shadow {
            pieces.append(.filled(.shadow, ellipse(200, 350, 110, 12), palette.shadow, body: false))
        }
        if sticker > 0 {
            for path in [backLeft, backRight, leftLimb, middle, rightLimb] {
                pieces.append(.stroked(.sticker, path, palette.sticker, width: limbWidth + 2 * sticker))
            }
            var plate = MikaPiece.filled(.sticker, head, palette.sticker)
            plate.stroke = palette.sticker
            plate.lineWidth = 2 * sticker
            pieces.append(plate)
        }
        pieces.append(.stroked(.back, backLeft, palette.shade, width: limbWidth))
        pieces.append(.stroked(.back, backRight, palette.shade, width: limbWidth))
        pieces.append(.stroked(.limb, leftLimb, palette.body, width: limbWidth))
        pieces.append(.stroked(.limb, middle, palette.body, width: limbWidth))
        pieces.append(.stroked(.limb, rightLimb, palette.body, width: limbWidth))
        pieces.append(.filled(.head, head, palette.body))
        pieces.append(.filled(.shine, shine, palette.shine))

        pencil(into: &pieces, pose: pose, hand: right.hand, palette: palette)

        let spark = Swift.min(1.25, pose.spark)
        if spark > 0.002 {
            pieces.append(.filled(.spark, star(pose.sparkX, pose.sparkY, 20 * spark), palette.spark))
        }

        eye(into: &pieces, pose: pose, centerX: 158, side: -1, palette: palette)
        eye(into: &pieces, pose: pose, centerX: 242, side: 1, palette: palette)
        pieces.append(.filled(.cheek, ellipse(116, 212, 18, 11), palette.cheek))
        pieces.append(.filled(.cheek, ellipse(284, 212, 18, 11), palette.cheek))

        let mouth = mouthShape(for: pose)
        var lips = MikaPiece.filled(.mouth, mouth.path, palette.ink)
        if mouth.lineWidth > 0.05 {
            lips.stroke = palette.ink
            lips.lineWidth = mouth.lineWidth
        }
        pieces.append(lips)
        if mouth.tongue > 0.02 {
            var tongue = MikaPiece.filled(.tongue, tonguePath(at: mouth.bottom, size: mouth.tongue), palette.tongue)
            tongue.clip = mouth.path
            pieces.append(tongue)
        }

        air(into: &pieces, pose: pose, palette: palette)
        return pieces
    }

    /// Un bras, ou un tentacule : deux courbes bout à bout.
    static func limb(_ arm: MikaArm) -> Path {
        let p = arm.points
        var path = Path()
        path.move(to: p[0])
        path.addQuadCurve(to: p[2], control: p[1])
        path.addQuadCurve(to: p[4], control: p[3])
        return path
    }

    /// L'étincelle : une étoile à quatre branches aux côtés creusés.
    static func star(_ cx: Double, _ cy: Double, _ radius: Double) -> Path {
        let pinch = radius * 0.2
        var path = Path()
        path.move(to: pt(cx, cy - radius))
        path.addQuadCurve(to: pt(cx + radius, cy), control: pt(cx + pinch, cy - pinch))
        path.addQuadCurve(to: pt(cx, cy + radius), control: pt(cx + pinch, cy + pinch))
        path.addQuadCurve(to: pt(cx - radius, cy), control: pt(cx - pinch, cy + pinch))
        path.addQuadCurve(to: pt(cx, cy - radius), control: pt(cx - pinch, cy - pinch))
        path.closeSubpath()
        return path
    }

    // MARK: Le crayon

    /// **Le crayon, dans la main droite** : le corps jaune, la gomme, le bois, la mine ; puis
    /// le poing par-dessus. Il tourne autour d'un point de son axe et, rangé, rentre dans le
    /// poing.
    private static func pencil(into pieces: inout [MikaPiece], pose: MikaPose, hand: CGPoint, palette: MikaPalette) {
        let held = Swift.min(1.15, pose.pencil)
        guard held > 0.002 else { return }
        let x = Double(hand.x)
        let y = Double(hand.y)
        let bottom = y - pose.pencilLift
        let turn = about(CGAffineTransform(rotationAngle: CGFloat(radians(pose.pencilAngle))), x: x, y: y - pose.pencilPivot)
        let grow = about(CGAffineTransform(scaleX: CGFloat(held), y: CGFloat(held)), x: x, y: y)
        let place = turn.concatenating(grow)

        let body = Path(roundedRect: CGRect(x: x - 11, y: bottom - 86, width: 22, height: 84), cornerRadius: 5, style: .circular)
        let eraser = Path(roundedRect: CGRect(x: x - 11, y: bottom - 14, width: 22, height: 14), cornerRadius: 5, style: .circular)
        var wood = Path()
        wood.move(to: pt(x - 11, bottom - 82))
        wood.addLine(to: pt(x, bottom - 110))
        wood.addLine(to: pt(x + 11, bottom - 82))
        wood.closeSubpath()
        var lead = Path()
        lead.move(to: pt(x - 4.5, bottom - 98))
        lead.addLine(to: pt(x, bottom - 110))
        lead.addLine(to: pt(x + 4.5, bottom - 98))
        lead.closeSubpath()

        pieces.append(.filled(.pencil, body.applying(place), palette.pencil))
        pieces.append(.filled(.pencil, eraser.applying(place), palette.eraser))
        pieces.append(.filled(.pencil, wood.applying(place), palette.wood))
        pieces.append(.filled(.pencil, lead.applying(place), palette.ink))
        pieces.append(.filled(.fist, ellipse(x, y, 23, 23), palette.body))
    }

    // MARK: Les yeux

    /// **Un œil.** Ouvert : l'ellipse blanche, la pupille, son reflet. Il se ferme en
    /// s'aplatissant pendant qu'un trait d'encre apparaît puis se courbe : vers le haut pour
    /// un œil rieur, vers le bas pour le sommeil et le clignement. Le sourire, le clin d'œil
    /// et le clignement passent par le même mécanisme.
    private static func eye(into pieces: inout [MikaPiece], pose: MikaPose, centerX: Double, side: Double, palette: MikaPalette) {
        let sleepy = 1 - pose.eyeOpen
        let happy = pose.eyeHappy + (side > 0 ? pose.eyeWink : 0)
        let total = sleepy + happy + pose.blink
        /// 0 : ouvert ; 1 : un arc.
        let closed = unit(total)
        /// 1 : l'arc rieur ; 0 : l'arc du sommeil.
        let smile = total > 0.0001 ? unit(happy / total) : 0
        let wide = unit(pose.eyeWide)

        let half = 20 + 2 * smile
        let endY = 172 + 4 * smile
        let controlY = 184 - 38 * smile
        let restY = (endY + controlY) / 2
        let centerY = mix(166, restY, closed)
        let open = 1 - closed

        if open > 0.002 {
            let radiusX = 28 + 2 * wide
            let radiusY = (34 + 4 * wide) * open
            pieces.append(.filled(.eye, ellipse(centerX, centerY, radiusX, radiusY), palette.white))
            let size = 1 - 0.15 * wide
            let pupilX = centerX - side * 5 + pose.pupilX
            let pupilY = centerY + (6 + pose.pupilY) * open
            pieces.append(.filled(.pupil, ellipse(pupilX, pupilY, 15 * size, 19 * size * open), palette.ink))
            pieces.append(.filled(.glint, ellipse(pupilX - 6, pupilY - 9 * open, 6, 6 * open), palette.white))
        }

        let shown = ramp(0.45, 0.8, closed)
        if shown > 0.002 {
            // D'abord un trait plat sur l'œil aplati, qui se courbe en fin de course.
            let bend = ramp(0.6, 1, closed)
            let y1 = mix(centerY, endY, bend)
            let y2 = mix(centerY, controlY, bend)
            var arc = Path()
            arc.move(to: pt(centerX - half, y1))
            arc.addQuadCurve(to: pt(centerX + half, y1), control: pt(centerX, y2))
            var ink = palette.ink
            ink.opacity *= shown
            pieces.append(.stroked(.lid, arc, ink, width: 8 + smile))
        }
    }

    // MARK: La bouche

    /// **La bouche** : un contour fermé de quatre courbes, qui va du trait (le sourire, la
    /// bouche plate, la tristesse : les deux lèvres confondues) à la bouche ouverte de la
    /// maquette, et à l'ellipse de la surprise. Le trait s'amincit à mesure qu'elle s'ouvre.
    static func mouthShape(for pose: MikaPose) -> (path: Path, bottom: CGPoint, lineWidth: Double, tongue: Double) {
        let curve = pose.mouthCurve
        let half = pose.mouthWidth
        let open = unit(pose.mouthOpen)
        let rounded = unit(pose.mouthRound)

        // Le creux du trait : 16 pour le sourire, −14 pour la tristesse.
        let depth: Double = curve >= 0 ? 16 : 14
        let bend = depth * curve
        // La hauteur des coins : 224 triste, 218 plate, 214 petit sourire, 212 sourire.
        let corner: Double
        if bend <= 0 {
            corner = mix(218, 224, unit(-bend / 14))
        } else if bend <= 8 {
            corner = mix(218, 214, bend / 8)
        } else {
            corner = mix(214, 212, unit((bend - 8) / 8))
        }
        let middle = corner + bend / 2

        // Du trait à la bouche ouverte (178…222 de large, de 208 à 240).
        let left = pt(mix(200 - half, 178, open), mix(corner, 208, open))
        let right = pt(mix(200 + half, 222, open), mix(corner, 208, open))
        let top = pt(200, mix(corner + bend, 206, open))
        let bottom = pt(200, mix(middle, 240, open))
        let bottomRight = pt(mix(200 + half / 2, 218, open), mix(middle, 240, open))
        let bottomLeft = pt(mix(200 - half / 2, 182, open), mix(middle, 240, open))

        // La lèvre du haut coupée en deux, puis tout en cubiques : treize points.
        let topLeft = between(left, top, 0.5)
        let topRight = between(top, right, 0.5)
        let topMiddle = between(topLeft, topRight, 0.5)
        var points: [CGPoint] = [left]
        points.append(contentsOf: cubic(left, topLeft, topMiddle))
        points.append(contentsOf: cubic(topMiddle, topRight, right))
        points.append(contentsOf: cubic(right, bottomRight, bottom))
        points.append(contentsOf: cubic(bottom, bottomLeft, left))

        // La bouche ronde : une ellipse de 11 × 14 autour de (200, 220), aux mêmes treize points.
        if rounded > 0 {
            let k = 0.5522847498
            let rx = 11.0
            let ry = 14.0
            let cy = 220.0
            let circle: [CGPoint] = [
                pt(200 - rx, cy), pt(200 - rx, cy - k * ry), pt(200 - k * rx, cy - ry), pt(200, cy - ry),
                pt(200 + k * rx, cy - ry), pt(200 + rx, cy - k * ry), pt(200 + rx, cy),
                pt(200 + rx, cy + k * ry), pt(200 + k * rx, cy + ry), pt(200, cy + ry),
                pt(200 - k * rx, cy + ry), pt(200 - rx, cy + k * ry), pt(200 - rx, cy),
            ]
            for index in points.indices {
                points[index] = between(points[index], circle[index], rounded)
            }
        }

        var path = Path()
        path.move(to: points[0])
        for segment in 0..<4 {
            let start = 1 + segment * 3
            path.addCurve(to: points[start + 2], control1: points[start], control2: points[start + 1])
        }
        path.closeSubpath()
        return (path, points[9], 7 * (1 - open) * (1 - rounded), open * (1 - rounded))
    }

    private static func between(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        CGPoint(x: mix(Double(a.x), Double(b.x), t), y: mix(Double(a.y), Double(b.y), t))
    }

    /// Une courbe quadratique (début, contrôle, fin), écrite en cubique : ses deux contrôles
    /// et sa fin.
    private static func cubic(_ start: CGPoint, _ control: CGPoint, _ end: CGPoint) -> [CGPoint] {
        [between(start, control, 2.0 / 3.0), between(end, control, 2.0 / 3.0), end]
    }

    /// La langue, au fond de la bouche ouverte : elle grandit avec elle.
    private static func tonguePath(at bottom: CGPoint, size: Double) -> Path {
        let x = Double(bottom.x)
        let y = Double(bottom.y)
        var path = Path()
        path.move(to: pt(x - 12 * size, y - 11 * size))
        path.addQuadCurve(to: pt(x + 12 * size, y - 11 * size), control: pt(x, y - 19 * size))
        path.addQuadCurve(to: pt(x, y), control: pt(x + 8 * size, y))
        path.addQuadCurve(to: pt(x - 12 * size, y - 11 * size), control: pt(x - 8 * size, y))
        path.closeSubpath()
        return path
    }

    // MARK: Autour de lui

    /// Les points de la réflexion, les traits de l'écriture, les « z » du sommeil, les
    /// confettis fixes de la fête : dans l'air, ils ne se penchent pas avec lui.
    private static func air(into pieces: inout [MikaPiece], pose: MikaPose, palette: MikaPalette) {
        let dots = Swift.min(1.25, pose.dots)
        if dots > 0.002 {
            let spots: [(x: Double, y: Double, radius: Double)] = [(318, 20, 9), (346, 8, 11), (378, -6, 13)]
            for (index, spot) in spots.enumerated() {
                // L'onde de l'attente : chaque point gonfle à son tour.
                let phase = pose.dotsPulse * 2 - Double(index) * 0.5 - 0.5
                let bump = Swift.max(0, 1 - abs(phase) * 2)
                let radius = spot.radius * dots * (1 + 0.3 * bump)
                pieces.append(.filled(.dots, ellipse(spot.x, spot.y, radius, radius), palette.air, body: false))
            }
        }

        let lines = unit(pose.lines)
        if lines > 0.002 {
            let strokes: [(x1: Double, y1: Double, x2: Double, y2: Double)] = [(262, 58, 250, 40), (286, 44, 282, 22), (244, 80, 226, 70)]
            for stroke in strokes {
                var path = Path()
                path.move(to: pt(stroke.x1, stroke.y1))
                path.addLine(to: pt(mix(stroke.x1, stroke.x2, lines), mix(stroke.y1, stroke.y2, lines)))
                pieces.append(.stroked(.lines, path, palette.pencil, width: 7, body: false))
            }
        }

        let zzz = Swift.min(1.25, pose.zzz)
        if zzz > 0.002 {
            // Deux « z » : (x, ligne de base, corps), comme les deux textes de la maquette.
            let letters: [(x: Double, y: Double, size: Double)] = [(300, 70, 40), (335, 36, 28)]
            for letter in letters {
                let width = letter.size * 0.5
                let height = letter.size * 0.52
                let weight = letter.size * 0.14
                let x1 = letter.x + weight / 2
                let x2 = letter.x + width - weight / 2
                let y1 = letter.y - height + weight / 2
                let y2 = letter.y - weight / 2
                var path = Path()
                path.move(to: pt(x1, y1))
                path.addLine(to: pt(x2, y1))
                path.addLine(to: pt(x1, y2))
                path.addLine(to: pt(x2, y2))
                let grow = about(CGAffineTransform(scaleX: CGFloat(zzz), y: CGFloat(zzz)), x: (x1 + x2) / 2, y: (y1 + y2) / 2)
                pieces.append(.stroked(.zzz, path.applying(grow), palette.air, width: weight * zzz, body: false))
            }
        }

        let confetti = Swift.min(1.25, pose.confetti)
        if confetti > 0.002 {
            func square(_ x: Double, _ y: Double, _ side: Double, _ degrees: Double, _ tint: MikaTint) {
                let cx = x + side / 2
                let cy = y + side / 2
                let turn = about(CGAffineTransform(rotationAngle: CGFloat(radians(degrees))), x: cx, y: cy)
                let grow = about(CGAffineTransform(scaleX: CGFloat(confetti), y: CGFloat(confetti)), x: cx, y: cy)
                let path = Path(roundedRect: CGRect(x: x, y: y, width: side, height: side), cornerRadius: 3, style: .circular)
                pieces.append(.filled(.confetti, path.applying(turn.concatenating(grow)), tint, body: false))
            }
            func dot(_ x: Double, _ y: Double, _ radius: Double, _ tint: MikaTint) {
                pieces.append(.filled(.confetti, ellipse(x, y, radius * confetti, radius * confetti), tint, body: false))
            }
            square(40, 40, 14, 20, palette.pencil)
            square(350, 150, 12, -15, palette.eraser)
            dot(60, 150, 7, palette.green)
            dot(200, 8, 7, palette.eraser)
            square(120, 0, 12, 30, palette.air)
            square(280, -6, 14, 12, palette.green)
        }
    }

    // MARK: La gerbe de la fête

    /// **Les confettis de la fête, en mouvement** : une gerbe de vingt-deux pièces qui part
    /// en éventail au-dessus de sa tête, ralentit, retombe un peu et s'efface. `progress` va
    /// de 0 à 1 ; à 0 comme à 1, il n'y a rien à dessiner.
    static func burst(_ progress: Double, palette: MikaPalette) -> [MikaPiece] {
        let p = unit(progress)
        guard p > 0, p < 1 else { return [] }
        let away = 1 - pow(1 - p, 3)
        let fade = 1 - ramp(0.62, 1, p)
        let grow = ramp(0, 0.12, p)
        let colors = [palette.pencil, palette.eraser, palette.green, palette.air]
        let count = 22
        var pieces: [MikaPiece] = []
        pieces.reserveCapacity(count)
        for index in 0..<count {
            // Des nombres fixes, tirés de l'indice : la gerbe est la même à chaque fête.
            let i = Double(index)
            let u = (i * 0.618034).truncatingRemainder(dividingBy: 1)
            let v = (i * 0.754877).truncatingRemainder(dividingBy: 1)
            let w = (i * 0.569840).truncatingRemainder(dividingBy: 1)
            let fan = -168 + 156 * ((i + 0.5) / Double(count))
            let angle = radians(fan + (u - 0.5) * 16)
            let reach = 150 + 110 * v
            let startX = 200 + cos(angle) * 96
            let startY = 150 + sin(angle) * 86
            let fall = 90 * p * p * (0.6 + 0.8 * w)
            let x = startX + cos(angle) * reach * away
            let y = startY + sin(angle) * reach * away + fall
            let size = (11 + 4 * w) * grow
            var tint = colors[index % colors.count]
            tint.opacity *= fade
            if index % 3 == 2 {
                pieces.append(.filled(.confetti, ellipse(x, y, size / 2, size / 2), tint, body: false))
            } else {
                let spin = (u - 0.5) * 520 * away + i * 37
                let turn = about(CGAffineTransform(rotationAngle: CGFloat(radians(spin))), x: x, y: y)
                let square = Path(
                    roundedRect: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size),
                    cornerRadius: size * 0.22,
                    style: .circular
                )
                pieces.append(.filled(.confetti, square.applying(turn), tint, body: false))
            }
        }
        return pieces
    }

    // MARK: Le rendu

    /// **Peint les pièces dans un canevas.** `toView` mène du dessin au canevas ; les pièces
    /// du corps prennent en plus le penché et l'écrasement de la pose.
    static func paint(_ pieces: [MikaPiece], pose: MikaPose, in context: inout GraphicsContext, toView: CGAffineTransform) {
        let body = bodyTransform(for: pose).concatenating(toView)
        for piece in pieces {
            var layer = context
            layer.concatenate(piece.isBody ? body : toView)
            if let clip = piece.clip {
                layer.clip(to: clip)
            }
            if let fill = piece.fill {
                layer.fill(piece.path, with: .color(fill.color))
            }
            if let stroke = piece.stroke, piece.lineWidth > 0 {
                layer.stroke(
                    piece.path,
                    with: .color(stroke.color),
                    style: StrokeStyle(lineWidth: CGFloat(piece.lineWidth), lineCap: .round, lineJoin: .round)
                )
            }
        }
    }

    /// **Où une pièce tombe dans le dessin**, trait compris, une fois le corps penché et
    /// écrasé : ce que les tests mesurent.
    static func bounds(of piece: MikaPiece, pose: MikaPose) -> CGRect {
        let reach = CGFloat(piece.lineWidth / 2)
        let box = piece.path.cgPath.boundingBoxOfPath.insetBy(dx: -reach, dy: -reach)
        return piece.isBody ? box.applying(bodyTransform(for: pose)) : box
    }
}
