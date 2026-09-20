import Foundation
import SwiftData

/// **Fabrique les chapitres d'un deck, et rattrape ceux qui n'en ont pas.**
///
/// Le découpage lui-même n'est pas une invention : `SheetChapters.split` sait depuis
/// longtemps lire les titres de partie d'une fiche, et c'est ce qui dessinait les
/// accordéons. Ce fichier ne fait que **matérialiser** cette lecture — la transformer d'un
/// calcul refait à chaque affichage en une table qui porte une identité, un rang, et des
/// cartes.
///
/// La migration est faite à la lecture, deck par deck, et non en une passe au lancement :
/// une base de cent quarante cours ouverte d'un bloc sur l'acteur principal est exactement
/// le genre de chose qui fait ramer une app au démarrage.
enum ChapterBuilder {

    /// Le découpage d'une fiche en parties, prêt à devenir des `Chapter`.
    ///
    /// Le titre est celui de la partie. Avant le premier titre de niveau un, une fiche a
    /// souvent une introduction : elle devient un chapitre à part entière, nommé d'après le
    /// deck, plutôt que d'être recollée à la partie suivante — c'est du texte que
    /// l'étudiant lira, il lui faut une entrée dans le plan.
    static func split(_ sheet: CourseSheet, deckTitle: String) -> [(title: String, sheet: CourseSheet)] {
        SheetChapters.split(sheet.blocks)
            .filter { !$0.isEmpty }
            .map { part in
                (title: part.title ?? introTitle(for: deckTitle), sheet: CourseSheet(blocks: part.blocks))
            }
    }

    private static func introTitle(for deckTitle: String) -> String {
        let trimmed = deckTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
            ? L10n.t("ios.chapter.intro", locale: .resolved())
            : trimmed
    }

    /// **Donne ses chapitres à un deck qui n'en a pas encore.**
    ///
    /// Sans effet si le deck en a déjà, ou s'il n'a pas de fiche à découper — un paquet de
    /// cartes importé d'Anki n'a rien à chapitrer, et ce n'est pas un défaut.
    ///
    /// Les cartes existantes **ne sont rattachées à rien**. C'est délibéré, et c'est la
    /// seule décision discutable de ce fichier, donc elle est écrite ici : on pourrait
    /// répartir les cartes au prorata de leur position dans le document, en pariant
    /// qu'elles ont été produites dans l'ordre du texte. Le pari est raisonnable et il est
    /// faux assez souvent pour classer des dizaines de cartes sous un titre qui n'est pas
    /// le leur — sans que rien à l'écran ne permette de s'en apercevoir. Une carte sans
    /// chapitre se voit ; une carte dans le mauvais chapitre, non.
    ///
    /// - Returns: vrai si des chapitres viennent d'être créés.
    @discardableResult
    static func migrate(_ course: Course, in context: ModelContext) -> Bool {
        guard (course.chapters ?? []).isEmpty else { return false }
        guard let sheet = course.decodedSheet(), !sheet.isEmpty else { return false }

        let parts = split(sheet, deckTitle: course.title)
        guard !parts.isEmpty else { return false }

        for (index, part) in parts.enumerated() {
            let chapter = Chapter(
                position: index,
                title: part.title,
                sheet: part.sheet,
                course: course
            )
            context.insert(chapter)
        }
        return true
    }

    /// La même chose, sur une liste de decks, avec un seul enregistrement à la fin.
    @discardableResult
    static func migrate(_ courses: [Course], in context: ModelContext) -> Int {
        var built = 0
        for course in courses where migrate(course, in: context) {
            built += 1
        }
        if built > 0 {
            try? context.save()
        }
        return built
    }

    /// **Remplace le plan d'un deck par un nouveau découpage.**
    ///
    /// Sert à la génération : le modèle rend un plan, on le pose. Les chapitres existants
    /// sont retirés, et leurs cartes retombent sans chapitre plutôt que de disparaître avec
    /// eux (`Chapter.cards` est en `.nullify`). Les cartes sont ensuite rattachées par
    /// `attach(cards:toChapterAt:)`, qui sait les retrouver par leur identifiant.
    static func replace(
        chaptersOf course: Course,
        with parts: [(title: String, sheet: CourseSheet)],
        in context: ModelContext
    ) {
        for chapter in course.chapters ?? [] {
            context.delete(chapter)
        }
        course.chapters = []

        for (index, part) in parts.enumerated() {
            let chapter = Chapter(
                position: index,
                title: part.title,
                sheet: part.sheet,
                course: course
            )
            context.insert(chapter)
        }
        course.updatedAt = Date()
    }

    /// Rattache des cartes au chapitre d'un rang donné.
    ///
    /// Silencieux quand le rang n'existe pas : un modèle qui rend un numéro de chapitre
    /// hors plan ne doit pas faire perdre la carte, seulement la laisser non classée.
    static func attach(cards: [Flashcard], toChapterAt position: Int, of course: Course) {
        guard let chapter = course.orderedChapters.first(where: { $0.position == position }) else { return }
        for card in cards {
            card.chapter = chapter
        }
    }
}
