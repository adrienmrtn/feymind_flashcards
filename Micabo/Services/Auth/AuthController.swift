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
    /// Apple et Google réussissent ou expliquent. Le courriel, lui, a un succès qui n'ouvre
    /// pas encore la session : le lien est parti, il faut l'ouvrir.
    enum AuthMessage: Equatable {
        case error(String)
        case sent(String)
        /// L'adresse ressemble à une autre. On demande avant d'envoyer, parce qu'un lien
        /// parti à `gmial.com` ne revient pas à l'élève : il revient en rebond.
        case suggestion(typed: String, corrected: String)
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
        guard let stored = AuthTokenStore.load() else {
            state = .signedOut
            return
        }

        guard stored.isExpired else {
            session = stored
            state = .signedIn(stored.user)
            return
        }

        // Le jeton d'accès dure une heure : au lancement, il a presque toujours expiré.
        do {
            adopt(try await client.refresh(refreshToken: stored.refreshToken))
        } catch AuthError.sessionExpired {
            forget()
        } catch {
            // Un échec de rafraîchissement n'est pas forcément une déconnexion, c'est
            // peut-être l'avion : on garde la session et on réessaiera.
            session = stored
            state = .signedIn(stored.user)
        }
    }

    /// Le jeton d'accès à jour, rafraîchi au besoin. C'est le seul point d'entrée pour tout
    /// ce qui appelle la base : personne d'autre n'a à savoir qu'un jeton expire.
    func validAccessToken() async -> String? {
        guard let current = session else { return nil }
        guard current.isExpired else { return current.accessToken }

        do {
            let renewed = try await client.refresh(refreshToken: current.refreshToken)
            adopt(renewed)
            return renewed.accessToken
        } catch AuthError.sessionExpired {
            // Un jeton que GoTrue a oublié ne se rattrape pas. Le garder rejouait le même
            // appel à chaque écran, et laissait l'app affirmer une session qui n'ouvre rien.
            forget()
            return nil
        } catch {
            return nil
        }
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

    /// Relit l'adresse, puis envoie le lien. C'est le courriel qui ferme la session.
    ///
    /// Sauf pour `@apple.com` : les relecteurs n'ont pas de boîte là-bas, donc l'appui ouvre
    /// le compte tout de suite plutôt que d'envoyer un lien qui rebondirait.
    ///
    /// Le tri des adresses se fait ici et non dans la vue, pour que l'écran d'accueil, la
    /// feuille des réglages et l'étape du parcours obéissent tous à la même règle.
    func sendMagicLink(to email: String) async {
        guard !isWorking else { return }

        if AppStoreReview.matches(email) {
            await openReviewSession()
            return
        }

        switch EmailAddress.inspect(email) {
        case .malformed:
            message = .error(L10n.t("onboarding.emailMalformed", locale: .resolved()))
        case .undeliverable:
            message = .error(L10n.t("onboarding.emailUndeliverable", locale: .resolved()))
        case .suspicious(let address, let suggestion):
            message = .suggestion(typed: address, corrected: suggestion)
        case .ok(let address):
            await deliverMagicLink(to: address)
        }
    }

    /// Envoie sans redemander. Les deux réponses à « tu voulais dire … ? » passent par ici :
    /// la correction, et le refus de corriger.
    func deliverMagicLink(to address: String) async {
        if AppStoreReview.matches(address) {
            await openReviewSession()
            return
        }
        await perform {
            let pkce = PKCEPair()
            self.pendingVerifier = pkce.verifier
            try await self.client.sendMagicLink(
                email: address,
                redirectTo: AuthRedirect.url,
                challenge: pkce.challenge
            )
            self.message = .sent(address)
        }
    }

    /// Session du compte de relecture. Un refus remonte comme les autres : mieux vaut
    /// une phrase d'erreur qu'une app qui se croit connectée sans pouvoir rien lire.
    private func openReviewSession() async {
        await perform {
            self.adopt(try await self.client.signInWithPassword(
                email: AppStoreReview.email,
                password: AppStoreReview.password
            ))
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

        if let tokenHash = value("token_hash") {
            let type = value("type") ?? "magiclink"
            await perform {
                self.adopt(try await self.client.verify(tokenHash: tokenHash, type: type))
            }
            return
        }

        if let code = value("code"), let verifier = pendingVerifier {
            await perform {
                self.adopt(try await self.client.exchange(code: code, verifier: verifier))
                self.pendingVerifier = nil
            }
        }
    }

    /// Vérificateur du dernier flux PKCE lancé hors de l'app (lien par courriel).
    ///
    /// `OAuthWebFlow` garde le sien en mémoire parce qu'il attend son retour dans la même
    /// fonction. Un lien reçu par courriel, lui, peut être ouvert deux jours plus tard : son
    /// vérificateur doit survivre au lancement suivant.
    private var pendingVerifier: String? {
        get { UserDefaults.standard.string(forKey: Self.verifierKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: Self.verifierKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.verifierKey)
            }
        }
    }

    private static let verifierKey = "micabo.auth.pkceVerifier"

    // MARK: - Sortie

    func signOut() async {
        if let token = session?.accessToken {
            try? await client.signOut(accessToken: token)
        }
        forget()
    }

    /// Efface le compte Auth. Le reste suit par cascade côté serveur.
    func deleteAccount() async {
        guard await validAccessToken() != nil else { return }
        let database = SupabaseDatabase(accessToken: { await self.validAccessToken() })
        do {
            try await database.rpc("delete_own_account")
        } catch {
            message = .error("Le compte n'a pas pu être supprimé.")
            return
        }
        // Pas de `logout` : l'utilisateur vient d'être supprimé, et GoTrue répond alors
        // `user_not_found`. Ça se lisait dans les journaux comme un incident
        // d'authentification, alors que c'était la suppression qui avait réussi.
        forget()
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

    /// Oublie la session, sans rien demander au serveur. C'est le geste commun à la
    /// déconnexion, à la suppression du compte, et à un jeton que GoTrue ne connaît plus.
    private func forget() {
        session = nil
        AuthTokenStore.clear()
        state = .signedOut
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
