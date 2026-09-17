import Foundation

/// **Le vocabulaire des événements, fermé.**
///
/// Une énumération et pas une chaîne au point d'appel : un tableau de bord qui compte
/// `paywall_opened` d'un côté et `paywallOpened` de l'autre montre deux courbes à moitié
/// vides et ne le dit pas. Le compilateur empêche la faute de frappe, la contrainte de la
/// table empêche le reste.
///
/// **Ajouter un nom est gratuit, en renommer un ne l'est pas** : les lignes déjà écrites
/// gardent l'ancien nom pour toujours. Un nom se garde donc même quand ce qu'il mesure
/// change de place dans l'app.
enum AnalyticsEvent: String, Sendable, CaseIterable {
    // MARK: Cycle de vie

    /// L'app passe au premier plan. Une ouverture, pas un lancement : revenir de
    /// l'arrière-plan après trois heures est le même geste que rouvrir l'app.
    case appOpened = "app_opened"
    case appBackgrounded = "app_backgrounded"
    /// Le tout premier lancement de cette installation. C'est le dénominateur de tout
    /// l'entonnoir : sans lui, « combien vont jusqu'au bout » n'a pas de « sur combien ».
    case appInstalled = "app_installed"

    // MARK: Parcours d'accueil

    case onboardingStarted = "onboarding_started"
    /// Un écran du parcours, avec son nom et son rang. Le rang voyage avec l'événement
    /// pour que l'entonnoir s'ordonne sans recopier la liste des écrans côté serveur.
    case onboardingStep = "onboarding_step"
    /// Une réponse donnée : le pays, le palier, la moyenne visée. C'est ce qui distingue
    /// « a vu l'écran » de « a répondu », et l'écart entre les deux est un abandon.
    case onboardingAnswer = "onboarding_answer"
    case onboardingFinished = "onboarding_finished"

    // MARK: Compte

    case signInStarted = "sign_in_started"
    case signedIn = "signed_in"
    case signInFailed = "sign_in_failed"
    case signedOut = "signed_out"

    // MARK: Paywall

    /// Le paywall s'ouvre, avec la porte qui l'a ouvert (`trigger`).
    case paywallOpened = "paywall_opened"
    /// La seconde page, celle qui compare les offres. « Atteint » au sens où l'étudiant
    /// a dépassé la première offre au lieu de refermer.
    case paywallPlansSeen = "paywall_plans_seen"
    case paywallPurchaseStarted = "paywall_purchase_started"
    case paywallPurchased = "paywall_purchased"
    case paywallPurchaseFailed = "paywall_purchase_failed"
    case paywallPurchaseCancelled = "paywall_purchase_cancelled"
    case paywallRestored = "paywall_restored"
    /// Refermé sans rien acheter. Avec la durée passée dessus : un paywall refermé en
    /// deux secondes et un paywall lu pendant une minute ne se corrigent pas pareil.
    case paywallDismissed = "paywall_dismissed"

    // MARK: Import

    case importOpened = "import_opened"
    /// Un document lu (PDF, photos, Word, transcription) : l'étape entre « a ouvert
    /// l'import » et « a lancé la génération ».
    case importDocumentRead = "import_document_read"
    case importDocumentFailed = "import_document_failed"
    case courseGenerationStarted = "course_generation_started"
    /// Le cours est enregistré. C'est **l'événement qui compte** : tout ce qui précède
    /// n'est qu'une tentative.
    case courseImported = "course_imported"
    case courseGenerationFailed = "course_generation_failed"

    // MARK: Fiche et cartes

    case sheetOpened = "sheet_opened"
    case sheetWriteStarted = "sheet_write_started"
    case sheetWritten = "sheet_written"
    case sheetWriteFailed = "sheet_write_failed"
    case cardsGenerationStarted = "cards_generation_started"
    case cardsGenerated = "cards_generated"
    case cardsGenerationFailed = "cards_generation_failed"

    // MARK: Révision

    case reviewStarted = "review_started"
    case reviewFinished = "review_finished"
}

/// **Ce qu'une étiquette a le droit d'être.**
///
/// Trois formes, et pas `Any` : ce qui part vers le serveur doit pouvoir s'encoder sans
/// jamais échouer, et `Any` demande un `try` au point d'appel — donc, tôt ou tard, un
/// traceur qui plante l'écran qu'il mesure.
///
/// Les littéraux sont acceptés tels quels, pour que le point d'appel se lise comme un
/// dictionnaire ordinaire : `["step": "country", "index": 1, "pro": true]`.
enum AnalyticsValue: Sendable, Codable, ExpressibleByStringLiteral,
                     ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
                     ExpressibleByFloatLiteral {
    case text(String)
    case number(Double)
    case flag(Bool)

    init(stringLiteral value: String) { self = .text(value) }
    init(integerLiteral value: Int) { self = .number(Double(value)) }
    init(booleanLiteral value: Bool) { self = .flag(value) }
    init(floatLiteral value: Double) { self = .number(value) }

    /// Relu depuis le disque : la file en attente survit à une app tuée, et c'est ce
    /// décodage qui la ramène.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) { self = .flag(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else { self = .text(try container.decode(String.self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let value):
            // Le plafond de la table porte sur la ligne entière ; couper ici évite qu'une
            // seule étiquette bavarde fasse refuser tout le lot.
            try container.encode(String(value.prefix(120)))
        case .number(let value):
            // Un entier reste un entier : `3.0` dans un tableau de bord se lit mal.
            if value == value.rounded(), abs(value) < 1e15 {
                try container.encode(Int(value))
            } else {
                try container.encode((value * 1000).rounded() / 1000)
            }
        case .flag(let value):
            try container.encode(value)
        }
    }
}
