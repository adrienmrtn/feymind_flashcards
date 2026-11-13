import QuartzCore
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import Micabo

// **Le banc d'essai de la fluidité** (lot 10) : de quoi poser un vrai écran dans une vraie
// fenêtre, avec les données d'un élève qui a 40 leçons, 600 cartes et 30 événements, et
// compter ce que le fil principal travaille. Rien ici ne vérifie quoi que ce soit : les
// mesures sont dans `PerfBenchTests`, les garde-fous dans `PerfGuardTests`.
//
// Ce que ces chiffres disent, et ce qu'ils ne disent pas. Ils viennent d'une construction de
// développement (sans optimisation) sur le simulateur d'une machine partagée : ils comparent
// un écran à un autre et un commit au suivant, ils ne prédisent pas une durée sur un iPhone.
// Et ils ne voient que le fil principal : le coût d'un flou ou d'une ombre, payé par le
// serveur de rendu, leur échappe.

// MARK: - Le compteur du fil principal

/// **Le temps où le fil principal travaille**, entre deux attentes de sa boucle.
///
/// Deux observateurs encadrent le sommeil de la boucle : tout ce qui se passe entre un réveil
/// et l'endormissement suivant est du travail (une source, une minuterie, un lien d'affichage,
/// la mise en page, et le dépôt de la transaction Core Animation, qui passe avant le nôtre).
final class MainThreadMeter {
    struct Sample {
        /// Le travail total de la fenêtre, en millisecondes.
        var busy: Double
        /// Le plus long travail d'un seul tenant, en millisecondes : c'est lui qui fait une
        /// image sautée.
        var longest: Double
    }

    private var before: CFRunLoopObserver?
    private var after: CFRunLoopObserver?
    private var mark: CFTimeInterval = 0
    private var awake = true
    private var busy: CFTimeInterval = 0
    private var longest: CFTimeInterval = 0

    init() {
        before = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, CFIndex.max
        ) { [weak self] _, _ in
            guard let self, self.awake else { return }
            self.close(at: CACurrentMediaTime())
            self.awake = false
        }
        after = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault, CFRunLoopActivity.afterWaiting.rawValue, true, CFIndex.min
        ) { [weak self] _, _ in
            guard let self else { return }
            self.mark = CACurrentMediaTime()
            self.awake = true
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), before, .commonModes)
        CFRunLoopAddObserver(CFRunLoopGetMain(), after, .commonModes)
    }

    deinit {
        if let before { CFRunLoopObserverInvalidate(before) }
        if let after { CFRunLoopObserverInvalidate(after) }
    }

    private func close(at time: CFTimeInterval) {
        let stretch = max(0, time - mark)
        busy += stretch
        longest = max(longest, stretch)
        mark = time
    }

    /// Fait `work`, puis laisse tourner la boucle `pump` secondes, et rend le travail du fil
    /// principal sur toute la fenêtre.
    @discardableResult
    func measure(pump: TimeInterval, _ work: () -> Void = {}) -> Sample {
        busy = 0
        longest = 0
        awake = true
        mark = CACurrentMediaTime()
        work()
        let deadline = CACurrentMediaTime() + pump
        while true {
            let left = deadline - CACurrentMediaTime()
            guard left > 0 else { break }
            CFRunLoopRunInMode(.defaultMode, left, false)
        }
        if awake { close(at: CACurrentMediaTime()) }
        return Sample(busy: busy * 1000, longest: longest * 1000)
    }
}

// MARK: - La scène

/// **Une fenêtre où poser un écran**, à la taille du téléphone du simulateur.
@MainActor
final class PerfStage {
    struct Mount {
        /// De la construction de la vue à la fin de la première mise en page, transaction
        /// déposée : ce que l'élève attend avant de voir l'écran.
        var first: Double
        /// Le travail du fil principal sur toute la fenêtre d'arrivée (première mise en page
        /// comprise) : les tâches d'apparition et les entrées animées s'y ajoutent.
        var settle: Double
        /// Le plus long travail d'un seul tenant pendant cette fenêtre.
        var stall: Double
    }

    let window: UIWindow
    let meter = MainThreadMeter()

