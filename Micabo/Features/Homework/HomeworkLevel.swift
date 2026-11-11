import Foundation

/// **Le niveau de l'élève, dit à Mika dans les mots de son pays.**
///
/// `mika-chat` reçoit déjà un registre (`StudyLevel` : « lycee », « licence »…), mais ce
/// registre est le même pour un lycéen français, un élève de Gymnasium et un high schooler
/// américain. L'aide aux devoirs et la correction d'un texte ajoutent donc, à la fin de la
/// consigne, le palier choisi à l'inscription tel que l'app l'affiche (`EducationStage`) :
/// « Lycée », « Gymnasium (Oberstufe) », « High school », « Collège »… Mika explique une
/// règle de grammaire autrement à un collégien qu'à un étudiant, sans fonction nouvelle.
enum HomeworkLevel {
    /// Le palier de l'élève, dans la langue de l'app ; rien quand le profil ne le connaît pas.
    static var current: String? {
        guard let stage = OnboardingPreferences.educationStage else { return nil }
        let title = stage.localizedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// La ligne ajoutée à la consigne, ou rien.
    static func line(_ level: String?) -> String? {
        guard let level = level?.trimmingCharacters(in: .whitespacesAndNewlines), !level.isEmpty else { return nil }
        return L10n.t("ios.ku7.prompt.level", locale: .resolved(), vars: ["level": String(level.prefix(60))])
    }

    /// La consigne, suivie du niveau quand on le connaît.
    static func appending(_ level: String?, to prompt: String) -> String {
        guard let line = line(level) else { return prompt }
        return prompt + "\n" + line
    }
}
