import SwiftUI
import XCTest
@testable import Micabo

/// **Une page du parcours posée comme dans l'app** (lot 11) : le fond qui passe sous les
/// marges, la page de l'étape et la barre du haut fixe, exactement comme `OnboardingFlowView`
/// les empile. Rien n'est immobilisé (`onboardingStill` reste faux) : le gabarit est celui
/// de l'iPhone, avec son défilement, et pas celui des rendus.
struct OnboardingLivePage: View {
    let step: OnboardingStep
    let model: OnboardingModel

    var body: some View {
        let auth = AuthController()
        ZStack(alignment: .top) {
            V3Color.bg
                .ignoresSafeArea()
            OnboardingStepScreen(step: step)
            OnboardingTopBar(model: model)
        }
        .ignoresSafeArea(.keyboard)
        .environment(model)
        .environment(auth)
        .environment(CloudSync(auth: auth))
        .environment(\.mikaStill, true)
    }
}

/// **Le parcours d'accueil sur un vrai iPhone** : chaque écran dans une fenêtre aux marges de
/// l'iPhone 15 Pro (59/34) et de l'iPhone SE (20/0), encoche et barre d'accueil dessinées
/// (`RenderGallery.renderDevice`). C'est là que se voient un titre sous l'encoche, des réponses
/// qui ne descendent pas, un bouton collé au bord.
@MainActor
final class OnboardingDeviceRenderTests: XCTestCase {
    private var savedLocale: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
        UserDefaults.standard.set(UiLocale.fr.rawValue, forKey: UiLocale.storageKey)
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        OnboardingPreferences.reset()
        FirstLessonIntent.pending = nil
        super.tearDown()
    }

    /// Une lycéenne de terminale arrivée au bout des questions.
    private func lina() -> OnboardingModel {
        let model = OnboardingModel()
        model.displayName = "Lina"
        if let country = WorldCountries.country(code: "FR") {
            model.select(worldCountry: country)
        }
        if let track = model.tracks.first(where: { $0.id == "fr.lyceeGeneral" }) {
            model.track = track
            model.year = track.years.first { $0.id == "fr.terminale" } ?? track.years.last
        }
        if let first = model.examChoices.first {
            model.choose(exam: first)
        }
        model.subjects = ["Mathématiques", "Philosophie", "Physique-Chimie"]
        for worry in [StudyWorry.forgetting, .examStress, .homework] {
            model.toggle(worry: worry)
        }
        model.goals = [.dreamSchool]
        model.currentScore = 12
        model.targetScore = 16
        model.dailyMinutes = 15
        model.studyHour = 18
        model.firstLessonChoice = .topic
        model.firstLessonTopic = "La guerre froide"
        return model
    }

    private func render(_ name: String, _ step: OnboardingStep) throws {
        let model = lina()
        model.place(on: step)
        try RenderGallery.renderDevice("onb11-device-\(name)", OnboardingLivePage(step: step, model: model))
    }

    /// Chaque écran du parcours (le paywall est rendu par son propre lot).
    func testEveryStepOnDevice() throws {
        let steps = OnboardingStep.allCases.filter { $0 != .paywall && $0 != .level }
        for step in steps {
            try render(String(format: "%02d-%@", step.rawValue, step.analyticsName), step)
        }
    }
}
