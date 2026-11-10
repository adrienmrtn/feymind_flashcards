import Foundation

/// Ce que le lancement ouvre : le parcours d'accueil, ou l'app.
enum LaunchRoute: Equatable {
    case onboarding
    case home
}

/// **Parcours ou app, au lancement : une seule règle, et testée.**
///
/// Jusqu'à la 1.13 (164), le parcours se sautait tout seul après une réinstallation. La
/// session Supabase vit dans le trousseau (`AuthTokenStore`), que iOS **n'efface pas** avec
/// l'app ; au premier lancement, elle se restaurait, la première synchro relisait
/// `profiles.onboarding_completed_at` et marquait le parcours fini (`applyToLocalPreferences`),
/// et `RootView` quittait le parcours une ou deux secondes après son premier écran.
///
/// La règle, désormais :
///
/// - **le parcours se fait sur chaque installation**, qu'il y ait une session restaurée ou non,
///   et quoi qu'en dise le profil du serveur ;
/// - **la seule façon de le sauter** : « J'ai déjà un compte » sur le premier écran, suivi
///   d'une connexion qui aboutit. Le parcours est alors marqué fini *sur cette installation*,
///   et l'app s'ouvre sur ses cours ;
/// - une session restaurée n'est jamais fermée en silence : l'élève qui refait le parcours la
///   garde, et le parcours ne lui redemande pas de compte (`OnboardingModel.hasAccount`).
///
/// Le drapeau « parcours fini » vit dans `UserDefaults`, effacé avec l'app : c'est ce qui le
/// rend propre à l'installation. Le repère d'installation (`markInstallIfNeeded`) le
/// confirme : il est écrit au premier lancement, et son absence dit « installation neuve ».
enum LaunchGate {
    /// La date du premier lancement de cette installation.
    static let installMarkerKey = "micabo.install.firstLaunchAt"

    /// **La décision**, sans état : ce que le lancement doit montrer.
    ///
    /// - `installMarked` : le repère d'installation était déjà là. Absent, l'installation est
    ///   neuve — ou elle vient d'une version qui ne l'écrivait pas encore, auquel cas le
    ///   drapeau local fait foi.
    /// - `onboardingDoneLocally` : le parcours a été fini (ou sauté par « J'ai déjà un
    ///   compte ») **sur cette installation**.
    /// - `hasSession` : un compte est ouvert, restauré du trousseau ou tout juste connecté.
    /// - `tappedHaveAccount` : l'élève a choisi « J'ai déjà un compte ».
    ///
    /// Une session seule n'ouvre jamais l'app : elle survit à la désinstallation, et ne dit
    /// rien de ce que l'élève a fait sur ce téléphone-ci.
    static func route(
        installMarked: Bool,
        onboardingDoneLocally: Bool,
        hasSession: Bool,
        tappedHaveAccount: Bool
    ) -> LaunchRoute {
        if tappedHaveAccount && hasSession { return .home }
        // Une installation neuve n'a pas de drapeau local (il part avec l'app) : le repère
        // absent n'ajoute rien à la décision. Une mise à jour depuis une version sans repère
        // garde le sien, et il fait foi - le repère ne le contredit jamais.
        return onboardingDoneLocally ? .home : .onboarding
    }

    /// Vrai quand rien de cette installation n'a encore été vu : ni repère, ni parcours fini.
    static func isFreshInstall(installMarked: Bool, onboardingDoneLocally: Bool) -> Bool {
        !installMarked && !onboardingDoneLocally
    }

    /// Le repère est-il posé ?
    static func isInstallMarked(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: installMarkerKey) != nil
    }

    /// **Pose le repère au premier lancement**, et dit si l'installation était neuve. À
    /// appeler une fois, au lancement, avant toute synchro.
    @discardableResult
    static func markInstallIfNeeded(defaults: UserDefaults = .standard) -> Bool {
        let marked = isInstallMarked(defaults: defaults)
        let fresh = isFreshInstall(
            installMarked: marked,
            onboardingDoneLocally: defaults.bool(forKey: OnboardingPreferences.Key.completed)
        )
        if !marked {
            defaults.set(Date(), forKey: installMarkerKey)
        }
        return fresh
    }
}
