import SwiftUI
import UIKit
import XCTest
@testable import Micabo

final class AppearanceTests: XCTestCase {
    /// Clair, sombre, ou le téléphone ; un choix enregistré se relit tel quel.
    func testTheThreeThemesAndTheOldSettings() {
        XCTAssertEqual(MicaboAppearance.allCases, [.system, .day, .night])
        XCTAssertEqual(MicaboAppearance.fromUnknown(nil), .night, "sans choix, l'app est en marine")
        XCTAssertEqual(MicaboAppearance.fromUnknown("sepia"), .night)
        XCTAssertEqual(MicaboAppearance.fromUnknown("system"), .system)
        XCTAssertEqual(MicaboAppearance.fromUnknown("day"), .day)
        XCTAssertEqual(MicaboAppearance.fromUnknown("night"), .night)
        XCTAssertEqual(MicaboAppearance.fromUnknown("twilight"), .night, "le crépuscule était une nuit douce")
    }

    func testEachThemeSetsTheWindow() {
        XCTAssertNil(MicaboAppearance.system.colorScheme, "le téléphone décide")
        XCTAssertEqual(MicaboAppearance.day.colorScheme, .light)
        XCTAssertEqual(MicaboAppearance.night.colorScheme, .dark)
    }

    /// **Lot 10 : marine par défaut, pour tout le monde.** Un appareil neuf s'ouvre en marine,
    /// et un ancien aussi, quoi que dise l'ancienne clé : elle a pu être écrite sans geste.
    func testANewOrUndecidedStudentStartsInNavy() throws {
        let fresh = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        XCTAssertEqual(AppearanceStore(defaults: fresh).appearance, .night)
        XCTAssertEqual(MicaboAppearance.defaultAppearance, .night)

        for legacy in ["system", "day", "night", "twilight", "sepia"] {
            let old = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
            old.set(legacy, forKey: MicaboAppearance.storageKey)
            XCTAssertEqual(AppearanceStore(defaults: old).appearance, .night, "ancienne clé « \(legacy) »")
        }
    }

    /// **Un choix explicite est gardé** : « Jour », « Comme le téléphone » ou « Nuit », choisi
    /// dans le Profil, survit au passage en marine — et au redémarrage.
    func testAnExplicitChoiceSurvivesTheMoveToNavy() throws {
        for (choice, expected) in [("day", MicaboAppearance.day), ("system", .system), ("night", .night)] {
            let defaults = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
            defaults.set(choice, forKey: MicaboAppearance.choiceKey)
            XCTAssertEqual(AppearanceStore(defaults: defaults).appearance, expected, "choix « \(choice) »")
        }

        let defaults = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        AppearanceStore(defaults: defaults).choose(.day)
        XCTAssertEqual(defaults.string(forKey: MicaboAppearance.choiceKey), "day")
        XCTAssertEqual(AppearanceStore(defaults: defaults).appearance, .day, "« Jour » choisi se retrouve au lancement suivant")
    }

    /// Lancer l'app n'écrit rien : seul le geste de l'élève devient un choix.
    func testLaunchingDoesNotRecordAChoice() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        _ = AppearanceStore(defaults: defaults)
        XCTAssertNil(defaults.string(forKey: MicaboAppearance.choiceKey))
    }

    func testTheChoiceIsRemembered() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        defaults.set("night", forKey: MicaboAppearance.storageKey)
        let store = AppearanceStore(defaults: defaults)
        store.choose(.system)
        XCTAssertEqual(store.appearance, .system)
        XCTAssertEqual(AppearanceStore(defaults: defaults).appearance, .system, "le choix l'emporte sur l'ancienne clé")
        store.choose(.night)
        XCTAssertEqual(AppearanceStore(defaults: defaults).appearance, .night)
    }

    /// Chaque jeton se résout selon l'écran : le clair teinté le jour, le marine la nuit.
    func testTheAdaptivePaletteFollowsTheScreen() {
        let light = UITraitCollection(userInterfaceStyle: .light)
        let dark = UITraitCollection(userInterfaceStyle: .dark)
        let canvas = UIColor(MicaboPalette.adaptive.canvas)
        assertSame(canvas.resolvedColor(with: light), UIColor(MicaboPalette.day.canvas))
        assertSame(canvas.resolvedColor(with: dark), UIColor(MicaboPalette.night.canvas))
        XCTAssertEqual(MicaboPalette.adaptive.toneVivid.count, LessonTone.allCases.count)
        XCTAssertEqual(MicaboPalette.night.tonePale.count, LessonTone.allCases.count)
    }

    private func assertSame(_ lhs: UIColor, _ rhs: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        let a = components(lhs)
        let b = components(rhs)
        for index in 0..<3 {
            XCTAssertEqual(a[index], b[index], accuracy: 0.01, file: file, line: line)
        }
    }

    private func components(_ color: UIColor) -> [CGFloat] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }
}
