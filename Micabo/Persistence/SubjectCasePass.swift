import Foundation
import SwiftData

/// **Rend leur casse aux matières écrites en capitales**, une fois, au lancement.
///
/// Le nettoyage à l'import ne vaut que pour ce qui arrive après lui. Les cours déjà là
/// gardaient leur « HISTOIRE », et c'est justement ce qu'on voit en ouvrant l'app : la
/// bibliothèque d'un étudiant qui l'utilise depuis un mois est faite de ces cours-là.
///
/// La passe ne touche pas `updatedAt`. Ce n'est pas un oubli : remonter la date de tous les
/// cours d'un coup les renverrait tous au cloud pour une différence de casse, et la synchro
/// décapitale déjà ce qu'elle redescend. Une correction d'affichage n'a pas à ressembler à
/// une modification du cours.
enum SubjectCasePass {
    static let key = "micabo.didNormalizeSubjectCase"

    /// `defaults` est un paramètre pour que le test travaille sur son propre domaine plutôt
    /// que sur les réglages de la machine qui lance la suite.
    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: key) else { return }

        // Le drapeau est posé avant le travail, comme pour la purge des exemples : si
        // l'écriture échoue, on ne veut pas retenter la passe à chaque lancement.
        defaults.set(true, forKey: key)

        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        var didChange = false

        for course in courses {
            guard let subject = course.subject else { continue }
            let fixed = TextSanitizer.subject(subject)
            guard fixed != subject else { continue }
            course.subject = fixed
            didChange = true
        }

        guard didChange else { return }
        try? context.save()
    }
}
