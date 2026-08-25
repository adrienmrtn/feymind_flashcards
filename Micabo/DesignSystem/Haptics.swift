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

extension Haptics {
    /// **Ce que le doigt sent quand il appuie.**
    ///
    /// Toutes les vibrations d'appui de l'app passent par ce type, et par les styles de
    /// bouton qui le portent. C'est ce qui permet de dire « tout ce qui se touche vibre »
    /// sans écrire un appel dans chacune des cent actions de l'app — et surtout sans en
    /// écrire deux au même endroit : un appui qui vibre deux fois s'entend, et ça ne
    /// ressemble pas à une réponse, ça ressemble à un défaut.
    ///
    /// La vibration part à l'**enfoncement**, pas au relâchement. C'est le moment où le
    /// doigt attend une réponse : la déclencher à l'action la ferait arriver après
    /// l'animation, et sur les boutons qui lancent un travail elle arriverait au milieu.
    enum Press {
        /// Ce qui se touche sans rien décider : une rangée, une pastille, une croix.
        case light
        /// Un panneau, une carte, une surface large.
        case soft
        /// Le bouton principal d'un écran.
        case medium
        /// Un choix dans une liste : le cran d'un sélecteur, pas un coup.
        case selection
        /// Un geste qui reprend la main : annuler sa dernière note.
        case rigid
        /// Un geste qui écarte quelque chose. La vibration double du système dit
        /// « c'est fait, mais ce n'était pas rien » mieux qu'un coup sec.
        case warning
        /// Les rares éléments dont le retour vient d'ailleurs, et plus juste que celui-ci :
        /// une proposition de QCM, dont c'est la réponse — juste ou fausse — qui parle.
        case none

        func play() {
            switch self {
            case .light: Haptics.light()
            case .soft: Haptics.soft()
            case .medium: Haptics.medium()
            case .selection: Haptics.selection()
            case .rigid: Haptics.rigid()
            case .warning: Haptics.warning()
            case .none: break
            }
        }
    }
}
