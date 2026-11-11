import SwiftUI
import UIKit
import XCTest
@testable import Micabo

final class AppearanceTests: XCTestCase {
    /// Clair, sombre, ou le téléphone ; un choix enregistré se relit tel quel.
    func testTheThreeThemesAndTheOldSettings() {
        XCTAssertEqual(MicaboAppearance.allCases, [.system, .day, .night])
        XCTAssertEqual(MicaboAppearance.fromUnknown(nil), .day, "sans choix, l'app est en clair")
        XCTAssertEqual(MicaboAppearance.fromUnknown("sepia"), .day)
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

    /// **Lot 7 : clair par défaut.** Un appareil neuf, ou un ancien resté en « Système »,
    /// s'ouvre en clair ; un élève qui avait choisi la nuit la garde.
    func testANewOrUndecidedStudentStartsInDay() throws {
        let fresh = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        XCTAssertEqual(AppearanceStore(defaults: fresh).appearance, .day)

        let undecided = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        undecided.set("system", forKey: MicaboAppearance.storageKey)
        XCTAssertEqual(AppearanceStore(defaults: undecided).appearance, .day, "« system » a pu être écrit sans geste")

        let nightOwl = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        nightOwl.set("night", forKey: MicaboAppearance.storageKey)
        XCTAssertEqual(AppearanceStore(defaults: nightOwl).appearance, .night, "la nuit était un choix")

        let twilight = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        twilight.set("twilight", forKey: MicaboAppearance.storageKey)
        XCTAssertEqual(AppearanceStore(defaults: twilight).appearance, .night)
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

    /// Chaque jeton se résout selon l'écran : l'ivoire le jour, la nuit la nuit.
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
