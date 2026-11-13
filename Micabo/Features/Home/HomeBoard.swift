import Foundation

// **Ce que la Home dit et propose, calculé sans écran** (lot 10, HOME.md § 1).
//
// La Home ne défile pas et ne dit qu'une chose : sous l'examen qui approche, Mika, **une**
// phrase tirée du plan du jour et **une** action. Tout ce qu'elle montre se décide ici, d'après
// ce que l'app sait déjà (la séance du calendrier, les cartes dues, la leçon en cours, la
// série, la leçon qui s'écrit) : l'écran ne fait que dessiner, et les tests lisent les mêmes
// valeurs que lui.

// MARK: - La génération

/// Où en est la leçon que la Home écrit (`LessonGeneration`).
enum LessonGenerationPhase: Equatable {
    case idle
    /// Hors ligne : la demande attend, et part dès que le réseau revient.
    case waiting
    case running
    /// L'écriture a échoué : la phrase de la panne, pour l'écran.
    case failed(String)
}

/// **Une leçon lue, pas encore écrite** : la leçon offerte a servi, les supports ont été lus sur
/// l'appareil, et l'écriture attend Pro (`LessonAllowance.sendRoute`). Les chiffres sont ceux
/// de la lecture (`LessonReadSummary`), rien n'est inventé.
struct HomeLockedLesson: Equatable {
    var supports: Int
    var pages: Int
    var words: Int
    /// La date d'examen donnée avant l'aperçu : la leçon part avec elle une fois débloquée.
    var examDate: Date?

    init(summary: LessonReadSummary, examDate: Date?) {
        supports = summary.supports
        pages = summary.pages
        words = summary.words
        self.examDate = examDate
    }

    init(supports: Int, pages: Int, words: Int, examDate: Date? = nil) {
        self.supports = supports
        self.pages = pages
        self.words = words
        self.examDate = examDate
    }

    /// « 4 pages lues · 290 mots lus ». Une vidéo ou un texte collé n'ont pas de pages.
    func detail(locale: UiLocale = .resolved()) -> String {
        var parts: [String] = []
        if pages > 0 {
            parts.append(L10n.t("ios.conv.locked.pages", locale: locale, vars: ["count": String(pages)]))
        }
        parts.append(L10n.t("ios.conv.locked.words", locale: locale, vars: ["count": String(words)]))
        return parts.joined(separator: " · ")
    }
}

// MARK: - Le moment

/// **Ce que la Home met en avant**, par ordre de priorité : une leçon qui s'écrit (ou qui
/// attend) passe devant tout ; puis la séance prévue aujourd'hui, les cartes dues, la leçon en
/// cours ; sinon la journée est faite, ou rien n'est prévu. Le nouvel élève, lui, n'a pas
/// encore de plan : Mika lui propose sa première leçon.
enum HomeMoment: String, Equatable, CaseIterable {
    case generating
    case waiting
    case failed
    case locked
    case session
    case cards
    case lesson
    case done
    case open
    case newcomer
}

/// **La phrase de la Home** : deux lignes, son mot-clé écrit entre deux paires d'astérisques
/// (l'écran le peint en bleu clair), et l'humeur de Mika qui va avec.
struct HomePhrase: Equatable {
    var marked: String
    var mood: MikaMood

    /// La phrase sans ses marques, pour VoiceOver et pour les tests.
    var plain: String {
        marked.replacingOccurrences(of: "**", with: "")
    }

    /// Le groupe de mots mis en avant, s'il y en a un.
    var keyword: String? {
        let parts = marked.components(separatedBy: "**")
        guard parts.count >= 3 else { return nil }
        let word = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        return word.isEmpty ? nil : word
    }
}

/// **L'action de la Home.** Il n'y en a qu'une à la fois.
struct HomeAction: Equatable {
    enum Kind: String, Equatable, CaseIterable {
        /// Lancer la séance de révision du calendrier.
        case session
        /// Réviser les cartes dues.
        case cards
        /// Ouvrir la leçon en cours, à son étape.
        case lesson
        /// « Réviser quand même » : la dernière leçon, quand rien ne presse.
        case more
        /// « Nouvelle leçon » : la feuille des sources, pour qui n'a aucune leçon ouverte.
        case create
        /// « Créer ma première leçon » : la feuille des sources.
        case first
        /// « Débloquer ma leçon » : le paywall `lessonReady`.
        case unlock
        /// « Réessayer » une leçon qui n'a pas pu s'écrire, ou qui attend le réseau.
        case retry
    }

