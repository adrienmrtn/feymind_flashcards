import SwiftData
import SwiftUI

/// **Un quiz** : une question par écran, quelle que soit sa forme, la barre qui se remplit, et
/// la réponse dans un panneau qui monte du bas, vert ou rouge, avec sa phrase d'explication.
/// Une série de bonnes réponses s'affiche ; à la fin, le score se remplit en cercle et Mika
/// réagit. Sert aux Checkpoints, au Quiz final, au quiz de la barre du bas et à l'examen blanc.
///
/// Il n'y a pas de score minimum : une étape se coche quand toutes les questions sont
/// répondues. Chaque question ratée devient une flashcard à revoir demain.
struct LessonQuizView: View {
    let session: LessonSession
    let title: String
    /// L'étape que ce quiz coche ; `nil` pour le quiz de la barre du bas et l'examen blanc.
    let circleID: String?
    let onClose: () -> Void
    var onDone: (() -> Void)?
    /// À la fin : « Générer de nouvelles questions », quand l'entraînement le propose.
    var onMore: (() -> Void)?

    @Environment(\.modelContext) private var modelContext

    /// Le tirage, figé à l'ouverture : une question ratée change l'ordre du prochain tirage,
    /// pas celui du quiz en cours.
    @State private var questions: [QuizQuestion]
    @State private var index = 0
    @State private var answer: QuizAnswer?
    @State private var right = 0
    @State private var streak = 0
    @State private var finished = false
    /// La graine du mélange des propositions : neuve à chaque ouverture.
    @State private var seed = UInt64.random(in: 1...UInt64.max)

