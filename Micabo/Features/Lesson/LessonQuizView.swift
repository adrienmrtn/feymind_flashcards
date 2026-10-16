import SwiftData
import SwiftUI

/// **Un quiz** : un QCM par écran, la barre « 2 / 5 », la réponse tout de suite en vert ou en
/// rouge avec sa phrase d'explication, puis le score avec Mika. Sert au cercle Quiz (cinq
/// questions), au quiz complet de la navbar et à l'examen blanc (dix).
///
/// Il n'y a pas de score minimum : un cercle Quiz se coche quand toutes les questions sont
/// répondues. Chaque question ratée devient une flashcard à revoir demain.
struct LessonQuizView: View {
    let session: LessonSession
    let title: String
    /// Le cercle que ce quiz coche ; `nil` pour le quiz complet et l'examen blanc.
    let circleID: String?
    let onClose: () -> Void
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    /// Le tirage, figé à l'ouverture : une question ratée change l'ordre du prochain tirage,
    /// pas celui du quiz en cours.
    @State private var questions: [QuizQuestion]
    @State private var index = 0
    @State private var answer: Int?
    @State private var right = 0
    @State private var finished = false

    init(
        session: LessonSession,
        questions: [QuizQuestion],
        title: String,
        circleID: String?,
        onClose: @escaping () -> Void,
        onDone: (() -> Void)? = nil
    ) {
        self.session = session
        self.title = title
        self.circleID = circleID
        self.onClose = onClose
        self.onDone = onDone
        _questions = State(initialValue: questions)
    }

    private var tone: LessonTone { session.course.tone }

    var body: some View {
        VStack(spacing: 0) {
            CircleTopBar(
                progress: questions.isEmpty ? 0 : Double(index + (answer == nil ? 0 : 1)) / Double(questions.count),
                tone: tone,
                label: questions.isEmpty || finished ? nil : "\(min(index + 1, questions.count)) / \(questions.count)",
                onClose: onClose
            )
            if questions.isEmpty {
                empty
            } else if finished {
                score
            } else {
                ScrollView {
                    QuestionCard(question: questions[index], tone: tone, answered: answer) { choice in
                        record(choice)
                    }
                    .id(index)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 16)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                }
                Button(L10n.t("lesson.quiz.continue", locale: .resolved()), action: next)
                    .buttonStyle(LessonPrimaryButtonStyle(enabled: answer != nil))
                    .disabled(answer == nil)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.bottom, 12)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .lessonClock(session, activity: circleID == nil ? .quiz : nil)
    }

    private func record(_ choice: Int) {
        answer = choice
        let question = questions[index]
        let isRight = choice == question.answer
        if isRight { right += 1 }
        isRight ? Haptics.success() : Haptics.warning()
        session.answered(question, right: isRight, in: modelContext)
    }

    private func next() {
        guard answer != nil else { return }
        if index + 1 < questions.count {
            withAnimation(.spring(duration: 0.35)) {
                index += 1
                answer = nil
            }
        } else {
            if let circleID {
                session.recordQuiz(circleID, right: right, total: questions.count, in: modelContext)
            }
            withAnimation(.spring(duration: 0.4)) { finished = true }
        }
    }

