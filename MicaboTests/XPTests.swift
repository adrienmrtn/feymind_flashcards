import XCTest
@testable import Micabo

/// **L'XP, l'objectif du jour et la ligue de la semaine** (`XPMath`, `XPStore`), jumeaux de
/// `web/packages/core/src/xp.ts` : les mêmes cas que `xp.test.ts`, plus le magasin.
///
/// Tout passe par un `UserDefaults` à part et un calendrier fixe en UTC. Le calendrier commence
/// la semaine le **dimanche** : la semaine de la ligue doit commencer le lundi quand même.
final class XPTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "micabo.tests.xp"

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }()

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        super.tearDown()
    }

    private func date(_ day: Int, month: Int = 11, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func store(at date: @escaping () -> Date) -> XPStore {
        XPStore(defaults: defaults, calendar: calendar, now: date)
    }

    // MARK: Le contrat

    func testTheNumbersAreTheContract() {
        XCTAssertEqual(XPReason.correctAnswer.points, 10)
        XCTAssertEqual(XPReason.wrongAnswer.points, 2)
        XCTAssertEqual(XPReason.cardReviewed.points, 3)
        XCTAssertEqual(XPReason.circleCompleted.points, 25)
        XCTAssertEqual(XPReason.lessonCreated.points, 30)
        XCTAssertEqual(XPReason.mockExamFinished.points, 60)
        XCTAssertEqual(XPReason.mikaAnswer.points, 5)
        XCTAssertEqual(XPReason.exerciseSolved.points, 15)
        XCTAssertEqual(XPReason.focusSession.points, 40)
        XCTAssertEqual(XPRules.dailyGoal, 50)
        XCTAssertEqual(XPRules.dailyCap, 5000)
        XCTAssertEqual(XPRules.focusMinutes, 25)
        XCTAssertEqual(XPRules.leagues.map(\.id), ["bronze", "silver", "gold", "sapphire", "diamond"])
        XCTAssertEqual(XPRules.leagues.map(\.floor), [0, 200, 500, 1000, 2000])
    }

    // MARK: La semaine

    func testTheWeekStartsOnMonday() {
        // Mercredi 11 novembre 2026.
        XCTAssertEqual(XPMath.weekStart(date(11), calendar: calendar), "2026-11-09")
        // Un dimanche appartient à la semaine commencée six jours plus tôt.
        XCTAssertEqual(XPMath.weekStart(date(15), calendar: calendar), "2026-11-09")
        XCTAssertEqual(XPMath.weekStart(date(9, hour: 0), calendar: calendar), "2026-11-09")
        XCTAssertEqual(XPMath.weekStart(date(16, hour: 0), calendar: calendar), "2026-11-16")
        // Par-dessus un changement de mois.
        XCTAssertEqual(XPMath.weekStart(date(1), calendar: calendar), "2026-10-26")
    }

    func testDaysLeftCountsUntilMondayMidnight() {
        XCTAssertEqual(XPMath.daysLeftInWeek(date(9), calendar: calendar), 7)
        XCTAssertEqual(XPMath.daysLeftInWeek(date(11), calendar: calendar), 5)
        XCTAssertEqual(XPMath.daysLeftInWeek(date(15, hour: 23), calendar: calendar), 1)
    }

    func testTheDayAndTheWeekAddUp() {
        var ledger = XPMath.add([:], 10, at: date(8), calendar: calendar) // le dimanche d'avant
        ledger = XPMath.add(ledger, 25, at: date(9), calendar: calendar)
        ledger = XPMath.add(ledger, 15, at: date(11), calendar: calendar)
        let now = date(11, hour: 18)
        XCTAssertEqual(XPMath.today(ledger, now: now, calendar: calendar), 15)
        XCTAssertEqual(XPMath.thisWeek(ledger, now: now, calendar: calendar), 40)
    }

    // MARK: Le plafond

    func testADayIsCapped() {
        let ledger = XPMath.add(["2026-11-11": XPRules.dailyCap - 5], 100, at: date(11), calendar: calendar)
        XCTAssertEqual(ledger["2026-11-11"], XPRules.dailyCap)
        XCTAssertEqual(XPMath.add([:], -40, at: date(11), calendar: calendar)["2026-11-11"], 0)
    }

    func testTheStoreStopsAtTheCapAndCountsOnlyWhatItAdds() {
        let xp = store { self.date(11) }
        XCTAssertEqual(xp.award(points: XPRules.dailyCap - 4).added, XPRules.dailyCap - 4)
        XCTAssertEqual(xp.award(.correctAnswer).added, 4)
        XCTAssertEqual(xp.award(.correctAnswer), XPAward.zero)
        XCTAssertEqual(xp.today, XPRules.dailyCap)
        XCTAssertEqual(xp.lifetime, XPRules.dailyCap)
    }

    // MARK: Le journal

    func testOldDaysArePruned() {
        let pruned = XPMath.prune(["2026-10-01": 50, "2026-11-10": 20], now: date(11), calendar: calendar)
        XCTAssertEqual(pruned, ["2026-11-10": 20])
        // Quinze jours exactement en arrière, c'est déjà trop vieux ; quatorze, non.
        let edge = XPMath.prune(["2026-10-27": 1, "2026-10-28": 2], now: date(11), calendar: calendar)
        XCTAssertEqual(edge, ["2026-10-28": 2])
    }

    func testTheStorePrunesButKeepsTheLifetimeTotal() {
        var now = date(1)
        let xp = store { now }
        xp.award(.lessonCreated)
        now = date(25)
        xp.award(.correctAnswer)
        XCTAssertEqual(xp.ledger, ["2026-11-25": 10])
        XCTAssertEqual(xp.lifetime, 40)

        // Relu depuis le disque.
        let reopened = store { now }
        XCTAssertEqual(reopened.ledger, ["2026-11-25": 10])
        XCTAssertEqual(reopened.lifetime, 40)
        XCTAssertEqual(reopened.syncValues.total, 40)
        XCTAssertEqual(reopened.syncValues.week, 10)
        XCTAssertEqual(reopened.syncValues.weekStart, "2026-11-23")
    }

    func testARemoteTotalOnlyRaisesTheLocalOne() {
        let xp = store { self.date(11) }
        xp.award(.mockExamFinished)
        xp.adoptRemote(total: 12)
        XCTAssertEqual(xp.lifetime, 60)
        xp.adoptRemote(total: nil)
        XCTAssertEqual(xp.lifetime, 60)
        xp.adoptRemote(total: 900)
        XCTAssertEqual(xp.lifetime, 900)
        XCTAssertEqual(xp.week, 60)
    }

    // MARK: L'objectif du jour

    func testTheDailyGoalCelebratesOncePerDay() {
        var now = date(11)
        let xp = store { now }
        var shown: [XPAward] = []
        xp.onAward = { shown.append($0) }

        XCTAssertFalse(xp.award(.lessonCreated).reachedGoal) // 30
        XCTAssertTrue(xp.award(.circleCompleted).reachedGoal) // 55
        XCTAssertTrue(xp.goalReached)
        XCTAssertFalse(xp.award(.correctAnswer).reachedGoal)
        XCTAssertEqual(shown.map(\.reachedGoal), [false, true, false])

        // Un magasin rouvert le même jour ne refête pas.
        let reopened = store { now }
        XCTAssertFalse(reopened.award(.correctAnswer).reachedGoal)

        // Le lendemain, si.
        now = date(12)
        XCTAssertFalse(xp.goalReached)
        XCTAssertFalse(xp.award(.lessonCreated).reachedGoal)
        XCTAssertTrue(xp.award(.lessonCreated).reachedGoal)
    }

    func testAScreenThatCelebratesItselfSilencesTheOverlay() {
        let xp = store { self.date(11) }
        var shown: [XPAward] = []
        xp.onAward = { shown.append($0) }
        xp.award(.correctAnswer)
        let award = xp.award(.focusSession, celebrates: false)
        XCTAssertTrue(award.reachedGoal)
        XCTAssertEqual(shown.last, XPAward(added: 40, reachedGoal: false))
    }

    // MARK: Les ligues

    func testLeagues() {
        XCTAssertEqual(XPMath.league(for: 0).id, "bronze")
        XCTAssertEqual(XPMath.league(for: 199).id, "bronze")
        XCTAssertEqual(XPMath.league(for: 200).id, "silver")
        XCTAssertEqual(XPMath.league(for: 999).id, "gold")
        XCTAssertEqual(XPMath.league(for: 2500).id, "diamond")
        XCTAssertEqual(XPMath.nextLeague(for: 150)?.league.id, "silver")
        XCTAssertEqual(XPMath.nextLeague(for: 150)?.missing, 50)
        XCTAssertNil(XPMath.nextLeague(for: 3000))
    }

    func testTheLeagueFollowsThisWeekOnly() {
        var now = date(13) // vendredi
        let xp = store { now }
        xp.award(points: 300)
        XCTAssertEqual(xp.league.id, "silver")
        now = date(16) // lundi suivant
        XCTAssertEqual(xp.week, 0)
        XCTAssertEqual(xp.league.id, "bronze")
    }

    // MARK: La ligue entre amis

    func testTheLeagueRowsUseTheLocalXPForMe() throws {
        let me = UUID()
        let friend = UUID()
        let records = [
            FriendsLeague.Record(userId: friend, username: "lea", displayName: nil, xpWeek: 120, isMe: false),
            FriendsLeague.Record(userId: me, username: "moi", displayName: "Camille", xpWeek: 10, isMe: true),
        ]
        let rows = FriendsLeague.rows(from: records, me: me, myName: "Camille", myXP: 150)
        XCTAssertEqual(rows.map(\.isMe), [true, false])
        XCTAssertEqual(rows.first?.xp, 150)

        // Sans réponse du serveur : la seule ligne de l'élève.
        let alone = FriendsLeague.rows(from: [], me: nil, myName: "Camille", myXP: 30)
        XCTAssertEqual(alone.count, 1)
        XCTAssertEqual(alone.first?.isMe, true)
        XCTAssertEqual(alone.first?.initial, "C")
    }

    func testTheLeagueDecodesTheFunctionRows() throws {
        let json = """
        [{"user_id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","username":"lea","display_name":null,"xp_week":"42","is_me":false}]
        """
        let records = try JSONDecoder().decode([FriendsLeague.Record].self, from: Data(json.utf8))
        XCTAssertEqual(records.first?.xpWeek, 42)
        XCTAssertEqual(records.first?.username, "lea")
        XCTAssertEqual(records.first?.isMe, false)
    }

    // MARK: La synchro

    func testAMissingXPColumnIsRecognised() {
        let missing = SupabaseDatabase.Failure.server(
            status: 400,
            message: "Could not find the 'xp_total' column of 'profiles' in the schema cache",
            code: "PGRST204"
        )
        XCTAssertTrue(missing.concernsXPColumns)
        XCTAssertFalse(SupabaseDatabase.Failure.server(status: 500, message: "boom").concernsXPColumns)
        XCTAssertFalse(SupabaseDatabase.Failure.network("offline").concernsXPColumns)

        var profile = ProfileRecord.fromLocalPreferences(userID: UUID(), displayName: nil)
        profile.xp_total = 10
        let stripped = profile.withoutXP
        XCTAssertNil(stripped.xp_total)
        XCTAssertNil(stripped.xp_week)
        XCTAssertNil(stripped.xp_week_start)
        XCTAssertEqual(stripped.signature, profile.signature)
    }
}
