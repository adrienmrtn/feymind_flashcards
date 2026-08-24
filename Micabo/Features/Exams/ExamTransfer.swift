import CoreTransferable
import Foundation

/// Un examen qu'on déplace au doigt, de la liste vers un jour du calendrier.
///
/// Seul l'identifiant voyage : reconstruire un examen depuis un objet transféré serait une
/// façon de créer des doublons, et l'examen à déplacer existe déjà en base. L'identifiant
/// est porté en texte brut plutôt que par un type de contenu déclaré dans l'`Info.plist`,
/// parce qu'un glisser-déposer interne à l'app n'a pas besoin d'un type public pour
/// fonctionner.
struct ExamTransfer: Transferable {
    /// Nul quand la chaîne reçue n'est pas un identifiant : c'est le cas d'un texte déposé
    /// depuis une autre application, et le dépôt est alors simplement ignoré.
    let id: UUID?

    init(id: UUID?) {
        self.id = id
    }

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(
            exporting: { (transfer: ExamTransfer) in transfer.id?.uuidString ?? "" },
            importing: { (value: String) in ExamTransfer(id: UUID(uuidString: value)) }
        )
    }
}
