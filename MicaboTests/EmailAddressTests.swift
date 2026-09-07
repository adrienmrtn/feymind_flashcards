import XCTest
@testable import Micabo

/// Le pendant de `web/lib/auth/email.test.ts` : les deux plateformes doivent trier les
/// adresses de la même façon, sinon un rebond passe par celle qui a été oubliée.
final class EmailAddressTests: XCTestCase {
    func testAnAddressIsStoredTheWayGoTrueStoresIt() {
        XCTAssertEqual(EmailAddress.normalize("  Eleve@Gmail.COM "), "eleve@gmail.com")
        XCTAssertEqual(EmailAddress.normalize(nil), "")
    }

    func testAnOrdinaryAddressGoesThrough() {
        XCTAssertEqual(EmailAddress.inspect("eleve@gmail.com"), .ok("eleve@gmail.com"))
        XCTAssertEqual(EmailAddress.inspect("  Eleve.Martin@Orange.fr  "), .ok("eleve.martin@orange.fr"))
    }

    func testASchoolDomainWeDoNotKnowGoesThrough() {
        XCTAssertTrue(EmailAddress.isSendable("p.martin@ac-versailles.fr"))
        XCTAssertTrue(EmailAddress.isSendable("ogrenci@bogazici.edu.tr"))
        XCTAssertTrue(EmailAddress.isSendable("eleve@lycee-carnot.education"))
    }

    func testWhatGoTrueWouldRefuseIsRefusedHere() {
        for bad in [
            "", "   ", "eleve", "@gmail.com", "eleve@", "eleve@lycee", "eleve@.fr",
            "eleve@lycee.", "eleve@lycee..fr", "eleve @gmail.com", "eleve@gmail com",
            "deux@arobases@gmail.com", ".eleve@gmail.com", "eleve.@gmail.com",
            "el..eve@gmail.com", "eleve@-gmail.com", "eleve@gmail-.com",
            "eleve@gmail.c", "eleve@gmail.c0m",
        ] {
            XCTAssertEqual(EmailAddress.inspect(bad), .malformed, bad)
        }
    }

    func testReservedDomainsNeverReceive() {
        for reserved in [
            "essai.web@micabo.test",
            "quelquun@example.com",
            "quelquun@example.org",
            "moi@monsite.invalid",
            "root@machine.localhost",
            "imprimante@bureau.local",
            "service@cluster.internal",
        ] {
            XCTAssertEqual(EmailAddress.inspect(reserved), .undeliverable, reserved)
        }
    }

    func testTwoSwappedLettersGetTheRightBoxProposed() {
        XCTAssertEqual(
            EmailAddress.inspect("eleve@gmial.com"),
            .suspicious(address: "eleve@gmial.com", suggestion: "eleve@gmail.com")
        )
        XCTAssertEqual(
            EmailAddress.inspect("eleve@hotmial.fr"),
            .suspicious(address: "eleve@hotmial.fr", suggestion: "eleve@hotmail.fr")
        )
    }

    func testAMissedExtensionIsRepaired() {
        XCTAssertEqual(suggestion(for: "eleve@gmail.con"), "eleve@gmail.com")
        XCTAssertEqual(suggestion(for: "eleve@gmail.co"), "eleve@gmail.com")
        XCTAssertEqual(suggestion(for: "eleve@orange.fe"), "eleve@orange.fr")
    }

    func testNothingIsProposedForAnAddressThatIsAlreadyRight() {
        for good in [
            "eleve@gmail.com", "eleve@mail.com", "eleve@free.fr", "eleve@gmx.de",
            "eleve@icloud.com", "eleve@yandex.com", "eleve@hotmail.co.uk",
        ] {
            XCTAssertTrue(EmailAddress.isSendable(good), good)
        }
    }

    /// Sur sept caractères, deux lettres d'écart ne sont plus une faute de frappe mais un
    /// autre nom : proposer reviendrait à envoyer le lien chez quelqu'un d'autre.
    func testTheThresholdTightensOnShortDomains() {
        XCTAssertEqual(suggestion(for: "eleve@bree.fr"), "eleve@free.fr")
        XCTAssertTrue(EmailAddress.isSendable("eleve@bnee.fr"))
    }

    func testTwoLettersAreAllowedOnALongDomain() {
        XCTAssertEqual(suggestion(for: "eleve@gmaul.cm"), "eleve@gmail.com")
        XCTAssertEqual(suggestion(for: "eleve@protonmial.com"), "eleve@protonmail.com")
    }

    /// Le champ laisse appuyer sur une adresse douteuse : sans ça, la question
    /// « tu voulais dire … ? » ne s'afficherait jamais.
    func testASuspiciousAddressCanStillBeSubmitted() {
        XCTAssertTrue(EmailAddress.isPlausible("eleve@gmial.com"))
        XCTAssertFalse(EmailAddress.isSendable("eleve@gmial.com"))
        XCTAssertFalse(EmailAddress.isPlausible("eleve@lycee"))
    }

    private func suggestion(for raw: String) -> String? {
        if case .suspicious(_, let corrected) = EmailAddress.inspect(raw) { return corrected }
        return nil
    }
}
