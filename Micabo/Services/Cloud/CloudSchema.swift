import Foundation

/// **Ce que la base sait stocker**, vérifié une fois par lancement.
///
/// L'app et la base ne se mettent pas à jour en même temps : un téléphone peut recevoir la
/// refonte « parcours » avant que la migration `lesson_paths` soit appliquée en production.
/// Or PostgREST refuse en bloc une ligne qui porte une colonne inconnue — et avec elle tout
/// l'envoi des cours. Avant de monter quoi que ce soit, la synchro demande donc à la base si
/// les colonnes de la leçon existent (`select` de ces colonnes, sans ligne) ; tant qu'elles
/// n'existent pas, les cours montent à l'ancien format, et rien ne casse.
///
/// Une panne réseau ne tranche rien : la question se repose à la synchro suivante.
@MainActor
enum CloudSchema {
    /// Vrai quand `courses` et `chapters` ont les colonnes de la leçon.
    private(set) static var hasLessonColumns = false
    private static var answered = false

    private struct Probe: Decodable {
        let id: UUID
    }

    static func probe(_ database: SupabaseDatabase) async {
        guard !answered else { return }
        do {
            _ = try await database.rows(
                Probe.self,
                from: CloudTable.courses,
                select: "id,path,progress,tone,icon,last_opened_at",
                limit: 1
            )
            _ = try await database.rows(
                Probe.self,
                from: CloudTable.chapters,
                select: "id,icon,notes,quiz,status",
                limit: 1
            )
            hasLessonColumns = true
            answered = true
        } catch SupabaseDatabase.Failure.server(let status, _, _) where status == 400 {
            // `42703 column does not exist` : la migration n'est pas passée.
            hasLessonColumns = false
            answered = true
        } catch {
            // Réseau, session : on ne sait pas. On reposera la question.
        }
    }

    /// Pour les tests.
    static func assume(lessonColumns: Bool) {
        hasLessonColumns = lessonColumns
        answered = true
    }
}