    private var score: some View {
        let ratio = Double(right) / Double(max(1, questions.count))
        return VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: ratio >= 0.8 ? .celebrate : ratio >= 0.5 ? .happy : .think, size: 170)
            Text("\(right) / \(questions.count)")
                .font(MicaboFont.number(56))
                .foregroundStyle(tone.ink)
                .monospacedDigit()
            Text(ratio >= 0.8
                ? L10n.t("lesson.quiz.great", locale: .resolved())
                : ratio >= 0.5
                ? L10n.t("lesson.quiz.good", locale: .resolved())
                : L10n.t("lesson.quiz.keepGoing", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            if right < questions.count {
                Text(L10n.t("lesson.quiz.missedBecomeCards", locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("lesson.circle.next", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle())
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
        .onAppear { if ratio >= 0.8 { Haptics.burst(count: 3, over: 0.4) } }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Spacer()
            MikaMascot(mood: .think, size: 150)
            Text(L10n.t("lesson.quiz.empty", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("lesson.circle.next", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle())
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
    }
}

// MARK: - Les flashcards

/// **Une série de flashcards** : on retourne, on note Encore / Bien / Facile, et l'écran de
/// fin « 10 / 10 ». Sert au cercle Flashcards et à la révision du jour de la leçon.
struct LessonCardsRun: View {
    let session: LessonSession
    let onClose: () -> Void
    var onDone: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    /// Les cartes, figées à l'ouverture : une carte notée change de rang dans le prochain
    /// tirage, pas dans la série en cours.
    @State private var cards: [Flashcard]
    @State private var index = 0
    @State private var flipped = false
    @State private var finished = false

    init(session: LessonSession, cards: [Flashcard], onClose: @escaping () -> Void, onDone: (() -> Void)? = nil) {
        self.session = session
        self.onClose = onClose
        self.onDone = onDone
        _cards = State(initialValue: cards)
    }

    private var tone: LessonTone { session.course.tone }

    var body: some View {
        VStack(spacing: 0) {
            CircleTopBar(
                progress: cards.isEmpty ? 0 : Double(index) / Double(cards.count),
                tone: tone,
                label: cards.isEmpty || finished ? nil : "\(index + 1) / \(cards.count)",
                onClose: onClose
            )
            if cards.isEmpty {
                emptyState
            } else if finished {
                finishedState
            } else {
                Spacer(minLength: 12)
                FlashcardFace(card: cards[index], flipped: flipped, tone: tone)
                    .id(index)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onTapGesture { flip() }
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                Spacer(minLength: 12)
                controls
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.bottom, 12)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .lessonClock(session, activity: onDone == nil ? .flashcards : nil)
    }

    @ViewBuilder
    private var controls: some View {
        if flipped {
            HStack(spacing: 10) {
                rating(.again, title: L10n.t("lesson.cards.again", locale: .resolved()), color: MicaboColor.wrong)
                rating(.good, title: L10n.t("lesson.cards.good", locale: .resolved()), color: tone.vivid)
                rating(.easy, title: L10n.t("lesson.cards.easy", locale: .resolved()), color: MicaboColor.correct)
            }
        } else {
            Button(L10n.t("lesson.cards.flip", locale: .resolved()), action: flip)
                .buttonStyle(LessonPrimaryButtonStyle())
        }
    }

    private func rating(_ rating: ReviewRating, title: String, color: Color) -> some View {
        Button {
            rate(rating)
        } label: {
            Text(title)
                .font(MicaboFont.ui(17, weight: .heavy))
                .foregroundStyle(MicaboColor.onInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
    }

    private func flip() {
        withAnimation(.spring(duration: 0.35)) { flipped.toggle() }
    }

    private func rate(_ rating: ReviewRating) {
        LessonReview.rate(cards[index], rating)
        session.course.updatedAt = Date()
        try? modelContext.save()
        if index + 1 < cards.count {
            withAnimation(.spring(duration: 0.35)) {
                index += 1
                flipped = false
            }
        } else {
            withAnimation(.spring(duration: 0.4)) { finished = true }
        }
    }

    private var finishedState: some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: .happy, size: 170)
            Text("\(cards.count) / \(cards.count)")
                .font(MicaboFont.number(56))
                .foregroundStyle(tone.ink)
            Text(L10n.t("lesson.cards.done", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("lesson.circle.next", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle())
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            MikaMascot(mood: .sleep, size: 150)
            Text(L10n.t("lesson.cards.empty", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("lesson.circle.next", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle())
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
    }
}

/// Une flashcard, recto puis verso. Une question de quiz ratée garde ses propositions ; le
/// verso montre la bonne et l'explication.
struct FlashcardFace: View {
    let card: Flashcard
    let flipped: Bool
    let tone: LessonTone

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(flipped
                ? L10n.t("lesson.cards.answer", locale: .resolved())
                : L10n.t("lesson.cards.question", locale: .resolved()))
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(tone.ink)

            Text(card.front)
                .font(MicaboFont.ui(flipped ? 18 : 24, weight: .heavy))
                .foregroundStyle(flipped ? MicaboColor.inkSecondary : MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            if card.kind == .choice, card.choices.count > 1, !flipped {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(card.choices.enumerated()), id: \.offset) { _, choice in
                        Text("• \(choice)")
                            .font(MicaboFont.ui(17, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                    }
                }
            }

            if flipped {
                if card.kind == .choice, card.choices.indices.contains(card.correctChoiceIndex) {
                    Text(card.choices[card.correctChoiceIndex])
                        .font(MicaboFont.ui(24, weight: .heavy))
                        .foregroundStyle(MicaboColor.correctInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                KeywordText(card.back)
                    .font(MicaboFont.ui(card.kind == .choice ? 17 : 22, weight: card.kind == .choice ? .medium : .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(flipped ? tone.vivid : MicaboColor.stroke, lineWidth: 2)
        )
        .micaboElevation(.card)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(L10n.t("lesson.cards.flip", locale: .resolved())))
    }
}

/// **L'entrée Flashcards de la navbar** : « X à réviser aujourd'hui », et la révision.
struct LessonCardsHub: View {
    let session: LessonSession

    @Environment(\.dismiss) private var dismiss
    @State private var running: [Flashcard]?

    var body: some View {
        Group {
            if let running {
                LessonCardsRun(session: session, cards: running, onClose: { dismiss() })
            } else {
                overview
            }
        }
    }

    private var overview: some View {
        let due = session.dueCards()
        return VStack(spacing: 18) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                Spacer()
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)

            Spacer()
            MicaboIconView(icon: .cards, size: 110)
            Text(due.isEmpty
                ? L10n.t("lesson.cards.nothingDue", locale: .resolved())
                : L10n.t("lesson.cards.dueToday", locale: .resolved(), vars: ["count": String(due.count)]))
                .font(MicaboFont.title)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Text(L10n.t("lesson.cards.total", locale: .resolved(), vars: [
                "count": String(session.course.cards.count),
                "learned": String(session.course.learnedCardCount()),
            ]))
            .font(MicaboFont.ui(16, weight: .medium))
            .foregroundStyle(MicaboColor.inkSecondary)
            Spacer()
            Button(due.isEmpty
                ? L10n.t("lesson.cards.reviewAnyway", locale: .resolved())
                : L10n.t("lesson.cards.review", locale: .resolved())) {
                withAnimation { running = due.isEmpty ? session.circleCards() : Array(due.prefix(30)) }
            }
            .buttonStyle(LessonPrimaryButtonStyle())
            .disabled(session.course.cards.isEmpty)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 8)
        .background(MicaboColor.canvas.ignoresSafeArea())
    }
}
