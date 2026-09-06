import XCTest
@testable import Micabo

final class I18nTests: XCTestCase {
    func testOnlyFourUiLocales() {
        XCTAssertEqual(UiLocale.allCases.map(\.rawValue), ["fr", "de", "es", "tr"])
        XCTAssertTrue(UiLocale.isKnown("de"))
        XCTAssertFalse(UiLocale.isKnown("en"))
        XCTAssertFalse(UiLocale.isKnown("it"))
    }

    func testEachLocaleHasAFlag() {
        XCTAssertEqual(UiLocale.fr.flag, "🇫🇷")
        XCTAssertEqual(UiLocale.de.flag, "🇩🇪")
        XCTAssertEqual(UiLocale.es.flag, "🇪🇸")
        XCTAssertEqual(UiLocale.tr.flag, "🇹🇷")
        for locale in UiLocale.allCases {
            XCTAssertFalse(locale.flag.isEmpty)
        }
    }

    func testPreferredLanguagesFallbackToFrench() {
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["de-DE", "en"]), .de)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["es-MX"]), .es)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["tr"]), .tr)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["en-US", "en"]), .fr)
        XCTAssertEqual(UiLocale.fromPreferredLanguages([]), .fr)
    }

    func testSharedCatalogsHaveTheSameKeys() {
        let french = Set(SharedI18nCatalogs.fr.keys)
        XCTAssertEqual(Set(SharedI18nCatalogs.de.keys), french)
        XCTAssertEqual(Set(SharedI18nCatalogs.es.keys), french)
        XCTAssertEqual(Set(SharedI18nCatalogs.tr.keys), french)
        XCTAssertFalse(french.isEmpty)
    }

    func testIosCatalogsHaveTheSameKeys() {
        let french = Set(IosI18nCatalogs.fr.keys)
        XCTAssertEqual(Set(IosI18nCatalogs.de.keys), french)
        XCTAssertEqual(Set(IosI18nCatalogs.es.keys), french)
        XCTAssertEqual(Set(IosI18nCatalogs.tr.keys), french)
        XCTAssertTrue(french.contains("ios.welcomeTitle"))
        XCTAssertTrue(french.contains("ios.yourTurn"))
        XCTAssertTrue(french.contains("ios.appLanguage"))
        XCTAssertTrue(french.contains("ios.appearance"))
        XCTAssertTrue(french.contains("ios.appearanceTwilight"))
        XCTAssertTrue(french.contains("ios.retentionHeading"))
        XCTAssertTrue(french.contains("ios.deck.history.question"))
        XCTAssertTrue(french.contains("ios.deck.biology.opt1"))
        XCTAssertTrue(french.contains("ios.sheetReady"))
        XCTAssertTrue(french.contains("ios.examReviewsPlaced"))
        XCTAssertTrue(french.contains("ios.review1.quote"))
        XCTAssertTrue(french.contains("ios.trialReminder"))
        for goal in LearningGoal.allCases {
            XCTAssertTrue(french.contains("ios.goal.\(goal.rawValue)"), goal.rawValue)
        }
        for habit in ForgettingHabit.allCases {
            XCTAssertTrue(french.contains("ios.forget.\(habit.rawValue)"), habit.rawValue)
        }
    }

    func testWelcomeDeckAndRetentionCopyFollowLocale() {
        XCTAssertEqual(
            L10n.t("ios.deck.history.subject", locale: .de),
            "Geschichte"
        )
        XCTAssertEqual(
            L10n.t("ios.retentionRemember", locale: .es),
            "Retienes"
        )
        XCTAssertEqual(
            L10n.t("demo.legendWith", locale: .tr).contains("Micabo"),
            true
        )
        XCTAssertEqual(
            RetentionCurve.intervalLabel(forDay: 7, locale: .de),
            "7 T"
        )
        XCTAssertEqual(
            RetentionCurve.intervalLabel(forDay: 3, locale: .tr),
            "3 g"
        )
    }

    func testNoEmptyStrings() {
        for table in [SharedI18nCatalogs.fr, SharedI18nCatalogs.de, SharedI18nCatalogs.es, SharedI18nCatalogs.tr] {
            for (key, value) in table {
                XCTAssertFalse(value.isEmpty, key)
            }
        }
        for table in [IosI18nCatalogs.fr, IosI18nCatalogs.de, IosI18nCatalogs.es, IosI18nCatalogs.tr] {
            for (key, value) in table {
                XCTAssertFalse(value.isEmpty, key)
            }
        }
    }

    func testTokenReplacementAndPlurals() {
        XCTAssertEqual(
            L10n.format("Ouvre le lien envoyé à {email}", locale: .fr, vars: ["email": "a@b.fr"]),
            "Ouvre le lien envoyé à a@b.fr"
        )
        XCTAssertEqual(
            L10n.format("{n, plural, one {1 Fach} other {# Fächer}}", locale: .de, vars: ["n": "1"]),
            "1 Fach"
        )
        XCTAssertEqual(
            L10n.format("{n, plural, one {1 Fach} other {# Fächer}}", locale: .de, vars: ["n": "4"]),
            "4 Fächer"
        )
    }

    func testSubjectDisplayCoversTheCatalog() {
        for family in SubjectCatalog.families {
            XCTAssertNotNil(SubjectDisplay.families[family.name], family.name)
            for subject in family.subjects {
                XCTAssertNotNil(SubjectDisplay.subjects[subject], subject)
            }
        }
    }

    func testGoalAndForgetTitlesFollowTheLocale() {
        XCTAssertEqual(LearningGoal.exam.title(locale: .fr), "Réviser pour un examen")
        XCTAssertEqual(LearningGoal.exam.title(locale: .de), "Für eine Prüfung lernen")
        XCTAssertEqual(ForgettingHabit.never.title(locale: .es), "No, nunca")
        XCTAssertEqual(ForgettingHabit.always.title(locale: .tr), "Evet, sürekli")
    }

    func testCountryNamesComeFromTheSharedCatalog() {
        XCTAssertEqual(SchoolingCountry.de.localizedName(locale: .fr), "Allemagne")
        XCTAssertEqual(SchoolingCountry.de.localizedName(locale: .de), "Deutschland")
        XCTAssertEqual(SchoolingCountry.fr.localizedName(locale: .es), "Francia")
        XCTAssertEqual(SchoolingCountry.tr.localizedName(locale: .tr), "Türkiye")
    }

    func testUiLocaleStorePersists() {
        let defaults = UserDefaults(suiteName: "micabo.i18n.test")!
        defaults.removePersistentDomain(forName: "micabo.i18n.test")
        let store = UiLocaleStore(locale: .fr)
        store.pick(.tr)
        XCTAssertEqual(UserDefaults.standard.string(forKey: UiLocale.storageKey), "tr")
        store.pick(.fr)
    }
}
