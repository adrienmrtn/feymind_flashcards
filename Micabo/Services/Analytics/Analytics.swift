import Foundation
import UIKit

/// **Les statistiques d'usage, et la règle qui les gouverne : ne jamais coûter une image.**
///
/// Un traceur se pose sur le chemin le plus chaud de l'app — l'apparition d'un écran, l'appui
/// sur un bouton — et c'est exactement là qu'une milliseconde se voit. La règle tient en une
/// phrase : **le point d'appel ne fait qu'une chose, poser un fait dans une file.** Le reste
/// — l'horodatage en ISO, l'encodage JSON, l'écriture sur disque, la requête — se passe dans
/// un acteur, en priorité utilitaire, hors du fil principal.
///
/// Concrètement, `track` construit un dictionnaire de quelques clés, lit l'heure, et rend la
/// main. Il n'attend rien, ne verrouille rien, ne touche ni au disque ni au réseau, et ne
/// peut pas échouer : une panne de statistiques qui ferait clignoter un écran serait un
/// marché absurde.
///
/// ## Ce qui part, et quand
///
/// Par lots. Vingt événements, ou quinze secondes, ou le passage à l'arrière-plan — le
/// premier des trois. Une requête par geste aurait mis le réseau en permanence sous tension
/// pour des lignes qui n'ont aucune urgence ; le trafic est en plus marqué `.background`,
/// ce qui le fait céder le passage à une génération de fiche en cours.
///
/// ## Ce qui ne se perd pas
///
/// La file est écrite sur disque au passage en arrière-plan et à chaque envoi raté : une app
/// tuée ou un métro sans réseau ne coûtent pas la journée. Une app tuée **pendant** la fenêtre
/// de quinze secondes perd ce qu'elle contenait, et c'est assumé : écrire le disque à chaque
/// événement pour sauver quinze secondes reviendrait à faire le contraire de ce que ce
/// fichier promet.
///
/// Au-delà de cinq cents lignes en attente, les plus anciennes tombent. Une file qui grandit
/// sans fin est une fuite de mémoire qui se déguise en prudence.
enum Analytics {
    /// Le jeton du compte, posé au lancement comme pour les Edge Functions. Sans compte, la
    /// clé publique prend le relais : **la moitié de ce qu'on mesure arrive avant qu'il y
    /// ait quelqu'un de connecté**, et refuser ces lignes viderait l'entonnoir de sa moitié
    /// la plus intéressante.
    static var accessToken: (() async -> String?)?

    /// Pose un fait. Rend la main immédiatement.
    ///
    /// `nonisolated` et synchrone : appelable depuis un `.onAppear`, une action de bouton ou
    /// un acteur, sans `await` et sans se demander sur quel fil on se trouve.
    static func track(_ event: AnalyticsEvent, _ props: [String: AnalyticsValue] = [:]) {
        let at = Date()
        Task.detached(priority: .utility) {
            await AnalyticsQueue.shared.append(name: event.rawValue, props: props, at: at)
        }
    }

    /// À appeler une fois au lancement : ouvre une session, signale l'installation au tout
    /// premier démarrage, et reprend ce qu'un lancement précédent n'avait pas pu envoyer.
    static func start() {
        Task.detached(priority: .utility) {
            await AnalyticsQueue.shared.start()
        }
    }

    /// Le compte a changé. Les lignes suivantes porteront le nouvel identifiant — le serveur
    /// le lit de la session, jamais de la requête, mais l'app a besoin de savoir quand
    /// émettre `signedIn` et `signedOut`.
    static func account(changedTo userID: UUID?) {
        Task.detached(priority: .utility) {
            await AnalyticsQueue.shared.account(changedTo: userID)
        }
    }

    /// L'app passe à l'arrière-plan : on vide la file et on écrit ce qui reste.
    static func flushForBackground() {
        Task.detached(priority: .utility) {
            await AnalyticsQueue.shared.flushForBackground()
        }
    }

    /// L'app revient au premier plan. Une nouvelle session au-delà de trente minutes : deux
    /// coups d'œil à cinq minutes d'écart sont la même session, revenir le lendemain matin
    /// n'en est pas une.
    static func enterForeground() {
        Task.detached(priority: .utility) {
            await AnalyticsQueue.shared.enterForeground()
        }
    }
}

