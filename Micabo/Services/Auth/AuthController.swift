import AuthenticationServices
import Observation
import SwiftUI

/// L'état du compte, pour toute l'app.
///
/// Un seul objet le porte, et il est posé dans l'environnement : deux écrans qui décideraient
/// chacun s'il y a quelqu'un de connecté finiraient par ne pas être d'accord.
@Observable
@MainActor
final class AuthController {
    enum State: Equatable {
        /// Au lancement, le temps de relire le trousseau. Cet état existe pour ne pas montrer
        /// l'écran de connexion pendant un dixième de seconde à quelqu'un déjà connecté.
        case restoring
        case signedOut
        case signedIn(AuthUser)
    }

    private(set) var state: State = .restoring
    /// Vrai pendant une opération : l'écran grise ses boutons plutôt que d'en accepter deux.
    private(set) var isWorking = false
    private(set) var message: AuthMessage?

    /// Ce que l'écran de connexion a à dire.
    ///
    /// Il n'y a plus qu'un cas, et c'est le signe que le mot de passe est bien parti : les
    /// trois autres annonçaient qu'un courriel venait d'être envoyé — confirmation, lien de
    /// connexion, réinitialisation. Apple et Google ne renvoient rien à lire, ils
    /// réussissent ou ils expliquent pourquoi.
    enum AuthMessage: Equatable {
        case error(String)
    }

    private let client: SupabaseAuthClient
    private var session: AuthSession?

    init(client: SupabaseAuthClient = .shared) {
        self.client = client
    }

    var user: AuthUser? {
        if case .signedIn(let user) = state { return user }
        return nil
    }

    var isSignedIn: Bool {
        user != nil
    }

    // MARK: - Reprise

    /// À appeler au lancement. Relit la session du trousseau et la rafraîchit si son jeton a
    /// expiré.
    func restore() async {
        if let stored = AuthTokenStore.load() {
            if stored.isExpired {
                // Le jeton d'accès dure une heure : au lancement, il a presque toujours
                // expiré. Un échec de rafraîchissement n'est pas forcément une déconnexion,
                // c'est peut-être l'avion : on garde la session et on réessaiera.
                if let renewed = try? await client.refresh(refreshToken: stored.refreshToken) {
                    adopt(renewed)
                } else {
                    session = stored
                    state = .signedIn(stored.user)
                }
            } else {
                session = stored
                state = .signedIn(stored.user)
            }
        } else {
            state = .signedOut
        }
    }

    /// Le jeton d'accès à jour, rafraîchi au besoin. C'est le seul point d'entrée pour tout
    /// ce qui appelle la base : personne d'autre n'a à savoir qu'un jeton expire.
    func validAccessToken() async -> String? {
        guard let current = session else { return nil }
        guard current.isExpired else { return current.accessToken }

        guard let renewed = try? await client.refresh(refreshToken: current.refreshToken) else {
            return nil
        }
        adopt(renewed)
        return renewed.accessToken
    }

    // MARK: - Fournisseurs

    /// Ouvre la session depuis ce que le bouton d'Apple vient de rendre.
    ///
    /// Le résultat arrive de la vue parce que `SignInWithAppleButton` construit sa requête
    /// lui-même : c'est la seule façon de l'utiliser, et ses règles d'interface imposent ce
    /// bouton-là dès qu'on propose la connexion Apple.
    func signInWithApple(result: Result<ASAuthorization, Error>, nonce: String) async {
        await perform {
            switch result {
            case .failure(let error):
                throw (error as? ASAuthorizationError)?.code == .canceled
                    ? AuthError.cancelled
                    : AuthError.server(error.localizedDescription)

            case .success(let authorization):
                guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    throw AuthError.invalidResponse
                }
                let credential = try AppleCredential(appleCredential)
                var session = try await self.client.signIn(
                    idToken: credential.idToken,
                    provider: "apple",
                    nonce: nonce
                )
                // Le nom n'est donné qu'une fois par Apple : on le recopie sur place, sinon
                // le profil restera anonyme pour toujours.
                if session.user.displayName?.nilIfBlank == nil, let name = credential.fullName {
                    session.user.displayName = name
                }
                self.adopt(session)
            }
        }
    }

    func signInWithGoogle() async {
        await perform {
            let result = try await OAuthWebFlow().authorize(provider: "google")
            self.adopt(try await self.client.exchange(code: result.code, verifier: result.verifier))
        }
    }

    /// Le retour d'un lien reçu par courriel, ouvert depuis l'app.
    ///
    /// Un lien de confirmation ou de connexion revient sur le schéma de Micabo avec un code
    /// PKCE ou une paire de jetons. Les deux formes existent selon le réglage du projet, donc
    /// les deux sont lues.
    func handle(callback url: URL) async {
        guard url.scheme?.lowercased() == AuthRedirect.scheme else { return }

        // Les jetons arrivent parfois dans le fragment (`#access_token=…`), qui n'est pas une
        // requête : on le relit comme telle.
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let fragment = url.fragment.map { "?" + $0 }.flatMap { URLComponents(string: $0) }
        let items = (query?.queryItems ?? []) + (fragment?.queryItems ?? [])

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value
        }

        if let refresh = value("refresh_token") {
            await perform {
                self.adopt(try await self.client.refresh(refreshToken: refresh))
            }
            return
        }

        if let code = value("code"), let verifier = pendingVerifier {
            await perform {
                self.adopt(try await self.client.exchange(code: code, verifier: verifier))
            }
        }
    }

    /// Vérificateur du dernier flux PKCE lancé hors de l'app (lien par courriel).
    ///
    /// `OAuthWebFlow` garde le sien en mémoire parce qu'il attend son retour dans la même
    /// fonction. Un lien reçu par courriel, lui, peut être ouvert deux jours plus tard : son
    /// vérificateur doit survivre au lancement suivant.
    private var pendingVerifier: String? {
        get { UserDefaults.standard.string(forKey: "micabo.auth.pkceVerifier") }
        set { UserDefaults.standard.set(newValue, forKey: "micabo.auth.pkceVerifier") }
    }

    // MARK: - Sortie

    func signOut() async {
        if let token = session?.accessToken {
            try? await client.signOut(accessToken: token)
        }
        session = nil
        AuthTokenStore.clear()
        state = .signedOut
        message = nil
    }

    func clearMessage() {
        message = nil
    }

    // MARK: - Rouages

    private func adopt(_ session: AuthSession) {
        self.session = session
        AuthTokenStore.save(session)
        state = .signedIn(session.user)
        message = nil
    }

    /// Enveloppe commune : un seul travail à la fois, et une panne se raconte au lieu de
    /// disparaître. `AuthError.cancelled` ne dit rien, parce qu'annuler n'est pas échouer.
    private func perform(_ work: () async throws -> Void) async {
        guard !isWorking else { return }
        isWorking = true
        message = nil
        defer { isWorking = false }

        do {
            try await work()
        } catch let error as AuthError {
            if let description = error.errorDescription {
                message = .error(description)
            }
        } catch {
            message = .error(error.localizedDescription)
        }
    }
}

// L'objet est posé dans l'environnement par `MicaboApp`, comme `TabRouter` et
// `OnboardingModel` : c'est le mécanisme d'observation d'iOS 17, et il évite d'inventer une
// clé d'environnement pour un objet qui est déjà observable.
