import SwiftUI

/// Panneau qui remonte du bas quand l'étudiant demande une explication sur un passage.
struct AskAISheet: View {
    let course: Course
    let selection: String

    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var angle: ExplainAngle = .explain
    @State private var answer: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var accent: Color { Color(hexString: course.accentHex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FeySpacing.md) {
                    quotedSelection
                    anglePicker

                    if isLoading {
                        LoadingLines()
                    } else if let errorMessage {
                        errorView(errorMessage)
                    } else if !answer.isEmpty {
                        answerView
                    }
                }
                .padding(.horizontal, FeySpacing.screen)
                .padding(.top, FeySpacing.sm)
                .padding(.bottom, FeySpacing.xl)
            }
            .feyScreenBackground()
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Demander à l'IA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(FeyColor.inkTertiary)
                    }
                }
            }
        }
        .task(id: angle) { await ask() }
    }

    private var quotedSelection: some View {
        HStack(alignment: .top, spacing: FeySpacing.sm) {
            Capsule()
                .fill(accent.opacity(0.4))
                .frame(width: 3)

            Text(selection)
                .font(.system(size: 15))
                .foregroundStyle(FeyColor.inkSecondary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(FeySpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.surfaceMuted, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
    }

    private var anglePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: FeySpacing.xs) {
                ForEach(ExplainAngle.allCases) { option in
                    Button {
                        guard option != angle else { return }
                        angle = option
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: option.systemImage)
                                .font(.system(size: 11, weight: .bold))
                            Text(option.label)
                                .font(FeyFont.caption)
                        }
                        .foregroundStyle(option == angle ? .white : FeyColor.inkSecondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 13)
                        .background(option == angle ? accent : FeyColor.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var answerView: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            ForEach(Array(answerParagraphs.enumerated()), id: \.offset) { _, paragraph in
                InlineMarkup.swiftUIText(paragraph)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
        .textSelection(.enabled)
    }

    private var answerParagraphs: [String] {
        answer
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func errorView(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkSecondary)

            Button("Réessayer") {
                Task { await ask() }
            }
            .buttonStyle(FeySecondaryButtonStyle(tint: accent, fullWidth: false))
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.amberSoft, in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
    }

    @MainActor
    private func ask() async {
        isLoading = true
        errorMessage = nil
        answer = ""

        let request = ExplainRequest(
            selection: selection,
            courseTitle: course.title,
            courseContext: course.contextSnippet(),
            angle: angle
        )

        do {
            let result = try await aiService.explain(request)
            answer = TextSanitizer.removeEmDashes(result)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }
}

/// Squelette animé affiché pendant la génération.
struct LoadingLines: View {
    var lineCount: Int = 4
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: FeySpacing.sm) {
            ForEach(0..<lineCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(FeyColor.surfaceMuted)
                    .frame(height: 13)
                    .frame(maxWidth: index == lineCount - 1 ? 180 : .infinity, alignment: .leading)
                    .overlay {
                        GeometryReader { proxy in
                            LinearGradient(
                                colors: [.clear, Color.white.opacity(0.85), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: proxy.size.width * 0.4)
                            .offset(x: phase * proxy.size.width)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
        .padding(FeySpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.lg, style: .continuous))
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        }
    }
}