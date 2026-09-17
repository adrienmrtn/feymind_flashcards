import XCTest
@testable import Micabo

/// **Ce que les statistiques doivent tenir, et qui se perdrait sans bruit.**
///
/// Un traceur cassé ne casse rien : l'écran s'affiche, le bouton répond, et la courbe est
/// plate. C'est la panne la plus difficile à voir, et c'est pour ça que ces règles-là sont
/// vérifiées plutôt que relues.
final class AnalyticsTests: XCTestCase {
    /// **Chaque nom doit passer la contrainte de `app_events`.**
    ///
    /// Recopiée de `supabase/migrations/20260917220000_app_events.sql`. Un nom refusé ferait
    /// rejeter le **lot entier** par Postgres — donc les dix-neuf autres événements avec lui
    /// — et l'app ne le dirait pas, puisqu'elle ne dit jamais rien d'un envoi raté.
    func testEveryNamePassesTheTableConstraint() throws {
        let pattern = try NSRegularExpression(pattern: "^[a-z][a-z0-9_]{1,46}[a-z0-9]$")

        for event in AnalyticsEvent.allCases {
            let name = event.rawValue
            let range = NSRange(name.startIndex..., in: name)
            XCTAssertNotNil(
                pattern.firstMatch(in: name, range: range),
                "« \(name) » serait refusé par la contrainte de la table"
            )
        }
    }

    /// Deux événements qui partagent un nom font une courbe qui additionne deux gestes.
    func testTheNamesAreDistinct() {
        let names = AnalyticsEvent.allCases.map(\.rawValue)
        XCTAssertEqual(names.count, Set(names).count)
    }

    /// **Un entier reste un entier.** `"index": 3` doit donner `3`, pas `3.0` : un tableau de
    /// bord qui groupe sur `3` et sur `3.0` montre deux colonnes pour un seul écran.
    func testAWholeNumberStaysWhole() throws {
        let json = try encode(["index": 3, "ratio": 0.5, "on": true, "mot": "bonjour"])

        XCTAssertTrue(json.contains("\"index\":3"), json)
        XCTAssertFalse(json.contains("3.0"), json)
        XCTAssertTrue(json.contains("\"ratio\":0.5"), json)
        XCTAssertTrue(json.contains("\"on\":true"), json)
        XCTAssertTrue(json.contains("\"mot\":\"bonjour\""), json)
    }

    /// Une étiquette bavarde est coupée ici plutôt que de faire refuser la ligne entière
    /// par le plafond de deux mille caractères de la colonne.
    func testALongLabelIsCutShort() throws {
        let json = try encode(["texte": .text(String(repeating: "a", count: 400))])

        XCTAssertLessThan(json.count, 200)
        XCTAssertTrue(json.contains(String(repeating: "a", count: 120)))
        XCTAssertFalse(json.contains(String(repeating: "a", count: 121)))
    }

    /// La file survit à une app tuée : c'est l'aller-retour par le disque qui la ramène,
    /// et il doit rendre exactement ce qu'on avait posé.
    func testTheQueueSurvivesTheDisk() throws {
        let row = AnalyticsRow(
            deviceID: UUID(),
            sessionID: UUID(),
            name: AnalyticsEvent.paywallOpened.rawValue,
            props: ["trigger": "lockedSheet", "index": 4, "pro": false],
            country: "FR",
            schoolCountry: "fr",
            locale: "fr_FR",
            platform: "ios",
            appVersion: "1.0+1",
            build: "debug",
            isPro: false,
            occurredAt: Date(timeIntervalSince1970: 1_789_680_000)
        )

        let data = try JSONEncoder.analytics.encode([row])
        let back = try JSONDecoder.analytics.decode([AnalyticsRow].self, from: data)

        XCTAssertEqual(back.count, 1)
        XCTAssertEqual(back[0].name, row.name)
        XCTAssertEqual(back[0].deviceID, row.deviceID)
        XCTAssertEqual(back[0].props.count, 3)
        XCTAssertEqual(back[0].occurredAt.timeIntervalSince1970, row.occurredAt.timeIntervalSince1970, accuracy: 1)
    }

    /// **Les noms des colonnes voyagent en clair.** Une clé mal orthographiée fait rejeter
    /// le lot avec un message de PostgREST que personne ne lit jamais.
    func testTheRowCarriesTheColumnNames() throws {
        let row = AnalyticsRow(
            deviceID: UUID(),
            sessionID: UUID(),
            name: "app_opened",
            props: [:],
            country: "DE",
            schoolCountry: "de",
            locale: "de_DE",
            platform: "ios",
            appVersion: "1.0",
            build: "release",
            isPro: true,
            occurredAt: Date()
        )

        let json = String(data: try JSONEncoder.analytics.encode(row), encoding: .utf8) ?? ""

        for column in ["device_id", "session_id", "school_country", "app_version", "is_pro", "occurred_at"] {
            XCTAssertTrue(json.contains("\"\(column)\""), "colonne absente : \(column) — \(json)")
        }
    }

    /// `Locale` sait rendre des régions à trois chiffres (019 pour l'Amérique du Nord) que
    /// la contrainte de la colonne refuse. Mieux vaut une colonne vide qu'un lot rejeté.
    func testOnlyATwoLetterRegionGoesOut() {
        let region = AnalyticsContext.deviceRegion()
        guard let region else { return }

        XCTAssertEqual(region.count, 2)
        XCTAssertEqual(region, region.uppercased())
        XCTAssertTrue(region.allSatisfy(\.isLetter))
    }

    private func encode(_ props: [String: AnalyticsValue]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(data: try encoder.encode(props), encoding: .utf8) ?? ""
    }
}
