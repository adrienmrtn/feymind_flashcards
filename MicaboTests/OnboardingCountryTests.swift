import SwiftData
import XCTest
@testable import Micabo

/// **Le parcours v2 s'adapte à chaque pays** : les filières et les années, les examens et
/// leur date, les matières dans leur langue, le barème des moyennes ; et l'examen choisi se
/// pose dans le Calendrier.
final class OnboardingCountryTests: XCTestCase {
    private var paris: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        paris.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func year(_ id: String, region: String) -> (SchoolTrack, SchoolYear)? {
        for track in SchoolSystem.tracks(region: region) {
            if let year = track.years.first(where: { $0.id == id }) { return (track, year) }
        }
        return nil
    }

    private func examTitles(_ yearID: String, region: String) -> [String] {
        guard let (track, year) = year(yearID, region: region) else { return [] }
        return SchoolExams.choices(track: track, year: year, tier: track.tier).compactMap {
            if case .named(let exam) = $0 { return exam.title }
            return nil
        }
    }

    // MARK: - Les systèmes scolaires

    /// Chaque pays décrit a ses filières, chaque filière ses années, et chaque identifiant
    /// porte le préfixe de son pays et n'existe qu'une fois : c'est lui qu'on relit.
    func testEveryDescribedCountryHasTracksYearsAndUniqueIDs() {
        var trackIDs: Set<String> = []
        var yearIDs: Set<String> = []
        for region in SchoolSystem.describedRegions {
            let tracks = SchoolSystem.tracks(region: region)
            XCTAssertFalse(tracks.isEmpty, region)
            for track in tracks {
                XCTAssertFalse(track.years.isEmpty, track.id)
                XCTAssertTrue(trackIDs.insert(track.id).inserted, "filière en double : \(track.id)")
                let prefix = region == "GB" ? "uk" : region.lowercased()
                XCTAssertTrue(track.id.hasPrefix(prefix + "."), track.id)
                for year in track.years {
                    XCTAssertTrue(yearIDs.insert(year.id).inserted, "année en double : \(year.id)")
                    XCTAssertFalse(year.title.isEmpty, year.id)
                }
            }
        }
    }

    /// Les pays de la liste sont tous décrits ; « Autre pays » ne l'est que par le pays tapé.
    func testEveryListedCountryIsDescribed() {
        for country in SchoolingCountry.allCases where country != .other {
            XCTAssertTrue(SchoolSystem.isDetailed(country), country.rawValue)
        }
        XCTAssertFalse(SchoolSystem.isDetailed(.other))
        XCTAssertTrue(SchoolSystem.isDetailed(.other, custom: WorldCountry(code: "AT", name: "Österreich")))
        XCTAssertTrue(SchoolSystem.isDetailed(.other, custom: WorldCountry(code: "BR", name: "Brasil")))
        XCTAssertFalse(SchoolSystem.isDetailed(.other, custom: WorldCountry(code: "JP", name: "Japan")))
    }

    /// Chaque examen cité par une année ou une filière existe dans le catalogue.
    func testEveryExamCitedExists() {
        for region in SchoolSystem.describedRegions {
            for track in SchoolSystem.tracks(region: region) {
                for id in track.exams + track.years.flatMap(\.exams) {
                    XCTAssertNotNil(SchoolExams.catalog[id], "\(track.id) cite \(id)")
                }
            }
        }
    }

    // MARK: - Les examens, pays par pays

