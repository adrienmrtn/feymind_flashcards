import SwiftUI

/// **La scène de marque** : le grand aplat bleu Micabo, d'où Mika sort par le bas, comme sur
/// l'icône et l'écran de lancement (`design/micabo-kit-mika/icone/`).
///
/// Home, le paywall et l'aperçu de la leçon verrouillée la partagent, avec les mêmes mesures :
/// un écran qui change de rayon ou de bleu d'une carte à l'autre se lit comme trois apps.
///
/// Le bleu est **une constante de la marque**, pas `MicaboColor.accent` : la nuit, l'accent
/// s'éclaircit pour se lire sur le noir, et la scène doit rester exactement le bleu de l'icône,
/// celui sur lequel le corps noir de Mika se détache.
enum MicaboStage {
    /// Le rayon de la scène : la plus grande surface de l'écran.
    static let heroRadius: CGFloat = 32
    /// Le rayon d'une carte posée sur la page.
    static let cardRadius: CGFloat = 26
    /// Le rayon d'une tuile ou d'une offre.
    static let tileRadius: CGFloat = 20
    /// Le rayon du grand bouton de marque.
    static let buttonRadius: CGFloat = 18

    /// Le texte posé sur le bleu.
    static let ink = Color.white
    static let inkSecondary = Color.white.opacity(0.86)

    /// L'aplat : le bleu Micabo, à peine plus profond en bas (le 600 de la gamme).
    static var fill: LinearGradient {
        LinearGradient(colors: [MicaboBrand.blue, MicaboBrand.blue600], startPoint: .top, endPoint: .bottom)
    }

    /// Le grand bouton : du bleu Micabo vers le 600, de gauche à droite.
    static var buttonFill: LinearGradient {
        LinearGradient(colors: [MicaboBrand.blue, MicaboBrand.blue600], startPoint: .leading, endPoint: .trailing)
    }
}

/// **L'aplat de marque** : le bleu, une lueur blanche très douce dans le coin haut, et deux
/// ou trois étincelles blanches — celle du crayon de Mika, en écho. Rien ne bouge : c'est un
/// fond, il ne doit pas tirer l'œil de ce qui est posé dessus.
struct MicaboBrandBackdrop: View {
    var sparkles = true

    var body: some View {
        ZStack {
            MicaboStage.fill
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [Color.white.opacity(0.20), Color.white.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.55
                        ))
                        .frame(width: width * 1.1, height: width * 1.1)
                        .position(x: width * 0.08, y: height * 0.02)
                    if sparkles {
                        MicaboSparkleShape()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: 14, height: 14)
                            .position(x: width * 0.56, y: min(34, height * 0.2))
                        MicaboSparkleShape()
                            .fill(Color.white.opacity(0.55))
                            .frame(width: 8, height: 8)
                            .position(x: width * 0.66, y: min(58, height * 0.32))
                        MicaboSparkleShape()
                            .fill(Color.white.opacity(0.4))
                            .frame(width: 7, height: 7)
                            .position(x: width * 0.92, y: min(26, height * 0.16))
                    }
                }
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// L'étincelle à quatre branches de Micabo, celle du bout du crayon.
struct MicaboSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let pinch = radius * 0.16
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: CGPoint(x: center.x + pinch, y: center.y - pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: CGPoint(x: center.x + pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: CGPoint(x: center.x - pinch, y: center.y + pinch))
        path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: CGPoint(x: center.x - pinch, y: center.y - pinch))
        path.closeSubpath()
        return path
    }
}

/// **Le grand bouton de marque** : le bouton principal de l'app (`MicaboPrimaryFill`), avec
/// une hauteur et une taille de texte réglables. Le même sur Home, le paywall et l'aperçu
/// verrouillé — un seul par écran.
///
/// `minHeight` et non une hauteur : avec les grandes tailles de texte, le libellé pousse le
/// bouton au lieu d'être coupé.
struct MicaboBrandButtonStyle: ButtonStyle {
    var minHeight: CGFloat = MicaboButtonMetrics.height
    var fontSize: CGFloat = 17
    var feedback: Haptics.Press = .medium

    func makeBody(configuration: Configuration) -> some View {
        MicaboPrimaryFill(
            label: configuration.label,
            minHeight: minHeight,
            fontSize: fontSize,
            isPressed: configuration.isPressed,
            feedback: feedback
        )
    }
}
