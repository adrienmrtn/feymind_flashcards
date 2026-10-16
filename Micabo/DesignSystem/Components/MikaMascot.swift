import SwiftUI

/// Les huit humeurs de Mika, celles du design.
enum MikaMood: String, CaseIterable, Identifiable {
    /// Au repos : il respire, cligne, regarde autour de lui. Les écrans calmes.
    case idle
    /// Coucou : l'aile qui salue. Accueil.
    case wave
    /// Joie : il saute, des cœurs. Une bonne réponse, une action réussie.
    case happy
    /// Dodo : les yeux fermés, des « z ». Une liste vide.
    case sleep
    /// Réflexion : une bulle à trois points. Les chargements.
    case think
    /// Surprise : un point d'exclamation. Une nouveauté.
    case surprise
    /// Fête : il saute, des confettis. Une leçon terminée.
    case celebrate
    /// Oups : une larme. Une erreur, une mauvaise réponse.
    case sad

    var id: String { rawValue }
}

/// **Mika, la mascotte, dessinée et animée nativement.**
///
/// Le dessin et le mouvement viennent du design (`design/mika/`), traduits une fois pour toutes
/// par `scripts/generate-mika.py` dans `mika.json` : chaque calque (ailes, houppette, yeux,
/// queue…), et pour chaque humeur ce qui bouge, autour de quel point, sur quelles images clés.
/// Cette vue rejoue ces animations comme le ferait un navigateur, dans un `Canvas`, sans
/// WebView : autant de Mika qu'on veut à l'écran, et le même dessin dans les rendus de la CI.
///
/// Changer d'humeur fond les yeux, la bouche et les effets en 0,18 s, comme le design.
/// « Réduire les animations » fige Mika dans la pose de son humeur.
struct MikaMascot: View {
    var mood: MikaMood = .idle
    var size: CGFloat = 120
    /// Un appui le fait sauter de joie, puis il revient à son humeur.
    var reactsToTap = false
    /// Fige l'animation à un instant donné, en secondes (rendus, aperçus).
    var frozenAt: Double?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var previousMood: MikaMood?
    @State private var moodChangedAt = Date.distantPast
    @State private var tapUntil = Date.distantPast

    var body: some View {
        let animated = frozenAt == nil && !reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !animated)) { timeline in
            let now = timeline.date
            let shown: MikaMood = now < tapUntil ? .happy : mood
            Canvas { context, canvasSize in
                guard let scene = MikaScene.shared else { return }
                let time = frozenAt ?? (animated ? now.timeIntervalSince(start) : 0)
                let fade = animated ? min(1, now.timeIntervalSince(moodChangedAt) / scene.fade) : 1
                MikaRenderer(
                    scene: scene,
                    mood: shown,
                    previous: fade < 1 ? previousMood : nil,
                    fade: fade,
                    time: time,
                    still: !animated && frozenAt == nil
                )
                .draw(in: context, size: canvasSize)
            }
        }
        // Les effets (confettis, cœurs, bulle) débordent de la boîte du dessin, comme dans
        // le design : la toile est plus grande que la place que Mika occupe.
        .frame(width: size * MikaRenderer.overflow, height: size * MikaRenderer.overflow)
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture {
            guard reactsToTap else { return }
            Haptics.selection()
            tapUntil = Date().addingTimeInterval(1.15)
        }
        .allowsHitTesting(reactsToTap)
        .onChange(of: mood) { old, _ in
            previousMood = old
            moodChangedAt = Date()
        }
        .accessibilityHidden(true)
    }
}

// MARK: - La scène

/// `mika.json`, décodé une fois.
final class MikaScene: Decodable {
    let viewBox: [Double]
    let fade: Double
    let keyframes: [String: MikaKeyframes]
    let nodes: [MikaNode]

