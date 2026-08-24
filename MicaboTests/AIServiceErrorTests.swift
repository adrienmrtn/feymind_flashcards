import XCTest
@testable import Micabo

final class AIServiceErrorTests: XCTestCase {
    func testParserJargonIsHiddenFromTheStudent() {
        let raw = SupabaseFunctionError.server(
            status: 502,
            message: "JSON invalide renvoyé par le modèle : Expected ',' or ']' after array element in JSON at position 25458 (line 530 column 6)",
            code: nil
        )

        let error = AIServiceError(raw)

        XCTAssertEqual(error.errorDescription, "L'écriture a échoué. Réessaie, rien n'a été perdu.")
    }

    func testConfigurationErrorsStayReadable() {
        let raw = SupabaseFunctionError.server(
            status: 500,
            message: "Le secret FAL_KEY est absent du projet Supabase.",
            code: nil
        )

        let error = AIServiceError(raw)

        XCTAssertEqual(
            error.errorDescription,
            "La clé fal.ai est absente côté Supabase. Ajoute le secret FAL_KEY à ton projet."
        )
    }
}
