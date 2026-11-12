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
    /// Une page des stories du premier écran, vue : `index` de 1 à 4. Une fois par page.
    case onboardingStoryViewed = "onboarding_story_viewed"
    /// La première leçon choisie pendant le parcours : `choice` vaut `topic`, `import` ou
    /// `later`. Jamais le sujet tapé.
    case onboardingFirstLesson = "onboarding_first_lesson"

    // MARK: Compte

    case signInStarted = "sign_in_started"
    case signedIn = "signed_in"
    case signInFailed = "sign_in_failed"
    case signedOut = "signed_out"
    /// Ce qui a échoué côté Apple avant Supabase, avec son étape (`autorisation`,
    /// `identifiant`, `jeton`, `nonce`) et, pour une autorisation refusée, le `domain` et le
    /// `code` de l'erreur. `sign_in_failed` ne dit que « refus » ; celui-ci dit lequel.
    case appleSignInError = "apple_sign_in_error"

    // MARK: Paywall

    /// Le paywall s'ouvre, avec la porte qui l'a ouvert (`trigger`).
    case paywallOpened = "paywall_opened"
    /// La seconde page, celle qui compare les offres. « Atteint » au sens où l'étudiant
    /// a dépassé la première offre au lieu de refermer.
    case paywallPlansSeen = "paywall_plans_seen"
    /// Ce que la boutique répond sur l'essai, offre par offre (`eligible`, `deja_utilise`,
    /// `aucun_essai`, `inconnu`), avec le pays de la boutique.
    case paywallTrialStatus = "paywall_trial_status"
    case paywallPurchaseStarted = "paywall_purchase_started"
    case paywallPurchased = "paywall_purchased"
    case paywallPurchaseFailed = "paywall_purchase_failed"
    case paywallPurchaseCancelled = "paywall_purchase_cancelled"
    /// L'achat attend une validation (partage familial, banque) : ni acheté, ni refusé.
    case paywallPurchasePending = "paywall_purchase_pending"
    case paywallRestored = "paywall_restored"
    /// Refermé sans rien acheter. Avec la durée passée dessus : un paywall refermé en
    /// deux secondes et un paywall lu pendant une minute ne se corrigent pas pareil.
    case paywallDismissed = "paywall_dismissed"
    /// **Un achat qui ouvre un essai gratuit** : posé avec `paywall_purchased` quand l'offre
    /// achetée promettait l'essai à ce compte. Les deux portent `price_display`, la variante
    /// du test de prix (`PriceDisplay`).
    case paywallTrialStarted = "paywall_trial_started"
    /// **Le rappel de fin d'essai est posé** (`TrialEndReminder`) : la veille de la fin, si les
    /// notifications sont permises. Sans propriété.
    case paywallTrialReminder = "paywall_trial_reminder"

    // MARK: Offre de réduction

    /// **L'offre de réduction s'affiche** (lot 10) : `source` dit ce qui y a mené (`paywall` :
    /// un paywall refermé sans achat ; `direct` : la pastille de la Home ou les Réglages ;
    /// `test`), `fresh` si cet affichage a ouvert une fenêtre de vingt-quatre heures. L'achat
    /// du tarif réduit reste `paywall_purchased`, avec `trigger` à `discount`.
    case discountShown = "discount_shown"
    /// L'offre est refusée (« Non merci », la croix), avec `source` et la durée passée dessus.
    case discountDismissed = "discount_dismissed"

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
    /// **La leçon verrouillée** : la leçon offerte a servi, Mika a lu les supports sur
    /// l'appareil, et l'aperçu s'affiche avant le paywall `lessonReady`. Avec `source`,
    /// `supports`, `pages`, `words`. Le dénominateur de la conversion de ce moment-là.
    case lessonLockedPreview = "lesson_locked_preview"
    /// Un écran du parcours de création d'un deck. C'est l'entonnoir de l'import : le
    /// parcours pose sept questions avant la première dépense, et c'est là que se perdent
    /// les decks qui ne seront jamais créés.
    case deckSetupStep = "deck_setup_step"

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

    // MARK: Mika

    /// Une question posée à Mika, et répondue : avec `pro` et `attached`, pour savoir qui
    /// parle à Mika et si c'est avec un document.
    case mikaAsked = "mika_asked"
    /// Une question refusée avant l'appel : `reason` dit si c'est le paywall (la question
    /// offerte est passée) ou le plafond du jour d'un abonné.
    case mikaBlocked = "mika_blocked"
    /// Une carte proposée par Mika, rangée dans un cours.
    case mikaCardAdded = "mika_card_added"

    // MARK: Scanner d'exercices

    /// Un énoncé lu ou tapé : `source` (`camera`, `library`, `typed`) et `subject`, la matière
    /// devinée. Jamais l'énoncé lui-même.
    case solverCaptured = "solver_captured"
    /// Une photo dont l'appareil n'a rien lu, avec sa `source`.
    case solverUnreadable = "solver_unreadable"
    /// Une solution arrivée : `subject`, `steps`, `structured` (les balises lues) et `source`.
    case solverSolved = "solver_solved"
    /// « Je ne comprends pas cette étape », répondu : `subject` et `step`.
    case solverStepHelp = "solver_step_help"
    /// Une réponse à l'exercice d'entraînement corrigée : `subject`, `result` (`right`,
    /// `wrong`, `unknown`).
    case solverPracticeChecked = "solver_practice_checked"
    /// Un message envoyé dans un fil de « Demande à Mika », avec `subject`.
    case tutorAsked = "tutor_asked"

    // MARK: Corriger un texte (lot 7)

    /// Un raccourci des outils de Home : `tool` (`scan`, `writing`, `quiz`).
    case homeToolOpened = "home_tool_opened"
    /// L'écran « Corriger un texte » ouvert.
    case writingOpened = "writing_opened"
    /// Une photo de texte dont l'appareil n'a rien lu.
    case writingUnreadable = "writing_unreadable"
    /// Une relecture arrivée : `source` (`typed`, `pasted`, `photo`), `fixes` (le nombre de
    /// corrections), `applied` (celles retrouvées dans le texte), `structured` et `words`, une
    /// tranche de longueur. Jamais le texte ni une correction.
    case writingChecked = "writing_checked"
    /// Le texte corrigé copié.
    case writingCopied = "writing_copied"

    // MARK: Leçons et synchro

    /// Un thème de leçon que le serveur n'a pas pu écrire : `reason` dit pourquoi
    /// (`provider`, `invalid_json`, `invalid_content`, `network`, `free_limit`…), `retry` si
    /// l'app va le redemander seule. Le 21 octobre 2026, quarante-cinq thèmes ont échoué sans
    /// qu'aucune courbe de l'app ne le montre.
    case lessonThemeFailed = "lesson_theme_failed"
    /// **« Cette leçon t'a aidé ? »** : 👍 ou 👎, une fois par leçon. Avec `lesson_id`,
    /// `rating` (`up`, `down`), `reasons` (séparées par des virgules), `comment` (facultatif,
    /// coupé à 120 caractères), `prompt_version` (celle du serveur qui a écrit le plan, ou
    /// `inconnue`), `path_version`, `source`, `app_language`, `level`, `moment`
    /// (`first_circle`, `finished`) et `created` (le jour de la leçon).
    case lessonRated = "lesson_rated"
    /// Un aller-retour de synchro réussi, avec ce qu'il a poussé (`courses`, `cards`) et
    /// sous quel compte (`user` : `account` ou `guest`). Sans lui, deux leçons sur trois
    /// manquaient en base et rien ne le disait.
    case syncFinished = "sync_finished"
    /// Un aller-retour de synchro interrompu, et sa raison en quelques mots.
    case syncFailed = "sync_failed"
    /// Les lignes de l'invité passées au compte (`claim_guest`), avec ce qui a bougé.
    case guestClaimed = "guest_claimed"
    /// Une réclamation refusée ou tombée, et pourquoi. Le passage suivant la retente.
    case guestClaimFailed = "guest_claim_failed"

    // MARK: Calendrier

    /// Un calendrier créé à la main ou par le scanner, avec sa couleur.
    case calendarCreated = "calendar_created"
    /// Un événement ajouté à la main, avec `weekly`.
    case calendarEventAdded = "calendar_event_added"
    /// Une photo d'emploi du temps lue : `result` (`ok`, `empty`, `unreadable`, `failed`) et
    /// `count`, le nombre de cours trouvés.
    case timetableScanned = "timetable_scanned"
    /// Les cours relus et enregistrés, avec `count`.
    case timetableSaved = "timetable_saved"
    /// Mika a planifié les révisions d'un examen : `count` séances, `days` jours restants.
    case planGenerated = "plan_generated"
    case planCleared = "plan_cleared"
    /// Un planning demandé pour un second examen, sans Pro : le paywall s'ouvre.
    case planBlocked = "plan_blocked"

    // MARK: Concentration

    /// « Commencer la session », avec `mode` et `minutes`.
    case focusPrepared = "focus_prepared"
    /// Une séance lancée : `mode`, `minutes`, `goal` (une leçon visée), `planned` (une
    /// séance du calendrier).
    case focusStarted = "focus_started"
    case focusCompleted = "focus_completed"
    /// Une séance arrêtée en route, avec les minutes faites.
    case focusStopped = "focus_stopped"
    case taskAdded = "task_added"
    case taskDone = "task_done"

    // MARK: Home

    /// Un geste du plan du jour : `step` (`session`, `lesson`, `cards`, `create`), `slot`
    /// (`hero` pour le grand bouton, `secondary` pour la ligne dessous) et `exam` (un examen
    /// est à venir). Rien d'écrit par l'élève.
    case homePlanTapped = "home_plan_tapped"
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