    func testEachYearProposesItsCountrysExam() {
        XCTAssertEqual(examTitles("fr.3e", region: "FR"), ["Brevet"])
        XCTAssertEqual(examTitles("fr.premiere", region: "FR"), ["Bac de français"])
        XCTAssertEqual(examTitles("fr.terminale", region: "FR"), ["Bac"])
        XCTAssertEqual(examTitles("de.klasse13", region: "DE"), ["Abitur"])
        XCTAssertEqual(examTitles("de.real10", region: "DE"), ["Realschulabschluss (MSA)"])
        XCTAssertEqual(examTitles("at.o4", region: "AT"), ["Matura"])
        XCTAssertEqual(examTitles("it.liceo5", region: "IT"), ["Maturità"])
        XCTAssertEqual(examTitles("it.media3", region: "IT"), ["Esame di terza media", "Prove INVALSI"])
        XCTAssertEqual(examTitles("es.bachCiencias2", region: "ES"), ["PAU (Selectividad)"])
        XCTAssertEqual(examTitles("uk.y11", region: "GB"), ["GCSEs"])
        XCTAssertEqual(examTitles("uk.y13", region: "GB"), ["A-levels"])
        XCTAssertEqual(examTitles("us.hs11", region: "US"), ["SAT", "ACT", "AP Exams", "PSAT/NMSQT"])
        XCTAssertEqual(examTitles("br.m3", region: "BR"), ["ENEM", "Vestibular (Fuvest, Unicamp…)"])
        XCTAssertEqual(examTitles("tr.anadolu.12", region: "TR"), ["YKS"])
        XCTAssertEqual(examTitles("tr.8", region: "TR"), ["LGS"])
        XCTAssertEqual(examTitles("pl.lo4", region: "PL"), ["Matura"])
        XCTAssertEqual(examTitles("pl.sp2", region: "PL"), ["Egzamin ósmoklasisty"])
        XCTAssertEqual(examTitles("ru.s2", region: "RU"), ["ЕГЭ"])
        XCTAssertEqual(examTitles("ru.o5", region: "RU"), ["ОГЭ"])
        XCTAssertEqual(examTitles("ch.gym4", region: "CH").count, 1)
        XCTAssertEqual(examTitles("nl.vwo3", region: "NL"), ["Centraal eindexamen"])
    }

    /// Après les examens du pays : un contrôle à l'école, les partiels après le bac, et
    /// toujours « pas d'examen en vue » en dernier.
    func testTheGenericChoicesFollowTheLevel() throws {
        let (school, terminale) = try XCTUnwrap(year("fr.terminale", region: "FR"))
        let schoolChoices = SchoolExams.choices(track: school, year: terminale, tier: school.tier)
        XCTAssertEqual(schoolChoices.suffix(2), [.test, .noExam])

        let (uni, l2) = try XCTUnwrap(year("fr.l2", region: "FR"))
        let uniChoices = SchoolExams.choices(track: uni, year: l2, tier: uni.tier)
        XCTAssertEqual(uniChoices, [.finals, .noExam])

        let generic = SchoolExams.choices(track: nil, year: nil, tier: .upperSecondary)
        XCTAssertEqual(generic, [.test, .noExam])
    }

    /// **La date proposée est la prochaine session** : le bac de juin qui vient, ou celui de
    /// l'année d'après quand il est passé ; un contrôle dans deux semaines ; rien sans examen.
    func testTheSuggestedDateIsTheNextSession() throws {
        let bac = ExamChoice.named(try XCTUnwrap(SchoolExams.catalog["fr.bac"]))
        XCTAssertEqual(SchoolExams.suggestedDate(for: bac, from: date(2026, 11, 11), calendar: paris), date(2027, 6, 15))
        XCTAssertEqual(SchoolExams.suggestedDate(for: bac, from: date(2027, 6, 20), calendar: paris), date(2028, 6, 15))
        XCTAssertEqual(SchoolExams.suggestedDate(for: .test, from: date(2026, 11, 11), calendar: paris), date(2026, 11, 25))
        XCTAssertNil(SchoolExams.suggestedDate(for: .noExam, from: date(2026, 11, 11), calendar: paris))
        let finals = try XCTUnwrap(SchoolExams.suggestedDate(for: .finals, from: date(2026, 11, 11), calendar: paris))
        XCTAssertEqual(finals, date(2027, 1, 15))
        let sat = ExamChoice.named(try XCTUnwrap(SchoolExams.catalog["us.sat"]))
        XCTAssertEqual(SchoolExams.suggestedDate(for: sat, from: date(2026, 11, 11), calendar: paris), date(2027, 1, 10))
    }