    static let shared: MikaScene? = {
        guard let url = Bundle.main.url(forResource: "mika", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(MikaScene.self, from: data)
    }()
}

struct MikaKeyframes: Decodable {
    /// [décalage, tx, ty, rotation (degrés), sx, sy]
    let transform: [[Double]]?
    /// [décalage, opacité]
    let opacity: [[Double]]?
}

struct MikaAnimation: Decodable {
    let name: String
    let dur: Double
    /// Les quatre nombres d'une courbe `cubic-bezier`.
    let ease: [Double]
    let alternate: Bool
    let delay: Double
}

struct MikaStyle: Decodable {
    let anim: MikaAnimation?
    /// [tx, ty, rotation (degrés), sx, sy]
    let tf: [Double]?
    let op: Double?
    let origin: [Double]?
}

final class MikaNode: Decodable {
    let t: String
    let c: [String]?
    let m: [Double]?
    let o: Double?
    let kids: [MikaNode]?
    let d: [MikaCommand]?
    let bb: [Double]?
    let fill: MikaPaint?
    let stroke: MikaPaint?
    let sw: Double?
    let cap: String?
    let join: String?
    let st: [String: MikaStyle]?
    let fade: Bool?

    private enum CodingKeys: String, CodingKey {
        case t, c, m, o, kids, d, bb, fill, stroke, sw, cap, join, st, fade
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        t = try container.decode(String.self, forKey: .t)
        c = try container.decodeIfPresent([String].self, forKey: .c)
        m = try container.decodeIfPresent([Double].self, forKey: .m)
        o = try container.decodeIfPresent(Double.self, forKey: .o)
        kids = try container.decodeIfPresent([MikaNode].self, forKey: .kids)
        let commands = try container.decodeIfPresent([MikaCommand].self, forKey: .d)
        d = commands
        bb = try container.decodeIfPresent([Double].self, forKey: .bb)
        fill = try container.decodeIfPresent(MikaPaint.self, forKey: .fill)
        stroke = try container.decodeIfPresent(MikaPaint.self, forKey: .stroke)
        sw = try container.decodeIfPresent(Double.self, forKey: .sw)
        cap = try container.decodeIfPresent(String.self, forKey: .cap)
        join = try container.decodeIfPresent(String.self, forKey: .join)
        st = try container.decodeIfPresent([String: MikaStyle].self, forKey: .st)
        fade = try container.decodeIfPresent(Bool.self, forKey: .fade)
        path = commands.map(MikaNode.makePath)
    }

    /// Le tracé, construit une fois au décodage.
    let path: Path?

    private static func makePath(_ commands: [MikaCommand]) -> Path {
        var path = Path()
        for command in commands {
            let v = command.values.map { CGFloat($0) }
            switch command.op {
            case "M": path.move(to: CGPoint(x: v[0], y: v[1]))
            case "L": path.addLine(to: CGPoint(x: v[0], y: v[1]))
            case "C":
                path.addCurve(
                    to: CGPoint(x: v[4], y: v[5]),
                    control1: CGPoint(x: v[0], y: v[1]),
                    control2: CGPoint(x: v[2], y: v[3])
                )
            default: path.closeSubpath()
            }
        }
        return path
    }

    var box: CGRect {
        guard let bb, bb.count == 4 else { return .zero }
        return CGRect(x: bb[0], y: bb[1], width: bb[2], height: bb[3])
    }
}

/// Une commande de tracé : `["C", x1, y1, x2, y2, x, y]`.
struct MikaCommand: Decodable {
    let op: String
    let values: [Double]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        op = try container.decode(String.self)
        var values: [Double] = []
        while !container.isAtEnd {
            values.append(try container.decode(Double.self))
        }
        self.values = values
    }
}

/// Une couleur pleine ou un dégradé, en coordonnées de l'objet (`bbox`) ou de la scène.
struct MikaPaint: Decodable {
    struct Stop: Decodable {
        let offset: Double
        let color: Color

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            offset = try container.decode(Double.self)
            let hex = try container.decode(String.self)
            let alpha = try container.decode(Double.self)
            color = Color(hex: UInt32(hex, radix: 16) ?? 0).opacity(alpha)
        }
    }

    let k: String
    let rgb: String?
    let units: String?
    let stops: [Stop]?
    let x1: Double?
    let y1: Double?
    let x2: Double?
    let y2: Double?
    let cx: Double?
    let cy: Double?
    let r: Double?

    var solid: Color { Color(hex: UInt32(rgb ?? "000000", radix: 16) ?? 0) }

    var gradient: Gradient {
        Gradient(stops: (stops ?? []).map { Gradient.Stop(color: $0.color, location: $0.offset) })
    }
}

// MARK: - Le rendu

