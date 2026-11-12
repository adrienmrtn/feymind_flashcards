import SwiftUI

/// **« Préparer ma session »** : séance simple ou Pomodoro, la durée, les cycles, l'objectif
/// (une leçon, des tâches), et l'XP qu'on gagnera en allant au bout.
struct FocusSetupSheet: View {
    let lessons: [Course]
    let tasks: [StudyTaskSpec]
    let onStart: (FocusPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var plan: FocusPlan
    @State private var goalsOpen: Bool
    @State private var choosingLesson = false

    init(initial: FocusPlan, lessons: [Course], tasks: [StudyTaskSpec], onStart: @escaping (FocusPlan) -> Void) {
        self.lessons = lessons
        self.tasks = tasks
        self.onStart = onStart
        _plan = State(initialValue: initial)
        _goalsOpen = State(initialValue: initial.courseID != nil || !initial.taskIDs.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                FocusSetupForm(
                    plan: $plan,
                    goalsOpen: $goalsOpen,
                    tasks: tasks,
                    onPickLesson: { choosingLesson = true }
                )
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                FocusStartBar(xp: plan.xpToEarn) {
                    Analytics.track(.focusPrepared, [
                        "mode": .text(plan.mode.rawValue),
                        "minutes": .number(Double(plan.totalWorkMinutes)),
                    ])
                    onStart(plan)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 8)
                .background(MicaboColor.canvas)
            }
            .navigationTitle(loc("ios.focus.prepare"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .accessibilityLabel(Text(loc("ios.cal.close")))
                }
            }
            .navigationDestination(isPresented: $choosingLesson) {
                LessonPickerSheet(lessons: lessons, selected: plan.courseID) { course in
                    plan.courseID = course?.id
                    plan.courseTitle = course?.title
                }
            }
        }
    }
}