    /// Le temps qui reste s'écrit par le système, avec les pluriels de chaque langue.
    func testTheRemainingTimeIsWrittenByTheSystem() {
        XCTAssertEqual(SchoolExams.remainingText(days: 214, locale: .fr), "7 mois")
        XCTAssertEqual(SchoolExams.remainingText(days: 21, locale: .en), "3 weeks")
        XCTAssertEqual(SchoolExams.remainingText(days: 5, locale: .de), "5 Tage")
        XCTAssertTrue(SchoolExams.remainingText(days: 214, locale: .ru).contains("месяц"))
    }

    /// Mika réagit à l'examen dans chaque langue, en le nommant, sans accolade oubliée.
    func testMikaReactsToTheExamInEveryLanguage() throws {
        let bac = ExamChoice.named(try XCTUnwrap(SchoolExams.catalog["fr.bac"]))
        let now = date(2026, 11, 11)
        for locale in UiLocale.allCases {
            for days in [200, 30, 5] {
                let when = paris.date(byAdding: .day, value: days, to: now)!
                let text = try XCTUnwrap(ExamStepView.reaction(choice: bac, date: when, now: now, locale: locale))
                XCTAssertTrue(text.contains("Bac"), "\(locale.rawValue) \(days) : \(text)")
                XCTAssertFalse(text.contains("{"), "\(locale.rawValue) \(days) : \(text)")
            }
            let none = try XCTUnwrap(ExamStepView.reaction(choice: .noExam, date: nil, locale: locale))
            XCTAssertFalse(none.hasPrefix("ios."), locale.rawValue)
            for choice in [ExamChoice.test, .finals, .noExam] {
                XCTAssertFalse(choice.title(locale: locale).hasPrefix("ios."), "\(locale.rawValue) \(choice)")
            }
        }
        XCTAssertNil(ExamStepView.reaction(choice: nil, date: nil, locale: .fr))
    }

    // MARK: - Les barèmes

    private func scale(_ region: String, track trackID: String?) -> StudentGradeScale {
        let country = SchoolingCountry(rawValue: region == "GB" ? "uk" : region.lowercased()) ?? .other
        let track = trackID.flatMap { id in SchoolSystem.tracks(region: region).first { $0.id == id } }
        return StudentGradeScale.for(region: region, country: country, track: track, locale: .fr)
    }

    func testEachCountryGradesInItsOwnScale() {
        XCTAssertEqual(scale("FR", track: "fr.lyceeGeneral").best, "20/20")
        let oberstufe = scale("DE", track: "de.gymnasium")
        XCTAssertEqual(oberstufe.scale.ticks.map(\.label).first, "05")
        XCTAssertEqual(oberstufe.best, "15")
        XCTAssertEqual(oberstufe.unitKey, "ios.onb5.grade.points")
        let realschule = scale("DE", track: "de.realschule")
        XCTAssertTrue(realschule.lowerIsBetter, "En Allemagne, 1 est la meilleure note")
        XCTAssertEqual(realschule.best, "1,0")
        XCTAssertEqual(scale("GB", track: "uk.gcse").best, "9")
        XCTAssertEqual(scale("GB", track: "uk.alevels").best, "A*")
        XCTAssertEqual(scale("US", track: "us.high").best, "4.0")
        XCTAssertEqual(scale("AT", track: "at.oberstufe").best, "1")
        XCTAssertTrue(scale("AT", track: "at.oberstufe").lowerIsBetter)
        XCTAssertEqual(scale("BR", track: "br.medio").best, "10")
        XCTAssertEqual(scale("IT", track: "it.triennale").best, "30L")
        XCTAssertEqual(scale("IT", track: "it.liceo").best, "10/10")
        XCTAssertEqual(scale("PL", track: "pl.liceum").best, "6")
        XCTAssertEqual(scale("RU", track: "ru.starshaya").best, "5")
        XCTAssertEqual(scale("TR", track: "tr.anadolu").best, "100")

        // Onze crans sur la droite 10–20, du plus faible au meilleur, partout.
        for region in SchoolSystem.describedRegions {
            for track in SchoolSystem.tracks(region: region) {
                let ticks = scale(region, track: track.id).scale.ticks
                XCTAssertEqual(ticks.count, 11, track.id)
                XCTAssertEqual(ticks.map(\.score), Array(TargetScore.min...TargetScore.max), track.id)
            }
        }
    }

    // MARK: - Le modèle

