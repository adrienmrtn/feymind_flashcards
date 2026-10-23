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

    /// **Le compte invisible de qui a passé la connexion.**
    ///
    /// Les cours restent sur le téléphone et n'en ont pas besoin. Les fonctions, si : sans
    /// jeton d'utilisateur, elles n'acceptent la clé publique que jusqu'à la fin de la
    /// transition (`ANON_GRACE_UNTIL`, côté serveur), et un élève sans compte ne pourrait plus
    /// générer de cours ni parler à Mika. Un compte anonyme porte leur quota, et
    /// l'identifiant RevenueCat de qui s'abonne sans compte.
    ///
    /// **Ce n'est pas un compte au sens de l'app** : `isSignedIn` reste faux, les réglages
    /// proposent toujours de se connecter. Mais ses leçons se synchronisent sous lui depuis le
    /// 23 octobre 2026 (`CloudSync.syncUserID`) : une réinstallation ne les perd plus. Une
    /// connexion Apple ou Google ouvre le vrai compte à côté ; tout ce qui est local y monte à
    /// la première synchro, le repère repartant de zéro pour ce nouveau compte.
    private(set) var guestUserID: UUID?
    @ObservationIgnored private var guestSession: AuthSession?
    @ObservationIgnored private var guestCreation: Task<AuthSession?, Never>?
    /// Les nonces des requêtes Apple en vol. Ici et pas dans le bouton : le contrôleur vit
    /// autant que l'app, et aucun retour d'Apple ne peut plus renouveler celui d'un autre.
    /// Hors observation : émettre un nonce ne change rien à ce que l'écran montre.
    @ObservationIgnored private var appleNonces = AppleNonceLedger()
    /// **Le contrôleur d'autorisation Apple en vol, tenu ici.** Voir `startAppleSignIn`.
    @ObservationIgnored private var appleFlow: AppleSignInFlow?
    /// L'erreur immédiate d'Apple, mise en attente : affichée seulement si rien ne suit.
    @ObservationIgnored private var deferredAppleError: Task<Void, Never>?

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

    /// L'identifiant sous lequel on achète : le compte, sinon le compte invité. C'est lui
    /// que RevenueCat reçoit, pour que le webhook sache à qui ouvrir Pro.
    var billingUserID: UUID? {
        user?.id ?? guestUserID
    }

    // MARK: - Reprise

    /// À appeler au lancement. Relit la session du trousseau et la rafraîchit si son jeton a
    /// expiré.
    func restore() async {
        guestSession = AuthTokenStore.load(account: AuthTokenStore.guestAccount)
        guestUserID = guestSession?.user.id

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

    // MARK: - Sans compte

    /// Le jeton des fonctions : celui du compte, sinon celui du compte invité, ouvert à la
    /// première demande. `nil` quand ni l'un ni l'autre n'est possible — hors ligne, ou
    /// connexion anonyme fermée côté Supabase : l'appel part alors sous la clé publique.
    func functionsAccessToken() async -> String? {
        if session != nil, let token = await validAccessToken() {
            return token
        }
        return await guestAccessToken()
    }

    /// **« Passer ».** Ouvre le compte invité tout de suite, plutôt qu'au premier appel : il
    /// faut qu'il existe avant un achat, pour que l'abonnement ait un propriétaire.
    func continueWithoutAccount() async {
        guard session == nil else { return }
        _ = await guestAccessToken()
    }

    private func guestAccessToken() async -> String? {
        guard AppConfig.isConfigured else { return nil }

        if let guest = guestSession {
            guard guest.isExpired else { return guest.accessToken }
            do {
                let renewed = try await client.refresh(refreshToken: guest.refreshToken)
                keepGuest(renewed)
                return renewed.accessToken
            } catch AuthError.sessionExpired {
                // Le compte invité a été oublié par GoTrue : on en rouvre un. Rien ne s'y
                // perd, les cours sont sur le téléphone.
                dropGuest()
            } catch {
                return nil
            }
        }

        // Deux appels simultanés ne doivent pas ouvrir deux comptes.
        if let pending = guestCreation {
            return await pending.value?.accessToken
        }
        let client = self.client
        let creation = Task { () -> AuthSession? in
            do {
                return try await client.signInAnonymously()
            } catch {
                Analytics.track(.signInFailed, ["reason": "invite"])
                return nil
            }
        }
        guestCreation = creation
        let created = await creation.value
        guestCreation = nil
        guard let created else { return nil }
        keepGuest(created)
        return created.accessToken
    }

    private func keepGuest(_ guest: AuthSession) {
        guestSession = guest
        AuthTokenStore.save(guest, account: AuthTokenStore.guestAccount)
        if guestUserID != guest.user.id { guestUserID = guest.user.id }
    }

    private func dropGuest() {
        guestSession = nil
        guestUserID = nil
        AuthTokenStore.clear(account: AuthTokenStore.guestAccount)
    }

    // MARK: - Fournisseurs

    /// Remplit la requête que `SignInWithAppleButton` construit lui-même. Chaque requête
    /// reçoit son propre nonce, y compris quand un seul geste en fait partir deux.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        request.nonce = appleNonces.issue()
    }

    /// **Lance la connexion Apple**, et garde son contrôleur jusqu'au retour.
    ///
    /// Jusqu'au 23 octobre 2026, c'était `SignInWithAppleButton` de SwiftUI qui tenait le
    /// contrôleur d'autorisation. Le bouton était lié à `isWorking` par `.disabled` et
    /// `.opacity` : quand l'état changeait pendant que la feuille d'Apple se présentait, SwiftUI
    /// redessinait le bouton et son contrôleur disparaissait sous la feuille. Apple rendait
    /// alors `AuthorizationError 1000` tout de suite, puis la vraie réponse arrivait sur le
    /// contrôleur suivant : 135 appareils en quatorze jours, 2,4 retours par appareil, 92 %
    /// connectés sept secondes plus tard. Le contrôleur vit maintenant ici, aussi longtemps que
    /// la requête, et rien de ce que l'écran redessine ne peut le lâcher.
    ///
    /// Le bouton reste celui d'Apple (`ASAuthorizationAppleIDButton`, dans `AppleSignInButton`),
    /// comme ses règles l'exigent ; il ne fait plus que nous appeler.
    func startAppleSignIn() {
        guard !isWorking, appleFlow == nil else { return }
        deferredAppleError?.cancel()
        deferredAppleError = nil

        let request = ASAuthorizationAppleIDProvider().createRequest()
        prepareAppleRequest(request)
        let flow = AppleSignInFlow(requests: [request]) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.appleFlow = nil
                await self.signInWithApple(result: result)
            }
        }
        appleFlow = flow
        flow.start()
    }

    /// Ouvre la session depuis ce qu'Apple vient de rendre.
    ///
    /// Le nonce ne vient pas de la vue : il se retrouve par l'empreinte que porte le jeton.
    /// Un retour d'Apple, erreur comprise, ne peut donc pas fausser celui du suivant.
    func signInWithApple(result: Result<ASAuthorization, Error>) async {
        Analytics.track(.signInStarted, ["provider": "apple"])
        await perform {
            switch result {
            case .failure(let error):
                if (error as? ASAuthorizationError)?.code == .canceled {
                    throw AuthError.cancelled
                }
                // Le code, et celui de l'erreur en dessous (`AKAuthenticationError`) : c'est
                // lui qui dit si c'est une annulation du système, un compte iCloud absent ou
                // un contrôleur perdu. Le message traduit ne dit rien de tout ça.
                let nsError = error as NSError
                let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
                Analytics.track(.appleSignInError, [
                    "stage": "autorisation",
                    "domain": .text(nsError.domain),
                    "code": .number(Double(nsError.code)),
                    "underlying_domain": .text(underlying?.domain ?? ""),
                    "underlying_code": .number(Double(underlying?.code ?? 0)),
                ])
                // **Le 1000 ne s'affiche pas tout de suite.** Neuf fois sur dix, la connexion
                // suit dans les secondes ; montrer une erreur à ce moment-là, c'est faire
                // douter quelqu'un qui est en train de réussir. Si rien ne suit en dix
                // secondes, le message vient, avec les mêmes mots qu'avant.
                if nsError.code == ASAuthorizationError.unknown.rawValue {
                    self.deferAppleError(error.localizedDescription)
                    throw AuthError.transient
                }
                throw AuthError.server(error.localizedDescription)

            case .success(let authorization):
                guard let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                    Analytics.track(.appleSignInError, ["stage": "identifiant"])
                    throw AuthError.invalidResponse
                }
                let credential: AppleCredential
                do {
                    credential = try AppleCredential(appleCredential)
                } catch {
                    Analytics.track(.appleSignInError, ["stage": "jeton"])
                    throw error
                }
                // Un jeton sans nonce part sans nonce : Supabase n'accepte que les deux
                // présents ou les deux absents. Un nonce que ce registre n'a pas émis ne
                // passerait pas, et le dire ici évite un aller-retour voué au refus.
                let tokenNonce = AppleIdentityToken.nonce(in: credential.idToken)
                let nonce = tokenNonce.flatMap { self.appleNonces.redeem(hashed: $0) }
                if tokenNonce != nil, nonce == nil {
                    Analytics.track(.appleSignInError, ["stage": "nonce"])
                    throw AuthError.invalidResponse
                }
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
        Analytics.track(.signInStarted, ["provider": "google"])
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
            Analytics.track(.signInStarted, ["provider": "lien"])
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
            message = .error(L10n.t("app.settings.delete.error", locale: .resolved()))
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
        deferredAppleError?.cancel()
        deferredAppleError = nil
        self.session = session
        AuthTokenStore.save(session)
        state = .signedIn(session.user)
        message = nil
    }

    /// Montre l'erreur immédiate d'Apple dans dix secondes, sauf si une connexion l'a rendue
    /// sans objet entre-temps.
    private func deferAppleError(_ description: String) {
        deferredAppleError?.cancel()
        deferredAppleError = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, !self.isSignedIn, !self.isWorking else { return }
            self.message = .error(description)
        }
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
            // Annuler n'est pas échouer, ici non plus : le compter ferait passer chaque
            // retour en arrière pour une panne de connexion. L'erreur immédiate d'Apple non
            // plus : elle a sa propre ligne (`apple_sign_in_error`), et presque toujours une
            // connexion qui suit.
            if case .cancelled = error {} else if case .transient = error {} else {
                Analytics.track(.signInFailed, ["reason": "refus"])
            }
            if let description = error.errorDescription {
                message = .error(description)
            }
        } catch {
            Analytics.track(.signInFailed, ["reason": "panne"])
            message = .error(error.localizedDescription)
        }
    }
}