/// La file, et tout ce qui coûte.
///
/// Un acteur plutôt qu'une file sérielle : l'état — les lignes en attente, la tâche de
/// vidage, le délai d'attente courant — est partagé entre le fil principal, le réseau et le
/// disque, et l'isolement d'acteur est ce qui rend cette cohabitation vérifiable par le
/// compilateur plutôt que par l'attention.
actor AnalyticsQueue {
    static let shared = AnalyticsQueue()

    // MARK: Réglages

    /// Le lot qui déclenche un envoi immédiat.
    private static let batch = 20
    /// La fenêtre d'attente avant d'envoyer un lot incomplet.
    private static let window: Duration = .seconds(15)
    /// Ce qu'on garde au plus. Au-delà, les plus anciennes tombent.
    private static let ceiling = 500
    /// Au-delà de ce silence, revenir au premier plan ouvre une nouvelle session.
    private static let sessionGap: TimeInterval = 30 * 60

    private enum Key {
        static let device = "micabo.analytics.deviceId"
        static let installed = "micabo.analytics.didInstall"
        static let lastSeen = "micabo.analytics.lastSeen"
    }

    // MARK: État

    private var pending: [AnalyticsRow] = []
    private var context: AnalyticsContext?
    private var flush: Task<Void, Never>?
    /// L'attente après un échec, doublée à chaque fois et plafonnée à cinq minutes. Un
    /// téléphone sans réseau ne doit pas réessayer toutes les quinze secondes pendant une
    /// heure : c'est de la batterie dépensée pour des lignes qui peuvent attendre.
    private var backoff: Duration = .seconds(15)
    private var userID: UUID?

    private let defaults = UserDefaults.standard

    /// Le disque : un seul fichier JSON, remplacé en entier. Les lots sont petits, et un
    /// format qui s'ajoute par morceaux se répare mal quand l'app meurt au milieu.
    private var store: URL {
        URL.applicationSupportDirectory.appending(path: "Micabo.events.json")
    }

    /// Le transport, en `.background` : le système fait passer une génération de fiche
    /// avant ces lignes, ce qui est exactement l'ordre voulu.
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.networkServiceType = .background
        // Sans ça, un appel sans réseau reste pendu jusqu'au délai plutôt que d'échouer et
        // de rendre la main à la file, qui sait déjà attendre.
        configuration.waitsForConnectivity = false
        configuration.allowsExpensiveNetworkAccess = true
        return URLSession(configuration: configuration)
    }()

    // MARK: Cycle de vie

    func start() {
        guard context == nil else { return }
        context = AnalyticsContext.current(deviceID: deviceID(), sessionID: UUID())
        restoreFromDisk()

        if !defaults.bool(forKey: Key.installed) {
            defaults.set(true, forKey: Key.installed)
            enqueue(name: AnalyticsEvent.appInstalled.rawValue, props: [:], at: Date())
        }
        enqueue(name: AnalyticsEvent.appOpened.rawValue, props: [:], at: Date())
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastSeen)
    }

    func account(changedTo newValue: UUID?) {
        guard newValue != userID else { return }
        let hadAccount = userID != nil
        userID = newValue
        if newValue != nil {
            enqueue(name: AnalyticsEvent.signedIn.rawValue, props: [:], at: Date())
        } else if hadAccount {
            enqueue(name: AnalyticsEvent.signedOut.rawValue, props: [:], at: Date())
        }
    }

    func enterForeground() {
        let last = defaults.double(forKey: Key.lastSeen)
        let silence = Date().timeIntervalSince1970 - last
        if silence > Self.sessionGap, let old = context {
            context = AnalyticsContext(
                deviceID: old.deviceID,
                sessionID: UUID(),
                country: old.country,
                locale: old.locale,
                appVersion: old.appVersion,
                build: old.build
            )
        }
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastSeen)
        enqueue(name: AnalyticsEvent.appOpened.rawValue, props: [:], at: Date())
    }

    func flushForBackground() {
        defaults.set(Date().timeIntervalSince1970, forKey: Key.lastSeen)
        enqueue(name: AnalyticsEvent.appBackgrounded.rawValue, props: [:], at: Date())
        // Sur disque **avant** l'envoi : le système peut suspendre l'app au milieu de la
        // requête, et une file écrite est une file qui repart au prochain lancement.
        writeToDisk()
        flush?.cancel()
        flush = Task { [weak self] in await self?.send() }
    }

    // MARK: File

    func append(name: String, props: [String: AnalyticsValue], at date: Date) {
        if context == nil { start() }
        enqueue(name: name, props: props, at: date)
    }

    private func enqueue(name: String, props: [String: AnalyticsValue], at date: Date) {
        guard AppConfig.isConfigured, let context else { return }

        pending.append(AnalyticsRow(
            deviceID: context.deviceID,
            sessionID: context.sessionID,
            name: name,
            props: props,
            country: context.country,
            schoolCountry: OnboardingPreferences.schoolingCountry.rawValue,
            locale: context.locale,
            platform: "ios",
            appVersion: context.appVersion,
            build: context.build,
            // Lu des réglages et non de `ProAccess`, qui vit sur le fil principal : y
            // sauter depuis cet acteur pour une ligne de statistique serait précisément le
            // saut qu'on cherche à ne jamais faire.
            isPro: defaults.bool(forKey: ProAccess.Key.isPro),
            occurredAt: date
        ))

        if pending.count > Self.ceiling {
            pending.removeFirst(pending.count - Self.ceiling)
        }

        schedule(after: pending.count >= Self.batch ? .zero : Self.window)
    }

    private func schedule(after delay: Duration) {
        guard flush == nil || delay == .zero else { return }
        flush?.cancel()
        flush = Task { [weak self] in
            if delay > .zero {
                try? await Task.sleep(for: delay)
                if Task.isCancelled { return }
            }
            await self?.send()
        }
    }

    // MARK: Envoi

    private func send() async {
        // Relâché d'abord : les `schedule` de la suite doivent pouvoir poser la prochaine
        // tentative, et un `defer` qui remettrait `nil` après eux laisserait deux tâches de
        // vidage tourner en parallèle sur la même file.
        flush = nil
        guard !pending.isEmpty else { return }

        // Le lot part en entier : PostgREST accepte un tableau, et vingt lignes en une
        // requête coûtent le prix d'une.
        let batch = pending

        // Construit comme partout ailleurs, avec la session remplacée ensuite : c'est le
        // seul appelant qui ne veut pas de celle par défaut, et passer par l'initialiseur
        // implicite ferait dépendre ce fichier de l'ordre des champs de la structure.
        var database = SupabaseDatabase(
            accessToken: { await Analytics.accessToken?() ?? AppConfig.supabaseAnonKey }
        )
        database.session = session

        do {
            try await database.insert(batch, into: "app_events")
        } catch {
            // Rien à dire à l'utilisateur, et rien à réessayer tout de suite : les lignes
            // restent, le prochain essai est plus loin, et le disque garde la trace au cas
            // où l'app ne reviendrait pas.
            writeToDisk()
            backoff = min(backoff * 2, .seconds(300))
            schedule(after: backoff)
            return
        }

        pending.removeFirst(min(batch.count, pending.count))
        backoff = .seconds(15)
        writeToDisk()
        // Des lignes sont arrivées pendant l'envoi : on repart sans attendre la fenêtre.
        if !pending.isEmpty { schedule(after: .zero) }
    }

    // MARK: Disque

    private func writeToDisk() {
        guard !pending.isEmpty else {
            try? FileManager.default.removeItem(at: store)
            return
        }
        guard let data = try? JSONEncoder.analytics.encode(pending) else { return }
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )
        try? data.write(to: store, options: .atomic)
    }

    private func restoreFromDisk() {
        guard let data = try? Data(contentsOf: store),
              let rows = try? JSONDecoder.analytics.decode([AnalyticsRow].self, from: data)
        else { return }
        pending = Array(rows.suffix(Self.ceiling)) + pending
        if !pending.isEmpty { schedule(after: Self.window) }
    }

    // MARK: Identité de l'appareil

    /// L'identifiant de l'installation. Tiré au premier lancement, gardé ensuite, effacé
    /// avec l'app. Ce n'est ni l'`identifierForVendor` ni rien qui suive quelqu'un d'une app
    /// à l'autre : il ne sert qu'à relier l'écran de bienvenue à l'abonnement pris vingt
    /// minutes plus tard, dans cette app-ci.
    private func deviceID() -> UUID {
        if let raw = defaults.string(forKey: Key.device), let id = UUID(uuidString: raw) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: Key.device)
        return id
    }
}

// MARK: - Formats

extension JSONEncoder {
    /// Les dates en ISO 8601 avec fractions, comme le reste de la base. Ce n'est utilisé que
    /// pour le fichier d'attente : l'envoi passe par l'encodeur de `SupabaseDatabase`.
    static var analytics: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var analytics: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
