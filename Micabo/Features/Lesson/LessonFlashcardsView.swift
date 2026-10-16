import SwiftUI

/// Où en est une carte, en trois mots que tout le monde comprend.
enum CardMastery: CaseIterable {
    /// Jamais révisée.
    case new
    /// En cours d'apprentissage : vue, mais pas encore ancrée.
    case learning
    /// Ancrée : son prochain rappel est à trois semaines ou plus.
    case mastered

    init(_ card: Flashcard) {
        if card.state == .new {
            self = .new
        } else if card.intervalDays >= 21 {
            self = .mastered
        } else {
            self = .learning
        }
    }

    var color: Color {
        switch self {
        case .new: MicaboColor.accent
        case .learning: LessonTone.yellow.vivid
        case .mastered: MicaboColor.correct
        }
    }

    var titleKey: String {
        switch self {
        case .new: "lesson.cards.mastery.new"
        case .learning: "lesson.cards.mastery.learning"
        case .mastered: "lesson.cards.mastery.mastered"
        }
    }
}

/// **Les flashcards d'une leçon** : « Ta progression » (nouvelles, en cours, maîtrisées),
/// « Commencer à réviser », puis toutes les cartes, chacune avec sa pastille.
///
/// La révision prend d'abord les cartes dues, puis des nouvelles, quinze au plus par séance :
/// toutes les cartes de la leçon finissent par entrer dans le rythme, sans tout déverser d'un
/// coup.
struct LessonCardsHub: View {
    let session: LessonSession

    @Environment(\.dismiss) private var dismiss
    @State private var running: [Flashcard]?
    @State private var shown = false

    var body: some View {
        Group {
            if let running {
                LessonCardsRun(session: session, cards: running, onClose: { withAnimation { self.running = nil } })
                    .transition(.move(edge: .trailing))
            } else {
                overview
            }
        }
        .animation(.spring(duration: 0.4), value: running == nil)
    }

    private var cards: [Flashcard] {
        session.course.cards.filter { !$0.isSuspended }.sorted { $0.position < $1.position }
    }

    private var overview: some View {
        let cards = self.cards
        let counts = Dictionary(grouping: cards, by: CardMastery.init).mapValues(\.count)
        let queue = session.studyQueue()
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))

                Text(L10n.t("lesson.nav.flashcards", locale: .resolved()))
                    .font(MicaboFont.display(40))
                    .foregroundStyle(MicaboColor.ink)

                progressCard(counts: counts, total: cards.count, queue: queue)

                if !cards.isEmpty {
                    Text(L10n.t("lesson.cards.all", locale: .resolved(), vars: ["count": String(cards.count)]))
                        .font(MicaboFont.ui(24, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .padding(.top, 6)
                    LazyVStack(spacing: 12) {
                        ForEach(cards) { card in
                            CardRow(card: card, tone: session.course.tone)
                        }
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onAppear { withAnimation(.easeOut(duration: 0.9).delay(0.15)) { shown = true } }
    }

    private func progressCard(counts: [CardMastery: Int], total: Int, queue: [Flashcard]) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.t("lesson.cards.progress", locale: .resolved()))
                .font(MicaboFont.ui(22, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(CardMastery.allCases, id: \.self) { mastery in
                        let share = total == 0 ? 0 : CGFloat(counts[mastery] ?? 0) / CGFloat(total)
                        Rectangle()
                            .fill(mastery.color)
                            .frame(width: shown ? proxy.size.width * share : 0)
                    }
                    Spacer(minLength: 0)
                }
                .background(MicaboColor.track)
                .clipShape(Capsule())
            }
            .frame(height: 14)

            HStack(spacing: 16) {
                ForEach(CardMastery.allCases, id: \.self) { mastery in
                    HStack(spacing: 6) {
                        Circle().fill(mastery.color).frame(width: 10, height: 10)
                        Text("\(counts[mastery] ?? 0) \(L10n.t(mastery.titleKey, locale: .resolved()))")
                            .font(MicaboFont.ui(15, weight: .semibold))
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Button {
                Haptics.medium()
                withAnimation { running = queue.isEmpty ? Array(cards.shuffled().prefix(20)) : queue }
            } label: {
                Label(queue.isEmpty
                    ? L10n.t("lesson.cards.reviewAnyway", locale: .resolved())
                    : L10n.t("lesson.cards.start", locale: .resolved(), vars: ["count": String(queue.count)]),
                    systemImage: "lightbulb.max")
            }
            .buttonStyle(LessonPrimaryButtonStyle(enabled: total > 0))
            .disabled(total == 0)

            if total == 0 {
                Text(L10n.t("lesson.cards.empty", locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
        }
        .padding(20)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }
}

/// Une carte dans la liste : le recto en couleur, le verso en dessous, la pastille d'état.
private struct CardRow: View {
    let card: Flashcard
    let tone: LessonTone

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(card.format == .cloze ? card.front.replacingOccurrences(of: ClozeGap.marker, with: "____") : card.front)
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(tone.ink)
                    .lineLimit(2)
                Text(card.kind == .choice && card.choices.indices.contains(card.correctChoiceIndex) ? card.choices[card.correctChoiceIndex] : card.back)
                    .font(MicaboFont.ui(16, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
            Circle()
                .fill(CardMastery(card).color)
                .frame(width: 14, height: 14)
                .accessibilityLabel(Text(L10n.t(CardMastery(card).titleKey, locale: .resolved())))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
    }
}
