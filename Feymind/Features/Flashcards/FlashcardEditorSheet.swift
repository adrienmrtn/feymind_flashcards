import SwiftData
import SwiftUI

/// Modification d'une carte existante.
struct FlashcardEditorSheet: View {
    @Bindable var card: Flashcard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            FlashcardForm(
                front: $card.front,
                back: $card.back,
                hint: Binding(
                    get: { card.hint ?? "" },
                    set: { card.hint = $0.nilIfBlank }
                ),
                footer: { AnyView(schedulingSummary) }
            )
            .navigationTitle("Modifier la carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Supprimer", role: .destructive) { showDeleteConfirmation = true }
                        .foregroundStyle(FeyColor.negative)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Terminé") {
                        card.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                    .font(FeyFont.cardTitle)
                    .foregroundStyle(FeyColor.ink)
                }
            }
            .confirmationDialog("Supprimer cette carte ?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Supprimer", role: .destructive) {
                    try? CourseRepository.delete(card, in: modelContext)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            }
        }
    }

    private var schedulingSummary: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            Text("Progression")
                .font(FeyFont.captionEmphasis)
                .foregroundStyle(FeyColor.inkTertiary)

            HStack(spacing: FeySpacing.sm) {
                summaryItem(card.state.label, "État")
                summaryItem(card.intervalDays >= 1 ? "\(Int(card.intervalDays)) j" : "-", "Intervalle")
                summaryItem(String(format: "%.2f", card.easeFactor), "Facilité")
                summaryItem("\(card.lapses)", "Oublis")
            }

            Button("Réinitialiser cette carte") {
                card.resetScheduling()
                try? modelContext.save()
            }
            .buttonStyle(FeyQuietButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .feyCard(padding: FeySpacing.md, radius: FeyRadius.lg, elevated: false)
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(FeyFont.cardTitle)
                .foregroundStyle(FeyColor.ink)
                .lineLimit(1)
            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Création d'une carte à la main.
struct FlashcardCreatorSheet: View {
    let course: Course

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var front = ""
    @State private var back = ""
    @State private var hint = ""

    private var canSave: Bool {
        front.nilIfBlank != nil && back.nilIfBlank != nil
    }

    var body: some View {
        NavigationStack {
            FlashcardForm(
                front: $front,
                back: $back,
                hint: $hint,
                footer: { AnyView(EmptyView()) }
            )
            .navigationTitle("Nouvelle carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundStyle(FeyColor.inkSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") { save() }
                        .font(FeyFont.cardTitle)
                        .foregroundStyle(canSave ? FeyColor.ink : FeyColor.inkTertiary)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let generated = GeneratedFlashcard(front: front, back: back, hint: hint.nilIfBlank)
        try? CourseRepository.addFlashcards([generated], to: course, in: modelContext)
        dismiss()
    }
}

/// Formulaire partagé entre création et modification.
private struct FlashcardForm: View {
    @Binding var front: String
    @Binding var back: String
    @Binding var hint: String
    let footer: () -> AnyView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FeySpacing.md) {
                field(title: "Recto", subtitle: "La question posée", text: $front, minHeight: 96)
                field(title: "Verso", subtitle: "La réponse attendue", text: $back, minHeight: 140)
                field(title: "Indice", subtitle: "Facultatif", text: $hint, minHeight: 60)
                footer()
            }
            .padding(.horizontal, FeySpacing.screen)
            .padding(.vertical, FeySpacing.md)
        }
        .feyScreenBackground()
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(title: String, subtitle: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(FeyFont.captionEmphasis)
                    .foregroundStyle(FeyColor.ink)
                Text(subtitle)
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
            }

            TextEditor(text: text)
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.ink)
                .scrollContentBackground(.hidden)
                .padding(FeySpacing.sm)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
        }
    }
}
