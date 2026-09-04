import SwiftUI

/// L'école, après l'inscription : la même recherche que le parcours d'accueil.
struct SettingsSchoolSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSync.self) private var sync

    @State private var query: String
    @State private var chosenId: String?
    @State private var suggestions: [Institution] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    init() {
        _query = State(initialValue: OnboardingPreferences.institutionName ?? "")
        _chosenId = State(initialValue: OnboardingPreferences.institutionId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(MicaboColor.inkTertiary)

                        TextField("Lycée, université, école…", text: $query)
                            .font(MicaboFont.hanken(16, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .onChange(of: query) { _, value in
                                if chosenId != nil { chosenId = nil }
                                scheduleSearch(for: value)
                            }

                        if !query.isEmpty {
                            Button {
                                query = ""
                                chosenId = nil
                                suggestions = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(MicaboColor.inkTertiary)
                            }
                            .buttonStyle(MicaboPressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))

                    if isSearching {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MicaboColor.progress)
                            .padding(.leading, 4)
                    }

                    ForEach(suggestions) { institution in
                        Button {
                            chosenId = institution.id
                            query = institution.name
                            suggestions = []
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(institution.name)
                                    .font(MicaboFont.hanken(14, weight: .semibold))
                                    .foregroundStyle(MicaboColor.ink)
                                Text(institution.subtitle)
                                    .font(MicaboFont.hanken(11, weight: .medium))
                                    .foregroundStyle(MicaboColor.inkTertiary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MicaboRowButtonStyle(feedback: .selection))
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .micaboScreenBackground()
            .navigationTitle("École")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: save)
                        .font(MicaboFont.hanken(15, weight: .semibold))
                }
            }
        }
    }

    private func scheduleSearch(for value: String) {
        searchTask?.cancel()
        let needle = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            let country = OnboardingPreferences.schoolingCountry.institutionCountryIso
                ?? OnboardingPreferences.customCountry?.code
            let results = await InstitutionSearchService.shared.suggestions(matching: needle, country: country)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                suggestions = results
                isSearching = false
            }
        }
    }

    private func save() {
        let name = query.trimmingCharacters(in: .whitespacesAndNewlines)
        OnboardingPreferences.institutionName = name.isEmpty ? nil : name
        OnboardingPreferences.institutionId = chosenId?.nilIfBlank
        Task { await sync.sync(context: modelContext) }
        dismiss()
    }
}
