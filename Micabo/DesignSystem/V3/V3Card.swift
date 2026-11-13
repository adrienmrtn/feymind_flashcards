import SwiftUI

/// **La surface de l'app** : un fond, un rayon, un filet de 1,5 pt. Pas de lèvre, pas d'ombre :
/// sur le marine, une surface se détache par sa clarté et son filet. Carte, ligne de réponse,
/// puce, tuile d'outil sont toutes faites ainsi ; seul le bouton principal a une lèvre.
struct V3SurfaceStyle: ViewModifier {
    var radius: CGFloat = V3Metric.radiusCard
    var fill: Color = V3Color.surface
    var border: Color = V3Color.line
    var borderWidth: CGFloat = V3Metric.border

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .background(fill, in: shape)
            .overlay {
                shape.strokeBorder(border, lineWidth: borderWidth)
            }
    }
}

/// Les deux couleurs d'une surface : son fond et son filet.
struct V3SurfaceColors {
    var fill: Color
    var border: Color

    /// Au repos : surface et filet. Choisie : lavis et filet d'accent. Dans un ton : le lavis du
    /// ton et un filet assorti (`V3Color.wash(of:)`, `V3Color.edge(of:)`).
    static func resolve(selected: Bool, tone: Color?) -> V3SurfaceColors {
        if selected {
            return V3SurfaceColors(fill: V3Color.accentWash, border: V3Color.accent)
        }
        if let tone {
            return V3SurfaceColors(fill: V3Color.wash(of: tone), border: V3Color.edge(of: tone))
        }
        return V3SurfaceColors(fill: V3Color.surface, border: V3Color.line)
    }
}

extension View {
    /// **La carte de l'app** : surface, rayon 22, filet de 1,5 pt, sans lèvre. Le contenu apporte
    /// ses marges.
    ///
    /// - `selected` : filet d'accent, fond de lavis bleu.
    /// - `tone` : une carte teintée (une réussite en vert, une alerte en rouge). On lui passe le
    ///   lavis (`V3Color.greenWash`) ou le plein (`V3Color.green`) : le fond et le filet s'en
    ///   déduisent.
    func v3Card(selected: Bool = false, tone: Color? = nil, radius: CGFloat = V3Metric.radiusCard) -> some View {
        let colors = V3SurfaceColors.resolve(selected: selected, tone: tone)
        return modifier(V3SurfaceStyle(radius: radius, fill: colors.fill, border: colors.border))
    }
}

/// **Le style de ce qui se touche** et qui dessine lui-même son contenu : une surface à
/// filet, qui s'enfonce d'un rien et vibre à l'appui. `V3OptionRow` et `V3Chip` le portent ; un
/// écran peut le donner à un `Button` dont il compose le contenu (une tuile d'outil).
struct V3TileButtonStyle: ButtonStyle {
    var selected: Bool = false
    var tone: Color?
    var radius: CGFloat = V3Metric.radiusInner
    /// Le fond d'une surface choisie, quand ce n'est pas le lavis (une puce choisie est pleine).
    var selectedFill: Color?
    var feedback: Haptics.Press = .selection

    func makeBody(configuration: Configuration) -> some View {
        let colors = V3SurfaceColors.resolve(selected: selected, tone: tone)
        let fill = selected ? (selectedFill ?? colors.fill) : colors.fill
        return configuration.label
            .modifier(V3SurfaceStyle(radius: radius, fill: fill, border: colors.border))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .micaboPressEffect(isPressed: configuration.isPressed, feedback: feedback)
            .hoverEffect(.highlight)
    }
}

/// **La coche de l'app** : un cercle de 24 pt. Choisie, un aplat d'accent et une coche blanche ;
/// vide, un anneau gris — qu'une ligne à choix unique ne montre pas (elle n'a de coche que
/// choisie), et qu'une ligne à choix multiple garde pour dire qu'on peut en cocher plusieurs.
struct V3Check: View {
    var isOn: Bool
    var size: CGFloat = V3Metric.check

    var body: some View {
        ZStack {
            Circle().fill(isOn ? V3Color.accent : Color.clear)
            Circle().strokeBorder(isOn ? V3Color.accent : V3Color.ink3, lineWidth: MicaboSurface.border)
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .black))
                    .foregroundStyle(V3Color.onAccent)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
