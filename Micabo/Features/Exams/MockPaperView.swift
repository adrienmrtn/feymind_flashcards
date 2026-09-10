import SwiftUI

/// **La copie.** Toutes les questions posées d'un coup, aucune réponse avant la remise.
///
/// La feuille se lit en entier dès la première seconde. C'est délibéré : gérer son temps sur
/// une épreuve est une compétence, et elle ne se travaille pas si le produit décide de l'ordre
/// et cache ce qui reste. On saute une question, on y revient, on voit ce qui est encore blanc.
///
/// Le chronomètre est affiché mais ne ferme rien de force jusqu'à zéro, où il remet la copie
/// telle quelle - comme un surveillant qui ramasse. Une copie remise ne se quitte pas : elle
/// devient lisible, sur place, avec sa correction.
struct MockPaperView: View {
    let session: MockSessionRecord
    let examName: String
    /// Appelé quand on quitte l'écran : avec la copie fermée si elle a été remise, `nil` si
    /// on est parti avant - elle reste ouverte, on la reprendra.
    var onClose: (MockSessionRecord?) -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(MockExamService.self) private var mocks: MockExamService?

    @State private var answers: [String: MockAnswer] = [:]
    @State private var remaining: Int
    @State private var confirming = false
    @State private var leaving = false
    @State private var saving = false
    @State private var failed = false
    @State private var report: MockSessionRecord?
    @State private var dictation = Dictation()

    private let deadline: Date

