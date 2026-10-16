import SwiftUI

/// **Le chemin** : des cercles de 72 points en zigzag, reliés par un trait de 6 points, les
/// paliers posés en travers. Voir `docs/refonte-parcours.md` § 5.3.
///
/// La géométrie est calculée, pas mesurée : chaque ligne a une hauteur connue (112 points pour
/// un cercle, 56 pour un palier), donc le trait se dessine sous les cercles sans attendre la
/// mise en page, et le chemin défile jusqu'au cercle en cours dès l'ouverture.
struct PathMapView: View {
    let session: LessonSession
    let tone: LessonTone
    /// La largeur de l'écran : la géométrie du chemin se calcule dessus.
    let width: CGFloat
    let onOpen: (PathCircle) -> Void
    let onRetry: (PathCircle) -> Void

    @State private var shaking: String?
    @State private var blocked: String?

    static let circleSize: CGFloat = 72
    static let currentSize: CGFloat = 84
    static let rowHeight: CGFloat = 112
    static let palierHeight: CGFloat = 56
    static let swing: CGFloat = 60
    /// L'air entre un cercle et son titre, assez pour l'anneau du cercle en cours.
    static let titleGap: CGFloat = 54

    var body: some View {
        let layout = PathGeometry(steps: session.steps, width: width)
        VStack(spacing: 0) {
            ForEach(Array(session.steps.enumerated()), id: \.element.id) { index, step in
                row(step, index: index, layout: layout)
                    .id(step.id)
            }
        }
        .frame(width: width)
        .padding(.bottom, 24)
        .background(alignment: .topLeading) { trail(layout) }
        .overlay(alignment: .bottom) { blockedToast }
    }

    // MARK: Le trait

