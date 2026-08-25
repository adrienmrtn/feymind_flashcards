import Foundation
import SwiftData
import XCTest
@testable import Micabo

/// Le nom d'utilisateur : ce qu'on accepte, ce qu'on met en forme, et ce qu'on refuse.
///
/// Les règles sont écrites deux fois, ici et dans une contrainte de la base
/// (`profiles_username_shape`). Ces tests verrouillent la version de l'app **sur celle de la
/// base** : un nom que l'app accepte et que la base refuse donne un aller-retour pour rien et
/// un message que personne ne comprend.
final class UsernameTests: XCTestCase {
    /// La forme que la base exige, recopiée depuis la migration : au moins trois caractères, au
    /// plus vingt, une lettre ou un chiffre en tête, et ensuite lettres, chiffres, souligné ou
    /// tiret.
    private func matchesDatabaseShape(_ value: String) -> Bool {
        let pattern = "^[a-z0-9][a-z0-9_-]{2,19}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    func testWhatIsTypedIsShapedRatherThanRefused() {
        XCTAssertEqual(Username.normalize("Adrien Martinot"), "adrien-martinot")
        XCTAssertEqual(Username.normalize("Zoé_92"), "zoe_92")
        XCTAssertEqual(Username.normalize("Jean--Pierre"), "jean-pierre")
        XCTAssertEqual(Username.normalize("  marie  "), "marie")
    }

    /// Les accents sont pliés, pas retirés : « Éléonore » doit rester lisible, pas devenir
    /// « lonore ». Et une lettre sans accent à retirer, comme le « ı » turc, obtient quand même
    /// son équivalent ASCII au lieu d'être jetée.
    func testAccentsAreFoldedAndNotDropped() {
        XCTAssertEqual(Username.normalize("Éléonore"), "eleonore")
        XCTAssertEqual(Username.normalize("Çağrı"), "cagri")
    }

    /// Un nom commence par une lettre ou un chiffre, et la base l'exige. Un souligné en tête se
    /// confond avec un nom masqué, et un tiret en tête se lit comme une puce.
    func testItNeverStartsWithASeparator() {
        XCTAssertEqual(Username.normalize("...martin"), "martin")
        XCTAssertEqual(Username.normalize("_martin"), "martin")
        XCTAssertEqual(Username.normalize("-_-martin"), "martin")

        for input in ["...martin", "_martin", "-_-martin", "__abc", "!!!zoe"] {
            let normalized = Username.normalize(input)
            XCTAssertTrue(
                matchesDatabaseShape(normalized),
                "« \(normalized) » doit passer la contrainte de la base"
            )
        }
    }

    func testItIsCutToTwentyCharacters() {
        let long = Username.normalize("Marie-Charlotte de la Fontaine-Dupont")
        XCTAssertEqual(long.count, Username.maximumLength)
        XCTAssertTrue(matchesDatabaseShape(long), "« \(long) » doit passer la contrainte de la base")
    }

    func testEverythingItAcceptsPassesTheDatabaseConstraint() throws {
        let inputs = [
            "Adrien Martinot", "Zoé_92", "abc", "a1_", "Jean--Pierre",
            "Marie-Charlotte de la Fontaine-Dupont", "ÉLÉONORE", "x9"
        ]

        for input in inputs {
            guard case .success(let accepted) = Username.validate(input) else { continue }
            XCTAssertTrue(
                matchesDatabaseShape(accepted),
                "L'app accepte « \(accepted) » que la base refuserait"
            )
        }
    }

    func testWhatCannotBeSavedIsRefusedWithItsReason() {
        XCTAssertEqual(Username.validate(""), .failure(.empty))
        XCTAssertEqual(Username.validate("   "), .failure(.empty))
        XCTAssertEqual(Username.validate("!!!"), .failure(.tooShort))
        XCTAssertEqual(Username.validate("ab"), .failure(.tooShort))
        XCTAssertEqual(Username.validate("x9"), .failure(.tooShort))
    }

    func testTheHandleCarriesItsAtSignExactlyOnce() {
        XCTAssertEqual(Username.display("adrien"), "@adrien")
        XCTAssertEqual(Username.display("@adrien"), "@adrien")
    }
}

/// La visibilité d'un cours : trois valeurs, et le brut qui voyage jusqu'à la base.
final class CourseVisibilityTests: XCTestCase {
    /// Le brut est écrit dans une contrainte de la base (`courses_visibility_values`) : le
    /// renommer ici rendrait toute écriture impossible, sans que rien ne le dise à la
    /// compilation.
    func testTheRawValuesAreTheOnesTheDatabaseAccepts() {
        XCTAssertEqual(CourseVisibility.public.rawValue, "public")
        XCTAssertEqual(CourseVisibility.friends.rawValue, "friends")
        XCTAssertEqual(CourseVisibility.private.rawValue, "private")
        XCTAssertEqual(CourseVisibility.allCases.count, 3)
    }

