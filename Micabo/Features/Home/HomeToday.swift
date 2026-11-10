import SwiftData
import SwiftUI

// MARK: - Aujourd'hui

/// Ce que l'app sait de la journée, et la seule chose qu'on en tire : **la prochaine étape**.
/// Tout se lit dans ce que l'app sait déjà — les cartes dues, la leçon en cours, la série —,
/// rien ne vient d'un serveur.
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

    /// Une étape de la journée.
    enum Step: String, Equatable {
        /// Écrire une leçon : la première, ou la suivante.
        case create
        /// Reprendre la leçon en cours, au cercle où elle attend.
        case lesson
        /// Réviser les cartes dues.
        case cards
    }

    private var hasOpenLesson: Bool { lessonTitle != nil && lessonCircle != nil }

    /// **La prochaine chose à faire**, et la seule que la carte met en avant : la leçon en
    /// cours tant qu'elle n'a pas avancé aujourd'hui, puis les cartes dues, puis la leçon ;
    /// sans leçon, en écrire une.
    var primary: Step {
        guard hasCourses else { return .create }
        if hasOpenLesson && !lessonAdvancedToday { return .lesson }
        if dueCount > 0 { return .cards }
        if hasOpenLesson { return .lesson }
        return .create
    }

    /// **Une seconde ligne, au plus** : ce qui reste d'utile à côté de l'étape mise en avant.
    var secondary: Step? {
        switch primary {
        case .lesson: dueCount > 0 ? .cards : nil
        case .cards: hasOpenLesson ? .lesson : nil
        case .create: dueCount > 0 ? .cards : nil
        }
    }
}

/// **« Aujourd'hui »** (`docs/refonte-knowunity.md` § 1.3) : en tête, l'anneau de l'objectif
/// du jour (`xpToday / 50`) qui se remplit à l'arrivée ; dessous, **une seule** étape, avec
/// son bouton — reprendre la leçon, réviser les cartes, ou écrire une leçon — et au plus une
/// ligne de plus. Une carte, une décision.
struct HomeTodayCard: View {
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
    let motion: HomeMotion
    let onStep: (HomeDay.Step) -> Void

    @Environment(XPStore.self) private var injected: XPStore?

    private var xp: XPStore { injected ?? .shared }

    var body: some View {
        let primary = day.primary
        VStack(alignment: .leading, spacing: 16) {
            goalHeader(today: xp.today)
            stepBlock(primary)
            Button { onStep(primary) } label: {
                Text(cta(primary))
            }
            .buttonStyle(MicaboBrandButtonStyle(minHeight: 52))
            if let secondary = day.secondary {
                secondaryRow(secondary)
            }
        }
        .padding(18)
        .homeCard()
    }

    // MARK: L'objectif

