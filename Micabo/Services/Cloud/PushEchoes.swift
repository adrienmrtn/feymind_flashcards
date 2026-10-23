import Foundation

/// **Les échos de nos propres envois.**
///
/// La base pose elle-même `updated_at` à chaque écriture (`touch_updated_at`,
/// `chapters_touch`) : une ligne que cet appareil vient d'envoyer redescend au passage
/// suivant avec un horodatage du serveur, postérieur à la copie locale. La descente la
/// prenait pour une modification faite ailleurs et l'appliquait - par-dessus ce qui avait
/// changé ici **pendant** l'envoi. Le cas réel : un thème arrivé pendant la montée de sa
/// version « en préparation » repassait « en préparation », se réécrivait, et doublait ses
/// cartes.
///
/// On garde donc, par table et par identifiant, l'horodatage que le serveur a rendu à notre
/// envoi (`SupabaseDatabase.upsertReturningStamps`). Une ligne qui redescend avec exactement
/// cet horodatage est notre écho : personne d'autre ne l'a touchée depuis, et la copie locale
/// est au moins aussi neuve. Un autre horodatage, c'est un autre appareil, ou le site : la
/// règle ordinaire (le plus récent gagne) s'applique.
struct PushEchoes: Equatable {
    private static let key = "micabo.cloud.pushEchoes"
    /// Au-delà, un écho ne sert plus : la descente qui l'aurait ramené est passée depuis
    /// longtemps (elle ne relit que cinq minutes avant son repère).
    static let lifetime: TimeInterval = 2 * 24 * 3600
    /// Les deux horodatages viennent de la même chaîne du serveur, lue deux fois ; la marge
    /// couvre l'arrondi d'un `Double`, pas une autre écriture.
    private static let tolerance: TimeInterval = 0.0005

    /// table → identifiant (minuscules) → horodatage du serveur, en secondes depuis 1970.
    private(set) var stamps: [String: [String: Double]] = [:]

    init(stamps: [String: [String: Double]] = [:]) {
        self.stamps = stamps
    }

    static func load(from defaults: UserDefaults = .standard) -> PushEchoes {
        PushEchoes(stamps: (defaults.dictionary(forKey: key) as? [String: [String: Double]]) ?? [:])
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(stamps, forKey: Self.key)
    }

    static func removeAll(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }

    mutating func record(_ rows: [SupabaseDatabase.RowStamp], in table: String) {
        guard !rows.isEmpty else { return }
        var byID = stamps[table] ?? [:]
        for row in rows {
            byID[row.id.uuidString.lowercased()] = row.updated_at.timeIntervalSince1970
        }
        stamps[table] = byID
    }

    /// Vrai quand cette ligne distante est exactement celle que cet appareil a envoyée.
    func isEcho(_ table: String, id: UUID, updatedAt: Date) -> Bool {
        guard let sent = stamps[table]?[id.uuidString.lowercased()] else { return false }
        return abs(sent - updatedAt.timeIntervalSince1970) < Self.tolerance
    }

    /// Oublie les échos trop vieux pour revenir encore.
    mutating func prune(now: Date = Date()) {
        let cutoff = now.timeIntervalSince1970 - Self.lifetime
        stamps = stamps.compactMapValues { byID in
            let kept = byID.filter { $0.value >= cutoff }
            return kept.isEmpty ? nil : kept
        }
    }
}
