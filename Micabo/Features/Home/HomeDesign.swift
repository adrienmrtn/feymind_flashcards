import SwiftUI

// MARK: - Les couleurs de Home

/// **Les couleurs de Home : celles de l'app.**
///
/// La page suit le papier de Micabo (`MicaboColor`) : l'ivoire le jour, le graphite la nuit,
/// des cartes blanches ou anthracite. Mika y vit, noir sur le clair (la règle de mise en scène,
/// en tête de `MikaMascot.swift`) ; le bleu de la marque (`MicaboStage`) n'est plus qu'un
/// accent : le grand bouton, l'anneau, les pastilles.
enum HomePalette {
    static var canvas: Color { MicaboColor.canvas }
    static var card: Color { MicaboColor.surface }
    static var cardStroke: Color { MicaboColor.stroke }
    static var ink: Color { MicaboColor.ink }
    static var inkSecondary: Color { MicaboColor.inkSecondary }
    static var inkTertiary: Color { MicaboColor.inkTertiary }
    static var track: Color { MicaboColor.track }
    static var done: Color { MicaboColor.correctInk }
    static var doneSoft: Color { MicaboColor.correctSoft }

    /// Le jaune du crayon, pour l'éclair de l'XP : l'accent qu'on garde rare.
    static let bolt = MicaboBrand.pencil
    /// Le texte de la bulle de Mika, toujours blanche : une encre fixe, pas celle du thème.
    static let bubbleInk = Color(hex: 0x1B1E24)

    /// **Le dégradé de marque, en aplat sous du texte blanc** : constant, pour que le blanc
    /// s'y lise aussi la nuit.
    static var brand: LinearGradient { MicaboStage.buttonFill }
}

// MARK: - Le mouvement

private struct HomeStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Home immobile** : tout est posé dans son état final, sans entrée, sans frappe, sans
    /// flottement. Les rendus de la CI le demandent (`ImageRenderer` ne dessine qu'une image) ;
    /// « Réduire les animations » donne le même résultat par `HomeMotion`.
    var homeStill: Bool {
        get { self[HomeStillKey.self] }
        set { self[HomeStillKey.self] = newValue }
    }
}

/// **L'appui de Home** : un enfoncement net, et la vibration à l'enfoncement, comme partout
/// (`micaboPressFeedback`).
struct HomePressStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(MicaboMotion.quick, value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: feedback)
    }
}

extension View {
    /// La carte de la page : **la surface de l'app** (`micaboSurface`), blanche le jour,
    /// marine la nuit, un filet et sa lèvre.
    func homeCard(radius: CGFloat = MicaboStage.cardRadius) -> some View {
        micaboSurface(radius: radius, fill: HomePalette.card, stroke: HomePalette.cardStroke)
    }

    /// **La même carte, qui coupe ce qu'elle porte** : pour un Mika qui sort de son bord bas.
    /// La coupe ne prend que le contenu : la lèvre reste visible.
    func homeCardClipped(radius: CGFloat = MicaboStage.cardRadius) -> some View {
        micaboSurface(radius: radius, fill: HomePalette.card, stroke: HomePalette.cardStroke, clipped: true)
    }
}
