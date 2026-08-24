import SwiftUI
import UIKit

/// Le seul geste de balayage qui reste dans l'app : **le retour en arrière du système.**
///
/// Le défilement horizontal entre onglets est parti, et le bricolage qui allait le couper
/// dans la hiérarchie UIKit avec lui. Celui-ci n'a rien à voir : c'est le geste que tout
/// iPhone fait sur un écran poussé, et le retirer ne fluidifie rien — ça oblige à viser un
/// bouton là où le pouce a l'habitude de partir du bord.

/// Délégué unique du geste de retour. Il vit aussi longtemps que l'app : confier ce rôle
/// à un objet lié à un écran laisserait le geste sans délégué une fois l'écran dépilé,
/// et le geste se déclencherait alors sur la racine, ce qui fige la navigation.
private final class PopGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = PopGestureDelegate()

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let navigation = Self.navigationController(of: gestureRecognizer) else { return false }
        return navigation.viewControllers.count > 1
    }

    private static func navigationController(of recognizer: UIGestureRecognizer) -> UINavigationController? {
        var responder = recognizer.view?.next
        while let current = responder {
            if let navigation = current as? UINavigationController { return navigation }
            responder = current.next
        }
        return nil
    }
}

/// Rend le geste de retour du système actif même quand la barre de navigation est masquée :
/// SwiftUI le coupe dès qu'on cache le bouton de retour.
private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = Controller()
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? Controller)?.enablePopGesture()
    }

    final class Controller: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enablePopGesture()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enablePopGesture()
        }

        func enablePopGesture() {
            guard let recognizer = navigationController?.interactivePopGestureRecognizer else { return }
            recognizer.delegate = PopGestureDelegate.shared
            recognizer.isEnabled = true
        }
    }
}

extension View {
    /// À appliquer sur un écran poussé qui masque sa barre de navigation.
    func enablesSwipeBack() -> some View {
        background {
            InteractivePopGestureEnabler()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }
}
