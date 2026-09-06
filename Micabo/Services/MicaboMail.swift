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
            case .bug: L10n.t("app.feedback.kind.bug", locale: .resolved())
            case .idea: L10n.t("app.feedback.kind.idea", locale: .resolved())
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
            case .bug: L10n.t("app.feedback.placeholder.bug", locale: .resolved())
            case .idea: L10n.t("app.feedback.placeholder.idea", locale: .resolved())
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
