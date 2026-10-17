import Foundation

/// **Ce que le serveur dit, dans la langue de l'app.**
///
/// Les fonctions Edge écrivent leurs messages en français — « Dis-moi ce que tu veux
/// apprendre. », « Connecte-toi pour utiliser Micabo. » —, et l'app les affichait tels
/// quels : une interface en allemand montrait une erreur en français. En français, le message
/// du serveur passe, il est plus précis que tout ce qu'on pourrait dire à sa place ; dans les
/// autres langues, c'est la phrase générique de l'app qui le remplace.
///
/// **Sauf pour les refus que l'app sait déjà dire.** Le plafond du jour arrivait sans code
/// jusqu'à `generate-lesson` : en anglais, il devenait « The lesson couldn't be written. Try
/// again. », et l'élève réessayait un refus qui ne se lèverait que le lendemain. Ces phrases
/// sont reconnues mot pour mot ; une phrase reformulée côté serveur retombe simplement sur la
/// phrase générique, comme avant.
enum ServerMessage {
    static func localized(_ message: String, fallback key: String, locale: UiLocale = .resolved()) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, locale == .fr else {
            return L10n.t(known[trimmed] ?? key, locale: locale)
        }
        return trimmed
    }

    /// Les phrases des fonctions Edge (`_shared/caller.ts`, `generate-lesson`, `generate-course`),
    /// et la clé qui les dit dans la langue de l'app.
    static let known: [String: String] = [
        "Trop de générations aujourd'hui. Réessaie demain.": "ios.ai.quota",
        "Connecte-toi pour utiliser Micabo.": "app.errors.signIn",
        "Le document ne contient pas assez de contenu à analyser.": "ios.ai.emptySource",
    ]
}
