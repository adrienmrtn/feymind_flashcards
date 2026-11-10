import XCTest
@testable import Micabo

final class I18nTests: XCTestCase {
    /// Les langues des marchés de Micabo : l'Europe, le Moyen-Orient, le Brésil et
    /// l'Amérique latine, chacun avec la sienne.
    func testEveryMarketHasItsLanguage() {
        XCTAssertEqual(UiLocale.allCases.map(\.rawValue), ["en", "fr", "de", "es", "es-419", "it", "pt-PT", "pt-BR", "nl", "pl", "ro", "sv", "da", "fi", "et", "cs", "sk", "hu", "hr", "sl", "sr", "bg", "el", "ru", "tr", "ar"])
        XCTAssertTrue(UiLocale.isKnown("de"))
        XCTAssertTrue(UiLocale.isKnown("pt-BR"))
        XCTAssertFalse(UiLocale.isKnown("ja"))
        XCTAssertTrue(UiLocale.ar.isRightToLeft)
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

    /// Un iPhone ouvre l'app dans sa langue, région comprise ; une langue que Micabo ne parle
    /// pas retombe sur l'anglais, la langue de base — un appareil sans préférence aussi.
    func testPreferredLanguagesFollowTheRegion() {
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["de-DE", "en"]), .de)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["es-ES"]), .es)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["es-MX"]), .es419)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["es-419"]), .es419)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["pt-BR"]), .ptBR)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["pt-PT"]), .pt)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["sr-Latn-RS"]), .sr)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["ar-AE"]), .ar)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["tr"]), .tr)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["en-US", "en"]), .en)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["en-GB"]), .en)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["it-IT", "ja"]), .it)
        XCTAssertEqual(UiLocale.fromPreferredLanguages(["ja"]), .en)
        XCTAssertEqual(UiLocale.fromPreferredLanguages([]), .en)
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
                L10n.table(for: locale)["landing.titleAccent"],
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
        XCTAssertTrue(french.contains("ios.hook.title"))
        XCTAssertTrue(french.contains("ios.appLanguage"))
        XCTAssertTrue(french.contains("ios.appearance"))
        XCTAssertTrue(french.contains("ios.appearanceTwilight"))
        XCTAssertTrue(french.contains("ios.retentionHeading"))
        XCTAssertTrue(french.contains("ios.deck.history.question"))
        XCTAssertTrue(french.contains("ios.deck.biology.opt1"))
        XCTAssertTrue(french.contains("ios.sheetReady"))
        XCTAssertTrue(french.contains("ios.examReviewsPlaced"))
        XCTAssertTrue(french.contains("ios.onb.review1.title"))
        XCTAssertTrue(french.contains("ios.trialReminder"))
        for goal in LearningGoal.allCases {
            XCTAssertTrue(french.contains("ios.goal.\(goal.rawValue)"), goal.rawValue)
        }
        for habit in ForgettingHabit.allCases {
            XCTAssertTrue(french.contains("ios.forget.\(habit.rawValue)"), habit.rawValue)
        }
    }

    /// **Le lot « Knowunity » parle toutes les langues de l'app** (`docs/refonte-knowunity.md`
    /// § 8) : chaque phrase `ios.kx.*` existe dans chaque table, régionales comprises, sans
    /// retomber sur l'anglais.
    func testKnowunityCopyExistsInEveryLanguage() {
        let keys = IosI18nCatalogs.fr.keys.filter { $0.hasPrefix("ios.kx.") }
        XCTAssertEqual(keys.count, 70)
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for key in keys {
                XCTAssertNotNil(table[key], "\(locale.rawValue) \(key)")
            }
        }
        for league in XPRules.leagues {
            XCTAssertNotNil(IosI18nCatalogs.fr["ios.kx.league.\(league.id)"], league.id)
        }
        XCTAssertEqual(L10n.t("ios.kx.today.due", locale: .fr, vars: ["count": "1"]), "1 carte à réviser")
        XCTAssertEqual(L10n.t("ios.kx.today.due", locale: .en, vars: ["count": "3"]), "3 cards to review")
        XCTAssertEqual(L10n.t("ios.kx.league.name", locale: .de, vars: ["name": "Gold"]), "Gold-Liga")
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
        // un objet de courriel, des abréviations que l'anglais partage avec le français,
        // et un pluriel dont les deux branches se ressemblent.
        // Des formats de nombres, un pluriel ICU, et une référence bibliographique : pareils
        // dans toutes les langues par nature.
        let sameEverywhere: Set<String> = [
            "ios.rankingAria", "ios.photo.scanName", "ios.mail.subject.bug", "ios.offer.minutes",
            "ios.durationHm", "ios.readingApprox", "ios.deck.count", "ios.deck.percentAndCards",
            "ios.journey.source", "ios.today.approxMinutes",
            // Deux formats chiffrés du lot « Knowunity » : « 30 / 50 XP », « Or · 120 XP ».
            "ios.kx.today.goalProgress", "ios.kx.league.rowSub",
        ]
        assertNotCopiedFromFrench(
            french: IosI18nCatalogs.fr,
            english: IosI18nCatalogs.en,
            exempt: sameEverywhere,
            table: "IosI18nCatalogs"
        )
    }

    /// La même garantie sur la table partagée, celle que le site écrit.
    ///
    /// Elle est générée, donc jamais relue ici — et c'est exactement pourquoi le test
    /// existe : une clé ajoutée côté site sans sa traduction descendrait jusqu'à l'iPhone
    /// sans que rien ne l'arrête.
    func testSharedCatalogIsNotFrenchInEnglish() {
        // Des chiffres, des abréviations communes, et trois références bibliographiques.
        let sameEverywhere: Set<String> = [
            "app.session.underOneMin", "app.mock.blockLine", "app.mock.progress",
            "app.profile.streak.record", "app.deck.pouringCount", "app.import.readingMins",
            "app.paywall.study1Source", "app.paywall.study2Source", "app.paywall.study3Source",
            "app.today.mock", "app.today.minutesCourses", "app.common.delayUnderMin",
            // La carte animée de la vitrine : un format et une taille, pareils dans les deux langues.
            "landing.demoFile1Meta", "landing.demoFile2Meta", "landing.demoFile3Meta", "landing.demoFile4Meta",
        ]
        assertNotCopiedFromFrench(
            french: SharedI18nCatalogs.fr,
            english: SharedI18nCatalogs.en,
            exempt: sameEverywhere,
            table: "SharedI18nCatalogs"
        )
    }

    private func assertNotCopiedFromFrench(
        french: [String: String],
        english: [String: String],
        exempt: Set<String>,
        table: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var copied: [String] = []
        for (key, value) in french {
            guard !exempt.contains(key) else { continue }
            // Un mot isolé peut légitimement s'écrire pareil dans deux langues.
            guard value.split(separator: " ").count > 2 else { continue }
            if english[key] == value { copied.append(key) }
        }
        XCTAssertTrue(
            copied.isEmpty,
            "\(table) : clés restées en français — \(copied.sorted())",
            file: file,
            line: line
        )
    }

    /// **Aucun écran ne doit écrire sa propre phrase de repli.**
    ///
    /// L'environnement rend `UiLocaleStore?`, et il est nil pour de bon dans une barre
    /// d'outils posée en accessoire de clavier. Chaque appel portait donc son repli écrit à
    /// la main, en français : l'app basculait de langue au milieu d'un écran sans que rien
    /// ne plante. L'extension sur l'optionnel rend la langue résolue à la place.
    func testTheOptionalStoreStillSpeaksTheChosenLanguage() {
        let absent: UiLocaleStore? = nil
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) }
            else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }

        defaults.set(UiLocale.en.rawValue, forKey: UiLocale.storageKey)
        XCTAssertEqual(absent.locale, .en)
        XCTAssertEqual(absent.t("ios.done"), "Done")

        defaults.set(UiLocale.de.rawValue, forKey: UiLocale.storageKey)
        XCTAssertEqual(absent.t("ios.done"), "Fertig")

        let present: UiLocaleStore? = UiLocaleStore(locale: .es)
        XCTAssertEqual(present.t("ios.done"), IosI18nCatalogs.es["ios.done"])
    }

    /// **Un retour à la ligne doit en être un, pas deux caractères à l'écran.**
    ///
    /// Huit titres d'accueil anglais portaient un antislash suivi d'un `n` au lieu du saut
    /// de ligne : la table avait été reconstruite en ré-encodant des valeurs déjà
    /// échappées. L'écran affichait « Say it out loud.\nThen you will know. » en toutes
    /// lettres. Rien ne plantait, et la parité des clés était verte — la clé existait, sa
    /// valeur était juste fausse d'un caractère.
    func testNoEscapedBackslashesInCopy() {
        for locale in UiLocale.allCases {
            for (key, value) in IosI18nCatalogs.table(for: locale.rawValue) {
                XCTAssertFalse(
                    value.contains("\\n"),
                    "\(locale.rawValue) \(key) : un antislash et un n, au lieu d'un retour à la ligne"
                )
            }
            for (key, value) in SharedI18nCatalogs.table(for: locale.rawValue) {
                XCTAssertFalse(value.contains("\\n"), "\(locale.rawValue) \(key)")
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
        XCTAssertEqual(DiscountHeadline.split(percent: 30, locale: .tr).rest, " indirim")
    }

    /// **Chaque clé écrite dans le code a sa phrase dans chacune des vingt-six langues.**
    ///
    /// La parité des tables ne le prouve pas : une clé appelée par un écran mais rangée dans
    /// une seule table (les intensités d'examen n'existaient qu'en langues régionales)
    /// s'affichait telle quelle en français et en anglais, et une langue régionale à qui il
    /// manque une clé retombe sur l'anglais sans rien dire. Le test relit les sources :
    /// les littéraux `ios.*` et `lesson.*`, et tout ce qui est passé à `t("…")`.
    func testEveryKeyUsedInTheCodeExistsInEveryLanguage() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        let patterns = try [
            NSRegularExpression(pattern: #""((?:ios|lesson)\.[A-Za-z0-9_.\-]*[A-Za-z0-9])""#),
            NSRegularExpression(pattern: #"\bt\(\s*"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9_\-]+)+)""#),
        ]
        var used: Set<String> = []
        var read = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            // Les catalogues eux-mêmes ne sont pas des appels.
            guard !url.path.contains("/Services/I18n/"),
                  let text = try? String(contentsOf: url, encoding: .utf8)
            else { continue }
            read += 1
            for line in text.components(separatedBy: "\n") {
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { continue }
                let range = NSRange(line.startIndex..., in: line)
                for pattern in patterns {
                    for match in pattern.matches(in: line, range: range) {
                        guard let keyRange = Range(match.range(at: 1), in: line) else { continue }
                        used.insert(String(line[keyRange]))
                    }
                }
            }
        }
        guard read > 0 else { throw XCTSkip("aucune source lue") }
        XCTAssertGreaterThan(used.count, 500, "la lecture des sources a raté des clés")

        var missing: [String] = []
        for key in used.sorted() {
            // Les réglages de développement restent derrière `#if DEBUG` : le français et
            // l'anglais leur suffisent.
            let locales: [UiLocale] = key.hasPrefix("ios.debug.") ? [.fr, .en] : UiLocale.allCases
            for locale in locales where !Self.speaks(key, locale) {
                missing.append("\(locale.rawValue) \(key)")
            }
        }
        XCTAssertEqual(missing, [], "clés absentes d'une langue : elles s'afficheraient en anglais, ou telles quelles")
    }

    /// Vrai quand la langue a sa propre phrase pour la clé, sans retomber sur une autre.
    private static func speaks(_ key: String, _ locale: UiLocale) -> Bool {
        if key.hasPrefix("lesson.") {
            return LessonI18nCatalogs.table(for: locale.rawValue)[key] != nil
        }
        if IosI18nCatalogs.table(for: locale.rawValue)[key] != nil { return true }
        return SharedI18nCatalogs.sharedLocales.contains(locale.rawValue)
            && SharedI18nCatalogs.table(for: locale.rawValue)[key] != nil
    }

    /// **Les mêmes `{variables}` dans toutes les langues.** Une traduction qui renomme
    /// `{count}` en `{n}`, ou l'oublie, affiche l'accolade telle quelle, ou un chiffre manquant.
    func testPlaceholdersMatchFrenchInEveryLanguage() {
        var mismatched: [String] = []
        for locale in UiLocale.allCases {
            for (key, value) in IosI18nCatalogs.table(for: locale.rawValue) {
                guard let french = IosI18nCatalogs.fr[key] ?? SharedI18nCatalogs.fr[key] else { continue }
                if Self.placeholders(in: value) != Self.placeholders(in: french) {
                    mismatched.append("\(locale.rawValue) \(key)")
                }
                if value.components(separatedBy: "**").count % 2 == 0 {
                    mismatched.append("\(locale.rawValue) \(key) : un ** sans son pendant")
                }
            }
            for (key, value) in LessonI18nCatalogs.table(for: locale.rawValue) {
                guard let french = LessonI18nCatalogs.fr[key] else { continue }
                if Self.placeholders(in: value) != Self.placeholders(in: french) {
                    mismatched.append("\(locale.rawValue) \(key)")
                }
            }
        }
        XCTAssertEqual(mismatched.sorted(), [])
    }

    /// Les noms des variables du premier niveau : `{name}`, et le `count` de
    /// `{count, plural, one {…} other {…}}` — pas les mots des deux branches.
    static func placeholders(in template: String) -> Set<String> {
        var names: Set<String> = []
        var depth = 0
        var name = ""
        var reading = false
        for character in template {
            if character == "{" {
                depth += 1
                if depth == 1 {
                    name = ""
                    reading = true
                }
                continue
            }
            if character == "}" {
                if depth == 1, reading { names.insert(name) }
                if depth == 1 { reading = false }
                depth = max(0, depth - 1)
                continue
            }
            guard depth == 1, reading else { continue }
            if character == "," {
                names.insert(name)
                reading = false
            } else {
                name.append(character)
            }
        }
        return names
    }

    func testPlaceholderReaderSkipsPluralBranches() {
        XCTAssertEqual(I18nTests.placeholders(in: "{count, plural, one {cours} other {cours}}"), ["count"])
        XCTAssertEqual(I18nTests.placeholders(in: "{used} min sur {total}"), ["used", "total"])
    }

    /// **Un pourcentage s'écrit comme la langue l'écrit.** Les écrans posaient `"\(n) %"` à la
    /// main : l'espace française partout, et le signe du mauvais côté en turc.
    func testPercentFollowsTheLocale() {
        XCTAssertEqual(L10n.percent(42, locale: .en), "42%")
        XCTAssertEqual(L10n.percent(42, locale: .tr), "%42")
        let french = L10n.percent(42, locale: .fr)
        XCTAssertTrue(french.hasPrefix("42"), french)
        XCTAssertTrue(french.hasSuffix("%"), french)
        XCTAssertNotEqual(french, "42%")
        for locale in UiLocale.allCases {
            XCTAssertTrue(L10n.percent(100, locale: locale).contains("%") || L10n.percent(100, locale: locale).contains("٪"), locale.rawValue)
        }
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