    init() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        if let scene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        }
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
    }

    /// Pose `make()` à la racine de la fenêtre et mesure son arrivée.
    func mount<V: View>(settle: TimeInterval = 0.3, _ make: () -> V) -> Mount {
        var first = 0.0
        let sample = meter.measure(pump: settle) {
            let start = CACurrentMediaTime()
            let controller = UIHostingController(rootView: make())
            window.rootViewController = controller
            window.isHidden = false
            window.makeKey()
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            CATransaction.flush()
            first = (CACurrentMediaTime() - start) * 1000
        }
        return Mount(first: first, settle: sample.busy, stall: sample.longest)
    }

    /// Retire l'écran et laisse ses tâches s'éteindre.
    func clear() {
        window.rootViewController?.dismiss(animated: false)
        window.rootViewController = UIViewController()
        meter.measure(pump: 0.05)
    }

    /// Rend la fenêtre : à appeler à la fin du test.
    func close() {
        window.rootViewController?.dismiss(animated: false)
        window.rootViewController = nil
        window.isHidden = true
    }

    /// Le travail du fil principal par seconde quand on ne touche à rien : une minuterie, une
    /// horloge d'animation ou une boucle décorative s'y voient.
    func idle(seconds: TimeInterval = 1) -> Double {
        meter.measure(pump: seconds).busy / seconds
    }

    // MARK: Défiler

    /// Fait défiler la plus grande liste de l'écran, cran par cran, et rend le coût médian et
    /// le pire d'un cran, en millisecondes. `nil` quand rien ne défile.
    func scroll(steps: Int = 12, by delta: CGFloat = 180) -> (median: Double, worst: Double, travelled: CGFloat)? {
        window.layoutIfNeeded()
        guard let scroll = Self.tallestScrollView(in: window) else { return nil }
        var costs: [Double] = []
        let origin = scroll.contentOffset.y
        for _ in 0..<steps {
            let limit = max(-scroll.adjustedContentInset.top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
            let target = min(limit, scroll.contentOffset.y + delta)
            guard target > scroll.contentOffset.y + 1 else { break }
            let sample = meter.measure(pump: 0.02) {
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: target), animated: false)
                window.layoutIfNeeded()
                CATransaction.flush()
            }
            costs.append(sample.busy)
        }
        guard !costs.isEmpty else { return nil }
        return (Self.median(costs), costs.max() ?? 0, scroll.contentOffset.y - origin)
    }

    private static func tallestScrollView(in root: UIView) -> UIScrollView? {
        var best: UIScrollView?
        var bestRoom: CGFloat = 40
        var queue: [UIView] = [root]
        while let view = queue.popLast() {
            if let scroll = view as? UIScrollView, !(view is UITextView), scroll.window != nil, !scroll.isHidden {
                let room = scroll.contentSize.height - scroll.bounds.height
                if room > bestRoom {
                    best = scroll
                    bestRoom = room
                }
            }
            queue.append(contentsOf: view.subviews)
        }
        return best
    }

    // MARK: Taper

    struct Typing {
        /// Le coût médian d'une frappe, en millisecondes.
        var median: Double
        var worst: Double
        /// Le nombre de frappes que le champ a vraiment reçues.
        var typed: Int
        /// Les phrases relues par frappe (`L10n.t`) : ce que la frappe a fait redessiner.
        var lookups: Double
    }

    /// Tape dans le premier champ de l'écran. `nil` quand il n'y en a pas, ou qu'il refuse le
    /// curseur.
    func typeText(strokes: Int = 8) -> Typing? {
        window.layoutIfNeeded()
        guard let field = Self.firstTextInput(in: window) else { return nil }
        meter.measure(pump: 0.5) { _ = field.becomeFirstResponder() }
        guard field.isFirstResponder, let input = field as? UIKeyInput else { return nil }
        let before = Self.length(of: field)
        var costs: [Double] = []
        let lookupsBefore = PerfProbe.count("l10n")
        for _ in 0..<strokes {
            let sample = meter.measure(pump: 0.03) {
                input.insertText("a")
                window.layoutIfNeeded()
                CATransaction.flush()
            }
            costs.append(sample.busy)
        }
        let lookups = Double(PerfProbe.count("l10n") - lookupsBefore) / Double(max(1, strokes))
        let typed = Self.length(of: field) - before
        meter.measure(pump: 0.3) { _ = field.resignFirstResponder() }
        return Typing(median: Self.median(costs), worst: costs.max() ?? 0, typed: typed, lookups: lookups)
    }

    private static func length(of field: UIView) -> Int {
        if let field = field as? UITextField { return field.text?.count ?? 0 }
        if let field = field as? UITextView { return field.text.count }
        return 0
    }

    private static func firstTextInput(in root: UIView) -> UIView? {
        var queue: [UIView] = [root]
        var index = 0
        while index < queue.count {
            let view = queue[index]
            index += 1
            if view.window != nil, !view.isHidden {
                if let field = view as? UITextField, field.isEnabled { return field }
                if let field = view as? UITextView, field.isEditable { return field }
            }
            queue.append(contentsOf: view.subviews)
        }
        return nil
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}

