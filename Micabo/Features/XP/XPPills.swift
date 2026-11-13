import SwiftUI

/// **« +10 XP »** dans un retour de quiz ou de carte (§ 6) : une petite pastille, à côté du
/// verdict qui existe déjà.
struct XPBadge: View {
    let points: Int
    var tint: Color = MicaboColor.accent

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .black))
            Text(L10n.t("ios.kx.xp.gain", locale: .resolved(), vars: ["n": "\(points)"]))
                .font(MicaboFont.ui(13, weight: .heavy))
                .monospacedDigit()
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(MicaboColor.surface.opacity(0.85), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: MicaboSurface.border))
        .fixedSize()
    }
}

/// **Un mot qui félicite** sur une bonne réponse (§ 6), tiré au hasard mais stable pour une
/// même question : le panneau se redessine sans changer de mot sous les yeux.
enum XPCheer {
    static let keys = ["ios.kx.cheer.1", "ios.kx.cheer.2", "ios.kx.cheer.3", "ios.kx.cheer.4"]

    static func word(for seed: String) -> String {
        let key = keys[Int(StableHash.of(seed) % UInt64(keys.count))]
        return L10n.t(key, locale: .resolved())
    }
}

/// L'anneau de l'objectif du jour : `xpToday / 50`, plein et coché une fois atteint.
struct XPGoalRing: View {
    let progress: Double
    var size: CGFloat = 58
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle().stroke(MicaboColor.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(
                    LinearGradient(colors: MicaboColor.brandGradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: progress >= 1 ? "checkmark" : "bolt.fill")
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(progress >= 1 ? MicaboColor.correct : LessonTone.yellow.ink)
        }
        .frame(width: size, height: size)
        .animation(MicaboMotion.gentle, value: progress)
        .accessibilityHidden(true)
    }
}