/// Le formulaire, sans état : la feuille le tient, les rendus le dessinent.
struct FocusSetupForm: View {
    @Binding var plan: FocusPlan
    @Binding var goalsOpen: Bool
    let tasks: [StudyTaskSpec]
    let onPickLesson: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 18) {
                FocusModePicker(mode: $plan.mode)
                durationBlock
                if plan.mode == .pomodoro {
                    cyclesBlock
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .homeCard()
            .animation(MicaboMotion.standard, value: plan.mode)

            goals
        }
    }

    // MARK: La durée

    private var range: ClosedRange<Int> {
        plan.mode == .pomodoro ? FocusPlan.pomodoroRange : FocusPlan.simpleRange
    }

    private var durationBlock: some View {
        VStack(spacing: 14) {
            Text(loc(plan.mode == .pomodoro ? "ios.focus.cycleLength" : "ios.focus.duration"))
                .font(MicaboFont.ui(16, weight: .black))
                .foregroundStyle(MicaboColor.ink)
            HStack(spacing: 14) {
                stepButton("minus", delta: -FocusPlan.stepMinutes, label: "ios.focus.less")
                Text(FocusPhases.clock(TimeInterval(plan.workMinutes * 60)))
                    .font(MicaboFont.number(42))
                    .foregroundStyle(MicaboColor.accentInk)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText(value: Double(plan.workMinutes)))
                    .frame(maxWidth: .infinity, minHeight: 74)
                    .background(MicaboColor.accentSoft.opacity(0.5), in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous).strokeBorder(MicaboColor.accent.opacity(0.5), lineWidth: 2))
                    .accessibilityLabel(Text(CalendarTime.duration(minutes: plan.workMinutes)))
                stepButton("plus", delta: FocusPlan.stepMinutes, label: "ios.focus.more")
            }
            StudySlider(value: $plan.workMinutes, range: range, step: FocusPlan.stepMinutes)
                .accessibilityLabel(Text(loc(plan.mode == .pomodoro ? "ios.focus.cycleLength" : "ios.focus.duration")))
        }
        .onChange(of: plan.mode) { _, _ in
            plan.workMinutes = max(range.lowerBound, min(range.upperBound, plan.workMinutes))
        }
    }

    private func stepButton(_ symbol: String, delta: Int, label: String) -> some View {
        let next = plan.workMinutes + delta
        let enabled = range.contains(next)
        return Button {
            withAnimation(MicaboMotion.quick) { plan.workMinutes = max(range.lowerBound, min(range.upperBound, next)) }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(enabled ? MicaboColor.ink : MicaboColor.inkTertiary)
                .frame(width: 48, height: 48)
                .background(MicaboColor.surface, in: Circle())
                .overlay(Circle().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        }
        .buttonStyle(HomePressStyle(scale: 0.9, feedback: .selection))
        .disabled(!enabled)
        .accessibilityLabel(Text(loc(label)))
    }

    // MARK: Les cycles

    private var cyclesBlock: some View {
        VStack(spacing: 12) {
            Text(loc("ios.focus.cycles"))
                .font(MicaboFont.ui(16, weight: .black))
                .foregroundStyle(MicaboColor.ink)
            HStack(spacing: 10) {
                ForEach(Array(FocusPlan.cycleRange), id: \.self) { count in
                    let isOn = plan.cycles == count
                    Button {
                        withAnimation(MicaboMotion.quick) { plan.cycles = count }
                    } label: {
                        Text("\(count)")
                            .font(MicaboFont.number(20))
                            .foregroundStyle(isOn ? Color.white : MicaboColor.ink)
                            .frame(width: 54, height: 50)
                            .background {
                                RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                                    .fill(isOn ? AnyShapeStyle(MicaboStage.buttonFill) : AnyShapeStyle(MicaboColor.surface))
                            }
                            .overlay {
                                if !isOn {
                                    RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5)
                                }
                            }
                    }
                    .buttonStyle(HomePressStyle(scale: 0.92, feedback: .selection))
                    .accessibilityLabel(Text(loc("ios.focus.cyclesA11y", ["count": "\(count)"])))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            Text(loc("ios.focus.pomodoroSummary", [
                "cycles": "\(plan.effectiveCycles)",
                "work": "\(plan.workMinutes)",
                "rest": "\(plan.breakMinutes)",
            ]))
            .font(MicaboFont.ui(14, weight: .bold))
            .foregroundStyle(MicaboColor.inkSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            Text(loc("ios.focus.totalLength", ["duration": CalendarTime.duration(minutes: Int(FocusPhases.total(plan.phases) / 60))]))
                .font(MicaboFont.ui(13, weight: .bold))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
    }

    // MARK: L'objectif

    private var goals: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(MicaboMotion.standard) { goalsOpen.toggle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MicaboColor.accentInk)
                        .frame(width: 38, height: 38)
                        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(loc("ios.focus.goal"))
                            .font(MicaboFont.ui(16, weight: .black))
                            .foregroundStyle(MicaboColor.ink)
                        Text(goalSummary)
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .rotationEffect(.degrees(goalsOpen ? 180 : 0))
                }
                .padding(14)
                .contentShape(Rectangle())
            }
            .buttonStyle(HomePressStyle(scale: 0.98))

            if goalsOpen {
                VStack(alignment: .leading, spacing: 12) {
                    MicaboHairline()
                    lessonRow
                    if !tasks.isEmpty {
                        StudyFieldLabel(text: loc("ios.focus.goalTasks"))
                        ForEach(tasks.prefix(8)) { task in
                            let isOn = plan.taskIDs.contains(task.id)
                            Button {
                                if isOn { plan.taskIDs.removeAll { $0 == task.id } } else { plan.taskIDs.append(task.id) }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(isOn ? MicaboColor.accent : MicaboColor.inkTertiary)
                                    Text(task.title)
                                        .font(MicaboFont.ui(15, weight: .bold))
                                        .foregroundStyle(MicaboColor.ink)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(HomePressStyle(scale: 0.98, feedback: .selection))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .transition(.opacity)
            }
        }
        .homeCard(radius: MicaboStage.tileRadius)
    }

    private var goalSummary: String {
        var parts: [String] = []
        if let title = plan.courseTitle { parts.append(title) }
        if !plan.taskIDs.isEmpty { parts.append(loc("ios.focus.goalTaskCount", ["count": "\(plan.taskIDs.count)"])) }
        return parts.isEmpty ? loc("ios.focus.goalOptional") : parts.joined(separator: " · ")
    }

    private var lessonRow: some View {
        Button(action: onPickLesson) {
            HStack(spacing: 10) {
                Image(systemName: "book.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.accentInk)
                Text(plan.courseTitle ?? loc("ios.focus.pickLesson"))
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(plan.courseTitle == nil ? MicaboColor.inkSecondary : MicaboColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(MicaboColor.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
        }
        .buttonStyle(HomePressStyle(scale: 0.98))
    }
}

/// **Séance simple ou Pomodoro**, en deux moitiés : la moitié choisie se lève en blanc.
struct FocusModePicker: View {
    @Binding var mode: FocusMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FocusMode.allCases) { option in
                let isOn = option == mode
                Button {
                    withAnimation(MicaboMotion.standard) { mode = option }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: option == .simple ? "timer" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 14, weight: .bold))
                        Text(loc(option == .simple ? "ios.focus.simple" : "ios.focus.pomodoro"))
                            .font(MicaboFont.ui(15, weight: .black))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(isOn ? MicaboColor.accentInk : MicaboColor.inkSecondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background {
                        if isOn {
                            RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                                .fill(MicaboColor.surface)
                                .shadow(color: MicaboBrand.blue900.opacity(0.1), radius: 6, y: 2)
                        }
                    }
                }
                .buttonStyle(HomePressStyle(scale: 0.97, feedback: .selection))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(MicaboColor.surfaceSunken, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
    }
}

/// **Un curseur de la marque**, par crans : la piste bleue, le pouce blanc. Dessiné en SwiftUI
/// (les rendus ne dessinent pas le curseur du système), réglable aussi à la voix.
struct StudySlider: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    private var fraction: CGFloat {
        let span = CGFloat(range.upperBound - range.lowerBound)
        guard span > 0 else { return 0 }
        return CGFloat(value - range.lowerBound) / span
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let thumb: CGFloat = 28
            let x = (width - thumb) * fraction
            ZStack(alignment: .leading) {
                Capsule().fill(MicaboColor.track).frame(height: 8)
                Capsule().fill(MicaboStage.buttonFill).frame(width: x + thumb / 2, height: 8)
                Circle()
                    .fill(Color.white)
                    .frame(width: thumb, height: thumb)
                    .overlay(Circle().strokeBorder(MicaboBrand.blue, lineWidth: 3))
                    .shadow(color: MicaboBrand.blue900.opacity(0.18), radius: 5, y: 2)
                    .offset(x: x)
            }
            .frame(height: thumb)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let ratio = max(0, min(1, (drag.location.x - thumb / 2) / max(1, width - thumb)))
                        let raw = Double(range.lowerBound) + Double(range.upperBound - range.lowerBound) * Double(ratio)
                        let stepped = Int((raw / Double(step)).rounded()) * step
                        let clamped = max(range.lowerBound, min(range.upperBound, stepped))
                        if clamped != value {
                            value = clamped
                            Haptics.selection()
                        }
                    }
            )
        }
        .frame(height: 28)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityValue(Text(CalendarTime.duration(minutes: value)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }
}

/// Le bas de la feuille : « Commencer la session », et l'XP à gagner.
struct FocusStartBar: View {
    let xp: Int
    let onStart: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onStart) {
                Label(loc("ios.focus.begin"), systemImage: "play.fill")
            }
            .buttonStyle(MicaboBrandButtonStyle())
            VStack(spacing: 0) {
                Text(xp > 0 ? "+\(xp) XP" : "XP")
                    .font(MicaboFont.number(17))
                    .foregroundStyle(MicaboColor.accentInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(loc(xp > 0 ? "ios.focus.xpToEarn" : "ios.focus.xpFrom"))
                    .font(MicaboFont.ui(11, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 8)
            .frame(width: 92, height: 56)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous).strokeBorder(MicaboColor.accent.opacity(0.4), lineWidth: 1.5))
            .accessibilityElement(children: .combine)
        }
    }
}
