import UserNotifications

/// **L'autorisation de notifier, demandée une fois.**
///
/// Le parcours a longtemps porté un écran de rappels qui ne demandait rien au système : il
/// notait une intention que personne ne relisait, et l'étudiant croyait avoir dit oui à
/// quelque chose. L'écran qui le remplace (`NotificationsStepView`) montre la notification
/// qu'il recevra, puis ouvre **la vraie** boîte de dialogue d'iOS.
///
/// iOS ne pose la question qu'une fois. Tout ce qui suit en découle :
///
/// - on relit l'état avant de demander, parce qu'un second appel sur un choix déjà fait se
///   résout immédiatement sans rien afficher. Un écran qui attend un dialogue qui n'arrive
///   pas reste planté sur son bouton ;
/// - un refus n'est pas une erreur : c'est une réponse, et le parcours continue. Rien dans
///   Micabo ne dépend des notifications pour fonctionner.
enum NotificationPermission {
    /// Ce que le système répond, ramené à ce que l'écran a besoin de savoir.
    enum Outcome {
        /// La boîte s'est ouverte et l'étudiant a accepté.
        case granted
        /// La boîte s'est ouverte et l'étudiant a refusé.
        case denied
        /// La question avait déjà été tranchée : rien ne s'est affiché.
        case alreadyAnswered(isAuthorized: Bool)
    }

    /// Demande l'autorisation, et ne la demande qu'une fois.
    @discardableResult
    static func request() async -> Outcome {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus

        guard status == .notDetermined else {
            return .alreadyAnswered(isAuthorized: status == .authorized || status == .provisional)
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            return granted ? .granted : .denied
        } catch {
            // Le système a refusé de poser la question (profil géré, par exemple). On ne
            // bloque pas le parcours pour autant.
            return .denied
        }
    }

    /// Vrai si les notifications sont déjà accordées. Sert à ne pas montrer un écran qui
    /// promet une boîte de dialogue à quelqu'un qui a déjà dit oui.
    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional
    }
}
