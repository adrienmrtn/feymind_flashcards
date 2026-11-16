import XCTest
@testable import Micabo

/// **Lot 14** : le maintien de l'engagement, le curseur du temps, « je ne suis pas juste
/// ChatGPT », le prix à la semaine.
final class OnboardingLot14Tests: XCTestCase {
    override func tearDown() {
        OnboardingPreferences.reset()
        super.tearDown()
    }

    // MARK: - Le maintien

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    /// **Un appui bref n'engage jamais** (« on a juste appuyé une fois »).
    func testAShortTapNeverCommits() {
        var hold = CommitHold()
        hold.press(at: start)
        XCTAssertFalse(hold.release(at: start.addingTimeInterval(0.1)))
        XCTAssertNil(hold.pressedAt)
        // L'horloge qui continue après le lever ne signe rien.
        XCTAssertFalse(hold.tick(at: start.addingTimeInterval(5)))
    }

    /// **Un geste annulé** (le défilement l'a repris) n'engage pas, même si l'horloge tourne.
    func testACancelledGestureNeverCommits() {
        var hold = CommitHold()
        hold.press(at: start)
        XCTAssertFalse(hold.tick(at: start.addingTimeInterval(0.4)))
        hold.cancel()
        XCTAssertFalse(hold.tick(at: start.addingTimeInterval(3)))
        XCTAssertEqual(hold.progress(at: start.addingTimeInterval(3)), 0)
    }

    /// **Seul un maintien d'une seconde et demie engage**, que l'horloge le constate doigt posé
    /// ou que le doigt se lève juste après.
    func testOnlyAFullHoldCommits() {
        XCTAssertEqual(CommitHold.duration, 1.5)
        var hold = CommitHold()
        hold.press(at: start)
        XCTAssertFalse(hold.tick(at: start.addingTimeInterval(1.4)))
        XCTAssertEqual(hold.progress(at: start.addingTimeInterval(0.75)), 0.5, accuracy: 0.001)
        XCTAssertTrue(hold.tick(at: start.addingTimeInterval(1.5)))

        var lifted = CommitHold()
        lifted.press(at: start)
        XCTAssertTrue(lifted.release(at: start.addingTimeInterval(1.6)))

        var early = CommitHold()
        early.press(at: start)
        XCTAssertFalse(early.release(at: start.addingTimeInterval(1.49)))
    }

    /// Un second appui pendant le maintien ne le relance pas.
    func testASecondPressDoesNotRestartTheHold() {
        var hold = CommitHold()
        hold.press(at: start)
        hold.press(at: start.addingTimeInterval(1))
        XCTAssertTrue(hold.tick(at: start.addingTimeInterval(1.5)))
    }

    // MARK: - Le temps par jour

