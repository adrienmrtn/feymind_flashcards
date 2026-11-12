import SwiftUI

/// **La forme « à lèvre » de V3** : une face au bord de 2 pt, posée sur une lèvre pleine de la
/// même couleur, qui dépasse dessous. Tout ce qui se touche est fait ainsi — carte, ligne de
/// réponse, puce — et s'enfonce sur sa lèvre à l'appui (`sunk`). Aucune ombre floue.
///
/// **Tout est dans le fond**, rien sur le contenu : la lèvre ne se lit pas en double sous
/// chaque mot. Le modificateur réserve la hauteur de la lèvre sous la face, pour que deux
/// surfaces empilées ne se chevauchent pas.
struct V3SurfaceStyle: ViewModifier {
    var radius: CGFloat = V3Metric.radiusCard
    var fill: Color = V3Color.surface
    var border: Color = V3Color.line
    var lipColor: Color = V3Color.line
    var lip: CGFloat = V3Metric.lip
    var borderWidth: CGFloat = V3Metric.border
    /// De combien la face est enfoncée : 0 au repos, `lip` sous le doigt.
    var sunk: CGFloat = 0

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background {
                ZStack {
                    shape.fill(lipColor).offset(y: lip - sunk)
                    shape.fill(fill)
                    shape.strokeBorder(border, lineWidth: borderWidth)
                }
            }
            .offset(y: sunk)
            .padding(.bottom, lip)
    }
}

/// Les trois couleurs d'une surface V3 : sa face, son bord, sa lèvre.
struct V3SurfaceColors {
    var fill: Color
    var border: Color
    var lip: Color

    /// Au repos : blanc, filet. Choisie : lavis, bord et lèvre d'accent. Dans un ton : le
    /// lavis du ton, et un bord assorti (`V3Color.wash(of:)`, `V3Color.edge(of:)`).
    static func resolve(selected: Bool, tone: Color?) -> V3SurfaceColors {
        if selected {
            return V3SurfaceColors(fill: V3Color.accentWash, border: V3Color.accent, lip: V3Color.accent)
        }
        if let tone {
            let edge = V3Color.edge(of: tone)
            return V3SurfaceColors(fill: V3Color.wash(of: tone), border: edge, lip: edge)
        }
        return V3SurfaceColors(fill: V3Color.surface, border: V3Color.line, lip: V3Color.line)
    }
}

extension View {
    /// **La carte V3** : bord de 2 pt, lèvre de 4 pt, rayon 24. Le contenu apporte ses marges.
    ///
    /// - `selected` : bord et lèvre d'accent, fond de lavis bleu.
    /// - `tone` : une carte teintée (la réaction verte de Mika, une alerte rose). On lui passe
    ///   le lavis (`V3Color.greenWash`) ou le plein (`V3Color.green`) : le fond et le bord
    ///   s'en déduisent.
    func v3Card(selected: Bool = false, tone: Color? = nil, radius: CGFloat = V3Metric.radiusCard) -> some View {
        let colors = V3SurfaceColors.resolve(selected: selected, tone: tone)
        return modifier(
            V3SurfaceStyle(radius: radius, fill: colors.fill, border: colors.border, lipColor: colors.lip)
        )
    }
}

/// **Le style de ce qui se touche en V3** et qui dessine lui-même son contenu : la face
/// s'enfonce sur sa lèvre à l'appui, avec un retour haptique. `V3OptionRow` et `V3Chip` le
/// portent ; un écran peut le donner à un `Button` dont il compose le contenu.
struct V3TileButtonStyle: ButtonStyle {
    var selected: Bool = false
    var tone: Color?
    var radius: CGFloat = V3Metric.radiusButton
    var lip: CGFloat = V3Metric.lip
    var feedback: Haptics.Press = .selection

    func makeBody(configuration: Configuration) -> some View {
        let colors = V3SurfaceColors.resolve(selected: selected, tone: tone)
        let sunk: CGFloat = configuration.isPressed ? lip : 0
        return configuration.label
            .modifier(
                V3SurfaceStyle(
                    radius: radius,
                    fill: colors.fill,
                    border: colors.border,
                    lipColor: colors.lip,
                    lip: lip,
                    sunk: sunk
                )
            )
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .animation(MicaboPress.animation(isPressed: configuration.isPressed), value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: feedback)
            .hoverEffect(.highlight)
    }
}

/// **La coche V3** : un cercle de 26 pt au bord gris ; choisie, un aplat d'accent et une coche
/// blanche. `square` l'arrondit en case, pour un choix multiple.
struct V3Check: View {
    var isOn: Bool
    var square: Bool = false
    var size: CGFloat = V3Metric.check

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: square ? 8 : size / 2, style: .continuous)
        ZStack {
            shape.fill(isOn ? V3Color.accent : Color.clear)
            shape.strokeBorder(isOn ? V3Color.accent : V3Color.lip, lineWidth: 2.5)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .black))
                    .foregroundStyle(V3Color.onAccent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
