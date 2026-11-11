import SwiftUI

// MARK: - Le bonjour

/// **Le bonjour et l'objectif du jour**, sur la page, sous la rangée du haut : « Bonsoir Léa »,
/// l'XP du jour sur l'objectif, et l'anneau qui se remplit. Le seul chiffre du jour sur Home.
struct HomeGreetingRow: View {
    let title: String
    let motion: HomeMotion

    @Environment(XPStore.self) private var injected: XPStore?

    private var xp: XPStore { injected ?? .shared }

    var body: some View {
        let today = xp.today
        let reached = today >= XPRules.dailyGoal
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MicaboFont.ui(26, weight: .black))
                    .foregroundStyle(HomePalette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(detail(today: today, reached: reached))
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(reached ? HomePalette.done : HomePalette.inkSecondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            HomeGoalRing(progress: Double(today) / Double(XPRules.dailyGoal), motion: motion, size: 48, lineWidth: 6)
        }
        .accessibilityElement(children: .combine)
    }

    private func detail(today: Int, reached: Bool) -> String {
        let progress = L10n.t("ios.kx.today.goalProgress", locale: .resolved(), vars: [
            "xp": "\(min(today, XPRules.dailyGoal))",
            "goal": "\(XPRules.dailyGoal)",
        ])
        return reached
            ? "\(L10n.t("ios.kx.today.goalReached", locale: .resolved())) · \(progress)"
            : "\(progress) · \(L10n.t("ios.home2.goalLeft", locale: .resolved(), vars: ["n": "\(XPRules.dailyGoal - today)"]))"
    }
}

// MARK: - Le plan du jour

/// **« Ton plan du jour »**, sur une carte claire de la page, pour l'élève qui a déjà ses
/// leçons (`docs/refonte-knowunity.md` § 1 et § 9) :
/// 1. en haut, le prochain examen dans sa tuile bleu pâle — le compte à rebours dans sa
///    pastille bleue, le nom, la préparation —, ou, sans examen, « Ton plan du jour » et une
///    pilule discrète « Ajouter un examen » ;
/// 2. **la** chose à faire maintenant (`HomeDay.primary`) : la séance du calendrier, la leçon
///    en cours ou les cartes dues ;
/// 3. **un** grand bouton bleu, le seul de l'écran, et Mika qui dépasse de son bord, noir sur
///    le blanc de la carte ;
/// 4. au plus une seconde ligne (`HomeDay.secondary`).
struct HomePlanHero: View {
    let day: HomeDay
    let resume: (Course, ResumeTarget)?
    let exam: HomeExam?
    let motion: HomeMotion
    let onStep: (HomeDay.Step, HomeSlot) -> Void
    let onExam: () -> Void
    let onAddExam: () -> Void

    static let mikaSize: CGFloat = 104
    /// Ce qui passe derrière le bouton : le bas du buste. Assez peu pour que ses yeux
    /// dépassent.
    static let mikaSink: CGFloat = 12
    /// La place que le buste prend à droite du texte.
    static let mikaReserve: CGFloat = 86