    /// **De 5 minutes à 2 heures** : 5 minutes jusqu'à une demi-heure, puis 15 minutes ; un mot
    /// qui qualifie chaque cran, dans toutes les langues.
    func testTheDailyTimeSliderGoesToTwoHours() {
        XCTAssertEqual(DailyLoad.steps, [5, 10, 15, 20, 25, 30, 45, 60, 75, 90, 105, 120])
        XCTAssertEqual(DailyTimeStepView.qualifierKey(5), "ios.onb10.time.5")
        XCTAssertEqual(DailyTimeStepView.qualifierKey(15), "ios.onb10.time.15")
        XCTAssertEqual(DailyTimeStepView.qualifierKey(45), "ios.onb10.time.30")
        XCTAssertEqual(DailyTimeStepView.qualifierKey(120), "ios.onb16.time.max")
        for locale in UiLocale.allCases {
            for minutes in DailyLoad.steps {
                XCTAssertFalse(L10n.t(DailyTimeStepView.qualifierKey(minutes), locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(minutes)")
                XCTAssertFalse(DailyTimeStepView.duration(minutes, locale: locale).isEmpty)
            }
        }
        XCTAssertFalse(OnboardingStep.dailyTime.advancesOnChoice, "Un curseur a son bouton")
    }

    // MARK: - « Je ne suis pas juste ChatGPT »

    /// **La première ligne dit sa classe**, sans chiffre ; sans classe, une phrase pour tous.
    // MARK: - Le prix

    /// **Le prix à la semaine pour tout le monde** (décision du fondateur), sauf variante
    /// forcée depuis les réglages de test.
    func testTheWeeklyPriceIsShownByDefault() {
        let saved = PriceDisplay.forced(in: .standard)
        defer { PriceDisplay.setOverride(saved) }
        PriceDisplay.setOverride(nil)
        XCTAssertEqual(PriceDisplay.current, .weekly)
        PriceDisplay.setOverride(.monthly)
        XCTAssertEqual(PriceDisplay.current, .monthly)
    }

    /// **La somme facturée reste écrite** à côté du prix à la semaine, et redite sous le bouton.
    func testTheBilledAmountStaysWritten() {
        let yearly = PaywallCatalog.yearly
        XCTAssertTrue(yearly.caption.contains(yearly.displayPrice), yearly.caption)
        XCTAssertTrue(PaywallCopy.legal(for: yearly, locale: .fr).contains(yearly.displayPrice))
        let discount = PaywallCatalog.discount
        XCTAssertTrue(discount.caption.contains(discount.displayPrice), discount.caption)
    }

    /// **Les lignes du tableau du paywall ne promettent pas l'illimité** : le serveur plafonne.
    func testThePaywallTableNeverPromisesUnlimited() {
        for locale in [UiLocale.fr, .en, .de, .es] {
            for feature in PaywallFeature.allCases {
                let title = L10n.t(feature.titleKey, locale: locale).lowercased()
                for word in ["illimit", "unlimited", "unbegrenzt", "ilimitad", "sans limite", "à volonté"] {
                    XCTAssertFalse(title.contains(word), "\(locale.rawValue) \(feature) : \(title)")
                }
            }
        }
    }

    // MARK: - Lot 16 : l'écran des matières

    /// **Plus de livre générique** sur les matières courantes : une icône par domaine, la même
    /// pour toutes les langues étrangères, la plume pour la langue du pays.
    func testEverySubjectHasAMeaningfulIcon() {
        let cases: [(String, SchoolingCountry, MicaboIcon)] = [
            ("Médecine", .fr, .health), ("Pharmacie", .fr, .health), ("Kinésithérapie", .fr, .health),
            ("SES", .fr, .economy), ("Business", .uk, .economy), ("NSI", .fr, .computer),
            ("Computer Science", .us, .computer), ("Sciences de l'ingénieur", .fr, .engineering),
            ("Technologie", .fr, .engineering), ("HGGSP", .fr, .politics), ("Government", .us, .politics),
            ("Politik und Wirtschaft", .de, .politics), ("Astronomie", .fr, .astronomy),
            ("Statistiques", .fr, .statistics), ("Géologie", .fr, .globe), ("HLP", .fr, .quill),
            ("Anglais", .fr, .language), ("Französisch", .de, .language), ("LLCER", .fr, .language),
            ("Français", .fr, .quill), ("Deutsch", .de, .quill), ("Mathématiques", .fr, .calculator),
        ]
        for (subject, country, icon) in cases {
            XCTAssertEqual(OnbSubjectGroup.icon(for: subject, country: country), icon, subject)
        }
        for subject in SubjectCatalog.allSubjects {
            XCTAssertNotEqual(OnbSubjectGroup.icon(for: subject, country: .fr), .book, "\(subject) : livre générique")
        }
    }

    /// **Le tronc commun d'abord** : les maths, la langue du pays, les sciences,
    /// l'histoire-géographie, la philosophie, puis les spécialités.
    func testMainSubjectsStartWithTheCoreCurriculum() {
        let terminale = ["Philosophie", "Histoire-Géographie", "Enseignement scientifique", "Mathématiques",
                         "Maths complémentaires", "Physique-Chimie", "SVT", "SES", "HGGSP", "NSI"]
        XCTAssertEqual(OnbSubjectGroup.ordered(terminale, country: .fr), [
            "Mathématiques", "Enseignement scientifique", "Physique-Chimie", "SVT", "Histoire-Géographie",
            "Philosophie", "Maths complémentaires", "SES", "HGGSP", "NSI",
        ])
        XCTAssertEqual(OnbSubjectGroup.ordered(["Geschichte", "Physik", "Deutsch", "Mathematik"], country: .de),
                       ["Mathematik", "Deutsch", "Physik", "Geschichte"])
    }
}
