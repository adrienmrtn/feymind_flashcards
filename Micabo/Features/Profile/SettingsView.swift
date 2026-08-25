import SwiftData
import SwiftUI

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

    @State private var studyLevel = OnboardingPreferences.studyLevel
    @State private var country = OnboardingPreferences.schoolingCountry
    @AppStorage(SheetPreferences.lengthKey) private var sheetLength = SheetLength.default
    @State private var showResetConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showAuth = false

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
                studiesSection
                reviewSection
                intelligenceSection
                connectionSection
                dataSection
                testSection
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
        .sheet(isPresented: $showAuth) {
            AuthView { showAuth = false }
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

            MicaboSectionFootnote(text: auth.isSignedIn
                ? "Tes cours, tes cartes et ton planning sont copiés sur ton compte. Les images et les enregistrements audio restent sur cet appareil."
                : "Sans compte, tout reste sur cet appareil : effacer l'app efface tes cours."
            )
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
                Menu {
                    Picker("Stade d'étude", selection: $studyLevel) {
                        ForEach(StudyLevel.allCases) { level in
                            Text(level.title).tag(Optional(level))
                        }
                        Text("Non précisé").tag(Optional<StudyLevel>.none)
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("🎓"), background: MicaboColor.tilePastels[0]),
                        title: "Stade d'étude",
                        subtitle: studyLevel?.detail ?? "Rédaction équilibrée, sans niveau supposé.",
                        accessory: .value(studyLevel?.title ?? "Non précisé")
                    )
                }

                MicaboHairline(inset: 71)

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
                        subtitle: country.systemHint,
                        accessory: .value(country.name)
                    )
                }

                MicaboHairline(inset: 71)

                Menu {
                    Picker("Longueur des fiches", selection: $sheetLength) {
                        ForEach(SheetLength.allCases) { length in
                            Text("\(length.title) · \(length.readingHint)").tag(length)
                        }
                    }
                } label: {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("📄"), background: MicaboColor.tilePastels[3]),
                        title: "Longueur des fiches",
                        subtitle: sheetLength.detail,
                        accessory: .value(sheetLength.title)
                    )
                }
            }
            .micaboGroup()

            MicaboSectionFootnote(text: "Micabo écrit les fiches pour ce niveau et ce système scolaire : le vocabulaire, la profondeur des explications et les examens auxquels la fiche renvoie en dépendent. La longueur se choisit aussi au moment d'un import.")
        }
        .onChange(of: studyLevel) { _, newValue in
            OnboardingPreferences.studyLevel = newValue
            Haptics.selection()
        }
        .onChange(of: country) { _, newValue in
            OnboardingPreferences.schoolingCountry = newValue
            Haptics.selection()
        }
        .onChange(of: sheetLength) { _, _ in
            Haptics.selection()
        }
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

            MicaboSectionFootnote(text: "Une carte neuve revient huit fois avant d'être acquise : le plafond découle du temps que tu t'accordes.")
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

            MicaboSectionFootnote(text: "Le modèle écrit les fiches et les cartes à partir du texte lu sur l'appareil. Le choix se garde entre deux lancements.")
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

            MicaboSectionFootnote(text: "Les Edge Functions generate-course, generate-flashcards et explain-selection écrivent les fiches, les cartes et les explications. La clé fal.ai reste côté serveur, dans le secret FAL_KEY.")
        }
    }

    private var dataSection: some View {
        MicaboSettingsSection(
            caption: "Données",
            rows: [
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
            ],
            footnote: "Effacer tes cours les efface aussi de ton compte à la prochaine synchronisation."
        )
    }

    private var testSection: some View {
        MicaboSettingsSection(
            caption: "Test",
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("🔁"), background: MicaboColor.tilePastels[2]),
                    title: "Refaire l'onboarding",
                    accessory: .chevron,
                    action: replayOnboarding
                )
            ],
            footnote: "Relance le parcours d'accueil et efface les réponses données à l'inscription. Tes cours ne sont pas touchés."
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
        Haptics.selection()
    }

    /// La feuille se referme d'abord : la bascule vers l'onboarding remplace toute
    /// la hiérarchie de vues, autant ne pas le faire pendant l'animation de fermeture.
    private func replayOnboarding() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            OnboardingPreferences.reset()
        }
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
