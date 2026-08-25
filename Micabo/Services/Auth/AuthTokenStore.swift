import Foundation
import Security

/// Où vit la session entre deux lancements.
///
/// **Le trousseau, et pas `UserDefaults`.** Un jeton de rafraîchissement donne accès au compte
/// sans mot de passe : dans les réglages, il se lit en clair dans une sauvegarde iTunes ou
/// dans un fichier de conteneur. Le trousseau le chiffre et le refuse tant que le téléphone
/// n'a pas été déverrouillé une fois depuis son démarrage, ce qui est exactement la garantie
/// qu'on veut ici — l'app doit pouvoir rafraîchir en tâche de fond, mais rien ne doit être
/// lisible sur un appareil éteint qu'on emporte.
///
/// `ThisDeviceOnly` ferme la dernière porte : la session ne part pas dans la sauvegarde
/// iCloud, donc restaurer un vieux backup sur un autre téléphone ne connecte personne.
enum AuthTokenStore {
    private static let service = "com.micabo.app.auth"
    private static let account = "session"

    static func load() -> AuthSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    static func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Mettre à jour d'abord : ajouter par-dessus une entrée existante échoue avec
        // `errSecDuplicateItem`, et supprimer puis ajouter laisse une fenêtre sans session.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecItemNotFound else { return }

        SecItemAdd(query.merging(attributes) { current, _ in current } as CFDictionary, nil)
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