// L'objet est posé dans l'environnement par `MicaboApp`, comme `TabRouter` et
// `OnboardingModel` : c'est le mécanisme d'observation d'iOS 17, et il évite d'inventer une
// clé d'environnement pour un objet qui est déjà observable.

// MARK: - Le contrôleur Apple, tenu le temps de la requête

/// **Une requête Apple, du `performRequests` au retour**, tenue par `AuthController` et par
/// rien d'autre. Le délégué et le fournisseur de fenêtre sont le même objet, et il se garde
/// lui-même en vie tant qu'Apple n'a pas répondu : c'est précisément ce que le bouton SwiftUI
/// ne garantissait pas.
@MainActor
final class AppleSignInFlow: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let controller: ASAuthorizationController
    private let completion: (Result<ASAuthorization, Error>) -> Void
    private var finished = false
    /// L'erreur inconnue mise de côté, le temps de voir si un succès la suit.
    private var pendingFailure: Task<Void, Never>?

    init(requests: [ASAuthorizationRequest], completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        controller = ASAuthorizationController(authorizationRequests: requests)
        self.completion = completion
        super.init()
        controller.delegate = self
        controller.presentationContextProvider = self
    }

    func start() {
        controller.performRequests()
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in self.finish(.success(authorization)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in self.finish(.failure(error)) }
    }

    /// La fenêtre clé, celle qui porte l'écran de connexion. Sans elle, Apple présente sa
    /// feuille sur une fenêtre quelconque, ou pas du tout.
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let windows = scenes.flatMap(\.windows)
            return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
        }
    }

    /// Une seule réponse par requête : Apple a parfois rendu deux retours pour un appui, et
    /// c'est le second qui comptait.
    ///
    /// Le premier retour gagnait pourtant : une erreur inconnue (1000) arrivée juste avant le
    /// succès faisait perdre le succès, puis s'affichait dix secondes plus tard. Un succès passe
    /// donc toujours tout de suite ; une erreur inconnue attend une seconde et demie qu'un
    /// succès la remplace. Les autres erreurs (annulation comprise) passent sans attendre.
    private func finish(_ result: Result<ASAuthorization, Error>) {
        guard !finished else { return }
        if case .failure(let error) = result,
           (error as? ASAuthorizationError)?.code == .unknown,
           pendingFailure == nil {
            pendingFailure = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                guard let self, !Task.isCancelled, !self.finished else { return }
                self.finished = true
                self.completion(result)
            }
            return
        }
        pendingFailure?.cancel()
        pendingFailure = nil
        finished = true
        completion(result)
    }
}
