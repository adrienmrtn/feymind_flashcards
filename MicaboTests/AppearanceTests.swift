import SwiftUI
import UIKit
import XCTest
@testable import Micabo

final class AppearanceTests: XCTestCase {
    /// Clair, sombre, ou le téléphone ; les anciens réglages retrouvent leur sens.
    func testTheThreeThemesAndTheOldSettings() {
        XCTAssertEqual(MicaboAppearance.allCases, [.system, .day, .night])
        XCTAssertEqual(MicaboAppearance.fromUnknown(nil), .system)
        XCTAssertEqual(MicaboAppearance.fromUnknown("sepia"), .system)
        XCTAssertEqual(MicaboAppearance.fromUnknown("day"), .day)
        XCTAssertEqual(MicaboAppearance.fromUnknown("night"), .night)
        XCTAssertEqual(MicaboAppearance.fromUnknown("twilight"), .night, "le crépuscule était une nuit douce")
    }

    func testEachThemeSetsTheWindow() {
        XCTAssertNil(MicaboAppearance.system.colorScheme, "le téléphone décide")
        XCTAssertEqual(MicaboAppearance.day.colorScheme, .light)
        XCTAssertEqual(MicaboAppearance.night.colorScheme, .dark)
    }

    func testTheChoiceIsRemembered() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "appearance-\(UUID().uuidString)"))
        let store = AppearanceStore(defaults: defaults)
        XCTAssertEqual(store.appearance, .system)
        store.appearance = .night
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
