import SwiftData
import SwiftUI

// MARK: - Aujourd'hui

/// **Une mission du jour** : ce qu'il y a à faire, ce que ça rapporte, et si c'est fait.
/// Tout se lit dans ce que l'app sait déjà — les cartes dues, la leçon en cours, la série —,
/// rien ne vient d'un serveur.
struct HomeMission: Identifiable, Equatable {
    enum Kind: String {
        case cards
        case lesson
        case create
        case streak
    }

    let kind: Kind
    var title: String
    var subtitle: String?
    var icon: MicaboIcon
    var tone: LessonTone
    var reward: HomeRewardChip.Reward
    var done: Bool

    var id: String { kind.rawValue }
}

/// Ce que l'app sait de la journée, et les missions qu'on en tire.
struct HomeDay: Equatable {
    /// Les cartes dues, toutes leçons confondues.
    var dueCount = 0
    /// Les cartes notées aujourd'hui.
    var reviewedToday = 0
    var hasCourses = false
    /// La leçon en cours : son titre et le cercle où elle attend (`nil` une fois terminée).
    var lessonTitle: String?
    var lessonCircle: String?
    /// La leçon a avancé aujourd'hui : terminée aujourd'hui, ou ouverte et travaillée.
    var lessonAdvancedToday = false
    /// Un vrai geste d'étude a allumé la journée (`StudyStreak`).
    var studiedToday = false

    func missions(locale: UiLocale = .resolved()) -> [HomeMission] {
        var missions: [HomeMission] = []
        if dueCount > 0 {
            missions.append(HomeMission(
                kind: .cards,
                title: L10n.t("ios.home2.mission.cards", locale: locale),
                subtitle: L10n.t("ios.kx.today.due", locale: locale, vars: ["count": "\(dueCount)"]),
                icon: .cards,
                tone: .lilac,
                reward: .xp(dueCount * XPRules.cardReviewed),
                done: false
            ))
        } else if reviewedToday > 0 {
            missions.append(HomeMission(
                kind: .cards,
                title: L10n.t("ios.home2.mission.cardsDone", locale: locale),
                subtitle: nil,
                icon: .cards,
                tone: .lilac,
                reward: .xp(reviewedToday * XPRules.cardReviewed),
                done: true
            ))
        }
        if !hasCourses {
            missions.append(HomeMission(
                kind: .create,
                title: L10n.t("ios.kx.today.createFirst", locale: locale),
                subtitle: L10n.t("ios.home2.mission.createSub", locale: locale),
                icon: .quill,
                tone: .blue,
                reward: .xp(XPRules.lessonCreated),
                done: false
            ))
        } else if let lessonTitle, let lessonCircle {
            missions.append(HomeMission(
                kind: .lesson,
                title: lessonAdvancedToday
                    ? L10n.t("ios.home2.mission.circleDone", locale: locale)
                    : L10n.t("ios.home2.mission.circle", locale: locale),
                subtitle: "\(lessonTitle) · \(lessonCircle)",
                icon: .flag,
                tone: .mint,
                reward: .xp(XPRules.circleCompleted),
                done: lessonAdvancedToday
            ))
        }
        missions.append(HomeMission(
            kind: .streak,
            title: studiedToday
                ? L10n.t("ios.home2.mission.streakDone", locale: locale)
                : L10n.t("ios.home2.mission.streak", locale: locale),
            subtitle: studiedToday ? nil : L10n.t("ios.home2.mission.streakSub", locale: locale),
            icon: .flame,
            tone: .pink,
            reward: .streak,
            done: studiedToday
        ))
        return missions
    }
}

/// **« Aujourd'hui », en missions** (`docs/refonte-knowunity.md` § 1.3) : en tête, dans le
/// dégradé de Micabo, l'anneau de l'objectif du jour (`xpToday / 50`) qui se remplit à
/// l'arrivée ; dessous, deux ou trois missions avec leur récompense, cochées une fois faites.
struct HomeTodayCard: View {
    let day: HomeDay
    let motion: HomeMotion
    let onMission: (HomeMission.Kind) -> Void

