import Foundation

/// **La ligue de la semaine** (`docs/refonte-knowunity.md` § 3) : l'élève et ses amis
/// acceptés, triés par XP de la semaine, tels que `friends_league()` les rend.
///
/// `profiles` n'est lisible que par son propriétaire : le classement ne peut venir que de la
/// fonction. Sans compte, sans ami, ou si la fonction n'est pas encore déployée, l'écran se
/// contente de la ligne de l'élève, avec son XP locale.
enum FriendsLeague {
    struct Record: Equatable {
        var userId: UUID
        var username: String?
        var displayName: String?
        var xpWeek: Int
        var isMe: Bool
    }

    struct Row: Identifiable, Equatable {
        let id: UUID
        let name: String
        let xp: Int
        let isMe: Bool

        /// L'initiale de l'avatar.
        var initial: String {
            name.trimmingCharacters(in: CharacterSet(charactersIn: "@ ")).first.map { String($0).uppercased() } ?? "?"
        }
    }

    /// Les lignes à montrer. La ligne de l'élève porte toujours son XP **locale** : celle du
    /// serveur date de la dernière synchro, et l'élève vient peut-être d'en gagner.
    /// Sans ligne à lui dans la réponse, on l'ajoute.
    static func rows(from records: [Record], me: UUID?, myName: String, myXP: Int) -> [Row] {
        var rows = records.map { record in
            let isMe = record.isMe || record.userId == me
            return Row(
                id: record.userId,
                name: isMe ? myName : name(of: record),
                xp: isMe ? myXP : record.xpWeek,
                isMe: isMe
            )
        }
        if !rows.contains(where: \.isMe) {
            rows.append(Row(id: me ?? UUID(), name: myName, xp: myXP, isMe: true))
        }
        return rows.sorted { lhs, rhs in
            lhs.xp != rhs.xp ? lhs.xp > rhs.xp : (lhs.isMe && !rhs.isMe)
        }
    }

    private static func name(of record: Record) -> String {
        if let display = record.displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !display.isEmpty {
            return display
        }
        if let username = record.username, !username.isEmpty {
            return Username.display(username)
        }
        return L10n.t("app.friends.someone", locale: .resolved())
    }
}

extension FriendsLeague.Record: Decodable {
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case username
        case displayName = "display_name"
        case xpWeek = "xp_week"
        case isMe = "is_me"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userId = try container.decode(UUID.self, forKey: .userId)
        username = try container.decodeIfPresent(String.self, forKey: .username)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        if let value = try? container.decode(Int.self, forKey: .xpWeek) {
            xpWeek = value
        } else if let text = try? container.decode(String.self, forKey: .xpWeek), let value = Int(text) {
            xpWeek = value
        } else {
            xpWeek = 0
        }
        isMe = (try? container.decode(Bool.self, forKey: .isMe)) ?? false
    }
}
