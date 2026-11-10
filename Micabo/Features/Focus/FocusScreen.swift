import Charts
import SwiftUI

// MARK: - Le haut de la page

/// **La journée de concentration**, sur la scène bleue de la marque : les minutes du jour dans
/// un anneau qui se remplit vers l'objectif (le temps que l'élève s'est donné dans le parcours
/// d'accueil), la série, et le grand bouton. Mika sort du bas de la scène, posé derrière le
/// panneau blanc du bouton, comme sur Home.
struct FocusHeroCard: View {
    let minutesToday: Int
    let goalMinutes: Int
    let streak: Int
    let streakLit: Bool
    let onStart: () -> Void

    @Environment(\.homeStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let mikaSize: CGFloat = 116
    /// Ce qui passe derrière le bouton : le bas du buste.
    static let mikaSink: CGFloat = 30
    /// La place que le buste prend à droite de la colonne de texte.
    static let mikaReserve: CGFloat = 88

    private var progress: Double {
        goalMinutes > 0 ? min(1, Double(minutesToday) / Double(goalMinutes)) : 0
    }

    private var reached: Bool { minutesToday >= goalMinutes && goalMinutes > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(loc("ios.focus.today"))
                    .font(MicaboFont.ui(12.5, weight: .black))
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboStage.inkSecondary)
                Spacer()
                streakPill
            }
            HStack(alignment: .center, spacing: 12) {
                ring
                VStack(alignment: .leading, spacing: 4) {
                    Text(loc("ios.focus.minutesToday"))
                        .font(MicaboFont.ui(15, weight: .black))
                        .foregroundStyle(MicaboStage.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(reached ? loc("ios.focus.goalReached") : loc("ios.focus.goalLeft", ["minutes": CalendarTime.duration(minutes: goalMinutes - minutesToday)]))
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(reached ? MicaboBrand.pencil : MicaboStage.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: Self.mikaReserve - 12, height: 1)
            }
            .padding(.top, 10)
            .padding(.bottom, 18)

            // Le bouton blanc passe devant le bas du buste : Mika regarde par-dessus.
            Button(action: onStart) {
                Label(loc("ios.focus.start"), systemImage: "play.fill")
                    .font(MicaboFont.ui(17, weight: .heavy))
                    .foregroundStyle(MicaboBrand.blue700)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: MicaboStage.buttonRadius, style: .continuous))
                    .shadow(color: MicaboBrand.blue900.opacity(0.18), radius: 10, y: 5)
            }
            .buttonStyle(HomePressStyle(scale: 0.97, feedback: .medium))
            .background(alignment: .topTrailing) {
                MikaMascot(mood: reached ? .happy : .idle, size: Self.mikaSize, frozenAt: still ? 0.5 : nil, backdrop: .blue)
                    .offset(x: 2, y: -Self.mikaSize + Self.mikaSink)
                    .accessibilityHidden(true)
            }
        }
        .padding(18)
        .background(MicaboBrandBackdrop(sparkles: true))
        .clipShape(RoundedRectangle(cornerRadius: MicaboStage.heroRadius, style: .continuous))
        .shadow(color: MicaboBrand.blue.opacity(0.3), radius: 20, y: 10)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(reached ? MicaboBrand.pencil : Color.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text("\(minutesToday)")
                    .font(MicaboFont.number(30))
                    .foregroundStyle(MicaboStage.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(loc("ios.focus.minUnit"))
                    .font(MicaboFont.ui(12, weight: .black))
                    .foregroundStyle(MicaboStage.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(14)
        }
        .frame(width: 88, height: 88)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(loc("ios.focus.ringA11y", ["minutes": "\(minutesToday)", "goal": "\(goalMinutes)"])))
    }

    private var streakPill: some View {
        HStack(spacing: 4) {
            MicaboIconView(icon: .flame, size: 18)
                .saturation(streakLit ? 1 : 0)
                .opacity(streakLit ? 1 : 0.6)
            Text("\(streak)")
                .font(MicaboFont.number(15))
                .foregroundStyle(MicaboStage.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Color.white.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t("ios.streak.pillA11y", locale: .resolved(), vars: ["count": "\(streak)"])))
    }
}