    @Environment(XPStore.self) private var injected: XPStore?

    private var xp: XPStore { injected ?? .shared }

    var body: some View {
        let today = xp.today
        let missions = day.missions()
        let doneCount = missions.filter(\.done).count
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeader(title: L10n.t("ios.kx.today.title", locale: .resolved())) {
                Text("\(doneCount)/\(missions.count)")
                    .font(MicaboFont.ui(13, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(HomePalette.inkSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(HomePalette.track, in: Capsule())
                    .accessibilityLabel(Text(L10n.t("ios.home2.missions.a11y", locale: .resolved(), vars: ["done": "\(doneCount)", "total": "\(missions.count)"])))
            }
            VStack(spacing: 0) {
                goalHeader(today: today)
                VStack(spacing: 8) {
                    ForEach(missions) { mission in
                        missionRow(mission)
                    }
                }
                .padding(10)
            }
            .homeCard(radius: 28)
        }
    }

    private func goalHeader(today: Int) -> some View {
        let reached = today >= XPRules.dailyGoal
        return HStack(spacing: 14) {
            HomeGoalRing(progress: Double(today) / Double(XPRules.dailyGoal), motion: motion)
            VStack(alignment: .leading, spacing: 2) {
                Text(reached
                    ? L10n.t("ios.kx.today.goalReached", locale: .resolved())
                    : L10n.t("ios.kx.today.goal", locale: .resolved()))
                    .font(MicaboFont.ui(19, weight: .black))
                    .foregroundStyle(Color.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(L10n.t("ios.kx.today.goalProgress", locale: .resolved(), vars: [
                    "xp": "\(min(today, XPRules.dailyGoal))",
                    "goal": "\(XPRules.dailyGoal)",
                ]))
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(today)))
                if !reached {
                    Text(L10n.t("ios.home2.goalLeft", locale: .resolved(), vars: ["n": "\(XPRules.dailyGoal - today)"]))
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
            MikaMascot(mood: reached ? .celebrate : .idle, size: 64, frozenAt: motion.ambient ? nil : 0.4)
                .frame(width: 64, height: 64)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
        .background {
            // La lueur est posée par-dessus l'aplat, pas à côté : dans une pile, ses 180 points
            // agrandiraient le fond au-delà de l'en-tête.
            HomePalette.brand
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(RadialGradient(colors: [Color.white.opacity(0.3), .clear], center: .center, startRadius: 0, endRadius: 90))
                        .frame(width: 180, height: 180)
                        .offset(x: 50, y: -80)
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 27, bottomLeadingRadius: 20, bottomTrailingRadius: 20, topTrailingRadius: 27, style: .continuous))
        }
        .padding([.horizontal, .top], 1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func missionRow(_ mission: HomeMission) -> some View {
        let row = HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(mission.tone.pale)
                MicaboIconView(icon: mission.icon, size: 30)
            }
            .frame(width: 46, height: 46)
            .overlay(alignment: .bottomTrailing) {
                if mission.done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(Color.white)
                        .frame(width: 20, height: 20)
                        .background(HomePalette.done, in: Circle())
                        .overlay(Circle().strokeBorder(HomePalette.card, lineWidth: 2))
                        .offset(x: 5, y: 5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(mission.title)
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(mission.done ? HomePalette.inkSecondary : HomePalette.ink)
                    .strikethrough(mission.done, color: HomePalette.inkTertiary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = mission.subtitle {
                    Text(subtitle)
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(HomePalette.inkSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 4)
            HomeRewardChip(reward: mission.reward, done: mission.done)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(HomePalette.rowFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)

        if mission.done || mission.kind == .streak {
            row
        } else {
            Button { onMission(mission.kind) } label: { row }
                .buttonStyle(HomePressStyle(scale: 0.97, feedback: .soft))
        }
    }
}

/// **L'anneau de l'objectif du jour**, sur le dégradé : blanc sur un creux translucide. Il se
/// remplit à l'arrivée, puis suit chaque gain.
struct HomeGoalRing: View {
    let progress: Double
    let motion: HomeMotion
    var size: CGFloat = 66
    var lineWidth: CGFloat = 8

    @State private var filled = false

    var body: some View {
        let target = max(0, min(1, progress))
        let shown = filled || !motion.entrance ? target : 0
        ZStack {
            Circle().stroke(Color.white.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(
                    LinearGradient(colors: [Color(hex: 0xFFE27A), Color.white], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Color.white.opacity(0.35), radius: 4)
            Image(systemName: target >= 1 ? "checkmark" : "bolt.fill")
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(target >= 1 ? Color.white : HomePalette.bolt)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: shown)
        .onAppear {
            guard motion.entrance, !filled else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { filled = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Les raccourcis

/// **Les outils, en pastilles sous la barre** : « Cartes du jour » quand il y en a, puis
/// Scanner un exo, Quiz éclair, Minuteur, Ligue. Une ligne qui défile, posée sur le ciel.
struct HomeToolChips: View {
    let dueCount: Int
    let motion: HomeMotion
    let onReview: () -> Void
    let onTool: (HomeToolsGrid.Tool) -> Void

    var body: some View {
        if motion.still {
            // Les rendus ne dessinent pas une ligne qui défile : la même ligne, coupée au bord.
            Color.clear
                .frame(height: 46)
                .overlay(alignment: .leading) {
                    chips.fixedSize().padding(.horizontal, MicaboSpacing.screen)
                }
                .clipped()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                chips.padding(.horizontal, MicaboSpacing.screen)
            }
            .scrollClipDisabled()
        }
    }

    private var chips: some View {
        HStack(spacing: 8) {
            if dueCount > 0 {
                chip(
                    icon: .cards,
                    tone: .lilac,
                    title: L10n.t("ios.home2.tool.due", locale: .resolved()),
                    badge: dueCount,
                    action: onReview
                )
            }
            ForEach(HomeToolsGrid.Tool.allCases, id: \.self) { tool in
                chip(icon: Self.icon(tool), tone: Self.tone(tool), title: Self.title(tool), badge: nil) { onTool(tool) }
            }
        }
    }

    private func chip(icon: MicaboIcon, tone: LessonTone, title: String, badge: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                MicaboIconView(icon: icon, size: 22)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(colors: [tone.vivid.opacity(0.95), tone.vivid.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle()
                    )
                Text(title)
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(HomePalette.heroInk)
                    .lineLimit(1)
                if let badge {
                    Text("\(badge)")
                        .font(MicaboFont.ui(12, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 7)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(MicaboColor.flame, in: Capsule())
                }
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .frame(height: 44)
            .homeGlass(Capsule())
        }
        .buttonStyle(HomePressStyle(scale: 0.93))
    }

    static func icon(_ tool: HomeToolsGrid.Tool) -> MicaboIcon {
        switch tool {
        case .scan: .photo
        case .quiz: .quiz
        case .timer: .alarm
        case .league: .trophy
        }
    }

    static func tone(_ tool: HomeToolsGrid.Tool) -> LessonTone {
        switch tool {
        case .scan: .blue
        case .quiz: .pink
        case .timer: .mint
        case .league: .yellow
        }
    }

    static func title(_ tool: HomeToolsGrid.Tool) -> String {
        switch tool {
        case .scan: L10n.t("ios.kx.tools.scan.title", locale: .resolved())
        case .quiz: L10n.t("ios.kx.tools.quiz.title", locale: .resolved())
        case .timer: L10n.t("ios.kx.tools.timer.title", locale: .resolved())
        case .league: L10n.t("ios.kx.tools.league.title", locale: .resolved())
        }
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