// MARK: - Le verdict

/// **Les échecs du banc et des garde-fous, écrits à côté des mesures** : `PERF|echec|…` par
/// assertion tombée, `PERF|bilan|…` quand une classe a fini. Le journal de l'étape des tests
/// peut se taire avant la fin (une ligne d'un autre test l'a déjà coupé) ; `perf.txt`, lui,
/// repasse par sa propre étape et par la branche des rendus.
enum PerfVerdict {
    static func write(_ line: String) {
        print(line)
        guard let path = ProcessInfo.processInfo.environment["MICABO_RENDER_DIR"], !path.isEmpty else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("perf.txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    static func failure(in test: String, _ issue: XCTIssue) {
        let text = issue.compactDescription.replacingOccurrences(of: "\n", with: " ")
        write("PERF|echec|\(test)|\(String(text.prefix(600)))")
    }
}

// MARK: - Le rapport

/// **Les chiffres, une ligne par mesure** : `PERF|section|nom|clé=valeur|…`. Imprimés (le
/// journal de la CI les garde) et ajoutés à `perf.txt` dans le dossier des rendus (la branche
/// `renders/run-N` le porte).
@MainActor
enum PerfReport {
    static func record(_ section: String, _ name: String, _ values: [(String, Double)], note: String? = nil) {
        var line = "PERF|\(section)|\(name)"
        for (key, value) in values {
            line += "|\(key)=\(format(value))"
        }
        if let note { line += "|\(note)" }
        print(line)
        guard let directory = RenderGallery.directory else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("perf.txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }

    static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1_000_000 { return String(Int(value)) }
        return String(format: abs(value) < 10 ? "%.3f" : "%.1f", value)
    }

    /// Le temps d'un appel, en microsecondes : la médiane de `rounds` séries de `count` appels.
    static func micro(_ count: Int = 200, rounds: Int = 5, _ work: () -> Void) -> Double {
        var perCall: [Double] = []
        for _ in 0..<rounds {
            let start = CACurrentMediaTime()
            for _ in 0..<count { work() }
            perCall.append((CACurrentMediaTime() - start) * 1_000_000 / Double(count))
        }
        return PerfStage.median(perCall)
    }

    /// Le temps d'un travail fait une fois, en millisecondes.
    static func once(_ work: () throws -> Void) rethrows -> Double {
        let start = CACurrentMediaTime()
        try work()
        return (CACurrentMediaTime() - start) * 1000
    }
}

// MARK: - L'élève du banc

/// **Un élève qui a travaillé** : 40 leçons de cinq thèmes (notes, quiz, plan, progression),
/// 600 cartes et leur historique, quatre dossiers, trois examens, trois calendriers et trente
/// événements, douze tâches, quarante séances de concentration, des fils avec Mika et des
/// exercices scannés. Sur disque, comme sur le téléphone : SQLite compte dans la mesure.
@MainActor
final class PerfFixture {
    static let lessonCount = 40
    static let themesPerLesson = 5
    static let cardsPerLesson = 15

    let directory: URL
    let storeURL: URL
    private(set) var container: ModelContainer
    /// Les conteneurs précédents, gardés en vie : une tâche d'un écran déjà retiré peut encore
    /// tenir un de leurs objets, et un objet dont le conteneur a disparu fait tomber le test.
    private var retired: [ModelContainer] = []

