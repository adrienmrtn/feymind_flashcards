import XCTest
@testable import Micabo

/// Le classement de la semaine, tel que le profil le montre : soi et le cercle,
/// et rien si l'on est seul.
final class WeekReviewRankingTests: XCTestCase {
    private let me = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
    private let friend = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!

    func testItMarksWhichRowIsMine() {
        let rows = WeekReviewRanking.rows(
            from: [
                .init(userId: friend, username: "camille", passes: 40),
                .init(userId: me, username: "adrien", passes: 12),
            ],
            me: me
        )

        XCTAssertEqual(rows.map(\.isMe), [false, true])
        XCTAssertEqual(rows[0].handle, "@camille")
        XCTAssertEqual(rows[1].handle, "@adrien")
    }

    /// Un podium d'une seule personne n'est pas un classement. C'est la même
    /// règle que le web : le bloc n'existe que s'il y a quelqu'un à comparer.
    func testALoneRowIsNotARanking() {
        let alone = WeekReviewRanking.rows(
            from: [.init(userId: me, username: "adrien", passes: 8)],
            me: me
        )
        XCTAssertFalse(WeekReviewRanking.isVisible(alone))

        let circle = WeekReviewRanking.rows(
            from: [
                .init(userId: me, username: "adrien", passes: 8),
                .init(userId: friend, username: "camille", passes: 3),
            ],
            me: me
        )
        XCTAssertTrue(WeekReviewRanking.isVisible(circle))
    }

    func testAMissingUsernameDoesNotInventAHandle() {
        let rows = WeekReviewRanking.rows(
            from: [.init(userId: friend, username: nil, passes: 1)],
            me: me
        )
        XCTAssertEqual(rows[0].handle, "Quelqu'un")
    }

    /// PostgREST rend parfois un `bigint` en nombre, parfois en chaîne. Les deux
    /// doivent donner le même volume, sinon le classement change selon la version
    /// du serveur.
    func testItReadsAPassCountWrittenAsANumberOrAString() throws {
        let json = Data("""
        [
          {"user_id":"\(me.uuidString.lowercased())","username":"adrien","passes":12},
          {"user_id":"\(friend.uuidString.lowercased())","username":"camille","passes":"40"}
        ]
        """.utf8)

        let records = try JSONDecoder().decode([WeekReviewRanking.Record].self, from: json)
        XCTAssertEqual(records.map(\.passes), [12, 40])
        XCTAssertEqual(records[0].userId, me)
    }
}
