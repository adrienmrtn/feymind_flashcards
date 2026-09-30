import CryptoKit
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
        XCTAssertNotNil(AuthError.sessionExpired.errorDescription)
    }

    /// Le schéma de retour est écrit à deux endroits, l'`Info.plist` et le code. S'ils
    /// divergent, la connexion Google échoue à son retour et rien ne le dit.
    func testAPlausibleEmailHasALocalPartAndADottedDomain() {
        XCTAssertTrue(EmailAddress.isPlausible("eleve@lycee.fr"))
        XCTAssertTrue(EmailAddress.isPlausible("  eleve@lycee.fr  "))
        XCTAssertFalse(EmailAddress.isPlausible(""))
        XCTAssertFalse(EmailAddress.isPlausible("eleve"))
        XCTAssertFalse(EmailAddress.isPlausible("@lycee.fr"))
        XCTAssertFalse(EmailAddress.isPlausible("eleve@lycee"))
        XCTAssertFalse(EmailAddress.isPlausible("eleve@.fr"))
    }

    func testTheCallbackSchemeMatchesTheBundle() {
        XCTAssertEqual(AuthRedirect.url.absoluteString, "micabo://auth-callback")

        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let schemes = types.flatMap { ($0["CFBundleURLSchemes"] as? [String]) ?? [] }
        XCTAssertTrue(
            schemes.contains(AuthRedirect.scheme),
            "Le schéma \(AuthRedirect.scheme) doit être déclaré dans l'Info.plist"
        )
    }

    // MARK: - Le nonce Apple

    /// Un jeton d'identité au format d'Apple : en-tête, charge utile, signature.
    private func appleToken(_ claims: [String: Any]) throws -> String {
        let payload = try JSONSerialization.data(withJSONObject: claims).base64URLEncodedString()
        return "eyJraWQiOiJXNldjT0tCIiwiYWxnIjoiUlMyNTYifQ.\(payload).c2lnbmF0dXJl"
    }

    /// **Le cas qui faisait `Nonces mismatch`.** Un geste, deux requêtes ; la première
    /// revient en erreur sans jeton, la seconde avec. Le clair présenté doit être celui dont
    /// le jeton porte l'empreinte, quel que soit l'ordre des retours.
    func testTheTokenLeadsBackToTheNonceOfItsOwnRequest() throws {
        var ledger = AppleNonceLedger()
        let first = ledger.issue()
        let second = ledger.issue()

        let token = try appleToken(["iss": "https://appleid.apple.com", "nonce": first])
        let hashed = try XCTUnwrap(AppleIdentityToken.nonce(in: token))
        let raw = try XCTUnwrap(ledger.redeem(hashed: hashed))

        let rehashed = SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(rehashed, first)
        XCTAssertNotEqual(rehashed, second)
    }

    /// Un nonce ne sert qu'une fois, et une empreinte inconnue ne rend rien.
    func testANonceIsRedeemedOnce() {
        var ledger = AppleNonceLedger()
        let hashed = ledger.issue()

        XCTAssertNotNil(ledger.redeem(hashed: hashed))
        XCTAssertNil(ledger.redeem(hashed: hashed))
        XCTAssertNil(ledger.redeem(hashed: "inconnue"))
    }

    /// Le registre ne grossit pas : au-delà de sa capacité, le plus ancien part.
    func testTheLedgerForgetsTheOldestNonce() {
        var ledger = AppleNonceLedger()
        let oldest = ledger.issue()
        let kept = (0..<AppleNonceLedger.capacity).map { _ in ledger.issue() }

        XCTAssertNil(ledger.redeem(hashed: oldest))
        XCTAssertNotNil(ledger.redeem(hashed: kept[0]))
    }

    /// La charge utile se lit quelle que soit sa longueur (le base64 d'un JWT n'a pas de
    /// `=`), et un jeton sans nonce ou mal formé ne rend rien plutôt qu'une empreinte fausse.
    func testTheNonceIsReadFromTheTokenPayload() throws {
        for nonce in ["a", "ab", "abc", "abcd", AppleNonce().hashed] {
            let token = try appleToken(["nonce": nonce])
            XCTAssertEqual(AppleIdentityToken.nonce(in: token), nonce)
        }
        let withoutNonce = try appleToken(["iss": "https://appleid.apple.com"])
        XCTAssertNil(AppleIdentityToken.nonce(in: withoutNonce))
        XCTAssertNil(AppleIdentityToken.nonce(in: "pas.un-jeton"))
        XCTAssertNil(AppleIdentityToken.nonce(in: "a.%%%.c"))
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

    func testJSONValueBuildsFromASerializedObjectWithoutASecondEncode() throws {
        let object: [String: Any] = ["ok": true, "n": 2, "s": "fiche"]
        let value = try XCTUnwrap(JSONValue(jsonObject: object))
        guard case .object(let fields) = value else {
            return XCTFail("L'objet JSON doit rester un objet")
        }
        XCTAssertEqual(fields["s"]?.stringValue, "fiche")
        if case .bool(let flag) = fields["ok"] {
            XCTAssertTrue(flag)
        } else {
            XCTFail("Un booléen JSONSerialization doit rester un booléen")
        }
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
        // La langue ne monte que si elle a été choisie à la main : celle du pays reste
        // implicite, sinon elle redescendait épinglée et un changement de pays n'y
        // changeait plus rien.
        XCTAssertNil(sent.sheet_language)
        XCTAssertNotEqual(sent.signature, "")
    }

    /// Un profil distant sans langue explicite efface celle qui était posée ici : la
    /// langue des fiches redevient celle du pays.
    func testAProfileWithoutASheetLanguageClearsTheLocalOne() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        OnboardingPreferences.sheetLanguage = .pl
        let payload = """
        {
          "id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
          "country_code": "de",
          "learning_goals": [],
          "subjects": [],
          "daily_minutes": 20,
          "sheet_length": "standard"
        }
        """
        let profile = try JSONDecoder().decode(ProfileRecord.self, from: Data(payload.utf8))
        profile.applyToLocalPreferences()

        XCTAssertNil(OnboardingPreferences.sheetLanguage)
        XCTAssertEqual(OnboardingPreferences.contentLanguage, .de)
    }

    /// L'empreinte change avec le pays : c'est elle qui protège un réglage changé ici
    /// contre le profil de la veille qui redescend.
    func testTheProfileSignatureFollowsTheCountry() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let id = UUID()
        OnboardingPreferences.schoolingCountry = .fr
        let before = ProfileRecord.fromLocalPreferences(userID: id, displayName: nil).signature
        OnboardingPreferences.schoolingCountry = .de
        let after = ProfileRecord.fromLocalPreferences(userID: id, displayName: nil).signature

        XCTAssertNotEqual(before, after)
    }

    /// Une langue de fiche posée sur le web doit revenir sur le téléphone, même si
    /// le pays dirait autre chose.
    func testTheSheetLanguageComesBackWithTheProfile() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let payload = """
        {
          "id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
          "country_code": "fr",
          "learning_goals": [],
          "subjects": [],
          "daily_minutes": 20,
          "sheet_length": "standard",
          "sheet_language": "pl"
        }
        """

        let profile = try JSONDecoder().decode(ProfileRecord.self, from: Data(payload.utf8))
        profile.applyToLocalPreferences()

        XCTAssertEqual(OnboardingPreferences.sheetLanguage, .pl)
        XCTAssertEqual(OnboardingPreferences.contentLanguage, .pl)
    }

    /// `deleted_at: null` ressusciterait une carte tombstonée sur le web. On l'omet.
    func testALiveCardDoesNotSendDeletedAt() throws {
        let record = try decodeCard("""
        {
          "id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
          "user_id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
          "front": "Q",
          "back": "A",
          "position": 0,
          "kind": "basic",
          "choices": [],
          "correct_choice_index": 0,
          "mask_x": 0, "mask_y": 0, "mask_width": 0, "mask_height": 0,
          "is_reversed": false,
          "is_suspended": false,
          "state": "new",
          "due_date": "2026-08-28T10:00:00Z",
          "interval_days": 0,
          "ease_factor": 2.5,
          "repetitions": 0,
          "lapses": 0,
          "step_index": 0,
          "created_at": "2026-08-28T10:00:00Z",
          "updated_at": "2026-08-28T10:00:00Z"
        }
        """)

        let json = String(data: try JSONEncoder().encode(record), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("deleted_at"), "Un null ressuscite la ligne côté Postgres")
        XCTAssertFalse(json.contains("image_path"))
    }

    /// **Le 400 du 29 septembre.** Une carte avec indice et une carte sans ne portent pas les
    /// mêmes clés, et PostgREST refuse en entier un tableau aux clés inégales
    /// (`PGRST102 All object keys must match`). Elles partent donc en deux envois, chacun
    /// uniforme, dans l'ordre où elles apparaissent.
    func testCardsWithAndWithoutHintLeaveInUniformBatches() throws {
        let card = """
        {
          "id": "%@",
          "user_id": "7F9C2B41-3D5E-4A6F-8B12-9C0D1E2F3A4B",
          "front": "Q", "back": "A", %@
          "position": 0, "kind": "basic", "choices": [], "correct_choice_index": 0,
          "mask_x": 0, "mask_y": 0, "mask_width": 0, "mask_height": 0,
          "is_reversed": false, "is_suspended": false, "state": "new",
          "due_date": "2026-08-28T10:00:00Z", "interval_days": 0, "ease_factor": 2.5,
          "repetitions": 0, "lapses": 0, "step_index": 0,
          "created_at": "2026-08-28T10:00:00Z", "updated_at": "2026-08-28T10:00:00Z"
        }
        """
        let hinted = try decodeCard(String(format: card, UUID().uuidString, "\"hint\": \"Un indice\","))
        let plain = try decodeCard(String(format: card, UUID().uuidString, ""))
        let other = try decodeCard(String(format: card, UUID().uuidString, "\"hint\": \"Un autre\","))

        let database = SupabaseDatabase(accessToken: { nil })
        let batches = try database.uniformBatches([hinted, plain, other])

        XCTAssertEqual(batches.count, 2)
        let rows = try batches.map { try XCTUnwrap(JSONSerialization.jsonObject(with: $0) as? [[String: Any]]) }
        XCTAssertEqual(rows.map(\.count), [2, 1], "Les cartes à indice ensemble, d'abord")
        for batch in rows {
            let keys = batch.map { Set($0.keys) }
            XCTAssertEqual(Set(keys).count, 1, "Un envoi dont les lignes n'ont pas les mêmes clés serait refusé")
        }
        XCTAssertTrue(rows[0].allSatisfy { $0["hint"] != nil })
        XCTAssertTrue(rows[1].allSatisfy { $0["hint"] == nil })
    }

    /// Des lignes toutes pareilles partent en un seul envoi, et rien ne part pour rien.
    func testUniformRowsStayInOneBatch() throws {
        let database = SupabaseDatabase(accessToken: { nil })
        XCTAssertEqual(try database.uniformBatches([["a": 1], ["a": 2], ["a": 3]]).count, 1)
        XCTAssertTrue(try database.uniformBatches([[String: Int]]()).isEmpty)
    }

    func testAnOcclusionImageTravelsAsADataURL() {
        let bytes = Data([0xFF, 0xD8, 0xFF, 0x01, 0x02])
        XCTAssertEqual(CloudImage.data(from: CloudImage.dataURL(from: bytes)), bytes)
        XCTAssertNil(CloudImage.dataURL(from: Data()))
        XCTAssertNil(CloudImage.data(from: "/storage/occlusions/a.jpg"))
    }

    func testATombstoneBlocksResurrection() {
        let suite = "micabo.tests.tombstones.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        CloudTombstones.defaults = defaults
        defer {
            CloudTombstones.defaults = .standard
            defaults.removePersistentDomain(forName: suite)
        }

        let id = UUID()
        XCTAssertFalse(CloudTombstones.contains(CloudTable.flashcards, id: id))
        CloudTombstones.mark(CloudTable.flashcards, id: id)
        XCTAssertTrue(CloudTombstones.contains(CloudTable.flashcards, id: id))
        XCTAssertEqual(CloudTombstones.all()[CloudTable.flashcards], [id])
    }

    func testALiveExamOmitsDeletedAtAndCarriesTheBackup() throws {
        let backup = try XCTUnwrap(JSONCodable(data: Data(#"{"entries":[]}"#.utf8)))
        let record = ExamRecord(
            id: UUID(),
            user_id: UUID(),
            name: "Partiel",
            exam_date: Date(timeIntervalSince1970: 1_787_649_000),
            intensity: "standard",
            target_score: 15,
            course_ids: [],
            is_planned: true,
            planned_at: nil,
            created_at: Date(timeIntervalSince1970: 1_787_649_000),
            updated_at: Date(timeIntervalSince1970: 1_787_649_000),
            deleted_at: nil,
            schedule_backup: backup
        )

        let json = String(data: try JSONEncoder().encode(record), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("deleted_at"))
        XCTAssertTrue(json.contains("schedule_backup"))
    }

    private func decodeCard(_ payload: String) throws -> FlashcardRecord {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(FlashcardRecord.self, from: Data(payload.utf8))
    }
}
