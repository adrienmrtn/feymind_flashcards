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
    /// connexion Apple ou Google ouvre le vrai compte à côté. Ses lignes au serveur ne peuvent
    /// pas y monter telles quelles - elles sont à l'invité, et le cloisonnement refuse de les
    /// réécrire sous un autre - : la connexion prend d'abord un jeton avec la session de
    /// l'invité (`adoptAccount`), et la synchro qui suit le présente sous le compte
    /// (`claim_guest`, voir `GuestClaimStore`).
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
    /// première demande.
    ///
    /// `nil` quand aucune identité ne s'ouvre, et l'appel ne part pas (`SupabaseFunctions`) :
    /// **plus jamais sous la clé publique**. Elle porte un budget du jour partagé par tous les
    /// appareils sans identité, et un élève neuf lisait « reviens demain » avant sa première
    /// leçon - puis, la transition finie côté serveur, un refus pur et simple.
    ///
    /// **Un compte dont le jeton ne se rafraîchit pas ne prend pas celui de l'invité.** Ce n'est
    /// presque toujours qu'une panne passagère (l'avion, un réseau lent) : passer sous l'invité
    /// aurait compté la leçon et le quota à un autre que l'élève connecté. On rend `nil`, et
    /// l'appel échoue comme une panne de réseau, qu'on peut retenter. Seul un compte que
    /// GoTrue a oublié (`forget()`) laisse la place à l'invité : on n'est alors plus connecté.
    func functionsAccessToken() async -> String? {
        if session != nil {
            if let token = await validAccessToken() { return token }
            guard session == nil else { return nil }
        }
        return await ensureGuestAccessToken()
    }

    /// Les pauses avant chaque nouvel essai d'ouverture de l'invité.
    static let guestRetryDelays: [Duration] = [.milliseconds(500), .milliseconds(1500)]
    /// Au-delà, on ne relance plus : hors ligne, chaque essai attend déjà le réseau, et
    /// l'élève ne doit pas regarder tourner l'écran pendant trois minutes.
    static let guestRetryBudget: Duration = .seconds(12)

    /// **Le jeton de l'invité, quitte à réessayer de l'ouvrir.** Une création qui a buté au
    /// lancement (un réseau qui se réveille, GoTrue lent une seconde) se retente ici, juste
    /// avant l'appel qui en a besoin, deux fois avec une courte pause.
    private func ensureGuestAccessToken() async -> String? {
        guard AppConfig.isConfigured else { return nil }
        let clock = ContinuousClock()
        let start = clock.now
        if let token = await guestAccessToken() { return token }
        for delay in Self.guestRetryDelays {
            guard !Task.isCancelled, start.duration(to: clock.now) < Self.guestRetryBudget else { return nil }
            try? await Task.sleep(for: delay)
            if let token = await guestAccessToken() { return token }
        }
        return nil
    }

    /// **Qui achète, ouvert avant l'achat** (`PaywallPurchases.buy`). Le compte, sinon
    /// l'invité, ouvert maintenant s'il n'existe pas encore. `nil` quand aucun ne s'ouvre :
    /// l'achat ne part pas, plutôt que sous l'identifiant anonyme de RevenueCat, que le
    /// webhook refuse.
    func ensureBillingIdentity() async -> (userID: UUID?, guestID: UUID?) {
        if let user { return (user.id, guestUserID) }
        if guestUserID == nil {
            _ = await ensureGuestAccessToken()
        }
        return (billingUserID, guestUserID)
    }

    /// **Un 401 d'une fonction** (`SupabaseFunctions.recoverIdentity`) : le jeton du compte,
    /// rafraîchi au besoin, sinon celui de l'invité - ouvert maintenant si sa création avait
    /// échoué. `nil` quand rien ne s'ouvre (hors ligne, connexion anonyme fermée).
    func recoverFunctionsIdentity() async -> String? {
        if session != nil { return await validAccessToken() }
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
        let flow = AppleSignInFlow(requests: [request]) { [weak self] source, result in
            Task { @MainActor in
                guard let self else { return }
                // Seulement si c'est encore lui : un succès tardif (voir `AppleSignInFlow`)
                // peut arriver quand l'élève a déjà relancé une connexion, et lâcher le
                // contrôleur de celle-ci la ferait échouer.
                if self.appleFlow === source { self.appleFlow = nil }
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
                // douter quelqu'un qui est en train de réussir. Si rien ne suit en une
                // douzaine de secondes, le message vient, avec les mêmes mots qu'avant.
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
                await self.adoptAccount(session)
            }
        }
    }

    func signInWithGoogle() async {
        Analytics.track(.signInStarted, ["provider": "google"])
        await perform {
            let result = try await OAuthWebFlow().authorize(provider: "google")
            let session = try await self.client.exchange(code: result.code, verifier: result.verifier)
            await self.adoptAccount(session)
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
            try await self.client.sendMagicLink(
                email: address,
                redirectTo: AuthRedirect.url,
                challenge: pkce.challenge
            )
            // **Gardé seulement une fois le lien parti.** Posé avant l'envoi, le vérificateur
            // d'un renvoi que GoTrue refusait (une minute entre deux liens) écrasait celui du
            // lien réellement reçu : ce lien-là ne pouvait plus ouvrir de session.
            self.rememberVerifier(pkce.verifier)
            self.message = .sent(address)
        }
    }

    /// Session du compte de relecture. Un refus remonte comme les autres : mieux vaut
    /// une phrase d'erreur qu'une app qui se croit connectée sans pouvoir rien lire.
    private func openReviewSession() async {
        await perform {
            let session = try await self.client.signInWithPassword(
                email: AppStoreReview.email,
                password: AppStoreReview.password
            )
            await self.adoptAccount(session)
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

        // **Un lien refusé revient avec son erreur** (`error`, `error_code`,
        // `error_description`) : un lien expiré ou déjà ouvert (`otp_expired`). L'app ne
        // faisait rien, et l'élève restait devant l'écran de connexion sans savoir pourquoi.
        // On le dit, avec la suite : redemander un lien depuis le même écran.
        // Déjà connecté (un vieux lien rouvert), il n'y a rien à dire.
        if value("error") != nil || value("error_code") != nil || value("error_description") != nil {
            guard !isSignedIn else { return }
            Analytics.track(.signInFailed, ["reason": .text(value("error_code") ?? value("error") ?? "lien")])
            message = .error(AuthError.linkExpired.errorDescription ?? "")
            return
        }

        if let refresh = value("refresh_token") {
            await perform {
                let session = try await self.client.refresh(refreshToken: refresh)
                await self.adoptAccount(session)
            }
            return
        }

        if let tokenHash = value("token_hash") {
            let type = value("type") ?? "magiclink"
            await perform {
                let session = try await self.client.verify(tokenHash: tokenHash, type: type)
                await self.adoptAccount(session)
            }
            return
        }

        if let code = value("code") {
            // Un code sans vérificateur : le lien a été demandé sur un autre appareil, ou
            // avant une réinstallation. Il ne peut rien ouvrir ici ; on le dit au lieu de se
            // taire.
            let verifiers = pendingVerifiers
            guard !verifiers.isEmpty else {
                guard !isSignedIn else { return }
                Analytics.track(.signInFailed, ["reason": "lien_sans_verificateur"])
                message = .error(AuthError.linkExpired.errorDescription ?? "")
                return
            }
            await perform {
                let session = try await self.exchange(code: code, verifiers: verifiers)
                await self.adoptAccount(session)
                self.pendingVerifiers = []
            }
        }
    }

    /// **Échange le code avec le bon vérificateur.** Le lien ouvert n'est pas forcément le
    /// dernier demandé : on essaie les vérificateurs gardés, du plus récent au plus ancien,
    /// comme Android. Une panne de réseau s'arrête au premier essai : les suivants buteraient
    /// sur la même, et l'élève pourra rouvrir le lien.
    private func exchange(code: String, verifiers: [String]) async throws -> AuthSession {
        for verifier in verifiers {
            do {
                return try await client.exchange(code: code, verifier: verifier)
            } catch AuthError.network(let detail) {
                throw AuthError.network(detail)
            } catch {
                continue
            }
        }
        throw AuthError.linkExpired
    }

    /// Les vérificateurs des derniers liens envoyés par courriel, du plus récent au plus
    /// ancien.
    ///
    /// `OAuthWebFlow` garde le sien en mémoire parce qu'il attend son retour dans la même
    /// fonction. Un lien reçu par courriel, lui, peut être ouvert deux jours plus tard : son
    /// vérificateur doit survivre au lancement suivant. Et il y en a plusieurs : l'élève qui
    /// redemande un lien peut ouvrir le premier.
    private var pendingVerifiers: [String] {
        get {
            let defaults = UserDefaults.standard
            var verifiers = defaults.stringArray(forKey: Self.verifiersKey) ?? []
            // L'ancienne clé, à un seul vérificateur : un lien demandé avant la mise à jour.
            if let legacy = defaults.string(forKey: Self.legacyVerifierKey), !verifiers.contains(legacy) {
                verifiers.append(legacy)
            }
            return verifiers
        }
        set {
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: Self.legacyVerifierKey)
            if newValue.isEmpty {
                defaults.removeObject(forKey: Self.verifiersKey)
            } else {
                defaults.set(Array(newValue.prefix(Self.keptVerifiers)), forKey: Self.verifiersKey)
            }
        }
    }

    /// Le vérificateur d'un lien qui vient de partir, en tête de la liste.
    private func rememberVerifier(_ verifier: String) {
        pendingVerifiers = [verifier] + pendingVerifiers.filter { $0 != verifier }
    }

    /// Trois liens gardés : c'est déjà plus que ce qu'un élève redemande avant d'en ouvrir un.
    static let keptVerifiers = 3
    private static let verifiersKey = "micabo.auth.pkceVerifiers"
    private static let legacyVerifierKey = "micabo.auth.pkceVerifier"

    // MARK: - Sortie

    func signOut() async {
        if let token = session?.accessToken {
            try? await client.signOut(accessToken: token)
        }
        forget()
    }

    /// Efface le compte Auth. Le reste suit par cascade côté serveur. Rend vrai quand le
    /// compte est bien parti : c'est seulement alors que le téléphone se vide.
    @discardableResult
    func deleteAccount() async -> Bool {
        guard await validAccessToken() != nil else { return false }
        let database = SupabaseDatabase(accessToken: { await self.validAccessToken() })
        do {
            try await database.rpc("delete_own_account")
        } catch {
            message = .error(L10n.t("app.settings.delete.error", locale: .resolved()))
            return false
        }
        // Pas de `logout` : l'utilisateur vient d'être supprimé, et GoTrue répond alors
        // `user_not_found`. Ça se lisait dans les journaux comme un incident
        // d'authentification, alors que c'était la suppression qui avait réussi.
        forget()
        return true
    }

    /// **Un invité neuf, après la sortie d'un compte.** L'ancien invité a déjà cédé ses
    /// lignes au compte (`claim_guest`) ou n'a plus rien à lui : le garder ferait remonter
    /// sous lui ce que le téléphone aura de nouveau, mélangé à ce qu'il avait. Un jeton de
    /// réclamation en attente part avec lui : il désignait l'ancien.
    func startFreshGuest() async {
        dropGuest()
        GuestClaimStore.clear()
        guard AppConfig.isConfigured else { return }
        _ = await guestAccessToken()
    }

    func clearMessage() {
        message = nil
    }

    // MARK: - Rouages

    /// **Passer de l'invité au compte.** Toutes les connexions passent par ici (Apple, Google,
    /// lien par courriel, compte de relecture) ; le rafraîchissement d'une session déjà
    /// ouverte, non.
    ///
    /// Avant d'adopter le compte, on prend le jeton de réclamation **avec la session de
    /// l'invité**, si l'invité a monté des lignes. Huit secondes au plus : la connexion ne doit
    /// pas attendre une réponse lente, et si le jeton manque, la synchro le redemandera
    /// elle-même tant que la session de l'invité est là (`CloudSync.settleGuestClaim`).
    private func adoptAccount(_ session: AuthSession) async {
        if let guestID = guestUserID, guestID != session.user.id, GuestClaimStore.guestHasRows(guestID),
           GuestClaimStore.validToken(for: guestID) == nil {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { _ = await self.createGuestClaim(for: guestID) }
                group.addTask { try? await Task.sleep(for: .seconds(8)) }
                _ = await group.next()
                group.cancelAll()
            }
        }
        adopt(session)
    }

    /// **Demande un jeton de réclamation sous la session de l'invité** et le garde. `nil`
    /// quand l'invité n'a plus de session (GoTrue l'a oublié) ou que le serveur ne répond pas.
    ///
    /// La session de l'invité est rafraîchie au besoin, mais jamais recréée : un invité neuf
    /// n'aurait aucune ligne, et son jeton ne réclamerait rien.
    func createGuestClaim(for guestID: UUID) async -> UUID? {
        guard AppConfig.isConfigured, guestUserID == guestID, guestSession != nil else { return nil }
        let database = SupabaseDatabase(accessToken: { await self.existingGuestAccessToken() })
        guard let data = try? await database.rpcData("create_guest_claim"),
              let token = GuestClaimStore.parseToken(data),
              guestUserID == guestID
        else { return nil }
        GuestClaimStore.save(token: token, guestID: guestID)
        return token
    }

    /// Vrai tant que cet appareil tient la session de cet invité : sans elle, plus personne ne
    /// peut signer de jeton pour ses lignes.
    func holdsGuestSession(_ guestID: UUID) -> Bool {
        guestUserID == guestID && guestSession != nil
    }

    /// Le jeton de l'invité existant, rafraîchi au besoin. Contrairement à `guestAccessToken`,
    /// n'ouvre jamais de nouvel invité.
    private func existingGuestAccessToken() async -> String? {
        guard let guest = guestSession else { return nil }
        guard guest.isExpired else { return guest.accessToken }
        do {
            let renewed = try await client.refresh(refreshToken: guest.refreshToken)
            keepGuest(renewed)
            return renewed.accessToken
        } catch AuthError.sessionExpired {
            // GoTrue a oublié l'invité : plus personne ne signera de jeton pour ses lignes.
            // L'oublier ici laisse la synchro renoncer à la réclamation au lieu de la retenter
            // pour toujours (`CloudSync.settleGuestClaim`).
            dropGuest()
            return nil
        } catch {
            return nil
        }
    }

    private func adopt(_ session: AuthSession) {
        deferredAppleError?.cancel()
        deferredAppleError = nil
        self.session = session
        AuthTokenStore.save(session)
        state = .signedIn(session.user)
        message = nil
    }

    /// Montre l'erreur immédiate d'Apple un peu après la fin de l'attente d'un succès tardif
    /// (`AppleSignInFlow.lateSuccessWindow`), sauf si une connexion l'a rendue sans objet
    /// entre-temps.
    private func deferAppleError(_ description: String) {
        deferredAppleError?.cancel()
        deferredAppleError = Task { [weak self] in
            try? await Task.sleep(for: AppleSignInFlow.lateSuccessWindow)
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
    /// **Combien de temps un succès reste attendu après l'erreur inconnue (1000).** Les
    /// mesures du 23 octobre 2026 : la vraie réponse suit le 1000 jusqu'à sept secondes plus
    /// tard. Une seconde et demie n'en laissait passer qu'une partie ; douze les couvrent.
    static let lateSuccessWindow: Duration = .seconds(12)
    /// Le temps avant de rendre l'erreur inconnue à l'appelant, qui la garde pour lui
    /// (`AuthController.deferAppleError`) : elle ne s'affiche que si aucun succès ne suit.
    static let unknownErrorDelay: Duration = .milliseconds(1500)

    private let controller: ASAuthorizationController
    private let completion: (AppleSignInFlow, Result<ASAuthorization, Error>) -> Void
    /// Vrai une fois la réponse définitive rendue : un succès, une autre erreur, ou la fin de
    /// l'attente d'un succès tardif.
    private var finished = false
    /// Vrai quand l'erreur inconnue a été rendue : un succès peut encore la remplacer.
    private var deliveredUnknownFailure = false
    /// L'erreur inconnue mise de côté, le temps de voir si un succès la suit.
    private var pendingFailure: Task<Void, Never>?
    /// **Le flux se tient en vie** pendant `lateSuccessWindow` après le 1000 : c'est lui qui
    /// garde le contrôleur d'Apple, et un contrôleur lâché ne rend jamais le succès qui suit.
    private var keepAlive: Task<Void, Never>?

    init(requests: [ASAuthorizationRequest], completion: @escaping (AppleSignInFlow, Result<ASAuthorization, Error>) -> Void) {
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
    /// donc toujours tout de suite. Une erreur inconnue est rendue au bout d'une seconde et
    /// demie - l'appelant la tait - mais **le flux reste ouvert douze secondes** : un succès
    /// qui arrive après passe encore, et c'est lui qui ouvre la session. Jusqu'au 2 novembre
    /// 2026, le flux se refermait avec l'erreur, et un succès arrivé à la deuxième seconde
    /// était perdu. Les autres erreurs (annulation comprise) passent sans attendre.
    private func finish(_ result: Result<ASAuthorization, Error>) {
        guard !finished else { return }
        switch result {
        case .success:
            pendingFailure?.cancel()
            pendingFailure = nil
            close()
            completion(self, result)

        case .failure(let error) where (error as? ASAuthorizationError)?.code == .unknown:
            guard pendingFailure == nil, !deliveredUnknownFailure else { return }
            pendingFailure = Task { @MainActor [weak self] in
                try? await Task.sleep(for: Self.unknownErrorDelay)
                guard let self, !Task.isCancelled, !self.finished else { return }
                self.deliveredUnknownFailure = true
                self.completion(self, result)
            }
            // Une référence forte, à dessein : personne d'autre ne garde le flux une fois
            // l'erreur rendue, et c'est lui qui tient le contrôleur d'Apple.
            keepAlive = Task { @MainActor in
                try? await Task.sleep(for: Self.lateSuccessWindow)
                self.close()
            }

        case .failure:
            // Une autre erreur après un 1000 déjà rendu n'ajoute rien : l'appelant attend
            // déjà de voir si un succès suit, et affichera le 1000 sinon.
            guard !deliveredUnknownFailure else {
                close()
                return
            }
            pendingFailure?.cancel()
            pendingFailure = nil
            close()
            completion(self, result)
        }
    }

    /// Plus aucune réponse n'est attendue : le flux peut partir.
    private func close() {
        finished = true
        keepAlive?.cancel()
        keepAlive = nil
    }
}