    /// Le défaut est public, et c'est celui de la base : un cours importé hors ligne, puis
    /// synchronisé, ne doit pas changer de visibilité en route.
    func testTheDefaultIsPublicOnBothSides() {
        XCTAssertEqual(CourseVisibility.standard, .public)
        XCTAssertEqual(Course(title: "Photosynthèse").visibility, .public)
    }

    func testOnlyPrivateStaysOnTheDevice() {
        XCTAssertTrue(CourseVisibility.public.isShared)
        XCTAssertTrue(CourseVisibility.friends.isShared)
        XCTAssertFalse(CourseVisibility.private.isShared)
    }

    func testEveryValueSaysWhoSeesIt() {
        for value in CourseVisibility.allCases {
            XCTAssertFalse(value.title.isEmpty, "\(value) doit avoir un libellé")
            XCTAssertFalse(value.detail.isEmpty, "\(value) doit dire qui voit le cours")
            XCTAssertFalse(value.systemImage.isEmpty, "\(value) doit avoir un symbole")
        }
    }

    /// Une valeur inconnue vient d'un serveur plus récent que l'app. Elle ne doit pas faire
    /// retomber le cours sur « public » : ce serait le pire repli possible pour un réglage de
    /// partage.
    func testAnUnknownRawValueDoesNotOpenTheCourse() {
        let course = Course(title: "Psychanalyse")
        course.visibility = .private
        course.visibilityRaw = "restreint-aux-tuteurs"

        XCTAssertNil(CourseVisibility(rawValue: course.visibilityRaw))
        XCTAssertEqual(course.visibility, .standard, "Le brut inconnu se lit comme le défaut")
    }
}

/// Reprendre le cours de quelqu'un d'autre.
final class SharedCourseAdoptionTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: Course.self,
            Flashcard.self,
            ReviewLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        context = ModelContext(container)
    }

    override func tearDown() {
        context = nil
        container = nil
    }

    /// Le texte est délibérément long : `CourseFingerprint.make` rend une chaîne vide en dessous
    /// de quatre-vingts caractères utiles, et un texte court aurait fait passer le test de la
    /// détection de doublon pour la mauvaise raison.
    private func shared(
        title: String = "Le cycle de l'eau",
        rawText: String = "L'eau change d'état sans jamais quitter la planète, et le cycle est fermé. "
            + "L'évaporation précède la condensation, puis la précipitation referme la boucle."
    ) -> SharedCourseRecord {
        SharedCourseRecord(
            id: UUID(),
            user_id: UUID(),
            title: title,
            subject: "SVT",
            summary: "Les trois temps du cycle.",
            emoji: "💧",
            accent_hex: "2E7D63",
            raw_text: rawText,
            sheet: nil,
            context_text: rawText,
            visibility: "public",
            updated_at: Date()
        )
    }

    /// Un cours repris est **un cours à soi**. L'identifiant local devient la clé primaire
    /// distante : garder celui de l'auteur ferait écrire une ligne qui lui appartient.
    func testAnAdoptedCourseGetsItsOwnIdentity() throws {
        let remote = shared()
        let adopted = try CourseRepository.adopt(remote, from: "camille", in: context)

        XCTAssertNotEqual(adopted.id, remote.id, "L'identifiant de l'auteur ne se recopie pas")
        XCTAssertEqual(adopted.title, remote.title)
        XCTAssertEqual(adopted.source, .library)
        XCTAssertTrue(adopted.isFromLibrary)
    }

    /// **Privé par défaut.** Reprendre un cours ne donne pas le droit de le rediffuser sous son
    /// propre nom : c'est le seul chemin de l'app qui crée un cours non public, et c'est
    /// délibéré.
    func testAnAdoptedCourseIsNotReshared() throws {
        let adopted = try CourseRepository.adopt(shared(), from: "camille", in: context)

        XCTAssertEqual(adopted.visibility, .private)
        XCTAssertFalse(adopted.visibility.isShared)
    }

    /// Le cours dit d'où il vient : c'est ce que son écran affiche en provenance.
    func testItRemembersWhoWroteIt() throws {
        let adopted = try CourseRepository.adopt(shared(), from: "camille", in: context)

        XCTAssertEqual(adopted.sourceFileName, "@camille")
    }

    /// Reprendre deux fois le même cours est le geste le plus facile à faire par erreur : il ne
    /// coûte qu'un appui. L'empreinte le reconnaît, comme pour un import.
    func testTheSameCourseIsRecognizedOnASecondPass() throws {
        let remote = shared()
        XCTAssertNil(CourseRepository.adopted(remote, in: context))

        let adopted = try CourseRepository.adopt(remote, from: "camille", in: context)

        let found = CourseRepository.adopted(remote, in: context)
        XCTAssertEqual(found?.id, adopted.id)
    }

    /// Un cours trop court pour avoir une empreinte se reconnaît par son titre. Sans ce repli,
    /// un paquet de cartes partagé se laissait reprendre indéfiniment, une copie par appui.
    func testACourseTooShortForAFingerprintIsStillRecognized() throws {
        let tiny = shared(title: "Vocabulaire allemand", rawText: "der, die, das")
        XCTAssertTrue(CourseFingerprint.make(from: tiny.raw_text).isEmpty, "Ce texte est trop court pour une empreinte")
        XCTAssertNil(CourseRepository.adopted(tiny, in: context))

        let adopted = try CourseRepository.adopt(tiny, from: "camille", in: context)

        XCTAssertEqual(CourseRepository.adopted(tiny, in: context)?.id, adopted.id)
    }

    /// Deux cours différents ne se confondent pas, même repris à la suite.
    func testTwoDifferentCoursesStayTwoCourses() throws {
        let first = shared(title: "Le cycle de l'eau", rawText: String(repeating: "La condensation referme la boucle. ", count: 4))
        let second = shared(title: "La photosynthèse", rawText: String(repeating: "Les thylakoïdes captent la lumière. ", count: 4))

        let one = try CourseRepository.adopt(first, from: "camille", in: context)
        let two = try CourseRepository.adopt(second, from: "camille", in: context)

        XCTAssertNotEqual(one.id, two.id)
        XCTAssertEqual(CourseRepository.adopted(first, in: context)?.id, one.id)
        XCTAssertEqual(CourseRepository.adopted(second, in: context)?.id, two.id)
    }
}

