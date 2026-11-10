import SwiftUI
import UIKit

// MARK: - Les couleurs de Home

/// **Les couleurs de Home, et d'elle seule.**
///
/// Home a son propre décor : un ciel de nuit bleu marine qui tourne à l'indigo, avec deux
/// lueurs, bleue et violette, qui dérivent lentement derrière Mika. C'est l'écran qu'on ouvre
/// tous les jours, celui qui doit donner envie ; les autres écrans gardent le papier de
/// Micabo. D'où un jeu de jetons à part, plutôt qu'un `MicaboColor` qui bougerait partout.
///
/// **Le haut est sombre dans les deux apparences** — c'est la scène de Mika, la bulle et la
/// barre. Dessous, la page suit le thème : un lavande très clair le jour, le même marine la
/// nuit. Chaque jeton « canvas » se résout au moment de peindre, comme `MicaboPalette`.
///
/// Les contrastes ont été vérifiés sur leur fond : `heroInkSecondary` fait 9:1 sur le marine,
/// `inkSecondary` 6:1 sur le blanc le jour et 7:1 sur la carte marine la nuit.
enum HomePalette {
    // MARK: La scène (toujours sombre)

    static let heroTop = Color(hex: 0x080C27)
    static let heroMid = Color(hex: 0x111743)
    static let heroBottom = Color(hex: 0x23196A)
    static let glowBlue = Color(hex: 0x2F6BFF)
    static let glowViolet = Color(hex: 0x8B5CF6)
    static let glowPink = Color(hex: 0xD946EF)
    static let heroInk = Color.white
    static let heroInkSecondary = Color(hex: 0xC5C9F2)
    static let heroInkTertiary = Color(hex: 0x8E93C7)
    /// Le verre posé sur la scène : pastilles, barre, raccourcis.
    static let glass = Color.white.opacity(0.09)
    static let glassStrong = Color.white.opacity(0.15)
    static let glassStroke = Color.white.opacity(0.16)
    /// Un support illisible, écrit sur la scène : le rouge de l'app s'y perdrait.
    static let heroError = Color(hex: 0xFF9E9E)
    static let bolt = Color(hex: 0xFFC53D)

    // MARK: Le dégradé de Micabo

    /// **Le bleu-violet de Micabo, en aplat sous du texte blanc.** Ce sont les valeurs du
    /// jour de `MicaboColor.accent` et `MicaboColor.keyword` : la nuit, ces deux jetons
    /// s'éclaircissent pour se lire sur le noir, et un « Pro » blanc ne se lirait plus dessus.
    static let brandStart = Color(hex: 0x2563EB)
    static let brandEnd = Color(hex: 0x7C3AED)
    static var brand: LinearGradient {
        LinearGradient(colors: [brandStart, brandEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: La page (suit le thème)

    static let canvas = adaptive(0xF3F1FF, 0x0B0F2A)
    static let card = adaptive(0xFFFFFF, 0x161B45)
    static let cardStroke = adaptive(0xE8E3FB, 0x252A5C)
    static let ink = adaptive(0x161933, 0xF5F4FF)
    static let inkSecondary = adaptive(0x5A5E82, 0xA9AEDB)
    static let inkTertiary = adaptive(0x9598B6, 0x6F74A3)
    static let track = adaptive(0xECE8FB, 0x262B5E)
    static let rowFill = adaptive(0xF7F5FF, 0x1C2252)
    static let done = adaptive(0x16A34A, 0x34D399)
    static let doneSoft = adaptive(0xDCFCE7, 0x123A2E)
    static let cardShadow = adaptive(0x4C3BCF, 0x000000)

    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        let light = UIColor(Color(hex: light))
        let dark = UIColor(Color(hex: dark))
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}

// MARK: - Le mouvement

private struct HomeStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Home immobile** : tout est posé dans son état final, sans entrée, sans frappe, sans
    /// dérive. Les rendus de la CI le demandent (`ImageRenderer` ne dessine qu'une image) ;
    /// « Réduire les animations » donne le même résultat par `HomeMotion`.
    var homeStill: Bool {
        get { self[HomeStillKey.self] }
        set { self[HomeStillKey.self] = newValue }
    }
}

/// Ce qui bouge sur Home, et ce qui reste en place quand on le demande.
struct HomeMotion {
    let still: Bool
    let reduceMotion: Bool

    /// La dérive des lueurs, le flottement de Mika, la frappe de la bulle, le reflet du Pro.
    var ambient: Bool { !still && !reduceMotion }
    /// L'entrée des blocs : un fondu reste permis avec « Réduire les animations ».
    var entrance: Bool { !still }
}

extension View {
    /// **L'entrée d'un bloc**, l'un après l'autre : il monte de quelques points et apparaît,
    /// sur un ressort. Une seule fois : `shown` est tenu par Home, pas par le bloc.
    func homeEntrance(_ index: Int, shown: Bool, motion: HomeMotion) -> some View {
        modifier(HomeEntrance(index: index, shown: shown, motion: motion))
    }
}

private struct HomeEntrance: ViewModifier {
    let index: Int
    let shown: Bool
    let motion: HomeMotion

    func body(content: Content) -> some View {
        let visible = shown || !motion.entrance
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible || motion.reduceMotion ? 0 : 22)
            .scaleEffect(visible || motion.reduceMotion ? 1 : 0.97, anchor: .top)
            .animation(
                motion.reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(response: 0.55, dampingFraction: 0.78).delay(0.06 * Double(index)),
                value: visible
            )
    }
}

/// **L'appui de Home** : un enfoncement plus franc que celui du reste de l'app — on est sur
/// des pastilles et des cartes colorées qu'on a envie de toucher — et la vibration à
/// l'enfoncement, comme partout (`micaboPressFeedback`).
struct HomePressStyle: ButtonStyle {
    var scale: CGFloat = 0.95
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: feedback)
    }
}

