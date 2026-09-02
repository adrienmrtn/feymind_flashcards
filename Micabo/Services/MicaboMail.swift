import Foundation

/// L'adresse de l'équipe, et les kinds du retour.
///
/// C'est la même adresse que `LEGAL_CONTACT` sur le web. L'envoi s'écrit
/// dans `feedback`, plus dans un courriel.
enum MicaboMail {
    static let team = "team@micabo.app"

    enum Kind: String, CaseIterable, Identifiable {
        case bug
        case idea

        var id: String { rawValue }

        var title: String {
            switch self {
            case .bug: "Un bug"
            case .idea: "Une idée"
            }
        }

        var subject: String {
            switch self {
            case .bug: "Bug — Micabo"
            case .idea: "Idée — Micabo"
            }
        }

        var placeholder: String {
            switch self {
            case .bug: "Ce qui s'est passé, et où."
            case .idea: "Ce que tu aimerais pouvoir faire."
            }
        }
    }

    static func composeURL(kind: Kind, message: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = "mailto"
        parts.path = team
        parts.queryItems = [
            URLQueryItem(name: "subject", value: kind.subject),
            URLQueryItem(name: "body", value: message.trimmingCharacters(in: .whitespacesAndNewlines)),
        ]
        return parts.url
    }
}
