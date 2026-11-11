import SwiftData
import SwiftUI

// MARK: - Les fils

/// Ce qu'on montre d'un fil dans la liste des matières.
struct TutorThreadSummary: Identifiable, Equatable {
    var subject: SolverSubject
    var last: String?
    var date: Date?
    var count: Int

    var id: String { subject.rawValue }
}

/// **« Demande à Mika »** : Mika en buste sur le papier de l'app, et un fil par matière.
struct TutorHomeContent: View {
    let threads: [TutorThreadSummary]
    var onOpen: (SolverSubject) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SolverMikaCard(mood: .wave, mikaSize: 124) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(solveText("tutor.heroTitle"))
                        .font(MicaboFont.ui(20, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(solveText("tutor.heroBody"))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(solveText("tutor.subjects"))
                .font(MicaboFont.sectionTitle)
                .foregroundStyle(MicaboColor.ink)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(threads.enumerated()), id: \.element.id) { index, thread in
                    if index > 0 {
                        Rectangle().fill(MicaboColor.hairline).frame(height: 1).padding(.leading, 74)
                    }
                    Button { onOpen(thread.subject) } label: { row(thread) }
                        .buttonStyle(MicaboPressableButtonStyle())
                }
            }
            .solverCard()
        }
    }

    private func row(_ thread: TutorThreadSummary) -> some View {
        HStack(spacing: 14) {
            SolverSubjectTile(subject: thread.subject, size: 46)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(thread.subject.label)
                        .font(MicaboFont.ui(17, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if let date = thread.date {
                        Text(SolverDates.short(date))
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                }
                Text(thread.last.map { KeywordText.plain($0.replacingOccurrences(of: "\n", with: " ")) } ?? solveText("tutor.emptyThread"))
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.forward")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

struct TutorHomeView: View {
    var onBack: () -> Void
    var onOpen: (SolverSubject) -> Void
    @Query(sort: \TutorMessage.createdAt) private var messages: [TutorMessage]

    private var threads: [TutorThreadSummary] {
        SolverSubject.allCases.map { subject in
            let thread = messages.filter { $0.subjectRaw == subject.rawValue }
            return TutorThreadSummary(subject: subject, last: thread.last?.text, date: thread.last?.createdAt, count: thread.count)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MicaboScreenHeader(title: solveText("tutor.title"), eyebrow: nil, back: .back(onBack))
                TutorHomeContent(threads: threads, onOpen: onOpen)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enablesSwipeBack()
    }
}

// MARK: - Un fil

/// Un message tel que le fil le dessine.
struct TutorBubble: Identifiable, Equatable {
    var id: UUID
    var role: MikaTurn.Role
    var text: String
    var exerciseID: UUID?

    init(id: UUID = UUID(), role: MikaTurn.Role, text: String, exerciseID: UUID? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.exerciseID = exerciseID
    }

    init(_ message: TutorMessage) {
        self.init(id: message.id, role: message.role, text: message.text, exerciseID: message.exerciseID)
    }
}

/// **Le fil d'une matière** : les bulles, les exercices scannés qui y sont arrivés, et, tant
/// qu'il est vide, Mika et deux idées de questions.
struct TutorThreadContent: View {
    let subject: SolverSubject
    let bubbles: [TutorBubble]
    var thinking = false
    var failure: String?
    var notice: String?
    var onSuggestion: (String) -> Void = { _ in }
    var onOpenExercise: (UUID) -> Void = { _ in }
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if bubbles.isEmpty {
                empty
            }
            ForEach(bubbles) { bubble in
                view(for: bubble).id(bubble.id)
            }
            if thinking {
                HStack(alignment: .bottom, spacing: 10) {
                    SolverMikaAvatar(size: 34, mood: .think)
                    HStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { _ in
                            Circle().fill(MicaboColor.inkTertiary).frame(width: 7, height: 7)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    Spacer(minLength: 0)
                }
                .id("thinking")
                .accessibilityLabel(Text(solveText("tutor.thinking")))
            }
            if let failure {
                HStack(spacing: 10) {
                    Text(failure)
                        .font(MicaboFont.ui(14, weight: .medium))
                        .foregroundStyle(MicaboColor.wrongInk)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button(L10n.t("lesson.path.retry", locale: .resolved()), action: onRetry)
                        .font(MicaboFont.ui(14, weight: .heavy))
                }
            }
            if let notice {
                Text(notice)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.wrongInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            SolverMikaCard(mood: .wave, mikaSize: 112) {
                Text(solveText("tutor.threadLead", ["subject": subject.label]))
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(["1", "2"], id: \.self) { index in
                let suggestion = solveText("tutor.suggest.\(subject.rawValue)\(index)")
                Button { onSuggestion(suggestion) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MicaboColor.accentInk)
                        Text(suggestion)
                            .font(MicaboFont.ui(15, weight: .semibold))
                            .foregroundStyle(MicaboColor.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .solverCard(radius: 16)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func view(for bubble: TutorBubble) -> some View {
        if bubble.role == .user {
            if let exerciseID = bubble.exerciseID {
                exerciseCard(bubble.text) { onOpenExercise(exerciseID) }
            } else {
                Text(bubble.text)
                    .font(MicaboFont.ui(16, weight: .medium))
                    .foregroundStyle(MicaboColor.onInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 48)
            }
        } else {
            HStack(alignment: .bottom, spacing: 10) {
                SolverMikaAvatar(size: 34)
                VStack(alignment: .leading, spacing: 6) {
                    if bubble.exerciseID != nil {
                        Text(solveText("answer"))
                            .font(MicaboFont.ui(12, weight: .heavy))
                            .foregroundStyle(MicaboColor.accentInk)
                            .textCase(.uppercase)
                    }
                    SolverRichText(source: bubble.text, size: 16)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
                .padding(.trailing, 24)
            }
        }
    }

    private func exerciseCard(_ statement: String, open: @escaping () -> Void) -> some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 13, weight: .bold))
                    Text(solveText("tutor.scanned"))
                        .font(MicaboFont.ui(12, weight: .heavy))
                        .textCase(.uppercase)
                }
                .foregroundStyle(MicaboColor.onInkMuted)
                Text(KeywordText.plain(statement))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.onInk)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 4) {
                    Text(solveText("tutor.openSolution"))
                    Image(systemName: "chevron.forward")
                }
                .font(MicaboFont.ui(14, weight: .heavy))
                .foregroundStyle(MicaboColor.onInk)
            }
            .padding(14)
            .frame(maxWidth: 290, alignment: .leading)
            .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 48)
    }
}

/// Le champ du bas du fil.
struct TutorInputBar: View {
    @Binding var draft: String
    var thinking: Bool
    var focused: FocusState<Bool>.Binding
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(solveText("tutor.placeholder"), text: $draft, axis: .vertical)
                .font(MicaboFont.ui(16, weight: .medium))
                .lineLimit(1...5)
                .focused(focused)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(draft.nilIfBlank == nil || thinking ? MicaboColor.inkTertiary : MicaboBrand.blue, in: Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .disabled(draft.nilIfBlank == nil || thinking)
            .accessibilityLabel(Text(L10n.t("lesson.mika.send", locale: .resolved())))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, 10)
        .background(MicaboColor.canvas)
    }
}

struct TutorThreadView: View {
    let subject: SolverSubject
    var onBack: () -> Void
    var onOpenExercise: (UUID) -> Void

    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(\.modelContext) private var context
    @Query private var messages: [TutorMessage]
    @State private var chat: TutorChat
    @FocusState private var focused: Bool

    init(subject: SolverSubject, onBack: @escaping () -> Void, onOpenExercise: @escaping (UUID) -> Void) {
        self.subject = subject
        self.onBack = onBack
        self.onOpenExercise = onOpenExercise
        let raw = subject.rawValue
        _messages = Query(filter: #Predicate<TutorMessage> { $0.subjectRaw == raw }, sort: \TutorMessage.createdAt)
        _chat = State(initialValue: TutorChat(subject: subject))
    }

    private var isPro: Bool { pro?.isPro ?? false }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                MicaboCircleButton(systemImage: "chevron.backward", size: 38, accessibilityTitle: L10n.t("app.common.back", locale: .resolved()), action: onBack)
                SolverSubjectTile(subject: subject, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(subject.label)
                        .font(MicaboFont.ui(18, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                    Text(solveText("tutor.withMika"))
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
                .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.vertical, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    TutorThreadContent(
                        subject: subject,
                        bubbles: messages.map { TutorBubble($0) },
                        thinking: chat.thinking,
                        failure: chat.failure,
                        notice: chat.notice,
                        onSuggestion: { suggestion in send(suggestion) },
                        onOpenExercise: onOpenExercise,
                        onRetry: { Task { await chat.retry(isPro: isPro, service: aiService, context: context) } }
                    )
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 12)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .scrollDismissesKeyboard(.interactively)
                .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                .onChange(of: messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: chat.thinking) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }

            TutorInputBar(draft: $chat.draft, thinking: chat.thinking, focused: $focused) { send(nil) }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enablesSwipeBack()
        .micaboPaywall($chat.paywall)
    }

    private func send(_ suggestion: String?) {
        Task {
            await chat.send(suggestion, isPro: isPro, service: aiService, context: context)
            if chat.paywall != nil { focused = false }
        }
    }
}
