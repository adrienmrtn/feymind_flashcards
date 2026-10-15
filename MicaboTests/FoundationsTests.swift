import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// Les fondations de la refonte : une police, cinq tons, une base d'icônes.
final class FoundationsTests: XCTestCase {
    // MARK: - Nunito

    /// Chaque fichier déclaré s'enregistre, et chaque graisse demandée par l'app existe : une
    /// graisse absente retomberait sur San Francisco sans rien dire.
    func testEveryNunitoWeightIsAvailable() {
        FontLoader.registerFonts()
        for name in FontLoader.fileNames {
            XCTAssertNotNil(UIFont(name: name, size: 17), "\(name) n'est pas enregistrée")
        }
        let weights: [Font.Weight] = [.regular, .medium, .semibold, .bold, .heavy, .black]
        for weight in weights {
            let name = MicaboFont.nunitoName(for: weight)
            XCTAssertNotNil(UIFont(name: name, size: 17), "\(name) introuvable")
            XCTAssertNotNil(UIFont(name: MicaboFont.nunitoName(for: weight, italic: true), size: 17))
        }
    }

    func testLightWeightsFallBackToRegular() {
        XCTAssertEqual(MicaboFont.nunitoName(for: .light), "Nunito-Regular")
        XCTAssertEqual(MicaboFont.nunitoName(for: .thin), "Nunito-Regular")
        XCTAssertEqual(MicaboFont.nunitoName(for: .semibold, italic: true), "Nunito-BoldItalic")
        XCTAssertEqual(MicaboFont.nunitoName(for: .regular, italic: true), "Nunito-Italic")
    }

    func testUIKitFontIsNunito() {
        FontLoader.registerFonts()
        XCTAssertEqual(MicaboFont.uiFont(17).fontName, "Nunito-Regular")
        XCTAssertEqual(MicaboFont.uiFont(17, weight: .bold, italic: true).fontName, "Nunito-BoldItalic")
    }

    // MARK: - Les tons

    func testTonesRotateAndNeverRepeatTwiceInARow() {
        var tone: LessonTone? = nil
        var seen: [LessonTone] = []
        for _ in 0..<LessonTone.allCases.count {
            let next = LessonTone.next(after: tone)
            XCTAssertNotEqual(next, tone)
            seen.append(next)
            tone = next
        }
        XCTAssertEqual(Set(seen), Set(LessonTone.allCases), "les cinq tons doivent tourner")
    }

    func testStableToneDoesNotChangeBetweenCalls() throws {
        let id = try XCTUnwrap(UUID(uuidString: "6B1F2C3D-4E5F-4061-8273-94A5B6C7D8E9"))
        XCTAssertEqual(LessonTone.stable(for: id), LessonTone.stable(for: id))
        // FNV-1a ne dépend pas du lancement : la valeur se recalcule à la main.
        XCTAssertEqual(StableHash.of(""), 0xcbf29ce484222325)
        XCTAssertEqual(StableHash.of("a"), 0xaf63dc4c8601ec8c)
    }

    func testUnknownToneFallsBackToBlue() {
        XCTAssertEqual(LessonTone(raw: nil), .blue)
        XCTAssertEqual(LessonTone(raw: "violet"), .blue)
        XCTAssertEqual(LessonTone(raw: "mint"), .mint)
    }

    func testPaletteHasOneShadePerTone() {
        let palette = MicaboPalette.day
        XCTAssertEqual(palette.tonePale.count, LessonTone.allCases.count)
        XCTAssertEqual(palette.toneVivid.count, LessonTone.allCases.count)
        XCTAssertEqual(palette.toneInk.count, LessonTone.allCases.count)
    }

    // MARK: - Les icônes

    /// Chaque icône de la base a son image dans le catalogue d'assets, aux deux densités.
    func testEveryBaseIconHasItsImage() {
        for icon in MicaboIcon.allCases where icon.isInBase {
            XCTAssertNotNil(icon.image, "\(icon.assetName) manque dans Assets.xcassets")
        }
    }

    func testTheModelCatalogIsMadeOfBaseIconsOnlyOnce() {
        let icons = MicaboIcon.lessonCatalog.map(\.icon)
        XCTAssertEqual(icons.count, Set(icons).count, "une icône apparaît deux fois dans le catalogue")
        for icon in icons {
            XCTAssertTrue(icon.isInBase, "\(icon) n'a pas d'image : le modèle ne doit pas la choisir")
        }
        XCTAssertTrue(icons.contains(.book), "le livre est l'icône par défaut")
    }

    func testUnknownIconFallsBackToTheBook() {
        XCTAssertEqual(MicaboIcon(id: nil), .book)
        XCTAssertEqual(MicaboIcon(id: "licorne"), .book)
        XCTAssertEqual(MicaboIcon(id: " Globe "), .globe)
        XCTAssertEqual(MicaboIcon(id: "livre-ouvert"), .book)
    }
}
