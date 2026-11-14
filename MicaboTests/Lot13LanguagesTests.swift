import CoreText
import SwiftUI
import XCTest
@testable import Micabo

/// **Les six langues du lot 13** : ce qui ne dépend pas de leur traduction — le sens de
/// lecture, la police des titres, les formats.
final class Lot13LanguagesTests: XCTestCase {
    private var savedLocale: String?

    override func setUp() {
        super.setUp()
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        super.tearDown()
    }

    /// La police des titres n'écrit ni l'hébreu, ni le japonais, ni le coréen : leurs titres
    /// passent en police système. Les autres langues gardent la condensée (l'arabe, son repli).
    func testTitlesUseTheSystemFontWhereTheDisplayFontHasNoGlyphs() {
        XCTAssertNotNil(V3Typeface.systemDisplay(for: .ja))
        XCTAssertNotNil(V3Typeface.systemDisplay(for: .ko))
        XCTAssertNotNil(V3Typeface.systemDisplay(for: .he))
        for locale in UiLocale.allCases where ![.ja, .ko, .he].contains(locale) {
            XCTAssertNil(V3Typeface.systemDisplay(for: locale), locale.rawValue)
        }

        FontLoader.registerFonts()
        UserDefaults.standard.set(UiLocale.ja.rawValue, forKey: UiLocale.storageKey)
        let japanese = MicaboFont.uiFont(22, weight: .bold)
        XCTAssertFalse(japanese.fontName.contains("Sofia"), japanese.fontName)
        XCTAssertLessThan(japanese.pointSize, 22)
        UserDefaults.standard.set(UiLocale.fr.rawValue, forKey: UiLocale.storageKey)
        XCTAssertEqual(MicaboFont.uiFont(22, weight: .bold).fontName, "SofiaSansCondensed-Black")
    }

    /// **Pas de case vide** : la police système grasse a chaque caractère des trois écritures,
    /// et le système ne retombe pas sur la police de dernier recours.
    func testTheSystemTitleFontWritesHebrewJapaneseAndKorean() {
        let samples = [
            "בוא נתחיל את החזרה של היום",
            "今日の復習を始めよう、試験まであと十二日。",
            "오늘의 복습을 시작해요",
        ]
        let base = UIFont.systemFont(ofSize: 27, weight: .heavy) as CTFont
        for sample in samples {
            let text = sample as NSString
            var index = 0
            while index < text.length {
                let range = text.rangeOfComposedCharacterSequence(at: index)
                let font = CTFontCreateForString(base, text as CFString, CFRange(location: range.location, length: range.length))
                let name = CTFontCopyPostScriptName(font) as String
                XCTAssertFalse(name.contains("LastResort"), "« \(text.substring(with: range)) » dans « \(sample) »")
                index = range.location + range.length
            }
        }
    }

    /// Les dates et les jours de la semaine viennent de la locale de la langue, pas d'une
    /// table : le japonais écrit « 11月14日 », l'hébreu ses mois, le coréen « 11월 ».
    func testDatesFollowTheNewLocales() {
        let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 12)) ?? Date()
        XCTAssertTrue(MicaboDateFormat.template("d MMMM", locale: .ja).string(from: date).contains("11月"))
        XCTAssertTrue(MicaboDateFormat.template("d MMMM", locale: .ko).string(from: date).contains("11월"))
        XCTAssertTrue(MicaboDateFormat.template("d MMMM", locale: .he).string(from: date).contains("נובמבר"))
        XCTAssertTrue(MicaboDateFormat.template("d MMMM", locale: .lt).string(from: date).lowercased().contains("lapkri"))
        XCTAssertTrue(MicaboDateFormat.template("d MMMM", locale: .lv).string(from: date).lowercased().contains("novembr"))
        XCTAssertTrue(MicaboDateFormat.template("d MMMM", locale: .nb).string(from: date).lowercased().contains("november"))
        XCTAssertEqual(L10n.percent(42, locale: .ja), "42%")
        for locale in [UiLocale.nb, .he, .ja, .lt, .lv, .ko] {
            XCTAssertTrue(L10n.percent(100, locale: locale).contains("%"), locale.rawValue)
        }
    }

    /// **La traduction depuis la caméra vise toute langue dont la consigne est écrite** : les six
    /// d'avant au moins, jamais une langue encore en copie anglaise (sa consigne dirait « into
    /// English »), et chaque cible a sa propre consigne, différente de l'anglaise.
    func testCameraTranslationTargetsFollowTheCatalogs() {
        let targets = Set(ScanTranslation.targets)
        XCTAssertTrue(targets.isSuperset(of: [.fr, .en, .de, .es, .tr, .ar]))
        for locale in UiLocale.allCases where locale.catalogIsProvisional {
            XCTAssertFalse(targets.contains(locale), locale.rawValue)
        }
        let english = L10n.t("ios.scan12.prompt.translate", locale: .en)
        for target in targets where target != .en {
            XCTAssertNotEqual(L10n.t("ios.scan12.prompt.translate", locale: target), english, target.rawValue)
        }
        XCTAssertEqual(ScanTranslation.defaultTarget(for: .ja), UiLocale.ja.catalogIsProvisional ? .en : .ja)
    }

    /// Le norvégien et l'hébreu arrivent aussi sous leurs autres codes, et la transcription
    /// écoute dans la bonne langue.
    func testCodesAndRecognitionLocales() {
        XCTAssertEqual(AudioTranscriber.locale(for: .ja).identifier.replacingOccurrences(of: "_", with: "-"), "ja-JP")
        XCTAssertEqual(AudioTranscriber.locale(for: .he).identifier.replacingOccurrences(of: "_", with: "-"), "he-IL")
        XCTAssertEqual(AudioTranscriber.locale(for: .nb).identifier.replacingOccurrences(of: "_", with: "-"), "nb-NO")
        XCTAssertEqual(OnDeviceOCR.preferredRecognitionLanguages(content: .ko).first, "ko-KR")
        XCTAssertEqual(UiLocale.he.foundation.language.characterDirection, .rightToLeft)
        XCTAssertEqual(UiLocale.ja.contentLanguage, .ja)
    }
}
