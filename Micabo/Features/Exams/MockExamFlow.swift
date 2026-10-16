import Combine
import SwiftData
import SwiftUI

/// D'où part un examen blanc : d'un examen déclaré (ses leçons sont cochées), ou de rien.
struct MockExamStart: Identifiable {
    let id = UUID()
    var exam: Exam?
}

/// **Un examen blanc, du début à la fin** : on choisit les leçons et la durée, Mika écrit la
/// copie, on compose contre la montre sans savoir si l'on a juste, puis on rend : la note dans
/// le barème du pays, leçon par leçon, et le corrigé de chaque question.
struct MockExamFlow: View {
    let start: MockExamStart
    let lessons: [Course]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LessonBuilder.self) private var builder
    @Environment(ProAccess.self) private var pro: ProAccess?

    private enum Phase {
        case setup
        case writing
        case failed(String)
        case run(ExamPaper)
        case result(ExamPaper, [String: QuizAnswer], ExamPaperResult)
    }

    @State private var phase: Phase = .setup
    @State private var selected: Set<UUID> = []
    @State private var minutes = 30
    @State private var paywall: PaywallTrigger?
    @State private var loaded = false

    static let durations = [15, 30, 45, 60]

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            switch phase {
            case .setup:
                setup
                    .transition(.opacity)
            case .writing:
                writing
                    .transition(.opacity)
            case .failed(let message):
                failed(message)
                    .transition(.opacity)
            case .run(let paper):
                MockExamRunView(paper: paper, tone: tone, onQuit: { dismiss() }) { answers, seconds in
                    let result = paper.result(answers: answers, seconds: seconds)
                    ExamHistory.record(result)
                    withAnimation(.spring(duration: 0.5)) { phase = .result(paper, answers, result) }
                }
                .transition(.move(edge: .trailing))
            case .result(let paper, let answers, let result):
                MockExamResultView(paper: paper, answers: answers, result: result, tone: tone, lessons: lessons) { dismiss() }
                    .transition(.move(edge: .trailing))
            }
        }
        .micaboPaywall($paywall)
        .onAppear(perform: load)
    }

    private var tone: LessonTone {
        lessons.first { selected.contains($0.id) }?.tone ?? .blue
    }

    private var title: String {
        start.exam?.name.nilIfBlank ?? L10n.t("lesson.exam.mockTitle", locale: .resolved())
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        let wanted = Set(start.exam?.courseIDs ?? [])
        let preset = lessons.filter { wanted.contains($0.id) }.map(\.id)
        selected = Set(preset.isEmpty ? lessons.prefix(1).map(\.id) : preset)
    }

    // MARK: Les réglages

    private var setup: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title)
                                .font(MicaboFont.display(32))
                                .foregroundStyle(MicaboColor.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            Text(L10n.t("lesson.exam.setupBody", locale: .resolved()))
                                .font(MicaboFont.ui(16, weight: .medium))
                                .foregroundStyle(MicaboColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        MikaMascot(mood: .think, size: 84)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("lesson.exam.duration", locale: .resolved()))
                            .font(MicaboFont.ui(15, weight: .heavy))
                            .foregroundStyle(MicaboColor.inkSecondary)
                        HStack(spacing: 10) {
                            ForEach(Self.durations, id: \.self) { value in
                                let isOn = minutes == value
                                Button {
                                    Haptics.selection()
                                    withAnimation(.spring(duration: 0.3)) { minutes = value }
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(value)")
                                            .font(MicaboFont.number(24))
                                        Text("min")
                                            .font(MicaboFont.ui(13, weight: .bold))
                                    }
                                    .foregroundStyle(isOn ? MicaboColor.accent : MicaboColor.ink)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(isOn ? MicaboColor.accentSoft : MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isOn ? MicaboColor.accent : MicaboColor.stroke, lineWidth: isOn ? 2 : 1.5))
                                    .scaleEffect(isOn ? 1.04 : 1)
                                }
                                .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                            }
                        }
                        Text(L10n.t("lesson.exam.questionCount", locale: .resolved(), vars: ["count": "\(LessonBuilder.examQuestionCount(minutes: minutes))"]))
                            .font(MicaboFont.ui(14, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .contentTransition(.numericText())
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(L10n.t("lesson.exam.lessons", locale: .resolved()))
                            .font(MicaboFont.ui(15, weight: .heavy))
                            .foregroundStyle(MicaboColor.inkSecondary)
                        LessonChecklist(lessons: lessons, selected: $selected)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        rule("timer", "lesson.exam.rule.timer")
                        rule("eye.slash", "lesson.exam.rule.hidden")
                        rule("checkmark.seal", "lesson.exam.rule.grade")
                    }
                    .padding(16)
                    .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 8) {
                Button(action: begin) {
                    Label(L10n.t("lesson.exam.begin", locale: .resolved()), systemImage: "play.fill")
                }
                .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent, enabled: !selected.isEmpty))
                .disabled(selected.isEmpty)
                if pro?.isPro != true, !ExamAllowance.freeMockUsed {
                    Text(L10n.t("lesson.exam.freeOne", locale: .resolved()))
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 12)
        }
    }

    private func rule(_ symbol: String, _ key: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 24)
            Text(L10n.t(key, locale: .resolved()))
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Écrire la copie

    private func begin() {
        let isPro = pro?.isPro == true
        if !isPro && ExamAllowance.freeMockUsed {
            paywall = .practice
            return
        }
        let chosen = lessons.filter { selected.contains($0.id) }
        withAnimation { phase = .writing }
        Task {
            do {
                let paper = try await builder.examPaper(title: title, exam: start.exam, courses: chosen, minutes: minutes, in: modelContext)
                if !isPro { ExamAllowance.freeMockUsed = true }
                guard !paper.items.isEmpty else {
                    withAnimation { phase = .failed(L10n.t("lesson.exam.failed", locale: .resolved())) }
                    return
                }
                Haptics.success()
                withAnimation(.spring(duration: 0.5)) { phase = .run(paper) }
            } catch let error as LessonServiceError where error.opensPaywall {
                ExamAllowance.freeMockUsed = true
                withAnimation { phase = .setup }
                paywall = .practice
            } catch {
                withAnimation {
                    phase = .failed((error as? LocalizedError)?.errorDescription ?? L10n.t("lesson.exam.failed", locale: .resolved()))
                }
            }
        }
    }

    private var writing: some View {
        VStack(spacing: 20) {
            Spacer()
            MikaMascot(mood: .think, size: 170)
            Text(L10n.t("lesson.exam.writing", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Text(L10n.t("lesson.exam.writingSub", locale: .resolved()))
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
            ProgressView()
                .tint(MicaboColor.accent)
                .padding(.top, 6)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: .sad, size: 150)
            Text(message)
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button(L10n.t("lesson.practice.retry", locale: .resolved()), action: begin)
                    .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
                Button(L10n.t("lesson.practice.back", locale: .resolved())) { withAnimation { phase = .setup } }
                    .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Composer

/// **La copie, contre la montre** : une question à la fois, la réponse choisie se surligne
/// sans verdict, on peut revenir en arrière et changer d'avis. À zéro, la copie se rend seule.
struct MockExamRunView: View {
    let paper: ExamPaper
    let tone: LessonTone
    let onQuit: () -> Void
    let onSubmit: ([String: QuizAnswer], Int) -> Void

    @State private var index = 0
    @State private var answers: [String: QuizAnswer] = [:]
    /// Le nombre de remises à zéro de chaque question, pour recréer sa carte.
    @State private var resets: [String: Int] = [:]
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var confirmQuit = false
    @State private var confirmSubmit = false
    @State private var submitted = false
    @State private var direction: Edge = .trailing

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var total: Int { paper.minutes * 60 }
    private var elapsed: Int { min(total, Int(now.timeIntervalSince(startedAt))) }
    private var remaining: Int { max(0, total - elapsed) }
    private var item: ExamPaper.Item { paper.items[index] }
    private var answeredCount: Int { paper.items.filter { answers[$0.id] != nil }.count }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            dots
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L10n.t("lesson.exam.questionOf", locale: .resolved(), vars: ["n": "\(index + 1)", "total": "\(paper.items.count)"]))
                        .font(MicaboFont.ui(14, weight: .heavy))
                        .foregroundStyle(MicaboColor.inkSecondary)
                    if paper.lessons.count > 1, paper.lessons.indices.contains(item.lesson) {
                        Text(paper.lessons[item.lesson].title)
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(tone.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(tone.pale, in: Capsule())
                    }
                    card
                        .id("\(item.id)#\(resets[item.id, default: 0])")
                        .transition(.asymmetric(
                            insertion: .move(edge: direction).combined(with: .opacity),
                            removal: .move(edge: direction == .trailing ? .leading : .trailing).combined(with: .opacity)
                        ))
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onReceive(timer) { value in
            now = value
            // Lu depuis l'instant reçu, pas depuis l'état qu'on vient d'écrire.
            let left = total - Int(value.timeIntervalSince(startedAt))
            if left <= 0, !submitted {
                submit()
            } else if left == 60 {
                Haptics.warning()
            }
        }
        .confirmationDialog(L10n.t("lesson.exam.quitConfirm", locale: .resolved()), isPresented: $confirmQuit, titleVisibility: .visible) {
            Button(L10n.t("lesson.exam.quit", locale: .resolved()), role: .destructive, action: onQuit)
        }
        .confirmationDialog(
            L10n.t("lesson.exam.submitConfirm", locale: .resolved(), vars: ["count": "\(paper.items.count - answeredCount)"]),
            isPresented: $confirmSubmit,
            titleVisibility: .visible
        ) {
            Button(L10n.t("lesson.exam.submit", locale: .resolved()), action: submit)
        }
    }

    // MARK: La barre du haut

    private var topBar: some View {
        HStack(spacing: 12) {
            Button { confirmQuit = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.exam.quit", locale: .resolved())))

            Spacer()

            TimerPill(remaining: remaining, total: total)

            Spacer()

            Text("\(answeredCount)/\(paper.items.count)")
                .font(MicaboFont.number(16))
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(width: 52, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    /// Une pastille par question : pleine quand on a répondu, cerclée pour celle qu'on lit. Un
    /// appui y saute.
    private var dots: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(paper.items.enumerated()), id: \.element.id) { number, entry in
                        let done = answers[entry.id] != nil
                        Button {
                            go(to: number)
                        } label: {
                            Text("\(number + 1)")
                                .font(MicaboFont.ui(12, weight: .heavy))
                                .foregroundStyle(done ? MicaboColor.onInk : MicaboColor.inkSecondary)
                                .frame(width: 28, height: 28)
                                .background(done ? MicaboColor.accent : MicaboColor.surface, in: Circle())
                                .overlay(Circle().strokeBorder(number == index ? MicaboColor.ink : MicaboColor.stroke, lineWidth: number == index ? 2 : 1))
                        }
                        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                        .id(number)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
            }
            .scrollIndicators(.hidden)
            .onChange(of: index) { _, value in
                withAnimation { proxy.scrollTo(value, anchor: .center) }
            }
        }
    }

    // MARK: La question

    @ViewBuilder
    private var card: some View {
        let answer = answers[item.id]
        if let answer, item.question.kind == .order || item.question.kind == .match {
            // Un ordre ou une association ne se redessine pas tel qu'on l'a laissé : on dit
            // qu'il est enregistré, et l'on peut le refaire.
            VStack(alignment: .leading, spacing: 16) {
                Text(item.question.prompt)
                    .font(MicaboFont.ui(22, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                savedBadge(answer)
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                QuestionCard(
                    question: item.question,
                    tone: tone,
                    answered: answer,
                    shuffleSeed: LessonPicking.seed(paper.id.uuidString),
                    showsFeedback: false,
                    reveals: false
                ) { value in
                    Haptics.selection()
                    answers[item.id] = value
                }
                if let answer {
                    savedBadge(answer)
                }
            }
        }
    }

    private func savedBadge(_ answer: QuizAnswer) -> some View {
        HStack(spacing: 10) {
            Label(L10n.t("lesson.exam.saved", locale: .resolved()), systemImage: "checkmark.circle.fill")
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.accent)
            Spacer()
            Button {
                Haptics.selection()
                answers[item.id] = nil
                resets[item.id, default: 0] += 1
            } label: {
                Label(L10n.t("lesson.exam.change", locale: .resolved()), systemImage: "arrow.uturn.backward")
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            .buttonStyle(MicaboPressableButtonStyle())
        }
        .padding(14)
        .background(MicaboColor.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: La barre du bas

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button {
                go(to: index - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 58, height: 58)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .disabled(index == 0)
            .opacity(index == 0 ? 0.4 : 1)
            .accessibilityLabel(Text(L10n.t("lesson.exam.previous", locale: .resolved())))

            if index == paper.items.count - 1 {
                Button {
                    if answeredCount < paper.items.count { confirmSubmit = true } else { submit() }
                } label: {
                    Label(L10n.t("lesson.exam.submit", locale: .resolved()), systemImage: "paperplane.fill")
                }
                .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.correct))
            } else {
                Button {
                    go(to: index + 1)
                } label: {
                    Text(L10n.t(answers[item.id] == nil ? "lesson.exam.skip" : "lesson.exam.next", locale: .resolved()))
                }
                .buttonStyle(LessonPrimaryButtonStyle(tint: answers[item.id] == nil ? MicaboColor.inkSecondary : MicaboColor.accent))
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(MicaboColor.canvas)
    }

    private func go(to target: Int) {
        guard paper.items.indices.contains(target), target != index else { return }
        direction = target > index ? .trailing : .leading
        withAnimation(.spring(duration: 0.4)) { index = target }
    }

    private func submit() {
        guard !submitted else { return }
        submitted = true
        Haptics.success()
        onSubmit(answers, elapsed)
    }
}

/// **Le chrono** : un anneau qui se vide et les minutes qui restent. Il passe à l'orange à
/// cinq minutes, au rouge à la dernière, et bat doucement.
struct TimerPill: View {
    let remaining: Int
    let total: Int

    @State private var beat = false

    private var color: Color {
        if remaining <= 60 { return MicaboColor.wrong }
        if remaining <= 300 { return MicaboColor.cautionVivid }
        return MicaboColor.accent
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle().stroke(color.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: total == 0 ? 0 : CGFloat(remaining) / CGFloat(total))
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
            }
            .frame(width: 22, height: 22)
            Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                .font(MicaboFont.number(19))
                .monospacedDigit()
                .foregroundStyle(remaining <= 60 ? MicaboColor.wrongInk : MicaboColor.ink)
                .contentTransition(.numericText(countsDown: true))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(MicaboColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1.5))
        .scaleEffect(remaining <= 60 && beat ? 1.06 : 1)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { beat = true }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Le résultat

/// **La copie rendue** : la note dans le barème du pays, au centre d'un anneau qui se remplit,
/// la moyenne ou pas, chaque leçon avec sa barre, puis le corrigé. Les erreurs peuvent
/// rejoindre les flashcards de leur leçon.
struct MockExamResultView: View {
    let paper: ExamPaper
    let answers: [String: QuizAnswer]
    let result: ExamPaperResult
    let tone: LessonTone
    let lessons: [Course]
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var fill: Double = 0
    @State private var shown = false
    @State private var cardsAdded = false
    @State private var showsCorrections = false

    private var country: SchoolingCountry { OnboardingPreferences.schoolingCountry }
    private var passes: Bool { ExamGrade.passes(result.fraction) }
    private var missed: [ExamPaper.Item] { paper.items.filter { answers[$0.id]?.right != true } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(MicaboPressableButtonStyle())
                    .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
                }

                ZStack {
                    Circle().stroke(MicaboColor.track, lineWidth: 18)
                    Circle()
                        .trim(from: 0, to: fill)
                        .stroke(
                            AngularGradient(colors: passes ? [MicaboColor.correct, MicaboColor.accent, MicaboColor.correct] : [MicaboColor.cautionVivid, MicaboColor.wrong, MicaboColor.cautionVivid], center: .center),
                            style: StrokeStyle(lineWidth: 18, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(ExamGrade.label(result.fraction, country: country))
                            .font(MicaboFont.number(44))
                            .foregroundStyle(MicaboColor.ink)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                        Text("\(result.correct)/\(result.total)")
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                    .padding(.horizontal, 24)
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)
                }
                .frame(width: 220, height: 220)
                .overlay(alignment: .bottomTrailing) {
                    MikaMascot(mood: passes ? .celebrate : .sad, size: 86)
                        .offset(x: 36, y: 12)
                        .opacity(shown ? 1 : 0)
                }

                VStack(spacing: 6) {
                    Text(L10n.t(passes ? "lesson.exam.passed" : "lesson.exam.notYet", locale: .resolved()))
                        .font(MicaboFont.display(28))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                    Text(L10n.t("lesson.exam.time", locale: .resolved(), vars: [
                        "used": "\(max(1, Int((Double(result.seconds) / 60).rounded(.up))))",
                        "total": "\(result.minutes)"
                    ]))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                }
                .opacity(shown ? 1 : 0)

                if result.lessons.count > 1 {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(L10n.t("lesson.exam.byLesson", locale: .resolved()))
                            .font(MicaboFont.ui(18, weight: .heavy))
                            .foregroundStyle(MicaboColor.ink)
                        ForEach(Array(result.lessons.enumerated()), id: \.offset) { _, score in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(score.title)
                                        .font(MicaboFont.ui(15, weight: .bold))
                                        .foregroundStyle(MicaboColor.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(ExamGrade.label(score.fraction, country: country))
                                        .font(MicaboFont.number(15))
                                        .foregroundStyle(ExamGrade.passes(score.fraction) ? MicaboColor.correctInk : MicaboColor.wrongInk)
                                }
                                GeometryReader { proxy in
                                    Capsule().fill(MicaboColor.track)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(ExamGrade.passes(score.fraction) ? MicaboColor.correct : MicaboColor.cautionVivid)
                                                .frame(width: proxy.size.width * (shown ? score.fraction : 0))
                                        }
                                }
                                .frame(height: 10)
                            }
                        }
                    }
                    .padding(18)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                }

                if !missed.isEmpty {
                    Button(action: addCards) {
                        Label(
                            L10n.t(cardsAdded ? "lesson.exam.cardsAdded" : "lesson.exam.addCards", locale: .resolved(), vars: ["count": "\(missed.count)"]),
                            systemImage: cardsAdded ? "checkmark" : "rectangle.stack.badge.plus"
                        )
                    }
                    .buttonStyle(LessonPrimaryButtonStyle(tint: cardsAdded ? MicaboColor.correct : MicaboColor.accent))
                    .disabled(cardsAdded)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.4)) { showsCorrections.toggle() }
                    } label: {
                        HStack {
                            Text(L10n.t("lesson.exam.corrections", locale: .resolved()))
                                .font(MicaboFont.ui(18, weight: .heavy))
                                .foregroundStyle(MicaboColor.ink)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(MicaboColor.inkSecondary)
                                .rotationEffect(.degrees(showsCorrections ? 180 : 0))
                        }
                    }
                    .buttonStyle(MicaboPressableButtonStyle())

                    if showsCorrections {
                        ForEach(Array(paper.items.enumerated()), id: \.element.id) { number, item in
                            CorrectionRow(number: number + 1, question: item.question, answer: answers[item.id], seed: LessonPicking.seed(paper.id.uuidString))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }

                Button(L10n.t("lesson.exam.done", locale: .resolved()), action: onClose)
                    .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 1.3).delay(0.2)) { fill = result.fraction }
            withAnimation(.spring(duration: 0.6).delay(0.5)) { shown = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                if passes { Haptics.success() } else { Haptics.warning() }
            }
        }
    }

    /// Chaque question ratée devient une flashcard de sa leçon, dans le bon thème, à revoir
    /// dès demain.
    private func addCards() {
        let byID = Dictionary(lessons.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in missed {
            guard paper.lessons.indices.contains(item.lesson), let course = byID[paper.lessons[item.lesson].courseID] else { continue }
            let chapterIDs = paper.lessons[item.lesson].chapterIDs
            let chapterID = chapterIDs.indices.contains(item.theme) ? chapterIDs[item.theme] : nil
            let chapter = course.orderedChapters.first { $0.id == chapterID }
            LessonReview.cardForMissed(item.question, chapter: chapter, course: course, in: modelContext)
        }
        try? modelContext.save()
        CourseLedger.noteChange()
        Haptics.success()
        withAnimation(.spring(duration: 0.4)) { cardsAdded = true }
    }
}