// MARK: - La prochaine révision

/// La séance de révision que Mika a posée pour aujourd'hui, avec son bouton.
struct FocusNextRevisionCard: View {
    let time: String
    let title: String
    let detail: String
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(CalendarTint.at(CalendarTint.revisionIndex).wash)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(CalendarTint.at(CalendarTint.revisionIndex).color)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(loc("ios.focus.nextRevision", ["time": time]))
                    .font(MicaboFont.ui(12, weight: .black))
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.accentInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(title)
                    .font(MicaboFont.ui(16, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: onStart) {
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color.white)
                    .frame(width: 44, height: 44)
                    .background(MicaboStage.buttonFill, in: Circle())
                    .shadow(color: MicaboBrand.blue.opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(HomePressStyle(scale: 0.9, feedback: .medium))
            .accessibilityLabel(Text(loc("ios.cal.startSession")))
        }
        .padding(14)
        .homeCard(radius: MicaboStage.tileRadius)
    }
}

// MARK: - Mes tâches

/// **« Mes tâches »** : ce qui reste, la barre de ce qui est fait, les tâches à cocher, et le
/// « + ». Les tâches cochées aujourd'hui restent visibles, barrées, jusqu'à demain.
struct FocusTasksCard: View {
    let tasks: [StudyTaskSpec]
    let lessonTitles: [UUID: String]
    let onAdd: () -> Void
    let onToggle: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onSeeAll: () -> Void

    static let shown = 5

