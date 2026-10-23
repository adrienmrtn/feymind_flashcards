import XCTest
@testable import Micabo

/// **Les correctifs de l'audit du 23 octobre 2026**, chacun par la règle qu'il pose.
///
/// Ce sont des règles pures - un drapeau, une issue d'achat, un jeton, un écho - testées sans
/// réseau ni boutique : c'est ce qui permet de les tenir en CI alors que le reste du chemin
/// (Supabase, RevenueCat) ne tourne que sur un vrai téléphone.
final class AuditFixesTests: XCTestCase {
    // MARK: - L'examen blanc offert

    /// Une copie vide est une génération ratée : elle ne coûte pas l'examen offert.
    func testAnEmptyPaperDoesNotConsumeTheFreeMock() {
        XCTAssertFalse(ExamAllowance.consumesFreeMock(isPro: false, questionCount: 0))
        XCTAssertTrue(ExamAllowance.consumesFreeMock(isPro: false, questionCount: 12))
        XCTAssertFalse(ExamAllowance.consumesFreeMock(isPro: true, questionCount: 12))
    }

    // MARK: - L'achat en attente

    /// Un achat qui attend une validation n'est pas une fermeture : le cadeau ne tombe pas.
    func testAPendingPurchaseIsNotADismissal() {
        XCTAssertFalse(PaywallOutcome.pending.countsAsDismissal)
        XCTAssertFalse(PaywallOutcome.purchased.countsAsDismissal)
        XCTAssertTrue(PaywallOutcome.cancelled.countsAsDismissal)
        XCTAssertTrue(PaywallOutcome.unavailable.countsAsDismissal)
    }

