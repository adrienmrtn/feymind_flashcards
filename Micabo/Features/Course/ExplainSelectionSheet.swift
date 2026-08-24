import SwiftData
import SwiftUI

/// Ce que Micabo répond quand on sélectionne un passage de la fiche et qu'on demande
/// « Expliquer ».
///
/// La feuille s'ouvre **avant** la réponse, avec le passage déjà cité et surligné : c'est
/// ce qui rend l'attente supportable, parce qu'on voit tout de suite que la question a été
/// prise. Elle se ferme sur la possibilité d'en faire une carte, ce qui est la suite
/// naturelle : ce qu'on vient de comprendre est exactement ce qu'on oubliera.
struct ExplainSelectionSheet: View {
    let course: Course
    let selection: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var explanation: SelectionExplanation?
    @State private var failure: String?
    @State private var isLoading = true
    @State private var savedCard = false

    private var quoted: String {
        SheetSelection.trimmed(selection)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                quote

                if isLoading {
                    LoadingLines()
                } else if let explanation {
                    answer(explanation)
                } else if let failure {
                    failureState(failure)
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.md)
            .padding(.bottom, MicaboSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .task { await load() }
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: MicaboSpacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                MicaboEyebrow(text: course.title)
                Text("Explication")
                    .font(MicaboFont.hanken(26, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.tight)
            }

            Spacer(minLength: 0)

            MicaboCircleButton(systemImage: "xmark", size: 36, accessibilityTitle: "Fermer") {
                dismiss()
            }
        }
    }

    /// Le passage cité, surligné comme il l'était sous le doigt : on doit reconnaître ce
    /// qu'on a sélectionné sans avoir à s'en souvenir.
    private var quote: some View {
        SheetInlineText(
            markup: "==\(quoted)==",
            style: SheetTextStyle(size: 16, weight: .medium, color: MicaboColor.ink, lineSpacing: 5)
        )
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
    }

    // MARK: - Réponse

    private func answer(_ explanation: SelectionExplanation) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            SheetInlineText(
                markup: explanation.headline,
                style: SheetTextStyle(size: 18, weight: .semibold, color: MicaboColor.ink, lineSpacing: 5)
            )

            if let body = explanation.body.nilIfBlank {
                SheetProse(markup: body, style: .prose)
            }

            if let example = explanation.example?.nilIfBlank {
                block(tone: .exemple, text: example)
            }

            if let watchOut = explanation.watchOut?.nilIfBlank {
                block(tone: .attention, text: watchOut)
            }

            if let card = explanation.card {
                cardOffer(card)
            }
        }
    }

    private func block(tone: SheetCalloutTone, text: String) -> some View {
        SheetBlockView(block: .callout(tone: tone, text: text), tint: Color(hexString: course.accentHex))
    }

    /// « En faire une carte » : le seul chemin de la compréhension vers la révision, et il
    /// tient en un appui. Le bouton ne se répète pas une fois la carte écrite, il annonce
    /// ce qui a été fait.
    @ViewBuilder
    private func cardOffer(_ card: GeneratedFlashcard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MicaboSectionCaption(text: "À réviser plus tard")

            VStack(alignment: .leading, spacing: 6) {
                Text(FormulaRenderer.stripped(card.front))
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(FormulaRenderer.stripped(card.back))
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .micaboGroup(radius: MicaboRadius.lg)

            Button {
                add(card)
            } label: {
                HStack(spacing: MicaboSpacing.xs) {
                    Image(systemName: savedCard ? "checkmark" : "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text(savedCard ? "Carte ajoutée au cours" : "En faire une carte")
                }
            }
            .buttonStyle(MicaboSecondaryButtonStyle())
            .disabled(savedCard)
        }
        .padding(.top, MicaboSpacing.xxs)
    }

    private func failureState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            Text(message)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Réessayer") {
                Task { await load() }
            }
            .buttonStyle(MicaboSecondaryButtonStyle())
        }
    }

    // MARK: - Actions

    @MainActor
    private func load() async {
        isLoading = true
        failure = nil

        let request = SelectionExplanationRequest(
            selection: quoted,
            courseTitle: course.title,
            subject: course.subject,
            courseContext: course.contextSnippet(limit: 16_000)
        )

        do {
            explanation = try await aiService.explain(request)
        } catch {
            explanation = nil
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func add(_ card: GeneratedFlashcard) {
        guard !savedCard else { return }
        do {
            let inserted = try CourseRepository.addFlashcards([card], to: course, in: modelContext)
            guard !inserted.isEmpty else { return }
            savedCard = true
            Haptics.success()
        } catch {
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// L'attente d'une explication.
///
/// Trois lignes de texte qui respirent, à la place du texte à venir : un tourniquet
/// centré ne dirait pas ce qui se prépare, et surtout il ferait sauter la mise en page
/// d'un coup quand la réponse arrive.
private struct LoadingLines: View {
    @State private var isAnimating = false

    private let widths: [CGFloat] = [1, 0.94, 0.72]

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            Text("Micabo relit ton cours.")
                .font(MicaboFont.hanken(15, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            VStack(alignment: .leading, spacing: 11) {
                ForEach(Array(widths.enumerated()), id: \.offset) { index, width in
                    GeometryReader { proxy in
                        Capsule()
                            .fill(MicaboColor.surfaceSunken)
                            .frame(width: proxy.size.width * width)
                            .opacity(isAnimating ? 0.45 : 1)
                            .animation(
                                .easeInOut(duration: 0.9)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.14),
                                value: isAnimating
                            )
                    }
                    .frame(height: 11)
                }
            }
        }
        .onAppear { isAnimating = true }
    }
}
