import Foundation
import XCTest
@testable import Micabo

final class CourseContentTests: XCTestCase {
    func testStructuredBlocksAreFlattenedIntoContext() throws {
        let json = """
        {
          "title": "Titre",
          "summary": "Résumé",
          "blocks": [
            {"type": "paragraph", "text": "Premier"},
            {"type": "bloc-inconnu", "valeur": 12},
            {"type": "heading", "level": 2, "text": "Second"}
          ]
        }
        """

        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))
        let lines = course.contextText.components(separatedBy: "\n")

        XCTAssertEqual(course.title, "Titre")
        XCTAssertEqual(lines, ["Premier", "Second"])
    }

    func testNestedBlocksKeepTheirText() throws {
        let json = """
        {
          "title": "Titre",
          "summary": "S",
          "blocks": [
            {"type": "comparison", "title": "Comparaison", "columns": [
              {"title": "Colonne", "items": ["Premier point", "Second point"]}
            ]},
            {"type": "chart", "title": "Rendement", "bars": [{"label": "A", "value": 40, "unit": "%"}]}
          ]
        }
        """

        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertTrue(course.contextText.contains("Premier point"))
        XCTAssertTrue(course.contextText.contains("Colonne"))
        XCTAssertTrue(course.contextText.contains("Rendement"))
        // Les valeurs numériques ne portent pas de sens hors de leur graphique.
        XCTAssertFalse(course.contextText.contains("40"))
    }

    func testContextTextIsUsedWhenTheServerSendsItDirectly() throws {
        let json = #"{"title": "T", "summary": "S", "contextText": "Une seule ligne"}"#
        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertEqual(course.contextText, "Une seule ligne")
    }

    func testMissingTitleFallsBackInsteadOfFailing() throws {
        let json = #"{"summary": "S", "blocks": [{"type": "paragraph", "text": "a"}]}"#
        let course = try JSONDecoder().decode(GeneratedCourse.self, from: Data(json.utf8))

        XCTAssertEqual(course.title, "Cours sans titre")
        XCTAssertEqual(course.contextText, "a")
    }

    // MARK: - Nettoyage

    func testEmDashesAreReplaced() {
        XCTAssertEqual(
            TextSanitizer.removeEmDashes("Le cours — voici — la suite"),
            "Le cours, voici, la suite"
        )
        XCTAssertEqual(TextSanitizer.removeEmDashes("mot—mot"), "mot-mot")
    }

    func testInlineMarkupIsStripped() {
        XCTAssertEqual(
            TextSanitizer.clean("Un **terme** et une ==définition== avec `du code`"),
            "Un terme et une définition avec du code"
        )
    }

    func testSanitizationReachesTitleSummaryAndContext() {
        let course = GeneratedCourse(
            title: "A — B",
            subject: "C — D",
            summary: "**Résumé**",
            contextText: "E — F"
        )

        let clean = course.sanitized()

        XCTAssertEqual(clean.title, "A, B")
        XCTAssertEqual(clean.subject, "C, D")
        XCTAssertEqual(clean.summary, "Résumé")
        XCTAssertEqual(clean.contextText, "E, F")
    }

    // MARK: - La casse d'une matière

    /// Le modèle rend la casse du titre qu'il a lu : « HISTOIRE » quand le polycopié criait.
    /// Sur une pastille de filtre, une matière en capitales hurle au milieu d'un écran qui ne
    /// crie jamais.
    func testAScreamingSubjectGetsItsCaseBack() {
        XCTAssertEqual(TextSanitizer.subject("HISTOIRE"), "Histoire")
        XCTAssertEqual(TextSanitizer.subject("PHYSIQUE-CHIMIE"), "Physique-Chimie")
        XCTAssertEqual(TextSanitizer.subject("DROIT CONSTITUTIONNEL"), "Droit Constitutionnel")
        XCTAssertEqual(TextSanitizer.subject("MATHÉMATIQUES"), "Mathématiques")
    }

    /// **Un sigle garde ses capitales.** « Svt » ou « Staps » se lit comme une faute, là
    /// qu'« ARTS » laissé en capitales n'est qu'un cas non corrigé : entre les deux, la règle
    /// choisit de ne pas se tromper. Un mot de quatre lettres avec deux voyelles est un mot ;
    /// le reste est probablement un sigle.
    func testAnAcronymKeepsItsCapitals() {
        for acronym in ["SVT", "SES", "PASS", "STAPS", "HGGSP", "QCM", "PIB"] {
            XCTAssertEqual(TextSanitizer.subject(acronym), acronym, "\(acronym) est un sigle")
        }
    }

    /// Une matière déjà écrite comme quelqu'un l'écrirait n'est pas touchée : il n'y a rien à
    /// y redire, et une règle qui repasse sur du texte correct finit par l'abîmer.
    func testASubjectThatAlreadyHasCaseIsLeftAlone() {
        XCTAssertEqual(TextSanitizer.subject("Histoire des arts"), "Histoire des arts")
        XCTAssertEqual(TextSanitizer.subject("Physique-chimie"), "Physique-chimie")
        XCTAssertEqual(TextSanitizer.subject("SVT et biologie"), "SVT et biologie")
    }

    /// La règle passe par le nettoyage : une matière criée **et** balisée ressort propre des
    /// deux côtés, et c'est ce chemin-là que prend un cours importé.
    func testTheImportPathCleansAndLowersTheSubject() {
        let course = GeneratedCourse(title: "T", subject: "**HISTOIRE**", summary: "S")
        XCTAssertEqual(course.sanitized().subject, "Histoire")
    }

    // MARK: - Repli hors ligne

    func testOfflineBuilderProducesCardsFromRawText() {
        let source = """
        Les fonctions affines
        Une fonction affine s'écrit toujours sous la forme f(x) = ax + b, où a et b sont deux nombres fixés.
        Le coefficient directeur a mesure la pente de la droite représentative de la fonction.
        """

        let course = OfflineCourseBuilder.build(from: source, hintTitle: nil, sourceName: nil)
        let cards = OfflineCourseBuilder.buildFlashcards(from: course, count: 5)

        XCTAssertFalse(cards.isEmpty)
        XCTAssertTrue(cards.allSatisfy { !$0.front.isEmpty && !$0.back.isEmpty })
    }
}
