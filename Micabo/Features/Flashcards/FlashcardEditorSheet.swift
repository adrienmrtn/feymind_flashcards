import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Modification d'une carte existante. Même en-tête que partout : croix, sur-titre,
/// grand titre — pas de barre de navigation système.
struct FlashcardEditorSheet: View {
    @Bindable var card: Flashcard

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var showAudioImporter = false

    var body: some View {
        FlashcardForm(
            front: $card.front,
            back: $card.back,
            hint: Binding(
                get: { card.hint ?? "" },
                set: { card.hint = $0.nilIfBlank }
            ),
            header: { AnyView(header) },
            footer: { AnyView(attachments) }
        )
        .fileImporter(
            isPresented: $showAudioImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            attachAudio(from: result)
        }
        .confirmationDialog("Supprimer cette carte ?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Supprimer", role: .destructive) {
                try? CourseRepository.delete(card, in: modelContext)
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    private var header: some View {
        MicaboScreenHeader(
            title: "Modifier la carte",
            eyebrow: card.course?.title,
            back: MicaboHeaderBack.close(save)
        ) {
            Button("Terminé", action: save)
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
        }
    }

    private var attachments: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
            audioSection

            if card.isMultipleChoice {
                choicesSection
            }

            if card.isOcclusion {
                occlusionSection
            }

            schedulingSummary
        }
    }

    /// Les propositions d'un QCM se relisent ici. Elles ne se réécrivent pas encore :
    /// une liste de propositions avec sa bonne réponse demande son propre éditeur, et
    /// en attendant le verso reste modifiable comme sur n'importe quelle carte.
    private var choicesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Propositions")

            VStack(spacing: 0) {
                ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
                    let isCorrect = index == card.correctChoiceIndex

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: isCorrect ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(isCorrect ? MicaboColor.positive : MicaboColor.strokeStrong)

                        Text(choice)
                            .font(MicaboFont.body)
                            .foregroundStyle(isCorrect ? MicaboColor.ink : MicaboColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, MicaboSpacing.md)

                    if index < card.choices.count - 1 {
                        MicaboHairline(inset: MicaboSpacing.md)
                    }
                }
            }
            .micaboGroup()
        }
    }

    /// Le son est facultatif, et c'est ce qui manquait pour les langues : une carte de
    /// vocabulaire muette n'apprend pas à prononcer.
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Prononciation")

            VStack(spacing: 0) {
                if card.hasAudio {
                    HStack(spacing: MicaboSpacing.sm) {
                        CardAudioButton(card: card, title: "Écouter")

                        Spacer(minLength: 0)

                        Button("Retirer") {
                            card.audioData = nil
                            try? modelContext.save()
                        }
                        .font(MicaboFont.captionEmphasis)
                        .foregroundStyle(MicaboColor.negative)
                        .buttonStyle(MicaboPressableButtonStyle())
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, MicaboSpacing.md)
                } else {
                    MicaboRow(
                        tile: MicaboTile(glyph: .emoji("🔊"), background: MicaboColor.accentSoft),
                        title: "Ajouter un son",
                        subtitle: "Un fichier audio depuis tes fichiers",
                        accessory: .chevron,
                        action: { showAudioImporter = true }
                    )
                }
            }
            .micaboGroup()
        }
    }

    private var occlusionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Schéma")

            VStack(alignment: .leading, spacing: 10) {
                OcclusionFigure(card: card, isRevealed: true, maxHeight: 200)

                Text("La zone encadrée est celle que cette carte demande. Le verso ci-dessus en est la réponse.")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MicaboSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }

    private var schedulingSummary: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            MicaboSectionCaption(text: "Progression")

            HStack(spacing: MicaboSpacing.sm) {
                summaryItem(card.state.label, "État")
                summaryItem(card.intervalDays >= 1 ? "\(Int(card.intervalDays)) j" : "-", "Intervalle")
                summaryItem(String(format: "%.2f", card.easeFactor), "Facilité")
                summaryItem("\(card.lapses)", "Oublis")
            }

            HStack(spacing: MicaboSpacing.md) {
                Button("Réinitialiser cette carte") {
                    card.resetScheduling()
                    try? modelContext.save()
                }
                .buttonStyle(MicaboQuietButtonStyle())

                Button("Supprimer la carte") {
                    showDeleteConfirmation = true
                }
                .font(MicaboFont.captionEmphasis)
                .foregroundStyle(MicaboColor.negative)
                .buttonStyle(MicaboPressableButtonStyle())

                Spacer(minLength: 0)
            }
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private func summaryItem(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MicaboFont.cardTitle)
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
            Text(label)
                .font(MicaboFont.micro)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func save() {
        card.updatedAt = Date()
        try? modelContext.save()
        dismiss()
    }

    /// Le fichier est recopié dans la carte : il reste lisible même si l'original bouge.
    private func attachAudio(from result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { return }
        card.audioData = data
        card.updatedAt = Date()
        try? modelContext.save()
        Haptics.success()
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
        FlashcardForm(
            front: $front,
            back: $back,
            hint: $hint,
            header: { AnyView(header) },
            footer: { AnyView(EmptyView()) }
        )
    }

    private var header: some View {
        MicaboScreenHeader(
            title: "Nouvelle carte",
            eyebrow: course.title,
            back: MicaboHeaderBack.close { dismiss() }
        ) {
            Button("Ajouter", action: save)
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(canSave ? MicaboColor.accent : MicaboColor.inkTertiary)
                .disabled(!canSave)
        }
    }

    private func save() {
        guard canSave else { return }
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
    let header: () -> AnyView
    let footer: () -> AnyView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                header()
                    .padding(.bottom, MicaboSpacing.xxs)

                field(title: "Recto", subtitle: "La question posée", text: $front, minHeight: 96)
                field(title: "Verso", subtitle: "La réponse attendue", text: $back, minHeight: 140)
                field(title: "Indice", subtitle: "Facultatif", text: $hint, minHeight: 60)
                footer()
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .scrollDismissesKeyboard(.interactively)
    }

    private func field(title: String, subtitle: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                Text(subtitle)
                    .font(MicaboFont.micro)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            TextEditor(text: text)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .scrollContentBackground(.hidden)
                .padding(MicaboSpacing.sm)
                .frame(minHeight: minHeight, alignment: .topLeading)
                .micaboGroup(radius: MicaboRadius.lg)
        }
    }
}
