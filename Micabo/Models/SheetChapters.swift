import Foundation

/// **Un chapitre : un titre de partie, et tout ce qui le suit.**
///
/// La fiche est, et reste, une liste plate de blocs : c'est ce que le modèle écrit, ce que la
/// base garde et ce que les deux clients lisent. Le chapitre n'est **pas** un niveau de plus
/// dans le modèle, c'est une lecture de cette liste, faite au moment de l'afficher. Ajouter un
/// conteneur aurait obligé à migrer les fiches en base, à décider ce qu'on fait d'un chapitre
/// vide, et à réconcilier deux formats à chaque synchro — pour une information que les blocs
/// portent déjà.
///
/// Ce que ça change, en revanche, est tout l'écran : une fiche de dix-sept minutes s'ouvrait
/// au milieu de son premier paragraphe, sans qu'on sache combien de parties elle contenait ni
/// où elles commençaient. Repliée en chapitres, elle s'ouvre sur son plan.
struct SheetChapter: Identifiable, Equatable, Sendable {
    /// Le rang du chapitre dans la fiche, à partir de zéro.
    ///
    /// C'est lui qui fait l'identité, et pas le titre : deux parties d'un même cours peuvent
    /// s'appeler « Applications », et un `ForEach` qui les confondrait replierait les deux
    /// ensemble.
    let index: Int

    /// Le titre, **sans son balisage**, pour l'en-tête de l'accordéon et le sommaire.
    ///
    /// `nil` avant le premier titre de partie : une fiche ouvre sur un paragraphe, jamais sur
    /// un titre, et ce qui précède la première partie n'est pas une partie. Ce chapitre-là
    /// n'a pas d'en-tête et ne se replie pas.
    let title: String?

    /// Les blocs du chapitre, **titre compris**.
    ///
    /// Le titre reste dans le texte au lieu de monter dans l'en-tête, et c'est ce qui permet
    /// de continuer à le corriger comme le reste : la fiche est un document qu'on écrit, sans
    /// bouton Modifier, et un titre qui ne vivrait plus que dans un en-tête d'accordéon
    /// deviendrait la seule ligne de la page qu'on ne peut plus toucher.
    var blocks: [SheetBlock]

    var id: Int { index }

    /// Ce qu'on annonce d'un chapitre replié : sa longueur de lecture, en blocs.
    var isEmpty: Bool { blocks.isEmpty }
}

enum SheetChapters {
    /// Découpe une fiche à chaque titre de partie.
    ///
    /// Un titre de sous-partie n'ouvre pas de chapitre : c'est le plan **dans** une partie, et
    /// replier à ce niveau-là donnerait vingt accordéons d'une ligne au lieu du plan qu'on
    /// vient chercher.
    static func split(_ blocks: [SheetBlock]) -> [SheetChapter] {
        var chapters: [SheetChapter] = []
        var current: [SheetBlock] = []
        var title: String?

        func close() {
            guard !current.isEmpty else { return }
            chapters.append(SheetChapter(index: chapters.count, title: title, blocks: current))
            current = []
        }

        for block in blocks {
            if case .heading(let level, let text) = block, level == 1 {
                // On ferme **avant** de retenir le nouveau titre : celui qu'on ferme est
                // encore celui du chapitre qui s'achève.
                close()
                title = SheetMarkup.plain(text).nilIfBlank
            }
            current.append(block)
        }
        close()

        return chapters
    }

    /// Recolle les chapitres en une fiche.
    ///
    /// L'inverse exact de `split` : `join(split(blocks)) == blocks`, toujours, y compris pour
    /// une fiche sans le moindre titre. C'est la propriété dont dépend l'enregistrement — un
    /// chapitre se modifie seul, et la fiche entière se réécrit à partir des autres.
    static func join(_ chapters: [SheetChapter]) -> [SheetBlock] {
        chapters.flatMap(\.blocks)
    }

    /// Remplace les blocs d'un chapitre et rend la fiche entière.
    ///
    /// C'est ce qu'appelle l'éditeur d'un chapitre quand son texte a changé. Un rang inconnu
    /// ne fait rien : mieux vaut perdre une frappe que réécrire la fiche à partir d'un
    /// chapitre qui n'existe plus.
    static func replacing(
        _ chapters: [SheetChapter],
        at index: Int,
        with blocks: [SheetBlock]
    ) -> [SheetBlock] {
        guard chapters.indices.contains(index) else { return join(chapters) }
        var next = chapters
        next[index].blocks = blocks
        return join(next)
    }
}
