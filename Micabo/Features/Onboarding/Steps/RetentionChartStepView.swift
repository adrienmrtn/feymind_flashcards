import SwiftUI

/// Écran 6 : la démonstration visuelle. Deux courbes de mémorisation qui partent
/// ensemble puis divergent à la première révision.
struct RetentionChartStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Rappel actif",
            title: "Relire ne suffit pas.\nSe souvenir, oui.",
            subtitle: "Chaque fois que tu ressors une information de ta tête au lieu de la relire, tu la rends plus solide. Micabo te fait faire ça, au bon moment.",
            titleSize: 28
        ) {
            VStack(alignment: .leading, spacing: 14) {
                RetentionChart()
                    .frame(height: 236)

                Text("Chaque pic est une révision : quelques secondes qui remettent la carte à 100 %, et qui rallongent le temps avant l'oubli suivant.")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

// MARK: - Courbes

/// Modèle des deux courbes. La rétention décroît de façon exponentielle et remonte
/// à 100 % à chaque révision, avec une stabilité qui augmente à chaque passage.
enum RetentionCurve {
    static let horizonDays = 30.0
    static let reviewDays: [Double] = [1, 3, 7, 16]

    /// Stabilité (en jours) de chaque segment. La première est identique à celle
    /// de la courbe sans révision : les deux tracés partent donc confondus.
    private static let stabilities: [Double] = [3.5, 6, 13, 28, 70]
    private static let baseStability = 3.5

    static func withoutReview(samples: Int = 140) -> [CGPoint] {
        (0...samples).map { index in
            let t = horizonDays * Double(index) / Double(samples)
            return CGPoint(x: t / horizonDays, y: exp(-t / baseStability))
        }
    }

    static func withMicabo(samplesPerSegment: Int = 30) -> [CGPoint] {
        var points: [CGPoint] = []
        var segmentStart = 0.0

        for (index, segmentEnd) in (reviewDays + [horizonDays]).enumerated() {
            let stability = stabilities[min(index, stabilities.count - 1)]

            for step in 0...samplesPerSegment {
                let t = segmentStart + (segmentEnd - segmentStart) * Double(step) / Double(samplesPerSegment)
                points.append(CGPoint(x: t / horizonDays, y: exp(-(t - segmentStart) / stability)))
            }

            // Remontée verticale au moment de la révision.
            if segmentEnd < horizonDays {
                points.append(CGPoint(x: segmentEnd / horizonDays, y: 1))
            }
            segmentStart = segmentEnd
        }

        return points
    }
}

private struct RetentionChart: View {
    private let withoutPoints = RetentionCurve.withoutReview()
    private let withPoints = RetentionCurve.withMicabo()
    private let duration = 1.9

    @State private var progress = 0.0
    @State private var elapsed = 0.0
    @State private var isRunning = false
    @State private var firedMarkers = 0

    private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            legend

            GeometryReader { proxy in
                let size = proxy.size

                ZStack(alignment: .topLeading) {
                    grid(in: size)

                    // Aire sous la courbe Micabo.
                    areaPath(for: withPoints, in: size)
                        .fill(
                            LinearGradient(
                                colors: [MicaboColor.accent.opacity(0.16), MicaboColor.accent.opacity(0.01)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(for: withoutPoints, in: size)
                        .stroke(
                            MicaboColor.inkTertiary,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4])
                        )

                    linePath(for: withPoints, in: size)
                        .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                    markers(in: size)

                    endLabels(in: size)
                }
            }

            axisLabels
        }
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                isRunning = true
            }
        }
        .onReceive(ticker) { _ in
            guard isRunning, progress < 1 else { return }
            elapsed += 1.0 / 60.0
            let linear = min(1, elapsed / duration)
            progress = 1 - pow(1 - linear, 3)
            fireMarkerHapticsIfNeeded()
        }
    }

    // MARK: - Éléments

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(color: MicaboColor.accent, label: "Avec Micabo", dashed: false)
            legendItem(color: MicaboColor.inkTertiary, label: "Sans Micabo", dashed: true)
            Spacer(minLength: 0)
        }
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule()
                .fill(color)
                .frame(width: dashed ? 6 : 16, height: 3)
                .overlay(alignment: .trailing) {
                    if dashed {
                        Capsule()
                            .fill(color)
                            .frame(width: 6, height: 3)
                            .offset(x: 10)
                    }
                }
            Text(label)
                .font(MicaboFont.hanken(11, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
    }

    private func grid(in size: CGSize) -> some View {
        ForEach(0..<4) { index in
            let y = size.height * CGFloat(index) / 3
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            .stroke(MicaboColor.stroke, style: StrokeStyle(lineWidth: 1, dash: [3, 5]))
        }
    }

    private func markers(in size: CGSize) -> some View {
        ForEach(Array(RetentionCurve.reviewDays.enumerated()), id: \.offset) { _, day in
            let x = day / RetentionCurve.horizonDays
            let isVisible = progress >= x

            Circle()
                .fill(MicaboColor.accent)
                .frame(width: 9, height: 9)
                .overlay {
                    Circle().strokeBorder(MicaboColor.surface, lineWidth: 2)
                }
                .scaleEffect(isVisible ? 1 : 0.1)
                .opacity(isVisible ? 1 : 0)
                .position(point(x: x, y: 1, in: size))
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isVisible)
        }
    }

    private func endLabels(in size: CGSize) -> some View {
        let opacity = max(0, min(1, (progress - 0.82) / 0.18))

        return ZStack(alignment: .topLeading) {
            Text("Tu retiens")
                .font(MicaboFont.hanken(10, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .padding(.vertical, 3)
                .padding(.horizontal, 7)
                .background(MicaboColor.infoSoft, in: Capsule())
                .position(labelPosition(value: 0.82, in: size, offsetY: -14))
                .opacity(opacity)

            Text("Tu as oublié")
                .font(MicaboFont.hanken(10, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.vertical, 3)
                .padding(.horizontal, 7)
                .background(MicaboColor.surfaceMuted, in: Capsule())
                .position(labelPosition(value: 0.02, in: size, offsetY: -16))
                .opacity(opacity)
        }
    }

    private var axisLabels: some View {
        HStack {
            Text("Aujourd'hui")
            Spacer()
            Text("Dans 1 mois")
        }
        .font(MicaboFont.hanken(10, weight: .medium))
        .foregroundStyle(MicaboColor.inkTertiary)
    }

    // MARK: - Géométrie

    private func point(_ value: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: value.x * size.width, y: (1 - value.y) * size.height)
    }

    private func point(x: Double, y: Double, in size: CGSize) -> CGPoint {
        point(CGPoint(x: x, y: y), in: size)
    }

    private func labelPosition(value: Double, in size: CGSize, offsetY: CGFloat) -> CGPoint {
        let base = point(x: 1, y: value, in: size)
        return CGPoint(x: base.x - 34, y: base.y + offsetY)
    }

    private func visiblePoints(_ points: [CGPoint]) -> [CGPoint] {
        points.filter { Double($0.x) <= progress }
    }

    private func linePath(for points: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        let visible = visiblePoints(points)
        guard let first = visible.first else { return path }

        path.move(to: point(first, in: size))
        for value in visible.dropFirst() {
            path.addLine(to: point(value, in: size))
        }
        return path
    }

    private func areaPath(for points: [CGPoint], in size: CGSize) -> Path {
        var path = linePath(for: points, in: size)
        guard let last = visiblePoints(points).last else { return path }

        path.addLine(to: CGPoint(x: last.x * size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// Une impulsion à chaque révision franchie par le tracé.
    private func fireMarkerHapticsIfNeeded() {
        let crossed = RetentionCurve.reviewDays.filter { progress >= $0 / RetentionCurve.horizonDays }.count
        guard crossed > firedMarkers else { return }
        firedMarkers = crossed
        Haptics.tick()
    }
}