    private var open: [StudyTaskSpec] { tasks.filter { !$0.isDone } }
    private var done: [StudyTaskSpec] { tasks.filter(\.isDone) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: loc("ios.focus.tasks"), detail: remainingText) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(MicaboColor.accentInk)
                        .frame(width: 38, height: 38)
                        .background(MicaboColor.accentSoft, in: Circle())
                }
                .buttonStyle(HomePressStyle(scale: 0.9))
                .accessibilityLabel(Text(loc("ios.focus.addTask")))
            }
            if tasks.isEmpty {
                Button(action: onAdd) {
                    HStack(spacing: 10) {
                        Image(systemName: "checklist")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(MicaboColor.accentInk)
                        Text(loc("ios.focus.tasksEmpty"))
                            .font(MicaboFont.ui(14.5, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(MicaboColor.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(HomePressStyle(scale: 0.98))
            } else {
                progressBar
                VStack(spacing: 2) {
                    ForEach(Array((open + done).prefix(Self.shown))) { task in
                        FocusTaskRow(task: task, lessonTitle: task.courseID.flatMap { lessonTitles[$0] }) {
                            onToggle(task.id)
                        }
                        .contextMenu {
                            Button(loc("ios.focus.deleteTask"), systemImage: "trash", role: .destructive) { onDelete(task.id) }
                        }
                    }
                }
                if tasks.count > Self.shown || !done.isEmpty {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text(loc("ios.focus.seeAll"))
                            Image(systemName: "chevron.forward")
                                .font(.system(size: 12, weight: .heavy))
                                .flipsForRightToLeftLayoutDirection(true)
                        }
                        .font(MicaboFont.ui(14, weight: .black))
                        .foregroundStyle(MicaboColor.accentInk)
                    }
                    .buttonStyle(HomePressStyle(scale: 0.95))
                }
            }
        }
        .padding(16)
        .homeCard()
    }

    private var remainingText: String? {
        guard !tasks.isEmpty else { return nil }
        switch open.count {
        case 0: return loc("ios.focus.tasksAllDone")
        case 1: return loc("ios.focus.taskLeftOne")
        default: return loc("ios.focus.tasksLeft", ["count": "\(open.count)"])
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(MicaboColor.track)
                Capsule()
                    .fill(done.isEmpty ? AnyShapeStyle(Color.clear) : AnyShapeStyle(MicaboStage.buttonFill))
                    .frame(width: max(done.isEmpty ? 0 : 8, proxy.size.width * CGFloat(done.count) / CGFloat(max(1, tasks.count))))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

/// Une tâche : la case, le titre, l'échéance, la leçon.
struct FocusTaskRow: View {
    let task: StudyTaskSpec
    let lessonTitle: String?
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(task.isDone ? MicaboColor.correctInk : MicaboColor.inkTertiary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(MicaboFont.ui(15.5, weight: .bold))
                        .foregroundStyle(task.isDone ? MicaboColor.inkTertiary : MicaboColor.ink)
                        .strikethrough(task.isDone, color: MicaboColor.inkTertiary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let detail {
                        Text(detail)
                            .font(MicaboFont.ui(12.5, weight: .bold))
                            .foregroundStyle(isLate ? MicaboColor.wrongInk : MicaboColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(HomePressStyle(scale: 0.98, feedback: .selection))
        .accessibilityAddTraits(task.isDone ? .isSelected : [])
    }

    private var isLate: Bool {
        guard let due = task.dueDate, !task.isDone else { return false }
        return MicaboCalendar.shared.startOfDay(for: due) < MicaboCalendar.shared.startOfDay(for: Date())
    }

    private var detail: String? {
        var parts: [String] = []
        if let due = task.dueDate {
            let calendar = MicaboCalendar.shared
            if calendar.isDateInToday(due) {
                parts.append(loc("ios.focus.dueToday"))
            } else if calendar.isDateInTomorrow(due) {
                parts.append(loc("ios.focus.dueTomorrow"))
            } else {
                parts.append(loc("ios.focus.dueOn", ["date": MicaboCalendar.shortDayLabel(due)]))
            }
        }
        if let lessonTitle { parts.append(lessonTitle) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Les statistiques

/// Un jour du graphique.
struct FocusDayBar: Identifiable, Equatable {
    var day: Date
    var minutes: Int
    var id: Date { day }
}

/// **Cette semaine** : les minutes des sept derniers jours en barres, la ligne de l'objectif,
/// et trois chiffres — le total de la semaine, les séances, la meilleure série.
struct FocusStatsCard: View {
    let days: [FocusDayBar]
    let goalMinutes: Int
    let weekMinutes: Int
    let weekSessions: Int
    let bestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StudySectionTitle(title: loc("ios.focus.stats"), detail: loc("ios.focus.statsSub"))
            chart
                .frame(height: 150)
            HStack(spacing: 8) {
                tile(value: CalendarTime.duration(minutes: weekMinutes), label: loc("ios.focus.statWeek"))
                tile(value: "\(weekSessions)", label: loc("ios.focus.statSessions"))
                tile(value: loc("ios.focus.streakDays", ["count": "\(bestStreak)"]), label: loc("ios.focus.statStreak"))
            }
        }
        .padding(16)
        .homeCard()
    }

    private var chart: some View {
        Chart {
            ForEach(days) { bar in
                BarMark(
                    x: .value("day", MicaboCalendar.shortWeekday(bar.day)),
                    y: .value("minutes", bar.minutes)
                )
                .foregroundStyle(MicaboCalendar.shared.isDateInToday(bar.day) ? AnyShapeStyle(MicaboStage.fill) : AnyShapeStyle(MicaboBrand.blue300.opacity(0.75)))
                .cornerRadius(6)
            }
            if goalMinutes > 0 {
                RuleMark(y: .value("goal", goalMinutes))
                    .foregroundStyle(MicaboBrand.pencil)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text(loc("ios.focus.goalLine", ["minutes": "\(goalMinutes)"]))
                            .font(MicaboFont.ui(11, weight: .black))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
            }
        }
        .chartYScale(domain: 0...max(goalMinutes + 10, (days.map(\.minutes).max() ?? 0) + 10))
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(MicaboColor.hairline)
                AxisValueLabel().font(MicaboFont.ui(10.5, weight: .bold)).foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .chartXAxis {
            AxisMarks { _ in
                AxisValueLabel().font(MicaboFont.ui(11, weight: .black)).foregroundStyle(MicaboColor.inkSecondary)
            }
        }
        .accessibilityLabel(Text(loc("ios.focus.chartA11y", ["minutes": "\(weekMinutes)"])))
    }

    private func tile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(MicaboFont.number(18))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(MicaboFont.ui(12, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(MicaboColor.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
