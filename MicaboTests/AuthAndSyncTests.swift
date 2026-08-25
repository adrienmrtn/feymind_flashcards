import XCTest
@testable import Micabo

/// Ce que Supabase renvoie, et ce que Micabo en fait.
///
/// Les charges utiles ci-dessous sont celles de vraies réponses GoTrue, réduites aux champs
/// qu'on lit. C'est volontaire : un décodeur testé contre un JSON inventé passe, et casse en
/// production sur un champ qu'on n'avait pas vu.
final class AuthDecodingTests: XCTestCase {
    private let tokenPayload = """
    {
      "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.payload.signature",
      "token_type": "bearer",
      "expires_in": 3600,
      "expires_at": 1787652584,
      "refresh_token": "sq3l4k5j6h7g8f9d",
      "user": {
        "id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
        "aud": "authenticated",
        "role": "authenticated",
        "email": "eleve@micabo.app",
        "app_metadata": { "provider": "google", "providers": ["google"] },
        "user_metadata": { "name": "Camille Lefèvre", "email_verified": true },
        "created_at": "2026-08-25T09:00:00Z"
      }
    }
    """

    func testASessionIsReadFromWhatGoTrueReturns() throws {
        let response = try JSONDecoder().decode(AuthTokenResponse.self, from: Data(tokenPayload.utf8))

        XCTAssertEqual(response.refreshToken, "sq3l4k5j6h7g8f9d")
        XCTAssertEqual(response.user.email, "eleve@micabo.app")
        XCTAssertEqual(response.user.displayName, "Camille Lefèvre")
    }

    /// L'échéance est calculée à la réception, pas relue dans le jeton : décoder un JWT pour
    /// connaître sa date d'expiration demanderait de faire confiance à un contenu non vérifié.
    func testTheExpiryIsComputedOnArrival() throws {
        let response = try JSONDecoder().decode(AuthTokenResponse.self, from: Data(tokenPayload.utf8))
        let now = Date(timeIntervalSince1970: 1_787_649_000)

        let session = response.session(now: now)

        XCTAssertEqual(session.expiresAt, now.addingTimeInterval(3600))
        XCTAssertFalse(session.isExpired)
    }

    /// On rafraîchit **avant** l'échéance : un jeton qui expire pendant l'appel qu'il autorise
    /// produit une erreur que l'utilisateur ne peut pas comprendre.
    func testASessionAboutToExpireIsAlreadyConsideredExpired() {
        let session = AuthSession(
            accessToken: "a",
            refreshToken: "b",
            expiresAt: Date().addingTimeInterval(AuthSession.renewalMargin - 10),
            user: AuthUser(id: UUID(), email: nil, displayName: nil)
        )

        XCTAssertTrue(session.isExpired)
    }

