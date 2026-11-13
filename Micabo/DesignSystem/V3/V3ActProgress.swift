import SwiftUI

/// **La jauge d'un parcours découpé en actes** (lot 12) : un segment par acte, séparés de
/// 4 pt. Les actes finis sont pleins, celui en cours se remplit, les suivants attendent.
///
/// Elle dit deux choses à la fois : où l'on en est (le segment courant avance à chaque écran)
/// et ce qui a déjà été bouclé (un acte fini se ferme d'un coup). Elle avance sur la courbe
/// standard de l'app, d'un fondu avec « Réduire les animations », et se remplit de droite à
/// gauche en arabe.
struct V3ActProgress: View {
    /// Le nombre d'actes.
    let acts: Int
    /// L'acte en cours, de 0 à `acts - 1`.
    let act: Int
    /// L'avancée dans l'acte en cours, de 0 à 1.
    let fraction: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedFraction: Double {
        guard fraction.isFinite else { return 0 }
        return min(1, max(0, fraction))
    }

    /// Le remplissage d'un segment.
    func fill(of index: Int) -> Double {
        if index < act { return 1 }
        if index > act { return 0 }
        return clampedFraction
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< max(1, acts), id: \.self) { index in
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(V3Color.line)
                        let value = fill(of: index)
                        if value > 0 {
                            Capsule()
                                .fill(V3Color.accent)
                                .frame(width: max(V3Metric.progressHeight, proxy.size.width * value))
                        }
                    }
                }
                .frame(height: V3Metric.progressHeight)
            }
        }
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: act)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: clampedFraction)
        .accessibilityElement()
        .accessibilityValue(Text(L10n.percent(Int((overall * 100).rounded()), locale: .resolved())))
    }

    /// L'avancée totale, pour le lecteur d'écran.
    private var overall: Double {
        guard acts > 0 else { return 0 }
        return (Double(min(act, acts)) + clampedFraction) / Double(acts)
    }
}
