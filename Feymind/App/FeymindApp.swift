import SwiftData
import SwiftUI

@main
struct FeymindApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Course.self,
                CourseBlockEntity.self,
                Flashcard.self,
                ReviewLog.self,
                TextHighlight.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
        } catch {
            // En cas d'incompatibilité de schéma, on repart d'une base propre plutôt que de planter.
            container = try! ModelContainer(
                for: Course.self,
                CourseBlockEntity.self,
                Flashcard.self,
                ReviewLog.self,
                TextHighlight.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }

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
}
