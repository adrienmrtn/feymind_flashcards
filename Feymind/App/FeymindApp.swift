import SwiftData
import SwiftUI

@main
struct FeymindApp: App {
    private let container: ModelContainer

    private static let schema = Schema([Course.self, Flashcard.self, ReviewLog.self])

    init() {
        FontLoader.registerFonts()
        container = Self.makeContainer()
        SampleData.seedIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.light)
                .tint(FeyColor.accent)
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

    private static func persistentContainer() throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
    }

    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "Feymind.store")
    }

    private static func removeStore() {
        let manager = FileManager.default
        for path in [storeURL.path, storeURL.path + "-shm", storeURL.path + "-wal"] {
            try? manager.removeItem(atPath: path)
        }
        // Le contenu de démonstration revient : sans lui, l'application repart vide et paraît cassée.
        UserDefaults.standard.removeObject(forKey: SampleData.seedKey)
    }
}