    var kind: Kind
    var title: String
    /// Le pictogramme posé devant le libellé (SF Symbols).
    var symbol: String

    /// Le nom du geste dans `home_plan_tapped` : `session`, `lesson`, `cards` et `create`
    /// gardent le leur ; les nouveaux ont le nom de leur cas. Des valeurs fixes.
    var analyticsStep: String {
        kind == .first ? "create" : kind.rawValue
    }
}

/// **L'issue discrète sous l'action** : abandonner la leçon qui s'écrit, ou remettre à plus
/// tard celle qui attend Pro.
struct HomeExit: Equatable {
    enum Kind: String, Equatable {
        case cancel
        case later
    }

    var kind: Kind
    var title: String
}

/// Ce que la Home sait au moment de se dessiner.
struct HomeBoardInput: Equatable {
    var day = HomeDay()
    /// Le prénom, s'il a été donné.
    var name: String?
    var greeting: HomeGreeting.Moment = .day
    var phase: LessonGenerationPhase = .idle
    var stage: LessonBuilder.Stage?
    /// Ce que la leçon en cours d'écriture raconte : le sujet tapé, ou le nom du support. Il
    /// reste sur l'appareil.
    var subject: String?
    var hasSupports = false
    var locked: HomeLockedLesson?
    /// Une leçon peut s'ouvrir pour « Réviser quand même ».
    var hasLesson = false
}

/// **La Home, comme une valeur** : le moment, la phrase, et l'action — ou la jauge, pendant
/// qu'une leçon s'écrit.
struct HomeBoard: Equatable {
    var moment: HomeMoment
    var phrase: HomePhrase
    /// **La** pilule sous la phrase. `nil` pendant qu'une leçon s'écrit (la jauge prend sa
    /// place), et quand la journée est faite sans rien à rouvrir.
    var action: HomeAction?
    /// L'avancée de l'écriture, de 0 à 1 : une valeur par étape du vrai travail
    /// (`LessonBuilder.Stage`), aucune horloge.
    var progress: Double?
    /// Une ligne de soutien : l'étape en cours de l'écriture, la panne, ce qui a été lu.
    var caption: String?
    var exit: HomeExit?

    /// Les titres de leçon et les sujets tapés tiennent dans une phrase de deux lignes : au-delà,
    /// ils sont coupés d'une ellipse.
    static let keywordLimit = 34

