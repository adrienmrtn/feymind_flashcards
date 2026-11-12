import SwiftUI
import XCTest
@testable import Micabo

/// **Les places de Mika, lot 9** : chaque grand moment avec l'expression qui le dit, à la
/// taille de son rôle — la fête de l'objectif, la fin d'un quiz (réussi, moyen, raté), le
/// retour d'une réponse (Mika passe la tête au-dessus du panneau), l'attente d'une génération
/// et son erreur, un écran vide, la préparation du plan — de jour et de nuit, en allemand et
/// en arabe. Tout est posé immobile (`mikaStill`, `homeStill`).
@MainActor
final class Mika9RenderTests: XCTestCase {
    private var savedLocale: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        super.tearDown()
    }

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    private func t(_ key: String) -> String { L10n.t(key, locale: .resolved()) }

    private static let question = QuizQuestion(
        id: "mika9",
        prompt: "Quelle particule porte une charge positive ?",
        choices: ["L'électron", "Le proton", "Le neutron", "Le noyau"],
        answer: 1,
        why: "Le proton porte une charge positive, égale et opposée à celle de l'électron."
    )

    /// La fin d'un quiz et le retour d'une réponse : le panneau en bas d'un écran de quiz, Mika
    /// au-dessus de son bord.
    private func quiz(right: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            AnswerPanel(question: Self.question, right: right, isLast: false) {}
        }
        .frame(height: 400)
        .environment(\.mikaStill, true)
    }

    private func scores() -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach([9, 6, 3], id: \.self) { right in
                QuizScoreView(right: right, total: 10, tone: .lilac, doneTitle: self.t("lesson.quiz.finish"), onDone: {})
                    .frame(width: 393, height: 640)
                    .scaleEffect(0.5, anchor: .topLeading)
                    .frame(width: 196, height: 320, alignment: .topLeading)
            }
        }
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    private func moments() -> some View {
        VStack(spacing: 22) {
            XPGoalCard(showsButton: false)
            MicaboEmptyState(
                systemImage: "books.vertical",
                title: t("lesson.lessons.emptyTitle"),
                message: t("lesson.lessons.emptyBody"),
                actionTitle: t("lesson.lessons.new"),
                mika: .wave
            ) {}
        }
        .padding(20)
        .environment(\.mikaStill, true)
        .environment(\.homeStill, true)
    }

    /// L'attente d'une génération, puis son échec : la même taille, la même place.
    private func waits() -> some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(spacing: 12) {
                MikaMascot(mood: .write, size: 150)
                Text(t("lesson.create.generatingTitle"))
                    .font(MicaboFont.subtitle)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                MikaMascot(mood: .sad, size: 150)
                Text(t("lesson.create.failedTitle"))
                    .font(MicaboFont.subtitle)
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    func testMikaPlaces() throws {
        use(.fr)
        try RenderGallery.render("mika9-quiz-right", night: true, quiz(right: true))
        try RenderGallery.render("mika9-quiz-wrong", night: true, quiz(right: false))
        try RenderGallery.render("mika9-scores", height: 340, night: true, scores())
        try RenderGallery.render("mika9-moments", night: true, moments())
        try RenderGallery.render("mika9-waits", night: true, waits())
        try RenderGallery.render("mika9-loading", height: 760, night: true,
            MikaLoadingView(progress: 0.6, title: "Mika prépare ton plan", subtitle: "Calibrage de ton niveau", stepLabel: "Étape 3")
                .environment(\.mikaStill, true))

        use(.de)
        try RenderGallery.render("mika9-quiz-wrong-de", width: 375, quiz(right: false))
        try RenderGallery.render("mika9-moments-de", width: 375, moments())

        use(.ar)
        try RenderGallery.render("mika9-quiz-right-ar", quiz(right: true).environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("mika9-moments-ar", moments().environment(\.layoutDirection, .rightToLeft))
    }
}
