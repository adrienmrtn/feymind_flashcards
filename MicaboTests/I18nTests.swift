import XCTest
@testable import Micabo

final class I18nTests: XCTestCase {
    func testFiveUiLocales() {
        XCTAssertEqual(UiLocale.allCases.map(\.rawValue), ["en", "fr", "de", "es", "tr"])
        XCTAssertTrue(UiLocale.isKnown("de"))
        XCTAssertTrue(UiLocale.isKnown("en"))
        XCTAssertFalse(UiLocale.isKnown("it"))
    }

    func testEachLocaleHasAFlag() {
        XCTAssertEqual(UiLocale.en.flag, "🇬🇧")
        XCTAssertEqual(UiLocale.fr.flag, "🇫🇷")
        XCTAssertEqual(UiLocale.de.flag, "🇩🇪")
        XCTAssertEqual(UiLocale.es.flag, "🇪🇸")
        XCTAssertEqual(UiLocale.tr.flag, "🇹🇷")
        for locale in UiLocale.allCases {
            XCTAssertFalse(locale.flag.isEmpty)
            XCTAssertFalse(locale.nativeName.isEmpty)
        }
    }

    /// Un iPhone en anglais ouvre l'app en anglais. Une langue qu'on ne parle pas retombe
    /// toujours sur le français : c'est celle de la quasi-totalité des comptes existants.
    func testPreferredLanguagesPickEnglishAndFallBackToFrench() {
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["de-DE", "en"]), .de)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["es-MX"]), .es)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["tr"]), .tr)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["en-US", "en"]), .en)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["en-GB"]), .en)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["it-IT", "ja"]), .fr)
        XCTAssertEqual(UiLocale.fromPreferredLanguages([]), .fr)
    }

    func testSharedCatalogsHaveTheSameKeys() {
        let french = Set(SharedI18nCatalogs.fr.keys)
        XCTAssertEqual(Set(SharedI18nCatalogs.en.keys), french)
        XCTAssertEqual(Set(SharedI18nCatalogs.de.keys), french)
        XCTAssertEqual(Set(SharedI18nCatalogs.es.keys), french)
        XCTAssertEqual(Set(SharedI18nCatalogs.tr.keys), french)
        XCTAssertFalse(french.isEmpty)
    }

    /// Le passage par `table(for:)` est ce qui décide de la langue rendue à l'écran : un
    /// code non branché retombe silencieusement sur le français, et c'est exactement ce qui
    /// laissait l'anglais dehors.
    func testTablesAreWiredForEveryLocale() {
        XCTAssertEqual(SharedI18nCatalogs.table(for: "en")["common.back"], "Back")
        XCTAssertEqual(SharedI18nCatalogs.table(for: "fr")["common.back"], "Retour")
        XCTAssertEqual(IosI18nCatalogs.table(for: "en")["ios.done"], "Done")
        XCTAssertEqual(IosI18nCatalogs.table(for: "fr")["ios.done"], "Terminé")

        // Une langue non branchée dans le `switch` rendrait le français sans le dire.
        for locale in UiLocale.allCases where locale != .fr {
            XCTAssertNotEqual(
                SharedI18nCatalogs.table(for: locale.rawValue)["landing.titleAccent"],
                SharedI18nCatalogs.fr["landing.titleAccent"],
                locale.rawValue
            )
            XCTAssertNotEqual(
                IosI18nCatalogs.table(for: locale.rawValue)["ios.welcomeTitle"],
                IosI18nCatalogs.fr["ios.welcomeTitle"],
                locale.rawValue
            )
        }
    }

    func testIosCatalogsHaveTheSameKeys() {
        let french = Set(IosI18nCatalogs.fr.keys)
        XCTAssertEqual(Set(IosI18nCatalogs.en.keys), french)
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
            L10n.t("ios.deck.history.subject", locale: .en),
            "History"
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
        for locale in UiLocale.allCases {
            for (key, value) in SharedI18nCatalogs.table(for: locale.rawValue) {
                XCTAssertFalse(value.isEmpty, "\(locale.rawValue) \(key)")
            }
            for (key, value) in IosI18nCatalogs.table(for: locale.rawValue) {
                XCTAssertFalse(value.isEmpty, "\(locale.rawValue) \(key)")
            }
        }
    }

    /// **Aucune clé ne doit retomber sur le français.**
    ///
    /// C'est le seul test qui dise vraiment « l'app est traduite » : la parité des clés
    /// prouve qu'une entrée existe, pas qu'elle a été traduite. Une valeur identique au
    /// français sur une phrase — une vraie phrase, pas « OK », « LaTeX » ou « Micabo » —
    /// est le signe d'une ligne recopiée et oubliée.
    func testNothingFallsBackToFrench() {
        // Ce qui s'écrit pareil dans les deux langues : des jetons seuls, un nom propre,
        // un objet de courriel, et un pluriel dont les deux branches se ressemblent.
        let sameEverywhere: Set<String> = [
            "ios.rankingAria", "ios.photo.scanName", "ios.mail.subject.bug", "ios.offer.minutes",
        ]
        var copied: [String] = []
        for (key, french) in IosI18nCatalogs.fr {
            guard !sameEverywhere.contains(key) else { continue }
            // Un mot isolé peut légitimement s'écrire pareil dans deux langues.
            guard french.split(separator: " ").count > 2 else { continue }
            if IosI18nCatalogs.en[key] == french { copied.append(key) }
        }
        XCTAssertTrue(copied.isEmpty, "clés restées en français : \(copied.sorted())")
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
        XCTAssertEqual(LearningGoal.exam.title(locale: .en), "Revise for an exam")
        XCTAssertEqual(LearningGoal.exam.title(locale: .de), "Für eine Prüfung lernen")
        XCTAssertEqual(ForgettingHabit.never.title(locale: .es), "No, nunca")
        XCTAssertEqual(ForgettingHabit.always.title(locale: .tr), "Evet, sürekli")
    }

    func testCountryNamesComeFromTheSharedCatalog() {
        XCTAssertEqual(SchoolingCountry.de.localizedName(locale: .fr), "Allemagne")
        XCTAssertEqual(SchoolingCountry.de.localizedName(locale: .de), "Deutschland")
        XCTAssertEqual(SchoolingCountry.de.localizedName(locale: .en), "Germany")
        XCTAssertEqual(SchoolingCountry.fr.localizedName(locale: .es), "Francia")
        XCTAssertEqual(SchoolingCountry.tr.localizedName(locale: .tr), "Türkiye")
        for country in SchoolingCountry.allCases {
            let key = "country.\(country.rawValue)"
            XCTAssertNotEqual(country.localizedName(locale: .en), key, key)
        }
    }

    /// Les matières s'affichent traduites dans les cinq langues, y compris l'anglais. La
    /// valeur stockée, elle, reste le français du catalogue.
    func testSubjectDisplayCoversEveryLocale() {
        XCTAssertEqual(SubjectDisplay.subject("Mathématiques", locale: .en), "Maths")
        XCTAssertEqual(SubjectDisplay.family("Droit & économie", locale: .en), "Law & business")
        for family in SubjectCatalog.families {
            for locale in UiLocale.allCases {
                XCTAssertNotNil(SubjectDisplay.families[family.name]?[locale], family.name)
                for subject in family.subjects {
                    XCTAssertNotNil(SubjectDisplay.subjects[subject]?[locale], subject)
                }
            }
        }
    }

    /// Le monde entier, nommé dans la langue de l'app et non dans celle du téléphone.
    func testWorldCountriesFollowTheAppLocale() {
        XCTAssertEqual(WorldCountries.country(code: "BR", locale: .en)?.name, "Brazil")
        XCTAssertEqual(WorldCountries.country(code: "BR", locale: .fr)?.name, "Brésil")
        XCTAssertEqual(WorldCountries.matches("Brazil", locale: .en).first?.code, "BR")
        XCTAssertGreaterThan(WorldCountries.all(locale: .en).count, 150)
    }

    /// Le compte à rebours de l'offre se compose au lieu de s'écrire : chaque langue pose
    /// « il reste » où elle veut, et le turc met le signe du pourcentage devant le nombre.
    func testOfferCountdownAndDiscountSplitFollowTheLocale() {
        XCTAssertEqual(DiscountOffer.countdownLabel(0, locale: .en), "offer ended")
        XCTAssertEqual(DiscountOffer.countdownLabel(30, locale: .en), "less than a minute left")
        XCTAssertEqual(DiscountOffer.countdownLabel(3 * 3600, locale: .en), "3 hours left")
        XCTAssertEqual(DiscountOffer.countdownLabel(3600 + 60, locale: .en), "1 hour and 1 minute left")
        XCTAssertEqual(DiscountOffer.countdownLabel(3600 + 60, locale: .fr), "il reste 1 heure et 1 minute")

        XCTAssertEqual(DiscountHeadline.split(percent: 30, locale: .en).rate, "30\u{00a0}%")
        XCTAssertEqual(DiscountHeadline.split(percent: 30, locale: .en).rest, " off")
        XCTAssertEqual(DiscountHeadline.split(percent: 30, locale: .tr).rate, "%30")
        XCTAssertEqual(DiscountHeadline.split(percent: 30, locale: .tr).rest, " daha az")
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
