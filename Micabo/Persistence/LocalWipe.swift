import Foundation
import SwiftData

/// **Vider le téléphone de ce qui appartient à l'élève.**
///
/// Deux gestes, et ils ne disent pas la même chose au serveur :
/// - « Tout effacer » (`eraseCourses`) efface **partout** : chaque identifiant reçoit sa
///   pierre tombale avant de disparaître ici, et la synchro suivante pose `deleted_at` au
///   serveur. Avant le 23 octobre 2026, l'effacement en masse ne passait pas par
///   `CourseRepository` : rien n'était marqué, la descente suivante refaisait tout revivre
///   depuis le compte, et le site gardait tout.
/// - La déconnexion et la suppression du compte (`eraseAccountData`) vident **le téléphone
///   seulement**, sans pierre tombale : les cours restent sur le compte (ou partent avec lui,
///   par la cascade du serveur). Avant, ils restaient sur le téléphone, et la synchro suivante
///   les remontait sous le compte d'après - l'invité suivant, un camarade sur le même iPhone.
///
/// Les suppressions se font objet par objet et non par `delete(model:)` : la suppression en
/// masse de SwiftData ne suit pas les règles de cascade, et laissait des thèmes orphelins.
@MainActor
enum LocalWipe {
    /// « Tout effacer » : les cours, leurs thèmes, leurs cartes et leur historique, ici et au
    /// serveur. Les examens, les dossiers et les journées fermées restent.
    static func eraseCourses(in context: ModelContext) throws {
        let courses = try context.fetch(FetchDescriptor<Course>())
        for course in courses {
            NotificationCenter.default.post(name: CourseRepository.courseDeleted, object: course.id)
            CloudTombstones.mark(CloudTable.courses, id: course.id)
        }
        for chapter in try context.fetch(FetchDescriptor<Chapter>()) {
            CloudTombstones.mark(CloudTable.chapters, id: chapter.id)
        }
        for card in try context.fetch(FetchDescriptor<Flashcard>()) {
            CloudTombstones.mark(CloudTable.flashcards, id: card.id)
        }
        // L'historique n'a pas de `deleted_at` au serveur : il n'y revit que rattaché à une
        // carte connue ici, et ces cartes-là sont marquées juste au-dessus.
        try deleteAll(Course.self, in: context)
        try deleteAll(Chapter.self, in: context)
        try deleteAll(Flashcard.self, in: context)
        try deleteAll(ReviewLog.self, in: context)
        LibraryCensus.forget()
        CourseLedger.noteChange()
        // Les pierres tombales partent tout de suite, sans attendre le lancement suivant.
        CloudSync.nudge()
    }

    /// Tout ce que l'élève possède sur ce téléphone, sans rien dire au serveur : à la sortie
    /// d'un compte (déconnexion, suppression).
    static func eraseAccountData(in context: ModelContext) throws {
        for course in try context.fetch(FetchDescriptor<Course>()) {
            NotificationCenter.default.post(name: CourseRepository.courseDeleted, object: course.id)
        }
        try deleteAll(Course.self, in: context)
        try deleteAll(Chapter.self, in: context)
        try deleteAll(Flashcard.self, in: context)
        try deleteAll(ReviewLog.self, in: context)
        try deleteAll(CourseFolder.self, in: context)
        try deleteAll(Exam.self, in: context)
        try deleteAll(OffDay.self, in: context)
        // Ce qui vit hors de la base mais appartient au compte qui part : les journées
        // décochées (sinon effacées au serveur du compte suivant), les examens blancs rendus,
        // et l'examen offert, que le serveur compte par compte.
        OffDayTombstones.clear(OffDayTombstones.all())
        ExamHistory.clear()
        ExamAllowance.freeMockUsed = false
        LibraryCensus.forget()
        CourseLedger.noteChange()
    }

    /// Supprime chaque objet d'un type, puis enregistre. Un enregistrement par type : la
    /// cascade d'un cours supprime ses thèmes et ses cartes, et le passage suivant ne relit
    /// que ce qui reste vraiment (des orphelins).
    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
        try context.save()
    }
}