    init(
        session: LessonSession,
        questions: [QuizQuestion],
        title: String,
        circleID: String?,
        onClose: @escaping () -> Void,
        onDone: (() -> Void)? = nil,
        onMore: (() -> Void)? = nil
    ) {
        self.session = session
        self.title = title
        self.circleID = circleID
        self.onClose = onClose
        self.onDone = onDone
        self.onMore = onMore
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
                QuizScoreView(
                    right: right,
                    total: questions.count,
                    tone: tone,
                    doneTitle: onDone == nil
                        ? L10n.t("lesson.quiz.finish", locale: .resolved())
                        : L10n.t("ios.pol.learn.nextStep", locale: .resolved()),
                    onDone: { if let onDone { onDone() } else { onClose() } },
                    onMore: onMore
                )
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if streak >= 3 {
                            StreakBadge(count: streak, tone: tone)
                                .transition(.scale.combined(with: .opacity))
                        }
                        QuestionCard(
                            question: questions[index],
                            tone: tone,
                            answered: answer,
                            shuffleSeed: seed &+ UInt64(index),
                            showsFeedback: false
                        ) { result in
                            record(result)
                        }
                    }
                    .id(index)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, 16)
                    .padding(.bottom, 200)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                }
                .scrollIndicators(.hidden)
            }
        }
        .overlay(alignment: .bottom) {
            if let answer, !finished, questions.indices.contains(index) {
                AnswerPanel(question: questions[index], right: answer.right, isLast: index + 1 == questions.count, action: next)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(LearnMotion.standard, value: answer)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .lessonClock(session, activity: circleID == nil ? .quiz : nil)
    }

    private func record(_ result: QuizAnswer) {
        // Deux appuis dans la même image passent tous deux la garde de la carte, qui relit
        // une valeur figée au rendu : la seconde réponse compterait deux fois l'XP et le score.
        guard answer == nil, !finished, questions.indices.contains(index) else { return }
        answer = result
        let question = questions[index]
        if result.right {
            right += 1
            streak += 1
            Haptics.success()
        } else {
            streak = 0
            Haptics.warning()
        }
        session.answered(question, right: result.right, in: modelContext)
    }

    private func next() {
        guard answer != nil, !finished else { return }
        if index + 1 < questions.count {
            withAnimation(LearnMotion.standard) {
                index += 1
                answer = nil
            }
        } else {
            if let circleID {
                session.recordQuiz(circleID, right: right, total: questions.count, in: modelContext)
            }
            withAnimation(LearnMotion.gentle) { finished = true }
        }
    }

    private var empty: some View {
        VStack(spacing: 16) {
            Spacer()
            MikaMascot(mood: .look, size: 120)
            Text(L10n.t("lesson.quiz.empty", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("ios.pol.learn.nextStep", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
    }
}

/// **La réponse, dans un panneau qui monte du bas** : vert et « Bien joué ! », ou rouge et
/// « Pas tout à fait », la phrase qui explique, et « Continuer » dans la même couleur.
struct AnswerPanel: View {
    let question: QuizQuestion
    let right: Bool
    let isLast: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: right ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(right ? MicaboColor.correct : MicaboColor.wrong)
                    .symbolEffect(.bounce, value: right)
                Text(right
                    ? XPCheer.word(for: question.id)
                    : L10n.t("lesson.question.wrong", locale: .resolved()))
                    .font(MicaboFont.ui(21, weight: .heavy))
                    .foregroundStyle(right ? MicaboColor.correctInk : MicaboColor.wrongInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // L'XP de la réponse (`docs/refonte-knowunity.md` § 6), à côté du verdict.
                XPBadge(points: right ? XPRules.correctAnswer : XPRules.wrongAnswer, tint: right ? MicaboColor.correctInk : MicaboColor.wrongInk)
                Spacer(minLength: 0)
                MikaAvatar(size: 36)
            }
            if !right, question.kind == .order || question.kind == .match || question.kind == .gap {
                KeywordText(question.answerText, size: 16, weight: .bold, tintsKeywords: false)
                    .font(MicaboFont.ui(16, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !question.why.isEmpty {
                KeywordText(question.why, size: 16, weight: .medium)
                    .font(MicaboFont.ui(16, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(isLast
                ? L10n.t("lesson.quiz.seeScore", locale: .resolved())
                : L10n.t("lesson.quiz.continue", locale: .resolved()), action: action)
                .buttonStyle(AnswerButtonStyle(color: right ? MicaboColor.correct : MicaboColor.wrong))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            (right ? MicaboColor.correctSoft : MicaboColor.wrongSoft)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    Rectangle().fill((right ? MicaboColor.correct : MicaboColor.wrong).opacity(0.35)).frame(height: 2)
                }
        }
    }
}

/// Le bouton du panneau de réponse : plein, dans la couleur de la réponse, avec son relief.
struct AnswerButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.ui(18, weight: .heavy))
            .foregroundStyle(MicaboColor.onInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color.opacity(0.6))
                    .offset(y: configuration.isPressed ? 0 : 4)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(LearnMotion.quick, value: configuration.isPressed)
    }
}

/// « Série de 4 » : des bonnes réponses d'affilée.
struct StreakBadge: View {
    let count: Int
    let tone: LessonTone

    var body: some View {
        Label(L10n.t("lesson.quiz.streak", locale: .resolved(), vars: ["n": String(count)]), systemImage: "flame.fill")
            .font(MicaboFont.ui(14, weight: .heavy))
            .foregroundStyle(LessonTone.yellow.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(LessonTone.yellow.pale, in: Capsule())
            .contentTransition(.numericText(value: Double(count)))
            .animation(LearnMotion.standard, value: count)
    }
}

/// **Le score** : un anneau qui se remplit jusqu'au résultat, le compte qui monte, Mika qui
/// réagit, et ce qui vient ensuite.
struct QuizScoreView: View {
    let right: Int
    let total: Int
    let tone: LessonTone
    let doneTitle: String
    let onDone: () -> Void
    var onMore: (() -> Void)?

    @State private var shown: Double = 0
    @Environment(\.homeStill) private var still

    private var ratio: Double { Double(right) / Double(max(1, total)) }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: ratio >= 0.8 ? .celebrate : ratio >= 0.5 ? .happy : .think, size: 128)
            ZStack {
                Circle().stroke(MicaboColor.track, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: shown)
                    .stroke(tone.vivid, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(Int((shown * Double(total)).rounded())) / \(total)")
                        .font(MicaboFont.number(40))
                        .foregroundStyle(tone.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: shown))
                    Text(L10n.percent(Int((shown * 100).rounded()), locale: .resolved()))
                        .font(MicaboFont.ui(16, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: shown))
                }
            }
            .frame(width: 170, height: 170)
            Text(ratio >= 0.8
                ? L10n.t("lesson.quiz.great", locale: .resolved())
                : ratio >= 0.5
                ? L10n.t("lesson.quiz.good", locale: .resolved())
                : L10n.t("lesson.quiz.keepGoing", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if right < total {
                Text(L10n.t("lesson.quiz.missedBecomeCards", locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(spacing: 12) {
                Button(doneTitle, action: onDone)
                    .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
                if let onMore {
                    Button(action: onMore) {
                        Label(L10n.t("lesson.practice.more", locale: .resolved()), systemImage: "sparkles")
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
        .onAppear {
            // Avec « Réduire les animations » (ou dans un rendu), le score est là d'emblée.
            if still || LearnMotion.reduceMotion {
                shown = ratio
            } else {
                withAnimation(LearnMotion.gentle(delay: 0.2)) { shown = ratio }
            }
            if ratio >= 0.8 { Haptics.burst(count: 3, over: 0.4) }
        }
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
    /// Les cartes notées « Encore » : elles reviennent dans la séance de demain.
    @State private var again = 0

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
                ZStack {
                    FlashcardFace(card: cards[index], flipped: false, tone: tone)
                        .opacity(flipped ? 0 : 1)
                    FlashcardFace(card: cards[index], flipped: true, tone: tone)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        .opacity(flipped ? 1 : 0)
                }
                .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
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
                rating(.again, title: L10n.t("lesson.cards.again", locale: .resolved()), ink: MicaboColor.wrongInk, fill: MicaboColor.wrongSoft)
                rating(.good, title: L10n.t("lesson.cards.good", locale: .resolved()), ink: MicaboColor.accentInk, fill: MicaboColor.accentSoft)
                rating(.easy, title: L10n.t("lesson.cards.easy", locale: .resolved()), ink: MicaboColor.correctInk, fill: MicaboColor.correctSoft)
            }
        } else {
            Button(L10n.t("lesson.cards.flip", locale: .resolved()), action: flip)
                .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
    }

    /// **Une note**, teintée de son sens : rouge pâle pour « Encore » (raté), bleu pour
    /// « Bien », vert pour « Facile ». Trois aplats pleins de trois couleurs côte à côte
    /// criaient plus fort que la carte elle-même.
    private func rating(_ rating: ReviewRating, title: String, ink: Color, fill: Color) -> some View {
        Button {
            rate(rating)
        } label: {
            Text(title)
                .font(MicaboFont.ui(17, weight: .heavy))
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(ink.opacity(0.25), lineWidth: 1.5))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
    }

    private func flip() {
        Haptics.light()
        withAnimation(LearnMotion.gentle) { flipped.toggle() }
    }

    private func rate(_ rating: ReviewRating) {
        // Un double appui sur une note notait aussi la carte suivante, sans qu'on l'ait vue.
        guard flipped, !finished, cards.indices.contains(index) else { return }
        LessonReview.rate(cards[index], rating)
        if rating == .again { again += 1 }
        session.course.updatedAt = Date()
        try? modelContext.save()
        if index + 1 < cards.count {
            withAnimation(LearnMotion.standard) {
                index += 1
                flipped = false
            }
        } else {
            withAnimation(LearnMotion.standard) { finished = true }
        }
    }

    private var finishedState: some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: again == 0 ? .celebrate : .happy, size: 128)
            Text("\(cards.count)")
                .font(MicaboFont.number(56))
                .foregroundStyle(tone.ink)
            Text(L10n.t("lesson.cards.done", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            // Ce qu'on retient de la séance : les cartes qui reviennent, ou aucune.
            Text(again == 0
                ? L10n.t("ios.pol.learn.cards.allKnown", locale: .resolved())
                : L10n.t("ios.pol.learn.cards.againCount", locale: .resolved(), vars: ["count": String(again)]))
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("ios.pol.learn.nextStep", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            MikaMascot(mood: .sleep, size: 120)
            Text(L10n.t("lesson.cards.empty", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button(onDone == nil
                ? L10n.t("lesson.quiz.finish", locale: .resolved())
                : L10n.t("ios.pol.learn.nextStep", locale: .resolved())) {
                if let onDone { onDone() } else { onClose() }
            }
            .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
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

            if card.format == .cloze {
                // Une carte à trou : le trou au recto, le mot à sa place au verso.
                KeywordText(flipped
                    ? card.front.replacingOccurrences(of: ClozeGap.marker, with: "**\(card.back)**")
                    : card.front.replacingOccurrences(of: ClozeGap.marker, with: "_____"),
                    size: 24, weight: .heavy)
                    .font(MicaboFont.ui(24, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                KeywordText(card.front, size: flipped ? 18 : 24, weight: .heavy)
                    .font(MicaboFont.ui(flipped ? 18 : 24, weight: .heavy))
                    .foregroundStyle(flipped ? MicaboColor.inkSecondary : MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if card.kind == .choice, card.choices.count > 1, !flipped {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(card.choices.enumerated()), id: \.offset) { _, choice in
                        KeywordText("• \(choice)", size: 17, weight: .medium)
                            .font(MicaboFont.ui(17, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                    }
                }
            }

            if flipped {
                if card.kind == .choice, card.choices.indices.contains(card.correctChoiceIndex) {
                    KeywordText(card.choices[card.correctChoiceIndex], size: 24, weight: .heavy, tintsKeywords: false)
                        .font(MicaboFont.ui(24, weight: .heavy))
                        .foregroundStyle(MicaboColor.correctInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if card.format != .cloze {
                    KeywordText(card.back, size: card.kind == .choice ? 17 : 22, weight: card.kind == .choice ? .medium : .bold)
                        .font(MicaboFont.ui(card.kind == .choice ? 17 : 22, weight: card.kind == .choice ? .medium : .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
