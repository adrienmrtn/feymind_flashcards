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
        .confirmationDialog(L10n.t("ios.deleteCardQ", locale: .resolved()), isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button(L10n.t("app.common.delete", locale: .resolved()), role: .destructive) {
                _ = try? CourseRepository.delete(card, in: modelContext)
                dismiss()
            }
            Button(L10n.t("app.common.cancel", locale: .resolved()), role: .cancel) {}
        }
    }

    private var header: some View {
        MicaboScreenHeader(
            title: L10n.t("ios.editCard", locale: .resolved()),
            eyebrow: card.course?.title,
            back: MicaboHeaderBack.close(save)
        ) {
            Button(L10n.t("ios.done", locale: .resolved()), action: save)
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
            MicaboSectionCaption(text: L10n.t("ios.choices", locale: .resolved()))

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
            MicaboSectionCaption(text: L10n.t("ios.pronunciation", locale: .resolved()))

            VStack(spacing: 0) {
                if card.hasAudio {
                    HStack(spacing: MicaboSpacing.sm) {
                        CardAudioButton(card: card, title: L10n.t("ios.listen", locale: .resolved()))

                        Spacer(minLength: 0)

                        Button(L10n.t("ios.remove", locale: .resolved())) {
                            card.audioData = nil
                            _ = try? modelContext.save()
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
                        title: L10n.t("ios.addSound", locale: .resolved()),
                        subtitle: L10n.t("ios.audioFileHelp", locale: .resolved()),
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
            MicaboSectionCaption(text: L10n.t("app.cardKind.diagram", locale: .resolved()))

            OcclusionFigure(card: card, isRevealed: true, maxHeight: 200)
                .padding(MicaboSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }

    private var schedulingSummary: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            MicaboSectionCaption(text: L10n.t("ios.cardProgress", locale: .resolved()))

            HStack(spacing: MicaboSpacing.sm) {
                summaryItem(card.state.label, L10n.t("ios.cardState", locale: .resolved()))
                summaryItem(card.intervalDays >= 1 ? "\(Int(card.intervalDays)) j" : "-", L10n.t("ios.cardInterval", locale: .resolved()))
                summaryItem(String(format: "%.2f", card.easeFactor), L10n.t("ios.cardEase", locale: .resolved()))
                summaryItem("\(card.lapses)", L10n.t("ios.cardLapses", locale: .resolved()))
            }

            HStack(spacing: MicaboSpacing.md) {
                Button(L10n.t("ios.resetThisCard", locale: .resolved())) {
                    card.resetScheduling()
                    _ = try? modelContext.save()
                }
                .buttonStyle(MicaboQuietButtonStyle())

                Button(L10n.t("ios.deleteCard", locale: .resolved())) {
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
        _ = try? modelContext.save()
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
        _ = try? modelContext.save()
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
            title: L10n.t("ios.newCard", locale: .resolved()),
            eyebrow: course.title,
            back: MicaboHeaderBack.close { dismiss() }
        ) {
            Button(L10n.t("app.common.add", locale: .resolved()), action: save)
                .font(MicaboFont.hanken(15, weight: .semibold))
                .foregroundStyle(canSave ? MicaboColor.accent : MicaboColor.inkTertiary)
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                .disabled(!canSave)
        }
    }

    private func save() {
        guard canSave else { return }
        let generated = GeneratedFlashcard(front: front, back: back, hint: hint.nilIfBlank)
        _ = try? CourseRepository.addFlashcards([generated], to: course, in: modelContext)
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

                field(title: L10n.t("ios.front", locale: .resolved()), text: $front, minHeight: 96)
                field(title: L10n.t("ios.back", locale: .resolved()), text: $back, minHeight: 140)
                field(
                    title: L10n.t("app.session.hint", locale: .resolved()),
                    subtitle: L10n.t("ios.optional", locale: .resolved()),
                    text: $hint,
                    minHeight: 60
                )
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

    /// Le sous-titre est devenu facultatif, et il ne reste que là où il apprend quelque
    /// chose : « Indice · Facultatif ». Un recto **est** la question et un verso **est** la
    /// réponse, donc « La question posée » sous « Recto » ne faisait que réécrire l'intitulé.
    private func field(
        title: String,
        subtitle: String? = nil,
        text: Binding<String>,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
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