    init(session: MockSessionRecord, examName: String, onClose: @escaping (MockSessionRecord?) -> Void) {
        self.session = session
        self.examName = examName
        self.onClose = onClose
        _remaining = State(initialValue: session.minutes * 60)
        deadline = Date().addingTimeInterval(TimeInterval(session.minutes * 60))
    }

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, locale: .resolved(), vars: vars)
    }

    private var questions: [MockQuestion] { session.questions }

    private var answered: Int {
        questions.filter { answers[$0.id]?.isAnswered == true }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if let report {
                    MockReportView(session: report, examName: examName) {
                        onClose(report)
                    }
                } else {
                    paper
                }
            }
        }
        .interactiveDismissDisabled()
    }

    // MARK: - La feuille

    private var paper: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                // Pas de consigne en tête : l'en-tête collé compte déjà les réponses et le
                // temps, et les questions sont là. Une copie ne s'ouvre pas sur un mode d'emploi.
                ForEach(Array(questions.enumerated()), id: \.element.id) { index, question in
                    questionCard(question, position: index + 1)
                }

                handSection
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.md)
            .padding(.bottom, MicaboSpacing.xxl)
            // **La copie ne part pas de travers.** Un `ScrollView` vertical défile quand même
            // en largeur dès qu'un enfant dépasse la largeur proposée - une longue réponse
            // dictée, un intitulé sans espace - et une copie qu'on pousse de côté pendant
            // l'épreuve fait perdre la question qu'on lisait. Borner la pile l'en empêche.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .scrollDismissesKeyboard(.interactively)
        .micaboScreenBackground()
        .safeAreaInset(edge: .top, spacing: 0) { stickyHeader }
        .toolbar(.hidden, for: .navigationBar)
        .task { await runClock() }
        .onDisappear { dictation.stop() }
        .confirmationDialog(t("ios.mock.leaveQ"), isPresented: $leaving, titleVisibility: .visible) {
            Button(t("ios.mock.leave"), role: .destructive) {
                dictation.stop()
                onClose(nil)
            }
            Button(t("ios.mock.stay"), role: .cancel) {}
        }
    }

    /// Le nom, le compte des réponses, le chronomètre. Collé en haut : on gère son temps en
    /// le voyant, pas en remontant le chercher.
    private var stickyHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: MicaboSpacing.sm) {
                Button {
                    leaving = true
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(width: 34, height: 34)
                        .background(MicaboColor.surface, in: Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(t("app.a11y.close"))

                VStack(alignment: .leading, spacing: 1) {
                    Text(examName)
                        .font(MicaboFont.hanken(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                    Text(t("app.mock.answered", ["done": "\(answered)", "total": "\(questions.count)"]))
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .monospacedDigit()
                }

                Spacer(minLength: MicaboSpacing.xs)

                Text(clock)
                    .font(MicaboFont.number(14, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(remaining <= 60 ? MicaboColor.negative : MicaboColor.ink)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(remaining <= 60 ? MicaboColor.negativeSoft : MicaboColor.surfaceMuted, in: Capsule())
                    .accessibilityLabel(clock)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.surfaceMuted)
                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: proxy.size.width * CGFloat(answered) / CGFloat(max(1, questions.count)))
                        .animation(.easeOut(duration: 0.25), value: answered)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
        .padding(.bottom, MicaboSpacing.sm)
        .background(MicaboColor.canvas.opacity(0.96))
    }

    private var clock: String {
        let minutes = remaining / 60
        let seconds = remaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Une question

    @ViewBuilder
    private func questionCard(_ question: MockQuestion, position: Int) -> some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.sm) {
                Text("\(position)")
                    .font(MicaboFont.number(12.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .frame(width: 18, alignment: .leading)
                Text(displayPrompt(question))
                    .font(MicaboFont.hanken(15, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Group {
                switch question {
                case .choice(let id, _, let choices, _, _):
                    choiceField(id: id, choices: choices)
                case .trueFalse(let id, _, _, _):
                    truthField(id: id)
                case .gap(let id, _, _, _, _):
                    gapField(id: id)
                case .feynman(let id, _, _):
                    feynmanField(id: id)
                }
            }
            .padding(.leading, 18 + MicaboSpacing.sm)
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    /// Le trou se voit : sans marque, on lit la phrase sans comprendre ce qu'on doit écrire.
    private func displayPrompt(_ question: MockQuestion) -> String {
        if case .gap = question {
            return question.prompt.replacingOccurrences(of: MockQuestion.gapMark, with: " ______ ")
        }
        return question.prompt
    }

    private func choiceField(id: String, choices: [String]) -> some View {
        VStack(spacing: 6) {
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                let picked = answers[id]?.choiceIndex == index
                Button {
                    Haptics.selection()
                    set(id) { $0.choiceIndex = index }
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: picked ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(picked ? MicaboColor.accent : MicaboColor.strokeStrong)
                        Text(choice)
                            .font(MicaboFont.hanken(14, weight: .regular))
                            .foregroundStyle(MicaboColor.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(picked ? MicaboColor.accentSoft : MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
    }

    private func truthField(id: String) -> some View {
        HStack(spacing: 8) {
            ForEach([true, false], id: \.self) { value in
                let picked = answers[id]?.truth == value
                Button {
                    Haptics.selection()
                    set(id) { $0.truth = value }
                } label: {
                    Text(value ? t("app.mock.true") : t("app.mock.false"))
                        .font(MicaboFont.hanken(14, weight: .semibold))
                        .foregroundStyle(picked ? MicaboColor.onInk : MicaboColor.ink)
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(picked ? MicaboColor.ink : MicaboColor.surfaceMuted, in: Capsule())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityAddTraits(picked ? .isSelected : [])
            }
        }
    }

    private func gapField(id: String) -> some View {
        TextField(t("app.mock.gapPlaceholder"), text: textBinding(id))
            .font(MicaboFont.body)
            .foregroundStyle(MicaboColor.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
    }

    /// Dicter une explication, ou l'écrire. Le texte reste modifiable après la dictée : une
    /// transcription qui écorche un terme ferait perdre des points sur un mot dit juste.
    private func feynmanField(id: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: textBinding(id))
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.ink)
                .scrollContentBackground(.hidden)
                .padding(MicaboSpacing.xs)
                .frame(minHeight: 110, alignment: .topLeading)
                .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if (answers[id]?.text ?? "").isEmpty {
                        Text(session.with_audio ? t("app.mock.spokenPlaceholder") : t("app.mock.typedPlaceholder"))
                            .font(MicaboFont.body)
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .padding(.top, MicaboSpacing.xs + 8)
                            .padding(.leading, MicaboSpacing.xs + 5)
                            .allowsHitTesting(false)
                    }
                }

            if session.with_audio {
                HStack(spacing: MicaboSpacing.sm) {
                    // L'état est celui de **cette** question : `dictation.isListening` seul
                    // mettait les trois questions orales en « Arrêter » dès qu'on dictait sur
                    // l'une d'elles.
                    let listening = dictation.isListening(to: id)

                    Button {
                        dictation.toggle(id: id, current: answers[id]?.text ?? "") { text in
                            set(id) { $0.text = text }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(listening ? MicaboColor.negative : MicaboColor.inkTertiary)
                                .frame(width: 8, height: 8)
                            Text(listening ? t("app.mock.dictateStop") : t("app.mock.dictate"))
                                .font(MicaboFont.hanken(13, weight: .medium))
                        }
                        .foregroundStyle(listening ? MicaboColor.negative : MicaboColor.ink)
                        .padding(.vertical, 7)
                        .padding(.horizontal, 13)
                        .background(listening ? MicaboColor.negativeSoft : MicaboColor.surfaceMuted, in: Capsule())
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                    .disabled(dictation.availability == .denied || dictation.availability == .unavailable)

                    Text(dictation.availability == .denied || dictation.availability == .unavailable
                        ? t("ios.mock.dictateUnavailable")
                        : t("app.mock.dictateHint"))
                        .font(MicaboFont.micro)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - La remise

    private var handSection: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            if confirming {
                VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
                    Text(t("app.mock.handTitle"))
                        .font(MicaboFont.sectionTitle)
                        .foregroundStyle(MicaboColor.ink)
                    Text(answered < questions.count
                        ? t("app.mock.handBlank", ["count": "\(questions.count - answered)"])
                        : t("app.mock.handAll"))
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        Task { await hand() }
                    } label: {
                        HStack(spacing: MicaboSpacing.xs) {
                            if saving {
                                ProgressView().tint(MicaboColor.onInk)
                            }
                            Text(saving ? t("app.mock.grading") : t("app.mock.handConfirm"))
                        }
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())
                    .disabled(saving)

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { confirming = false }
                    } label: {
                        Text(t("app.mock.handBack"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                    .disabled(saving)
                }
                .padding(MicaboSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .micaboGroup()
            } else {
                Button {
                    Haptics.selection()
                    withAnimation(.easeOut(duration: 0.2)) { confirming = true }
                } label: {
                    Text(t("app.mock.hand"))
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }

            if failed {
                Text(t("app.mock.failed"))
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.negative)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, MicaboSpacing.md)
    }

    // MARK: - Actions

    private func set(_ id: String, _ change: (inout MockAnswer) -> Void) {
        var answer = answers[id] ?? MockAnswer(id: id)
        change(&answer)
        answers[id] = answer
    }

    private func textBinding(_ id: String) -> Binding<String> {
        Binding(
            get: { answers[id]?.text ?? "" },
            set: { text in set(id) { $0.text = text } }
        )
    }

    /// Une seconde à la fois, jusqu'à zéro - où la copie se remet toute seule.
    private func runClock() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, report == nil else { return }
            let left = max(0, Int(deadline.timeIntervalSinceNow.rounded()))
            remaining = left
            if left == 0 {
                await hand()
                return
            }
        }
    }

    private func hand() async {
        guard !saving, report == nil else { return }
        dictation.stop()
        saving = true
        failed = false
        let ordered = questions.map { answers[$0.id] ?? MockAnswer(id: $0.id) }
        do {
            guard let mocks else { throw MockExamService.Failure.notSignedIn }
            let closed = try await mocks.finish(session, answers: ordered, examName: examName)
            Haptics.success()
            withAnimation(.easeOut(duration: 0.25)) { report = closed }
        } catch {
            Haptics.warning()
            failed = true
        }
        saving = false
    }
}
