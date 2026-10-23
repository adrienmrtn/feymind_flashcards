import Foundation

/// **Le jeton qui fait passer les lignes de l'invité au compte**, gardé jusqu'à ce qu'il serve.
///
/// Le contrat serveur est dans `supabase/migrations/20261023190000_guest_claim.sql`, et
/// Android appelle les mêmes deux fonctions :
/// - `create_guest_claim()` → `uuid`, sous la session **de l'invité** ;
/// - `claim_guest(p_token uuid)` → `{ "courses": n, … }`, sous la session **du compte**.
///
/// Pourquoi un jeton gardé ici, et pas un appel enchaîné : le premier se fait au moment de la
/// connexion, le second à la synchro qui suit, et entre les deux l'app peut être tuée, le
/// réseau tomber, la fonction ne pas encore être déployée. Le jeton survit dans
/// `UserDefaults` jusqu'à ce que la réclamation réussisse ou qu'il expire (24 heures côté
/// serveur) ; chaque passage de synchro la retente d'ici là.
enum GuestClaimStore {
    private static let tokenKey = "micabo.cloud.guestClaim.token"
    private static let guestKey = "micabo.cloud.guestClaim.guest"
    private static let createdKey = "micabo.cloud.guestClaim.createdAt"
    /// L'invité sous lequel cet appareil a commencé à monter des lignes. Posé par
    /// `CloudSync.push` à chaque passage d'invité : c'est ce qui dit qu'il y a quelque chose à
    /// réclamer.
    private static let rowsKey = "micabo.cloud.guestWithRows"
    /// Le compte du dernier passage réussi, tenu par `CloudSync`. Lu ici parce que les
    /// versions d'avant le 23 octobre 2026 ne posaient pas `rowsKey` : un invité qui s'est
    /// connecté avec elles a encore ses lignes au serveur, et c'est ce repère qui le dit.
    private static let lastSyncedUserKey = "micabo.cloud.lastSyncedUser"

    /// Le serveur refuse après 24 heures ; on renonce un peu avant, pour ne pas envoyer un
    /// jeton qui expirerait en route.
    static let lifetime: TimeInterval = 23 * 3600

    static var defaults: UserDefaults = .standard

    struct Claim: Equatable {
        let token: UUID
        let guestID: UUID
        let createdAt: Date

        func isExpired(now: Date = Date()) -> Bool {
            now.timeIntervalSince(createdAt) > GuestClaimStore.lifetime
        }
    }

    static var claim: Claim? {
        guard let token = defaults.string(forKey: tokenKey).flatMap(UUID.init(uuidString:)),
              let guest = defaults.string(forKey: guestKey).flatMap(UUID.init(uuidString:)),
              let created = defaults.object(forKey: createdKey) as? Date
        else { return nil }
        return Claim(token: token, guestID: guest, createdAt: created)
    }

    /// Le jeton encore utilisable pour cet invité, sinon `nil`. Un jeton expiré est oublié au
    /// passage : le suivant en redemandera un, tant que la session de l'invité existe.
    static func validToken(for guestID: UUID, now: Date = Date()) -> UUID? {
        guard let claim, claim.guestID == guestID else { return nil }
        guard !claim.isExpired(now: now) else {
            forgetToken()
            return nil
        }
        return claim.token
    }

    static func save(token: UUID, guestID: UUID, now: Date = Date()) {
        defaults.set(token.uuidString, forKey: tokenKey)
        defaults.set(guestID.uuidString, forKey: guestKey)
        defaults.set(now, forKey: createdKey)
    }

    /// Oublie le jeton, pas l'invité : le passage suivant en redemandera un.
    static func forgetToken() {
        defaults.removeObject(forKey: tokenKey)
        defaults.removeObject(forKey: guestKey)
        defaults.removeObject(forKey: createdKey)
    }

    /// L'invité a des lignes au serveur.
    static func noteRows(of guestID: UUID) {
        defaults.set(guestID.uuidString, forKey: rowsKey)
    }

    /// **L'invité dont les lignes attendent d'être réclamées**, s'il y en a un : celui du jeton
    /// en cours, sinon l'invité de cet appareil s'il a monté quelque chose. Jamais le compte.
    static func pendingGuest(current guestID: UUID?, account: UUID) -> UUID? {
        if let claim, claim.guestID != account { return claim.guestID }
        guard let guestID, guestID != account else { return nil }
        let withRows = defaults.string(forKey: rowsKey).flatMap(UUID.init(uuidString:))
        let lastSynced = defaults.string(forKey: lastSyncedUserKey).flatMap(UUID.init(uuidString:))
        return withRows == guestID || lastSynced == guestID ? guestID : nil
    }

    /// Vrai quand l'invité a sans doute des lignes au serveur : la connexion prend alors un
    /// jeton avant de passer au compte.
    static func guestHasRows(_ guestID: UUID) -> Bool {
        let withRows = defaults.string(forKey: rowsKey).flatMap(UUID.init(uuidString:))
        let lastSynced = defaults.string(forKey: lastSyncedUserKey).flatMap(UUID.init(uuidString:))
        return withRows == guestID || lastSynced == guestID
    }

    /// La réclamation a réussi, ou il n'y a plus rien à réclamer : tout s'oublie.
    static func clear() {
        forgetToken()
        defaults.removeObject(forKey: rowsKey)
    }

    /// Le jeton tel que PostgREST le rend : une chaîne JSON nue (`"5b1c…"`), parfois sans
    /// guillemets selon le client. Les deux se lisent.
    static func parseToken(_ data: Data) -> UUID? {
        if let text = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? String {
            return UUID(uuidString: text)
        }
        let raw = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\" \n\r\t"))
        return UUID(uuidString: raw)
    }
}
