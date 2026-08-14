import Foundation

/// Résultat d'un import, quel que soit le format d'origine.
/// Le texte est toujours produit sur l'appareil : PDFKit, OCR Vision ou lecture du DOCX.
/// Les images ne servent qu'à une passe visuelle facultative (schémas), jamais à lire le texte.
struct ImportedDocument {
    var text: String
    var pageImages: [Data]
    var coverImage: Data?
    var pageCount: Int
    var fileName: String
    var source: CourseSource
    /// Comment le texte a été obtenu, affiché à l'utilisateur.
    var extractionNote: String?

    var hasUsableText: Bool {
        text.count >= 200
    }
}