    static func resolve(_ input: HomeBoardInput, locale: UiLocale = .resolved()) -> HomeBoard {
        let moment = HomeBoard.moment(for: input)
        func t(_ key: String, _ vars: [String: String] = [:]) -> String {
            L10n.t(key, locale: locale, vars: vars)
        }
        let name = input.name?.nilIfBlank
        let day = input.day
        let cancel = HomeExit(kind: .cancel, title: t("lesson.create.cancel"))
        let retry = HomeAction(kind: .retry, title: t("lesson.path.retry"), symbol: "arrow.clockwise")
        let more = HomeAction(kind: .more, title: t("ios.home10.cta.more"), symbol: "arrow.clockwise")

        switch moment {
        case .generating:
            let subject = input.subject?.nilIfBlank.map { clip($0) }
            let marked = subject.map { t("ios.home10.ask.generating", ["topic": $0]) } ?? t("ios.home10.ask.generatingAnon")
            let stage = input.stage ?? .reading
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: marked, mood: .write),
                progress: progress(for: input.stage),
                caption: t(GenerationSteps.key(for: stage, hasSupports: input.hasSupports)),
                exit: cancel
            )
        case .waiting:
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: t("ios.home10.ask.offline"), mood: .think),
                action: retry,
                exit: cancel
            )
        case .failed:
            var message: String?
            if case .failed(let text) = input.phase { message = text.nilIfBlank }
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: t("ios.home10.ask.failed"), mood: .sad),
                action: retry,
                caption: message,
                exit: cancel
            )
        case .locked:
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: t("ios.home10.ask.locked"), mood: .wink),
                action: HomeAction(kind: .unlock, title: t("ios.conv.locked.unlock"), symbol: "lock.open.fill"),
                caption: input.locked?.detail(locale: locale),
                exit: HomeExit(kind: .later, title: t("ios.home10.cta.later"))
            )
        case .session:
            let session = day.session
            let vars = [
                "name": name ?? "",
                "min": String(session?.minutes ?? 0),
                "lesson": clip(session?.title ?? ""),
            ]
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: t(sessionKey(named: name != nil, greeting: input.greeting), vars), mood: .wave),
                action: HomeAction(kind: .session, title: t("ios.cal.startSession"), symbol: "play.fill")
            )
        case .cards:
            let vars = ["count": String(day.dueCount), "name": name ?? ""]
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: t(name != nil ? "ios.home10.ask.cards" : "ios.home10.ask.cardsAnon", vars), mood: .look),
                action: HomeAction(kind: .cards, title: t("ios.home10.cta.cards"), symbol: "rectangle.portrait.on.rectangle.portrait.fill")
            )
        case .lesson:
            let number = day.lessonStep ?? 1
            let vars = ["lesson": clip(day.lessonTitle ?? "")]
            let title = day.lessonStarted
                ? t("ios.pol.learn.next.resume", ["n": String(number)])
                : t("ios.pol.learn.next.start")
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(
                    marked: t(day.lessonStarted ? "ios.home10.ask.lesson" : "ios.home10.ask.lessonStart", vars),
                    mood: .idle
                ),
                action: HomeAction(kind: .lesson, title: title, symbol: "play.fill")
            )
        case .done:
            let marked = name.map { t("ios.home10.ask.done", ["name": $0]) } ?? t("ios.home10.ask.doneAnon")
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: marked, mood: .happy),
                action: input.hasLesson ? more : nil
            )
        case .open:
            let marked = name.map { t("ios.home10.ask.open", ["name": $0]) } ?? t("ios.home10.ask.openAnon")
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: marked, mood: .idle),
                action: input.hasLesson
                    ? more
                    : HomeAction(kind: .create, title: t("lesson.lessons.new"), symbol: "plus")
            )
        case .newcomer:
            let marked = name.map { t("ios.home10.ask.newcomer", ["name": $0]) } ?? t("ios.home10.ask.newcomerAnon")
            return HomeBoard(
                moment: moment,
                phrase: HomePhrase(marked: marked, mood: .wave),
                action: HomeAction(kind: .first, title: t("ios.home10.cta.first"), symbol: "sparkles")
            )
        }
    }

    /// La priorité : la leçon qui s'écrit, celle qui attend, puis la journée.
    static func moment(for input: HomeBoardInput) -> HomeMoment {
        switch input.phase {
        case .running: return .generating
        case .waiting: return .waiting
        case .failed: return .failed
        case .idle: break
        }
        if input.locked != nil { return .locked }
        switch input.day.proposal {
        case .session: return .session
        case .cards: return .cards
        case .lesson: return .lesson
        case .done: return .done
        case .open: return .open
        case .newcomer: return .newcomer
        }
    }

    /// La jauge de l'écriture : une valeur par étape du vrai travail.
    static func progress(for stage: LessonBuilder.Stage?) -> Double {
        switch stage {
        case nil, .reading?: 0.12
        case .cutting?: 0.38
        case .writing?: 0.64
        case .questions?: 0.88
        }
    }

    /// Un titre ou un sujet, coupé pour tenir dans la phrase.
    static func clip(_ text: String, to limit: Int = keywordLimit) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// « Bonjour », « Salut », « Bonsoir » : la nuit dit encore bonsoir.
    private static func sessionKey(named: Bool, greeting: HomeGreeting.Moment) -> String {
        switch (named, greeting) {
        case (true, .morning): "ios.home10.ask.session.morning"
        case (true, .day): "ios.home10.ask.session.day"
        case (true, .evening), (true, .night): "ios.home10.ask.session.evening"
        case (false, .morning): "ios.home10.ask.sessionAnon.morning"
        case (false, .day): "ios.home10.ask.sessionAnon.day"
        case (false, .evening), (false, .night): "ios.home10.ask.sessionAnon.evening"
        }
    }
}

// MARK: - La pastille de l'examen

/// **La pastille au-dessus de Mika** : le compte à rebours du prochain examen, ou l'invitation
/// à en ajouter un. C'est par elle que le Calendrier se voit dès la Home.
enum HomeExamPill: Equatable {
    /// « Bac d'histoire · J-12 » (le nom est celui que l'élève a donné).
    case countdown(String)
    /// « Ajouter mon examen ».
    case add(String)

