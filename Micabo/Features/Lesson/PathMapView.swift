import SwiftUI

/// **Le chemin** : des ronds posés sur une courbe douce, reliés par un trait qui se remplit à
/// mesure qu'on avance. C'est la signature d'une leçon (lot 10, HOME.md § 2) : il reste un
/// zigzag, pas une liste, sous la grille « Réviser ».
///
/// - Fait : rond vert, coche.
/// - En cours : rond d'accent, flèche de lecture, et un anneau qui dit où l'on en est dans
///   l'étape.
/// - À venir : rond neutre, le pictogramme de l'étape. Un appui le secoue et dit par où
///   passer d'abord : on ne saute pas.
///
/// **Rien ne se met en scène** : les ronds sont là quand l'écran arrive, sans entrée en
/// cascade, sans halo qui respire, sans bulle qui flotte. Le trait et l'anneau avancent sur la
/// courbe de l'app quand une étape se termine, et c'est tout.
///
/// La géométrie est calculée, pas mesurée : chaque étape a une hauteur connue, donc le trait se
/// dessine sous les ronds sans attendre la mise en page.
struct PathMapView: View {
    let session: LessonSession
    let tone: LessonTone
    /// La largeur de l'écran : la géométrie du chemin se calcule dessus.
    let width: CGFloat
    let onOpen: (PathCircle) -> Void
    let onRetry: (PathCircle) -> Void

    /// Les secousses de chaque rond à venir, comptées : passer de n à n + 1 fait un aller-retour
    /// et s'arrête tout seul, sans minuterie pour le remettre à zéro.
    @State private var shakes: [String: Int] = [:]
    /// L'étape à venir qu'on vient de toucher : « Termine d'abord l'étape 4 » s'écrit sous son
    /// titre, et y reste jusqu'au prochain geste.
    @State private var hinted: String?

    static let nodeSize: CGFloat = 58
    /// L'anneau de l'étape en cours : concentrique, à égale distance du rond tout autour.
    static let ringGap: CGFloat = 3
    static let ringWidth: CGFloat = 5
    static let rowHeight: CGFloat = 96
    static let trailWidth: CGFloat = 8
    /// L'air entre un rond (anneau compris) et son titre.
    static let titleGap: CGFloat = 12

    var body: some View {
        let layout = PathGeometry(count: session.circles.count, width: width)
        VStack(spacing: 0) {
            ForEach(Array(session.circles.enumerated()), id: \.element.id) { index, circle in
                row(circle, index: index, layout: layout)
                    .frame(width: layout.width, height: Self.rowHeight)
                    .id(circle.id)
            }
        }
        .frame(width: width)
        .background(alignment: .topLeading) { trail(layout) }
        .onChange(of: session.current?.id) { _, _ in hinted = nil }
    }

    // MARK: Le trait

    /// Où s'arrête la couleur : au centre de l'étape en cours, ou au bout quand tout est fait.
    private var reachedIndex: Int {
        session.circles.firstIndex { $0.id == session.current?.id } ?? max(0, session.circles.count - 1)
    }

    private func trail(_ layout: PathGeometry) -> some View {
        let shape = PathTrail(points: layout.centers)
        let fraction = layout.fraction(upTo: reachedIndex)
        let style = StrokeStyle(lineWidth: Self.trailWidth, lineCap: .round, lineJoin: .round)
        return ZStack {
            shape.stroke(V3Color.line, style: style)
            shape
                .trim(from: 0, to: fraction)
                .stroke(V3Color.green, style: style)
                .animation(LearnMotion.gentle, value: fraction)
        }
        .frame(width: layout.width, height: layout.height)
        .allowsHitTesting(false)
    }

    // MARK: Une étape

    private func row(_ circle: PathCircle, index: Int, layout: PathGeometry) -> some View {
        let state = session.state(of: circle)
        let readiness = session.readiness(of: circle)
        let center = layout.centers[index]
        let titleOnRight = layout.titleOnRight(index)
        let reach = Self.nodeSize / 2 + Self.ringGap + Self.ringWidth + Self.titleGap
        let titleWidth = max(96, titleOnRight ? layout.width - 20 - (center.x + reach) : center.x - reach - 20)
        let titleX = titleOnRight ? center.x + reach + titleWidth / 2 : center.x - reach - titleWidth / 2
        let y = Self.rowHeight / 2

        return ZStack {
            PathNode(
                circle: circle,
                state: state,
                readiness: readiness,
                tone: tone,
                ring: state == .current ? session.progress.inCircle : 0
            ) {
                tap(circle, state: state, readiness: readiness)
            }
            .modifier(Shake(amount: CGFloat(shakes[circle.id, default: 0])))
            .position(x: center.x, y: y)

            PathStepTitle(
                circle: circle,
                state: state,
                readiness: readiness,
                tone: tone,
                alignLeading: titleOnRight,
                hint: hinted == circle.id ? blockedHint : nil
            ) {
                onRetry(circle)
            }
            .frame(width: titleWidth, alignment: titleOnRight ? .leading : .trailing)
            .position(x: titleX, y: y)
        }
    }

