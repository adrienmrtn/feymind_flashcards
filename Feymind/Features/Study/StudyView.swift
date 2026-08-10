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

    private var title: String {
        switch source {
        case .course(let course): course.title
        case .allDue: "Révisions du jour"
        case .cards: "Entraînement"
        }
    }

    private var progressLabel: String {
        session.isFinished ? "Session terminée" : "\(session.answeredCount) répondues"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            if session.isFinished {
                CompletionView(session: session, isEmbedded: isEmbedded) {
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
                    FeyCircleButton(systemImage: "xmark", size: 38, accessibilityTitle: "Fermer") {
                        finish()
                    }
                }

                VStack(alignment: .leading, spacing: 1) {
                    // Intégrée dans l'onglet Réviser, la vue n'a pas besoin de répéter son titre.
                    Text(isEmbedded ? progressLabel : title)
                        .font(FeyFont.cardTitle)
                        .foregroundStyle(FeyColor.ink)
                        .lineLimit(1)

                    if !isEmbedded {
                        Text(progressLabel)
                            .font(FeyFont.micro)
                            .foregroundStyle(FeyColor.inkTertiary)
                    }
                }

                Spacer(minLength: 0)

                countsView
            }

            FeyProgressBar(progress: session.progress, tint: FeyColor.accent)
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, isEmbedded ? FeySpacing.xxs : FeySpacing.md)
        .padding(.bottom, FeySpacing.md)
    }

    private var countsView: some View {
        HStack(spacing: 5) {
            countPill(session.counts.newCards)
            countPill(session.counts.learning)
            countPill(session.counts.review)
        }
    }

    private func countPill(_ value: Int) -> some View {
        Text("\(value)")
            .font(FeyFont.micro)
            .foregroundStyle(value > 0 ? FeyColor.ink : FeyColor.inkTertiary)
            .frame(minWidth: 26)
            .padding(.vertical, 6)
            .background(value > 0 ? FeyColor.surface : FeyColor.surfaceMuted, in: Capsule())
    }

    // MARK: - Pile de cartes

    private var cardArea: some View {
        ZStack {
            ForEach(Array(session.upcoming(2).enumerated().reversed()), id: \.element.id) { index, card in
                StudyCardFace(card: card, showAnswer: false, isInteractive: false)
                    .scaleEffect(1 - CGFloat(index + 1) * 0.035)
                    .offset(y: CGFloat(index + 1) * 12)
                    .opacity(0.5 - Double(index) * 0.2)
            }

            if let card = session.current {
                StudyCardFace(
                    card: card,
                    showAnswer: session.isRevealed,
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
                .buttonStyle(FeyPrimaryButtonStyle())
                .transition(.opacity)
            }

            HStack(spacing: FeySpacing.sm) {
                Button("Passer") { withAnimation { session.skip() } }
                    .buttonStyle(FeyQuietButtonStyle())
                Button("Mettre en pause") { session.suspendCurrent() }
                    .buttonStyle(FeyQuietButtonStyle())
            }
        }
        .padding(.horizontal, FeySpacing.screen)
        .padding(.top, FeySpacing.md)
        .padding(.bottom, isEmbedded ? FeyLayout.tabBarClearance : FeySpacing.lg)
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
            HStack {
                Text(isBack ? "Réponse" : "Question")
                    .font(FeyFont.micro)
                    .foregroundStyle(isBack ? FeyColor.accent : FeyColor.inkTertiary)
                Spacer()
                if let subject = card.course?.subject?.nilIfBlank {
                    Text(subject)
                        .font(FeyFont.micro)
                        .foregroundStyle(FeyColor.inkTertiary)
                }
            }
            .padding(.horizontal, FeySpacing.lg)
            .padding(.top, FeySpacing.lg)

            ScrollView {
                VStack(spacing: FeySpacing.md) {
                    if isBack {
                        Text(card.front)
                            .font(FeyFont.captionEmphasis)
                            .foregroundStyle(FeyColor.inkTertiary)
                            .multilineTextAlignment(.center)

                        Rectangle()
                            .fill(FeyColor.stroke)
                            .frame(width: 40, height: 1)

                        Text(card.back)
                            .font(FeyFont.hanken(21, weight: .medium))
                            .foregroundStyle(FeyColor.ink)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(card.front)
                            .font(FeyFont.hanken(24, weight: .semibold))
                            .foregroundStyle(FeyColor.ink)
                            .tracking(FeyTracking.tight)
                            .multilineTextAlignment(.center)

                        if let hint = card.hint?.nilIfBlank {
                            Text(hint)
                                .font(FeyFont.caption)
                                .foregroundStyle(FeyColor.inkTertiary)
                                .multilineTextAlignment(.center)
                                .padding(.top, FeySpacing.xxs)
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
                    .padding(.bottom, FeySpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.xxl, style: .continuous))
        .feySoftShadow(strength: 0.08)
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
                            .font(FeyFont.hanken(14, weight: .semibold))
                            .foregroundStyle(tint(for: rating))
                        Text(labels[rating] ?? "")
                            .font(FeyFont.micro)
                            .foregroundStyle(tint(for: rating).opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(softTint(for: rating), in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: FeyColor.negative
        case .hard: FeyColor.caution
        case .good: FeyColor.positive
        case .easy: FeyColor.accent
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
        VStack(spacing: FeySpacing.lg) {
            Spacer()

            Image(systemName: session.answeredCount > 0 ? "checkmark" : "moon.zzz")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(FeyColor.onInk)
                .frame(width: 96, height: 96)
                .background(FeyColor.ink, in: Circle())

            VStack(spacing: 6) {
                Text(session.answeredCount > 0 ? "Session terminée" : "Rien à réviser")
                    .font(FeyFont.screenTitle)
                    .foregroundStyle(FeyColor.ink)
                    .tracking(FeyTracking.tight)

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
                .buttonStyle(FeyPrimaryButtonStyle())
                .padding(.horizontal, FeySpacing.screen)
                .padding(.bottom, isEmbedded ? FeyLayout.tabBarClearance : FeySpacing.lg)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(FeyFont.display(21))
                .foregroundStyle(FeyColor.ink)
            Text(label)
                .font(FeyFont.micro)
                .foregroundStyle(FeyColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, FeySpacing.sm)
        .background(FeyColor.surface, in: RoundedRectangle(cornerRadius: FeyRadius.md, style: .continuous))
    }

    private var durationLabel: String {
        let minutes = Int(session.elapsed / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}
