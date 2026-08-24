import SwiftData
import SwiftUI

@main
struct MicaboApp: App {
    private let container: ModelContainer

    private static let schema = Schema([Course.self, Flashcard.self, ReviewLog.self, Exam.self])

    init() {
        FontLoader.registerFonts()
        container = Self.makeContainer()
        SampleContentPurge.purgeIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            // Le thème clair n'est pas posé ici : le parcours d'accueil bascule en
            // sombre le temps de ses écrans d'encre, et une valeur fixée au-dessus de
            // lui l'en empêcherait. `RootView` l'applique donc à l'app elle-même.
            RootView()
                .tint(MicaboColor.accent)
        }
        .modelContainer(container)
    }

    // MARK: - Stockage

    private static func makeContainer() -> ModelContainer {
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        if let container = try? persistentContainer() {
            return container
        }

        // Le schéma a changé : on repart d'un fichier vide plutôt que de perdre l'écriture sur disque.
        removeStore()
        if let container = try? persistentContainer() {
            return container
        }

        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "Micabo.store")
    }

    /// Ancien nom de l'app (Feymind) : on reprend le fichier SwiftData s'il est encore là.
    private static func migrateLegacyStoreIfNeeded() {
        let manager = FileManager.default
        let legacy = URL.applicationSupportDirectory.appending(path: "Feymind.store")
        guard !manager.fileExists(atPath: storeURL.path),
              manager.fileExists(atPath: legacy.path) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let src = legacy.path + suffix
            let dst = storeURL.path + suffix
            guard manager.fileExists(atPath: src) else { continue }
            try? manager.moveItem(atPath: src, toPath: dst)
        }
    }

    private static func persistentContainer() throws -> ModelContainer {
        migrateLegacyStoreIfNeeded()
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
    }

    private static func removeStore() {
        let manager = FileManager.default
        for path in [storeURL.path, storeURL.path + "-shm", storeURL.path + "-wal"] {
            try? manager.removeItem(atPath: path)
        }
    }
}