/// Rejoue la scène à un instant donné, pour une humeur donnée.
struct MikaRenderer {
    /// La toile déborde de la boîte du dessin de 20 % : 10 % de chaque côté.
    static let overflow: CGFloat = 1.2

    let scene: MikaScene
    let mood: MikaMood
    /// L'humeur qu'on quitte, pendant le fondu.
    let previous: MikaMood?
    let fade: Double
    let time: Double
    /// Réduire les animations : la pose fixe de l'humeur, sans aucune animation.
    var still = false

    func draw(in context: GraphicsContext, size: CGSize) {
        let box = scene.viewBox
        guard box.count == 4 else { return }
        let side = min(size.width, size.height) / Self.overflow
        let scale = side / box[2]
        var context = context
        context.translateBy(x: (size.width - side) / 2, y: (size.height - side) / 2)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -box[0], y: -box[1])
        for node in scene.nodes {
            draw(node, in: context)
        }
    }

    private func draw(_ node: MikaNode, in parent: GraphicsContext) {
        let opacity = opacity(of: node)
        guard opacity > 0.002 else { return }
        var context = parent
        context.concatenate(transform(of: node))

        if node.t == "g" {
            let kids = node.kids ?? []
            if opacity < 0.999 {
                context.drawLayer { layer in
                    layer.opacity = opacity
                    for kid in kids { draw(kid, in: layer) }
                }
            } else {
                for kid in kids { draw(kid, in: context) }
            }
            return
        }

        guard let path = node.path else { return }
        context.opacity *= opacity
        if let fill = node.fill {
            paint(path, with: fill, box: node.box, in: context)
        }
        if let stroke = node.stroke {
            let style = StrokeStyle(
                lineWidth: node.sw ?? 1,
                lineCap: lineCap(node.cap),
                lineJoin: lineJoin(node.join)
            )
            paint(path.strokedPath(style), with: stroke, box: node.box, in: context)
        }
    }

    // MARK: Peinture

    private func paint(_ path: Path, with paint: MikaPaint, box: CGRect, in context: GraphicsContext) {
        switch paint.k {
        case "solid":
            context.fill(path, with: .color(paint.solid))
        case "lin", "rad":
            if paint.units == "user" {
                context.fill(path, with: shading(paint))
            } else {
                // Un dégradé en coordonnées de l'objet s'étire avec sa boîte, comme en SVG :
                // on le peint dans un carré unité posé sur la boîte, sous le tracé.
                guard box.width > 0, box.height > 0 else { return }
                var clipped = context
                clipped.clip(to: path)
                clipped.concatenate(
                    CGAffineTransform(a: box.width, b: 0, c: 0, d: box.height, tx: box.minX, ty: box.minY)
                )
                clipped.fill(Path(CGRect(x: -2, y: -2, width: 5, height: 5)), with: shading(paint))
            }
        default:
            break
        }
    }

    private func shading(_ paint: MikaPaint) -> GraphicsContext.Shading {
        if paint.k == "rad" {
            return .radialGradient(
                paint.gradient,
                center: CGPoint(x: paint.cx ?? 0.5, y: paint.cy ?? 0.5),
                startRadius: 0,
                endRadius: paint.r ?? 0.5
            )
        }
        return .linearGradient(
            paint.gradient,
            startPoint: CGPoint(x: paint.x1 ?? 0, y: paint.y1 ?? 0),
            endPoint: CGPoint(x: paint.x2 ?? 1, y: paint.y2 ?? 0)
        )
    }

    private func lineCap(_ value: String?) -> CGLineCap {
        switch value {
        case "round": .round
        case "square": .square
        default: .butt
        }
    }

    private func lineJoin(_ value: String?) -> CGLineJoin {
        switch value {
        case "round": .round
        case "bevel": .bevel
        default: .miter
        }
    }

    // MARK: Mouvement

    private func style(of node: MikaNode, in mood: MikaMood) -> MikaStyle? {
        node.st?[mood.rawValue]
    }

    /// La transformation d'un calque : celle de son animation si elle bouge, sa pose fixe de
    /// l'humeur sinon, et, à défaut de tout style, son attribut `transform` d'origine.
    private func transform(of node: MikaNode) -> CGAffineTransform {
        let style = style(of: node, in: mood)
        var components: [Double]?
        if !still, let animation = style?.anim,
           let track = scene.keyframes[animation.name]?.transform,
           let progress = progress(of: animation) {
            components = sample(track, at: progress, ease: animation.ease)
        }
        if components == nil { components = style?.tf }

        guard let components, components.count == 5 else {
            if let m = node.m, m.count == 6 {
                return CGAffineTransform(a: m[0], b: m[1], c: m[2], d: m[3], tx: m[4], ty: m[5])
            }
            return .identity
        }
        let origin = style?.origin ?? [0, 0]
        return CGAffineTransform(translationX: origin[0], y: origin[1])
            .translatedBy(x: components[0], y: components[1])
            .rotated(by: components[2] * .pi / 180)
            .scaledBy(x: components[3], y: components[4])
            .translatedBy(x: -origin[0], y: -origin[1])
    }

    private func opacity(of node: MikaNode) -> Double {
        let current = opacity(of: node, in: mood)
        guard node.fade == true, let previous, previous != mood else { return current }
        let before = opacity(of: node, in: previous)
        return before + (current - before) * fade
    }

    private func opacity(of node: MikaNode, in mood: MikaMood) -> Double {
        let style = style(of: node, in: mood)
        if !still, let animation = style?.anim,
           let track = scene.keyframes[animation.name]?.opacity,
           let progress = progress(of: animation) {
            return sample(track, at: progress, ease: animation.ease).first ?? 1
        }
        return style?.op ?? node.o ?? 1
    }

    /// Où en est une animation qui boucle, entre 0 et 1 ; `nil` avant son délai, où elle ne
    /// s'applique pas encore.
    private func progress(of animation: MikaAnimation) -> Double? {
        let local = time - animation.delay
        guard local >= 0, animation.dur > 0 else { return nil }
        let cycles = local / animation.dur
        let iteration = floor(cycles)
        var progress = cycles - iteration
        if animation.alternate, Int(iteration) % 2 == 1 {
            progress = 1 - progress
        }
        return progress
    }

    /// Les valeurs d'une piste d'images clés à un instant, la courbe appliquée à chaque
    /// intervalle comme en CSS.
    private func sample(_ track: [[Double]], at progress: Double, ease: [Double]) -> [Double] {
        guard let first = track.first, let last = track.last else { return [] }
        if progress <= first[0] { return Array(first.dropFirst()) }
        if progress >= last[0] { return Array(last.dropFirst()) }
        for index in 0..<(track.count - 1) {
            let a = track[index]
            let b = track[index + 1]
            guard progress >= a[0], progress <= b[0] else { continue }
            let span = b[0] - a[0]
            let local = span > 0 ? (progress - a[0]) / span : 1
            let eased = CubicBezier.value(ease, at: local)
            return zip(a.dropFirst(), b.dropFirst()).map { $0 + ($1 - $0) * eased }
        }
        return Array(last.dropFirst())
    }
}

