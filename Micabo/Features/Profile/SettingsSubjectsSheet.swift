import SwiftUI

/// Les matières, après l'inscription : les mêmes pastilles que le parcours d'accueil.
struct SettingsSubjectsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(CloudSync.self) private var sync

    @State private var selected: Set<String>

    init() {
        _selected = State(initialValue: Set(OnboardingPreferences.subjects))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(SubjectCatalog.families) { family in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(family.name.uppercased())
                                .font(MicaboFont.hanken(10, weight: .semibold))
                                .tracking(1.4)
                                .foregroundStyle(MicaboColor.inkTertiary)

                            MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                                ForEach(family.subjects, id: \.self) { subject in
                                    chip(subject)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .navigationTitle("Matières")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK", action: save)
                        .font(MicaboFont.hanken(15, weight: .semibold))
                }
            }
        }
    }

    private func chip(_ subject: String) -> some View {
        let isSelected = selected.contains(subject)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if isSelected {
                    selected.remove(subject)
                } else {
                    selected.insert(subject)
                }
            }
        } label: {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                } else {
                    Text(SubjectCatalog.emoji(for: subject))
                        .font(.system(size: 13))
                }
                Text(subject)
                    .font(MicaboFont.hanken(13, weight: .medium))
            }
            .foregroundStyle(isSelected ? MicaboColor.onInk : Color(hex: 0x4A463F))
            .padding(.vertical, 9)
            .padding(.horizontal, 13)
            .background(isSelected ? MicaboColor.ink : MicaboColor.surface, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
    }

    private func save() {
        OnboardingPreferences.subjects = selected.sorted()
        Task { await sync.sync(context: modelContext) }
        dismiss()
    }
}
