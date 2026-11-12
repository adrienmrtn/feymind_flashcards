import SwiftUI

/// **La jauge V3** : 10 pt de haut, arrondie, l'accent sur le filet. `value` va de 0 à 1.
///
/// Elle avance sur la courbe standard de l'app, et d'un fondu avec « Réduire les animations ».
/// En arabe, elle se remplit de droite à gauche.
struct V3ProgressBar: View {
    private let value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.v3Tint) private var tint

    init(value: Double) {
        self.value = value
    }

    private var clamped: Double {
        guard value.isFinite else { return 0 }
        return min(1, max(0, value))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint?.opacity(0.3) ?? V3Color.line)
                if clamped > 0 {
                    Capsule()
                        .fill(tint ?? V3Color.accent)
                        // Un premier pas se voit : la jauge n'est jamais plus étroite qu'un point.
                        .frame(width: max(V3Metric.progressHeight, proxy.size.width * clamped))
                }
            }
        }
        .frame(height: V3Metric.progressHeight)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: clamped)
        .accessibilityElement()
        .accessibilityValue(Text(L10n.percent(Int((clamped * 100).rounded()), locale: .resolved())))
    }
}
