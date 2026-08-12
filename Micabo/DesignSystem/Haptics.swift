import UIKit

/// Retours haptiques de l'app. Les générateurs sont conservés et préparés à l'avance :
/// sans cela, la première vibration arrive avec un retard visible sur l'animation.
///
/// Le type n'est pas isolé au `MainActor` : tous les appels partent déjà du fil principal
/// (corps de vue, `onAppear`, blocs postés sur `DispatchQueue.main`), et l'isoler ferait
/// remonter des erreurs sur les blocs différés qui rythment les animations du parcours.
enum Haptics {
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    /// À appeler à l'apparition d'un écran interactif.
    static func prepare() {
        selectionGenerator.prepare()
        lightGenerator.prepare()
        mediumGenerator.prepare()
    }

    /// Choix dans une liste, changement de valeur d'un curseur.
    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    /// Élément qui apparaît, carte qui se pose.
    static func tick() {
        lightGenerator.impactOccurred(intensity: 0.6)
    }

    static func light() {
        lightGenerator.impactOccurred()
    }

    static func soft() {
        softGenerator.impactOccurred()
    }

    /// Action principale : bouton d'avancement du parcours.
    static func medium() {
        mediumGenerator.impactOccurred()
        mediumGenerator.prepare()
    }

    static func rigid() {
        rigidGenerator.impactOccurred()
    }

    static func success() {
        notificationGenerator.notificationOccurred(.success)
    }

    static func warning() {
        notificationGenerator.notificationOccurred(.warning)
    }

    /// Série de petites impulsions, utilisée pendant les compteurs et les curseurs animés.
    static func burst(count: Int, over duration: Double, intensity: CGFloat = 0.45) {
        guard count > 0 else { return }
        let interval = duration / Double(count)
        for index in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(index)) {
                lightGenerator.impactOccurred(intensity: intensity)
            }
        }
    }
}