/// Une question corrigée : ce qu'on a répondu, la bonne réponse, et pourquoi.
struct CorrectionRow: View {
    let number: Int
    let question: QuizQuestion
    let answer: QuizAnswer?
    let seed: UInt64

    private var right: Bool { answer?.right == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: answer == nil ? "minus.circle.fill" : right ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(answer == nil ? MicaboColor.inkTertiary : right ? MicaboColor.correct : MicaboColor.wrong)
                Text("\(number). \(question.prompt.replacingOccurrences(of: "**", with: ""))")
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let picked = pickedText, !right {
                Text(L10n.t("lesson.exam.yourAnswer", locale: .resolved(), vars: ["answer": picked]))
                    .font(MicaboFont.ui(14.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.wrongInk)
                    .fixedSize(horizontal: false, vertical: true)
            } else if answer == nil {
                Text(L10n.t("lesson.exam.unanswered", locale: .resolved()))
                    .font(MicaboFont.ui(14.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            Text(L10n.t("lesson.exam.rightAnswer", locale: .resolved(), vars: ["answer": question.answerText]))
                .font(MicaboFont.ui(14.5, weight: .bold))
                .foregroundStyle(MicaboColor.correctInk)
                .fixedSize(horizontal: false, vertical: true)
            if !question.why.isEmpty {
                Text(question.why)
                    .font(MicaboFont.ui(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(right ? MicaboColor.correct.opacity(0.4) : MicaboColor.stroke, lineWidth: 1.5))
    }

    /// Le texte choisi, pour un QCM, un vrai/faux ou une phrase à trou : `picked` est le rang
    /// affiché, qu'on ramène au rang d'origine. Le vrai/faux ne se mélange pas.
    private var pickedText: String? {
        guard let picked = answer?.picked else { return nil }
        if question.kind == .truefalse {
            return question.choices.indices.contains(picked) ? question.choices[picked] : nil
        }
        let order = ChoiceList.order(of: question, seed: seed)
        guard order.indices.contains(picked) else { return nil }
        let original = order[picked]
        return question.choices.indices.contains(original) ? question.choices[original] : nil
    }
}
