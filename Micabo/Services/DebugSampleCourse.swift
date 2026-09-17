#if DEBUG
import Foundation
import SwiftData

/// **Le cours d'essai des constructions de développement.**
///
/// Travailler sur la fiche demande une fiche, donc un cours, donc un import : ouvrir le
/// sélecteur de fichiers, retrouver un PDF dans iCloud, attendre l'extraction, et
/// recommencer à chaque réinstallation du simulateur. Le cycle qu'on veut mesurer — écrire
/// la fiche, la relire, la refaire avec une autre longueur — est de quelques secondes ; la
/// mise en place autour en prenait dix fois plus.
///
/// Un vrai PDF de cours est donc embarqué, et il entre par **le chemin d'import ordinaire** :
/// `PDFImportService` en tire le texte et la couverture, `CourseRepository` enregistre un
/// cours de source `pdf`. Rien n'est simulé, et le cours obtenu est en tout point celui
/// qu'on aurait en important le fichier à la main.
///
/// **Il arrive sans fiche**, et c'est le point. Un cours déjà fiché n'aurait rien à ficher :
/// celui-ci s'ouvre sur « Faire la fiche », et son menu propose de la refaire autant de fois
/// qu'on veut, dans les trois longueurs. C'est exactement la boucle qu'on vient tester.
///
/// **Il se synchronise comme n'importe quel cours.** La synchro ne trie pas : si la
/// construction de développement est connectée à un vrai compte, le cours d'essai remonte et
/// apparaît sur le site et sur le téléphone. C'est assumé plutôt que contourné — un cours qui
/// s'enregistrerait à moitié ne serait plus le cours qu'on teste — et ça se défait en le
/// supprimant, ce qui se synchronise aussi.
///
/// Tout le fichier est sous `#if DEBUG` : rien de tout ceci n'existe dans l'app qu'on livre.
/// Le PDF, lui, est une ressource du paquet et pèse huit cents kilo-octets dans les deux
/// constructions — le retirer de la version de livraison demanderait une phase de script, et
/// ça ne vaut pas la fragilité tant que personne ne compte les octets.
enum DebugSampleCourse {
    /// Le fichier embarqué, sans son extension.
    static let resource = "Photosynthese"

    /// Le drapeau de premier lancement. Nommé assez précisément pour qu'ajouter un second
    /// cours d'essai un jour n'ait pas à deviner ce que celui-ci recouvrait.
    static let seededKey = "micabo.debug.didSeedPhotosynthesis"

    /// Le PDF dans le paquet.
    ///
    /// Trois recherches parce qu'une phase « Copy Bundle Resources » aplatit les dossiers, et
    /// qu'une référence de dossier ne les aplatit pas : selon la façon dont Xcode a repris le
    /// groupe, le fichier est à la racine ou sous son chemin. C'est le même tâtonnement que
    /// `InstitutionSearchService`, et pour la même raison.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: resource, withExtension: "pdf")
            ?? Bundle.main.url(forResource: resource, withExtension: "pdf", subdirectory: "Debug")
            ?? Bundle.main.url(forResource: resource, withExtension: "pdf", subdirectory: "Resources/Debug")
    }

    /// Pose le cours au premier lancement, une fois pour toutes.
    ///
    /// Le drapeau est posé **avant** le travail, comme dans `SampleContentPurge` et pour la
    /// même raison : si l'extraction échoue, on ne veut pas la retenter à chaque lancement.
    /// Le bouton des réglages reste là pour la refaire à la demande.
    @MainActor
    static func seedIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) async {
        guard !defaults.bool(forKey: seededKey) else { return }
        defaults.set(true, forKey: seededKey)
        _ = try? await importNow(in: context)
    }

    /// (Ré)importe le cours et rend celui qui vient d'être créé.
    ///
    /// Aucune déduplication : réimporter donne un second cours. C'est voulu — on compare
    /// souvent deux fiches du même document écrites avec deux réglages, et les mettre côte à
    /// côte dans la bibliothèque est justement ce qu'on veut faire.
    @discardableResult
    @MainActor
    static func importNow(in context: ModelContext) async throws -> Course? {
        guard let url = bundledURL else {
            // Sans cette ligne, un PDF qu'Xcode n'aurait pas repris dans « Copy Bundle
            // Resources » donnerait un bouton qui ne fait rien et un premier lancement sans
            // cours, sans que rien ne dise pourquoi.
            print("[DebugSampleCourse] \(resource).pdf absent du paquet : vérifier qu'il est bien dans les ressources de la cible.")
            return nil
        }

        // Les pages ne sont pas rendues en JPEG : `CourseSheetView.writeSheet` envoie une
        // liste d'images vide quand on refait une fiche, donc les produire ici coûterait
        // une seconde de lancement pour quelque chose que personne ne lira. La couverture,
        // elle, se voit dans la bibliothèque.
        var options = PDFImportService.Options.default
        options.includeImages = false

        // `extractWithOCR` et non `extract` : c'est ce qu'appelle l'écran d'import, et la
        // différence compte le jour où l'on remplace ce PDF par un scan. Sur un document
        // qui porte déjà son texte, comme celui-ci, la reconnaissance ne se déclenche pas.
        let document = try await PDFImportService.extractWithOCR(from: url, options: options)

        // Ni fiche ni résumé : le cours s'ouvre sur « Faire la fiche », qui est le geste
        // qu'on vient essayer. Le contexte est le texte brut, comme pour un import dont la
        // génération n'a pas encore eu lieu.
        let generated = GeneratedCourse(
            title: L10n.t("ios.debug.sampleCourseTitle", locale: .resolved()),
            subject: nil,
            emoji: "🌿",
            summary: "",
            sheet: nil,
            contextText: document.text
        )

        return try CourseRepository.save(
            generated,
            source: .pdf,
            rawText: document.text,
            fileName: document.fileName,
            coverImageData: document.coverImage,
            in: context
        )
    }
}
#endif
