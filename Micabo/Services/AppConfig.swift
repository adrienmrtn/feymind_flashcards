import Foundation

/// Configuration du backend IA. Les valeurs par défaut ciblent le projet Supabase de Micabo
/// et restent modifiables depuis l'écran Profil sans recompiler.
enum AppConfig {
    enum Key {
        static let supabaseURL = "micabo.supabaseURL"
        static let supabaseAnonKey = "micabo.supabaseAnonKey"
        static let aiModel = "micabo.aiModel"
    }

    static let defaultSupabaseURL = "https://khuzodsrznanzhwlbjbx.supabase.co"
    static let defaultSupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtodXpvZHNyem5hbnpod2xiamJ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU5NDg1MzIsImV4cCI6MjEwMTUyNDUzMn0.-PBadJI6rdYgoHisEfP54CN126IiT9DNIXR4J-vNYLw"
    static let defaultModel = "google/gemini-flash-1.5"

    static var supabaseURL: String {
        get { stored(Key.supabaseURL) ?? defaultSupabaseURL }
        set { store(newValue, for: Key.supabaseURL) }
    }

    static var supabaseAnonKey: String {
        get { stored(Key.supabaseAnonKey) ?? defaultSupabaseAnonKey }
        set { store(newValue, for: Key.supabaseAnonKey) }
    }

    static var aiModel: String {
        get { stored(Key.aiModel) ?? defaultModel }
        set { store(newValue, for: Key.aiModel) }
    }

    static var isConfigured: Bool {
        !supabaseURL.isEmpty && !supabaseAnonKey.isEmpty && URL(string: supabaseURL) != nil
    }

    static func functionURL(_ name: String) -> URL? {
        URL(string: supabaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/functions/v1/" + name)
    }

    static func resetToDefaults() {
        let defaults = UserDefaults.standard
        [Key.supabaseURL, Key.supabaseAnonKey, Key.aiModel].forEach(defaults.removeObject(forKey:))
    }

    private static func stored(_ key: String) -> String? {
        migrateLegacyKeyIfNeeded(key)
        let value = UserDefaults.standard.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty == false) ? value : nil
    }

    /// Reporte les réglages saisis sous l'ancien préfixe `feymind.*`.
    private static func migrateLegacyKeyIfNeeded(_ key: String) {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: key) == nil else { return }
        let legacy = key.replacingOccurrences(of: "micabo.", with: "feymind.")
        guard legacy != key, let value = defaults.string(forKey: legacy) else { return }
        defaults.set(value, forKey: key)
        defaults.removeObject(forKey: legacy)
    }

    private static func store(_ value: String, for key: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(trimmed, forKey: key)
        }
    }
}
