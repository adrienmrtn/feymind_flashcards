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

    /// Ce que l'objet gardé pèse **réellement** en mémoire.
    ///
    /// Le premier jet déclarait la taille de la source compressée. C'était faux d'un ordre de
    /// grandeur — une photo de 300 Ko en JPEG occupe une dizaine de mégaoctets une fois
    /// décompressée — et le plafond ne mordait donc jamais : seul `countLimit` tenait
    /// vraiment. Quatre octets par pixel, à l'échelle de l'écran.
    private static func cost(of image: UIImage) -> Int {
        let pixels = image.size.width * image.scale * image.size.height * image.scale
        return Int(pixels.rounded()) * 4
    }

    /// La clé d'un schéma de carte. Elle vit ici pour que les deux vues qui lisent et les
    /// deux endroits qui invalident ne puissent pas l'écrire différemment.
    static func cardKey(_ id: UUID) -> String {
        "card-\(id.uuidString)"
    }

    /// La clé d'une couverture d'import. Un document importé n'a pas d'identité propre ; son
    /// nom de fichier et le poids de sa couverture suffisent à la distinguer d'une autre.
    static func coverKey(fileName: String, bytes: Int) -> String {
        "cover-\(fileName)-\(bytes)"
    }

    /// **Décode et garde avant que la vue n'existe.**
    ///
    /// Pour les images dont la première apparition ne doit pas clignoter. Une vue qui trouve
    /// le cache froid dessine son repli, puis bascule — et cette bascule se voit. En amorçant
    /// ici, le décodage a lieu pendant que l'utilisateur attend **déjà** autre chose (la
    /// lecture d'un PDF, une transcription), et la vue qui suit trouve le cache chaud.
    ///
    /// Le décodage reste hors du fil principal : c'est `image(for:data:)` qui travaille.
    static func prime(_ key: String, data: Data?) async {
        _ = await image(for: key, data: data)
    }

    /// Ce que le cache a déjà, sans rien décoder. Rendu **synchronement** : c'est ce qui
    /// permet à une vue qui revient de dessiner son image dès la première passe, au lieu de
    /// clignoter le temps d'une tâche.
    static func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    /// **À appeler quand l'image derrière une clé a changé.**
    ///
    /// Sans ça, un schéma remplacé n'est jamais redessiné : la clé est la même, le cache
    /// répond, et l'ancienne image reste jusqu'au relancement de l'app. C'est arrivé au
    /// premier jet de ce fichier, et c'est la raison de cette fonction.
    ///
    /// L'invalidation est explicite plutôt que déduite d'une date de modification. Une clé
    /// qui porterait `updatedAt` se renouvellerait à **chaque note** — `Flashcard.review`
    /// écrit `updatedAt` (Flashcard.swift:272) — donc en pleine session, sur le geste que ce
    /// cache existe précisément pour rendre gratuit. Les deux endroits qui remplacent une
    /// image, eux, se comptent sur une main.
    static func forget(_ key: String) {
        cache.removeObject(forKey: key as NSString)
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
        cache.setObject(decoded, forKey: key as NSString, cost: cost(of: decoded))
        return decoded
    }
}