    /// **Un pays choisi dans « Autre pays » a son système** : l'Autriche demande la filière
    /// et l'année, et son palier en découle.
    func testATypedCountryBringsItsSchoolSystem() throws {
        let model = OnboardingModel()
        model.select(country: .other)
        model.customCountry = WorldCountry(code: "AT", name: "Österreich")
        XCTAssertTrue(OnboardingStep.level.isSkipped(for: model.country, custom: model.customCountry))
        XCTAssertFalse(OnboardingStep.year.isSkipped(for: model.country, custom: model.customCountry))
        let track = try XCTUnwrap(model.tracks.first { $0.id == "at.oberstufe" })
        model.track = track
        XCTAssertEqual(model.stage?.tier, .upperSecondary)
        model.year = track.years.last
        XCTAssertEqual(model.examChoices.first, .named(try XCTUnwrap(SchoolExams.catalog["at.matura"])))
        XCTAssertEqual(SchoolSystem.track(id: "at.oberstufe", in: .other)?.id, "at.oberstufe", "Retrouvée par son préfixe")
    }

    /// Changer d'année ou de pays efface l'examen, qui appartenait à l'autre.
    func testTheExamFollowsTheYearAndTheCountry() throws {
        let model = OnboardingModel()
        model.select(country: .fr)
        let lycee = try XCTUnwrap(model.tracks.first { $0.id == "fr.lyceeGeneral" })
        model.track = lycee
        model.year = lycee.years.last
        model.choose(exam: try XCTUnwrap(model.examChoices.first))
        XCTAssertNotNil(model.examChoice)
        XCTAssertNotNil(model.examDate)
        model.year = lycee.years.first
        XCTAssertNil(model.examChoice)
        model.choose(exam: .test)
        model.select(country: .de)
        XCTAssertNil(model.examChoice)
        XCTAssertNil(model.examDate)
    }

    /// L'examen et sa date sont écrits au changement d'écran, et relus à la reprise.
    func testTheExamIsPersistedAndResumed() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let model = OnboardingModel()
        model.displayName = "Lina"
        model.select(country: .fr)
        let lycee = try XCTUnwrap(model.tracks.first { $0.id == "fr.lyceeGeneral" })
        model.track = lycee
        model.year = lycee.years.last
        while model.step != .exam { model.advance() }
        model.choose(exam: try XCTUnwrap(model.examChoices.first))
        let chosen = model.examDate
        model.advance()
        XCTAssertEqual(OnboardingPreferences.examID, "fr.bac")
        XCTAssertEqual(OnboardingPreferences.examDate, chosen)

        let resumed = OnboardingModel.resuming(in: nil)
        XCTAssertEqual(resumed.examChoice?.id, "fr.bac")
        XCTAssertEqual(resumed.examDate, chosen)
    }

    // MARK: - Le Calendrier

    /// **L'examen du parcours devient un examen du Calendrier**, une seule fois, et jamais
    /// pour « pas d'examen en vue ».
    func testTheChosenExamIsPlacedInTheCalendarOnce() throws {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }
        let container = try ModelContainer(for: Course.self, Flashcard.self, ReviewLog.self, Exam.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let now = date(2026, 11, 11)

        OnboardingPreferences.examID = SchoolExams.noneID
        XCTAssertNil(OnboardingExamPlacement.placeIfNeeded(in: context, now: now, locale: .fr, calendar: paris))

        OnboardingPreferences.examID = "fr.bac"
        OnboardingPreferences.examDate = date(2027, 6, 15)
        OnboardingPreferences.targetScore = 16
        let exam = try XCTUnwrap(OnboardingExamPlacement.placeIfNeeded(in: context, now: now, locale: .fr, calendar: paris))
        XCTAssertEqual(exam.name, "Bac")
        XCTAssertEqual(exam.targetScore, 16)
        XCTAssertTrue(paris.isDate(exam.date, inSameDayAs: date(2027, 6, 15)))

        XCTAssertNil(OnboardingExamPlacement.placeIfNeeded(in: context, now: now, locale: .fr, calendar: paris), "Une seule fois")
        XCTAssertEqual(ExamRepository.all(in: context).count, 1)
    }
}
