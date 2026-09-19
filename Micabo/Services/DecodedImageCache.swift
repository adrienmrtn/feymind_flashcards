import Foundation
import UIKit

/// **Les images décodées une fois, et gardées.**
///
/// `UIImage(data:)` ne lit pas un fichier : il **décompresse un JPEG**. Sur iPhone 13, une
/// photo de schéma coûte dix à quarante millisecondes — soit une à trois images perdues à
/// soixante hertz. Écrit dans un `body`, ce travail repart à chaque évaluation de la vue :
/// au retournement d'une carte, à un changement d'état voisin, à une rotation. C'était le cas
/// de `OcclusionFigure`, en pleine session, sur le geste le plus fréquent de l'app.
///
/// Deux choses corrigent ça, et il faut les deux. Le décodage part **hors de l'acteur
/// principal**, pour que la première image ne bloque pas le dessin ; et le résultat est
/// **gardé**, pour qu'il n'y ait pas de deuxième fois.
///
/// ## Pourquoi `preparingForDisplay`
///
/// `UIImage(data:)` seul rend une image paresseuse : la décompression réelle a lieu au premier
/// dessin — donc sur l'acteur principal, donc exactement là où on ne la veut pas. Déplacer le
/// seul `UIImage(data:)` hors du fil principal n'aurait rien déplacé du tout.
/// `preparingForDisplay()` force la décompression tout de suite, là où on est.
///
/// ## Ce que le cache ne fait pas
///
/// Il ne garde rien sur disque et ne survit pas au lancement : `NSCache` se vide seul sous
/// pression mémoire, et c'est ce qu'on veut d'un cache d'images. Il n'a pas non plus
/// d'invalidation : une carte dont le schéma change reçoit `imageData` neuf, et l'appelant
/// passe alors une clé qui tient compte de ce changement.
enum DecodedImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Une vingtaine de schémas : au-delà, ce ne sont plus les cartes de la session en
        // cours. Le coût est compté en octets de la source, ce qui suffit à empêcher qu'une
        // poignée de très grandes images tienne la mémoire.
        cache.countLimit = 24
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    /// Ce que le cache a déjà, sans rien décoder. Rendu **synchronement** : c'est ce qui
    /// permet à une vue qui revient de dessiner son image dès la première passe, au lieu de
    /// clignoter le temps d'une tâche.
    static func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// Décode hors du fil principal, garde, et rend.
    ///
    /// L'appelant doit avoir lu `data` **avant** d'appeler : un `Data` se transporte entre
    /// fils, un objet SwiftData non.
    static func image(for key: String, data: Data?) async -> UIImage? {
        if let hit = cached(key) { return hit }
        guard let data, !data.isEmpty else { return nil }

        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(data: data)?.preparingForDisplay()
        }.value

        guard let decoded else { return nil }
        cache.setObject(decoded, forKey: key as NSString, cost: data.count)
        return decoded
    }
}
