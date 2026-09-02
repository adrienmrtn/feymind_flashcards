import Combine
import SwiftUI

/// La démonstration visuelle. Deux courbes de mémorisation qui partent
/// ensemble puis divergent à la première révision.
///
/// L'écran doit se lire en trois secondes : un titre, le graphe avec ses intervalles
/// étiquetés, et deux lignes de légende. Aucun paragraphe.
struct RetentionChartStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.retentionTitle") ?? "Relire ne suffit pas.\nSe souvenir, oui.",
            titleSize: 28
        ) {
            RetentionChart()
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

    /// Intervalle réel affiché sous chaque révision du graphe.
    static func intervalLabel(forDay day: Double) -> String {
        "\(Int(day)) j"
    }

    /// Les mêmes intervalles, en liste. L'écran de la répétition espacée les reprend
    /// tels quels : deux écrans voisins qui parlent des mêmes révisions ne peuvent pas
    /// annoncer deux échéanciers différents.
    static var intervalLabels: [String] {
        reviewDays.map(intervalLabel(forDay:))
    }

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
            heading

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

                    intervalLabels(in: size)

                    endLabels(in: size)
                }
            }
            .frame(height: 168)

            axisLabels

            MicaboHairline()

            legend
        }
        .padding(16)
        .micaboGroup()
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

    /// Ce que le graphe raconte, dit avant de le regarder. Les intervalles réels sont
    /// posés sur les points ; l'écran suivant les reprend en liste.
    private var heading: some View {
        Text("Ta mémoire, avec et sans révision")
            .font(MicaboFont.hanken(14, weight: .semibold))
            .foregroundStyle(MicaboColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Deux lignes, une par courbe : c'est toute l'explication de l'écran.
    private var legend: some View {
        VStack(alignment: .leading, spacing: 7) {
            legendItem(
                color: MicaboColor.inkTertiary,
                dashed: true,
                label: "Sans révision, tu oublies en quelques jours."
            )
            legendItem(
                color: MicaboColor.accent,
                dashed: false,
                label: "Chaque rappel au bon moment rallonge ta mémoire."
            )
        }
    }

    private func legendItem(color: Color, dashed: Bool, label: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            HStack(spacing: 2) {
                if dashed {
                    Capsule().fill(color).frame(width: 5, height: 3)
                    Capsule().fill(color).frame(width: 5, height: 3)
                    Capsule().fill(color).frame(width: 5, height: 3)
                } else {
                    Capsule().fill(color).frame(width: 19, height: 3)
                }
            }
            .frame(width: 19, alignment: .leading)

            Text(label)
                .font(MicaboFont.hanken(12, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Chaque révision porte son intervalle réel, posé juste au-dessus du point.
    private func intervalLabels(in size: CGSize) -> some View {
        ForEach(Array(RetentionCurve.reviewDays.enumerated()), id: \.offset) { _, day in
            let x = day / RetentionCurve.horizonDays
            let isVisible = progress >= x

            Text(RetentionCurve.intervalLabel(forDay: day))
                .font(MicaboFont.hanken(9.5, weight: .bold))
                .foregroundStyle(MicaboColor.accent)
                .monospacedDigit()
                .fixedSize()
                .opacity(isVisible ? 1 : 0)
                // Le premier point est collé au bord : on cale l'étiquette pour
                // qu'elle reste entière.
                .position(x: max(15, CGFloat(x) * size.width), y: 7)
                .animation(.easeOut(duration: 0.25), value: isVisible)
        }
    }

    private func grid(in size: CGSize) -> some View {
        ForEach(0..<4) { index in
            let y = point(x: 0, y: 1 - Double(index) / 3, in: size).y
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
                .animation(OnboardingMotion.shift, value: isVisible)
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

    /// Marge haute réservée aux étiquettes d'intervalle, pour qu'elles ne se posent
    /// pas sur les points de révision.
    private static let topInset: CGFloat = 20

    private func point(_ value: CGPoint, in size: CGSize) -> CGPoint {
        let usableHeight = max(1, size.height - Self.topInset)
        return CGPoint(
            x: value.x * size.width,
            y: Self.topInset + (1 - value.y) * usableHeight
        )
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