/// Ce qui part dans un filtre PostgREST.
///
/// La virgule, les parenthèses et le point sont structurels dans la grammaire d'un `or=(…)` :
/// une recherche qui en contient composait un filtre malformé, et le serveur répondait 400 pour
/// une recherche parfaitement valide.
final class LibrarySearchTests: XCTestCase {
    func testAShortNeedleAsksForNothing() {
        XCTAssertNil(SocialService.searchPattern(""))
        XCTAssertNil(SocialService.searchPattern(" "))
        XCTAssertNil(SocialService.searchPattern("a"))
    }

    func testTheValueIsQuotedSoItsPunctuationStaysAValue() throws {
        let pattern = try XCTUnwrap(SocialService.searchPattern("Chapitre 3, suite"))

        XCTAssertTrue(pattern.hasPrefix("\""), "La valeur doit être entre guillemets")
        XCTAssertTrue(pattern.hasSuffix("\""))
        XCTAssertTrue(pattern.contains("Chapitre 3, suite"))
        XCTAssertTrue(pattern.contains("*"), "La recherche reste partielle")
    }

    /// Les jokers de `LIKE` ne se tapent pas volontairement : les laisser passer ferait rendre
    /// toute la bibliothèque à quelqu'un qui cherche « 100_% ».
    func testLikeWildcardsDoNotSurvive() throws {
        let pattern = try XCTUnwrap(SocialService.searchPattern("100_%"))

        XCTAssertFalse(pattern.dropFirst().dropLast().contains("_"))
        XCTAssertFalse(pattern.contains("%"))
    }

    /// Un guillemet dans la recherche fermerait la valeur : il part.
    func testAQuoteCannotCloseTheValueEarly() throws {
        let pattern = try XCTUnwrap(SocialService.searchPattern("le \"cycle\" de l'eau"))
        let inner = pattern.dropFirst().dropLast()

        XCTAssertFalse(inner.contains("\""))
        XCTAssertTrue(inner.contains("cycle"))
    }
}

/// L'état d'une relation, et le fait qu'une ligne d'amitié n'a pas de sens.
final class FriendshipRecordTests: XCTestCase {
    private let me = UUID()
    private let other = UUID()

    func testTheOtherPersonIsFoundFromEitherSide() {
        let iAsked = FriendshipRecord(
            requester_id: me,
            addressee_id: other,
            status: FriendshipRecord.pending,
            created_at: nil,
            responded_at: nil
        )
        let theyAsked = FriendshipRecord(
            requester_id: other,
            addressee_id: me,
            status: FriendshipRecord.accepted,
            created_at: nil,
            responded_at: nil
        )

        XCTAssertEqual(iAsked.other(than: me), other)
        XCTAssertEqual(theyAsked.other(than: me), other)
    }

    /// Le brut est celui de la contrainte de la base : deux valeurs, et pas une de plus.
    func testTheStatesAreTheOnesTheDatabaseAccepts() {
        XCTAssertEqual(FriendshipRecord.pending, "pending")
        XCTAssertEqual(FriendshipRecord.accepted, "accepted")
    }

    func testOnlyAnAcceptedLinkIsAFriendship() {
        let pending = FriendshipRecord(
            requester_id: me,
            addressee_id: other,
            status: FriendshipRecord.pending,
            created_at: nil,
            responded_at: nil
        )

        XCTAssertFalse(pending.isAccepted)
    }
}
