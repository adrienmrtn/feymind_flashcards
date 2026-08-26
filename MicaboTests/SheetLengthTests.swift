import XCTest
@testable import Micabo

/// Verrouille le **curseur de longueur de fiche**, devenu continu.
///
/// Il n'avait que trois positions, ce qui n'est pas un curseur : trois crans se comptent, se
/// visent, et ne se distinguent en rien de trois boutons. Il court maintenant de huit à
/// trente-quatre blocs, et le format n'est plus qu'un nom donné à la zone où l'on se trouve.
final class SheetLengthTests: XCTestCase {
    /// `SheetPreferences` écrit dans les réglages partagés de l'app : les deux clés sont donc
    /// remises à zéro autour de chaque test, sinon leur résultat dépendrait de l'ordre dans
    /// lequel les autres ont tourné.
    override func setUp() {
        super.setUp()
        clearPreferences()
    }

    override func tearDown() {
        clearPreferences()
        super.tearDown()
    }

    private func clearPreferences() {
        UserDefaults.standard.removeObject(forKey: SheetPreferences.blocksKey)
        UserDefaults.standard.removeObject(forKey: SheetPreferences.lengthKey)
    }

    // MARK: - L'échelle

    /// Au moins dix crans, et c'est le fond de l'affaire : en dessous, le geste redevient un
    /// choix parmi quelques valeurs, et autant remettre des boutons.
    func testTheSliderHasFarMoreThanTenNotches() {
        let notches = SheetLength.blockBounds.count
        XCTAssertGreaterThanOrEqual(notches, 10, "Un curseur à moins de dix crans n'est pas un curseur")
        XCTAssertEqual(SheetLength.blockBounds, 8...34)
    }

    /// Le nom du format suit le nombre de blocs, et il le suit sans trou : chaque position
    /// du curseur a un nom, y compris celles qui tombent entre deux plages.
    func testEveryPositionOfTheSliderHasAFormat() {
        for blocks in SheetLength.blockBounds {
            let format = SheetLength.containing(blocks: blocks)
            XCTAssertFalse(format.title.isEmpty, "\(blocks) blocs sans format")
        }

        XCTAssertEqual(SheetLength.containing(blocks: 8), .brief)
        XCTAssertEqual(SheetLength.containing(blocks: 12), .brief)
        XCTAssertEqual(SheetLength.containing(blocks: 18), .standard)
        XCTAssertEqual(SheetLength.containing(blocks: 22), .standard)
        XCTAssertEqual(SheetLength.containing(blocks: 34), .deep)
    }

    /// Le format monte quand le curseur monte : une échelle qui ferait un aller-retour se
    /// lirait comme un bug.
    func testTheFormatNeverGoesBackwards() {
        var seen: [SheetLength] = []
        for blocks in SheetLength.blockBounds {
            let format = SheetLength.containing(blocks: blocks)
            if seen.last != format { seen.append(format) }
        }
        XCTAssertEqual(seen, [.brief, .standard, .deep])
    }

    func testEachFormatSitsInsideItsOwnRange() {
        for format in SheetLength.allCases {
            XCTAssertTrue(
                format.blockRange.contains(format.defaultBlocks),
                "\(format) a une valeur par défaut hors de sa plage"
            )
            XCTAssertEqual(SheetLength.containing(blocks: format.defaultBlocks), format)
        }
    }

    /// La durée annoncée grandit avec la fiche, et elle bouge **à l'intérieur d'une même
    /// famille** : c'est ce qui fait qu'on sent le curseur travailler au lieu de le voir
    /// sauter d'un nom à l'autre.
    func testTheReadingHintMovesWithinAFormat() {
        XCTAssertNotEqual(
            SheetPreferences.readingHint(forBlocks: 14),
            SheetPreferences.readingHint(forBlocks: 22),
            "Deux fiches équilibrées de volumes très différents ne se lisent pas en autant de temps"
        )
    }

    // MARK: - Le réglage

    func testTheBlockCountIsClampedToTheSlider() {
        SheetPreferences.blocks = 200
        XCTAssertEqual(SheetPreferences.blocks, SheetLength.blockBounds.upperBound)

        SheetPreferences.blocks = -4
        XCTAssertEqual(SheetPreferences.blocks, SheetLength.blockBounds.lowerBound)
    }

    /// Le format reste écrit à côté du nombre : c'est lui que le profil synchronise, et lui
    /// que la fonction Edge comprend depuis toujours.
    func testWritingBlocksAlsoWritesTheFormat() {
        SheetPreferences.blocks = 30
        XCTAssertEqual(SheetPreferences.length, .deep)
        XCTAssertEqual(UserDefaults.standard.string(forKey: SheetPreferences.lengthKey), "deep")
    }

    /// Choisir un format depuis un menu replace le curseur au milieu de la plage — sauf s'il
    /// y est déjà, auquel cas y toucher effacerait un réglage fin pour rien.
    func testChoosingAFormatOnlyMovesTheSliderWhenItHasTo() {
        SheetPreferences.blocks = 20
        SheetPreferences.length = .standard
        XCTAssertEqual(SheetPreferences.blocks, 20, "On était déjà en équilibrée")

        SheetPreferences.length = .brief
        XCTAssertEqual(SheetPreferences.blocks, SheetLength.brief.defaultBlocks)
    }

    /// Un appareil qui n'a connu que les trois formats ne doit pas voir son réglage sauter
    /// parce que la façon de le stocker a changé.
    func testAnOldFormatOnlySettingIsCarriedOver() {
        UserDefaults.standard.set(SheetLength.deep.rawValue, forKey: SheetPreferences.lengthKey)
        UserDefaults.standard.removeObject(forKey: SheetPreferences.blocksKey)

        XCTAssertEqual(SheetPreferences.blocks, SheetLength.deep.defaultBlocks)
        XCTAssertEqual(SheetPreferences.length, .deep)
    }
}
