import SwiftUI
import UIKit

/// Active ou coupe le défilement horizontal du `TabView` en style page,
/// pour éviter de changer d'onglet pendant qu'un écran de détail est ouvert.
struct TabPagingScrollBridge: UIViewRepresentable {
    var isEnabled: Bool

    func makeUIView(context: Context) -> BridgeView {
        let view = BridgeView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: BridgeView, context: Context) {
        uiView.isPagingEnabled = isEnabled
        uiView.applyPagingEnabled()
    }

    final class BridgeView: UIView {
        var isPagingEnabled = true

        override func didMoveToWindow() {
            super.didMoveToWindow()
            applyPagingEnabled()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            applyPagingEnabled()
        }

        func applyPagingEnabled() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for scrollView in Self.pagingScrollViews(from: self) {
                    if scrollView.isScrollEnabled != self.isPagingEnabled {
                        scrollView.isScrollEnabled = self.isPagingEnabled
                    }
                }
            }
        }

        private static func pagingScrollViews(from view: UIView) -> [UIScrollView] {
            var root: UIView = view
            while let superview = root.superview {
                root = superview
            }

            var result: [UIScrollView] = []
            collectPagingScrollViews(in: root, into: &result)
            return result
        }

        private static func collectPagingScrollViews(in view: UIView, into result: inout [UIScrollView]) {
            if let scrollView = view as? UIScrollView, scrollView.isPagingEnabled {
                result.append(scrollView)
            }
            for child in view.subviews {
                collectPagingScrollViews(in: child, into: &result)
            }
        }
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