    var context: ModelContext { container.mainContext }

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("micabo-perf-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("Micabo.store")
        container = try Self.open(storeURL)
        try seed()
    }

    static func open(_ url: URL) throws -> ModelContainer {
        try ModelContainer(
            for: MicaboApp.schema,
            configurations: ModelConfiguration(schema: MicaboApp.schema, url: url)
        )
    }

    /// Rouvre la base : un conteneur neuf, sans rien en mémoire, comme au lancement.
    @discardableResult
    func reopen() throws -> ModelContainer {
        let next = try Self.open(storeURL)
        retired.append(container)
        container = next
        return container
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: Lire

    func lessons() -> [Course] {
        let descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).filter { $0.isLesson }
    }

    func exams() -> [Exam] {
        (try? context.fetch(FetchDescriptor<Exam>(sortBy: [SortDescriptor(\Exam.date)]))) ?? []
    }

    func calendars() -> [StudyCalendar] {
        (try? context.fetch(FetchDescriptor<StudyCalendar>(sortBy: [SortDescriptor(\StudyCalendar.position)]))) ?? []
    }

    func tasks() -> [StudyTask] {
        (try? context.fetch(FetchDescriptor<StudyTask>(sortBy: [SortDescriptor(\StudyTask.createdAt)]))) ?? []
    }

    // MARK: Semer

    private static let subjects = [
        "Mathématiques", "Histoire", "Physique-chimie", "SVT", "Anglais",
        "Philosophie", "Géographie", "Français", "SES", "Espagnol",
    ]

    private static let paragraph = "Après 1945, les **États-Unis** et l'**URSS** s'opposent sans jamais se faire directement la guerre. Chacun rassemble ses alliés, construit son modèle et surveille l'autre : c'est un affrontement d'influence, d'armes et d'idées, qui dure plus de quarante ans et qui coupe l'Europe en deux."

