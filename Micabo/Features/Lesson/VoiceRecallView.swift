import AVFoundation
import SwiftData
import SwiftUI

/// **Réviser à voix haute** (`docs/supports.md`) : la carte pose sa question (à l'écran et à
/// voix haute), l'élève répond en parlant, la reconnaissance du téléphone écrit ce qu'il a
/// dit, et Mika compare avec la réponse (`SpokenAnswer`). L'élève garde le dernier mot :
/// « Je savais » ou « Pas encore » note la carte dans son rythme de révision (`LessonReview`).
struct VoiceRecallView: View {
    let session: LessonSession
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var cards: [Flashcard]
    @State private var index = 0
    @State private var phase: VoiceRecallPhase = .asking
    @State private var known = 0
    @State private var finished = false
    @State private var listener: VoiceRecallListener
    @State private var readsAloud = true
    @State private var noted = false
    @State private var voice = VoiceRecallVoice()

    static let sessionSize = 10

    init(session: LessonSession, onClose: @escaping () -> Void) {
        self.session = session
        self.onClose = onClose
        _cards = State(initialValue: Self.pick(session))
        let language = AudioTranscriber.locale(for: session.course.writingLanguage)
        _listener = State(initialValue: VoiceRecallListener(locale: language))
    }

    /// Les cartes de la séance : celles dues d'abord, puis des nouvelles ; dix au plus. Les
    /// schémas à trous se révisent des yeux, pas à voix haute.
    static func pick(_ session: LessonSession) -> [Flashcard] {
        let usable: (Flashcard) -> Bool = { $0.format != .occlusion && !VoiceRecallPrompt.answer(of: $0).isEmpty }
        let queue = session.studyQueue().filter(usable)
        if !queue.isEmpty { return Array(queue.prefix(sessionSize)) }
        return Array(session.course.cards.filter { !$0.isSuspended && usable($0) }.shuffled().prefix(sessionSize))
    }

    var body: some View {
        VStack(spacing: 0) {
            RevisionModeHeader(mode: .voice, lessonTitle: session.course.title, tone: session.course.tone, closesLeading: true) {
                listener.cancel()
                voice.stop()
                onClose()
            }
            if cards.isEmpty {
                empty
            } else if finished {
                VoiceRecallSummary(known: known, total: cards.count, tone: session.course.tone, onDone: onClose)
            } else {
                progress
                ScrollView {
                    VoiceRecallCard(
                        prompt: VoiceRecallPrompt(card: cards[index]),
                        phase: phase,
                        tone: session.course.tone,
                        level: listener.level,
                        transcript: listener.transcript,
                        readsAloud: $readsAloud,
                        onListen: listen,
                        onStop: { listener.finish() },
                        onReveal: reveal,
                        onRepeat: { voice.speak(VoiceRecallPrompt(card: cards[index]).question, language: languageCode) },
                        onRate: rate
                    )
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 12)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .task(id: index) { askAloud() }
        .onDisappear {
            listener.cancel()
            voice.stop()
        }
    }

    private var languageCode: String {
        AudioTranscriber.locale(for: session.course.writingLanguage).identifier.replacingOccurrences(of: "_", with: "-")
    }

    private var progress: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.track)
                    Capsule().fill(RevisionMode.voice.tone.vivid)
                        .frame(width: max(10, proxy.size.width * CGFloat(index) / CGFloat(max(1, cards.count))))
                }
            }
            .frame(height: 10)
            Text(verbatim: "\(index + 1) / \(cards.count)")
                .font(MicaboFont.ui(14, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 4)
    }

    private var empty: some View {
        VStack(spacing: 14) {
            Spacer()
            MikaMascot(mood: .wink, size: 120)
            Text(L10n.t("ios.home10.cards.empty", locale: .resolved()))
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 32)
    }

    // MARK: Agir

    private func askAloud() {
        guard readsAloud, cards.indices.contains(index), phase == .asking else { return }
        voice.speak(VoiceRecallPrompt(card: cards[index]).question, language: languageCode)
    }

    private func listen() {
        voice.stop()
        Task {
            guard await listener.prepare() else {
                phase = .unavailable(denied: listener.state == .denied)
                return
            }
            phase = .listening
            listener.start { heard in
                judge(heard)
            }
        }
    }

    private func judge(_ heard: String) {
        let prompt = VoiceRecallPrompt(card: cards[index])
        let judgement = SpokenAnswer.judge(heard: heard, expected: prompt.answer)
        withAnimation(LearnMotion.standard) {
            phase = .judged(heard: heard, judgement: judgement)
        }
        switch judgement.verdict {
        case .right: Haptics.success()
        case .close: Haptics.medium()
        case .missed: Haptics.warning()
        }
    }

    private func reveal() {
        listener.cancel()
        voice.stop()
        withAnimation(LearnMotion.standard) {
            phase = .judged(heard: "", judgement: nil)
        }
    }

    private func rate(_ knew: Bool) {
        guard cards.indices.contains(index) else { return }
        if !noted {
            noted = true
            RevisionModeAllowance.noteVoiceSession()
        }
        LessonReview.rate(cards[index], knew ? .good : .again)
        if knew { known += 1 }
        session.course.updatedAt = Date()
        try? modelContext.save()
        voice.stop()
        if index + 1 < cards.count {
            withAnimation(LearnMotion.standard) {
                phase = .asking
                index += 1
            }
        } else {
            Haptics.success()
            withAnimation(LearnMotion.standard) { finished = true }
        }
    }
}

