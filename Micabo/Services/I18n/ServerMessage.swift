import Foundation

/// **Ce que le serveur dit, dans la langue de l'app.**
///
/// Les fonctions Edge écrivent leurs messages en français — « Dis-moi ce que tu veux
/// apprendre. », « Connecte-toi pour utiliser Micabo. » —, et l'app les affichait tels
/// quels : une interface en allemand montrait une erreur en français. En français, le message
/// du serveur passe, il est plus précis que tout ce qu'on pourrait dire à sa place ; dans les
/// autres langues, c'est la phrase générique de l'app qui le remplace.
enum ServerMessage {
    static func localized(_ message: String, fallback key: String, locale: UiLocale = .resolved()) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, locale == .fr else {
            return L10n.t(key, locale: locale)
        }
        return trimmed
    }
}
