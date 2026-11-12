import SwiftData
import SwiftUI
import UIKit

/// Ce que les boutons de la solution déclenchent.
struct SolverSolutionActions {
    var solve: () -> Void = {}
    var next: () -> Void = {}
    var revealAll: () -> Void = {}
    var help: (Int) -> Void = { _ in }
    var editStatement: () -> Void = {}
    var pickSubject: (SolverSubject) -> Void = { _ in }
    var unlock: () -> Void = {}
    var startPractice: () -> Void = {}
    var check: (String) -> Void = { _ in }
    var showPracticeAnswer: () -> Void = {}
    var anotherPractice: () -> Void = {}
    var askMika: () -> Void = {}
}

// MARK: - Le contenu

/// **La solution, façon prof particulier** : l'énoncé reconnu (qu'on corrige), puis les
/// étapes en cartes numérotées qui se dévoilent une à une, la réponse encadrée, et
/// l'entraînement. Sans défilement ni barre : `SolverSolutionView` les ajoute, et les rendus
/// dessinent ceci tel quel.
struct SolverSolutionContent: View {
    let session: SolverSession
    var isPro: Bool
    var actions: SolverSolutionActions
    @State private var attempt = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statementCard
            switch session.phase {
            case .review:
                reviewCard
            case .solving:
                solvingCard
            case .locked:
                lockedTeaser
            case .failed(let message):
                failureCard(message, retry: actions.solve)
            case .solved:
                solved
            }
            if let notice = session.notice {
                Text(notice)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.wrongInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: L'énoncé

    private var statementCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MicaboEyebrow(text: solveText("statement.title"))
                Spacer(minLength: 8)
                SolverSubjectMenu(subject: session.exercise.subject, onPick: actions.pickSubject)
                    .layoutPriority(1)
            }
            HStack(alignment: .top, spacing: 12) {
                if let data = session.exercise.thumbnail, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
                        .accessibilityHidden(true)
                }
                SolverRichText(source: session.exercise.statement, size: 16)
            }
            Button(action: actions.editStatement) {
                Label(solveText("statement.edit"), systemImage: "pencil")
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .disabled(session.phase == .solving)
        }
        .padding(16)
        .solverCard()
    }

    // MARK: Avant la solution

    private var reviewCard: some View {
        SolverMikaCard(mood: .wave) {
            VStack(alignment: .leading, spacing: 10) {
                Text(solveText("review.lead"))
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !isPro, session.quota.hasFreeQuestion {
                    Label(solveText("review.free"), systemImage: "gift.fill")
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .foregroundStyle(MicaboColor.accentInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MicaboColor.accentWash, in: Capsule())
                }
            }
        }
    }

    private var solvingCard: some View {
        VStack(spacing: 12) {
            SolverMikaCard(mood: .think) {
                HStack(spacing: 10) {
                    ProgressView().tint(MicaboColor.accent)
                    Text(solveText("solving"))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ForEach(1...3, id: \.self) { index in
                SolverGhostStep(number: index)
            }
        }
    }

    /// **La porte atteinte** : l'énoncé reste lu, au-dessus ; les étapes attendent Pro.
    private var lockedTeaser: some View {
        VStack(spacing: 14) {
            ZStack {
                VStack(spacing: 10) {
                    ForEach(1...3, id: \.self) { index in
                        SolverGhostStep(number: index)
                    }
                }
                .blur(radius: 2.5)
                .opacity(0.7)
                .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(MicaboBrand.blue, in: Circle())
                    Text(solveText("locked.title"))
                        .font(MicaboFont.ui(19, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(solveText("locked.body"))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .solverCard()
                .padding(.horizontal, 12)
            }
        }
    }

    private func failureCard(_ message: String, retry: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message)
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.wrongInk)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: retry) {
                Label(L10n.t("lesson.path.retry", locale: .resolved()), systemImage: "arrow.clockwise")
            }
            .buttonStyle(MicaboSecondaryButtonStyle())
        }
        .padding(16)
        .solverCard()
    }

    // MARK: La solution

    @ViewBuilder
    private var solved: some View {
        if let solution = session.solution {
            HStack(alignment: .firstTextBaseline) {
                Text(solveText("steps.title"))
                    .font(MicaboFont.sectionTitle)
                    .foregroundStyle(MicaboColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Text(solveText("steps.progress", ["n": "\(session.revealed)", "total": "\(solution.steps.count)"]))
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .monospacedDigit()
            }
            ForEach(0..<session.revealed, id: \.self) { index in
                SolverStepCard(
                    number: index + 1,
                    step: solution.steps[index],
                    help: session.help[index],
                    helping: session.helping.contains(index),
                    failure: session.helpFailures[index],
                    onHelp: { actions.help(index) }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if session.hasMoreSteps {
                Button(action: actions.next) {
                    SolverGhostStep(number: session.revealed + 1, label: solveText("steps.tapToReveal"))
                }
                .buttonStyle(MicaboPressableButtonStyle())
                Button(action: actions.revealAll) {
                    Text(solveText("steps.showAll"))
                        .font(MicaboFont.ui(14, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            } else {
                if let answer = solution.answer {
                    SolverAnswerBox(answer: answer)
                }
                practiceSection
                askMikaRow
            }
        } else if let plain = session.plainReply {
            VStack(alignment: .leading, spacing: 10) {
                MicaboEyebrow(text: solveText("plain.title"))
                SolverRichText(source: plain, size: 16)
            }
            .padding(16)
            .solverCard()
            practiceSection
            askMikaRow
        }
    }

    // MARK: L'entraînement

    @ViewBuilder
    private var practiceSection: some View {
        if session.practiceLoading {
            SolverMikaCard(mood: .write) {
                HStack(spacing: 10) {
                    ProgressView().tint(MicaboColor.accent)
                    Text(solveText("practice.loading"))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if let practice = session.practice {
            practiceCard(practice)
        } else {
            SolverMikaCard(mood: .idle) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(solveText("practice.title"))
                        .font(MicaboFont.ui(18, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(solveText("practice.lead"))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: actions.startPractice) {
                        Label(solveText("practice.start"), systemImage: "sparkles")
                            .font(MicaboFont.ui(15, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .background(MicaboBrand.blue, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                }
            }
        }
        if let failure = session.practiceFailure {
            Text(failure)
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.wrongInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func practiceCard(_ practice: SolverPractice) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "pencil.and.list.clipboard")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
                MicaboEyebrow(text: solveText("practice.cardTitle"))
            }
            SolverRichText(source: practice.exercise, size: 16)
            if let verdict = practice.verdict {
                verdictBanner(verdict)
            }
            if let feedback = practice.feedback {
                SolverMikaNote {
                    SolverRichText(source: feedback, size: 15)
                }
                if practice.showsAnswer, let expected = practice.expected {
                    SolverAnswerBox(answer: expected)
                }
                HStack(spacing: 10) {
                    if practice.verdict != .right, practice.expected != nil, !practice.showsAnswer {
                        Button(action: actions.showPracticeAnswer) {
                            Text(solveText("practice.showAnswer"))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .buttonStyle(MicaboSecondaryButtonStyle())
                    }
                    Button(action: actions.anotherPractice) {
                        Text(solveText("practice.another"))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                }
            } else {
                HStack(spacing: 10) {
                    TextField(solveText("practice.placeholder"), text: $attempt, axis: .vertical)
                        .font(MicaboFont.ui(16, weight: .medium))
                        .lineLimit(1...4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                        .submitLabel(.done)
                    Button {
                        actions.check(attempt)
                    } label: {
                        Group {
                            if session.checking {
                                ProgressView().tint(.white)
                            } else {
                                Text(solveText("practice.check"))
                                    .font(MicaboFont.ui(15, weight: .heavy))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .background(attempt.nilIfBlank == nil ? MicaboColor.inkTertiary : MicaboBrand.blue, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                    .disabled(attempt.nilIfBlank == nil || session.checking)
                }
            }
        }
        .padding(16)
        .solverCard()
    }

    private func verdictBanner(_ verdict: SolverVerdict) -> some View {
        let right = verdict == .right
        return Label(solveText(right ? "practice.right" : "practice.wrong"), systemImage: right ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(MicaboFont.ui(16, weight: .heavy))
            .foregroundStyle(right ? MicaboColor.correctInk : MicaboColor.wrongInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(right ? MicaboColor.correctSoft : MicaboColor.wrongSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
    }

    // MARK: Demander à Mika

    private var askMikaRow: some View {
        Button(action: actions.askMika) {
            HStack(spacing: 12) {
                SolverMikaAvatar(size: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(solveText("askMika.title"))
                        .font(MicaboFont.ui(16, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                    Text(solveText("askMika.subtitle", ["subject": session.exercise.subject.label]))
                        .font(MicaboFont.ui(14, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(14)
            .solverCard()
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}

// MARK: - Les pièces

/// Une étape dévoilée : son numéro, son titre, son explication, et « Je ne comprends pas
/// cette étape ».
struct SolverStepCard: View {
    let number: Int
    let step: SolverStep
    var help: String?
    var helping = false
    var failure: String?
    var onHelp: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(MicaboBrand.blue, in: Circle())
                    .accessibilityLabel(Text(solveText("steps.number", ["n": "\(number)"])))
                VStack(alignment: .leading, spacing: 8) {
                    if !step.title.isEmpty {
                        SheetInlineText(
                            markup: step.title,
                            style: SheetTextStyle(size: 17, weight: .bold, color: MicaboColor.ink, lineSpacing: 2)
                        )
                        .accessibilityAddTraits(.isHeader)
                    }
                    SolverRichText(source: step.body, size: 16, color: MicaboColor.inkBody)
                }
                .padding(.top, step.title.isEmpty ? 4 : 3)
            }
            if helping {
                SolverMikaNote {
                    HStack(spacing: 8) {
                        ProgressView().tint(MicaboColor.accent)
                        Text(solveText("help.loading"))
                            .font(MicaboFont.ui(14, weight: .semibold))
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if let help {
                SolverMikaNote {
                    SolverRichText(source: help, size: 15)
                }
            } else {
                if let failure {
                    Text(failure)
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.wrongInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(action: onHelp) {
                    Label(solveText("help.button"), systemImage: "questionmark.bubble")
                        .font(MicaboFont.ui(14, weight: .bold))
                        .foregroundStyle(MicaboColor.accentInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 6)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solverCard()
    }
}

/// L'étape suivante, pas encore dévoilée : son numéro, et des lignes grises.
struct SolverGhostStep: View {
    let number: Int
    var label: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("\(number)")
                .font(MicaboFont.ui(15, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(width: 30, height: 30)
                .background(MicaboColor.surfaceSunken, in: Circle())
            VStack(alignment: .leading, spacing: 8) {
                if let label {
                    Text(label)
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Capsule().fill(MicaboColor.surfaceSunken).frame(width: 150, height: 10)
                }
                Capsule().fill(MicaboColor.surfaceMuted).frame(height: 8)
                Capsule().fill(MicaboColor.surfaceMuted).frame(width: 190, height: 8)
            }
            if label != nil {
                Image(systemName: "eye.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface.opacity(0.6), in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }
}

/// **La réponse finale, encadrée.**
struct SolverAnswerBox: View {
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(solveText("answer"), systemImage: "checkmark.seal.fill")
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.accentInk)
                .textCase(.uppercase)
            SolverRichText(source: answer, size: 18, color: MicaboColor.ink)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous).strokeBorder(MicaboBrand.blue, lineWidth: 2))
        .accessibilityElement(children: .combine)
    }
}

/// La barre du bas : l'action principale du moment, une seule.
struct SolverSolutionBar: View {
    let session: SolverSession
    var actions: SolverSolutionActions

    var body: some View {
        switch session.phase {
        case .review:
            button(solveText("solve"), icon: "wand.and.stars", action: actions.solve)
        case .locked:
            button(solveText("locked.cta"), icon: "lock.open.fill", action: actions.unlock)
        case .solved where session.hasMoreSteps:
            button(solveText("steps.next", ["n": "\(session.revealed + 1)", "total": "\(session.steps.count)"]), icon: "arrow.down", action: actions.next)
        default:
            EmptyView()
        }
    }

    private func button(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .buttonStyle(MicaboPrimaryButtonStyle())
    }
}

// MARK: - L'écran

struct SolverSolutionView: View {
    @Bindable var session: SolverSession
    var onBack: () -> Void
    var onAskMika: (SolverSubject) -> Void

    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(\.modelContext) private var context
    @State private var editing = false

    private var isPro: Bool { pro?.isPro ?? false }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MicaboScreenHeader(
                        title: solveText("solution.title"),
                        eyebrow: session.exercise.subject.label,
                        back: .back(onBack)
                    )
                    SolverSolutionContent(session: session, isPro: isPro, actions: actions)
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .animation(LearnMotion.standard, value: session.revealed)
                .animation(LearnMotion.standard, value: session.phase)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: session.revealed) { _, _ in
                withAnimation(LearnMotion.standard) { proxy.scrollTo("end", anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showsBar {
                MicaboBottomBar {
                    SolverSolutionBar(session: session, actions: actions)
                }
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $editing) {
            SolverEditSheet(text: session.exercise.statement) { text in
                session.setStatement(text)
            }
        }
        .micaboPaywall($session.paywall, onSubscribed: {
            Task { await session.unlocked(service: aiService, context: context) }
        })
        .onChange(of: isPro) { _, nowPro in
            guard nowPro, session.phase == .locked else { return }
            Task { await session.unlocked(service: aiService, context: context) }
        }
    }

    private var showsBar: Bool {
        switch session.phase {
        case .review, .locked: true
        case .solved: session.hasMoreSteps
        default: false
        }
    }

    private var actions: SolverSolutionActions {
        SolverSolutionActions(
            solve: { Task { await session.solve(isPro: isPro, service: aiService, context: context) } },
            next: { withAnimation(LearnMotion.standard) { session.revealNext() } },
            revealAll: { withAnimation(LearnMotion.standard) { session.revealAll() } },
            help: { index in Task { await session.explain(step: index, isPro: isPro, service: aiService) } },
            editStatement: { editing = true },
            pickSubject: { session.setSubject($0) },
            unlock: { session.paywall = .mika },
            startPractice: { Task { await session.startPractice(isPro: isPro, service: aiService) } },
            check: { answer in Task { await session.check(answer: answer, isPro: isPro, service: aiService) } },
            showPracticeAnswer: { session.showPracticeAnswer() },
            anotherPractice: {
                session.clearPractice()
                Task { await session.startPractice(isPro: isPro, service: aiService) }
            },
            askMika: { onAskMika(session.exercise.subject) }
        )
    }
}

/// **Corriger l'énoncé reconnu**, quand la lecture s'est trompée sur un chiffre.
struct SolverEditSheet: View {
    @State var text: String
    var onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(solveText("statement.editTitle"))
                    .font(MicaboFont.pageTitle)
                    .foregroundStyle(MicaboColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                MicaboCircleButton(systemImage: "xmark", size: 34, accessibilityTitle: L10n.t("lesson.circle.close", locale: .resolved())) { dismiss() }
            }
            Text(solveText("statement.editHint"))
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $text)
                .font(MicaboFont.ui(17, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .scrollContentBackground(.hidden)
                .focused($focused)
                .padding(10)
                .frame(minHeight: 180)
                .solverCard(radius: 18)
            Button {
                onSave(text)
                dismiss()
            } label: {
                Text(solveText("statement.save"))
            }
            .buttonStyle(MicaboPrimaryButtonStyle())
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Spacer(minLength: 0)
        }
        .padding(MicaboSpacing.screen)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }
}