    // MARK: Les appuis

    /// « Termine d'abord l'étape 4 » : le numéro de l'étape en cours.
    private var blockedHint: String? {
        guard let current = session.current else { return nil }
        return L10n.t("ios.home10.lesson.finishFirst", locale: .resolved(), vars: ["n": String(current.number)])
    }

    private func tap(_ circle: PathCircle, state: PathCircle.State, readiness: LessonSession.Readiness) {
        if state == .upcoming {
            Haptics.warning()
            withAnimation(LearnMotion.standard) {
                shakes[circle.id, default: 0] += 1
                hinted = circle.id
            }
            return
        }
        if hinted != nil {
            withAnimation(LearnMotion.quick) { hinted = nil }
        }
        switch readiness {
        case .ready:
            Haptics.medium()
            onOpen(circle)
        case .writing:
            Haptics.light()
        case .failed:
            onRetry(circle)
        }
    }
}

// MARK: - La géométrie

/// **Où tombe chaque rond** : une courbe douce, d'un bord à l'autre, comme une rivière. Le
/// premier rond part un peu à droite du centre ; l'amplitude suit la largeur de l'écran.
struct PathGeometry {
    let count: Int
    let width: CGFloat

    var height: CGFloat { CGFloat(count) * PathMapView.rowHeight }

    /// L'écart au centre : assez pour que le chemin serpente, jamais au point d'écraser un
    /// titre contre le bord.
    var amplitude: CGFloat { min(64, max(36, width * 0.15)) }

    func offset(_ index: Int) -> CGFloat {
        amplitude * sin(Double(index) * 0.78 + 0.35)
    }

    var centers: [CGPoint] {
        (0..<count).map { index in
            CGPoint(x: width / 2 + offset(index), y: (CGFloat(index) + 0.5) * PathMapView.rowHeight)
        }
    }

    /// Le titre se lit du côté où il y a de la place : à droite d'un rond posé à gauche.
    func titleOnRight(_ index: Int) -> Bool {
        offset(index) < 0
    }

    /// La part du trait jusqu'au rond `index`, de 0 à 1, mesurée sur la courbe elle-même : le
    /// remplissage avance à vitesse constante, même dans les virages.
    func fraction(upTo index: Int) -> CGFloat {
        let points = centers
        guard points.count > 1 else { return 1 }
        let lengths = PathTrail.segmentLengths(points)
        let total = lengths.reduce(0, +)
        guard total > 0 else { return 0 }
        let reached = lengths.prefix(max(0, min(index, lengths.count))).reduce(0, +)
        return reached / total
    }
}

/// **Le trait du chemin** : des courbes qui passent par le centre de chaque rond, sans angle.
struct PathTrail: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for index in 1..<max(1, points.count) {
            let (c1, c2) = Self.controls(points, index)
            path.addCurve(to: points[index], control1: c1, control2: c2)
        }
        return path
    }

    /// Les points de contrôle d'un segment, à la verticale de ses deux bouts : le trait
    /// descend d'un rond à l'autre comme une corde souple.
    static func controls(_ points: [CGPoint], _ index: Int) -> (CGPoint, CGPoint) {
        let from = points[index - 1]
        let to = points[index]
        let pull = (to.y - from.y) * 0.5
        return (CGPoint(x: from.x, y: from.y + pull), CGPoint(x: to.x, y: to.y - pull))
    }

    /// La longueur de chaque segment, mesurée en suivant la courbe.
    static func segmentLengths(_ points: [CGPoint]) -> [CGFloat] {
        guard points.count > 1 else { return [] }
        return (1..<points.count).map { index in
            let (c1, c2) = controls(points, index)
            let p0 = points[index - 1]
            let p3 = points[index]
            var length: CGFloat = 0
            var previous = p0
            let samples = 16
            for step in 1...samples {
                let t = CGFloat(step) / CGFloat(samples)
                let u = 1 - t
                let x = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x
                let y = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y
                length += hypot(x - previous.x, y - previous.y)
                previous = CGPoint(x: x, y: y)
            }
            return length
        }
    }
}

// MARK: - Un rond

