import SwiftData
import XCTest
@testable import Micabo

/// Le nettoyage du contenu de démonstration : il doit vider ce que Micabo s'était inséré à
/// lui-même, et **ne rien toucher d'autre**. Un utilisateur qui a importé son propre cours de
/// photosynthèse ne doit pas le perdre parce qu'une ancienne version en insérait un du même
/// nom.
final class SampleContentPurgeTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.samplePurge"

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)

        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        context = nil
        container = nil
    }

    private func makeCourse(title: String, source: CourseSource) throws -> Course {
        try CourseRepository.save(
            GeneratedCourse(title: title, subject: nil, emoji: "📘", summary: "", contextText: ""),
            source: source,
            rawText: "",
            in: context
        )
    }

    private func courseTitles() -> [String] {
        CourseRepository.allCourses(in: context).map(\.title).sorted()
    }

    func testOnlySeededCoursesAreRemoved() throws {
        _ = try makeCourse(title: "La photosynthèse", source: .sample)
        _ = try makeCourse(title: "Les fonctions affines", source: .sample)
        _ = try makeCourse(title: "Mon cours à moi", source: .pdf)
        try context.save()

        SampleContentPurge.purgeIfNeeded(in: context, defaults: defaults)

        XCTAssertEqual(courseTitles(), ["Mon cours à moi"])
    }

    /// Les cartes partent avec leur cours : sans ça, l'écran Réviser continuerait d'annoncer
    /// des cartes à réviser qui n'appartiennent plus à rien.
    func testCardsOfSeededCoursesGoWithThem() throws {
        let sample = try makeCourse(title: "La photosynthèse", source: .sample)
        _ = try CourseRepository.addFlashcards(
            [GeneratedFlashcard(front: "Question", back: "Réponse", hint: nil)],
            to: sample,
            in: context
        )
        try context.save()
        XCTAssertEqual(CourseRepository.allCards(in: context).count, 1)

        SampleContentPurge.purgeIfNeeded(in: context, defaults: defaults)

        XCTAssertTrue(CourseRepository.allCards(in: context).isEmpty)
    }

    /// Le nettoyage ne passe qu'une fois : un cours d'exemple créé après coup — par un test,
    /// ou par une future fonctionnalité qui réutiliserait cette source — n'a pas à disparaître
    /// au lancement suivant.
    func testPurgeRunsOnlyOnce() throws {
        _ = try makeCourse(title: "La photosynthèse", source: .sample)
        try context.save()

        SampleContentPurge.purgeIfNeeded(in: context, defaults: defaults)
        XCTAssertTrue(courseTitles().isEmpty)
        XCTAssertTrue(defaults.bool(forKey: SampleContentPurge.key))

        _ = try makeCourse(title: "Revenu après coup", source: .sample)
        try context.save()

        SampleContentPurge.purgeIfNeeded(in: context, defaults: defaults)
        XCTAssertEqual(courseTitles(), ["Revenu après coup"])
    }

    /// Les drapeaux d'insertion des anciennes versions sont retirés, sinon un retour en
    /// arrière réinsérerait les deux cours.
    func testLegacySeedFlagsAreCleared() throws {
        for legacy in SampleContentPurge.legacySeedKeys {
            defaults.set(true, forKey: legacy)
        }

        SampleContentPurge.purgeIfNeeded(in: context, defaults: defaults)

        for legacy in SampleContentPurge.legacySeedKeys {
            XCTAssertFalse(defaults.bool(forKey: legacy), "\(legacy) doit être retiré")
        }
    }
}