/// Une courbe `cubic-bezier(x1, y1, x2, y2)` évaluée comme en CSS : on cherche le paramètre
/// dont l'abscisse vaut la progression, et on rend son ordonnée.
enum CubicBezier {
    static func value(_ points: [Double], at x: Double) -> Double {
        guard points.count == 4 else { return x }
        let (x1, y1, x2, y2) = (points[0], points[1], points[2], points[3])
        if x1 == y1, x2 == y2 { return x }
        func coord(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let mt = 1 - t
            return 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t
        }
        func slope(_ t: Double, _ p1: Double, _ p2: Double) -> Double {
            let mt = 1 - t
            return 3 * mt * mt * p1 + 6 * mt * t * (p2 - p1) + 3 * t * t * (1 - p2)
        }
        var t = x
        for _ in 0..<8 {
            let error = coord(t, x1, x2) - x
            if abs(error) < 1e-5 { return coord(t, y1, y2) }
            let d = slope(t, x1, x2)
            if abs(d) < 1e-6 { break }
            t -= error / d
        }
        var low = 0.0
        var high = 1.0
        t = x
        for _ in 0..<30 {
            let value = coord(t, x1, x2)
            if abs(value - x) < 1e-5 { break }
            if value < x { low = t } else { high = t }
            t = (low + high) / 2
        }
        return coord(t, y1, y2)
    }
}
