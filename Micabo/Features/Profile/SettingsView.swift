import SwiftData
import SwiftUI
import UIKit

/// Réglages du backend IA et des données locales.
/// Mise en page en blocs blancs : un intitulé en capitales, des rangées à tuile
/// pastel, et une note grise quand une explication est nécessaire.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var supabaseURL = AppConfig.supabaseURL
    @State private var anonKey = AppConfig.supabaseAnonKey
    @State private var model = AppConfig.aiModel
    @State private var dailyMinutes = OnboardingPreferences.dailyMinutes
    @Environment(AuthController.self) private var auth
    @Environment(CloudSync.self) private var sync
    @Environment(SocialService.self) private var social
    @Environment(ProAccess.self) private var pro: ProAccess?

    @State private var username = ""

    @State private var stage = OnboardingPreferences.educationStage
    @State private var country = OnboardingPreferences.schoolingCountry
    /// Le format, et pas le nombre de blocs : un menu ne fait pas un curseur. L'écrire
    /// replace le curseur de l'import au milieu de la plage choisie.
    @State private var sheetLength = SheetPreferences.length
    @State private var showResetConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showAuth = false
    @State private var showSubjects = false
    @State private var showSchool = false
    @State private var showFeedback = false
    @State private var subjects = OnboardingPreferences.subjects
    @State private var schoolName = OnboardingPreferences.institutionName

    private let models = [
        "google/gemini-flash-1.5",
        "google/gemini-flash-1.5-8b",
        "google/gemini-2.0-flash-001",
        "google/gemini-2.5-flash-lite",
        "openai/gpt-4o-mini"
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                accountSection
                identitySection
                studiesSection
                reviewSection
                #if DEBUG
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
        .confirmationDialog(
            "Supprimer le compte ?",
            isPresented: $showDeleteAccountConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer le compte", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes cours, tes cartes et ton historique seront effacés. L'abonnement déjà encaissé se gère chez Apple ou Stripe.")
        }
        .confirmationDialog(
            "Effacer toutes les données ?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Tout effacer", role: .destructive, action: eraseEverything)
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes cours, tes cartes et ton historique de révision seront supprimés.")
        }
        .confirmationDialog(
            "Se déconnecter ?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Se déconnecter", role: .destructive) {
                Task {
                    // On remonte une dernière fois avant de partir : une révision faite dans
                    // la minute qui précède ne doit pas être le prix d'une déconnexion.
                    await sync.sync(context: modelContext)
                    await auth.signOut()
                    sync.forget()
                }
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Tes cours restent sur cet appareil et sur ton compte. Tu les retrouveras à la prochaine connexion.")
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .sheet(isPresented: $showAuth) {
            // Plus de « continuer sans compte » : `AuthView` n'a plus de sortie, et la
            // feuille se referme toute seule dès que la connexion aboutit.
            AuthView()
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
        MicaboScreenHeader(title: "Réglages", back: MicaboHeaderBack.back(saveAndClose)) {
            Button("Terminé", action: saveAndClose)
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .buttonStyle(MicaboPressableButtonStyle())
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// Le compte, et l'état de la synchro.
    ///
    /// C'est le seul endroit où l'on voit si les cours sont en sécurité ailleurs que sur ce
    /// téléphone, et il le dit franchement dans les deux cas. Un utilisateur resté en local
    /// n'est pas harcelé : une rangée, une phrase, et il décide.
    @ViewBuilder
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Compte")

            VStack(spacing: 0) {
                if let user = auth.user {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("👤"), background: MicaboColor.accentSoft),
                        title: user.label,
                        subtitle: user.email ?? "Connecté",
                        accessory: .none
                    )

                    MicaboHairline(inset: 71)

                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("☁️"), background: MicaboColor.tilePastels[3]),
                        title: "Sauvegarde",
                        subtitle: syncSubtitle,
                        accessory: .none,
                        action: { Task { await sync.sync(context: modelContext) } }
                    )

                    MicaboHairline(inset: 71)

                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("🚪"), background: MicaboColor.surfaceMuted),
                        title: "Se déconnecter",
                        accessory: .none,
                        titleColor: MicaboColor.negative,
                        action: { showSignOutConfirmation = true }
                    )
                } else {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("☁️"), background: MicaboColor.tilePastels[3]),
                        title: "Créer un compte ou se connecter",
                        subtitle: "Retrouver tes cours sur tes autres appareils",
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
        case .idle: "Toucher pour synchroniser"
        case .syncing: "Synchronisation…"
        case .done(let date): "À jour · " + Self.timeFormatter.string(from: date)
        case .failed(let message): message
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

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
                MicaboSectionCaption(text: "Nom d'utilisateur")

                HStack(spacing: 11) {
                    Text("@")
                        .font(MicaboFont.hanken(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)

                    TextField("nom d'utilisateur", text: $username)
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
                        Button("Enregistrer", action: commitUsername)
                            .font(MicaboFont.hanken(13, weight: .semibold))
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
                    ? "Trois à vingt caractères, en commençant par une lettre ou un chiffre."
                    : "Sera enregistré sous \(Username.display(preview))."
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
            MicaboSectionCaption(text: "Tes études")

            VStack(spacing: 0) {
                // Le pays passe avant le stade, comme dans le parcours d'accueil : c'est lui
                // qui décide des paliers proposés juste en dessous.
                Menu {
                    Picker("Pays", selection: $country) {
                        ForEach(SchoolingCountry.allCases) { value in
                            Text("\(value.flag) \(value.name)").tag(value)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji(country.flag), background: MicaboColor.tilePastels[2]),
                        title: "Pays",
                        subtitle: "Micabo écrit en \(country.language.label)",
                        accessory: .value(country.name)
                    )
                }

                MicaboHairline(inset: 71)

                Menu {
                    Picker("Stade d'étude", selection: $stage) {
                        ForEach(country.stages) { value in
                            Text("\(value.emoji) \(value.title)").tag(Optional(value))
                        }
                        Text("Non précisé").tag(Optional<EducationStage>.none)
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji(stage?.emoji ?? "🎓"), background: MicaboColor.tilePastels[0]),
                        title: "Stade d'étude",
                        subtitle: stage?.level.detail ?? "Rédaction équilibrée, sans niveau supposé.",
                        accessory: .value(stage?.title ?? "Non précisé")
                    )
                }

                MicaboHairline(inset: 71)

                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("📚"), background: MicaboColor.tilePastels[4]),
                    title: "Matières",
                    subtitle: subjectsSubtitle,
                    accessory: .chevron,
                    action: { showSubjects = true }
                )

                MicaboHairline(inset: 71)

                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("🏫"), background: MicaboColor.tilePastels[5]),
                    title: "École",
                    subtitle: schoolName?.nilIfBlank ?? "Non renseignée",
                    accessory: .chevron,
                    action: { showSchool = true }
                )

                MicaboHairline(inset: 71)

                Menu {
                    Picker("Longueur des fiches", selection: $sheetLength) {
                        ForEach(SheetLength.allCases) { length in
                            Text("\(length.title) · \(readingHint(for: length))").tag(length)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("📄"), background: MicaboColor.tilePastels[3]),
                        title: "Longueur des fiches",
                        subtitle: readingHint(for: sheetLength) + " de lecture",
                        accessory: .value(sheetLength.title)
                    )
                }
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
        }
        .onChange(of: sheetLength) { _, newValue in
            SheetPreferences.length = newValue
            Haptics.selection()
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
        if subjects.isEmpty { return "Aucune matière" }
        if subjects.count <= 3 { return subjects.joined(separator: ", ") }
        return "\(subjects.prefix(3).joined(separator: ", ")) +\(subjects.count - 3)"
    }

    private func readingHint(for length: SheetLength) -> String {
        SheetPreferences.readingHint(forBlocks: length.defaultBlocks)
    }

    /// Le rythme quotidien commande le plafond de cartes neuves : les deux rangées se
    /// lisent ensemble, et la seconde n'est qu'une conséquence de la première.
    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Révision")

            VStack(spacing: 0) {
                Menu {
                    Picker("Objectif quotidien", selection: $dailyMinutes) {
                        ForEach(DailyLoad.steps, id: \.self) { minutes in
                            Text(DailyLoad.label(forMinutes: minutes)).tag(minutes)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("⏱️"), background: MicaboColor.tilePastels[1]),
                        title: "Objectif quotidien",
                        accessory: .value(DailyLoad.label(forMinutes: dailyMinutes))
                    )
                }

                MicaboHairline(inset: 71)

                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("🆕"), background: MicaboColor.accentSoft),
                    title: "Nouvelles cartes / jour",
                    accessory: .value("\(DailyLoad.newCardsPerDay(dailyMinutes: dailyMinutes)) max")
                )
            }
            .micaboGroup()
        }
        .onChange(of: dailyMinutes) { _, newValue in
            OnboardingPreferences.dailyMinutes = newValue
            Haptics.selection()
        }
    }

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Intelligence")

            VStack(spacing: 0) {
                Menu {
                    Picker("Modèle", selection: $model) {
                        ForEach(models, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("🧠"), background: MicaboColor.accentSoft),
                        title: "Modèle",
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
            MicaboSectionCaption(text: "Connexion")

            VStack(spacing: 0) {
                fieldRow(
                    emoji: "☁️",
                    background: MicaboColor.tilePastels[3],
                    title: "URL Supabase",
                    placeholder: "https://votre-projet.supabase.co",
                    text: $supabaseURL
                )

                MicaboHairline(inset: 71)

                fieldRow(
                    emoji: "🔑",
                    background: MicaboColor.tilePastels[5],
                    title: "Clé publique",
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
                tile: MicaboTile(glyph: .emoji("♻️"), background: MicaboColor.tilePastels[1]),
                title: "Rétablir les valeurs par défaut",
                accessory: .none,
                action: restoreDefaults
            ),
            MicaboRow(
                tile: MicaboTile(glyph: .emoji("🗑️"), background: MicaboColor.negativeSoft),
                title: "Effacer tous mes cours",
                accessory: .none,
                titleColor: MicaboColor.negative,
                action: { showResetConfirmation = true }
            )
        ]
        if case .signedIn = auth.state {
            rows.append(
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("🚪"), background: MicaboColor.negativeSoft),
                    title: "Supprimer mon compte",
                    accessory: .none,
                    titleColor: MicaboColor.negative,
                    action: { showDeleteAccountConfirmation = true }
                )
            )
        }
        return MicaboSettingsSection(
            caption: "Données",
            rows: rows,
            footnote: "Effacer tes cours les efface aussi de ton compte à la prochaine synchronisation. Supprimer le compte les efface partout."
        )
    }

    /// **L'interrupteur Pro n'existe qu'en `DEBUG`.**
    ///
    /// C'est un outil de relecture : sans lui, les écrans de blocage ne se voient qu'une fois
    /// et il faudrait réinstaller l'app pour revoir la fiche coupée. Mais dans une version
    /// livrée, un interrupteur qui mentirait sur l'état réel d'un abonnement payé est pire
    /// que pas d'interrupteur du tout — c'est RevenueCat qui décide, et lui seul.
    private var testSection: some View {
        MicaboSettingsSection(
            caption: "Test",
            rows: testRows,
            footnote: testFootnote
        )
    }

    private var testRows: [MicaboRow] {
        var rows: [MicaboRow] = []

        #if DEBUG
        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .emoji("🔓"), background: MicaboColor.accentSoft),
                title: "Micabo Pro",
                subtitle: isPro ? "Tout est ouvert" : "Version gratuite : 1 cours, 70 % de la fiche, 5 cartes",
                // La rangée fait vibrer la liaison elle-même : pas de `buzzing()` ici,
                // sinon l'interrupteur répondrait deux fois au même appui.
                accessory: .toggle(
                    Binding(
                        get: { isPro },
                        set: { pro?.setPro($0) }
                    )
                )
            )
        )

        // L'offre cadeau ne se présente qu'une fois par appareil : sans ce bouton, la
        // revoir demanderait de désinstaller l'app.
        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .emoji("🎁"), background: MicaboColor.infoSoft),
                title: "Rejouer le cadeau",
                subtitle: "Ouvre la boîte sur la prochaine fiche",
                accessory: .chevron,
                action: { DiscountOffer.forget() }
            )
        )
        #endif

        rows.append(
            MicaboRow(
                tile: MicaboTile(glyph: .emoji("🔁"), background: MicaboColor.tilePastels[2]),
                title: "Refaire l'onboarding",
                accessory: .chevron,
                action: replayOnboarding
            )
        )

        return rows
    }

    private var testFootnote: String {
        #if DEBUG
        return "L'interrupteur Pro et le cadeau n'existent qu'en développement : ils permettent de revoir les écrans de blocage et l'offre. Refaire l'onboarding efface les réponses de l'inscription, pas tes cours."
        #else
        return "Refaire l'onboarding efface les réponses de l'inscription, pas tes cours."
        #endif
    }

    private var isPro: Bool { pro?.isPro ?? false }

    private var feedbackSection: some View {
        MicaboSettingsSection(
            caption: "Retour",
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("✉️"), background: MicaboColor.infoSoft),
                    title: "Faire un retour",
                    subtitle: "Un bug, une idée",
                    accessory: .chevron,
                    action: { showFeedback = true }
                )
            ],
            footnote: "Ça arrive chez \(MicaboMail.team)."
        )
    }

    private var aboutSection: some View {
        MicaboSettingsSection(
            caption: "À propos",
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("📦"), background: MicaboColor.tilePastels[4]),
                    title: "Version",
                    accessory: .value(appVersion)
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("📈"), background: MicaboColor.tilePastels[0]),
                    title: "Répétition espacée",
                    accessory: .value("SM-2")
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("🔒"), background: MicaboColor.tilePastels[3]),
                    title: "Confidentialité",
                    accessory: .chevron,
                    action: { openLegal(PaywallLinks.privacy) }
                ),
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("📜"), background: MicaboColor.tilePastels[5]),
                    title: "Conditions",
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
                    .font(MicaboFont.hanken(13, weight: .regular))
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
        dismiss()
    }
}

#Preview {
    SettingsView()
}
