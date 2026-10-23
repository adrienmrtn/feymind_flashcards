import SwiftData
import SwiftUI
import UIKit

/// Réglages du backend IA et des données locales.
/// Mise en page en blocs blancs : un intitulé en capitales, des rangées à tuile
/// pastel, et une note grise quand une explication est nécessaire.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var supabaseURL = AppConfig.supabaseURL
    @State private var anonKey = AppConfig.supabaseAnonKey
    @State private var model = AppConfig.aiModel
    @Environment(AuthController.self) private var auth
    @Environment(CloudSync.self) private var sync
    @Environment(SocialService.self) private var social

    @State private var username = ""

    @State private var stage = OnboardingPreferences.educationStage
    @State private var country = OnboardingPreferences.schoolingCountry
    /// La langue des fiches, quand elle n'est pas celle du pays. `nil` : celle du pays.
    @State private var sheetLanguage = OnboardingPreferences.sheetLanguage
    @State private var showResetConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showAuth = false
    @State private var showSubjects = false
    @State private var showSchool = false
    @State private var showFeedback = false
    @State private var subjects = OnboardingPreferences.subjects
    @State private var schoolName = OnboardingPreferences.institutionName

    @Environment(ProAccess.self) private var pro: ProAccess?
    @State private var paywall: PaywallTrigger?
    @State private var discountOffer: DiscountPresentation?
    /// Ce que répondent les boutons de test des notifications.
    @State private var notificationReport: String?
    /// Vrai quand la réponse se règle dans les Réglages d'iOS : l'alerte y mène.
    @State private var notificationReportOffersSettings = false
    #if DEBUG
    @State private var debugCourseLanguage = DebugCourseCatalog.language
    #endif
    /// Relues pour que la rangée de l'offre suive son décompte sans qu'on rouvre l'écran.
    @AppStorage(DiscountOffer.Key.startedAt) private var discountStartedAt: Double = 0

    private let models = [
        "google/gemini-2.5-flash-lite",
        "google/gemini-2.5-flash",
        "google/gemini-2.0-flash-001",
        "openai/gpt-4o-mini"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                proSection
                accountSection
                identitySection
                studiesSection
                languageSection
                #if DEBUG
                debugCoursesSection
                intelligenceSection
                connectionSection
                #endif
                dataSection
                testSection
                feedbackSection
                aboutSection
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .micaboScreenBackground()
        // Les cours de l'appareil décident si l'offre de bienvenue est méritée. Recompté à
        // l'ouverture et après chaque synchro lancée d'ici, qui peut en faire descendre.
        .task(id: "\(CourseLedger.shared.stamp)-\(sync.epoch)") {
            let count = CourseRepository.ownedCount(in: modelContext)
            if count != ownedCourseCount { ownedCourseCount = count }
        }
        .confirmationDialog(
            i18n.t("ios.deleteAccountQ"),
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button(i18n.t("ios.deleteAccount"), role: .destructive) {
                Task { await auth.deleteAccount() }
            }
            Button(i18n.t("ios.cancel"), role: .cancel) {}
        } message: {
            Text(i18n.t("ios.deleteAccountMsg"))
        }
        .confirmationDialog(
            i18n.t("ios.eraseAllQ"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(i18n.t("ios.eraseAll"), role: .destructive, action: eraseEverything)
            Button(i18n.t("ios.cancel"), role: .cancel) {}
        } message: {
            Text(i18n.t("ios.eraseAllMsg"))
        }
        .confirmationDialog(
            i18n.t("ios.signOutQ"),
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button(i18n.t("common.signOut"), role: .destructive) {
                Task {
                    // On remonte une dernière fois avant de partir : une révision faite dans
                    // la minute qui précède ne doit pas être le prix d'une déconnexion.
                    await sync.sync(context: modelContext)
                    await auth.signOut()
                    sync.forget()
                }
            }
            Button(i18n.t("ios.cancel"), role: .cancel) {}
        } message: {
            Text(i18n.t("ios.signOutMsg"))
        }
        .alert(
            i18n.t("ios.debug.notifTitle"),
            isPresented: Binding(get: { notificationReport != nil }, set: { if !$0 { notificationReport = nil } })
        ) {
            if notificationReportOffersSettings {
                Button(i18n.t("ios.debug.openSettings")) {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
            Button(i18n.t("ios.ok"), role: .cancel) {}
        } message: {
            Text(notificationReport ?? "")
        }
        .micaboPaywall($paywall)
        .micaboDiscountOffer($discountOffer)
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(isPresented: $showAuth) {
            // Plus de « continuer sans compte » : `AuthView` n'a plus de sortie, et la
            // feuille se referme toute seule dès que la connexion aboutit.
            AuthView(placement: .sheet, onDismiss: { showAuth = false })
                .presentationCornerRadius(MicaboRadius.sheet)
                .onChange(of: auth.isSignedIn) { _, isSignedIn in
                    guard isSignedIn else { return }
                    showAuth = false
                    Task { await sync.sync(context: modelContext) }
                }
        }
    }

    // MARK: - Sections

    private var header: some View {
        MicaboScreenHeader(title: i18n.t("settings.title"), back: MicaboHeaderBack.back(saveAndClose)) {
            Button(i18n.t("ios.done"), action: saveAndClose)
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .buttonStyle(MicaboPressableButtonStyle())
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// **L'abonnement, en tête des Réglages.**
    ///
    /// Il n'y avait aucun endroit stable pour voir son abonnement ni pour retrouver un prix :
    /// le paywall ne s'ouvrait qu'en butant sur une porte fermée, et le tarif réduit n'existait
    /// que dans un cadeau qui surgit une fois. Un prix qu'on ne peut pas aller chercher est un
    /// prix qu'on ne paie pas — et, pour App Review, un achat « introuvable dans l'app ».
    ///
    /// Deux rangées au plus. L'offre de bienvenue n'apparaît qu'une fois méritée (un cours
    /// importé) ; l'ouvrir d'ici **relance sa fenêtre**, de sorte qu'elle soit toujours
    /// achetable, y compris pendant son repos.
    @ViewBuilder
    private var proSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.pro.section"))

            VStack(spacing: 0) {
                if isSubscribed {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("star.fill"), background: MicaboColor.accentSoft),
                        title: i18n.t("ios.pro.title"),
                        subtitle: i18n.t("ios.pro.active"),
                        accessory: .none
                    )

                    // La gestion d'un abonnement se fait chez celui qui l'encaisse — Apple,
                    // Google, ou le site pour un achat Stripe — et nulle part ailleurs : une app
                    // qui prétendrait résilier à sa place mentirait. Un accès offert n'a rien à
                    // gérer, et la rangée disparaît.
                    if let manageURL {
                        MicaboHairline(inset: 72)

                        MicaboRow(
                            tile: MicaboTile(glyph: .symbol("doc.plaintext.fill"), background: MicaboColor.surfaceMuted),
                            title: i18n.t("ios.pro.manage"),
                            subtitle: manageHelp,
                            accessory: .chevron,
                            action: { UIApplication.shared.open(manageURL) }
                        )
                    }
                } else {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("star.fill"), background: MicaboColor.accentSoft),
                        title: i18n.t("ios.pro.upgrade"),
                        subtitle: i18n.t("ios.pro.upgradeHelp"),
                        accessory: .chevron,
                        action: { paywall = .upgrade }
                    )

                    if DiscountOffer.isReachable(isPro: isSubscribed, courseCount: ownedCourseCount) {
                        MicaboHairline(inset: 72)

                        MicaboRow(
                            tile: MicaboTile(glyph: .symbol("gift.fill"), background: MicaboColor.tilePastels[1]),
                            title: i18n.t("ios.pro.offer"),
                            subtitle: discountSubtitle,
                            accessory: .chevron,
                            action: { discountOffer = .paywall }
                        )
                    }
                }
            }
            .micaboGroup()
        }
    }

    /// Vrai seulement si le droit est connu **et** ouvert : un environnement sans `ProAccess`
    /// doit montrer le prix, pas le cacher.
    private var isSubscribed: Bool { pro?.isPro ?? false }

    /// Les cours importés ici. Ceux repris de la bibliothèque ne comptent pas : on n'a rien
    /// fait pour eux.
    ///
    /// Compté et non observé : une seule rangée le lit — la ligne de l'offre, plus haut — et
    /// un `@Query` tenait pour ça la table entière des cours, trente kilo-octets de texte par
    /// ligne.
    ///
    /// Il est relu après une synchronisation, parce que **cette feuille en lance une**
    /// (« Synchroniser maintenant », plus bas) : un compte connecté qui reçoit ses cours
    /// depuis le serveur doit voir la rangée de l'offre apparaître sans refermer les Réglages.
    ///
    /// La valeur de départ est celle qu'a laissée la languette de l'offre, qui compte la même
    /// chose : la première image de la feuille est donc juste, au lieu de montrer une liste
    /// sans la rangée puis de l'y insérer.
    @AppStorage(DiscountOffer.Key.ownedCourses) private var ownedCourseCount = 0

    /// « -43 % sur l'année » et, quand la fenêtre court, le temps qu'il reste.
    private var discountSubtitle: String {
        let percent = i18n.t("ios.pro.offerHelp", ["percent": "\(DiscountOffer.savingsPercent)"])
        guard discountStartedAt > 0 else { return percent }
        let startedAt = Date(timeIntervalSince1970: discountStartedAt)
        let left = DiscountOffer.windowRemaining(startedAt: startedAt)
        guard left > 0 else { return percent }
        return "\(percent) · \(DiscountOffer.countdown(left))"
    }

    /// Où gérer l'abonnement en cours : la page du magasin qui l'encaisse. Un magasin inconnu
    /// (une ligne ancienne, un SDK muet) retombe sur l'App Store, comme avant ; un accès offert
    /// n'a pas de page.
    private var manageURL: URL? {
        (pro?.store ?? .appStore).manageURL
    }

    /// La petite ligne sous « Gérer l'abonnement » : elle dit où l'on va. « Chez Apple »
    /// posé sur un abonnement pris sur Google Play enverrait chercher au mauvais endroit.
    private var manageHelp: String {
        switch pro?.store ?? .appStore {
        case .playStore: i18n.t("app.subscription.fromPlay")
        case .stripe: i18n.t("app.subscription.fromWeb")
        case .appStore, .promotional: i18n.t("ios.pro.manageHelp")
        }
    }

    /// Le compte, et l'état de la synchro.
    ///
    /// C'est le seul endroit où l'on voit si les cours sont en sécurité ailleurs que sur ce
    /// téléphone, et il le dit franchement dans les deux cas. Un utilisateur resté en local
    /// n'est pas harcelé : une rangée, une phrase, et il décide.
    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.account"))

            VStack(spacing: 0) {
                if let user = auth.user {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("person.fill"), background: MicaboColor.accentSoft),
                        title: user.label,
                        subtitle: user.email ?? i18n.t("ios.connected"),
                        accessory: .none
                    )

                    MicaboHairline(inset: 72)

                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("icloud.fill"), background: MicaboColor.tilePastels[3]),
                        title: i18n.t("ios.backup"),
                        subtitle: syncSubtitle,
                        accessory: .none,
                        action: { Task { await sync.sync(context: modelContext) } }
                    )

                    MicaboHairline(inset: 72)

                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("rectangle.portrait.and.arrow.right"), background: MicaboColor.surfaceMuted),
                        title: i18n.t("common.signOut"),
                        accessory: .none,
                        titleColor: MicaboColor.negative,
                        action: { showSignOutConfirmation = true }
                    )
                } else {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("icloud.fill"), background: MicaboColor.tilePastels[3]),
                        title: i18n.t("ios.createOrSignIn"),
                        subtitle: i18n.t("ios.createOrSignInHelp"),
                        accessory: .chevron,
                        action: { showAuth = true }
                    )
                }
            }
            .micaboGroup()
        }
    }

    private var syncSubtitle: String {
        switch sync.state {
        case .idle: i18n.t("ios.tapToSync")
        case .syncing: i18n.t("ios.syncing")
        case .done(let date):
            i18n.t("ios.upToDate", ["time": Self.timeText(date, locale: i18n.locale)])
        case .failed(let message): message
        }
    }

    /// L'heure de la dernière synchro, écrite comme la langue l'écrit.
    ///
    /// Le formateur était figé sur `fr_FR` et sur « HH:mm » : un lecteur anglophone lisait
    /// « 15:42 » au milieu d'un écran par ailleurs en anglais. Le gabarit `j:mm` laisse
    /// ICU choisir les douze ou les vingt-quatre heures, et le formateur se refait à chaque
    /// appel parce qu'un `static let` aurait gardé la langue du premier lancement.
    private static func timeText(_ date: Date, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("j:mm")
        return formatter.string(from: date)
    }

    /// Le nom d'utilisateur, et rien d'autre dans cette section.
    ///
    /// Il est donné à l'inscription, dérivé de ce que le fournisseur OAuth a fourni — « Adrien
    /// Martinot » devient `adrien-7910` — pour qu'on n'ait rien à choisir avant d'avoir compris
    /// à quoi ça sert. Il se change ici, parce qu'un identifiant qu'on va dicter à ses
    /// camarades doit pouvoir être le sien.
    ///
    /// Le champ ne refuse rien : ce qu'on tape est mis en forme au fur et à mesure, majuscules
    /// et accents compris. C'est la base qui a le dernier mot sur l'unicité, et le message
    /// vient d'elle.
    @ViewBuilder
    private var identitySection: some View {
        if auth.isSignedIn {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: i18n.t("ios.usernameLabel"))

                HStack(spacing: 11) {
                    Text("@")
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)

                    TextField(i18n.t("ios.usernamePlaceholder"), text: $username)
                        .font(MicaboFont.rowTitle)
                        .foregroundStyle(MicaboColor.ink)
                        .tint(MicaboColor.accent)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { commitUsername() }

                    if social.isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MicaboColor.progress)
                    } else if hasUsernameChange {
                        Button(i18n.t("app.common.save"), action: commitUsername)
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(MicaboColor.accent)
                            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                    }
                }
                .padding(.vertical, 13)
                .padding(.horizontal, MicaboSpacing.md)
                .micaboGroup()

                usernameFootnote
            }
            .onAppear { username = social.username ?? "" }
            .onChange(of: social.username) { _, new in
                guard let new else { return }
                username = new
            }
        }
    }

    /// Ce que le nom va devenir, ou ce qui l'empêche.
    ///
    /// La mise en forme **ne se fait plus sous les doigts**, et c'était un vrai défaut : elle
    /// retirait le séparateur en attente à chaque frappe, si bien que taper « Adrien Martinot »
    /// lettre par lettre donnait `adrienmartinot`. Seul un collage marchait. Le champ laisse
    /// donc taper ce qu'on veut, et la ligne du dessous annonce ce qui sera enregistré.
    @ViewBuilder
    private var usernameFootnote: some View {
        if let notice = social.failure, hasUsernameChange {
            Text(notice)
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.negative)
                .fixedSize(horizontal: false, vertical: true)
        } else if hasUsernameChange {
            let preview = Username.normalize(username)
            MicaboSectionFootnote(
                text: preview.isEmpty
                    ? i18n.t("ios.usernameRules")
                    : i18n.t("ios.usernameSavedAs", ["name": Username.display(preview)])
            )
        }
    }

    private var hasUsernameChange: Bool {
        let typed = username.trimmingCharacters(in: .whitespaces)
        return !typed.isEmpty && Username.normalize(typed) != (social.username ?? "")
    }

    private func commitUsername() {
        let candidate = username
        Task {
            let saved = await social.setUsername(candidate)
            if saved {
                Haptics.success()
                username = social.username ?? candidate
            }
        }
    }

    /// Pour qui les fiches sont écrites, et à quelle longueur.
    ///
    /// Le stade d'étude est demandé à l'inscription et servait uniquement à cadrer le
    /// discours du parcours d'accueil ; il commande maintenant la rédaction des fiches. Il
    /// se corrige donc ici, parce qu'on change d'année, et parce qu'une réponse donnée en
    /// trente secondes le premier jour ne doit pas se payer pendant deux ans.
    private var studiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.yourStudies"))

            VStack(spacing: 0) {
                // Le pays passe avant le stade, comme dans le parcours d'accueil : c'est lui
                // qui décide des paliers proposés juste en dessous.
                Menu {
                    Picker(i18n.t("ios.country"), selection: $country) {
                        ForEach(SchoolingCountry.allCases) { value in
                            Text("\(value.flag) \(value.localizedName(locale: i18n.locale))").tag(value)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji(country.flag), background: MicaboColor.tilePastels[2]),
                        title: i18n.t("ios.country"),
                        subtitle: i18n.t("ios.writesIn", ["language": country.language.label]),
                        accessory: .value(country.localizedName(locale: i18n.locale))
                    )
                }

                MicaboHairline(inset: 72)

                // **La langue des fiches se choisit.** Elle suit le pays par défaut, et
                // un élève scolarisé en France qui révise en anglais, ou l'inverse, la
                // change ici : « changer la langue de l'app » ne la changeait pas, et il
                // n'y avait nulle part où le faire.
                Menu {
                    Picker(i18n.t("ios.sheetLanguageCaption"), selection: $sheetLanguage) {
                        Text(i18n.t("ios.sheetLanguage.auto", ["language": country.language.label]))
                            .tag(Optional<ContentLanguage>.none)
                        ForEach(ContentLanguage.allCases) { value in
                            Text(value.label).tag(Optional(value))
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("pencil"), background: MicaboColor.tilePastels[1]),
                        title: i18n.t("ios.sheetLanguageCaption"),
                        subtitle: i18n.t("settings.sheetLanguageHelp"),
                        accessory: .value((sheetLanguage ?? country.language).label)
                    )
                }

                MicaboHairline(inset: 72)

                Menu {
                    Picker(i18n.t("ios.stage"), selection: $stage) {
                        ForEach(country.stages) { value in
                            Text("\(value.emoji) \(value.localizedTitle)").tag(Optional(value))
                        }
                        Text(i18n.t("ios.unspecified")).tag(Optional<EducationStage>.none)
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("graduationcap.fill"), background: MicaboColor.tilePastels[0]),
                        title: i18n.t("ios.stage"),
                        subtitle: stage?.level.detail ?? i18n.t("ios.balancedCopy"),
                        accessory: .value(stage?.localizedTitle ?? i18n.t("ios.unspecified"))
                    )
                }

                MicaboHairline(inset: 72)

                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("books.vertical.fill"), background: MicaboColor.tilePastels[4]),
                    title: i18n.t("ios.subjects"),
                    subtitle: subjectsSubtitle,
                    accessory: .chevron,
                    action: { showSubjects = true }
                )

                MicaboHairline(inset: 72)

                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("building.columns.fill"), background: MicaboColor.tilePastels[5]),
                    title: i18n.t("ios.school"),
                    subtitle: schoolName?.nilIfBlank ?? i18n.t("ios.schoolEmpty"),
                    accessory: .chevron,
                    action: { showSchool = true }
                )


            }
            .micaboGroup()
        }
        // Le changement de pays écrit déjà le palier qu'il vient de reporter : sans ce
        // garde, la réaction en chaîne l'écrirait deux fois et vibrerait deux fois pour un
        // seul choix.
        .onChange(of: stage) { _, newValue in
            guard newValue != OnboardingPreferences.educationStage else { return }
            OnboardingPreferences.educationStage = newValue
            Haptics.selection()
        }
        // Changer de pays change la liste des paliers : celui qui était choisi est reporté
        // sur son équivalent quand il en a un, et abandonné sinon. Garder « PASS » après un
        // passage aux États-Unis laisserait affiché un palier absent du menu.
        .onChange(of: country) { _, newValue in
            OnboardingPreferences.schoolingCountry = newValue
            stage = newValue.resolvedStage(id: nil, tier: stage?.tier, level: stage?.level)
            OnboardingPreferences.educationStage = stage
            Haptics.selection()
            // Le changement monte tout de suite : sans ça, la descente du prochain
            // lancement pouvait le recouvrir avec le profil de la veille.
            Task { await sync.sync(context: modelContext) }
        }
        .onChange(of: sheetLanguage) { _, newValue in
            OnboardingPreferences.sheetLanguage = newValue
            Haptics.selection()
            Task { await sync.sync(context: modelContext) }
        }
        .sheet(isPresented: $showSubjects, onDismiss: { subjects = OnboardingPreferences.subjects }) {
            SettingsSubjectsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(isPresented: $showSchool, onDismiss: { schoolName = OnboardingPreferences.institutionName }) {
            SettingsSchoolSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(MicaboRadius.sheet)
        }
    }

    private var subjectsSubtitle: String {
        if subjects.isEmpty { return i18n.t("ios.noSubjects") }
        let locale = i18n.locale
        let shown = subjects.map { SubjectDisplay.subject($0, locale: locale) }
        if shown.count <= 3 { return shown.joined(separator: ", ") }
        return "\(shown.prefix(3).joined(separator: ", ")) +\(shown.count - 3)"
    }

    private var languageSection: some View {
        LanguageSwitcher(variant: .card)
    }

    #if DEBUG
    /// **Les cours de debug** : leur langue, la copie corrigée, et de quoi les retirer. Pas
    /// traduit : ces lignes n'existent que dans les constructions de développement.
    private var debugCoursesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Cours de debug")

            VStack(spacing: 0) {
                Menu {
                    Picker("Langue des cours de debug", selection: $debugCourseLanguage) {
                        ForEach(UiLocale.allCases) { locale in
                            Text("\(locale.flag)  \(locale.nativeName)").tag(locale)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("testtube.2"), background: MicaboColor.accentSoft),
                        title: "Langue des cours de debug",
                        subtitle: "\(debugCourseLanguage.flag)  \(debugCourseLanguage.nativeName) · réinstalle les 6 cours et l'activité",
                        accessory: .symbol("chevron.up.chevron.down")
                    )
                }


                MicaboHairline()

                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("wand.and.stars"), background: MicaboColor.tilePastels[3]),
                    title: "Retirer les cours de debug",
                    subtitle: "Cours, révisions, épreuves et amis simulés",
                    accessory: .none,
                    titleColor: MicaboColor.negative,
                    action: {
                        DebugCourseCatalog.removeAll(in: modelContext)
                        social.debugClear()
                        Haptics.success()
                    }
                )
            }
            .micaboGroup()
        }
        .onChange(of: debugCourseLanguage) { _, locale in
            DebugCourseCatalog.install(locale: locale, in: modelContext, social: social)
            Haptics.success()
        }
    }
    #endif

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.debug.intelligence"))

            VStack(spacing: 0) {
                Menu {
                    Picker(i18n.t("ios.debug.model"), selection: $model) {
                        ForEach(models, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .symbol("brain.head.profile"), background: MicaboColor.accentSoft),
                        title: i18n.t("ios.debug.model"),
                        subtitle: model,
                        accessory: .symbol("chevron.up.chevron.down")
                    )
                }
            }
            .micaboGroup()
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n.t("ios.debug.connection"))

            VStack(spacing: 0) {
                fieldRow(
                    emoji: "☁️",
                    background: MicaboColor.tilePastels[3],
                    title: i18n.t("ios.debug.supabaseURL"),
                    placeholder: "https://your-project.supabase.co",
                    text: $supabaseURL
                )

                MicaboHairline(inset: 72)

                fieldRow(
                    emoji: "🔑",
                    background: MicaboColor.tilePastels[5],
                    title: i18n.t("ios.debug.publicKey"),
                    placeholder: "sb_publishable_…",
                    text: $anonKey
                )
            }
            .micaboGroup()
        }
    }

    private var dataSection: some View {
        var rows = [
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("arrow.triangle.2.circlepath"), background: MicaboColor.tilePastels[1]),
                title: i18n.t("ios.restoreDefaults"),
                accessory: .none,
                action: restoreDefaults
            ),
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("trash.fill"), background: MicaboColor.negativeSoft),
                title: i18n.t("ios.eraseAllCourses"),
                accessory: .none,
                titleColor: MicaboColor.negative,
                action: { showResetConfirmation = true }
            )
        ]
        if case .signedIn = auth.state {
            rows.append(
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("rectangle.portrait.and.arrow.right"), background: MicaboColor.negativeSoft),
                    title: i18n.t("ios.deleteAccount"),
                    accessory: .none,
                    titleColor: MicaboColor.negative,
                    action: { showDeleteAccountConfirmation = true }
                )
            )
        }
        return MicaboSettingsSection(
            caption: i18n.t("ios.dataSection"),
            rows: rows,
            footnote: i18n.t("ios.dataFootnote")
        )
    }

    /// Outils de relecture. Plus d'interrupteur Pro : un interrupteur qui ment
    /// sur l'abonnement, même en `DEBUG`, se prend pour le vrai droit.
    private var testSection: some View {
        MicaboSettingsSection(
            caption: i18n.t("ios.debug.test"),
            rows: testRows,
            footnote: testFootnote
        )
    }

    private var testRows: [MicaboRow] {
        var rows: [MicaboRow] = []

        #if DEBUG
        // L'offre cadeau ne se présente qu'une fois par appareil : sans ce bouton, la
        // revoir demanderait de désinstaller l'app.
        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("gift.fill"), background: MicaboColor.infoSoft),
                title: i18n.t("ios.debug.replayGift"),
                subtitle: i18n.t("ios.debug.replayGiftHelp"),
                accessory: .chevron,
                action: { DiscountOffer.forget() }
            )
        )

        // Le mur d'abonnement se règle en le regardant : la moitié floutée d'une fiche, le
        // cadenas sur l'entraînement libre, le cadeau du premier cours. Sans cet
        // interrupteur, les voir demandait deux comptes et un webhook coopératif.
        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("crown.fill"), background: MicaboColor.cautionSoft),
                title: i18n.t("ios.debug.forcePro"),
                subtitle: i18n.t(pro?.debugProOverride == nil ? "ios.debug.forceProOff" : "ios.debug.forceProOn"),
                accessory: .toggle(Binding(
                    get: { pro?.isPro ?? false },
                    set: { value in pro?.debugProOverride = value }
                ))
            )
        )

        // Rendre la main au compte. C'est ce qui manque à un interrupteur à deux positions :
        // une fois touché, il n'y a plus moyen de redemander la vérité de l'abonnement, et
        // on finit par tester un mur qu'on a soi-même posé.
        if pro?.debugProOverride != nil {
            rows.append(
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("arrow.uturn.backward"), background: MicaboColor.surfaceMuted),
                    title: i18n.t("ios.debug.forceProClear"),
                    accessory: .chevron,
                    action: {
                        pro?.debugProOverride = nil
                        Task { await pro?.refresh() }
                    }
                )
            )
        }

        // Le cours d'essai arrive au premier lancement. Ce bouton le remet : après l'avoir
        // supprimé, ou pour en avoir deux et comparer deux fiches du même document écrites
        // avec deux réglages de longueur.
        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("leaf.fill"), background: MicaboColor.tilePastels[0]),
                title: i18n.t("ios.debug.sampleCourse"),
                subtitle: i18n.t("ios.debug.sampleCourseHelp"),
                accessory: .chevron,
                action: {
                    Task { @MainActor in
                        try? await DebugSampleCourse.importNow(in: modelContext)
                        Haptics.success()
                    }
                }
            )
        )
        #endif

        // **Les notifications, sans attendre le soir** : en développement et sur TestFlight.
        if BuildChannel.isInternal {
            rows.append(contentsOf: notificationTestRows)
        }

        // **Les paywalls, à vue**, même abonné ou déjà en essai : sans cette rangée, un compte
        // qui a commencé son essai ne les revoyait plus jamais.
        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("crown.fill"), background: MicaboColor.cautionSoft),
                title: i18n.t("ios.debug.showPaywall"),
                subtitle: i18n.t("ios.debug.showPaywallHelp"),
                accessory: .chevron,
                action: { paywall = .upgrade }
            )
        )

        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("repeat"), background: MicaboColor.tilePastels[2]),
                title: i18n.t("ios.debug.replayOnboarding"),
                accessory: .chevron,
                action: replayOnboarding
            )
        )

        return rows
    }

    private var notificationTestRows: [MicaboRow] {
        [
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("bell.badge.fill"), background: MicaboColor.infoSoft),
                title: i18n.t("ios.debug.notifImport"),
                subtitle: i18n.t("ios.debug.notifHelp"),
                accessory: .chevron,
                action: { sendTestNotification(.importCourse) }
            ),
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("bell.badge.fill"), background: MicaboColor.tilePastels[1]),
                title: i18n.t("ios.debug.notifPractice"),
                subtitle: i18n.t("ios.debug.notifHelp"),
                accessory: .chevron,
                action: { sendTestNotification(.practice) }
            ),
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("calendar.badge.clock"), background: MicaboColor.tilePastels[3]),
                title: i18n.t("ios.debug.notifScheduled"),
                subtitle: i18n.t("ios.debug.notifScheduledHelp"),
                accessory: .chevron,
                action: showScheduledReminders
            ),
            MicaboRow(
                tile: MicaboTile(glyph: .symbol("bell.and.waves.left.and.right.fill"), background: MicaboColor.cautionSoft),
                title: i18n.t("ios.debug.notifPermission"),
                subtitle: i18n.t("ios.debug.notifPermissionHelp"),
                accessory: .chevron,
                action: replayNotificationPermission
            )
        ]
    }

    /// **La demande d'autorisation, rejouée.** iOS n'ouvre sa fenêtre qu'une fois par
    /// installation : jamais posée, elle s'ouvre ; déjà tranchée, on dit la réponse et
    /// comment la changer, plutôt qu'un bouton qui ne fait rien.
    private func replayNotificationPermission() {
        Task { @MainActor in
            switch await NotificationPermission.request() {
            case .granted:
                notificationReportOffersSettings = false
                notificationReport = i18n.t("ios.debug.notifGranted")
                await DailyReminder.reschedule(context: modelContext, trialEndsAt: pro?.trialEndsAt)
            case .denied:
                notificationReportOffersSettings = true
                notificationReport = i18n.t("ios.debug.notifRefusedNow")
            case .alreadyAnswered(let isAuthorized):
                notificationReportOffersSettings = true
                notificationReport = i18n.t("ios.debug.notifPermissionAnswered", [
                    "answer": i18n.t(isAuthorized ? "ios.debug.notifAllowed" : "ios.debug.notifRefused")
                ])
            }
        }
    }

    private func sendTestNotification(_ kind: DailyReminder.TestKind) {
        Task { @MainActor in
            if await DailyReminder.sendTest(kind, context: modelContext) {
                Haptics.success()
            } else {
                notificationReportOffersSettings = true
                notificationReport = i18n.t("ios.debug.notifDenied")
            }
        }
    }

    /// Repose les rappels comme au passage en arrière-plan, puis dit ce qui est prévu.
    private func showScheduledReminders() {
        Task { @MainActor in
            await DailyReminder.reschedule(context: modelContext, trialEndsAt: pro?.trialEndsAt)
            let pending = await DailyReminder.pending()
            notificationReportOffersSettings = false
            guard let next = pending.first else {
                notificationReport = i18n.t("ios.debug.notifNone")
                return
            }
            let date = next.date.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened).locale(i18n.locale.foundation)
            )
            notificationReport = i18n.t("ios.debug.notifNext", [
                "count": "\(pending.count)",
                "date": date,
                "title": next.title
            ])
        }
    }

    private var testFootnote: String {
        #if DEBUG
        return i18n.t("ios.debug.footnoteDebug")
        #else
        return i18n.t("ios.debug.footnote")
        #endif
    }

    private var feedbackSection: some View {
        MicaboSettingsSection(
            caption: i18n.t("ios.feedbackSection"),
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("envelope.fill"), background: MicaboColor.infoSoft),
                    title: i18n.t("app.feedback.title"),
                    subtitle: i18n.t("ios.feedbackIdea"),
                    accessory: .chevron,
                    action: { showFeedback = true }
                )
            ],
            footnote: i18n.t("ios.feedbackArrives", ["team": MicaboMail.team])
        )
    }

    private var aboutSection: some View {
        MicaboSettingsSection(
            caption: i18n.t("ios.about"),
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("shippingbox.fill"), background: MicaboColor.tilePastels[4]),
                    title: i18n.t("ios.version"),
                    subtitle: buildCommit,
                    accessory: .value(appVersion)
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("chart.line.uptrend.xyaxis"), background: MicaboColor.tilePastels[0]),
                    title: i18n.t("ios.spacedRep"),
                    accessory: .value("SM-2")
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("lock.fill"), background: MicaboColor.tilePastels[3]),
                    title: i18n.t("common.privacy"),
                    accessory: .chevron,
                    action: { openLegal(PaywallLinks.privacy) }
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .symbol("doc.text.fill"), background: MicaboColor.tilePastels[5]),
                    title: i18n.t("common.terms"),
                    accessory: .chevron,
                    action: { openLegal(PaywallLinks.terms) }
                )
            ]
        )
    }

    // MARK: - Rangée éditable

    private func fieldRow(
        emoji: String,
        background: Color,
        title: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        HStack(spacing: 13) {
            MicaboTile(glyph: .emoji(emoji), background: background)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MicaboFont.rowTitle)
                    .foregroundStyle(MicaboColor.ink)

                TextField(placeholder, text: text)
                    .font(MicaboFont.ui(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .tint(MicaboColor.accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, MicaboSpacing.md)
    }

    // MARK: - Actions

    /// **Le commit d'où vient ce binaire.**
    ///
    /// Le numéro de version ne bouge pas d'un lot à l'autre et le numéro de build est un
    /// compteur : ni l'un ni l'autre ne dit quel code tourne. Sept caractères le disent, et
    /// ils se comparent à `git log` sans discuter. Gravés par `ci_scripts/ci_post_clone.sh` ;
    /// `dev` sur une construction faite à la main.
    private var buildCommit: String {
        Bundle.main.infoDictionary?["MicaboCommit"] as? String ?? "dev"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func saveAndClose() {
        AppConfig.supabaseURL = supabaseURL
        AppConfig.supabaseAnonKey = anonKey
        AppConfig.aiModel = model
        dismiss()
    }

    private func restoreDefaults() {
        AppConfig.resetToDefaults()
        supabaseURL = AppConfig.supabaseURL
        anonKey = AppConfig.supabaseAnonKey
        model = AppConfig.aiModel
        Haptics.success()
    }

    /// La feuille se referme d'abord : la bascule vers l'onboarding remplace toute
    /// la hiérarchie de vues, autant ne pas le faire pendant l'animation de fermeture.
    private func replayOnboarding() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            OnboardingPreferences.reset()
        }
    }

    private func openLegal(_ address: String) {
        guard let url = URL(string: address) else { return }
        UIApplication.shared.open(url)
    }

    private func eraseEverything() {
        try? modelContext.delete(model: ReviewLog.self)
        try? modelContext.delete(model: Flashcard.self)
        try? modelContext.delete(model: Course.self)
        try? modelContext.save()
        // La suppression en masse ne passe pas par `CourseRepository` : sans ce signal, les
        // écrans qui ne tiennent plus la table des cours resteraient sur leurs anciens
        // totaux derrière la feuille qui se referme.
        CourseLedger.noteChange()
        dismiss()
    }
}

#Preview {
    SettingsView()
}
