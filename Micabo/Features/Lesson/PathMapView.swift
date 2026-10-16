import SwiftUI

/// **Le chemin** : de gros ronds posés sur une courbe douce, reliés par un trait épais qui se
/// remplit dans la couleur de la leçon à mesure qu'on avance. Chaque étape porte son
/// pictogramme ; son numéro et son titre se lisent de l'autre côté. Voir
/// `docs/refonte-parcours.md` § 5.3.
///
/// - Fait : plein, coche blanche, un relief sous le rond.
/// - En cours : plein, étoile, un anneau concentrique qui dit où on en est dans l'étape, la
///   bulle « Commencer » (ou « Continuer ») et un halo qui respire.
/// - À venir : gris, le pictogramme de l'étape. Un appui secoue le rond : on ne saute pas.
///
/// La géométrie est calculée, pas mesurée : chaque étape a une hauteur connue, donc le trait se
/// dessine sous les ronds sans attendre la mise en page, et le chemin défile jusqu'à l'étape
/// en cours dès l'ouverture.
struct PathMapView: View {
    let session: LessonSession
    let tone: LessonTone
    /// La largeur de l'écran : la géométrie du chemin se calcule dessus.
    let width: CGFloat
    let onOpen: (PathCircle) -> Void
    let onRetry: (PathCircle) -> Void

