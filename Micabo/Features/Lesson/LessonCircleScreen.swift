import SwiftData
import SwiftUI

/// **Une étape ouverte**, en plein écran : l'Intro, des Notes, un Checkpoint ou le Quiz final
/// (puis « À retenir »). Chacune se termine par un bouton qui coche l'étape et ramène au
/// chemin.
struct LessonCircleScreen: View {
    let session: LessonSession
    let circle: PathCircle
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsTakeaways = false

    var body: some View {
        Group {
            switch circle.kind {
            case .intro:
                IntroCircleView(session: session, onDone: onDone)
            case .notes(let theme):
                if let chapter = session.chapter(at: theme) {
                    NotesCircleView(session: session, chapter: chapter, onDone: onDone)
                }
            case .quiz:
                LessonQuizView(
                    session: session,
                    questions: session.circleQuiz(circle),
                    title: circle.title,
                    circleID: circle.id,
                    onClose: { dismiss() },
                    onDone: onDone
                )
            case .final:
                if showsTakeaways {
                    ConclusionCircleView(session: session, onDone: onDone)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    LessonQuizView(
                        session: session,
                        questions: session.circleQuiz(circle),
                        title: circle.title,
                        circleID: circle.id,
                        onClose: { dismiss() },
                        onDone: { withAnimation(.spring(duration: 0.45)) { showsTakeaways = true } }
                    )
                }
            }
        }
        .lessonClock(session, activity: circle.activity)
    }
}

// MARK: - Le temps passé

/// **Le temps de révision, mesuré** : ce qu'on passe dans Notes, Quiz et Flashcards, ajouté à
/// la leçon quand l'écran se ferme ou que l'app passe en arrière-plan.
private struct LessonClock: ViewModifier {
    let session: LessonSession
    let activity: LessonActivity?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var since: Date?

    func body(content: Content) -> some View {
        content
            .onAppear { since = Date() }
            .onDisappear { flush() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    since = Date()
                } else {
                    flush()
                }
            }
    }

    private func flush() {
        guard let activity, let start = since else { return }
        since = nil
        session.addTime(Date().timeIntervalSince(start), to: activity, in: modelContext)
    }
}

extension View {
    func lessonClock(_ session: LessonSession, activity: LessonActivity?) -> some View {
        modifier(LessonClock(session: session, activity: activity))
    }
}

// MARK: - L'en-tête d'un cercle

/// La croix pour sortir sans cocher, et la barre fine qui dit où on en est.
struct CircleTopBar: View {
    var progress: Double?
    var tone: LessonTone
    var label: String?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))

            if let progress {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(MicaboColor.track)
                        Capsule()
                            .fill(tone.vivid)
                            .frame(width: max(8, proxy.size.width * CGFloat(min(1, max(0, progress)))))
                    }
                }
                .frame(height: 10)
                .animation(.easeOut(duration: 0.25), value: progress)
            } else {
                Spacer()
            }

            if let label {
                Text(label)
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

// MARK: - L'Intro

/// « Ce que tu vas apprendre » : trois lignes, les thèmes et leurs icônes, le temps estimé,
/// « C'est parti ».
struct IntroCircleView: View {
    let session: LessonSession
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CircleTopBar(progress: nil, tone: session.course.tone, label: nil) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        MikaMascot(mood: .wave, size: 130)
                        Spacer()
                    }
                    Text(L10n.t("lesson.intro.title", locale: .resolved()))
                        .font(MicaboFont.title)
                        .foregroundStyle(MicaboColor.ink)

                    if let lines = session.plan?.intro.lines, !lines.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(MicaboFont.notes)
                                    .foregroundStyle(MicaboColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(session.course.tone.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(session.course.orderedChapters) { chapter in
                            HStack(spacing: 14) {
                                MicaboIconView(icon: chapter.icon, size: 36)
                                Text(chapter.title)
                                    .font(MicaboFont.label)
                                    .foregroundStyle(MicaboColor.ink)
                            }
                        }
                    }

                    if let minutes = session.plan?.intro.minutes {
                        Text(L10n.t("lesson.intro.estimate", locale: .resolved(), vars: ["minutes": String(minutes)]))
                            .font(MicaboFont.small)
                            .tracking(MicaboTracking.caps)
                            .textCase(.uppercase)
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 24)
            }
            Button(L10n.t("lesson.intro.go", locale: .resolved()), action: onDone)
                .buttonStyle(LessonPrimaryButtonStyle())
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 12)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }
}

// MARK: - La Conclusion