    static func resolve(_ exam: HomeExam?, locale: UiLocale = .resolved()) -> HomeExamPill {
        guard let exam else {
            return .add(L10n.t("ios.home10.exam.add", locale: locale))
        }
        return .countdown(ExamCountdown.line(name: exam.name, daysLeft: exam.daysLeft, locale: locale))
    }

    var text: String {
        switch self {
        case .countdown(let text), .add(let text): text
        }
    }

    var hasExam: Bool {
        if case .countdown = self { return true }
        return false
    }
}

// MARK: - Les raccourcis

/// **Les puces d'outils, au-dessus de la barre de saisie.** « Focus » d'abord : c'est par lui
/// que la Concentration se voit dès la Home. L'élève actif retrouve ce qui fait travailler tout
/// de suite ; le nouvel élève, les trois façons de donner son premier cours.
///
/// Les noms partent tels quels dans `home_tool_opened` : des valeurs fixes.
enum HomeShortcut: String, Equatable, CaseIterable, Identifiable {
    /// Une séance de Concentration, à la durée par défaut de l'élève.
    case focus
    /// Scanner un exo (`ScanExerciseView`).
    case scan
    /// Le quiz éclair, sur la dernière leçon ouverte.
    case quiz
    /// Les cartes dues, toutes leçons confondues.
    case cards
    /// La feuille des sources.
    case importSource = "import"
    /// Corriger un texte (`WritingCoachView`).
    case writing
    /// L'examen blanc.
    case mock
    /// Les trois sources du nouvel élève.
    case photo
    case pdf
    case youtube
    /// Les conversations avec Mika (lot 11) : l'historique, en un geste.
    case chats

    var id: String { rawValue }

    /// Le nom de l'outil dans les statistiques.
    var analyticsName: String { rawValue }

    /// Ce que la Home propose, dans l'ordre. Le quiz demande une leçon ouverte, les cartes des
    /// cartes dues.
    ///
    /// Les conversations avec Mika ne sont plus une puce (lot 12) : elles ont leur tiroir, au
    /// bouton menu de l'en-tête.
    static func available(isNewcomer: Bool, hasLesson: Bool, dueCount: Int) -> [HomeShortcut] {
        if isNewcomer {
            return [.photo, .pdf, .youtube, .focus, .scan]
        }
        var shortcuts: [HomeShortcut] = [.focus, .scan]
        if hasLesson { shortcuts.append(.quiz) }
        if dueCount > 0 { shortcuts.append(.cards) }
        shortcuts.append(contentsOf: [.importSource, .writing, .mock])
        return shortcuts
    }

    /// Le mot de la puce. Chaque outil garde son nom (`MicaboName`) ; la Home l'écrit court.
    func title(dueCount: Int = 0, locale: UiLocale = .resolved()) -> String {
        switch self {
        case .focus: MicaboName.focus.text(locale: locale)
        case .scan: L10n.t("ios.home10.tool.scan", locale: locale)
        case .quiz: MicaboName.quiz.text(locale: locale)
        case .cards: L10n.t("ios.home10.tool.cards", locale: locale, vars: ["count": String(dueCount)])
        case .importSource: L10n.t("ios.home10.tool.import", locale: locale)
        case .writing: MicaboName.writing.text(locale: locale)
        case .mock: MicaboName.mock.text(locale: locale)
        case .photo: L10n.t("ios.home10.tool.photo", locale: locale)
        case .pdf: L10n.t("ios.home10.tool.pdf", locale: locale)
        case .youtube: "YouTube"
        case .chats: L10n.t("ios.chat11.home.chip", locale: locale)
        }
    }

    /// Ce que VoiceOver lit : le nom entier de l'outil.
    func spokenTitle(dueCount: Int = 0, locale: UiLocale = .resolved()) -> String {
        switch self {
        case .scan: MicaboName.scan.text(locale: locale)
        case .quiz: MicaboName.quickQuiz.text(locale: locale)
        case .cards: L10n.t("ios.home10.due", locale: locale, vars: ["count": String(dueCount)])
        default: title(dueCount: dueCount, locale: locale)
        }
    }

    /// Le support que la puce ouvre, pour les trois sources du nouvel élève.
    var source: LessonComposer.Kind? {
        switch self {
        case .photo: .photo
        case .pdf: .pdf
        case .youtube: .youtube
        default: nil
        }
    }
}
