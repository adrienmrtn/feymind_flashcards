import SwiftData
import SwiftUI

/// Réglages du backend IA et des données locales.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var supabaseURL = AppConfig.supabaseURL
    @State private var anonKey = AppConfig.supabaseAnonKey
    @State private var model = AppConfig.aiModel
    @State private var showResetConfirmation = false

    private let models = [
        "google/gemini-flash-1.5",
        "google/gemini-flash-1.5-8b",
        "google/gemini-2.0-flash-001",
        "google/gemini-2.5-flash-lite",
        "openai/gpt-4o-mini"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("URL Supabase") {
                        TextField("https://votre-projet.supabase.co", text: $supabaseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    LabeledContent("Clé publique") {
                        TextField("sb_publishable_...", text: $anonKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Backend")
                } footer: {
                    Text("Les appels passent par les Edge Functions generate-course, generate-flashcards et explain-passage. La clé fal.ai reste côté serveur, dans le secret FAL_KEY.")
                }

                Section("Modèle") {
                    Picker("Modèle", selection: $model) {
                        ForEach(models, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Button("Rétablir les valeurs par défaut") {
                        AppConfig.resetToDefaults()
                        supabaseURL = AppConfig.supabaseURL
                        anonKey = AppConfig.supabaseAnonKey
                        model = AppConfig.aiModel
                    }
                }

                Section {
                    Button("Effacer tous les cours", role: .destructive) {
                        showResetConfirmation = true
                    }
                } footer: {
                    Text("Vos cours et flashcards sont stockés uniquement sur cet appareil.")
                }

                Section("À propos") {
                    LabeledContent("Version", value: appVersion)
                    LabeledContent("Répétition espacée", value: "SM-2, réglages Anki")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminé") {
                        AppConfig.supabaseURL = supabaseURL
                        AppConfig.supabaseAnonKey = anonKey
                        AppConfig.aiModel = model
                        dismiss()
                    }
                    .font(FeyFont.cardTitle)
                }
            }
            .confirmationDialog(
                "Effacer toutes les données ?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive, action: eraseEverything)
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cours, flashcards et historique de révision seront supprimés.")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func eraseEverything() {
        try? modelContext.delete(model: ReviewLog.self)
        try? modelContext.delete(model: Flashcard.self)
        try? modelContext.delete(model: CourseBlockEntity.self)
        try? modelContext.delete(model: Course.self)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SettingsView()
}