    private func seed() throws {
        let context = container.mainContext
        let calendar = MicaboCalendar.shared
        let today = calendar.startOfDay(for: Date())
        var lessons: [Course] = []

        // Les dossiers.
        var folders: [CourseFolder] = []
        for (index, name) in ["Bac blanc", "Sciences", "Langues", "Première"].enumerated() {
            let folder = CourseFolder(name: name, emoji: ["📚", "🔬", "🌍", "🗂️"][index], position: index)
            context.insert(folder)
            folders.append(folder)
        }

        // Les leçons.
        let source = String(repeating: Self.paragraph + "\n\n", count: 40)
        for index in 0..<Self.lessonCount {
            let subject = Self.subjects[index % Self.subjects.count]
            let course = Course(
                title: "\(subject) · chapitre \(index / Self.subjects.count + 1) : la leçon numéro \(index + 1)",
                subject: subject,
                summary: "Ce qu'il faut retenir du chapitre \(index + 1), en cinq thèmes.",
                source: index % 3 == 0 ? .pdf : .text,
                rawText: source,
                contextText: String(source.prefix(4_000))
            )
            course.createdAt = today.addingTimeInterval(-Double(index) * 86_400 - 3_600)
            course.updatedAt = course.createdAt.addingTimeInterval(1_800)
            course.lastOpenedAt = index < 6 ? today.addingTimeInterval(-Double(index) * 7_200) : nil
            if index < 12 { course.folderID = folders[index % folders.count].id }
            context.insert(course)

            var chapters: [Chapter] = []
            for theme in 0..<Self.themesPerLesson {
                let chapter = Chapter(position: theme, title: "Thème \(theme + 1) : ce qui change et pourquoi", course: course)
                chapter.iconID = [MicaboIcon.globe, .flag, .hourglass, .puzzle, .trophy][theme].rawValue
                chapter.setNotes(Self.notes(theme))
                chapter.setQuiz(ThemeQuiz(questions: (0..<6).map { Self.question(id: "\(chapter.id.uuidString):\($0)", kind: $0) }))
                context.insert(chapter)
                chapters.append(chapter)
            }
            course.setLessonPath(LessonPath(
                icon: MicaboIcon.globe.rawValue,
                intro: LessonPath.Intro(lines: ["Pourquoi deux blocs", "Les grandes crises", "La fin d'un monde"], minutes: 25),
                takeaways: (1...5).map { "Phrase clé numéro \($0) : deux blocs s'opposent sans guerre directe." },
                groups: [LessonPath.Group(name: "Les causes", themes: [0, 1]), LessonPath.Group(name: "Les crises", themes: [2, 3, 4])],
                status: .ready
            ))
            // La progression : les premières leçons sont finies, les suivantes entamées.
            let circles = course.pathSteps().compactMap(\.circle)
            let doneCount = index < 8 ? circles.count : (index < 28 ? index % max(1, circles.count) : 0)
            course.updateProgress { progress in
                progress.done = Set(circles.prefix(doneCount).map(\.id))
                progress.quizScores = ["quiz:0": [4, 5]]
                progress.seconds = ["notes": 620, "quiz": 240, "flashcards": 180]
                if index < 8 { progress.finishedAt = today.addingTimeInterval(-Double(index) * 86_400) }
            }
            course.updatedAt = course.createdAt.addingTimeInterval(1_800)

            // Les cartes : un tiers neuves, un tiers dues, un tiers à venir.
            for position in 0..<Self.cardsPerLesson {
                let card = Flashcard(
                    front: "Question \(position + 1) de la leçon \(index + 1) : que s'est-il passé en 1947 ?",
                    back: "La doctrine Truman et le plan Marshall installent la logique des deux blocs.",
                    position: position,
                    course: course
                )
                card.chapter = chapters[position % chapters.count]
                switch position % 3 {
                case 1:
                    card.state = .review
                    card.intervalDays = 4
                    card.repetitions = 3
                    card.dueDate = today.addingTimeInterval(-Double(position) * 3_600)
                    card.lastReviewedAt = today.addingTimeInterval(-4 * 86_400)
                case 2:
                    card.state = .review
                    card.intervalDays = 12
                    card.repetitions = 5
                    card.dueDate = today.addingTimeInterval(Double(position + 2) * 86_400)
                    card.lastReviewedAt = today.addingTimeInterval(-2 * 86_400)
                default:
                    break
                }
                context.insert(card)
                if position % 3 != 0 {
                    var logs: [ReviewLog] = []
                    for step in 0..<3 {
                        let daysAgo = Double(step * 3 + index % 5)
                        let reviewedAt: Date = today.addingTimeInterval(-daysAgo * 86_400)
                        let rating: ReviewRating = step == 0 ? .hard : .good
                        let before: CardState = step == 0 ? .new : .review
                        let previous = Double(step)
                        let next = Double(step * 3 + 1)
                        logs.append(ReviewLog(
                            reviewedAt: reviewedAt,
                            rating: rating,
                            stateBefore: before,
                            previousIntervalDays: previous,
                            newIntervalDays: next,
                            easeAfter: 2.5
                        ))
                    }
                    card.logs = logs
                }
            }
            lessons.append(course)
        }

        // Les examens.
        let soon = Exam(name: "Bac blanc d'histoire", date: today.addingTimeInterval(12 * 86_400), courseIDs: lessons.prefix(4).map(\.id))
        let later = Exam(name: "Contrôle de maths", date: today.addingTimeInterval(30 * 86_400), courseIDs: lessons[4..<7].map(\.id))
        let past = Exam(name: "Devoir de SVT", date: today.addingTimeInterval(-9 * 86_400), courseIDs: [lessons[8].id])
        for exam in [soon, later, past] { context.insert(exam) }

        // Les calendriers et leurs trente événements.
        let classes = StudyCalendar(name: "Cours", emoji: "🏫", colorIndex: CalendarTint.classesIndex, kind: .classes, position: 0)
        let revisions = StudyCalendar(name: "Révisions", emoji: "📚", colorIndex: CalendarTint.revisionIndex, kind: .revision, position: 1)
        let club = StudyCalendar(name: "Théâtre", emoji: "🎭", colorIndex: 6, position: 2)
        for studyCalendar in [classes, revisions, club] { context.insert(studyCalendar) }
        let monday = calendar.date(byAdding: .day, value: -(MicaboCalendar.isoWeekday(of: today) - 1), to: today) ?? today
        for slot in 0..<20 {
            let day = calendar.date(byAdding: .day, value: slot % 5, to: monday) ?? today
            let start = (8 + (slot / 5) * 2) * 60
            context.insert(CalendarEvent(
                calendarID: classes.id,
                title: Self.subjects[slot % Self.subjects.count],
                day: day,
                startMinute: start,
                endMinute: start + 90,
                repeatsWeekly: true,
                room: "B\(10 + slot)",
                kind: .lesson
            ))
        }
        for session in 0..<8 {
            let day = calendar.date(byAdding: .day, value: session, to: today) ?? today
            context.insert(CalendarEvent(
                calendarID: revisions.id,
                title: lessons[session % 4].title,
                day: day,
                startMinute: 18 * 60,
                endMinute: 18 * 60 + 30,
                courseID: lessons[session % 4].id,
                examID: soon.id,
                kind: .revision
            ))
        }
        for extra in 0..<2 {
            let day = calendar.date(byAdding: .day, value: extra * 3 + 1, to: today) ?? today
            context.insert(CalendarEvent(calendarID: club.id, title: "Répétition", day: day, startMinute: 17 * 60, endMinute: 18 * 60 + 30))
        }

        // Les tâches et les séances de concentration.
        for index in 0..<12 {
            let task = StudyTask(
                title: "Tâche \(index + 1) : rendre le devoir maison",
                dueDate: index % 2 == 0 ? today.addingTimeInterval(Double(index) * 86_400) : nil,
                courseID: index % 3 == 0 ? lessons[index].id : nil
            )
            if index % 3 == 2 {
                task.isDone = true
                task.doneAt = Date()
            }
            context.insert(task)
        }
        for index in 0..<40 {
            let start = today.addingTimeInterval(-Double(index % 30) * 86_400 + 15 * 3_600)
            context.insert(FocusSession(
                startedAt: start,
                endedAt: start.addingTimeInterval(1_500),
                focusedSeconds: 1_500,
                mode: index % 2 == 0 ? .simple : .pomodoro,
                plannedMinutes: 25,
                cycles: 1,
                completed: index % 5 != 0,
                courseID: lessons[index % lessons.count].id,
                xpEarned: 25
            ))
        }

        // Mika : trois fils, et six exercices scannés.
        for index in 0..<30 {
            context.insert(TutorMessage(
                subject: [SolverSubject.math, .physics, .humanities][index % 3],
                role: index % 2 == 0 ? .user : .mika,
                text: index % 2 == 0
                    ? "Comment je résous une équation du second degré quand le discriminant est négatif ?"
                    : "Bonne question. Quand le **discriminant** est négatif, l'équation n'a pas de solution réelle : $\\Delta = b^2 - 4ac < 0$. " + Self.paragraph,
                createdAt: today.addingTimeInterval(-Double(30 - index) * 600)
            ))
        }
        for index in 0..<6 {
            let exercise = SolvedExercise(
                statement: "Résous l'équation $2x + \(index + 3) = 11$ et vérifie ta réponse.",
                subject: .math,
                source: .typed,
                thumbnail: nil
            )
            exercise.solutionRaw = "[SUBJECT] math\n[STEP] Isoler le terme en x\nOn retire \(index + 3) des deux côtés : $2x = \(8 - index)$.\n[STEP] Diviser par 2\nOn divise les deux côtés par 2.\n[ANSWER] $x = \(Double(8 - index) / 2)$"
            exercise.revealedSteps = 2
            context.insert(exercise)
        }

        try context.save()
    }

