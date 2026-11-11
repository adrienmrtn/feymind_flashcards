import SwiftUI

/// **Le verre de la refonte** : les barres qui flottent sur le contenu — la barre d'onglets, la
/// navbar interne d'une leçon, la barre du haut quand on fait défiler.
///
/// Liquid Glass sur iOS 26 ; avant, un matériau fin, un filet clair et une ombre douce, qui en
/// donnent l'idée sans en avoir l'optique.
struct MicaboGlass<S: Shape>: ViewModifier {
    var shape: S
    var interactive = false

    @Environment(\.colorScheme) private var colorScheme

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
            .overlay(shape.stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.55), lineWidth: 1))
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.10), radius: 18, x: 0, y: 8)
    }
}

extension View {
    func micaboGlass<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(MicaboGlass(shape: shape, interactive: interactive))
    }
}

/// Le bouton d'action principal d'une leçon, d'un quiz, d'un import : « C'est parti »,
/// « Cercle suivant », « Terminer ». **Le bouton principal de l'app** (`MicaboPrimaryFill`) :
/// il était d'encre noire, et un bouton noir sur un écran puis un bleu sur le suivant disaient
/// deux choses différentes pour la même. `enabled` à faux l'éteint en gris.
struct LessonPrimaryButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.accent
    var enabled = true

    func makeBody(configuration: Configuration) -> some View {
        MicaboPrimaryFill(
            label: configuration.label,
            tint: tint,
            fontSize: 17,
            enabled: enabled,
            isPressed: configuration.isPressed,
            feedback: .medium
        )
    }
}