/// Où en est une carte.
enum VoiceRecallPhase: Equatable {
    case asking
    case listening
    /// Ce qui a été entendu et le verdict ; sans verdict quand l'élève a seulement retourné la carte.
    case judged(heard: String, judgement: SpokenAnswer.Judgement?)
    /// Le micro ou la reconnaissance manque : l'élève retourne la carte et se note lui-même.
    case unavailable(denied: Bool)
}

/// La question et la réponse d'une carte, telles qu'elles se disent.
struct VoiceRecallPrompt: Equatable {
    var question: String
    var answer: String

    init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }

    init(card: Flashcard) {
        question = LessonDigest.plain(card.front.replacingOccurrences(of: ClozeGap.marker, with: "…"))
        answer = Self.answer(of: card)
    }

    static func answer(of card: Flashcard) -> String {
        LessonDigest.plain(card.correctChoice ?? card.back)
    }
}

/// La voix qui lit la question.
@MainActor
final class VoiceRecallVoice {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, language: String) {
        stop()
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .duckOthers])
        try? session.setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = LessonSpeaker.bestVoice(for: language)
        utterance.rate = LessonSpeaker.utteranceRate(for: 1)
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }
}

/// **La carte, à chaque moment** : la question ; l'écoute, avec l'onde et ce qui s'écrit ; le
/// verdict, la réponse et les deux boutons qui notent la carte.
struct VoiceRecallCard: View {
    let prompt: VoiceRecallPrompt
    let phase: VoiceRecallPhase
    let tone: LessonTone
    var level: Double = 0
    var transcript = ""
    @Binding var readsAloud: Bool
    var onListen: () -> Void = {}
    var onStop: () -> Void = {}
    var onReveal: () -> Void = {}
    var onRepeat: () -> Void = {}
    var onRate: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 18) {
            question
            switch phase {
            case .asking:
                asking
            case .listening:
                listening
            case .judged(let heard, let judgement):
                judged(heard: heard, judgement: judgement)
            case .unavailable(let denied):
                unavailable(denied: denied)
            }
        }
    }

    private var question: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.t("ios.sup.voice.question", locale: .resolved()))
                    .font(MicaboFont.ui(13, weight: .heavy))
                    .foregroundStyle(tone.ink)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Button(action: onRepeat) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tone.ink)
                        .frame(width: 36, height: 36)
                        .background(MicaboColor.surface.opacity(0.8), in: Circle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("ios.sup.voice.repeat", locale: .resolved())))
            }
            Text(prompt.question)
                .font(MicaboFont.ui(24, weight: .black))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.pale, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
    }

    private var asking: some View {
        VStack(spacing: 16) {
            Button(action: onListen) {
                VStack(spacing: 12) {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 96, height: 96)
                        .background(MicaboColor.accent, in: Circle())
                        .shadow(color: MicaboColor.accent.opacity(0.3), radius: 16, y: 8)
                    Text(L10n.t("ios.sup.voice.speak", locale: .resolved()))
                        .font(MicaboFont.ui(17, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .padding(.top, 10)

            Text(L10n.t("ios.sup.voice.hint", locale: .resolved()))
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(isOn: $readsAloud) {
                Text(L10n.t("ios.sup.voice.readAloud", locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
            }
            .tint(MicaboColor.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))

            Button(L10n.t("ios.sup.voice.reveal", locale: .resolved()), action: onReveal)
                .font(MicaboFont.ui(16, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .buttonStyle(MicaboPressableButtonStyle())
        }
    }

    private var listening: some View {
        VStack(spacing: 16) {
            VoiceWave(level: level, tone: RevisionMode.voice.tone)
                .frame(height: 56)
                .padding(.top, 8)
            Text(transcript.isEmpty ? L10n.t("ios.sup.voice.listening", locale: .resolved()) : transcript)
                .font(MicaboFont.ui(19, weight: transcript.isEmpty ? .semibold : .bold))
                .foregroundStyle(transcript.isEmpty ? MicaboColor.inkTertiary : MicaboColor.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 60)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onStop) {
                Label(L10n.t("ios.sup.voice.done", locale: .resolved()), systemImage: "stop.fill")
            }
            .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
    }

    private func judged(heard: String, judgement: SpokenAnswer.Judgement?) -> some View {
        VStack(spacing: 14) {
            if let judgement {
                verdictBanner(judgement.verdict)
            }
            if !heard.isEmpty {
                line(label: L10n.t("ios.sup.voice.youSaid", locale: .resolved()), text: heard, color: MicaboColor.inkSecondary)
            }
            line(label: L10n.t("ios.sup.voice.answer", locale: .resolved()), text: prompt.answer, color: MicaboColor.ink)
            HStack(spacing: 10) {
                rateButton(knew: false, recommended: judgement.map { $0.verdict == .missed } ?? false)
                rateButton(knew: true, recommended: judgement.map { $0.verdict == .right } ?? false)
            }
            .padding(.top, 4)
        }
    }

    private func unavailable(denied: Bool) -> some View {
        VStack(spacing: 14) {
            Label {
                Text(L10n.t(denied ? "ios.sup.voice.denied" : "ios.sup.voice.unavailable", locale: .resolved()))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "mic.slash.fill")
            }
            .font(MicaboFont.ui(15, weight: .semibold))
            .foregroundStyle(MicaboColor.inkSecondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            Button(L10n.t("ios.sup.voice.reveal", locale: .resolved()), action: onReveal)
                .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
    }

    private func verdictBanner(_ verdict: SpokenAnswer.Verdict) -> some View {
        let (key, symbol, fill, ink): (String, String, Color, Color) = {
            switch verdict {
            case .right: ("ios.sup.voice.right", "checkmark.circle.fill", MicaboColor.correctSoft, MicaboColor.correctInk)
            case .close: ("ios.sup.voice.close", "circle.lefthalf.filled", LessonTone.yellow.pale, LessonTone.yellow.ink)
            case .missed: ("ios.sup.voice.missed", "xmark.circle.fill", MicaboColor.wrongSoft, MicaboColor.wrongInk)
            }
        }()
        return Label {
            Text(L10n.t(key, locale: .resolved()))
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(MicaboFont.ui(17, weight: .heavy))
        .foregroundStyle(ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
    }

    private func line(label: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(MicaboFont.ui(12, weight: .heavy))
                .foregroundStyle(MicaboColor.inkTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(text)
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
    }

    private func rateButton(knew: Bool, recommended: Bool) -> some View {
        Button {
            onRate(knew)
        } label: {
            Text(L10n.t(knew ? "ios.sup.voice.knew" : "ios.sup.voice.notYet", locale: .resolved()))
                .font(MicaboFont.ui(17, weight: .heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .foregroundStyle(recommended ? .white : MicaboColor.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    recommended ? (knew ? MicaboColor.correct : MicaboColor.wrong) : MicaboColor.surface,
                    in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                        .strokeBorder(recommended ? Color.clear : MicaboColor.strokeStrong, lineWidth: 1.5)
                )
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
    }
}

/// L'onde du micro : sept barres qui suivent la voix.
struct VoiceWave: View {
    let level: Double
    let tone: LessonTone

    var body: some View {
        HStack(alignment: .center, spacing: 6) {
            ForEach(0..<7, id: \.self) { bar in
                let shape = [0.45, 0.7, 0.9, 1, 0.9, 0.7, 0.45][bar]
                Capsule()
                    .fill(tone.vivid)
                    .frame(width: 8, height: max(10, 56 * shape * max(0.2, level)))
            }
        }
        .animation(LearnMotion.quick, value: level)
        .accessibilityHidden(true)
    }
}

/// La fin de la séance : combien de cartes l'élève savait.
struct VoiceRecallSummary: View {
    let known: Int
    let total: Int
    let tone: LessonTone
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            MikaMascot(mood: known * 2 >= total ? .celebrate : .happy, size: 150)
            Text(verbatim: "\(known) / \(total)")
                .font(MicaboFont.number(52))
                .foregroundStyle(tone.ink)
            Text(L10n.t("ios.sup.voice.summary", locale: .resolved(), vars: ["count": String(known)]))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("ios.sup.voice.summarySub", locale: .resolved()))
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(L10n.t("lesson.quiz.finish", locale: .resolved()), action: onDone)
                .buttonStyle(LessonPrimaryButtonStyle(tint: MicaboColor.accent))
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.bottom, 20)
    }
}
