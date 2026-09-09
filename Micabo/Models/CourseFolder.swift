import Foundation
import SwiftData

/// **Un dossier de la bibliothèque.**
///
/// La liste des cours était plate. Ça tient un semestre ; au troisième, il y a quarante cours
/// de cinq matières, et retrouver le chapitre 4 de thermodynamique se fait en faisant défiler
/// jusqu'à le voir passer. Le filtre par matière ne remplace pas un rangement : « Physique »
/// est une étiquette, pas une organisation, et personne ne range son classeur en une pile par
/// matière.
///
/// Un dossier porte un **parent**, et l'arborescence sort de là : Physique > Thermodynamique >
/// TD. C'est la structure que tout le monde connaît, et la seule qu'on n'a pas à expliquer.
///
/// Comme pour le cours, le parent est un **identifiant** et non une relation SwiftData. Un
/// parent effacé sur un autre appareil pendant qu'on déplaçait son enfant est un cas réel : un
/// identifiant qui ne correspond à rien se lit comme « à la racine », là où une relation
/// cassée ferait disparaître le dossier et tout ce qu'il contient.
@Model
final class CourseFolder {
    var id: UUID = UUID()
    var parentID: UUID?
    var name: String = ""
    /// De quoi le reconnaître d'un coup d'œil dans une liste de quinze dossiers.
    var emoji: String?
    /// L'ordre voulu, à l'intérieur de son parent. Le nom tranche à rang égal.
    var position: Int = 0
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        parentID: UUID? = nil,
        name: String,
        emoji: String? = nil,
        position: Int = 0
    ) {
        self.id = id
        self.parentID = parentID
        self.name = name
        self.emoji = emoji
        self.position = position
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - L'arborescence

/// Le rangement, recomposé en mémoire.
///
/// Porté depuis `packages/core/src/library/folders.ts`, et pour la même raison que le reste du
/// noyau partagé : le site et l'app doivent montrer **le même classeur**. Les règles y sont
/// écrites une fois et testées des deux côtés.
struct FolderTree: Identifiable {
    var folder: CourseFolder
    var children: [FolderTree]
    var courses: [Course]
    /// Ce que le dossier contient en tout, sous-dossiers compris.
    var total: Int

    var id: UUID { folder.id }
}

enum CourseLibrary {
    /// La profondeur au-delà de laquelle un classeur n'est plus un classeur.
    static let maxDepth = 5

    /// Range les cours dans leurs dossiers, et rend ce qui n'est rangé nulle part.
    static func build(
        folders: [CourseFolder],
        courses: [Course]
    ) -> (tree: [FolderTree], loose: [Course]) {
        let known = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var byParent: [UUID?: [CourseFolder]] = [:]
        for folder in folders {
            // Un parent inconnu, effacé ou bouclé rend le dossier à la racine.
            let parent: UUID? = {
                guard let parentID = folder.parentID, known[parentID] != nil else { return nil }
                return loops(folder, known) ? nil : parentID
            }()
            byParent[parent, default: []].append(folder)
        }

        var byFolder: [UUID?: [Course]] = [:]
        for course in courses {
            let folder = course.folderID.flatMap { known[$0] != nil ? $0 : nil }
            byFolder[folder, default: []].append(course)
        }

        func branch(_ parent: UUID?, depth: Int) -> [FolderTree] {
            guard depth <= maxDepth else { return [] }
            return (byParent[parent] ?? []).sorted(by: before).map { folder in
                let children = branch(folder.id, depth: depth + 1)
                let own = byFolder[folder.id] ?? []
                return FolderTree(
                    folder: folder,
                    children: children,
                    courses: own,
                    total: own.count + children.reduce(0) { $0 + $1.total }
                )
            }
        }

        return (branch(nil, depth: 1), byFolder[nil] ?? [])
    }

    /// Le chemin d'un dossier jusqu'à la racine, racine d'abord. C'est le fil d'Ariane.
    static func path(_ folders: [CourseFolder], to id: UUID?) -> [CourseFolder] {
        guard let id else { return [] }
        let known = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var path: [CourseFolder] = []
        var seen: Set<UUID> = []
        var cursor: UUID? = id

        while let current = cursor, let folder = known[current], !seen.contains(current) {
            seen.insert(current)
            path.insert(folder, at: 0)
            cursor = folder.parentID
        }

        return path
    }

    /// Vrai quand `folder` peut aller dans `target`.
    ///
    /// Un dossier ne se range ni dans lui-même ni dans un de ses descendants : il
    /// disparaîtrait des deux côtés. Et pas au-delà de la profondeur admise, parce qu'un
    /// classeur à huit niveaux ne se parcourt plus, il se subit.
    static func canMove(_ folders: [CourseFolder], folder: UUID, into target: UUID?) -> Bool {
        if folder == target { return false }
        guard let target else { return true }

        let chain = path(folders, to: target)
        if chain.contains(where: { $0.id == folder }) { return false }

        return chain.count + depth(folders, under: folder) <= maxDepth
    }

    /// L'ordre d'affichage : le rang voulu d'abord, le nom ensuite. Deux dossiers au même
    /// rang ne dansent pas d'un lancement à l'autre.
    static func before(_ a: CourseFolder, _ b: CourseFolder) -> Bool {
        if a.position != b.position { return a.position < b.position }
        return a.name.localizedStandardCompare(b.name) == .orderedAscending
    }

    /// Le nombre de niveaux qu'un dossier emporte avec lui, lui compris.
    private static func depth(_ folders: [CourseFolder], under id: UUID) -> Int {
        let children = folders.filter { $0.parentID == id }
        guard !children.isEmpty else { return 1 }
        return 1 + (children.map { depth(folders, under: $0.id) }.max() ?? 0)
    }

    private static func loops(_ folder: CourseFolder, _ known: [UUID: CourseFolder]) -> Bool {
        var seen: Set<UUID> = [folder.id]
        var cursor = folder.parentID
        while let current = cursor {
            if seen.contains(current) { return true }
            seen.insert(current)
            cursor = known[current]?.parentID
        }
        return false
    }
}