    private func goalHeader(today: Int) -> some View {
        let reached = today >= XPRules.dailyGoal
        let progress = L10n.t("ios.kx.today.goalProgress", locale: .resolved(), vars: [
            "xp": "\(min(today, XPRules.dailyGoal))",
            "goal": "\(XPRules.dailyGoal)",
        ])
        let detail = reached
            ? "\(L10n.t("ios.kx.today.goalReached", locale: .resolved())) · \(progress)"
            : "\(progress) · \(L10n.t("ios.home2.goalLeft", locale: .resolved(), vars: ["n": "\(XPRules.dailyGoal - today)"]))"
        return HStack(spacing: 14) {
            HomeGoalRing(progress: Double(today) / Double(XPRules.dailyGoal), motion: motion)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.t("ios.kx.today.title", locale: .resolved()))
                    .font(MicaboFont.ui(21, weight: .black))
                    .foregroundStyle(HomePalette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(reached ? HomePalette.done : HomePalette.inkSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: L'étape

    @ViewBuilder
    private func stepBlock(_ step: HomeDay.Step) -> some View {
        HStack(alignment: .center, spacing: 14) {
            stepIcon(step)
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow = eyebrow(step) {
                    Text(eyebrow)
                        .font(MicaboFont.ui(12, weight: .black))
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(MicaboColor.accentInk)
                        .lineLimit(1)
                }
                Text(title(step))
                    .font(MicaboFont.ui(17, weight: .black))
                    .foregroundStyle(HomePalette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle(step))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(HomePalette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if step == .lesson, let resume {
                    lessonProgress(resume.1, tone: resume.0.tone)
                        .padding(.top, 5)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MicaboColor.canvas.opacity(0.7), in: RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func stepIcon(_ step: HomeDay.Step) -> some View {
        ZStack {
            switch step {
            case .lesson:
                let tone = resume?.0.tone ?? .blue
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [tone.vivid.opacity(0.95), tone.vivid.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                MicaboIconView(icon: resume?.0.icon ?? .book, size: 38)
            case .cards:
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(LessonTone.lilac.pale)
                MicaboIconView(icon: .cards, size: 36)
            case .create:
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(MicaboColor.accentSoft)
                MicaboIconView(icon: .quill, size: 36)
            }
        }
        .frame(width: 60, height: 60)
    }

    private func lessonProgress(_ target: ResumeTarget, tone: LessonTone) -> some View {
        HStack(spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(HomePalette.track)
                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: max(7, proxy.size.width * CGFloat(target.percent) / 100))
                }
            }
            .frame(height: 7)
            Text(L10n.percent(target.percent, locale: .resolved()))
                .font(MicaboFont.ui(12, weight: .black))
                .foregroundStyle(MicaboColor.accentInk)
                .monospacedDigit()
                .fixedSize()
        }
    }

    private func eyebrow(_ step: HomeDay.Step) -> String? {
        switch step {
        case .lesson: L10n.t("lesson.home.resume", locale: .resolved())
        case .cards: L10n.t("ios.home2.tool.due", locale: .resolved())
        case .create: nil
        }
    }

    private func title(_ step: HomeDay.Step) -> String {
        switch step {
        case .lesson: resume?.1.title ?? day.lessonTitle ?? ""
        case .cards: L10n.t("ios.kx.today.due", locale: .resolved(), vars: ["count": "\(day.dueCount)"])
        case .create: day.hasCourses
            ? L10n.t("ios.home3.create.next", locale: .resolved())
            : L10n.t("ios.kx.today.createFirst", locale: .resolved())
        }
    }

    private func subtitle(_ step: HomeDay.Step) -> String {
        switch step {
        case .lesson:
            guard let target = resume?.1, let number = target.circleNumber, let title = target.circleTitle else {
                return day.lessonCircle ?? ""
            }
            return L10n.t("lesson.home.resumeCircle", locale: .resolved(), vars: ["n": String(number), "title": title])
        case .cards: return L10n.t("ios.home3.cards.sub", locale: .resolved())
        case .create: return L10n.t("ios.home2.mission.createSub", locale: .resolved())
        }
    }

    private func cta(_ step: HomeDay.Step) -> String {
        switch step {
        case .lesson: L10n.t("ios.home3.cta.continue", locale: .resolved())
        case .cards: L10n.t("ios.home3.cta.review", locale: .resolved())
        case .create: L10n.t("ios.home3.cta.create", locale: .resolved())
        }
    }

    // MARK: La seconde ligne

    private func secondaryRow(_ step: HomeDay.Step) -> some View {
        Button { onStep(step) } label: {
            HStack(spacing: 10) {
                MicaboIconView(icon: step == .cards ? .cards : (resume?.0.icon ?? .book), size: 24)
                Text(step == .cards
                    ? L10n.t("ios.kx.today.due", locale: .resolved(), vars: ["count": "\(day.dueCount)"])
                    : L10n.t("ios.kx.today.continue", locale: .resolved(), vars: ["lesson": resume?.1.title ?? day.lessonTitle ?? ""]))
                    .font(MicaboFont.ui(15, weight: .heavy))
                    .foregroundStyle(HomePalette.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .black))
                    .foregroundStyle(HomePalette.inkTertiary)
            }
            .padding(.horizontal, 4)
            .frame(minHeight: 36)
        }
        .buttonStyle(HomePressStyle(scale: 0.98, feedback: .soft))
    }
}

/// **L'anneau de l'objectif du jour** : le bleu de la marque sur un creux, l'éclair jaune du
/// crayon au milieu, une coche une fois atteint. Il se remplit à l'arrivée, puis suit chaque
/// gain.
struct HomeGoalRing: View {
    let progress: Double
    let motion: HomeMotion
    var size: CGFloat = 58
    var lineWidth: CGFloat = 7

    @State private var filled = false

    var body: some View {
        let target = max(0, min(1, progress))
        let shown = filled || !motion.entrance ? target : 0
        ZStack {
            Circle().stroke(HomePalette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(
                    target >= 1 ? AnyShapeStyle(MicaboColor.correct) : AnyShapeStyle(MicaboStage.buttonFill),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Image(systemName: target >= 1 ? "checkmark" : "bolt.fill")
                .font(.system(size: size * 0.32, weight: .black))
                .foregroundStyle(target >= 1 ? MicaboColor.correct : HomePalette.bolt)
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

// MARK: - Les outils

/// Les outils de Home, hors de la leçon.
enum HomeTool: CaseIterable {
    case scan
    case quiz
    case timer
    case league

    var icon: MicaboIcon {
        switch self {
        case .scan: .photo
        case .quiz: .quiz
        case .timer: .alarm
        case .league: .trophy
        }
    }

    var tone: LessonTone {
        switch self {
        case .scan: .blue
        case .quiz: .pink
        case .timer: .mint
        case .league: .yellow
        }
    }

    var title: String {
        switch self {
        case .scan: L10n.t("ios.kx.tools.scan.title", locale: .resolved())
        case .quiz: L10n.t("ios.kx.tools.quiz.title", locale: .resolved())
        case .timer: L10n.t("ios.kx.tools.timer.title", locale: .resolved())
        case .league: L10n.t("ios.kx.tools.league.title", locale: .resolved())
        }
    }
}

/// **Les outils, en quatre tuiles** : Scanner un exo, Quiz éclair, Minuteur, Ligue. Une icône
/// sur sa pastille de couleur, le nom dessous, sur deux lignes au plus : les quatre tiennent
/// sur la largeur dans toutes les langues, sans rien faire défiler.
struct HomeToolsRow: View {
    let onTool: (HomeTool) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(HomeTool.allCases, id: \.self) { tool in
                Button { onTool(tool) } label: { tile(tool) }
                    .buttonStyle(HomePressStyle(scale: 0.94, feedback: .soft))
                    .accessibilityLabel(Text(tool.title))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func tile(_ tool: HomeTool) -> some View {
        VStack(spacing: 7) {
            MicaboIconView(icon: tool.icon, size: 28)
                .frame(width: 46, height: 46)
                .background(tool.tone.pale, in: Circle())
            Text(tool.title)
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(HomePalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .homeCard(radius: MicaboStage.tileRadius)
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
