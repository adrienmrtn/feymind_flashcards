import Foundation
import SwiftData

/// **Un chapitre : une partie d'un deck, avec ses blocs et ses cartes.**
///
/// C'est l'entité qui manquait, et c'est elle qui débloque tout le reste. Jusqu'ici, les
/// « chapitres repliables » d'une fiche étaient une **lecture** des blocs de type `heading`
/// faite au moment de l'afficher (`SheetChapters.split`) : la matière était là, mais elle
/// n'avait ni identité, ni progression, ni cartes rattachées. La preuve que ça bloquait
/// déjà : `exams.chapter_ids` existe dans le schéma serveur depuis des mois, et les trente
/// et un examens en base portent tous un tableau vide.
///
/// Un pourcentage de connaissance par chapitre, une révision qui ne porte que sur un
/// chapitre, un ordre d'introduction des cartes neuves qui suit le plan du cours : les
/// trois référencent un chapitre. Aucun ne tient sans cette table.
///
/// **Ce qu'un chapitre n'est pas.** Il ne se crée pas, ne s'ajoute pas, ne se déplace pas
/// et ne se supprime pas à la main. Le découpage vient du modèle à la génération du deck et
/// ne bouge plus ; ce qui s'édite, c'est le titre d'un chapitre et les blocs qu'il contient.
/// C'est un choix de produit et non une limite technique : un plan qu'on peut réordonner
/// est un plan dont l'ordre ne veut plus rien dire, et c'est cet ordre qui commande
/// l'introduction des cartes neuves.
@Model
final class Chapter {
    var id: UUID = UUID()
    /// Rang dans le deck, à partir de zéro. C'est lui qui fait l'ordre d'apparition des
    /// cartes neuves, et il ne se modifie pas depuis l'interface.
    var position: Int = 0
    var title: String = ""
    /// Les blocs de ce chapitre, encodés comme une `CourseSheet`.
    ///
    /// Le même format que `Course.sheetData`, et pour la même raison : une fiche se lit et
    /// s'écrit d'un bloc, jamais par morceaux. Le titre du chapitre reste **dans** les
    /// blocs, en tête : c'est ce qui permet de continuer à le corriger comme le reste du
    /// texte plutôt que d'en faire la seule ligne de la page qu'on ne peut plus toucher.
    /// `title` en est la copie dénormalisée, pour la liste et le sommaire.
    var sheetData: Data?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var course: Course?

    /// Les cartes nées de ces blocs.
    ///
    /// **`.nullify` et non `.cascade`.** Une carte appartient au deck, pas au chapitre :
    /// si un chapitre disparaît — une régénération, une fiche réécrite — ses cartes
    /// doivent rester, avec tout leur historique de répétition espacée. Elles retombent
    /// dans le lot des cartes non classées, ce que l'écran du deck sait montrer.
    @Relationship(deleteRule: .nullify, inverse: \Flashcard.chapter)
    var cards: [Flashcard]? = []

    init(
        id: UUID = UUID(),
        position: Int,
        title: String,
        sheet: CourseSheet? = nil,
        course: Course? = nil
    ) {
        self.id = id
        self.position = position
        self.title = title
        self.sheetData = sheet?.encoded()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.course = course
        self.cards = []
    }

    var orderedCards: [Flashcard] {
        (cards ?? []).sorted { $0.position < $1.position }
    }

    var cardCount: Int { cards?.count ?? 0 }

    /// Vrai dès qu'une fiche a été enregistrée. Se lit sans décoder le JSON.
    var hasSheet: Bool { sheetData?.isEmpty == false }

    func decodedSheet() -> CourseSheet? {
        CourseSheet.decode(from: sheetData)
    }

    func apply(_ sheet: CourseSheet?) {
        sheetData = sheet?.encoded()
        updatedAt = Date()
    }
}

/// L'état d'un chapitre, tel qu'il se lit dans la liste d'un deck.
///
/// Trois marches et non un pourcentage seul : « pas commencé » et « 3 % » ne disent pas la
/// même chose à quelqu'un qui choisit par où reprendre.
enum ChapterState: String, Equatable, Sendable {
    /// Aucune carte n'a jamais été vue.
    case untouched
    /// Au travail.
    case inProgress
    /// Toutes les cartes sont acquises.
    case learned
}

enum ChapterProgress {
    /// Le seuil au-delà duquel un chapitre est dit « su ».
    ///
    /// Quatre-vingt-dix et non cent : la dernière carte d'un chapitre peut rester à
    /// quatre-vingts pendant des semaines sans que personne n'y puisse rien, et un plan qui
    /// n'affiche jamais un chapitre terminé n'affiche jamais de progrès.
    static let learnedThreshold = 90

    /// Le pourcentage de connaissance d'un chapitre, sur la même échelle que celle des
    /// examens : la moyenne des solidités, pas la part de cartes acquises.
    ///
    /// `logs` vient de `ExamReadiness.recentLogsByCard` — une requête pour toutes les
    /// cartes du deck, pas une par chapitre.
    static func percent(
        of chapter: Chapter,
        logs: ExamReadiness.LogsByCard,
        now: Date = Date()
    ) -> Int {
        ExamReadiness.masteryPercent(of: chapter.orderedCards, logs: logs, now: now)
    }

    static func state(of chapter: Chapter, percent: Int) -> ChapterState {
        let cards = chapter.orderedCards.filter { !$0.isSuspended }
        guard !cards.isEmpty else { return .untouched }
        if cards.allSatisfy({ $0.state == .new }) { return .untouched }
        return percent >= learnedThreshold ? .learned : .inProgress
    }
}