    private func trail(_ layout: PathGeometry) -> some View {
        let currentIndex = session.circles.firstIndex { $0.id == session.current?.id } ?? session.circles.count
        let reachedColor = tone.vivid
        let trackColor = MicaboColor.track
        return Canvas { context, _ in
            let centers = layout.circleCenters
            guard centers.count > 1 else { return }
            for index in 1..<centers.count {
                var segment = Path()
                segment.move(to: centers[index - 1])
                segment.addLine(to: centers[index])
                context.stroke(
                    segment,
                    with: .color(index <= currentIndex ? reachedColor : trackColor),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
            }
        }
        .frame(width: layout.width, height: layout.height)
        .animation(.easeInOut(duration: 0.6), value: currentIndex)
        .allowsHitTesting(false)
    }

    // MARK: Les lignes

    @ViewBuilder
    private func row(_ step: PathStep, index: Int, layout: PathGeometry) -> some View {
        switch step {
        case .palier(let number, let name):
            palier(number: number, name: name)
                .frame(width: layout.width, height: Self.palierHeight)
        case .circle(let circle):
            circleRow(circle, side: layout.side(ofCircleAt: index), layout: layout)
                .frame(width: layout.width, height: Self.rowHeight)
        }
    }

    private func palier(number: Int, name: String) -> some View {
        let label = name.isEmpty
            ? L10n.t("lesson.path.palier", locale: .resolved(), vars: ["n": String(number)])
            : L10n.t("lesson.path.palierNamed", locale: .resolved(), vars: ["n": String(number), "name": name])
        return Text(label)
            .font(MicaboFont.small)
            .tracking(MicaboTracking.caps)
            .textCase(.uppercase)
            .foregroundStyle(MicaboColor.inkSecondary)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(MicaboColor.canvas, in: Capsule())
            .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1))
            .frame(maxWidth: .infinity)
    }

    private func circleRow(_ circle: PathCircle, side: CGFloat, layout: PathGeometry) -> some View {
        let state = session.state(of: circle)
        let readiness = session.readiness(of: circle)
        let size = state == .current ? Self.currentSize : Self.circleSize
        let centerX = layout.width / 2 + side * Self.swing
        let titleWidth = max(80, side < 0
            ? layout.width - 16 - (centerX + Self.titleGap)
            : centerX - Self.titleGap - 16)
        let titleCenter = side < 0
            ? centerX + Self.titleGap + titleWidth / 2
            : centerX - Self.titleGap - titleWidth / 2

        return ZStack {
            PathCircleButton(
                circle: circle,
                state: state,
                readiness: readiness,
                tone: tone,
                size: size,
                ring: state == .current ? session.progress.inCircle : 0
            ) {
                tap(circle, state: state, readiness: readiness)
            }
            .modifier(Shake(amount: shaking == circle.id ? 1 : 0))
            .position(x: centerX, y: Self.rowHeight / 2)

            circleTitle(circle, side: side, state: state, readiness: readiness)
                .frame(width: titleWidth, alignment: side < 0 ? .leading : .trailing)
                .position(x: titleCenter, y: Self.rowHeight / 2)
        }
    }

    private func circleTitle(
        _ circle: PathCircle,
        side: CGFloat,
        state: PathCircle.State,
        readiness: LessonSession.Readiness
    ) -> some View {
        VStack(alignment: side < 0 ? .leading : .trailing, spacing: 3) {
            Text(L10n.t("lesson.path.circleNumber", locale: .resolved(), vars: ["n": String(circle.number)]))
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
            Text(circle.title)
                .font(MicaboFont.label)
                .foregroundStyle(state == .upcoming ? MicaboColor.inkTertiary : MicaboColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(side < 0 ? .leading : .trailing)
            if readiness == .failed {
                Button {
                    onRetry(circle)
                } label: {
                    Label(L10n.t("lesson.path.retry", locale: .resolved()), systemImage: "arrow.clockwise")
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.wrongInk)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
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

/// La géométrie du chemin : où tombe chaque ligne, de quel côté chaque cercle.
struct PathGeometry {
    let steps: [PathStep]
    let width: CGFloat

    private var heights: [CGFloat] {
        steps.map { step in
            if case .palier = step { return PathMapView.palierHeight }
            return PathMapView.rowHeight
        }
    }

    var height: CGFloat { heights.reduce(0, +) }

    func top(of index: Int) -> CGFloat {
        heights.prefix(index).reduce(0, +)
    }

    /// −1 à gauche, +1 à droite : les cercles alternent, en commençant à gauche.
    func side(ofCircleAt index: Int) -> CGFloat {
        let circleIndex = steps.prefix(index).filter { $0.circle != nil }.count
        return circleIndex % 2 == 0 ? -1 : 1
    }

    var circleCenters: [CGPoint] {
        steps.indices.compactMap { index in
            guard steps[index].circle != nil else { return nil }
            return CGPoint(
                x: width / 2 + side(ofCircleAt: index) * PathMapView.swing,
                y: top(of: index) + PathMapView.rowHeight / 2
            )
        }
    }
}

/// **Un cercle** : fait (plein dans la couleur de la leçon, coche blanche), en cours (plus gros,
/// anneau de progression, « Continuer », pulsation lente), à venir (gris, icône effacée).
struct PathCircleButton: View {
    let circle: PathCircle
    let state: PathCircle.State
    let readiness: LessonSession.Readiness
    let tone: LessonTone
    let size: CGFloat
    var ring: Double = 0
    let action: () -> Void

    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(fill)
                    .overlay(Circle().strokeBorder(border, lineWidth: state == .upcoming ? 2 : 0))
                    .shadow(color: state == .upcoming ? .clear : tone.vivid.opacity(0.28), radius: 0, x: 0, y: 5)

                if readiness == .writing && state != .upcoming {
                    ProgressView()
                        .tint(state == .done ? MicaboColor.onInk : tone.ink)
                } else {
                    MicaboIconView(icon: circle.icon, size: size * 0.6, dimmed: state == .upcoming)
                }

                if state == .current {
                    Circle()
                        .trim(from: 0, to: max(0.02, ring))
                        .stroke(tone.vivid, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-9)
                    Circle()
                        .stroke(tone.vivid.opacity(0.18), lineWidth: 5)
                        .padding(-9)
                }

                if state == .done {
                    checkBadge
                        .offset(x: size * 0.36, y: size * 0.36)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(state == .current && pulse && !reduceMotion ? 1.04 : 1)
            .overlay(alignment: .top) {
                if state == .current {
                    continueLabel.offset(y: -34)
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
        .accessibilityLabel(Text(circle.title))
        .onAppear {
            guard state == .current else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulse = true }
        }
        .animation(.spring(duration: 0.6), value: state)
    }

    private var fill: Color {
        switch state {
        case .done: tone.vivid
        case .current: tone.pale
        case .upcoming: MicaboColor.surfaceSunken
        }
    }

    private var border: Color {
        state == .upcoming ? MicaboColor.stroke : .clear
    }

    private var checkBadge: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(tone.vivid)
            .frame(width: 22, height: 22)
            .background(Circle().fill(MicaboColor.onInk))
            .overlay(Circle().strokeBorder(tone.vivid, lineWidth: 2))
    }

    private var continueLabel: some View {
        Text(L10n.t("lesson.path.continue", locale: .resolved()))
            .font(MicaboFont.ui(13, weight: .heavy))
            .textCase(.uppercase)
            .foregroundStyle(MicaboColor.correctInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(MicaboColor.canvas, in: Capsule())
            .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            .fixedSize()
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
