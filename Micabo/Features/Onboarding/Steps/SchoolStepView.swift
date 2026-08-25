import SwiftUI

/// Écran « Tu étudies où ? » : saisie libre + suggestions locales puis Supabase.
struct SchoolStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var query = ""
    @State private var suggestions: [Institution] = []
    @State private var isSearching = false
    @State private var selected: Institution?
    @State private var searchTask: Task<Void, Never>?
    /// Texte posé par l'app (choix d'un résultat, reprise d'une réponse) : il ne doit
    /// pas relancer de recherche, sinon la liste se rouvre juste après la sélection.
    @State private var programmaticQuery: String?
    @FocusState private var isFocused: Bool

    private var canContinue: Bool {
        !normalizedQuery.isEmpty
    }

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton établissement",
            title: "Tu étudies où ?",
            subtitle: "Commence à taper, on cherche pour toi.",
            titleSize: 28,
            skip: OnboardingSkip(action: skipAndAdvance)
        ) {
            VStack(alignment: .leading, spacing: 14) {
                searchField

                if !suggestions.isEmpty {
                    suggestionsList
                } else if isSearching {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MicaboColor.progress)
                        Text("Recherche…")
                            .font(MicaboFont.hanken(13, weight: .medium))
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .padding(.top, 4)
                } else if normalizedQuery.count >= 2, selected == nil {
                    Text("Aucun résultat pour l'instant — tu peux quand même continuer avec ce nom.")
                        .font(MicaboFont.hanken(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let selected {
                    selectedBadge(selected)
                }
            }
        } footer: {
            OnboardingContinueButton(
                title: continueTitle,
                isEnabled: canContinue
            ) {
                commitAndAdvance()
            }
        }
        .onAppear {
            isFocused = true
            if let existing = model.institutionName, query.isEmpty {
                programmaticQuery = existing
                query = existing
            }
        }
        .onChange(of: query) { _, newValue in
            guard programmaticQuery != newValue else {
                programmaticQuery = nil
                return
            }
            programmaticQuery = nil
            selected = nil
            scheduleSearch(for: newValue)
        }
    }

    private var continueTitle: String {
        if let selected {
            return "Continuer avec \(shortName(selected.name))"
        }
        if normalizedQuery.isEmpty {
            return "Indique ton établissement"
        }
        return "Continuer avec « \(shortName(normalizedQuery)) »"
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            TextField("Ex. École polytechnique, Louis-le-Grand…", text: $query)
                .font(MicaboFont.hanken(16, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.done)

            if !query.isEmpty {
                Button {
                    query = ""
                    suggestions = []
                    selected = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                .strokeBorder(isFocused ? MicaboColor.ink : MicaboColor.stroke, lineWidth: isFocused ? 1.6 : 1)
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, institution in
                Button {
                    select(institution)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: icon(for: institution.kind))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .frame(width: 28, height: 28)
                            .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(institution.name)
                                .font(MicaboFont.hanken(14, weight: .semibold))
                                .foregroundStyle(MicaboColor.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(institution.subtitle)
                                .font(MicaboFont.hanken(11, weight: .medium))
                                .foregroundStyle(MicaboColor.inkTertiary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MicaboRowButtonStyle(feedback: .selection))

                if index < suggestions.count - 1 {
                    Rectangle()
                        .fill(MicaboColor.stroke)
                        .frame(height: 1)
                        .padding(.leading, 52)
                }
            }
        }
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private func selectedBadge(_ institution: Institution) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MicaboColor.positive)
            Text(institution.name)
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MicaboColor.positiveSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
    }

    private func icon(for kind: InstitutionKind) -> String {
        switch kind {
        case .university: "building.columns"
        case .grandeEcole: "rosette"
        case .lycee: "book.closed"
        case .other: "mappin.and.ellipse"
        }
    }

    private func shortName(_ value: String) -> String {
        value.count > 28 ? String(value.prefix(27)) + "…" : value
    }

    private func select(_ institution: Institution) {
        searchTask?.cancel()
        isSearching = false
        selected = institution
        programmaticQuery = institution.name
        query = institution.name
        suggestions = []
        isFocused = false
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
            let results = await InstitutionSearchService.shared.suggestions(matching: needle)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) {
                    suggestions = results
                    isSearching = false
                }
            }
        }
    }

    /// Passer laisse le champ vide **et l'écrit** : on ne garde pas la moitié d'un nom tapé
    /// puis abandonné, sinon l'app se met à parler d'un établissement que personne n'a
    /// confirmé.
    private func skipAndAdvance() {
        searchTask?.cancel()
        isSearching = false
        isFocused = false

        let flow = model
        flow.institutionId = nil
        flow.institutionName = nil
        flow.advance()
    }

    private func commitAndAdvance() {
        let flow = model
        if let selected {
            flow.institutionId = selected.id
            flow.institutionName = selected.name
        } else {
            flow.institutionId = nil
            flow.institutionName = normalizedQuery
        }
        flow.advance()
    }
}
