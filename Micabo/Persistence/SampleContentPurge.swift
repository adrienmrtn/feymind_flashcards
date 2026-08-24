import Foundation
import SwiftData

/// Efface le contenu de démonstration que les versions précédentes inséraient au premier
/// lancement.
///
/// **L'app part maintenant vide.** Deux cours qui ne sont pas les tiens ne montrent pas ce
/// que fait Micabo, ils montrent ce que quelqu'un d'autre a importé, et le premier geste
/// devient de les supprimer. Les écrans d'accueil vides, eux, disent quoi faire.
///
/// Ne plus insérer ne suffit pas : les téléphones où l'app a déjà tourné portent encore
/// « La photosynthèse » et « Les fonctions affines », avec leurs cartes, leur planning et
/// leur historique. Sans ce nettoyage, l'écran vide ne se verrait que sur une installation
/// neuve — c'est-à-dire jamais, pour quelqu'un qui a déjà l'app.
///
/// Le nettoyage ne touche **que les cours marqués `sample`**, ceux que Micabo s'est
/// insérés à lui-même. Un cours importé par l'utilisateur n'est jamais concerné, même s'il
/// porte le même titre. La suppression d'un cours emporte ses cartes et leurs journaux de
/// révision, par cascade : la série affichée ne compte donc plus de révisions fantômes.
enum SampleContentPurge {
    static let key = "micabo.didPurgeSampleContent"

    /// Drapeaux d'insertion des versions précédentes. On les retire au passage, sans quoi un
    /// retour en arrière sur une ancienne version réinsérerait les deux cours.
    static let legacySeedKeys = [
        "micabo.didSeedSampleData",
        "feymind.didSeedSampleData"
    ]

    /// `defaults` est un paramètre pour que le test puisse travailler sur son propre domaine
    /// plutôt que sur les réglages de la machine qui lance la suite.
    static func purgeIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: key) else { return }

        // Le drapeau est posé avant le travail, pas après : si la suppression échoue, on ne
        // veut pas la retenter à chaque lancement de l'app.
        defaults.set(true, forKey: key)
        for legacy in legacySeedKeys {
            defaults.removeObject(forKey: legacy)
        }

        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        let samples = courses.filter { $0.source == .sample }
        guard !samples.isEmpty else { return }

        for course in samples {
            context.delete(course)
        }
        try? context.save()
    }
}
