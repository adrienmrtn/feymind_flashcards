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
            // Le ScrollView de pagination peut apparaître un peu plus tard dans la hiérarchie.
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
