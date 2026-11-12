import Foundation

/// **Un petit cache borné, lisible de n'importe quel fil.**
///
/// Les écrans relisent les mêmes choses à chaque passe de `body` : le plan d'une leçon, les
/// notes d'un thème, sa question de fin, la progression — tous gardés en JSON dans la base —
/// et l'icône d'une matière, retrouvée en pliant son nom contre cent mots-clés. Chacune de ces
/// lectures refaisait tout le travail : tourner une page de notes décodait trois fois le même
/// JSON, une liste de quarante leçons pliait quatre-vingts fois les mêmes noms de matière.
///
/// Le cache se pose **à la source**, sous les fonctions qui décodent : aucun écran ne change,
/// et aucun ne peut oublier de s'en servir. La clé est la donnée elle-même (les octets du
/// JSON, le nom de la matière) : une donnée qui change est une autre clé, rien n'est jamais
/// périmé. Ce qu'il rend est une valeur (une structure), jamais un objet partagé.
///
/// Plein, il se vide d'un coup : c'est un cache de quelques dizaines d'entrées relues en
/// boucle, pas une mémoire à gérer finement.
final class MemoCache<Key: Hashable, Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Key: Value] = [:]
    private let limit: Int

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// La valeur de `key`, calculée par `make` la première fois seulement. `make` tourne hors
    /// du verrou : deux fils qui demandent la même clé en même temps la calculent deux fois,
    /// ce qui ne coûte rien de plus qu'avant le cache.
    func value(for key: Key, make: () -> Value) -> Value {
        lock.lock()
        if let hit = storage[key] {
            lock.unlock()
            return hit
        }
        lock.unlock()
        let made = make()
        lock.lock()
        if storage.count >= limit { storage.removeAll(keepingCapacity: true) }
        storage[key] = made
        lock.unlock()
        return made
    }

    func removeAll() {
        lock.lock()
        storage.removeAll(keepingCapacity: true)
        lock.unlock()
    }
}