    var body: some View {
        let primary = day.primary
        VStack(alignment: .leading, spacing: 0) {
            if let exam {
                examPanel(exam)
                    .padding(.bottom, 16)
            } else {
                planHeader
                    .padding(.bottom, 12)
            }
            stepBlock(primary)
                .padding(.bottom, 14)
            cta(primary)
            if let secondary = day.secondary {
                secondaryRow(secondary)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .homeCard(radius: MicaboStage.cardRadius)
    }

    // MARK: L'examen

    private func examPanel(_ exam: HomeExam) -> some View {
        Button(action: onExam) {
            HStack(spacing: 12) {
                HomeCountdownBadge(daysLeft: exam.daysLeft, side: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("ios.cal.nextExam", locale: .resolved()))
                        .font(MicaboFont.ui(11.5, weight: .black))
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(MicaboColor.accentInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(exam.name)
                        .font(MicaboFont.ui(17, weight: .black))
                        .foregroundStyle(HomePalette.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let readiness = exam.readiness {
                        readinessBar(readiness)
                            .padding(.top, 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(HomePalette.inkTertiary)
            }
            .padding(10)
            .padding(.trailing, 4)
            .background(MicaboColor.accentWash, in: RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous))
        }
        .buttonStyle(HomePressStyle(scale: 0.98, feedback: .selection))
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(L10n.t("ios.home4.agenda.calendar", locale: .resolved())))
    }

    private func readinessBar(_ value: Int) -> some View {
        HStack(spacing: 8) {
            Text(L10n.t("ios.cal.readiness", locale: .resolved()))
                .font(MicaboFont.ui(12, weight: .heavy))
                .foregroundStyle(HomePalette.inkSecondary)
                .lineLimit(1)
                .fixedSize()
            HomeBar(percent: value, track: MicaboColor.accent.opacity(0.16))
            Text(L10n.percent(value, locale: .resolved()))
                .font(MicaboFont.ui(12, weight: .black))
                .foregroundStyle(MicaboColor.accentInk)
                .monospacedDigit()
                .fixedSize()
        }
    }

    /// Sans examen : le nom du bloc, et la pilule qui en ajoute un — à côté quand les deux
    /// tiennent sur une ligne, dessous sinon (l'allemand, le finnois).
    private var planHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                planTitle.fixedSize()
                Spacer(minLength: 4)
                addExamPill
            }
            VStack(alignment: .leading, spacing: 8) {
                planTitle.fixedSize(horizontal: false, vertical: true)
                addExamPill
            }
        }
    }

    private var planTitle: some View {
        Text(L10n.t("ios.home4.plan.title", locale: .resolved()))
            .font(MicaboFont.ui(15, weight: .black))
            .foregroundStyle(HomePalette.inkSecondary)
            .accessibilityAddTraits(.isHeader)
    }

    private var addExamPill: some View {
        Button(action: onAddExam) {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .black))
                Text(L10n.t("ios.home4.exam.add", locale: .resolved()))
                    .font(MicaboFont.ui(13.5, weight: .heavy))
                    .lineLimit(1)
            }
            .foregroundStyle(MicaboColor.accentInk)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(MicaboColor.accentSoft, in: Capsule())
            .fixedSize()
        }
        .buttonStyle(HomePressStyle(scale: 0.94, feedback: .selection))
    }

    // MARK: L'étape

    private func stepBlock(_ step: HomeDay.Step) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow(step))
                .font(MicaboFont.ui(12, weight: .black))
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.accentInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title(step))
                .font(MicaboFont.ui(23, weight: .black))
                .foregroundStyle(HomePalette.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle = subtitle(step) {
                Text(subtitle)
                    .font(MicaboFont.ui(14.5, weight: .bold))
                    .foregroundStyle(HomePalette.inkSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if step == .lesson, let target = resume?.1 {
                lessonProgress(target)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.mikaSize - Self.mikaSink - 14, alignment: .bottomLeading)
        .padding(.trailing, Self.mikaReserve)
        .accessibilityElement(children: .combine)
    }

    private func lessonProgress(_ target: ResumeTarget) -> some View {
        HStack(spacing: 8) {
            HomeBar(percent: target.percent, track: HomePalette.track)
            Text(L10n.percent(target.percent, locale: .resolved()))
                .font(MicaboFont.ui(12, weight: .black))
                .foregroundStyle(MicaboColor.accentInk)
                .monospacedDigit()
                .fixedSize()
        }
    }

    private func eyebrow(_ step: HomeDay.Step) -> String {
        switch step {
        case .session:
            L10n.t("ios.focus.nextRevision", locale: .resolved(), vars: ["time": CalendarTime.label(minute: day.session?.startMinute ?? 0)])
        case .lesson: L10n.t("lesson.home.resume", locale: .resolved())
        case .cards: L10n.t("ios.home2.tool.due", locale: .resolved())
        case .create: L10n.t("lesson.lessons.new", locale: .resolved())
        }
    }

    private func title(_ step: HomeDay.Step) -> String {
        switch step {
        case .session: day.session?.title ?? ""
        case .lesson: resume?.1.title ?? day.lessonTitle ?? ""
        case .cards: L10n.t("ios.kx.today.due", locale: .resolved(), vars: ["count": "\(day.dueCount)"])
        case .create: L10n.t("ios.home3.create.next", locale: .resolved())
        }
    }

    private func subtitle(_ step: HomeDay.Step) -> String? {
        switch step {
        case .session:
            guard let session = day.session else { return nil }
            let length = CalendarTime.duration(minutes: session.minutes)
            guard let exam = session.examName?.nilIfBlank else { return length }
            return "\(length) · \(exam)"
        case .lesson:
            guard let target = resume?.1, let number = target.circleNumber, let title = target.circleTitle else {
                return day.lessonCircle
            }
            return L10n.t("lesson.home.resumeCircle", locale: .resolved(), vars: ["n": String(number), "title": title])
        case .cards: return L10n.t("ios.home3.cards.sub", locale: .resolved())
        case .create: return L10n.t("ios.home2.mission.createSub", locale: .resolved())
        }
    }

    // MARK: Le bouton

    /// Le bouton bleu passe devant le bas du buste : Mika dépasse de son bord, sur le blanc de
    /// la carte, comme sur Concentration.
    private func cta(_ step: HomeDay.Step) -> some View {
        Button { onStep(step, .hero) } label: {
            Label(ctaTitle(step), systemImage: ctaIcon(step))
        }
        .buttonStyle(MicaboBrandButtonStyle(minHeight: 54))
        .background(alignment: .topTrailing) {
            MikaMascot(
                mood: step == .session ? .wave : .idle,
                size: Self.mikaSize,
                frozenAt: motion.still ? 0.5 : nil
            )
            .offset(x: -2, y: -Self.mikaSize + Self.mikaSink)
            .accessibilityHidden(true)
        }
    }

    private func ctaTitle(_ step: HomeDay.Step) -> String {
        switch step {
        case .session: L10n.t("ios.cal.startSession", locale: .resolved())
        case .lesson: L10n.t("ios.home3.cta.continue", locale: .resolved())
        case .cards: L10n.t("ios.home3.cta.review", locale: .resolved())
        case .create: L10n.t("ios.home3.cta.create", locale: .resolved())
        }
    }

    private func ctaIcon(_ step: HomeDay.Step) -> String {
        switch step {
        case .session, .lesson: "play.fill"
        case .cards: "rectangle.on.rectangle.angled"
        case .create: "plus"
        }
    }

    // MARK: La seconde ligne

    private func secondaryRow(_ step: HomeDay.Step) -> some View {
        Button { onStep(step, .secondary) } label: {
            HStack(spacing: 10) {
                MicaboIconView(icon: step == .cards ? .cards : (resume?.0.icon ?? .book), size: 22)
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
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(HomePalette.canvas, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(HomePressStyle(scale: 0.98, feedback: .soft))
    }
}

/// **Le compte à rebours d'un examen**, dans sa pastille bleue : le nombre de jours en blanc,
/// « jours » dessous. Le même sur Home et dans le Calendrier.
struct HomeCountdownBadge: View {
    let daysLeft: Int
    var side: CGFloat = 58

    var body: some View {
        VStack(spacing: -1) {
            if daysLeft <= 0 {
                Text(L10n.t("ios.cal.examToday", locale: .resolved()))
                    .font(MicaboFont.ui(side * 0.21, weight: .black))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
            } else {
                Text("\(daysLeft)")
                    .font(MicaboFont.number(side * 0.41))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(L10n.t(daysLeft == 1 ? "ios.cal.dayLeft" : "ios.cal.daysLeft", locale: .resolved()))
                    .font(MicaboFont.ui(side * 0.18, weight: .black))
                    .opacity(0.88)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 4)
        .frame(width: side, height: side)
        .background(MicaboStage.fill, in: RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
        .shadow(color: MicaboBrand.blue.opacity(0.25), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
    }
}

/// Une barre de progression fine : la piste, et le bleu de l'accent jusqu'au pourcentage.
struct HomeBar: View {
    let percent: Int
    var track: Color = HomePalette.track
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(width: max(height, proxy.size.width * CGFloat(min(100, max(0, percent))) / 100))
            }
        }
        .frame(height: height)
    }
}

// MARK: - L'agenda d'aujourd'hui

/// **« Aujourd'hui »** : ce qui reste à l'agenda du jour, trois lignes au plus, dessinées comme
/// dans le calendrier (`AgendaRow`), et le chemin vers le calendrier.
struct HomeAgendaSection: View {
    let items: [AgendaItem]
    let onTap: (AgendaItem) -> Void
    let onStart: (AgendaItem) -> Void
    let onToggle: (AgendaItem) -> Void
    let onCalendar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: L10n.t("ios.kx.today.title", locale: .resolved())) {
                HomeSectionLink(title: L10n.t("ios.home4.agenda.calendar", locale: .resolved()), action: onCalendar)
            }
            VStack(spacing: 8) {
                ForEach(items) { item in
                    AgendaRow(item: item, onTap: { onTap(item) }, onStart: { onStart(item) }, onToggle: { onToggle(item) })
                }
            }
        }
    }
}

/// Le lien d'un titre de section : le texte bleu et son chevron.
struct HomeSectionLink: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                    .lineLimit(1)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 11, weight: .black))
            }
            .font(MicaboFont.ui(14, weight: .heavy))
            .foregroundStyle(MicaboColor.accentInk)
            .frame(minHeight: 32)
            .fixedSize()
        }
        .buttonStyle(HomePressStyle(scale: 0.95, feedback: .selection))
    }
}

