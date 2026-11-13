import XCTest
@testable import Micabo

/// **Parcours ou app, au lancement** (`LaunchGate`).
///
/// La 1.13 (164) sautait le parcours après une réinstallation : la session du trousseau
/// survivait, la synchro relisait `onboarding_completed_at`, et l'app quittait le parcours.
/// Ces tests tiennent la règle : le parcours se fait sur chaque installation, sauf
/// « J'ai déjà un compte » suivi d'une connexion.
final class LaunchGateTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "LaunchGateTests"

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - La décision

    /// Installation neuve, session restaurée du trousseau : le parcours, quand même.
    func testAFreshInstallWithAStaleSessionStillShowsTheOnboarding() {
        XCTAssertEqual(
            LaunchGate.route(installMarked: false, onboardingDoneLocally: false, hasSession: true, tappedHaveAccount: false),
            .onboarding
        )
        XCTAssertEqual(
            LaunchGate.route(installMarked: true, onboardingDoneLocally: false, hasSession: true, tappedHaveAccount: false),
            .onboarding
        )
    }

    func testAFreshInstallWithoutSessionShowsTheOnboarding() {
        XCTAssertEqual(
            LaunchGate.route(installMarked: false, onboardingDoneLocally: false, hasSession: false, tappedHaveAccount: false),
            .onboarding
        )
    }

    /// « J'ai déjà un compte », et la connexion a abouti : l'app.
    func testHaveAccountWithASessionOpensHome() {
        for installMarked in [false, true] {
            XCTAssertEqual(
                LaunchGate.route(installMarked: installMarked, onboardingDoneLocally: false, hasSession: true, tappedHaveAccount: true),
                .home
            )
        }
    }

    /// « J'ai déjà un compte » sans connexion aboutie (feuille refermée) : on reste au parcours.
    func testHaveAccountWithoutASessionStaysOnTheOnboarding() {
        XCTAssertEqual(
            LaunchGate.route(installMarked: true, onboardingDoneLocally: false, hasSession: false, tappedHaveAccount: true),
            .onboarding
        )
    }

    /// Le parcours fini sur cette installation ouvre l'app, compte ou pas — y compris après
    /// une mise à jour depuis une version qui ne posait pas encore le repère.
    func testAnOnboardingDoneLocallyOpensHome() {
        for installMarked in [false, true] {
            for hasSession in [false, true] {
                for tapped in [false, true] {
                    XCTAssertEqual(
                        LaunchGate.route(
                            installMarked: installMarked,
                            onboardingDoneLocally: true,
                            hasSession: hasSession,
                            tappedHaveAccount: tapped
                        ),
                        .home
                    )
                }
            }
        }
    }

    /// Une session seule n'ouvre jamais l'app.
    func testASessionAloneNeverSkipsTheOnboarding() {
        for installMarked in [false, true] {
            XCTAssertEqual(
                LaunchGate.route(installMarked: installMarked, onboardingDoneLocally: false, hasSession: true, tappedHaveAccount: false),
                .onboarding
            )
        }
    }

    // MARK: - Le repère d'installation

    func testTheFirstLaunchIsFreshAndMarksTheInstall() {
        XCTAssertFalse(LaunchGate.isInstallMarked(defaults: defaults))
        XCTAssertTrue(LaunchGate.markInstallIfNeeded(defaults: defaults))
        XCTAssertTrue(LaunchGate.isInstallMarked(defaults: defaults))
        // Le lancement suivant n'est plus neuf.
        XCTAssertFalse(LaunchGate.markInstallIfNeeded(defaults: defaults))
    }

    /// Une mise à jour depuis une version sans repère : le parcours était fini, ce n'est pas
    /// une installation neuve.
    func testAnUpdateFromAnOlderVersionIsNotFresh() {
        defaults.set(true, forKey: OnboardingPreferences.Key.completed)
        XCTAssertFalse(LaunchGate.markInstallIfNeeded(defaults: defaults))
        XCTAssertTrue(LaunchGate.isInstallMarked(defaults: defaults))
    }

    func testIsFreshInstall() {
        XCTAssertTrue(LaunchGate.isFreshInstall(installMarked: false, onboardingDoneLocally: false))
        XCTAssertFalse(LaunchGate.isFreshInstall(installMarked: true, onboardingDoneLocally: false))
        XCTAssertFalse(LaunchGate.isFreshInstall(installMarked: false, onboardingDoneLocally: true))
    }

    // MARK: - Le profil du serveur ne décide plus du parcours

    /// La cause du bug : un profil distant « parcours fini » marquait le parcours fini ici.
    func testARemoteCompletedProfileNoLongerCompletesTheLocalOnboarding() {
        OnboardingPreferences.reset()
        defer { OnboardingPreferences.reset() }

        let remote = ProfileRecord(
            id: UUID(),
            display_name: "Lina",
            study_level: "lycee",
            country_code: "fr",
            learning_goals: [],
            subjects: [],
            institution_id: nil,
            institution_name: nil,
            daily_minutes: 20,
            sheet_length: SheetLength.standard.rawValue,
            sheet_language: nil,
            onboarding_completed_at: Date()
        )
        remote.applyToLocalPreferences()

        XCTAssertFalse(OnboardingPreferences.isCompleted)
        XCTAssertEqual(OnboardingPreferences.dailyMinutes, 20)
    }
}