/// **Un rond du chemin**, dans l'un de ses trois états. Les couleurs sont celles du système,
/// pas celles de la leçon : vert pour ce qui est fait, l'accent pour ce qu'on fait maintenant,
/// le filet pour ce qui attend. `tone` reste dans la signature pour les écrans qui posent un
/// chemin en exemple.
struct PathNode: View {
    let circle: PathCircle
    let state: PathCircle.State
    let readiness: LessonSession.Readiness
    let tone: LessonTone
    var ring: Double = 0
    let action: () -> Void

    private var size: CGFloat { PathMapView.nodeSize }
    private var ringDiameter: CGFloat { size + 2 * PathMapView.ringGap + PathMapView.ringWidth }
    private var outer: CGFloat { size + 2 * (PathMapView.ringGap + PathMapView.ringWidth) }

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .current {
                    Circle()
                        .stroke(V3Color.accentWash, lineWidth: PathMapView.ringWidth)
                        .frame(width: ringDiameter, height: ringDiameter)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, ring)))
                        .stroke(V3Color.accent, style: StrokeStyle(lineWidth: PathMapView.ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringDiameter, height: ringDiameter)
                        .opacity(ring > 0.001 ? 1 : 0)
                        .animation(LearnMotion.gentle, value: ring)
                }
                Circle()
                    .fill(face)
                    .frame(width: size, height: size)
                content
            }
            .frame(width: outer, height: outer)
            .contentShape(Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
        .accessibilityLabel(Text(circle.title))
        .accessibilityValue(Text(accessibilityState))
        .animation(LearnMotion.standard, value: state)
    }

    // MARK: Le contenu

    @ViewBuilder
    private var content: some View {
        if readiness == .writing && state != .done {
            ProgressView()
                .tint(state == .current ? V3Color.onAccent : V3Color.ink3)
                .controlSize(.regular)
        } else if readiness == .failed && state != .done {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(state == .current ? V3Color.onAccent : V3Color.red)
        } else {
            switch state {
            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(V3Color.bg)
                    .symbolEffect(.bounce, value: state)
            case .current:
                Image(systemName: "play.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(V3Color.onAccent)
            case .upcoming:
                Image(systemName: PathSymbol.resolved(circle.symbol))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(V3Color.ink3)
            }
        }
    }

    // MARK: Les couleurs

    private var face: Color {
        switch state {
        case .done: V3Color.green
        case .current: V3Color.accent
        case .upcoming: V3Color.line
        }
    }

    private var accessibilityState: String {
        switch state {
        case .done: L10n.t("lesson.path.a11y.done", locale: .resolved())
        case .current: L10n.t("lesson.path.a11y.current", locale: .resolved())
        case .upcoming: L10n.t("lesson.path.a11y.locked", locale: .resolved())
        }
    }
}

// MARK: - Le titre d'une étape

/// « ÉTAPE 4 », le titre, et sous un Checkpoint le palier qu'il conclut. L'étape en cours
/// s'écrit dans l'accent, une étape faite dans le vert, une étape à venir en retrait.
struct PathStepTitle: View {
    let circle: PathCircle
    let state: PathCircle.State
    let readiness: LessonSession.Readiness
    let tone: LessonTone
    let alignLeading: Bool
    /// « Termine d'abord l'étape 4 », sous une étape à venir qu'on vient de toucher.
    var hint: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: alignLeading ? .leading : .trailing, spacing: 3) {
            Text(L10n.t("lesson.path.step", locale: .resolved(), vars: ["n": String(circle.number)]))
                .font(V3Font.caption)
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(numberColor)
            Text(circle.title)
                .font(V3Font.label)
                .foregroundStyle(state == .upcoming ? V3Color.ink2 : V3Color.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(alignLeading ? .leading : .trailing)
            if let subtitle = circle.subtitle {
                Text(subtitle)
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink3)
                    .lineLimit(1)
            }
            if readiness == .failed && state != .done {
                Button(action: onRetry) {
                    Label(L10n.t("lesson.path.retry", locale: .resolved()), systemImage: "arrow.clockwise")
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.red)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            } else if readiness == .writing && state != .done {
                Text(L10n.t("lesson.path.writing", locale: .resolved()))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink3)
            } else if let hint {
                Text(hint)
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .lineLimit(2)
                    .multilineTextAlignment(alignLeading ? .leading : .trailing)
                    .transition(.opacity)
            }
        }
        .animation(LearnMotion.standard, value: state)
    }

    private var numberColor: Color {
        switch state {
        case .done: V3Color.green
        case .current: V3Color.accent
        case .upcoming: V3Color.ink3
        }
    }
}

/// Un petit secouement : « on ne saute pas ». `amount` se compte : de n à n + 1, un aller-retour.
struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(amount * .pi * 4), y: 0))
    }
}