// MARK: - Mes leçons

/// **« Mes leçons »** : les leçons récentes en cartes qu'on fait glisser, chacune avec sa
/// progression ; « Tout voir » ouvre l'onglet Leçons.
struct HomeLessonsSection: View {
    let lessons: [HomeLessonCard]
    let onOpen: (UUID) -> Void
    let onAll: () -> Void

    @Environment(\.homeStill) private var still

    static let cardWidth: CGFloat = 160

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: L10n.t("ios.home4.lessons", locale: .resolved())) {
                HomeSectionLink(title: L10n.t("ios.focus.seeAll", locale: .resolved()), action: onAll)
            }
            if still, let first = lessons.first {
                // Les rendus ne dessinent pas ce qui défile : la même rangée, qui déborde. Une
                // carte cachée donne la hauteur ; la rangée est posée par-dessus, sans élargir
                // la page.
                card(first)
                    .hidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) { row.fixedSize() }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    row
                }
                .scrollClipDisabled()
            }
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(lessons) { lesson in
                Button { onOpen(lesson.id) } label: { card(lesson) }
                    .buttonStyle(HomePressStyle(scale: 0.96, feedback: .soft))
            }
        }
    }

    private func card(_ lesson: HomeLessonCard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [lesson.tone.vivid.opacity(0.95), lesson.tone.vivid.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                MicaboIconView(icon: lesson.icon, size: 28)
            }
            .frame(width: 46, height: 46)
            Text(lesson.title)
                .font(MicaboFont.ui(15.5, weight: .black))
                .foregroundStyle(HomePalette.ink)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(HomePalette.track)
                        Capsule()
                            .fill(lesson.percent >= 100 ? AnyShapeStyle(MicaboColor.correct) : AnyShapeStyle(MicaboColor.accent))
                            .frame(width: max(6, proxy.size.width * CGFloat(min(100, lesson.percent)) / 100))
                    }
                }
                .frame(height: 6)
                Text(L10n.percent(lesson.percent, locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .black))
                    .foregroundStyle(lesson.percent >= 100 ? HomePalette.done : MicaboColor.accentInk)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
        .padding(14)
        .frame(width: Self.cardWidth, alignment: .leading)
        .homeCard(radius: MicaboStage.tileRadius)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Une nouvelle leçon