    static func notes(_ theme: Int) -> ThemeNotes {
        ThemeNotes(
            oneLiner: "Deux blocs s'installent face à face, et chacun veut convaincre le reste du monde.",
            blocks: [
                .subtitle("Deux modèles que tout oppose"),
                .paragraph(paragraph),
                .list(["Le bloc de l'Ouest suit les **États-Unis**.", "Le bloc de l'Est suit l'**URSS**.", "Les pays non alignés refusent de choisir."]),
                .definition(term: "Guerre froide", text: "Un affrontement sans combat direct entre les deux grandes puissances, de 1947 à 1991."),
                .subtitle("Les dates à connaître"),
                .dates([
                    NoteBlock.DateItem(date: "1947", text: "Doctrine Truman et plan Marshall."),
                    NoteBlock.DateItem(date: "1961", text: "Construction du mur de Berlin."),
                    NoteBlock.DateItem(date: "1989", text: "Chute du mur."),
                ]),
                .formula(latex: "E = mc^2", caption: "L'énergie d'une masse au repos."),
                .table(columns: ["Bloc", "Chef de file", "Alliance"], rows: [["Ouest", "États-Unis", "OTAN"], ["Est", "URSS", "Pacte de Varsovie"]]),
                .steps(["Repérer la date.", "Nommer les deux acteurs.", "Dire ce qui change après."]),
                .callout(kind: theme % 2 == 0 ? .mistake : .tip, title: nil, text: "Ne confonds pas la **détente** et la fin de la guerre froide : la course aux armements continue."),
                .paragraph(paragraph),
            ],
            takeaways: ["Deux blocs, deux modèles.", "Aucune guerre directe.", "1989 : le mur tombe."]
        )
    }

