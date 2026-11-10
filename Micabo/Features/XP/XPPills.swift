import SwiftUI

/// **L'XP de la semaine, en haut de Home** (`docs/refonte-knowunity.md` § 1) : l'emoji de la
/// ligue, l'éclair et le nombre. Un appui ouvre la ligue.
struct XPPill: View {
    let action: () -> Void

    @Environment(XPStore.self) private var injected: XPStore?

    private var xp: XPStore { injected ?? .shared }

    var body: some View {
        let week = xp.week
        let league = xp.league
        Button(action: action) {
            HStack(spacing: 5) {
                Text(league.emoji)
                    .font(.system(size: 17))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(LessonTone.yellow.ink)
                Text("\(week)")
                    .font(MicaboFont.number(18))
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(week)))
            }
            .padding(.leading, 10)
            .padding(.trailing, 13)
            .frame(height: 40)
            .background(MicaboColor.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            .animation(.spring(duration: 0.4), value: week)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(L10n.t("ios.kx.xp.pillA11y", locale: .resolved(), vars: ["xp": "\(week)", "league": league.name])))
    }
}

/// **« ✦ Pro »**, pour qui n'est pas abonné : la pilule dans le dégradé de l'app, qui ouvre le
/// paywall (déclencheur `upgrade`, celui de « Passer en Pro » dans le Profil).
struct ProPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("✦")
                    .font(.system(size: 14, weight: .black))
                Text(L10n.t("ios.kx.pro.pill", locale: .resolved()))
                    .font(MicaboFont.ui(16, weight: .heavy))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(
                LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
            .shadow(color: MicaboColor.accent.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(L10n.t("ios.kx.pro.a11y", locale: .resolved())))
    }
}

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
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 1))
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
                    LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: progress >= 1 ? "checkmark" : "bolt.fill")
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(progress >= 1 ? MicaboColor.correct : LessonTone.yellow.ink)
        }
        .frame(width: size, height: size)
        .animation(.spring(duration: 0.6), value: progress)
        .accessibilityHidden(true)
    }
}
