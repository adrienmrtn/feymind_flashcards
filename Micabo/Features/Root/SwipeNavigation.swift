import SwiftUI
import UIKit

// MARK: - Balayage entre les onglets

/// Fait passer d'un onglet à l'autre au balayage horizontal, sans toucher à la barre
/// d'onglets du système. Le geste est simultané : les listes continuent de défiler,
/// et un mouvement franchement vertical ne change jamais de page.
private struct SwipeBetweenTabs: ViewModifier {
    @Environment(TabRouter.self) private var router: TabRouter?

    /// Course horizontale minimale pour valider un changement d'onglet.
    private let threshold: CGFloat = 70

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded { value in
                    guard let router else { return }
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > threshold, abs(horizontal) > abs(vertical) * 2 else { return }
                    move(router, by: horizontal < 0 ? 1 : -1)
                }
        )
    }

    private func move(_ router: TabRouter, by offset: Int) {
        let tabs = RootTab.allCases
        guard let index = tabs.firstIndex(of: router.selection) else { return }
        let target = index + offset
        guard tabs.indices.contains(target) else { return }
        Haptics.selection()
        router.selection = tabs[target]
    }
}

extension View {
    /// À poser sur chaque page racine, à l'intérieur de son `NavigationStack` :
    /// le balayage cesse ainsi dès qu'un écran de détail est ouvert.
    func swipeBetweenTabs() -> some View {
        modifier(SwipeBetweenTabs())
    }
}

// MARK: - Balayage de retour

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