    static func question(id: String, kind: Int) -> QuizQuestion {
        switch kind % 4 {
        case 1:
            return QuizQuestion(id: id, kind: .truefalse, prompt: "Les États-Unis et l'URSS se sont fait directement la guerre.", choices: ["Vrai", "Faux"], answer: 1, why: "Ils s'affrontent par alliés interposés.")
        case 2:
            return QuizQuestion(id: id, kind: .order, prompt: "Remets ces événements dans l'ordre.", choices: ["Plan Marshall", "Mur de Berlin", "Crise de Cuba", "Chute du mur"], answer: 0, why: "1947, 1961, 1962, 1989.")
        case 3:
            return QuizQuestion(id: id, kind: .match, prompt: "Associe chaque bloc à son alliance.", choices: ["Ouest", "Est", "Non-alignés"], answer: 0, why: "L'OTAN à l'Ouest, le pacte de Varsovie à l'Est.", matches: ["OTAN", "Pacte de Varsovie", "Bandung"])
        default:
            return QuizQuestion(id: id, prompt: "En quelle année le mur de Berlin est-il construit ?", choices: ["1947", "1961", "1968", "1989"], answer: 1, why: "Il est construit en août 1961.")
        }
    }

    /// Une copie d'examen blanc de vingt questions, pour l'écran de composition.
    func paper() -> ExamPaper {
        let picked = Array(self.lessons().prefix(4))
        return ExamPaper(
            id: UUID(),
            examID: nil,
            title: "Examen blanc",
            minutes: 30,
            createdAt: Date(),
            lessons: picked.map { ExamPaper.Lesson(courseID: $0.id, title: $0.title, chapterIDs: $0.orderedChapters.map(\.id)) },
            items: (0..<20).map { ExamPaper.Item(question: Self.question(id: "paper:\($0)", kind: $0), lesson: $0 % 4, theme: $0 % 5) }
        )
    }
}

// MARK: - L'environnement de l'app

/// **Ce que `MicaboApp` pose dans l'environnement**, refait pour le banc : un compte fermé,
/// un élève sans abonnement, la langue du simulateur.
@MainActor
final class PerfEnvironment {
    let auth: AuthController
    let sync: CloudSync
    let social: SocialService
    let mocks: MockExamService
    let pro: ProAccess
    let uiLocale: UiLocaleStore
    let lessons: LessonBuilder
    let xp: XPStore
    let router: TabRouter

    init() {
        let auth = AuthController()
        self.auth = auth
        sync = CloudSync(auth: auth)
        social = SocialService(auth: auth)
        mocks = MockExamService(auth: auth)
        let defaults = UserDefaults(suiteName: "micabo.perf.\(UUID().uuidString)") ?? .standard
        pro = ProAccess(defaults: defaults)
        xp = XPStore(defaults: defaults)
        uiLocale = UiLocaleStore()
        lessons = LessonBuilder()
        router = TabRouter()
    }

    func wrap<V: View>(_ view: V, container: ModelContainer) -> some View {
        view
            .tint(MicaboColor.accent)
            .environment(auth)
            .environment(sync)
            .environment(social)
            .environment(mocks)
            .environment(pro)
            .environment(uiLocale)
            .environment(lessons)
            .environment(xp)
            .environment(router)
            .environment(\.locale, uiLocale.locale.foundation)
            .modelContainer(container)
    }
}
