import Combine
import os
import SwiftData
import UIKit
import SwiftUI
import UserNotifications

@main
struct MicaboApp: App {
    private let container: ModelContainer
    /// L'état du compte, créé une fois pour toute l'app et posé dans l'environnement. Deux
    /// écrans qui décideraient chacun s'il y a quelqu'un de connecté finiraient par ne pas
    /// être d'accord.
    @State private var auth = AuthController()
    @State private var sync: CloudSync
    @State private var social: SocialService
    /// L'examen blanc : la copie s'écrit et se corrige sur le serveur, avec le compte.
    @State private var mocks: MockExamService
    /// L'abonnement, créé une fois pour toute l'app : tout ce qui se ferme lui pose la
    /// même question, et personne n'y répond de son côté.
    @State private var pro: ProAccess
    @State private var uiLocale = UiLocaleStore()
    /// Les leçons qui s'écrivent : le travail survit à l'écran qui l'a lancé.
    @State private var lessons: LessonBuilder
    /// Le thème choisi dans le Profil : clair, sombre ou celui du téléphone.
    @State private var appearance = AppearanceStore.shared
    /// Le parcours d'accueil et le premier cours sont dessinés pour le clair : ils le gardent.
    @AppStorage(OnboardingPreferences.Key.completed) private var didCompleteOnboarding = false
    @AppStorage(OnboardingPreferences.Key.pendingFirstImport) private var pendingFirstImport = false
    @Environment(\.scenePhase) private var scenePhase

    private static let schema = Schema([Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self])

    /// Vrai quand l'app ne sert que d'hôte aux tests unitaires : elle ne lance alors ni
    /// réseau, ni achats, ni synchro, ni cours de démonstration. Les tests construisent ce
    /// dont ils ont besoin, et une app qui démarre pour de vrai sur la machine de CI peut
    /// retarder le lancement des tests jusqu'à les faire abandonner.
    static let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    init() {
        FontLoader.registerFonts()
        if Self.isHostingTests {
            container = try! ModelContainer(
                for: Self.schema,
                configurations: ModelConfiguration(schema: Self.schema, isStoredInMemoryOnly: true)
            )
        } else {
            // Avant tout le reste : le SDK doit être configuré avant qu'un écran ne puisse
            // demander une offre, et avant le premier `logIn`.
            PurchasesBridge.configureIfPossible()
            // Avant la fin du lancement, comme iOS le demande : une notification qui ouvre
            // l'app doit trouver son délégué en place.
            UNUserNotificationCenter.current().delegate = ReminderPresenter.shared
            container = Self.makeContainer()
            SampleContentPurge.purgeIfNeeded(in: container.mainContext)
            SubjectCasePass.runIfNeeded(in: container.mainContext)
        }

        let auth = AuthController()
        _auth = State(initialValue: auth)
        let cloud = CloudSync(auth: auth)
        _sync = State(initialValue: cloud)
        // Une conversion que le serveur refuse faute de connaître le cours (`course_unknown`)
        // le fait monter, puis redemande : le constructeur attend cette synchro-là.
        let builder = LessonBuilder()
        let context = container.mainContext
        builder.syncNow = { await cloud.sync(context: context) }
        _lessons = State(initialValue: builder)
        _social = State(initialValue: SocialService(auth: auth))
        _mocks = State(initialValue: MockExamService(auth: auth))
        _pro = State(initialValue: ProAccess(
            accessToken: { await auth.validAccessToken() },
            userID: { auth.billingUserID },
            email: { auth.user?.email }
        ))
        // Le compte, sinon le compte invité de qui a passé la connexion : les fonctions
        // décomptent par utilisateur, et la clé publique n'y passe plus qu'en transition.
        SupabaseFunctions.accessToken = { await auth.functionsAccessToken() }
        // Un 401 d'une fonction : un invité qui n'avait pas pu s'ouvrir s'ouvre maintenant, et
        // l'appel repart une fois avec son jeton.
        SupabaseFunctions.recoverIdentity = { await auth.recoverFunctionsIdentity() }
        // Les statistiques partent avec le jeton du compte quand il y en a un, et sous la
        // clé publique sinon : le parcours d'accueil se mesure **avant** qu'il y ait
        // quelqu'un de connecté, et c'est justement la moitié qui intéresse.
        Analytics.accessToken = { await auth.validAccessToken() }
    }