    /// Chaque fournisseur nomme le champ à sa façon, et une inscription par courriel n'en
    /// envoie aucun.
    func testTheNameIsFoundWhateverTheProviderCallsIt() throws {
        func user(metadata: String) throws -> AuthUser {
            let payload = """
            {"id":"7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B","email":"lea@micabo.app","user_metadata":\(metadata)}
            """
            return try JSONDecoder().decode(AuthUser.self, from: Data(payload.utf8))
        }

        XCTAssertEqual(try user(metadata: #"{"full_name":"Léa Martin"}"#).displayName, "Léa Martin")
        XCTAssertEqual(try user(metadata: #"{"name":"Léa Martin"}"#).displayName, "Léa Martin")
        XCTAssertNil(try user(metadata: "{}").displayName)
        // Sans nom, on montre la partie gauche de l'adresse : jamais l'identifiant, dans
        // lequel personne ne se reconnaît.
        XCTAssertEqual(try user(metadata: "{}").label, "lea")
    }

    func testAnUnreadableIdentifierIsRefusedRatherThanInvented() {
        let payload = #"{"id":"pas-un-uuid","email":"a@micabo.app"}"#

        XCTAssertThrowsError(try JSONDecoder().decode(AuthUser.self, from: Data(payload.utf8)))
    }

    /// Annuler une connexion n'est pas une panne : l'écran ne doit rien afficher.
    func testCancellingSaysNothing() {
        XCTAssertNil(AuthError.cancelled.errorDescription)
        XCTAssertNotNil(AuthError.invalidCredentials.errorDescription)
        XCTAssertNotNil(AuthError.emailNotConfirmed.errorDescription)
    }

    /// Le schéma de retour est écrit à deux endroits, l'`Info.plist` et le code. S'ils
    /// divergent, la connexion Google échoue à son retour et rien ne le dit.
    func testTheCallbackSchemeMatchesTheBundle() {
        XCTAssertEqual(AuthRedirect.url.absoluteString, "micabo://auth-callback")

        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(
            schemes.contains(AuthRedirect.scheme),
            "Le schéma \(AuthRedirect.scheme) doit être déclaré dans l'Info.plist"
        )
    }
}

/// Ce qui monte dans le cloud, et ce qui en redescend.
final class CloudRecordTests: XCTestCase {
    /// **Le test qui compte.** La fiche est déjà du JSON sur l'appareil : elle traverse la
    /// synchro sans être interprétée, précisément pour ne rien pouvoir perdre. Si ce test
    /// tombe, des fiches se dégradent à chaque synchronisation sans que personne le voie.
    func testTheSheetCrossesTheSyncUntouched() throws {
        let sheet = SampleData.photosynthesisSheet.sanitized()
        let data = try XCTUnwrap(sheet.encoded())
        let carried = try XCTUnwrap(JSONCodable(data: data))

        struct Row: Codable { var sheet: JSONCodable? }
        let encoded = try JSONEncoder().encode(Row(sheet: carried))
        let decoded = try JSONDecoder().decode(Row.self, from: encoded)
        let restored = try XCTUnwrap(CourseSheet.decode(from: decoded.sheet?.data))

        XCTAssertEqual(restored.blocks.count, sheet.blocks.count)
        XCTAssertEqual(restored, sheet, "Un aller-retour dans le cloud ne doit rien changer à la fiche")
        // Le surlignage est du texte : c'est lui qu'un encodage bavard abîmerait le premier.
        XCTAssertTrue(restored.plainText().contains("dioxygène"))
    }

    func testABrokenSheetIsNeverSentToTheServer() {
        XCTAssertNil(JSONCodable(data: nil))
        XCTAssertNil(JSONCodable(data: Data()))
        XCTAssertNil(JSONCodable(data: Data("pas du json".utf8)))
    }

    /// Le profil est ce qui fait qu'une réinstallation retrouve un étudiant en santé en
    /// Belgique, et non un lycéen français par défaut.
    func testTheProfileGoesBothWays() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let payload = """
        {
          "id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
          "display_name": "Camille",
          "study_level": "sante",
          "country_code": "be",
          "learning_goals": ["exam"],
          "subjects": ["Médecine"],
          "institution_name": "ULB",
          "daily_minutes": 30,
          "sheet_length": "deep"
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let profile = try decoder.decode(ProfileRecord.self, from: Data(payload.utf8))

        profile.applyToLocalPreferences()

        XCTAssertEqual(OnboardingPreferences.studyLevel, .sante)
        XCTAssertEqual(OnboardingPreferences.schoolingCountry, .be)
        // Le cloud ne transporte que le registre d'écriture, pas le nom du palier : c'est
        // volontaire, il n'y a pas de colonne à ajouter, et le palier se retrouve dans les
        // termes du pays. Un étudiant en santé en Belgique lit « Médecine, santé », pas
        // « PASS, santé ».
        XCTAssertEqual(OnboardingPreferences.educationStage?.id, "be.medecine")
        XCTAssertEqual(OnboardingPreferences.contentLanguage, .fr)
        XCTAssertEqual(OnboardingPreferences.dailyMinutes, 30)
        XCTAssertEqual(OnboardingPreferences.subjects, ["Médecine"])
        XCTAssertEqual(SheetPreferences.length, .deep)

        let sent = ProfileRecord.fromLocalPreferences(userID: profile.id, displayName: "Camille")

        XCTAssertEqual(sent.study_level, "sante")
        XCTAssertEqual(sent.country_code, "be")
        XCTAssertEqual(sent.sheet_length, "deep")
    }
}
