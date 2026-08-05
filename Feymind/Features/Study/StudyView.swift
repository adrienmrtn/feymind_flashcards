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

    private var accent: Color {
        if case .course(let course) = source {
            return Color(hexString: course.accentHex)
        }
        return FeyColor.accent
    }

    private var title: String {
        switch source {
        case .course(let course): course.title
        case .allDue: "Révisions du jour"
        case .cards: "Entraînement"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if session.isFinished {
                CompletionView(session: session, accent: accent, isEmbedded: isEmbedded) {
                    finish()
                }
            } else {
                cardArea
                controls
            }
        }
        .feyScreenBackground()
        .onAppear(perform: startIfNeeded)
    }

    // MARK: - En-tête

    private var headerBar: some View {
        VStack(spacing: FeySpacing.sm) {
            HStack(spacing: FeySpacing.sm) {
                if !isEmbedded {
                    Button {
                        finish()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(FeyColor.inkSecondary)
                            .frame(width: 34, height: 34)
                            .background(FeyColor.surfaceMuted, in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(FeyFont.cardTitle)
                        .foregroundStyle(FeyColor.ink)
                        .lineLimit(1)
                    Text(session.isFinished ? "Session terminée" : "\(session.answeredCount) répondues")
                        .font(FeyFont.micro)
                        .foregroundStyle(FeyColor.inkTertiary)
                }

                Spacer(minLength: 0)

                countsView
            }

            FeyProgressBar(progress: session.progress, tint: accent)
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, isEmbedded ? FeySpacing.xxs : FeySpacing.md)
        .padding(.bottom, FeySpacing.sm)
    }

    private var countsView: some View {
        HStack(spacing: 6) {
            countPill(session.counts.newCards, FeyColor.mint)
            countPill(session.counts.learning, FeyColor.amber)
            countPill(session.counts.review, accent)
        }
    }

    private func countPill(_ value: Int, _ tint: Color) -> some View {
        Text("\(value)")
            .font(FeyFont.micro)
            .foregroundStyle(value > 0 ? tint : FeyColor.inkTertiary)
            .frame(minWidth: 24)
            .padding(.vertical, 5)
            .background(value > 0 ? tint.opacity(0.12) : FeyColor.surfaceMuted, in: Capsule())
    }

    // MARK: - Pile de cartes

    private var cardArea: some View {
        ZStack {
            ForEach(Array(session.upcoming(2).enumerated().reversed()), id: \.element.id) { index, card in
                StudyCardFace(card: card, showAnswer: false, accent: accent, isInteractive: false)
                    .scaleEffect(1 - CGFloat(index + 1) * 0.04)
                    .offset(y: CGFloat(index + 1) * 12)
                    .opacity(0.55 - Double(index) * 0.2)
            }

            if let card = session.current {
                StudyCardFace(
                    card: card,
                    showAnswer: session.isRevealed,
                    accent: accent,
                    isInteractive: true
                )
                .id(card.id)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        session.reveal()
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: session.current?.id)
        .padding(.horizontal, FeySpacing.screen)
        .frame(maxHeight: .infinity)
    }

    // MARK: - Commandes

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: FeySpacing.sm) {
            if session.isRevealed {
                GradeButtons(labels: session.previewLabels) { rating in
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
                .buttonStyle(FeyPrimaryButtonStyle(tint: accent))
                .transition(.opacity)
            }

            HStack(spacing: FeySpacing.md) {
                Button("Passer") { withAnimation { session.skip() } }
                    .buttonStyle(FeyQuietButtonStyle())
                Button("Mettre en pause") { session.suspendCurrent() }
                    .buttonStyle(FeyQuietButtonStyle())
            }
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, FeySpacing.sm)
        .padding(.bottom, isEmbedded ? FeySpacing.sm : FeySpacing.lg)
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
    let accent: Color
    var isInteractive: Bool = true

    var body: some View {
        ZStack {
            face(isBack: false)
                .opacity(showAnswer ? 0 : 1)

            face(isBack: true)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(showAnswer ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(showAnswer ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.4
        )
        .animation(.spring(response: 0.5, dampingFraction: 0.82), value: showAnswer)
    }

    private func face(isBack: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(accent.opacity(0.5))
                    .frame(width: 5, height: 5)
                Text(isBack ? "Réponse" : "Question")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
                Spacer()
                if let subject = card.course?.subject?.nilIfBlank {
                    Text(subject)
                        .font(FeyFont.micro)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
            .padding(.horizontal, FeySpacing.lg)
            .padding(.top, FeySpacing.md)

            ScrollView {
                VStack(spacing: FeySpacing.md) {
                    if isBack {
                        Text(card.front)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FeyColor.inkTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, FeySpacing.xxs)

                        Rectangle()
                            .fill(FeyColor.stroke)
                            .frame(width: 46, height: 1)

                        Text(card.back)
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(FeyColor.ink)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(card.front)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(FeyColor.ink)
                            .multilineTextAlignment(.center)

                        if let hint = card.hint?.nilIfBlank {
                            Text(hint)
                                .font(FeyFont.caption)
                                .foregroundStyle(FeyColor.inkTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, FeySpacing.xs)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, FeySpacing.lg)
                .padding(.vertical, FeySpacing.lg)
            }
            .scrollBounceBehavior(.basedOnSize)

            if !isBack, isInteractive {
                Text("Touchez la carte pour retourner")
                    .font(FeyFont.micro)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .padding(.bottom, FeySpacing.md)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.xl, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(accent)
                .frame(width: 44, height: 4)
                .offset(y: -2)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

// MARK: - Boutons de maîtrise

struct GradeButtons: View {
    let labels: [ReviewRating: String]
    var onSelect: (ReviewRating) -> Void

    var body: some View {
        HStack(spacing: FeySpacing.xs) {
            ForEach(ReviewRating.allCases) { rating in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(rating)
                } label: {
                    VStack(spacing: 3) {
                        Text(rating.shortLabel)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(labels[rating] ?? "")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .opacity(0.75)
                    }
                    .foregroundStyle(tint(for: rating))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(tint(for: rating).opacity(0.11), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                            .strokeBorder(tint(for: rating).opacity(0.22), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: FeyColor.coral
        case .hard: FeyColor.amber
        case .good: FeyColor.mint
        case .easy: FeyColor.sky
        }
    }
}

// MARK: - Fin de session

private struct CompletionView: View {
    let session: StudySession
    let accent: Color
    let isEmbedded: Bool
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: FeySpacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(accent.opacity(0.10))
                    .frame(width: 120, height: 120)
                Image(systemName: session.answeredCount > 0 ? "checkmark.seal.fill" : "moon.zzz.fill")
                    .font(.system(size: 46, weight: .medium))
                    .foregroundStyle(accent)
            }

            VStack(spacing: 6) {
                Text(session.answeredCount > 0 ? "Session terminée" : "Rien à réviser")
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)

                Text(session.answeredCount > 0
                     ? "Vos prochaines échéances sont enregistrées."
                     : "Revenez plus tard, ou entraînez-vous en avance depuis un cours.")
                    .font(FeyFont.body)
                    .foregroundStyle(FeyColor.inkTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, FeySpacing.lg)
            }

            if session.answeredCount > 0 {
                HStack(spacing: FeySpacing.sm) {
                    stat("\(session.answeredCount)", "réponses")
                    stat("\(Int(session.accuracy * 100)) %", "réussite")
                    stat(durationLabel, "durée")
                }
                .padding(.horizontal, FeySpacing.screen)
            }

            Spacer()

            Button(isEmbedded ? "Recharger" : "Terminer", action: onFinish)
                .buttonStyle(FeyPrimaryButtonStyle(tint: accent))
                .padding(.horizontal, FeySpacing.screen)
                .padding(.bottom, FeySpacing.lg)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(FeyFont.display(22))
                .foregroundStyle(FeyColor.ink)
            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FeySpacing.sm)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous)
                .strokeBorder(FeyColor.stroke, lineWidth: 1)
        }
    }

    private var durationLabel: String {
        let minutes = Int(session.elapsed / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}
