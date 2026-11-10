import SwiftData
import SwiftUI

// MARK: - Aujourd'hui

/// **« Aujourd'hui »** (`docs/refonte-knowunity.md` § 1.3) : l'anneau de l'objectif du jour
/// (`xpToday / 50`), les cartes à réviser, la leçon en cours — la carte « Reprendre » s'y est
/// fondue —, et sans aucune leçon, « Crée ta première leçon ».
struct HomeTodayCard: View {
    let dueCount: Int
    let resumeCourse: Course?
    let resumeTarget: ResumeTarget?
    let hasCourses: Bool
    let onReview: () -> Void
    let onContinue: () -> Void
    let onCreate: () -> Void

    @Environment(XPStore.self) private var injected: XPStore?

    private var xp: XPStore { injected ?? .shared }

    var body: some View {
        let today = xp.today
        let reached = today >= XPRules.dailyGoal
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("ios.kx.today.title", locale: .resolved()))
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 14) {
                XPGoalRing(progress: Double(today) / Double(XPRules.dailyGoal))
                VStack(alignment: .leading, spacing: 3) {
                    Text(reached
                        ? L10n.t("ios.kx.today.goalReached", locale: .resolved())
                        : L10n.t("ios.kx.today.goal", locale: .resolved()))
                        .font(MicaboFont.ui(18, weight: .heavy))
                        .foregroundStyle(reached ? MicaboColor.correctInk : MicaboColor.ink)
                    Text(L10n.t("ios.kx.today.goalProgress", locale: .resolved(), vars: [
                        "xp": "\(min(today, XPRules.dailyGoal))",
                        "goal": "\(XPRules.dailyGoal)",
                    ]))
                        .font(MicaboFont.ui(14, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            if dueCount > 0 {
                row(
                    icon: .cards,
                    title: L10n.t("ios.kx.today.due", locale: .resolved(), vars: ["count": "\(dueCount)"]),
                    subtitle: nil,
                    action: onReview
                )
            }
            if let resumeCourse, let resumeTarget {
                row(
                    icon: resumeCourse.icon,
                    title: L10n.t("ios.kx.today.continue", locale: .resolved(), vars: ["lesson": resumeTarget.title]),
                    subtitle: resumeSubtitle(resumeTarget),
                    action: onContinue
                )
            } else if !hasCourses {
                row(
                    icon: .quill,
                    title: L10n.t("ios.kx.today.createFirst", locale: .resolved()),
                    subtitle: nil,
                    action: onCreate
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .micaboElevation(.card)
    }

    private func resumeSubtitle(_ target: ResumeTarget) -> String {
        guard let number = target.circleNumber, let title = target.circleTitle else {
            return L10n.t("lesson.home.resumeDone", locale: .resolved())
        }
        return L10n.t("lesson.home.resumeCircle", locale: .resolved(), vars: ["n": String(number), "title": title])
    }

    private func row(icon: MicaboIcon, title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                MicaboIconView(icon: icon, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(MicaboFont.ui(16, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }
}

// MARK: - Outils

/// **« Outils »** (§ 1.4) : quatre tuiles, une icône colorée, un nom, une ligne.
struct HomeToolsGrid: View {
    enum Tool: CaseIterable {
        case scan
        case quiz
        case timer
        case league
    }

    let hasLesson: Bool
    let onTool: (Tool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("ios.kx.tools.title", locale: .resolved()))
                .font(MicaboFont.sectionTitle)
                .foregroundStyle(MicaboColor.ink)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    tile(.scan)
                    tile(.quiz)
                }
                HStack(spacing: 10) {
                    tile(.timer)
                    tile(.league)
                }
            }
        }
    }

    private func tile(_ tool: Tool) -> some View {
        Button { onTool(tool) } label: {
            VStack(alignment: .leading, spacing: 8) {
                MicaboIconView(icon: icon(tool), size: 30)
                    .frame(width: 46, height: 46)
                    .background(tone(tool).pale, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Text(title(tool))
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle(tool))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityElement(children: .combine)
    }

    private func icon(_ tool: Tool) -> MicaboIcon {
        switch tool {
        case .scan: .photo
        case .quiz: .quiz
        case .timer: .alarm
        case .league: .trophy
        }
    }

    private func tone(_ tool: Tool) -> LessonTone {
        switch tool {
        case .scan: .blue
        case .quiz: .pink
        case .timer: .mint
        case .league: .yellow
        }
    }

    private func title(_ tool: Tool) -> String {
        switch tool {
        case .scan: L10n.t("ios.kx.tools.scan.title", locale: .resolved())
        case .quiz: L10n.t("ios.kx.tools.quiz.title", locale: .resolved())
        case .timer: L10n.t("ios.kx.tools.timer.title", locale: .resolved())
        case .league: L10n.t("ios.kx.tools.league.title", locale: .resolved())
        }
    }

    private func subtitle(_ tool: Tool) -> String {
        switch tool {
        case .scan: L10n.t("ios.kx.tools.scan.sub", locale: .resolved())
        case .quiz: hasLesson
            ? L10n.t("ios.kx.tools.quiz.sub", locale: .resolved())
            : L10n.t("ios.kx.tools.quiz.subEmpty", locale: .resolved())
        case .timer: L10n.t("ios.kx.tools.timer.sub", locale: .resolved(), vars: ["n": "\(XPRules.focusMinutes)"])
        case .league: L10n.t("ios.kx.tools.league.sub", locale: .resolved())
        }
    }
}

// MARK: - Les cartes dues

/// Les cartes dues de toutes les leçons, comptées comme `LessonSession.dueCards`.
enum DueReview {
    static func dueCount(of course: Course, now: Date = Date()) -> Int {
        course.cards.filter { !$0.isSuspended && $0.state != .new && $0.dueDate <= now }.count
    }

    /// Les leçons qui ont des cartes dues, la plus chargée d'abord.
    static func courses(_ courses: [Course], now: Date = Date()) -> [Course] {
        courses
            .map { ($0, dueCount(of: $0, now: now)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }
}

/// **« {n} cartes à réviser »** : les cartes dues, leçon après leçon, dans la série de
/// flashcards de la leçon (`LessonCardsRun`). « Suivant » passe à la leçon d'après.
struct DueCardsReview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessions: [LessonSession]
    @State private var position = 0

    init(courses: [Course]) {
        _sessions = State(initialValue: courses.map { LessonSession(course: $0) })
    }

    var body: some View {
        Group {
            if sessions.indices.contains(position) {
                let session = sessions[position]
                LessonCardsRun(
                    session: session,
                    cards: session.dueCards(),
                    onClose: { dismiss() },
                    onDone: nextLesson
                )
                .id(position)
                .transition(.move(edge: .trailing))
            } else {
                Color.clear.onAppear { dismiss() }
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    /// « Suivant » vers la leçon d'après ; rien sur la dernière, qui se termine par « Terminer ».
    private var nextLesson: (() -> Void)? {
        guard position + 1 < sessions.count else { return nil }
        return {
            withAnimation(.spring(duration: 0.4)) { position += 1 }
        }
    }
}

// MARK: - Quiz éclair

/// **« Quiz éclair »** (§ 1.4) : cinq questions sur la dernière leçon ouverte, dans le quiz de
/// la leçon. Chaque réponse rapporte son XP, comme ailleurs.
struct QuickQuizSheet: View {
    static let count = 5

    @Environment(\.dismiss) private var dismiss
    @State private var session: LessonSession
    @State private var questions: [QuizQuestion]

    init(course: Course) {
        let session = LessonSession(course: course)
        _session = State(initialValue: session)
        _questions = State(initialValue: Array(session.fullQuiz(attempt: Int.random(in: 1...100_000)).prefix(Self.count)))
    }

    var body: some View {
        LessonQuizView(
            session: session,
            questions: questions,
            title: L10n.t("ios.kx.tools.quiz.title", locale: .resolved()),
            circleID: nil,
            onClose: { dismiss() }
        )
    }
}
