import SwiftData
import SwiftUI
import UIKit

struct StudyView: View {
    let source: StudySource
    var isEmbedded: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var session = StudySession()
    @State private var didStart = false
    @State private var showHint = false

    private var totalLabel: String {
        let answered = session.answeredCount
        let total = max(session.initialCount, 1)
        let current = session.isFinished ? total : min(answered + 1, total)
        return "\(current)/\(total)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if session.isFinished {
                CompletionView(session: session, isEmbedded: isEmbedded) {
                    finish()
                }
            } else {
                headerBar
                cardArea
                controls
            }
        }
        .micaboScreenBackground()
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - En-tête (maquette : X · barre · 4/12)

    private var headerBar: some View {
        HStack(spacing: 14) {
            if !isEmbedded {
                MicaboCircleButton(systemImage: "xmark", size: 32, accessibilityTitle: "Fermer") {
                    finish()
                }
            }

            MicaboProgressBar(progress: session.progress, tint: MicaboColor.accent, track: MicaboColor.surfaceSunken)
                .frame(height: 5)

            Text(totalLabel)
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 22)
    }

    // MARK: - Carte

    private var cardArea: some View {
        Group {
            if let card = session.current {
                StudyCardFace(
                    card: card,
                    showAnswer: session.isRevealed,
                    isHintVisible: showHint,
                    onToggleHint: toggleHint
                )
                .id(card.id)
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        session.reveal()
                    }
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .frame(maxHeight: .infinity)
        .onChange(of: session.current?.id) { _, _ in
            showHint = false
        }
    }

    private func toggleHint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            showHint.toggle()
        }
    }

    // MARK: - Commandes

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 14) {
            if session.isRevealed {
                Text("Comment as-tu répondu ?")
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)

                GradeButtons { rating in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        session.answer(rating)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        session.reveal()
                    }
                } label: {
                    Text("Afficher la réponse")
                }
                .buttonStyle(MicaboPrimaryButtonStyle())

                HStack(spacing: 24) {
                    Button("Passer") { withAnimation { session.skip() } }
                        .font(MicaboFont.hanken(13, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                    Button("Mettre en pause") { session.suspendCurrent() }
                        .font(MicaboFont.hanken(13, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: session.isRevealed)
    }

    // MARK: - Actions

    private func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        session.start(with: resolveCards(), context: modelContext)
    }

    private func resolveCards() -> [Flashcard] {
        switch source {
        case .course(let course): course.cards
        case .allDue: CourseRepository.allCards(in: modelContext)
        case .cards(let cards): cards
        }
    }

    private func finish() {
        if isEmbedded {
            session = StudySession()
            didStart = false
            startIfNeeded()
        } else {
            dismiss()
        }
    }
}

// MARK: - Carte

struct StudyCardFace: View {
    let card: Flashcard
    let showAnswer: Bool
    var isHintVisible: Bool = false
    var onToggleHint: (() -> Void)?

    var body: some View {
        VStack(alignment: showAnswer ? .leading : .center, spacing: 14) {
            if showAnswer {
                Text("RÉPONSE")
                    .font(MicaboFont.hanken(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MicaboColor.accent)

                Text(card.front)
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                MicaboHairline()

                ScrollView {
                    Text(card.back)
                        .font(MicaboFont.hanken(15, weight: .regular))
                        .foregroundStyle(Color(hex: 0x4A463F))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Spacer(minLength: 0)

                if let subject = card.course?.subject?.nilIfBlank ?? card.course?.title {
                    Text(subject.uppercased())
                        .font(MicaboFont.hanken(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Text(card.front)
                    .font(MicaboFont.hanken(24, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if onToggleHint != nil {
                    hintArea
                }
            }
        }
        .padding(showAnswer ? 26 : 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showAnswer ? .topLeading : .center)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    /// Ampoule au pied de la question : un appui donne un coup de pouce sans livrer la réponse.
    @ViewBuilder
    private var hintArea: some View {
        if isHintVisible {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.caution)

                Text(StudyHint.text(for: card))
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x4A463F))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(MicaboColor.cautionSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
            .transition(.opacity)
        } else {
            Button {
                onToggleHint?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Indice")
                        .font(MicaboFont.hanken(13, weight: .semibold))
                }
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(MicaboColor.surfaceMuted, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Afficher un indice")
        }
    }
}

/// Indice affiché pendant la révision. Les cartes écrites par l'IA en portent souvent un ;
/// pour les autres, on en dérive un de la réponse plutôt que de laisser l'ampoule vide.
enum StudyHint {
    static func text(for card: Flashcard) -> String {
        if let written = card.hint?.nilIfBlank {
            return written
        }
        return derived(from: card.back)
    }

    static func derived(from answer: String) -> String {
        let words = answer
            .split(whereSeparator: { $0 == " " || $0.isNewline })
            .map(String.init)

        guard let first = words.first else {
            return "Pas d'indice pour cette carte."
        }

        guard words.count > 2 else {
            return "La réponse commence par « \(first) »."
        }

        let shown = max(1, min(3, words.count / 4))
        let start = words.prefix(shown).joined(separator: " ")
        return "Commence par « \(start)… », \(words.count) mots en tout."
    }
}

// MARK: - Boutons de maîtrise (grille 2×2 de la maquette)

struct GradeButtons: View {
    var onSelect: (ReviewRating) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
            spacing: 9
        ) {
            ForEach(ReviewRating.allCases) { rating in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(rating)
                } label: {
                    Text(rating.label)
                        .font(MicaboFont.hanken(14, weight: .semibold))
                        .foregroundStyle(tint(for: rating))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(softTint(for: rating), in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: Color(hex: 0xB5573C)
        case .hard: MicaboColor.caution
        case .good: MicaboColor.positive
        case .easy: MicaboColor.info
        }
    }

    private func softTint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: MicaboColor.negativeSoft
        case .hard: MicaboColor.cautionSoft
        case .good: MicaboColor.positiveSoft
        case .easy: MicaboColor.infoSoft
        }
    }
}

// MARK: - Fin de session

private struct CompletionView: View {
    let session: StudySession
    let isEmbedded: Bool
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: session.answeredCount > 0 ? "trophy" : "moon.zzz")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(MicaboColor.caution)
                .frame(width: 78, height: 78)
                .background(MicaboColor.cautionSoft, in: Circle())
                .padding(.bottom, 8)

            Text(session.answeredCount > 0 ? "Session terminée" : "Rien à réviser")
                .font(MicaboFont.hanken(24, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)

            Text(session.answeredCount > 0
                 ? "\(session.answeredCount) cartes révisées en \(durationLabel)"
                 : "Revenez plus tard, ou entraînez-vous en avance depuis un cours.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MicaboSpacing.lg)
                .padding(.bottom, 20)

            if session.answeredCount > 0 {
                HStack(spacing: 10) {
                    stat("\(session.goodCount)", "acquises", MicaboColor.positive)
                    stat("\(session.againCount)", "à revoir", MicaboColor.caution)
                    stat("\(Int(session.accuracy * 100)) %", "réussite", MicaboColor.accent)
                }
                .padding(.horizontal, MicaboSpacing.screen)
            }

            Spacer()

            Button(isEmbedded ? "Recharger la session" : "Terminer", action: onFinish)
                .buttonStyle(MicaboPrimaryButtonStyle())
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.lg)
        }
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MicaboFont.hanken(22, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(MicaboFont.hanken(10, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .micaboGroup(radius: MicaboRadius.button)
    }

    private var durationLabel: String {
        let minutes = Int(session.elapsed / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}
