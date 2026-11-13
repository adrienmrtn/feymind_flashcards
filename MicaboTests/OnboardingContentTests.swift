import XCTest
@testable import Micabo

/// **Ce que le parcours dit, et qu'il le dit vrai** (lot 10).
///
/// Ce qui se vérifie sans écran : chaque phrase existe dans les six langues écrites par ce lot,
/// aucune ne cite un chiffre ou une étude hors de la question d'essai, rien de ce que l'élève
/// tape ne part dans les statistiques, aucun écran n'attend derrière une minuterie ; et chaque
/// élève du cahier des charges voit son école, son examen, son barème.
@MainActor
final class OnboardingContentTests: XCTestCase {
    /// Les six langues écrites par ce lot. Les vingt autres viennent d'un lot de traduction :
    /// `I18nTests.testEveryKeyUsedInTheCodeExistsInEveryLanguage` les réclame.
    private static let languages: [UiLocale] = [.fr, .en, .de, .es, .tr, .ar]

    /// Un jour fixe : les dates proposées et les « dans 7 mois » ne dépendent pas du jour du test.
    private static let now: Date = {
        MicaboCalendar.shared.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 12)) ?? Date()
    }()

    override func setUp() {
        super.setUp()
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
    }

    override func tearDown() {
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
        super.tearDown()
    }

    // MARK: - Les élèves

    /// Un élève, tel que le parcours le connaît à la fin : son pays, sa filière, son année, son
    /// premier examen, ses matières, ses deux moyennes, son temps et son heure.
    private func student(
        name: String = "Lina",
        region: String,
        track trackID: String,
        year yearID: String? = nil,
        subjects: [String],
        current: Int? = 12,
        target: Int? = 16
    ) throws -> OnboardingModel {
        let model = OnboardingModel()
        model.displayName = name
        model.select(worldCountry: try XCTUnwrap(WorldCountries.country(code: region), region))
        let track = try XCTUnwrap(model.tracks.first { $0.id == trackID }, trackID)
        model.track = track
        let year: SchoolYear?
        if let yearID {
            year = track.years.first { $0.id == yearID }
        } else {
            year = track.years.last
        }
        model.year = try XCTUnwrap(year, yearID ?? trackID)
        if let first = model.examChoices.first {
            model.choose(exam: first, now: Self.now)
        }
        model.subjects = Set(subjects)
        model.currentScore = current
        model.targetScore = target
        model.dailyMinutes = 15
        model.studyHour = 18
        return model
    }

    /// Le système met parfois une espace insécable entre un nombre et son unité (« 7 mois »,
    /// « 18 h ») : on compare les mots.
    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func named(_ model: OnboardingModel) -> [String] {
        model.examChoices.compactMap {
            if case .named(let exam) = $0 { return exam.title }
            return nil
        }
    }

    // MARK: - Les phrases, dans les six langues

    /// Chaque phrase du lot existe dans les six langues, celles dont la clé se construit
    /// (les solutions, les crans de temps, les sujets d'exemple) comprises.
    func testEveryPhraseExistsInTheSixLanguages() {
        let french = IosI18nCatalogs.table(for: "fr").filter { $0.key.hasPrefix("ios.onb10.") }
        XCTAssertGreaterThanOrEqual(french.count, 115)

        for locale in Self.languages {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, source) in french {
                let text = table[key] ?? ""
                XCTAssertFalse(text.isEmpty, "\(locale.rawValue) \(key)")
                XCTAssertEqual(
                    text.components(separatedBy: "**").count % 2, 1,
                    "\(locale.rawValue) \(key) : un ** sans son pendant"
                )
                XCTAssertEqual(
                    I18nTests.placeholders(in: text), I18nTests.placeholders(in: source),
                    "\(locale.rawValue) \(key)"
                )
            }
            for worry in StudyWorry.allCases {
                XCTAssertFalse(worry.solutionTitle(locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(worry)")
                XCTAssertFalse(worry.solutionBody(locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(worry)")
            }
            for time in OnboardingDailyTime.allCases {
                XCTAssertFalse(time.title(locale: locale).contains("ios."), "\(locale.rawValue) \(time)")
                XCTAssertTrue(time.title(locale: locale).contains("\(time.rawValue)"), "\(locale.rawValue) \(time)")
            }
            for card in SampleCard.allCases {
                for band in ["lower", "upper", "higher"] {
                    let key = "ios.onb10.lesson.ex.\(card.rawValue).\(band)"
                    XCTAssertFalse((table[key] ?? "").isEmpty, "\(locale.rawValue) \(key)")
                }
            }
            for story in OnboardingStory.allCases {
                let title = L10n.t(story.titleKey, locale: locale)
                XCTAssertFalse(title.hasPrefix("ios."), "\(locale.rawValue) \(story)")
                XCTAssertTrue(title.contains("**"), "\(locale.rawValue) \(story) : une story a son mot-clé")
            }
        }
        XCTAssertEqual(OnboardingStory.allCases.map(\.index), [1, 2, 3, 4])
    }

    /// Les textes de la spécification, tels qu'ils s'affichent en français.
    func testTheFrenchCopyIsTheSpec() {
        func french(_ key: String, _ vars: [String: String] = [:]) -> String {
            L10n.t(key, locale: .fr, vars: vars)
        }
        XCTAssertEqual(french("ios.onb10.story1"), "Ton cours devient une **leçon**. En 30 s.")
        XCTAssertEqual(french("ios.onb10.welcome.title"), "Salut, moi c'est **Mika** !")
        XCTAssertEqual(french("ios.onb10.go"), "C'est parti")
        XCTAssertEqual(french("ios.onb10.q.name"), "Comment je t'appelle ?")
        XCTAssertEqual(french("ios.onb10.q.country", ["name": "Lina"]), "Enchanté, Lina ! Tu étudies dans quel pays ?")
        XCTAssertEqual(french("ios.onb10.q.exam"), "Qu'est-ce qui arrive en premier ?")
        XCTAssertEqual(french("ios.onb10.react.subjects"), "Noté ! Je prépare tes leçons là-dessus.")
        XCTAssertEqual(french("ios.onb10.q.goal"), "Ton **objectif n°1** cette année ?")
        XCTAssertEqual(french("ios.onb10.q.worries"), "Qu'est-ce qui te **bloque** le plus ?")
        XCTAssertEqual(french("ios.onb10.solutions.title", ["name": "Lina"]), "Voilà comment je t'aide, **Lina**")
        XCTAssertEqual(french("ios.onb10.q.target"), "Et tu **vises** combien ?")
        XCTAssertEqual(french("ios.onb10.start.commit"), "Je m'engage")
        XCTAssertEqual(french("ios.onb10.q.lesson"), "Par quel cours on **commence** ?")
        XCTAssertEqual(french("ios.onb10.build.title"), "Je prépare ton plan…")
        XCTAssertEqual(french("ios.onb10.plan.title", ["name": "Lina"]), "Lina, ton plan est **prêt**")
        XCTAssertEqual(french("ios.onb10.trial.cancel"), "Tu annules en 2 touches, quand tu veux")
        XCTAssertEqual(OnboardingDailyTime.fifteen.title(locale: .fr), "15 min · Sérieux")
        XCTAssertEqual(DailyTimeStepView.advised, .fifteen, "Quinze minutes est le cran conseillé")
    }

    // MARK: - Vrai partout

    /// **Aucun chiffre d'utilisateurs, aucune note, aucun pourcentage, aucune étude** dans les
    /// phrases du lot : la seule étude du parcours est celle de la question d'essai, et ses
    /// deux chiffres sont écrits une fois, avec leur source.
    func testNoStudyAndNoFigureOutsideTheSampleCard() throws {
        let bigNumber = try NSRegularExpression(pattern: #"[0-9]{3,}"#)
        for locale in Self.languages {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for (key, text) in table where key.hasPrefix("ios.onb10.") {
                XCTAssertFalse(text.contains("%") || text.contains("٪"), "\(locale.rawValue) \(key) : un pourcentage")
                let range = NSRange(text.startIndex..., in: text)
                XCTAssertNil(bigNumber.firstMatch(in: text, range: range), "\(locale.rawValue) \(key) : un grand nombre")
                for name in ["Karpicke", "Roediger", "Harvard", "Science,"] {
                    XCTAssertFalse(text.localizedCaseInsensitiveContains(name), "\(locale.rawValue) \(key) cite \(name)")
                }
            }
        }

        XCTAssertEqual(SampleCard.retainedByTesting, 80)
        XCTAssertEqual(SampleCard.retainedByRereading, 36)
        XCTAssertTrue(L10n.t("ios.journey.source", locale: .fr).contains("Karpicke"))

        // La source et la phrase de l'étude ne sont appelées que par la question d'essai.
        for (path, text) in try Self.onboardingSources() where !path.hasSuffix("SampleCardStepView.swift") {
            XCTAssertFalse(text.contains("ios.journey.source"), path)
            XCTAssertFalse(text.contains("ios.onb7.card.proof"), path)
        }
    }

    /// **Rien de ce que l'élève tape ne part dans les statistiques** : ni le sujet de sa
    /// première leçon, ni son prénom, ni sa recherche de pays. Les trois réponses de la
    /// première leçon sont des valeurs fixes.
    func testTheTypedTextNeverReachesTheStatistics() throws {
        var firstLesson: [String] = []
        for (path, text) in try Self.onboardingSources() {
            for call in Self.calls(to: "Analytics.track(", in: text) {
                for typed in ["firstLessonTopic", "firstLessonSubject", "displayName", "query", "topic)"] {
                    XCTAssertFalse(call.contains(typed), "\(path) envoie \(typed) : \(call)")
                }
                if call.contains(".onboardingFirstLesson") { firstLesson.append(call) }
            }
        }
        XCTAssertEqual(firstLesson.count, 3)
        for value in ["topic", "import", "later"] {
            XCTAssertEqual(firstLesson.filter { $0.contains(#"["choice": "\#(value)"]"#) }.count, 1, value)
        }
    }

    /// **Aucune attente de mise en scène** : pas de minuterie avant un contenu ou un bouton.
    /// La seule horloge du parcours est celle du chargement du plan.
    func testOnlyTheLoadingScreenHasAClock() throws {
        for (path, text) in try Self.onboardingSources() {
            for (number, line) in text.components(separatedBy: "\n").enumerated() {
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { continue }
                for waiting in ["asyncAfter", "Task.sleep", ".delay(", "repeatForever"] {
                    XCTAssertFalse(line.contains(waiting), "\(path):\(number + 1) attend : \(waiting)")
                }
                for clock in ["Timer.", "TimelineView(", "CADisplayLink("] where line.contains(clock) {
                    XCTAssertTrue(path.hasSuffix("Steps/PlanStepViews.swift"), "\(path):\(number + 1) a une horloge")
                }
            }
        }
        let loading = PlanBuildingStepView.duration + PlanBuildingStepView.hold
        XCTAssertGreaterThanOrEqual(loading, 4, "Le chargement se lit")
        XCTAssertLessThanOrEqual(loading, 5, "Et il ne traîne pas")
    }

    /// Le chargement coche ses lignes une à une, la dernière à cent pour cent.
    func testTheLoadingTicksItsLinesOneByOne() {
        XCTAssertEqual(PlanBuildingStepView.progress(elapsed: 0), 0)
        XCTAssertEqual(PlanBuildingStepView.progress(elapsed: PlanBuildingStepView.duration), 1)
        XCTAssertEqual(PlanBuildingStepView.progress(elapsed: 60), 1, "L'app revenue de l'arrière-plan ne dépasse pas cent")
        XCTAssertGreaterThan(PlanBuildingStepView.progress(elapsed: PlanBuildingStepView.duration / 2), 0.5,
                             "La course part vite et se pose")
        XCTAssertEqual(PlanBuildingStepView.checkedCount(progress: 0, lines: 5), 0)
        XCTAssertEqual(PlanBuildingStepView.checkedCount(progress: 0.2, lines: 5), 1)
        XCTAssertEqual(PlanBuildingStepView.checkedCount(progress: 0.62, lines: 5), 3)
        XCTAssertEqual(PlanBuildingStepView.checkedCount(progress: 0.99, lines: 5), 4)
        XCTAssertEqual(PlanBuildingStepView.checkedCount(progress: 1, lines: 5), 5)
        XCTAssertEqual(PlanBuildingStepView.checkedCount(progress: 1, lines: 0), 0)
    }

    /// **Un rappel n'est promis que s'il peut être envoyé** : notifications refusées, ou essai
    /// trop court pour avoir une veille, l'écran dit ce qui reste vrai.
    func testNoReminderIsPromisedWithoutScheduling() {
        XCTAssertTrue(TrialOfferStepView.canPromise(notificationsAllowed: true, trialDays: 3, now: Self.now))
        XCTAssertFalse(TrialOfferStepView.canPromise(notificationsAllowed: false, trialDays: 3, now: Self.now))
        XCTAssertFalse(TrialOfferStepView.canPromise(notificationsAllowed: true, trialDays: 1, now: Self.now),
                       "Un essai d'un jour n'a pas de veille : rien ne serait posé")

        XCTAssertEqual(TrialOfferStepView.titleKey(canRemind: true), "ios.onb10.trial.remind")
        XCTAssertEqual(TrialOfferStepView.titleKey(canRemind: false), "ios.onb10.trial.anytime")
        XCTAssertEqual(TrialOfferStepView.reassuranceKey(canRemind: false), "ios.onb5.trial.noCharge")

        let refused = L10n.t(TrialOfferStepView.titleKey(canRemind: false), locale: .fr)
        XCTAssertFalse(refused.localizedCaseInsensitiveContains("préviens"), refused)
        XCTAssertFalse(refused.localizedCaseInsensitiveContains("rappel"), refused)
        XCTAssertTrue(L10n.t(TrialOfferStepView.titleKey(canRemind: true), locale: .fr).contains("préviens"))

        // La durée annoncée est celle du produit, et le rappel de cet essai-là se pose bien.
        XCTAssertEqual(OnboardingTrial.days, PaywallCatalog.yearly.trialDays)
        XCTAssertNotNil(TrialEndReminder.fireDate(purchasedAt: Self.now, trialDays: OnboardingTrial.days))
    }

    // MARK: - Adapté au pays et au niveau

    /// **Un lycéen français de terminale** : le Bac, ses matières, des notes sur 20.
    func testAFrenchHighSchoolStudent() throws {
        let lina = try student(region: "FR", track: "fr.lyceeGeneral", year: "fr.terminale",
                               subjects: ["Mathématiques", "Philosophie", "Physique-Chimie"])
        XCTAssertEqual(named(lina).first, "Bac")
        XCTAssertEqual(ExamStepView.rowTitle(.noExam, locale: .fr), "Rien pour l'instant")
        XCTAssertEqual(lina.classLabel, "Terminale")
        XCTAssertTrue(SubjectsStepView.classSubjects(for: lina).contains("Philosophie"))
        XCTAssertTrue(LearningGoal.offered(for: lina.tier).contains(.dreamSchool))

        XCTAssertEqual(
            plain(ExamStepView.reaction(choice: lina.examChoice, date: lina.examDate, now: Self.now, locale: .fr)),
            "Bac dans 7 mois : on a le temps de bien faire."
        )
        XCTAssertEqual(lina.currentLabel(locale: .fr), "12/20")
        XCTAssertEqual(lina.targetLabel(locale: .fr), "16/20")
        XCTAssertEqual(lina.gradeGap(locale: .fr)?.title(locale: .fr), "+4 points : ambitieux, et faisable")

        XCTAssertEqual(plain(OnbWords.day(try XCTUnwrap(lina.examDate), locale: .fr)), "15 juin")
        XCTAssertEqual(
            plain(lina.gradeGap(locale: .fr)?.line(until: lina.examDate, locale: .fr)),
            "12/20 → 16/20 d'ici le 15 juin"
        )
        XCTAssertEqual(plain(StartingPointStepView.title(for: lina, locale: .fr)), "On vise **16/20**\npour le 15 juin")

        lina.firstLessonChoice = .topic
        lina.firstLessonTopic = "La guerre froide"
        let hour = plain(OnbWords.hour(18, locale: .fr)) ?? ""
        XCTAssertEqual(lina.planLines(locale: .fr).map { plain($0) ?? "" }, [
            "Le programme de Terminale",
            "Tes 3 matières",
            "Ton objectif : 12/20 → 16/20",
            "Bac, le 15 juin",
            "15 min par jour, à \(hour)",
            "Ta première leçon : La guerre froide",
        ])
        XCTAssertEqual(lina.planSummary(locale: .fr).map(\.id), ["exam", "subjects", "daily", "goal", "lesson"])
        XCTAssertEqual(lina.planSummary(locale: .fr).first { $0.id == "goal" }?.value, "12/20 → 16/20")
        XCTAssertEqual(FirstLessonStepView.exampleTopic(for: lina, locale: .fr), "Les fonctions affines")
    }

    /// **Une plage de notes se lit de gauche à droite, comme une équation**, en arabe aussi :
    /// un bloc enchâssé de gauche à droite, flèche vers la note visée.
    func testTheGradeRangeReadsLikeAnEquation() {
        XCTAssertEqual(OnbWords.range(from: "12/20", to: "16/20", locale: .fr), "12/20 → 16/20")
        XCTAssertEqual(OnbWords.range(from: "60%", to: "80%", locale: .ar), "\u{202A}60% → 80%\u{202C}")
    }

    /// **Un collégien français est au collège**, même si le palier large envoyé au serveur
    /// est « Lycée » (la France n'a pas de palier collège) : ses objectifs et ses exemples sont
    /// ceux de son âge.
    func testTheTierOfTheScreensIsTheTrackOne() throws {
        let tom = try student(name: "Tom", region: "FR", track: "fr.college", year: "fr.3e", subjects: ["Histoire-Géographie"])
        XCTAssertEqual(tom.tier, .lowerSecondary)
        XCTAssertEqual(tom.stage?.tier, .upperSecondary, "Le palier large ne change pas")
    }

    /// **Un collégien de troisième** : le Brevet, pas de « formation de mes rêves », des
    /// exemples à sa hauteur.
    func testAFrenchMiddleSchoolStudent() throws {
        let tom = try student(name: "Tom", region: "FR", track: "fr.college", year: "fr.3e",
                              subjects: ["Histoire-Géographie"])
        XCTAssertEqual(named(tom), ["Brevet"])
        XCTAssertEqual(tom.classLabel, "Troisième")
        let goals = LearningGoal.offered(for: tom.tier)
        XCTAssertFalse(goals.contains(.dreamSchool))
        XCTAssertFalse(goals.contains(.passYear))
        XCTAssertEqual(FirstLessonStepView.band(for: tom.tier), "lower")
        XCTAssertEqual(FirstLessonStepView.exampleTopic(for: tom, locale: .fr), "La Révolution française")
        XCTAssertEqual(SampleCard.pick(for: tom.subjects).card, .history)
        XCTAssertTrue(NotificationsStepView.message(for: tom, locale: .fr).hasPrefix("Tom, "))
    }

    /// **Une étudiante en licence** : ses partiels, « valider mon année », des exemples du
    /// supérieur.
    func testAFrenchUniversityStudent() throws {
        let ines = try student(name: "Inès", region: "FR", track: "fr.universite", year: "fr.l1",
                               subjects: ["Mathématiques"])
        XCTAssertEqual(named(ines), [], "L'université n'a pas d'examen national")
        XCTAssertEqual(ines.examChoices.first, .finals)
        XCTAssertEqual(ines.examChoice, .finals)
        XCTAssertEqual(ines.classLabel, "Licence 1")
        XCTAssertTrue(LearningGoal.offered(for: ines.tier).contains(.passYear))
        XCTAssertEqual(FirstLessonStepView.band(for: ines.tier), "higher")
        XCTAssertEqual(FirstLessonStepView.exampleTopic(for: ines, locale: .fr), "Les matrices")
        let reaction = try XCTUnwrap(ExamStepView.reaction(choice: ines.examChoice, date: ines.examDate, now: Self.now, locale: .fr))
        XCTAssertTrue(reaction.hasPrefix("Partiels dans "), reaction)
    }

    /// **Une élève de Gymnasium** : l'Abitur, des Notenpunkte, l'allemand.
    func testAGermanGymnasiumStudent() throws {
        let mia = try student(name: "Mia", region: "DE", track: "de.gymnasium", year: "de.klasse12",
                              subjects: ["Mathematik", "Deutsch"])
        XCTAssertEqual(named(mia), ["Abitur"])
        XCTAssertEqual(mia.gradeScale.unitKey, "ios.onb5.grade.points")
        XCTAssertEqual(mia.currentLabel(locale: .de), "07")
        XCTAssertEqual(mia.targetLabel(locale: .de), "11")
        XCTAssertEqual(mia.gradeGap(locale: .de)?.title(locale: .de), "+4 Punkte: ehrgeizig und machbar")
        let reaction = try XCTUnwrap(ExamStepView.reaction(choice: mia.examChoice, date: mia.examDate, now: Self.now, locale: .de))
        XCTAssertTrue(reaction.hasPrefix("Abitur: noch "), reaction)
        XCTAssertTrue(StartingPointStepView.title(for: mia, locale: .de).contains("**11**"))
        XCTAssertEqual(mia.planLines(locale: .de).first, "Lehrplan: 12. Klasse")
    }

    /// **Un lycéen américain** : le SAT, une moyenne en GPA, et un écart dit dans ce barème.
    func testAnAmericanHighSchoolStudent() throws {
        let sam = try student(name: "Sam", region: "US", track: "us.high", year: "us.hs12",
                              subjects: ["Chemistry"], current: 14, target: 17)
        XCTAssertEqual(named(sam), ["SAT", "ACT", "AP Exams"])
        XCTAssertEqual(sam.currentLabel(locale: .en), "3.0")
        XCTAssertEqual(sam.targetLabel(locale: .en), "3.7")
        XCTAssertEqual(sam.gradeGap(locale: .en)?.title(locale: .en), "+0.7: ambitious, and doable")
        XCTAssertEqual(SampleCard.pick(for: sam.subjects).card, .chemistry)
        XCTAssertEqual(FirstLessonStepView.exampleTopic(for: sam, locale: .en), "Acid-base reactions")
    }

    /// **L'Espagne, l'Italie, le Maroc** : la PAU, la Maturità, le Bac national.
    func testSpanishItalianAndMoroccanStudents() throws {
        let lucia = try student(name: "Lucía", region: "ES", track: "es.bachCiencias", year: "es.bachCiencias2",
                                subjects: ["Matemáticas"], current: 10, target: 14)
        XCTAssertEqual(named(lucia), ["PAU (Selectividad)"])
        XCTAssertEqual(lucia.gradeGap(locale: .es)?.title(locale: .es), "+2 puntos: ambicioso, y posible")

        let marco = try student(name: "Marco", region: "IT", track: "it.liceo", year: "it.liceo5",
                                subjects: ["Matematica"])
        XCTAssertEqual(named(marco), ["Maturità"])

        let yasmine = try student(name: "Yasmine", region: "MA", track: "ma.lycee", year: "ma.2bac",
                                  subjects: ["Mathématiques"])
        XCTAssertEqual(yasmine.country, .ma)
        XCTAssertEqual(named(yasmine), ["Bac national"])
        XCTAssertEqual(yasmine.currentLabel(locale: .fr), "12/20")
    }

    /// **Une élève saoudienne**, arrivée par la recherche de pays : ses filières et ses examens
    /// en arabe, un barème en pourcentage.
    func testASaudiStudent() throws {
        let noura = try student(name: "نورة", region: "SA", track: "sa.thanawi", year: "sa.t3",
                                subjects: [])
        XCTAssertEqual(noura.country, .other)
        XCTAssertEqual(noura.customCountry?.code, "SA")
        XCTAssertEqual(named(noura), ["اختبار القدرات العامة", "الاختبار التحصيلي"])
        XCTAssertFalse(SubjectsStepView.classSubjects(for: noura).isEmpty)

        let gap = try XCTUnwrap(noura.gradeGap(locale: .ar))
        XCTAssertNotNil(gap.amount, "Un pourcentage se compte")
        XCTAssertFalse(gap.title(locale: .ar).contains("{"))
        let reaction = try XCTUnwrap(ExamStepView.reaction(choice: noura.examChoice, date: noura.examDate, now: Self.now, locale: .ar))
        XCTAssertTrue(reaction.contains("اختبار القدرات العامة"), reaction)
        for line in noura.planLines(locale: .ar) {
            XCTAssertFalse(line.contains("{") || line.contains("ios."), line)
        }
    }

    // MARK: - L'écart entre les deux moyennes

    /// L'écart se chiffre là où il se compte, et se dit sans chiffre ailleurs.
    func testTheGradeGapSpeaksTheStudentsScale() throws {
        let lina = try student(region: "FR", track: "fr.lyceeGeneral", subjects: ["Philosophie"], current: 14, target: 14)
        XCTAssertEqual(lina.gradeGap(locale: .fr)?.size, .hold)
        XCTAssertEqual(lina.gradeGap(locale: .fr)?.title(locale: .fr), "Tenir 14/20 : je t'aide à rester régulier")

        lina.targetScore = 15
        XCTAssertEqual(lina.gradeGap(locale: .fr)?.title(locale: .fr), "+1 point : un petit pas, tout à fait faisable")
        lina.currentScore = 10
        lina.targetScore = 18
        XCTAssertEqual(lina.gradeGap(locale: .fr)?.title(locale: .fr), "+8 points : un vrai défi. On y va étape par étape")

        // Sous le barème, l'écart ne se chiffre pas : « Moins de 10/20 » n'est pas un nombre.
        lina.currentScore = DesiredGradeScale.belowScore
        lina.targetScore = 12
        let below = try XCTUnwrap(lina.gradeGap(locale: .fr))
        XCTAssertNil(below.amount)
        XCTAssertEqual(below.title(locale: .fr), "Ambitieux, et faisable")
        XCTAssertEqual(lina.currentLabel(locale: .fr), "Moins de 10/20")

        // Des lettres : pas de « +3 ».
        let uk = try student(region: "GB", track: "uk.alevels", subjects: ["Maths"], current: 12, target: 16)
        XCTAssertNil(uk.gradeGap(locale: .en)?.amount)
        XCTAssertEqual(uk.gradeGap(locale: .en)?.title(locale: .en), "Ambitious, and doable")

        // La meilleure note est la plus petite : « +1,3 » voudrait dire le contraire.
        let real = try student(region: "DE", track: "de.realschule", subjects: ["Mathematik"], current: 12, target: 16)
        XCTAssertTrue(real.gradeScale.lowerIsBetter)
        XCTAssertNil(real.gradeGap(locale: .de)?.amount)

        XCTAssertNil(OnboardingModel().gradeGap(locale: .fr), "Sans les deux moyennes, pas d'écart")
    }

    /// La lecture d'une note : un nombre, son barème, sa virgule ; ou rien.
    func testReadingAGrade() {
        XCTAssertEqual(OnboardingGradeGap.number(in: "12/20")?.value, 12)
        XCTAssertEqual(OnboardingGradeGap.number(in: "12/20")?.denominator, "20")
        XCTAssertEqual(OnboardingGradeGap.number(in: "3.7")?.value, 3.7)
        XCTAssertEqual(OnboardingGradeGap.number(in: "2,7")?.value, 2.7)
        XCTAssertEqual(OnboardingGradeGap.number(in: "2,7")?.usesComma, true)
        XCTAssertEqual(OnboardingGradeGap.number(in: "08")?.value, 8)
        XCTAssertEqual(OnboardingGradeGap.number(in: "60 %")?.value, 60)
        XCTAssertNil(OnboardingGradeGap.number(in: "B+"))
        XCTAssertNil(OnboardingGradeGap.number(in: "2:1"))
        XCTAssertNil(OnboardingGradeGap.number(in: "30L"))
        XCTAssertNil(OnboardingGradeGap.number(in: ""))
    }

    // MARK: - Ce que le plan affiche

    /// **Une information absente retire sa ligne** : le plan ne remplit pas un vide.
    func testThePlanDropsWhatTheStudentDidNotSay() throws {
        let model = OnboardingModel()
        model.select(country: .other)
        model.examChoice = .noExam
        model.dailyMinutes = 10

        let hour = OnbWords.hour(DailyReminder.defaultHour, locale: .fr)
        XCTAssertEqual(model.planLines(locale: .fr), ["10 min par jour, à \(hour)"])
        XCTAssertEqual(model.planSummary(locale: .fr).map(\.id), ["daily"])
        XCTAssertNil(model.datedExam)
        XCTAssertNil(model.examName(locale: .fr))

        // Sans année connue, le palier se dit sans article.
        model.stage = try XCTUnwrap(SchoolingCountry.other.stages.first)
        XCTAssertEqual(model.planLines(locale: .fr).first, "Ton niveau : \(try XCTUnwrap(model.classLabel))")

        model.subjects = ["Biology"]
        XCTAssertTrue(model.planLines(locale: .fr).contains("Ta matière"))
        model.firstLessonChoice = .importSource
        XCTAssertEqual(model.planLines(locale: .fr).last, "Ta première leçon : ton cours à importer")
        XCTAssertEqual(model.planSummary(locale: .fr).last?.value, "Ton cours à importer")
    }

    /// Le titre de la projection suit ce que l'élève a dit : sa note et son examen, ou moins.
    func testTheProjectionTitleFollowsTheAnswers() throws {
        let lina = try student(region: "FR", track: "fr.lyceeGeneral", subjects: ["Philosophie"])
        XCTAssertEqual(plain(StartingPointStepView.title(for: lina, locale: .fr)), "On vise **16/20**\npour le 15 juin")

        lina.examChoice = .noExam
        let horizon = OnbWords.duration(days: StartingPointStepView.openHorizonDays, locale: .fr)
        XCTAssertEqual(plain(horizon), "3 mois")
        XCTAssertEqual(plain(StartingPointStepView.title(for: lina, locale: .fr)), "On vise **16/20**\nd'ici 3 mois")

        lina.currentScore = nil
        lina.targetScore = nil
        XCTAssertEqual(StartingPointStepView.title(for: lina, locale: .fr), "On vise **haut**")

        let exam = try XCTUnwrap(lina.examChoices.first)
        lina.choose(exam: exam, now: Self.now)
        XCTAssertEqual(StartingPointStepView.title(for: lina, locale: .fr), "**Bac** : on vise haut")
    }

    /// Mika réagit à ce qui arrive en premier : loin, bientôt, un contrôle, ou rien.
    func testMikaReactsToWhatComesFirst() throws {
        let bac = ExamChoice.named(try XCTUnwrap(SchoolExams.catalog["fr.bac"]))
        let soon = try XCTUnwrap(MicaboCalendar.shared.date(byAdding: .day, value: 12, to: Self.now))
        let far = try XCTUnwrap(MicaboCalendar.shared.date(byAdding: .day, value: 200, to: Self.now))

        XCTAssertEqual(plain(ExamStepView.reaction(choice: bac, date: soon, now: Self.now, locale: .fr)),
                       "Bac dans 12 jours : on s'y met tout de suite !")
        XCTAssertEqual(plain(ExamStepView.reaction(choice: bac, date: far, now: Self.now, locale: .fr)),
                       "Bac dans 7 mois : on a le temps de bien faire.")
        XCTAssertEqual(ExamStepView.reaction(choice: .test, date: soon, now: Self.now, locale: .fr),
                       "Un contrôle ? Je te prépare ça.")
        XCTAssertEqual(ExamStepView.reaction(choice: .noExam, date: nil, now: Self.now, locale: .fr),
                       "Parfait : on avance à ton rythme.")
        XCTAssertNil(ExamStepView.reaction(choice: nil, date: nil, locale: .fr))
        XCTAssertEqual(ExamStepView.soonDays, 30)
    }

    /// L'exemple de rappel est fait des réponses de l'élève : son prénom, les cartes de son
    /// temps par jour, sa première matière.
    func testTheReminderExampleIsMadeOfTheAnswers() throws {
        let lina = try student(region: "FR", track: "fr.lyceeGeneral", subjects: ["Philosophie"])
        let message = NotificationsStepView.message(for: lina, locale: .fr)
        XCTAssertEqual(message, "Lina, \(lina.cardsPerDay) cartes à revoir en Philosophie. 15 min ?")
        XCTAssertEqual(lina.cardsPerDay, DailyLoad.newCardsPerDay(dailyMinutes: 15))

        lina.examChoice = .test
        XCTAssertTrue(NotificationsStepView.message(for: lina, locale: .fr).contains("avant ton contrôle"))

        lina.subjects = []
        let plain = NotificationsStepView.message(for: lina, locale: .fr)
        XCTAssertFalse(plain.contains("Lina"), "Sans matière, pas de phrase à trous")
        XCTAssertFalse(plain.contains("{"))
        XCTAssertEqual(NotificationsStepView.hours.first, 5)
        XCTAssertEqual(NotificationsStepView.hours.last, 23)
    }

    /// L'examen de la dernière story est celui du pays détecté, tel qu'il se nomme là-bas.
    func testTheStoryNamesTheExamOfTheCountry() {
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "FR"), "Bac")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "DE"), "Abitur")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "ES"), "PAU (Selectividad)")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "IT"), "Maturità")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "US"), "SAT")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "GB"), "A-levels")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "MA"), "Bac national")
        XCTAssertEqual(StoriesStepView.flagshipExam(region: "SA"), "اختبار القدرات العامة")
        XCTAssertNil(StoriesStepView.flagshipExam(region: "JP"), "Un pays qu'on ne décrit pas n'a pas d'examen inventé")
        XCTAssertNil(StoriesStepView.flagshipExam(region: nil))
    }

    // MARK: - La question d'essai

    func testTheSampleCardFollowsTheStudentsSubjects() {
        XCTAssertEqual(SampleCard.pick(for: ["Mathématiques"]).card, .math)
        XCTAssertEqual(SampleCard.pick(for: ["Mathematik", "Deutsch"]).card, .math, "Dans l'ordre alphabétique : Deutsch se lit d'abord, sans question")
        XCTAssertEqual(SampleCard.pick(for: ["SVT"]).card, .biology)
        XCTAssertEqual(SampleCard.pick(for: ["Chemistry"]).card, .chemistry)
        XCTAssertEqual(SampleCard.pick(for: ["Physique-Chimie"]).card, .chemistry)
        XCTAssertEqual(SampleCard.pick(for: ["Histoire-Géographie"]).card, .history)
        XCTAssertEqual(SampleCard.pick(for: ["Philosophie"]).card, .philosophy)

        // La pastille montre la matière cochée, pas celle de la question.
        XCTAssertEqual(SampleCard.pick(for: ["Statistiques"]).subject, "Statistiques")
    }

    /// Des langues vivantes seulement : la question devient de la culture générale. Proposer
    /// « Mathématiques » à qui ne l'a pas cochée serait une incohérence.
    func testNoSubjectTheStudentDidNotPick() {
        let pick = SampleCard.pick(for: ["Anglais", "Espagnol"])
        XCTAssertEqual(pick.subject, "Culture générale")
        XCTAssertFalse(["Anglais", "Espagnol"].contains(pick.card.catalogSubject))
        XCTAssertEqual(SampleCard.pick(for: []).subject, "Culture générale")
    }

    func testTheRightAnswerIsNeverShownFirst() {
        for card in SampleCard.allCases {
            XCTAssertEqual(Set(card.displayOrder), [0, 1, 2], "\(card)")
            XCTAssertNotEqual(card.displayOrder.first, 0, "\(card) : la bonne réponse en tête se devine")
            XCTAssertTrue(card.isRight(0))
            XCTAssertFalse(card.isRight(1))
        }
    }

    func testEverySampleCardSpeaksEveryLanguage() {
        for locale in UiLocale.allCases {
            let table = IosI18nCatalogs.table(for: locale.rawValue)
            for card in SampleCard.allCases {
                XCTAssertFalse((table[card.questionKey] ?? "").isEmpty, "\(locale.rawValue) \(card.questionKey)")
                for option in 0..<3 {
                    let text = card.option(option, locale: locale)
                    XCTAssertFalse(text.hasPrefix("ios."), "\(locale.rawValue) \(card) \(option)")
                }
            }
            for key in ["ios.onb7.card.proof", "ios.journey.source", "ios.onb7.notif.one"] {
                XCTAssertFalse((table[key] ?? "").isEmpty, "\(locale.rawValue) \(key)")
            }
            XCTAssertTrue((table["ios.onb7.card.proof"] ?? "").contains("{testing}"), locale.rawValue)
            XCTAssertTrue((table["ios.onb7.card.proof"] ?? "").contains("{reread}"), locale.rawValue)
        }
    }

    // MARK: - Une question, une fois

    /// L'objectif n°1 ne redemande pas l'examen : il vient d'être dit, et il s'ajoute de
    /// lui-même à ce que le cloud garde.
    func testTheGoalIsReadFromTheExamInsteadOfAskedTwice() {
        for tier in EducationTier.allCases.map(Optional.some) + [nil] {
            XCTAssertFalse(LearningGoal.offered(for: tier).contains(.exam), "\(String(describing: tier))")
            XCTAssertFalse(LearningGoal.offered(for: tier).contains(.lectures), "\(String(describing: tier))")
        }

        let model = OnboardingModel()
        XCTAssertEqual(model.learningGoals, [])
        model.examChoice = .noExam
        XCTAssertEqual(model.learningGoals, [.lectures])
        let dated = SchoolExams.choices(track: nil, year: nil, tier: nil).first { $0.hasDate }
        if let dated {
            model.examChoice = dated
            XCTAssertEqual(model.learningGoals, [.exam])
        }
        model.goals = [.grades]
        XCTAssertEqual(model.learningGoals, dated == nil ? [.grades, .lectures] : [.grades, .exam])
    }

    // MARK: - L'essai, daté

    func testTheTrialTimelineNamesRealDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Paris"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: 18)))
        let steps = TrialTimeline.milestones(from: start, calendar: calendar, locale: .fr)
        XCTAssertEqual(steps[1].title, "13 novembre : un rappel", "Le rappel part la veille de la fin, comme TrialEndReminder")
        XCTAssertEqual(steps[2].title, "14 novembre : ton abonnement commence")

        let fire = try XCTUnwrap(TrialEndReminder.fireDate(purchasedAt: start, trialDays: TrialTimeline.freeDays))
        XCTAssertEqual(calendar.component(.day, from: fire), 13, "La date affichée et celle du rappel sont la même")
    }

    // MARK: - Les sources

    /// Les fichiers du parcours, relus depuis les sources.
    private static func onboardingSources() throws -> [(path: String, text: String)] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo/Features/Onboarding", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        var found: [(String, String)] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            // Les cours de démonstration sont du contenu, pas des écrans ; `DeckSetupKit` est
            // le gabarit de la création d'un deck, pas du parcours.
            guard !url.path.contains("/Demo/"), url.lastPathComponent != "DeckSetupKit.swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            found.append((url.path.replacingOccurrences(of: root.path + "/", with: ""), text))
        }
        guard !found.isEmpty else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
        return found
    }

    /// Chaque appel à `name`, de sa parenthèse ouvrante à celle qui la ferme.
    private static func calls(to name: String, in text: String) -> [String] {
        var calls: [String] = []
        var search = text.startIndex
        while let found = text.range(of: name, range: search..<text.endIndex) {
            var depth = 1
            var index = found.upperBound
            while index < text.endIndex, depth > 0 {
                if text[index] == "(" { depth += 1 }
                if text[index] == ")" { depth -= 1 }
                index = text.index(after: index)
            }
            calls.append(String(text[found.lowerBound..<index]))
            search = index
        }
        return calls
    }
}