/// **« Nouvelle leçon »**, en second : la même barre que sur la scène (`HomeComposerBar`), sur
/// une seule ligne. L'envoi passe par la même porte du gratuit (`HomeView.send`), le « + » par
/// la même feuille des supports.
struct HomeCreateSection: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onSources: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: L10n.t("lesson.lessons.new", locale: .resolved()))
            HomeComposerBar(composer: composer, focused: focused, onSend: onSend, onSources: onSources, compact: true)
            if !composer.hasRoom {
                Text(L10n.t("lesson.home.supportsFull", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(HomePalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Comment ça marche

/// **« Comment ça marche »**, pour l'élève tout neuf, sous la scène : trois pas, calmes.
struct HomeHowItWorks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("ios.home4.how.title", locale: .resolved()))
                .font(MicaboFont.ui(19, weight: .black))
                .foregroundStyle(HomePalette.ink)
                .accessibilityAddTraits(.isHeader)
            ForEach(1...3, id: \.self) { step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(step)")
                        .font(MicaboFont.number(15))
                        .foregroundStyle(Color.white)
                        .frame(width: 30, height: 30)
                        .background(HomePalette.brand, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("ios.home4.how.step\(step)", locale: .resolved()))
                            .font(MicaboFont.ui(16, weight: .black))
                            .foregroundStyle(HomePalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.t("ios.home4.how.step\(step)Sub", locale: .resolved()))
                            .font(MicaboFont.ui(14, weight: .semibold))
                            .foregroundStyle(HomePalette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeCard()
    }
}