    var body: some Scene {
        WindowGroup {
            if Self.isHostingTests {
                Color.clear
            } else {
                app
            }
        }
        .modelContainer(container)
    }

    /// **L'apparence de l'app, partout** : le parcours d'accueil et les paywalls compris.
    /// Ils étaient forcés en clair tant que le parcours n'était pas fini, ce qui leur donnait
    /// d'autres couleurs que l'app qui les suit.
    private var colorScheme: ColorScheme? {
        appearance.appearance.colorScheme
    }

    private var app: some View {
        // L'apparence (jour, nuit) est posée ici, pour toute l'app.
        RootView()
            // Une langue choisie dans l'app redessine tout : les écrans de la refonte lisent
            // leurs phrases au moment de se dessiner, pas dans le magasin de langue.
            .id(uiLocale.locale)
            .tint(MicaboColor.accent)
            .environment(auth)
            .environment(sync)
            .environment(social)
            .environment(mocks)
            .environment(pro)
            .environment(uiLocale)
            .environment(lessons)
            .environment(\.locale, uiLocale.locale.foundation)
            .environment(\.layoutDirection, uiLocale.locale.isRightToLeft ? .rightToLeft : .leftToRight)
            .preferredColorScheme(colorScheme)
            // Avant le reste de la tâche : ouvrir la session de statistiques est
            // quelques microsecondes, et tout ce qui suit peut vouloir tracer.
            .onAppear { Analytics.start() }
            // Vider la file en partant à l'arrière-plan, et l'écrire sur disque : c'est
            // le seul moment où l'on sait que l'app risque de ne pas revenir.
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .background:
                    Analytics.flushForBackground()
                    rescheduleRemindersInBackground()
                    syncInBackground()
                case .active: Analytics.enterForeground()
                default: break
                }
            }
            // Une leçon qui naît, un thème qui arrive, une leçon prête : elle monte dans les
            // deux secondes, groupée avec ce qui suit. Jusqu'au 23 octobre 2026, une leçon
            // créée après la connexion n'était poussée qu'au lancement suivant - s'il venait :
            // trente leçons sur cinquante-quatre n'étaient jamais arrivées en base.
            .onReceive(
                NotificationCenter.default.publisher(for: CloudSync.lessonChanged)
                    .debounce(for: .seconds(2), scheduler: RunLoop.main)
            ) { _ in
                Task { await sync.sync(context: container.mainContext) }
            }
            .task {
                #if DEBUG
                // Un vrai cours en PDF, posé au premier lancement d'une construction de
                // développement : la fiche ne se travaille pas sans cours à ficher, et
                // retrouver un document dans le sélecteur de fichiers à chaque
                // réinstallation du simulateur coûtait plus que le cycle qu'on voulait
                // mesurer. Voir `DebugSampleCourse`.
                //
                // Dans sa propre tâche : l'extraction du PDF n'a aucune raison de
                // retarder la restauration de la session, qui suit juste en dessous.
                Task { await DebugSampleCourse.seedIfNeeded(in: container.mainContext) }
                // Six cours fichés et un compte qui a l'air actif, sur le téléphone seulement.
                // Voir `DebugCourseCatalog`.
                DebugCourseCatalog.seedIfNeeded(in: container.mainContext, social: social)
                #endif
                await auth.restore()
                // L'identité RevenueCat **avant** de lire le droit, et avant tout achat :
                // `app_user_id` doit être l'`auth.users.id`, sinon le webhook refuse.
                await PurchasesBridge.identify(auth.billingUserID, guestID: auth.guestUserID)
                await pro.refresh()
                pro.observePurchases()
                // Les prix du pays, une fois par lancement : un paywall qui les
                // demanderait à son ouverture s'afficherait d'abord avec ceux de la
                // France, puis changerait de chiffre sous les yeux.
                await PaywallPurchases.refreshPrices()
                // La première image se pose avant le premier encodage des fiches :
                // c'est ça, pas le réseau, qui figeait l'ouverture.
                await Task.yield()
                try? await Task.sleep(for: .milliseconds(180))
                await sync.sync(context: container.mainContext)
                // Après la synchro et l'abonnement : le rappel nomme un cours, et ne part que
                // pour qui n'a jamais activé l'essai.
                await DailyReminder.reschedule(context: container.mainContext, eligible: pro.receivesDailyReminder)
                // L'annuaire et les amitiés viennent après la synchro : ils n'ont de sens
                // qu'avec un compte, et la synchro est ce qui confirme qu'il y en a un.
                await social.refresh()
            }
            // Une connexion, une déconnexion, un changement de compte : l'identifiant
            // RevenueCat suit, et le droit se relit. Sans ça, un achat partirait sous
            // l'identifiant de la personne précédente.
            //
            // La synchro suit pour la même raison qu'elle suit un lien de courriel :
            // c'est ici qu'on apprend qu'il y a un compte. Sans elle, se connecter
            // depuis le parcours n'apportait ses cours qu'au lancement suivant.
            .onChange(of: auth.user?.id) { _, userID in
                Analytics.account(changedTo: userID)
                Task {
                    await PurchasesBridge.identify(auth.billingUserID, guestID: auth.guestUserID)
                    await pro.refresh()
                    await sync.sync(context: container.mainContext)
                    await social.refresh()
                }
            }
            // Le compte invité vient de s'ouvrir (« Passer ») : RevenueCat passe sous son
            // identifiant avant tout achat, sinon l'abonnement n'aurait pas de propriétaire
            // côté serveur.
            .onChange(of: auth.guestUserID) { _, _ in
                guard auth.user == nil else { return }
                Task {
                    await PurchasesBridge.identify(auth.billingUserID, guestID: auth.guestUserID)
                    await pro.refresh()
                }
            }
            // Les liens de confirmation et de connexion reviennent sur le schéma de
            // Micabo : c'est ici qu'ils ouvrent la session, quel que soit l'écran affiché.
            .onOpenURL { url in
                Task {
                    await auth.handle(callback: url)
                    await PurchasesBridge.identify(auth.billingUserID, guestID: auth.guestUserID)
                    await pro.refresh()
                    await sync.sync(context: container.mainContext)
                    await social.refresh()
                }
            }
    }

    /// **Les rappels du jour, reposés en partant** : c'est là que les cours et le travail de
    /// la journée sont à jour. iOS laisse quelques secondes à l'app qui passe à l'arrière-plan,
    /// et la tâche en demande le temps explicitement pour ne pas être coupée en route.
    private func rescheduleRemindersInBackground() {
        let token = UIApplication.shared.beginBackgroundTask(withName: "DailyReminder")
        Task {
            await DailyReminder.reschedule(context: container.mainContext, eligible: pro.receivesDailyReminder)
            UIApplication.shared.endBackgroundTask(token)
        }
    }

    /// **Une dernière montée en partant.** L'élève qui ferme l'app juste après sa leçon est le
    /// cas le plus courant, et c'était celui qui ne synchronisait jamais. iOS laisse quelques
    /// secondes ; la tâche en demande le temps pour qu'une montée commencée aboutisse.
    private func syncInBackground() {
        guard !Self.isHostingTests else { return }
        let token = UIApplication.shared.beginBackgroundTask(withName: "CloudSync")
        Task {
            await sync.sync(context: container.mainContext)
            UIApplication.shared.endBackgroundTask(token)
        }
    }

    // MARK: - Stockage

    private static let storeLog = Logger(subsystem: "app.micabo", category: "store")

    /// **Ouvrir la base sur disque, sans jamais la jeter.**
    ///
    /// Jusqu'au 23 octobre 2026, n'importe quel échec d'ouverture effaçait les trois fichiers
    /// et repartait d'une base vide : un lancement en arrière-plan avant le premier
    /// déverrouillage (fichier protégé, illisible), un disque plein, et les cours de l'élève
    /// disparaissaient - ceux d'un invité sans synchro pour de bon. Désormais :
    /// - un fichier **illisible** (protégé, verrouillé) n'est pas touché : l'app tourne en
    ///   mémoire le temps de ce lancement, et la synchro se tait (`LocalStore.isVolatile`) pour
    ///   ne pas avancer son repère sur des lignes qui ne seraient pas écrites sur disque ;
    /// - un fichier **lisible que SwiftData refuse** (schéma ou migration incompatible, fichier
    ///   abîmé) est mis de côté sous un nom daté, jamais effacé, puis on repart d'une base
    ///   vide que la synchro reremplit.
    private static func makeContainer() -> ModelContainer {
        try? FileManager.default.createDirectory(
            at: URL.applicationSupportDirectory,
            withIntermediateDirectories: true
        )

        let firstError: Error
        do {
            return try persistentContainer()
        } catch {
            firstError = error
        }
        storeLog.error("Ouverture de la base impossible : \(String(describing: firstError), privacy: .public)")

        // Une seconde chance, telle quelle : un verrou SQLite passager se lève souvent dans
        // l'instant, et c'est le cas où il ne faut surtout rien déplacer.
        if let container = try? persistentContainer() {
            return container
        }

        if storeIsReadable() {
            // Le fichier se lit mais SwiftData n'en veut pas : c'est le schéma, une migration
            // ratée, ou un fichier abîmé. On le met de côté, et on repart d'un fichier neuf.
            let backup = moveStoreAside()
            storeLog.error("Base mise de côté (\(backup ?? "rien à déplacer", privacy: .public)), nouveau fichier.")
            if let backup {
                UserDefaults.standard.set(backup, forKey: "micabo.store.lastBackup")
            }
            do {
                return try persistentContainer()
            } catch {
                storeLog.error("Nouveau fichier impossible lui aussi : \(String(describing: error), privacy: .public)")
            }
        } else {
            storeLog.error("Fichier de base illisible (protégé ou verrouillé) : on n'y touche pas, lancement en mémoire.")
        }

        LocalStore.isVolatile = true
        return try! ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    /// Vrai quand le fichier n'existe pas encore, ou qu'on peut en lire l'en-tête. Faux quand
    /// il existe et ne s'ouvre pas : protection des données avant le premier déverrouillage,
    /// droits, disque. Dans ce cas, l'échec ne dit rien du schéma.
    private static func storeIsReadable() -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return true }
        guard let handle = FileHandle(forReadingAtPath: storeURL.path) else { return false }
        defer { try? handle.close() }
        do {
            _ = try handle.read(upToCount: 16)
            return true
        } catch {
            return false
        }
    }

    /// Déplace les fichiers de la base sous `Micabo-<date>.store.backup` et rend ce nom.
    /// Rien n'est effacé : un fichier qu'une version suivante saurait relire reste là.
    private static func moveStoreAside() -> String? {
        let manager = FileManager.default
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "Micabo-\(formatter.string(from: Date())).store.backup"
        let target = URL.applicationSupportDirectory.appending(path: name)
        var moved = false
        for suffix in ["", "-shm", "-wal"] {
            let source = storeURL.path + suffix
            guard manager.fileExists(atPath: source) else { continue }
            do {
                try manager.moveItem(atPath: source, toPath: target.path + suffix)
                moved = true
            } catch {
                storeLog.error("Déplacement de « \(suffix, privacy: .public) » impossible : \(String(describing: error), privacy: .public)")
            }
        }
        return moved ? name : nil
    }

    private static var storeURL: URL {
        URL.applicationSupportDirectory.appending(path: "Micabo.store")
    }

    /// Ancien nom de l'app (Feymind) : on reprend le fichier SwiftData s'il est encore là.
    private static func migrateLegacyStoreIfNeeded() {
        let manager = FileManager.default
        let legacy = URL.applicationSupportDirectory.appending(path: "Feymind.store")
        guard !manager.fileExists(atPath: storeURL.path),
              manager.fileExists(atPath: legacy.path) else { return }
        for suffix in ["", "-shm", "-wal"] {
            let src = legacy.path + suffix
            let dst = storeURL.path + suffix
            guard manager.fileExists(atPath: src) else { continue }
            try? manager.moveItem(atPath: src, toPath: dst)
        }
    }

    private static func persistentContainer() throws -> ModelContainer {
        migrateLegacyStoreIfNeeded()
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, url: storeURL)
        )
    }

}

/// **L'état de la base locale pour ce lancement.**
enum LocalStore {
    /// Vrai quand la base sur disque n'a pas pu s'ouvrir et que l'app tourne en mémoire. La
    /// synchro ne passe pas alors : elle avancerait son repère sur des lignes perdues à la
    /// fermeture, et le lancement suivant, revenu sur le vrai fichier, ne les redemanderait plus.
    /// Écrit une fois, dans `MicaboApp.init`, avant toute lecture.
    nonisolated(unsafe) static var isVolatile = false
}