/// « À retenir » : cinq phrases clés, le score moyen des quiz, « Terminer ».
struct ConclusionCircleView: View {
    let session: LessonSession
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            CircleTopBar(progress: nil, tone: session.course.tone, label: nil) { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        MicaboIconView(icon: .trophy, size: 84)
                        Spacer()
                    }
                    Text(L10n.t("lesson.conclusion.title", locale: .resolved()))
                        .font(MicaboFont.title)
                        .foregroundStyle(MicaboColor.ink)

                    if !takeaways.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(takeaways.enumerated()), id: \.offset) { _, line in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(session.course.tone.vivid)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 8)
                                    KeywordText(line)
                                        .font(MicaboFont.notes)
                                        .foregroundStyle(MicaboColor.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(session.course.tone.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

                    if let score = session.progress.averageQuizPercent {
                        HStack {
                            Text(L10n.t("lesson.conclusion.score", locale: .resolved()))
                                .font(MicaboFont.label)
                                .foregroundStyle(MicaboColor.ink)
                            Spacer()
                            Text("\(score) %")
                                .font(MicaboFont.number(28))
                                .foregroundStyle(session.course.tone.ink)
                        }
                        .padding(18)
                        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .micaboElevation(.row)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 24)
            }
            Button(L10n.t("lesson.conclusion.finish", locale: .resolved()), action: onDone)
                .buttonStyle(LessonPrimaryButtonStyle())
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 12)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    /// Les phrases de la leçon, sinon celles des thèmes.
    private var takeaways: [String] {
        if let lines = session.plan?.takeaways, !lines.isEmpty { return lines }
        return Array(session.course.orderedChapters.compactMap { $0.notes?.takeaways.first }.prefix(5))
    }
}

// MARK: - Leçon terminée

/// **« Leçon terminée »** : plein écran, Mika fait la fête, confettis, le score et le temps.
struct LessonFinishedView: View {
    enum Destination {
        case flashcards
        case lessons
    }

    let session: LessonSession
    let onLeave: (Destination) -> Void

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            ConfettiView(colors: LessonTone.allCases.map(\.vivid))
                .ignoresSafeArea()
                .allowsHitTesting(false)
            VStack(spacing: 22) {
                Spacer()
                MikaMascot(mood: .celebrate, size: 200, reactsToTap: true)
                Text(L10n.t("lesson.finished.title", locale: .resolved()))
                    .font(MicaboFont.display(32))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                HStack(spacing: 14) {
                    stat(
                        value: session.progress.averageQuizPercent.map { "\($0) %" } ?? "-",
                        label: L10n.t("lesson.finished.score", locale: .resolved())
                    )
                    stat(
                        value: minutes,
                        label: L10n.t("lesson.finished.time", locale: .resolved())
                    )
                }
                Spacer()
                VStack(spacing: 12) {
                    Button(L10n.t("lesson.finished.cards", locale: .resolved())) { onLeave(.flashcards) }
                        .buttonStyle(LessonPrimaryButtonStyle())
                    Button(L10n.t("lesson.finished.back", locale: .resolved())) { onLeave(.lessons) }
                        .buttonStyle(MicaboSecondaryButtonStyle())
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 12)
            }
        }
        .onAppear { Haptics.burst(count: 4, over: 0.6) }
    }

    private var minutes: String {
        let total = Int((session.progress.totalSeconds / 60).rounded())
        return L10n.t("lesson.finished.minutes", locale: .resolved(), vars: ["n": String(max(1, total))])
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MicaboFont.number(30))
                .foregroundStyle(session.course.tone.ink)
                .monospacedDigit()
            Text(label)
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .micaboElevation(.row)
    }
}

/// Des confettis légers, qui tombent une fois.
struct ConfettiView: View {
    let colors: [Color]
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed < 4 else { return }
                var generator = SeededGenerator(seed: 7)
                for index in 0..<60 {
                    let x = Double.random(in: 0...1, using: &generator) * size.width
                    let delay = Double.random(in: 0...0.8, using: &generator)
                    let speed = Double.random(in: 180...320, using: &generator)
                    let t = max(0, elapsed - delay)
                    let y = -20 + t * speed
                    guard y < size.height + 20 else { continue }
                    let sway = sin(t * 3 + Double(index)) * 14
                    let rotation = Angle.degrees(t * 260 + Double(index * 37))
                    var piece = context
                    piece.translateBy(x: x + sway, y: y)
                    piece.rotate(by: rotation)
                    piece.opacity = max(0, 1 - t / 3.2)
                    let color = colors.isEmpty ? MicaboColor.accent : colors[index % colors.count]
                    piece.fill(Path(roundedRect: CGRect(x: -4, y: -2.5, width: 8, height: 5), cornerRadius: 1.5), with: .color(color))
                }
            }
        }
    }
}
