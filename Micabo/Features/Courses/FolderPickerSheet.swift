import SwiftData
import SwiftUI

/// **Où ranger ça.**
///
/// Sur le site, on glisse une tuile sur un dossier. Sur un téléphone, le glisser-déposer
/// existe mais il se rate : la cible fait quarante points de haut, la liste défile sous le
/// doigt, et il faut voir la source et la destination en même temps sur un écran qui en tient
/// six. Le geste reste disponible - une rangée se prend et se lâche - mais **la voie sûre est
/// une liste** : on ouvre « Déplacer vers », on touche le dossier, c'est rangé.
///
/// L'arborescence est **mise à plat avec des retraits**. Un choix à faire dans une hiérarchie
/// qu'il faut d'abord déplier est un choix qu'on abandonne ; ici tout est visible d'un coup,
/// et le retrait dit la profondeur sans demander de geste.
struct FolderPickerSheet: View {
    /// Ce qu'on range. `nil` pour un cours : un cours va partout.
    var movingFolder: UUID?
    /// Le dossier où la chose est déjà, pour le marquer et ne pas le proposer deux fois.
    var current: UUID?
    var onPick: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Query private var folders: [CourseFolder]

    private var rows: [(folder: CourseFolder, depth: Int)] {
        var out: [(CourseFolder, Int)] = []

        func walk(_ parent: UUID?, depth: Int) {
            let here = folders
                .filter { $0.parentID == parent }
                .sorted(by: CourseLibrary.before)
            for folder in here {
                out.append((folder, depth))
                walk(folder.id, depth: depth + 1)
            }
        }

        walk(nil, depth: 0)
        return out.map { (folder: $0.0, depth: $0.1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("tray"), size: 42),
                        title: i18n?.t("app.folders.root") ?? "Mes cours",
                        subtitle: nil,
                        accessory: current == nil ? .symbol("checkmark") : .none
                    ) {
                        onPick(nil)
                        dismiss()
                    }

                    MicaboHairline(inset: MicaboSpacing.md, onCanvas: true)

                    ForEach(rows, id: \.folder.id) { row in
                        let allowed = isAllowed(row.folder)
                        MicaboRow(
                            tile: MicaboTile(glyph: .emoji(row.folder.emoji ?? "📁"), size: 42),
                            title: row.folder.name,
                            subtitle: nil,
                            accessory: current == row.folder.id ? .symbol("checkmark") : .none,
                            titleColor: allowed ? MicaboColor.ink : MicaboColor.inkTertiary,
                            action: allowed
                                ? {
                                    onPick(row.folder.id)
                                    dismiss()
                                }
                                : nil
                        )
                        .padding(.leading, CGFloat(row.depth) * 18)
                        .opacity(allowed ? 1 : 0.55)

                        MicaboHairline(inset: MicaboSpacing.md, onCanvas: true)
                    }
                }
                .padding(.vertical, MicaboSpacing.xs)
            }
            .micaboScreenBackground()
            .navigationTitle(i18n?.t("app.folders.moveTo") ?? "Déplacer vers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(i18n?.t("app.common.cancel") ?? "Annuler") { dismiss() }
                }
            }
        }
    }

    /// Un dossier ne se range pas dans lui-même ni dans son propre contenu : les cibles
    /// impossibles restent visibles, en gris, plutôt que de disparaître. Une liste dont les
    /// entrées s'évaporent selon ce qu'on déplace se lit comme un bug.
    private func isAllowed(_ folder: CourseFolder) -> Bool {
        guard let movingFolder else { return true }
        return CourseLibrary.canMove(folders, folder: movingFolder, into: folder.id)
    }
}
