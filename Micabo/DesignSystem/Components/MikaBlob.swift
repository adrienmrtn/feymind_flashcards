import SwiftUI

/// **Mika, l'assistant : un blob qui respire.**
///
/// Pas un personnage, pas un visage : une forme ronde, organique, qui ondule lentement sous
/// un dégradé violet, rose, orange. C'est ce qui le distingue de la mascotte d'avant — un
/// petit bonhomme violet avec des yeux — et c'est voulu : un assistant qui parle n'a pas
/// besoin d'une bouche, il a besoin d'une présence, et une forme qui bouge doucement en
/// est une.
///
/// **La forme est un cercle déformé par quatre ondes lentes.** Huit points posés autour
/// d'un cercle, dont le rayon monte et descend selon des sinus de fréquences différentes ;
/// une courbe fermée passe par eux (Catmull-Rom converti en Bézier), et le tout est
/// redessiné à chaque image par une `TimelineView`. Deux fréquences ne se retrouvent
/// jamais en phase : le blob ne repasse pas par la même forme, et il ne se lit jamais
/// comme une boucle.
struct MikaBlob: View {
    var size: CGFloat = 220
    /// L'amplitude des ondulations, en fraction du rayon. Douze pour cent : un blob, pas
    /// une amibe.
    var wobble: CGFloat = 0.12
    /// La vitesse, en tours d'onde par seconde. Lente : Mika respire, il ne s'agite pas.
    var speed: Double = 0.18

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate * speed
            MikaBlobShape(time: time, wobble: wobble)
                .fill(
                    LinearGradient(
                        colors: OnboardingPalette.mikaGradient.reversed(),
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                // Un reflet doux en haut à droite, comme une lumière posée sur quelque chose
                // de mat : c'est ce qui donne le volume sans dessiner une ombre.
                .overlay {
                    MikaBlobShape(time: time, wobble: wobble)
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                                center: UnitPoint(x: 0.68, y: 0.22),
                                startRadius: 0,
                                endRadius: size * 0.55
                            )
                        )
                }
                .shadow(color: OnboardingPalette.mikaGradient[0].opacity(0.22), radius: size * 0.12, y: size * 0.06)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Le contour du blob à un instant donné.
struct MikaBlobShape: Shape {
    var time: Double
    var wobble: CGFloat = 0.12

    private static let points = 8

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Le rayon de base laisse la place aux ondulations : sans ça, la forme sort du
        // cadre à chaque bosse.
        let base = min(rect.width, rect.height) / 2 * (1 - wobble)

        let vertices: [CGPoint] = (0..<Self.points).map { index in
            let angle = Double(index) / Double(Self.points) * 2 * .pi
            // Quatre ondes de fréquences et de phases différentes : la somme ne se répète
            // pas, et chaque bosse voyage à sa vitesse.
            let wave = sin(angle * 2 + time * 2 * .pi)
                + 0.6 * sin(angle * 3 - time * 1.7 * .pi + 1.3)
                + 0.4 * sin(angle * 5 + time * 1.1 * .pi + 2.1)
                + 0.3 * cos(angle * 1 + time * 0.6 * .pi)
            let radius = base * (1 + wobble * CGFloat(wave) / 2.3)
            return CGPoint(
                x: center.x + radius * CGFloat(cos(angle)),
                y: center.y + radius * CGFloat(sin(angle))
            )
        }

        return Self.closedCurve(through: vertices)
    }

    /// Une courbe fermée et lisse par les points : Catmull-Rom, converti en segments de
    /// Bézier. La tension est celle qui donne des bosses rondes sans creux pointus.
    static func closedCurve(through points: [CGPoint], tension: CGFloat = 0.5) -> Path {
        var path = Path()
        let count = points.count
        guard count >= 3 else { return path }
        path.move(to: points[0])
        for index in 0..<count {
            let p0 = points[(index - 1 + count) % count]
            let p1 = points[index]
            let p2 = points[(index + 1) % count]
            let p3 = points[(index + 2) % count]
            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * tension / 3,
                y: p1.y + (p2.y - p0.y) * tension / 3
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * tension / 3,
                y: p2.y - (p3.y - p1.y) * tension / 3
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}

/// **Un texte peint du dégradé de Mika**, de gauche à droite.
struct MikaGradientText: View {
    let text: String
    var size: CGFloat = 24
    var weight: Font.Weight = .bold

    var body: some View {
        Text(text)
            .font(MicaboFont.ui(size, weight: weight))
            .tracking(-0.4)
            .multilineTextAlignment(.center)
            .foregroundStyle(
                LinearGradient(
                    colors: OnboardingPalette.mikaGradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}
