import SwiftUI

/// **Le verre de la refonte** : les barres qui flottent sur le contenu — la barre d'onglets, la
/// navbar interne d'une leçon, la barre du haut quand on fait défiler.
///
/// Liquid Glass sur iOS 26 ; avant, un matériau fin, un filet clair et une ombre douce, qui en
/// donnent l'idée sans en avoir l'optique.
struct MicaboGlass<S: Shape>: ViewModifier {
    var shape: S
    var interactive = false

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.55), lineWidth: 1))
            .shadow(color: MicaboColor.ink.opacity(0.10), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func micaboGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(MicaboGlass(shape: shape, interactive: interactive))
    }
}

/// Le bouton d'action principal de la refonte : un aplat d'encre, texte blanc, coins arrondis.
/// « C'est parti », « Cercle suivant », « Terminer ».
struct LessonPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.ink
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.ui(18, weight: .heavy))
            .foregroundStyle(MicaboColor.onInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(
                enabled ? tint : MicaboColor.inkTertiary,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .shadow(color: tint.opacity(enabled ? 0.18 : 0), radius: 10, x: 0, y: 6)
            .micaboPressEffect(isPressed: configuration.isPressed, feedback: .medium)
    }
}