    @State private var shaking: String?
    @State private var blocked: String?
    /// Les ronds apparaissent un à un à la première ouverture.
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let nodeSize: CGFloat = 84
    /// L'anneau de l'étape en cours : concentrique, à égale distance du rond tout autour.
    static let ringGap: CGFloat = 9
    static let ringWidth: CGFloat = 7
    static let rowHeight: CGFloat = 148
    static let trailWidth: CGFloat = 12
    /// L'air entre un rond (anneau compris) et son titre.
    static let titleGap: CGFloat = 18

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
        .padding(.bottom, 12)
        .background(alignment: .topLeading) { trail(layout) }
        .overlay(alignment: .bottom) { blockedToast }
        .onAppear {
            guard !revealed else { return }
            if reduceMotion {
                revealed = true
            } else {
                withAnimation(.spring(duration: 0.55, bounce: 0.35).delay(0.08)) { revealed = true }
            }
        }
    }

    // MARK: Le trait

    /// Où s'arrête la couleur : au centre de l'étape en cours, ou au bout quand tout est fait.
    private var reachedIndex: Int {
        session.circles.firstIndex { $0.id == session.current?.id } ?? max(0, session.circles.count - 1)
    }

    private func trail(_ layout: PathGeometry) -> some View {
        let centers = layout.centers
        let shape = PathTrail(points: centers)
        let fraction = layout.fraction(upTo: reachedIndex)
        return ZStack {
            shape.stroke(MicaboColor.track, style: StrokeStyle(lineWidth: Self.trailWidth, lineCap: .round, lineJoin: .round))
            shape
                .trim(from: 0, to: revealed ? fraction : 0)
                .stroke(tone.vivid, style: StrokeStyle(lineWidth: Self.trailWidth, lineCap: .round, lineJoin: .round))
                .animation(.easeInOut(duration: reduceMotion ? 0 : 0.9), value: fraction)
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
        let titleWidth = max(96, titleOnRight ? layout.width - 18 - (center.x + reach) : center.x - reach - 18)
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
            .modifier(Shake(amount: shaking == circle.id ? 1 : 0))
            .scaleEffect(revealed ? 1 : 0.4)
            .opacity(revealed ? 1 : 0)
            .animation(.spring(duration: 0.5, bounce: 0.4).delay(Double(index) * 0.05), value: revealed)
            .position(x: center.x, y: y)

            PathStepTitle(circle: circle, state: state, readiness: readiness, tone: tone, alignLeading: titleOnRight) {
                onRetry(circle)
            }
            .frame(width: titleWidth, alignment: titleOnRight ? .leading : .trailing)
            .opacity(revealed ? 1 : 0)
            .offset(x: revealed ? 0 : (titleOnRight ? -12 : 12))
            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.05 + 0.1), value: revealed)
            .position(x: titleX, y: y)
        }
    }

    // MARK: Les appuis

    private func tap(_ circle: PathCircle, state: PathCircle.State, readiness: LessonSession.Readiness) {
        if state == .upcoming {
            Haptics.warning()
            withAnimation(.linear(duration: 0.4)) { shaking = circle.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { shaking = nil }
            showBlocked()
            return
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

    private func showBlocked() {
        let title = session.current?.title ?? ""
        withAnimation(.spring(duration: 0.3)) {
            blocked = L10n.t("lesson.path.finishFirst", locale: .resolved(), vars: ["circle": title])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.25)) { blocked = nil }
        }
    }

    @ViewBuilder
    private var blockedToast: some View {
        if let blocked {
            Text(blocked)
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.onInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(MicaboColor.ink, in: Capsule())
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 8)
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
    var amplitude: CGFloat { min(88, max(48, width * 0.2)) }

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

/// **Un rond du chemin**, dans l'un de ses trois états.
struct PathNode: View {
    let circle: PathCircle
    let state: PathCircle.State
    let readiness: LessonSession.Readiness
    let tone: LessonTone
    var ring: Double = 0
    let action: () -> Void

    @State private var breathe = false
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var size: CGFloat { PathMapView.nodeSize }
    /// Le relief sous le rond : un rond plus sombre, décalé vers le bas.
    private static let depth: CGFloat = 6

    var body: some View {
        Button(action: action) {
            ZStack {
                if state == .current {
                    halo
                    ringTrack
                    ringProgress
                }
                Circle()
                    .fill(rim)
                    .frame(width: size, height: size)
                    .offset(y: Self.depth)
                Circle()
                    .fill(face)
                    .frame(width: size, height: size)
                    .overlay {
                        Circle()
                            .fill(LinearGradient(colors: [.white.opacity(state == .upcoming ? 0.0 : 0.22), .clear], startPoint: .top, endPoint: .center))
                            .padding(6)
                    }
                content
            }
            .frame(width: size + 2 * (PathMapView.ringGap + PathMapView.ringWidth), height: size + 2 * (PathMapView.ringGap + PathMapView.ringWidth))
            .scaleEffect(pop ? 1.14 : 1)
            .overlay(alignment: .top) {
                if state == .current {
                    StartBubble(tone: tone, started: ring > 0.02)
                        .offset(y: -30)
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PathNodeButtonStyle())
        .accessibilityLabel(Text(circle.title))
        .accessibilityValue(Text(accessibilityState))
        .onAppear { startBreathing() }
        .onChange(of: state) { old, new in
            if new == .current { startBreathing() }
            guard old != new, new == .done || new == .current, !reduceMotion else { return }
            withAnimation(.spring(duration: 0.28, bounce: 0.6)) { pop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
                withAnimation(.spring(duration: 0.4, bounce: 0.3)) { pop = false }
            }
        }
        .animation(.spring(duration: 0.55, bounce: 0.3), value: state)
    }

    // MARK: Le contenu

    @ViewBuilder
    private var content: some View {
        if readiness == .writing && state != .done {
            ProgressView()
                .tint(state == .current ? MicaboColor.onInk : MicaboColor.inkTertiary)
                .controlSize(.regular)
        } else if readiness == .failed && state != .done {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(state == .current ? MicaboColor.onInk : MicaboColor.wrongInk)
        } else {
            switch state {
            case .done:
                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(MicaboColor.onInk)
                    .symbolEffect(.bounce, value: state)
                    .transition(.scale.combined(with: .opacity))
            case .current:
                Image(systemName: circle.isMilestone ? PathSymbol.resolved(circle.symbol) : "star.fill")
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(MicaboColor.onInk)
                    .shadow(color: .black.opacity(0.12), radius: 0, x: 0, y: 2)
                    .transition(.scale.combined(with: .opacity))
            case .upcoming:
                Image(systemName: PathSymbol.resolved(circle.symbol))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
    }

    // MARK: L'anneau de l'étape en cours

    private var ringDiameter: CGFloat { size + 2 * PathMapView.ringGap + PathMapView.ringWidth }

    private var ringTrack: some View {
        Circle()
            .stroke(MicaboColor.track, lineWidth: PathMapView.ringWidth)
            .frame(width: ringDiameter, height: ringDiameter)
            .offset(y: Self.depth / 2)
    }

    private var ringProgress: some View {
        Circle()
            .trim(from: 0, to: max(0.001, min(1, ring)))
            .stroke(tone.vivid, style: StrokeStyle(lineWidth: PathMapView.ringWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: ringDiameter, height: ringDiameter)
            .offset(y: Self.depth / 2)
            .opacity(ring > 0.001 ? 1 : 0)
            .animation(.easeOut(duration: 0.6), value: ring)
    }

    private var halo: some View {
        Circle()
            .fill(tone.vivid.opacity(0.18))
            .frame(width: ringDiameter + 18, height: ringDiameter + 18)
            .offset(y: Self.depth / 2)
            .scaleEffect(breathe && !reduceMotion ? 1.08 : 0.94)
            .opacity(breathe && !reduceMotion ? 0.0 : 0.9)
    }

    private func startBreathing() {
        guard state == .current, !reduceMotion else { return }
        breathe = false
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { breathe = true }
    }

    // MARK: Les couleurs

    private var face: Color {
        switch state {
        case .done, .current: tone.vivid
        case .upcoming: MicaboColor.surfaceSunken
        }
    }

    private var rim: Color {
        switch state {
        case .done, .current: tone.ink.opacity(0.55)
        case .upcoming: MicaboColor.track
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

/// Un rond s'enfonce sous le doigt, comme un vrai bouton : il descend sur son relief.
private struct PathNodeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(duration: 0.18, bounce: 0.2), value: configuration.isPressed)
    }
}

/// **« Commencer »**, posée au-dessus de l'étape en cours, la pointe vers le rond.
struct StartBubble: View {
    let tone: LessonTone
    let started: Bool

    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: -1) {
            Text(L10n.t(started ? "lesson.path.continue" : "lesson.path.start", locale: .resolved()))
                .font(MicaboFont.ui(14, weight: .heavy))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(tone.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            BubbleTip()
                .fill(MicaboColor.surface)
                .overlay(BubbleTip().stroke(MicaboColor.stroke, lineWidth: 1.5))
                .frame(width: 16, height: 9)
        }
        .fixedSize()
        .micaboElevation(.row)
        .offset(y: float && !reduceMotion ? -4 : 0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { float = true }
        }
    }
}

/// La pointe d'une bulle : un triangle vers le bas, sans le bord du haut.
struct BubbleTip: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - Le titre d'une étape

/// « ÉTAPE 4 », le titre, et sous un Checkpoint le palier qu'il conclut.
struct PathStepTitle: View {
    let circle: PathCircle
    let state: PathCircle.State
    let readiness: LessonSession.Readiness
    let tone: LessonTone
    let alignLeading: Bool
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: alignLeading ? .leading : .trailing, spacing: 4) {
            Text(L10n.t("lesson.path.step", locale: .resolved(), vars: ["n": String(circle.number)]))
                .font(MicaboFont.ui(13, weight: .heavy))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(state == .upcoming ? MicaboColor.inkTertiary : tone.ink)
            Text(circle.title)
                .font(MicaboFont.ui(19, weight: .bold))
                .foregroundStyle(state == .upcoming ? MicaboColor.inkSecondary : MicaboColor.ink)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(alignLeading ? .leading : .trailing)
            if let subtitle = circle.subtitle {
                Text(subtitle)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .lineLimit(1)
            }
            if readiness == .failed && state != .done {
                Button(action: onRetry) {
                    Label(L10n.t("lesson.path.retry", locale: .resolved()), systemImage: "arrow.clockwise")
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.wrongInk)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            } else if readiness == .writing && state != .done {
                Text(L10n.t("lesson.path.writing", locale: .resolved()))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .animation(.easeOut(duration: 0.3), value: state)
    }
}

/// Un petit secouement : « on ne saute pas ».
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
