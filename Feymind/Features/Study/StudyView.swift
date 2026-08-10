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
        .feyScreenBackground()
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - En-tête (maquette : X · barre · 4/12)

    private var headerBar: some View {
        HStack(spacing: 14) {
            if !isEmbedded {
                FeyCircleButton(systemImage: "xmark", size: 32, accessibilityTitle: "Fermer") {
                    finish()
                }
            }

            FeyProgressBar(progress: session.progress, tint: FeyColor.accent, track: FeyColor.surfaceSunken)
                .frame(height: 5)

            Text(totalLabel)
                .font(FeyFont.hanken(12, weight: .semibold))
                .foregroundStyle(FeyColor.inkTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, FeySpacing.screen)
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
                    isInteractive: true
                )
                .id(card.id)
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        session.reveal()
                    }
                }
            }
        }
        .padding(.horizontal, FeySpacing.screen)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Commandes

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 14) {
            if session.isRevealed {
                Text("Comment as-tu répondu ?")
                    .font(FeyFont.hanken(11, weight: .medium))
                    .foregroundStyle(FeyColor.inkTertiary)

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
                .buttonStyle(FeyPrimaryButtonStyle())

                HStack(spacing: 24) {
                    Button("Passer") { withAnimation { session.skip() } }
                        .font(FeyFont.hanken(13, weight: .medium))
                        .foregroundStyle(FeyColor.inkTertiary)
                    Button("Mettre en pause") { session.suspendCurrent() }
                        .font(FeyFont.hanken(13, weight: .medium))
                        .foregroundStyle(FeyColor.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FeySpacing.screen)
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
    var isInteractive: Bool = true

    var body: some View {
        VStack(alignment: showAnswer ? .leading : .center, spacing: 14) {
            if showAnswer {
                Text("RÉPONSE")
                    .font(FeyFont.hanken(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(FeyColor.accent)

                Text(card.front)
                    .font(FeyFont.hanken(17, weight: .semibold))
                    .foregroundStyle(FeyColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(FeyColor.stroke)
                    .frame(height: 1)

                ScrollView {
                    Text(card.back)
                        .font(FeyFont.hanken(15, weight: .regular))
                        .foregroundStyle(Color(hex: 0x4A463F))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Spacer(minLength: 0)

                if let subject = card.course?.subject?.nilIfBlank ?? card.course?.title {
                    Text(subject.uppercased())
                        .font(FeyFont.hanken(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(FeyColor.inkTertiary)
                }

                Text(card.front)
                    .font(FeyFont.hanken(24, weight: .semibold))
                    .foregroundStyle(FeyColor.ink)
                    .tracking(-0.2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
        }
        .padding(showAnswer ? 26 : 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showAnswer ? .topLeading : .center)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
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
                        .font(FeyFont.hanken(13, weight: .semibold))
                        .foregroundStyle(tint(for: rating))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(softTint(for: rating), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: Color(hex: 0xB5573C)
        case .hard: FeyColor.caution
        case .good: FeyColor.positive
        case .easy: FeyColor.info
        }
    }

    private func softTint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: FeyColor.negativeSoft
        case .hard: FeyColor.cautionSoft
        case .good: FeyColor.positiveSoft
        case .easy: FeyColor.infoSoft
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
                .foregroundStyle(Color(hex: 0xB39A5A))
                .frame(width: 76, height: 76)
                .background(Color(hex: 0xF0ECE2), in: Circle())
                .padding(.bottom, 8)

            Text(session.answeredCount > 0 ? "Session terminée" : "Rien à réviser")
                .font(FeyFont.hanken(24, weight: .bold))
                .foregroundStyle(FeyColor.ink)
                .tracking(-0.2)

            Text(session.answeredCount > 0
                 ? "\(session.answeredCount) cartes révisées en \(durationLabel)"
                 : "Revenez plus tard, ou entraînez-vous en avance depuis un cours.")
                .font(FeyFont.body)
                .foregroundStyle(FeyColor.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, FeySpacing.lg)
                .padding(.bottom, 20)

            if session.answeredCount > 0 {
                HStack(spacing: 10) {
                    stat("\(session.goodCount)", "acquises", FeyColor.positive)
                    stat("\(session.againCount)", "à revoir", FeyColor.caution)
                    stat("\(Int(session.accuracy * 100)) %", "réussite", FeyColor.accent)
                }
                .padding(.horizontal, FeySpacing.screen)
            }

            Spacer()

            Button(isEmbedded ? "Recharger la session" : "Terminer", action: onFinish)
                .buttonStyle(FeyPrimaryButtonStyle())
                .padding(.horizontal, FeySpacing.screen)
                .padding(.bottom, FeySpacing.lg)
        }
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(FeyFont.hanken(22, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(FeyFont.hanken(10, weight: .medium))
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.button, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
    }

    private var durationLabel: String {
        let minutes = Int(session.elapsed / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}