    func testThePendingMessageIsTranslatedEverywhere() {
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            XCTAssertNotNil(table["ios.paywallPending"], locale.rawValue)
            XCTAssertNotNil(table["ios.paywallPendingTitle"], locale.rawValue)
        }
    }

    // MARK: - Aucun rappel de fin d'essai

    /// L'app n'envoie aucun rappel de fin d'essai : aucune phrase de l'accueil ne doit en
    /// promettre un, dans aucune langue.
    func testTheTrialScreensPromiseNoReminder() {
        let keys = ["ios.trialReminder", "ios.trialDay2", "ios.trialDay2Detail"]
        let promises = ["rappel", "notification", "reminder", "erinnerung", "mitteilung", "recordatorio", "aviso", "hatırlatma", "bildirim"]
        for locale in [UiLocale.fr, .en, .de, .es, .tr] {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                let text = (table[key] ?? "").lowercased()
                XCTAssertFalse(text.isEmpty, "\(locale.rawValue) \(key)")
                for word in promises {
                    XCTAssertFalse(text.contains(word), "\(locale.rawValue) \(key) promet encore : \(word)")
                }
            }
            XCTAssertNil(table["ios.trialReminder.cardTitle"], locale.rawValue)
        }
        let french = L10n.t("ios.trialReminder", locale: .fr, vars: ["n": "3", "price": "49,99 €"])
        XCTAssertTrue(french.contains("49,99 €"))
        XCTAssertTrue(french.contains("3 jours"))
    }

    // MARK: - La réclamation de l'invité

    private func isolatedDefaults() -> UserDefaults {
        let name = "AuditFixesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    func testAClaimTokenLivesLessThanADay() {
        let previous = GuestClaimStore.defaults
        GuestClaimStore.defaults = isolatedDefaults()
        defer { GuestClaimStore.defaults = previous }

        let guest = UUID()
        let token = UUID()
        let created = Date(timeIntervalSince1970: 1_800_000_000)
        GuestClaimStore.save(token: token, guestID: guest, now: created)

        XCTAssertEqual(GuestClaimStore.validToken(for: guest, now: created.addingTimeInterval(3600)), token)
        XCTAssertNil(GuestClaimStore.validToken(for: UUID(), now: created), "un jeton ne sert qu'à son invité")
        XCTAssertNil(GuestClaimStore.validToken(for: guest, now: created.addingTimeInterval(24 * 3600)))
        XCTAssertNil(GuestClaimStore.claim, "un jeton expiré est oublié")
    }

    /// Un invité qui a monté des lignes est à réclamer ; le compte lui-même ne l'est jamais.
    func testOnlyAGuestWithRowsIsPending() {
        let previous = GuestClaimStore.defaults
        GuestClaimStore.defaults = isolatedDefaults()
        defer { GuestClaimStore.defaults = previous }

        let guest = UUID()
        let account = UUID()
        XCTAssertNil(GuestClaimStore.pendingGuest(current: guest, account: account))
        GuestClaimStore.noteRows(of: guest)
        XCTAssertEqual(GuestClaimStore.pendingGuest(current: guest, account: account), guest)
        XCTAssertNil(GuestClaimStore.pendingGuest(current: account, account: account))
        GuestClaimStore.clear()
        XCTAssertNil(GuestClaimStore.pendingGuest(current: guest, account: account))
    }

    /// PostgREST rend un `uuid` en chaîne JSON nue.
    func testTheClaimTokenIsReadFromAJSONString() {
        let token = UUID()
        XCTAssertEqual(GuestClaimStore.parseToken(Data("\"\(token.uuidString.lowercased())\"".utf8)), token)
        XCTAssertEqual(GuestClaimStore.parseToken(Data(token.uuidString.utf8)), token)
        XCTAssertNil(GuestClaimStore.parseToken(Data("{}".utf8)))
    }

    // MARK: - Les échos de la montée

    func testOurOwnWriteIsRecognizedOnTheWayBack() {
        let id = UUID()
        let stamp = Date(timeIntervalSince1970: 1_800_000_000.123)
        var echoes = PushEchoes()
        echoes.record([SupabaseDatabase.RowStamp(id: id, updated_at: stamp)], in: CloudTable.chapters)

        XCTAssertTrue(echoes.isEcho(CloudTable.chapters, id: id, updatedAt: stamp))
        XCTAssertFalse(echoes.isEcho(CloudTable.chapters, id: id, updatedAt: stamp.addingTimeInterval(1)), "un autre appareil a écrit après nous")
        XCTAssertFalse(echoes.isEcho(CloudTable.courses, id: id, updatedAt: stamp))

        echoes.prune(now: stamp.addingTimeInterval(3 * 24 * 3600))
        XCTAssertFalse(echoes.isEcho(CloudTable.chapters, id: id, updatedAt: stamp))
    }

    /// Un thème prêt ne recule jamais par la descente ; « en préparation » ne s'atteint pas.
    func testAThemeNeverGoesBackToPendingFromTheServer() {
        XCTAssertFalse(CloudSync.acceptsRemoteStatus(.pending, over: .ready))
        XCTAssertFalse(CloudSync.acceptsRemoteStatus(.failed, over: .ready))
        XCTAssertFalse(CloudSync.acceptsRemoteStatus(.pending, over: .failed))
        XCTAssertTrue(CloudSync.acceptsRemoteStatus(.ready, over: .pending))
        XCTAssertTrue(CloudSync.acceptsRemoteStatus(.failed, over: .pending))
        XCTAssertTrue(CloudSync.acceptsRemoteStatus(.ready, over: .failed))
    }

    // MARK: - Les refus du serveur durci

    func testTheLessonGateRefusalsAreRead() {
        let unknown = SupabaseFunctionError.server(status: 409, message: "Ce cours n'est pas encore synchronisé. Réessaie dans un instant.", code: "course_unknown")
        XCTAssertEqual(LessonServiceError.from(unknown), .courseUnknown)
        XCTAssertFalse(LessonServiceError.courseUnknown.opensPaywall)

        let anonymous = SupabaseFunctionError.server(status: 401, message: "Mets Micabo à jour, ou connecte-toi, pour continuer : cette version n'est plus prise en charge.", code: nil)
        XCTAssertEqual(LessonServiceError.from(anonymous), .accountRequired)

        let gate = LessonServiceError.from(SupabaseFunctionError.server(status: 503, message: "La vérification de ton accès est temporairement indisponible. Réessaie.", code: nil))
        XCTAssertTrue(gate.isWorthRetrying, "une porte muette se retente")
        XCTAssertEqual(gate.analyticsReason, "unavailable")
    }

    func testGeneratingACourseWithoutProOpensThePaywall() {
        let refusal = SupabaseFunctionError.server(status: 402, message: "Générer un cours, c'est avec Micabo Pro.", code: "pro_required")
        let error = AIServiceError(refusal)
        guard case .proRequired = error else { return XCTFail("attendu : proRequired, reçu \(error)") }
        XCTAssertFalse(error.allowsOfflineFallback, "un refus Pro ne se contourne pas par une fiche hors ligne")
    }

    func testReadingAVideoWithoutProIsAnImportRefusal() {
        let refusal = SupabaseFunctionError.server(status: 402, message: "Importer une vidéo, c'est avec Micabo Pro.", code: "import_pro")
        XCTAssertEqual(YouTubeImportError(refusal), .importPro)
        XCTAssertFalse(YouTubeImportError.importPro.allowsRetry)
    }
}
