import Foundation

/// Le classement de la semaine : soi-même et ses amis, cartes passées depuis lundi.
///
/// Les volumes viennent du RPC `week_review_ranking` : `review_logs` n'est lisible
/// que par son auteur, donc l'app ne peut pas les additionner elle-même. On ne
/// montre le bloc que s'il y a vraiment un cercle — un podium tout seul n'est
/// pas un classement.
enum WeekReviewRanking {
    struct Record: Equatable {
        var userId: UUID
        var username: String?
        var passes: Int
    }

    struct Row: Identifiable, Hashable {
        let id: UUID
        let username: String?
        let passes: Int
        let isMe: Bool

        var handle: String {
            guard let username, !username.isEmpty else { return "Quelqu'un" }
            return Username.display(username)
        }
    }

    /// Au moins deux personnes : soi et un ami, ou deux amis. Un seul nom, ce n'est
    /// pas un classement.
    static func isVisible(_ rows: [Row]) -> Bool {
        rows.count >= 2
    }

    static func rows(from records: [Record], me: UUID) -> [Row] {
        records.map { record in
            Row(
                id: record.userId,
                username: record.username,
                passes: record.passes,
                isMe: record.userId == me
            )
        }
    }
}

extension WeekReviewRanking.Record: Decodable {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case passes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        if let value = try? container.decode(Int.self, forKey: .passes) {
            passes = value
        } else if let text = try? container.decode(String.self, forKey: .passes),
                  let value = Int(text) {
            passes = value
        } else {
            passes = 0
        }
    }
}
