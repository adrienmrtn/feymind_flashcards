import AuthenticationServices
import SwiftUI
import UIKit

/// **Le bouton d'Apple, et seulement le bouton.**
///
/// `ASAuthorizationAppleIDButton` est dessiné par le système, comme ses règles d'interface
/// l'exigent dès qu'on propose la connexion Apple. Il ne construit plus la requête ni ne
/// tient le contrôleur : il appelle `AuthController.startAppleSignIn`, qui garde l'un et
/// l'autre jusqu'au retour. C'est ce qui a mis fin aux `AuthorizationError 1000` immédiats
/// que le bouton SwiftUI rendait quand l'écran se redessinait pendant la feuille d'Apple.
///
/// Le libellé (« Continuer avec Apple ») et sa langue sont ceux du système : une chaîne de
/// moins à traduire, et la seule forme qu'Apple accepte.
struct AppleSignInButton: UIViewRepresentable {
    var cornerRadius: CGFloat
    var action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        // **Noir le jour, blanc la nuit**, comme le demandent les règles d'Apple : un bouton
        // noir sur le graphite de la nuit ne se voyait plus. Le style ne change pas après la
        // création ; l'appelant recrée le bouton quand l'apparence change (`.id`).
        let style: ASAuthorizationAppleIDButton.Style = context.environment.colorScheme == .dark ? .white : .black
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: .continue, authorizationButtonStyle: style)
        button.cornerRadius = cornerRadius
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        // Sans ça, la vue UIKit impose sa hauteur intrinsèque et la pile SwiftUI ne peut plus
        // la poser à cinquante-six points comme les deux autres boutons.
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentHuggingPriority(.defaultLow, for: .vertical)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        uiView.cornerRadius = cornerRadius
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func tapped() {
            action()
        }
    }
}
