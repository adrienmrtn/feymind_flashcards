import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// Les fondations de la refonte : deux familles de caractères, cinq tons, une base d'icônes.
final class FoundationsTests: XCTestCase {
    // MARK: - Les polices

    /// Chaque fichier déclaré s'enregistre, et les deux graisses de la police d'affichage
    /// existent : une graisse absente retomberait sur San Francisco sans rien dire.
    func testTheDisplayFamilyIsAvailable() {
        FontLoader.registerFonts()
        XCTAssertEqual(FontLoader.fileNames, ["SofiaSansCondensed-ExtraBold", "SofiaSansCondensed-Black"])
        for name in FontLoader.fileNames {
            XCTAssertNotNil(UIFont(name: name, size: 17), "\(name) n'est pas enregistrée")
        }
        let weights: [Font.Weight] = [.semibold, .bold, .heavy, .black]
        for weight in weights {
            let name = V3Typeface.displayName(for: weight)
            XCTAssertNotNil(UIFont(name: name, size: 17), "\(name) introuvable")
        }
    }

    /// La police d'affichage n'a que deux graisses : Black, et ExtraBold pour le reste.
    func testTheDisplayFamilyHasTwoWeights() {
        XCTAssertEqual(V3Typeface.displayName(for: .black), "SofiaSansCondensed-Black")
        XCTAssertEqual(V3Typeface.displayName(for: .heavy), "SofiaSansCondensed-ExtraBold")
        XCTAssertEqual(V3Typeface.displayName(for: .bold), "SofiaSansCondensed-ExtraBold")
    }

    /// Nunito a quitté l'app : ni fichier, ni police enregistrée.
    func testNunitoIsGone() {
        FontLoader.registerFonts()
        XCTAssertNil(UIFont(name: "Nunito-Black", size: 17))
        XCTAssertNil(UIFont(name: "Nunito-Regular", size: 17))
        XCTAssertNil(Bundle.main.url(forResource: "Nunito-Regular", withExtension: "ttf"))
        XCTAssertNil(Bundle.main.url(forResource: "Nunito-Black", withExtension: "ttf"))
    }

    /// Côté UIKit (la fiche) : un titre en Sofia Sans Condensed, le texte en police système —
    /// avec son vrai italique.
    func testUIKitFontsFollowTheTwoFamilies() {
        FontLoader.registerFonts()
        XCTAssertEqual(MicaboFont.uiFont(22, weight: .bold).fontName, "SofiaSansCondensed-Black")
        XCTAssertFalse(MicaboFont.uiFont(17).fontName.contains("Sofia"))
        let italic = MicaboFont.uiFont(17, weight: .bold, italic: true)
        XCTAssertTrue(italic.fontDescriptor.symbolicTraits.contains(.traitItalic))
        XCTAssertFalse(italic.fontName.contains("Sofia"))
    }

    /// **Rien ne tombe en « tofu »** : un titre s'écrit dans les vingt-six langues de l'app. La
    /// police d'affichage porte le latin étendu, le cyrillique et le grec ; ce qu'elle ne porte
    /// pas (l'arabe) retombe sur une police du système, glyphe par glyphe — jamais sur la police
    /// de dernier recours, celle des cases vides.
    func testTitlesHaveGlyphsInEveryLanguage() {
        FontLoader.registerFonts()
        let display = CTFontCreateWithName(V3Typeface.displayName(for: .black) as CFString, 27, nil)
        XCTAssertEqual(CTFontCopyPostScriptName(display) as String, "SofiaSansCondensed-Black")
        var tofu: [String] = []
        for locale in UiLocale.allCases {
            let titles = RootTab.tabs.map { $0.label(t: { L10n.t($0, locale: locale) }) }
                + [L10n.t("app.common.back", locale: locale), L10n.t("lesson.lessons.emptyTitle", locale: locale)]
            for title in titles {
                let text = title as NSString
                var index = 0
                while index < text.length {
                    let range = text.rangeOfComposedCharacterSequence(at: index)
                    let font = CTFontCreateForString(display, text as CFString, CFRange(location: range.location, length: range.length))
                    let name = CTFontCopyPostScriptName(font) as String
                    if name.contains("LastResort") {
                        tofu.append("\(locale.rawValue) « \(text.substring(with: range)) » dans « \(title) »")
                    }
                    index = range.location + range.length
                }
            }
        }
        XCTAssertEqual(tofu, [])
    }

    /// La police d'affichage écrit elle-même le français, l'allemand, le polonais, le turc, le
    /// russe et le grec : ces langues-là ne doivent pas retomber sur la police système au milieu
    /// d'un titre.
    func testTheDisplayFamilyCoversLatinCyrillicAndGreek() {
        FontLoader.registerFonts()
        let display = CTFontCreateWithName(V3Typeface.displayName(for: .black) as CFString, 27, nil)
        for sample in ["Leçons à réviser, élève !", "Größe, Übung, weiß", "Zażółć gęślą jaźń", "İyi çalışmalar, öğrenci", "Уроки и карточки", "Μαθήματα και κάρτες"] {
            let text = sample as NSString
            let font = CTFontCreateForString(display, text as CFString, CFRange(location: 0, length: text.length))
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, "SofiaSansCondensed-Black", sample)
        }
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
