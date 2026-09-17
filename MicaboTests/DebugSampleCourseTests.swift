import SwiftData
import XCTest
@testable import Micabo

/// **Le cours d'essai des constructions de développement.**
///
/// Ce qui est vérifié ici n'est pas l'extraction du PDF — elle demande le paquet de l'app,
/// que le paquet de tests n'est pas — mais les deux propriétés dont dépend son utilité, et
/// qui se perdraient sans bruit si quelqu'un changeait une ligne de `DebugSampleCourse` :
/// il arrive **fichable**, et le nettoyage du contenu de démonstration ne le mange pas.
final class DebugSampleCourseTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.debugSample"

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

    /// Le cours tel que `DebugSampleCourse.importNow` l'enregistre, sans passer par le PDF.
    private func seeded() throws -> Course {
        try CourseRepository.save(
            GeneratedCourse(
                title: L10n.t("ios.debug.sampleCourseTitle", locale: .fr),
                subject: nil,
                emoji: "🌿",
                summary: "",
                sheet: nil,
                contextText: "La photosynthèse convertit l'énergie lumineuse en énergie chimique."
            ),
            source: .pdf,
            rawText: "La photosynthèse convertit l'énergie lumineuse en énergie chimique.",
            fileName: "Photosynthese.pdf",
            in: context
        )
    }

    /// **Il arrive sans fiche, et c'est tout l'intérêt.**
    ///
    /// Un cours déjà fiché n'aurait rien à ficher. Les trois conditions que `CourseSheetView`
    /// exige pour proposer « Faire la fiche » puis « Refaire la fiche » sont réunies : pas de
    /// fiche, du texte brut, et une source qui en attend une.
    func testTheCourseArrivesReadyToBeSheeted() throws {
        let course = try seeded()

        XCTAssertNil(CourseSheet.decode(from: course.sheetData))
        XCTAssertNotNil(course.rawText.nilIfBlank)
        XCTAssertTrue(course.source.expectsSheet)
    }

    /// **Le nettoyage du contenu de démonstration ne doit pas le manger.**
    ///
    /// `SampleContentPurge` supprime tout cours de source `sample`. Marquer le cours d'essai
    /// ainsi aurait paru naturel — c'en est un — et il aurait disparu au premier lancement
    /// suivant une mise à jour, sans que rien ne le signale. Il est de source `pdf`, parce
    /// qu'il vient bel et bien d'un PDF.
    func testThePurgeLeavesItAlone() throws {
        let course = try seeded()
        let id = course.id

        SampleContentPurge.purgeIfNeeded(in: context, defaults: defaults)

        let restants = CourseRepository.allCourses(in: context).map(\.id)
        XCTAssertTrue(restants.contains(id))
    }

    /// Le drapeau de premier lancement n'est ni celui du nettoyage, ni celui des versions
    /// d'avant : les confondre ferait sauter l'un des deux.
    func testTheSeedFlagIsItsOwn() {
        XCTAssertNotEqual(DebugSampleCourse.seededKey, SampleContentPurge.key)
        XCTAssertFalse(SampleContentPurge.legacySeedKeys.contains(DebugSampleCourse.seededKey))
    }

    /// Le titre existe dans les cinq langues : un cours d'essai nommé par sa clé de
    /// traduction serait le premier bug qu'on croirait voir dans la fiche.
    func testTheTitleIsTranslatedEverywhere() {
        for locale in UiLocale.allCases {
            let titre = L10n.t("ios.debug.sampleCourseTitle", locale: locale)
            XCTAssertFalse(titre.isEmpty, locale.rawValue)
            XCTAssertNotEqual(titre, "ios.debug.sampleCourseTitle", locale.rawValue)
        }
    }
}
