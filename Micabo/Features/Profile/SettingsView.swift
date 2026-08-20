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
    @State private var showResetConfirmation = false

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

            MicaboSectionFootnote(text: "Le modèle rédige les cartes à partir du texte lu sur l'appareil. Le choix se garde entre deux lancements.")
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

            MicaboSectionFootnote(text: "Les Edge Functions generate-course et generate-flashcards ne servent qu'à écrire les cartes. La clé fal.ai reste côté serveur, dans le secret FAL_KEY.")
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
            footnote: "Tes cours et tes cartes ne quittent jamais cet appareil."
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
