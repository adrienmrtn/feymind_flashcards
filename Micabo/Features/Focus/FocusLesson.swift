import SwiftData
import SwiftUI

// MARK: - Ce qu'on fait pendant la séance

/// **Ce que la séance fait de sa leçon** (lot 11) : avancer le chemin, réviser ses cartes, ou
/// faire son quiz. La séance ouvre la leçon sur cette activité dès qu'elle démarre.
enum FocusActivity: String, CaseIterable, Identifiable {
    case lesson
    case cards
    case quiz

    var id: String { rawValue }

    var title: String {
        L10n.t("ios.chat11.focus.activity.\(rawValue)", locale: .resolved())
    }

    var icon: MicaboIcon {
        switch self {
        case .lesson: .book
        case .cards: .cards
        case .quiz: .quiz
        }
    }
}

// MARK: - Ce qui a été fait

/// **Le bilan d'une séance liée à une leçon** : les minutes comptées sur elle, les étapes
/// finies, les cartes revues et les quiz faits pendant la séance — lus en comparant la leçon au
/// départ et à l'arrivée, et le journal des révisions depuis le départ.
struct FocusOutcome: Equatable {
    var lessonTitle: String
    var minutes: Int
    var steps: Int = 0
    var cards: Int = 0
    var quizzes: Int = 0

    /// La leçon au départ de la séance.
    struct Baseline: Equatable {
        var courseID: UUID
        var startedAt: Date
        var doneSteps: Int
        var quizzes: Int
    }

    static func baseline(of course: Course, at date: Date = Date()) -> Baseline {
        let progress = course.progress
        return Baseline(courseID: course.id, startedAt: date, doneSteps: progress.done.count, quizzes: progress.quizScores.count)
    }

    @MainActor
    static func measure(from baseline: Baseline, course: Course, workSeconds: TimeInterval, in context: ModelContext) -> FocusOutcome {
        let progress = course.progress
        let since = baseline.startedAt
        let logs = (try? context.fetch(FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.reviewedAt >= since }))) ?? []
        let cards = logs.filter { $0.card?.course?.id == baseline.courseID }.count
        return FocusOutcome(
            lessonTitle: course.title,
            minutes: Int(workSeconds / 60),
            steps: max(0, progress.done.count - baseline.doneSteps),
            cards: cards,
            quizzes: max(0, progress.quizScores.count - baseline.quizzes)
        )
    }

    /// Les lignes du bilan, dans l'ordre où elles se lisent.
    var lines: [String] {
        var out: [String] = []
        if steps > 0 { out.append(L10n.t("ios.chat11.focus.summary.steps", locale: .resolved(), vars: ["count": "\(steps)"])) }
        if cards > 0 { out.append(L10n.t("ios.chat11.focus.summary.cards", locale: .resolved(), vars: ["count": "\(cards)"])) }
        if quizzes > 0 { out.append(L10n.t("ios.chat11.focus.summary.quizzes", locale: .resolved(), vars: ["count": "\(quizzes)"])) }
        return out
    }
}

/// Le bilan, dans l'écran de fin : la leçon et ses minutes, puis ce qui a été fait.
struct FocusOutcomeCard: View {
    let outcome: FocusOutcome

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.t("ios.chat11.focus.summary.title", locale: .resolved()))
                .font(V3Font.eyebrow)
                .foregroundStyle(V3Color.ink3)
                .textCase(.uppercase)
            HStack(spacing: 10) {
                MicaboIconView(icon: .book, size: 26)
                Text(L10n.t("ios.chat11.focus.summary.minutes", locale: .resolved(), vars: ["minutes": "\(outcome.minutes)", "lesson": outcome.lessonTitle]))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if outcome.lines.isEmpty {
                Text(L10n.t("ios.chat11.focus.summary.nothing", locale: .resolved()))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(outcome.lines, id: \.self) { line in
                    Label {
                        Text(line)
                            .font(V3Font.body)
                            .foregroundStyle(V3Color.ink)
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(V3Color.green)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(radius: V3Metric.radiusInner)
    }
}

// MARK: - Choisir l'activité

/// Les trois activités d'une séance liée à une leçon, en puces.
struct FocusActivityPicker: View {
    @Binding var activity: FocusActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("ios.chat11.focus.activity", locale: .resolved()))
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink2)
            MicaboFlowLayout(spacing: 8) {
                ForEach(FocusActivity.allCases) { option in
                    V3Chip(option.title, icon: option.icon, isSelected: option == activity) {
                        activity = option
                    }
                }
            }
        }
    }
}

// MARK: - Lancer une séance d'ailleurs

/// **Lancer une séance de Concentration depuis un autre écran** (une leçon) : la feuille de
/// préparation, puis la séance une fois la feuille refermée — deux présentations ne se croisent
/// pas.
struct FocusLauncher: ViewModifier {
    @Binding var setup: FocusPlan?
    @Binding var pending: FocusPlan?
    @Binding var running: FocusPlan?
    let lessons: [Course]

    func body(content: Content) -> some View {
        content
            .sheet(item: $setup, onDismiss: launch) { plan in
                FocusSetupSheet(initial: plan, lessons: lessons, tasks: []) { prepared in
                    pending = prepared
                    setup = nil
                }
            }
            .fullScreenCover(item: $running) { plan in
                FocusTimerView(plan: plan)
            }
    }

    private func launch() {
        guard let plan = pending else { return }
        pending = nil
        running = plan
    }
}

/// Ce que la séance ouvre en plein écran : les cartes ou le quiz de sa leçon.
struct FocusLessonRun: Identifiable {
    let id = UUID()
    let course: Course
    let activity: FocusActivity
}
