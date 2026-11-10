import SwiftUI

// MARK: - Les couleurs de Home

/// **Les couleurs de Home : celles de l'app, et la scène de marque.**
///
/// La page suit le papier de Micabo (`MicaboColor`) : l'ivoire le jour, le graphite la nuit,
/// des cartes blanches ou anthracite. La scène de Mika, elle, reste le bleu de la marque
/// (`MicaboStage`) dans les deux apparences : c'est là que le corps noir de Mika se lit.
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

/// Ce qui bouge sur Home, et ce qui reste en place quand on le demande.
struct HomeMotion {
    let still: Bool
    let reduceMotion: Bool

    /// Le flottement de Mika, la frappe de la bulle, la flamme qui vacille.
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
            .offset(y: visible || motion.reduceMotion ? 0 : 18)
            .animation(
                motion.reduceMotion
                    ? .easeOut(duration: 0.2)
                    : .spring(response: 0.55, dampingFraction: 0.82).delay(0.06 * Double(index)),
                value: visible
            )
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
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: feedback)
    }
}

extension View {
    /// La carte de la page : blanche le jour, anthracite la nuit, un filet et une ombre douce.
    func homeCard(radius: CGFloat = MicaboStage.cardRadius) -> some View {
        background(HomePalette.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(HomePalette.cardStroke, lineWidth: 1))
            .shadow(color: MicaboBrand.blue900.opacity(0.06), radius: 16, y: 8)
    }
}