// MARK: - La scène

/// **Le ciel de Home** : un dégradé marine vers indigo, deux grandes lueurs bleue et violette
/// et une rose plus discrète, qui dérivent sur une dizaine de secondes. Les lueurs sont des
/// dégradés radiaux, pas des flous : rien ne se recalcule pendant qu'elles bougent.
struct HomeSky: View {
    let motion: HomeMotion

    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: HomePalette.heroTop, location: 0),
                    .init(color: HomePalette.heroMid, location: 0.55),
                    .init(color: HomePalette.heroBottom, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                ZStack {
                    glow(HomePalette.glowBlue, size: width * 1.05, opacity: 0.55)
                        .position(x: width * 0.92, y: height * 0.72)
                        .offset(x: drift ? -36 : 18, y: drift ? 28 : -22)
                        .animation(drifting(13), value: drift)
                    glow(HomePalette.glowViolet, size: width * 1.1, opacity: 0.6)
                        .position(x: width * 0.05, y: height * 0.9)
                        .offset(x: drift ? 30 : -14, y: drift ? -26 : 16)
                        .animation(drifting(11), value: drift)
                    glow(HomePalette.glowPink, size: width * 0.7, opacity: 0.28)
                        .position(x: width * 0.55, y: height * 1.02)
                        .offset(x: drift ? -24 : 26, y: drift ? -10 : 12)
                        .animation(drifting(9), value: drift)
                    sparkles(width: width, height: height)
                }
            }
        }
        .compositingGroup()
        .onAppear {
            guard motion.ambient else { return }
            drift = true
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func drifting(_ seconds: Double) -> Animation? {
        motion.ambient ? .easeInOut(duration: seconds).repeatForever(autoreverses: true) : nil
    }

    private func glow(_ color: Color, size: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(RadialGradient(
                colors: [color.opacity(opacity), color.opacity(opacity * 0.35), color.opacity(0)],
                center: .center,
                startRadius: 0,
                endRadius: size / 2
            ))
            .frame(width: size, height: size)
    }

    /// Quelques points de lumière, posés une fois pour toutes : un ciel, pas un fond d'écran.
    private func sparkles(width: CGFloat, height: CGFloat) -> some View {
        let points: [(CGFloat, CGFloat, CGFloat, Double)] = [
            (0.12, 0.30, 2.5, 0.55), (0.30, 0.19, 1.5, 0.4), (0.58, 0.28, 2, 0.5),
            (0.86, 0.22, 1.5, 0.45), (0.72, 0.42, 2.5, 0.35), (0.07, 0.52, 1.5, 0.35),
            (0.44, 0.47, 1.5, 0.3), (0.94, 0.55, 2, 0.4),
        ]
        return ZStack {
            ForEach(points.indices, id: \.self) { index in
                let point = points[index]
                Circle()
                    .fill(Color.white.opacity(point.3))
                    .frame(width: point.2, height: point.2)
                    .position(x: width * point.0, y: height * point.1)
            }
        }
    }
}

// MARK: - Les petites pièces

/// **Un intitulé de section** sur la page : en capitales, avec ce qu'il faut à droite.
struct HomeSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(MicaboFont.ui(13, weight: .black))
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(HomePalette.inkSecondary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 4)
    }
}

extension HomeSectionHeader where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}

/// **« +30 XP »** : la récompense d'une mission, en pastille.
struct HomeRewardChip: View {
    enum Reward: Equatable {
        case xp(Int)
        case streak
    }

    let reward: Reward
    var done = false

    var body: some View {
        HStack(spacing: 3) {
            switch reward {
            case .xp(let points):
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10, weight: .black))
                Text(L10n.t("ios.kx.xp.gain", locale: .resolved(), vars: ["n": "\(points)"]))
                    .font(MicaboFont.ui(13, weight: .black))
                    .monospacedDigit()
            case .streak:
                Text("+1")
                    .font(MicaboFont.ui(13, weight: .black))
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .black))
            }
        }
        .foregroundStyle(done ? HomePalette.done : foreground)
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(done ? HomePalette.doneSoft : background, in: Capsule())
        .fixedSize()
        .opacity(done ? 0.85 : 1)
    }

    private var foreground: Color {
        switch reward {
        case .xp: LessonTone.yellow.ink
        case .streak: MicaboColor.flameInk
        }
    }

    private var background: Color {
        switch reward {
        case .xp: LessonTone.yellow.pale
        case .streak: MicaboColor.flameSoft
        }
    }
}

extension View {
    /// La carte de la page : blanche le jour, marine la nuit, un filet et une ombre teintée.
    func homeCard(radius: CGFloat = 26) -> some View {
        background(HomePalette.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(HomePalette.cardStroke, lineWidth: 1))
            .shadow(color: HomePalette.cardShadow.opacity(0.07), radius: 18, y: 10)
    }

    /// Le verre de la scène : pastilles et barre posées sur le ciel.
    func homeGlass<S: InsettableShape>(_ shape: S, fill: Color = HomePalette.glass) -> some View {
        background(fill, in: shape)
            .overlay(shape.strokeBorder(HomePalette.glassStroke, lineWidth: 1))
    }
}
