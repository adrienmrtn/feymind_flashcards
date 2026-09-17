import Foundation

/// Une ligne d'`app_events`, telle qu'elle voyage et telle qu'elle attend sur le disque.
///
/// Les noms sont ceux des colonnes, en toutes lettres : ce fichier est le seul endroit où
/// le schéma de la table est écrit côté app, et une ligne refusée par Postgres se lit mieux
/// quand le nom qu'on a envoyé est celui qu'on voit ici.
struct AnalyticsRow: Codable, Sendable {
    var deviceID: UUID
    var sessionID: UUID
    var name: String
    var props: [String: AnalyticsValue]
    var country: String?
    var schoolCountry: String?
    var locale: String?
    var platform: String
    var appVersion: String?
    var build: String
    var isPro: Bool
    var occurredAt: Date

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
        case sessionID = "session_id"
        case name
        case props
        case country
        case schoolCountry = "school_country"
        case locale
        case platform
        case appVersion = "app_version"
        case build
        case isPro = "is_pro"
        case occurredAt = "occurred_at"
    }
}

/// **Ce que l'app dit d'elle-même sur chaque ligne.**
///
/// Calculé une fois par lancement et gardé : `Locale.current` et le dictionnaire du paquet
/// sont bon marché, mais pas assez pour être relus à chaque appui sur un bouton.
struct AnalyticsContext: Sendable {
    var deviceID: UUID
    var sessionID: UUID
    var country: String?
    var locale: String?
    var appVersion: String?
    var build: String

    /// La région de l'appareil en deux lettres majuscules, ou rien. `Locale` sait rendre
    /// des régions à trois chiffres (019 pour l'Amérique du Nord) que la contrainte de la
    /// table refuse : mieux vaut une colonne vide qu'un lot rejeté.
    static func deviceRegion() -> String? {
        guard let code = Locale.current.region?.identifier.uppercased(),
              code.count == 2,
              code.allSatisfy({ $0.isLetter }) else { return nil }
        return code
    }

    static func current(deviceID: UUID, sessionID: UUID) -> AnalyticsContext {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        let version = [short, build].compactMap { $0 }.joined(separator: "+")

        #if DEBUG
        let flavour = "debug"
        #else
        let flavour = "release"
        #endif

        return AnalyticsContext(
            deviceID: deviceID,
            sessionID: sessionID,
            country: deviceRegion(),
            locale: Locale.current.identifier,
            appVersion: version.nilIfBlank,
            build: flavour
        )
    }
}
