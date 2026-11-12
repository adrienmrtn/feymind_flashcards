import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Les garde-fous de la fluidité** (lot 10, `PERF.md` § 4).
///
/// Trois familles, toutes rapides, toutes lancées à chaque push :
///
/// 1. **Les sources relues** : plus de délai de mise en scène (`asyncAfter`, `Task.sleep`) hors
///    de la liste tenue ici, plus de boucle d'animation sans fin hors d'une attente, plus
///    d'horloge d'animation ni de minuterie hors de celles qu'on connaît. Règle du lot
///    (`COMMON.md` § 7) : le mouvement est natif et immédiat.
/// 2. **Les raccourcis rendent la même chose que le chemin long** : la lecture d'une phrase, la
///    table d'une langue, l'icône d'une matière, le décodage gardé en mémoire.
/// 3. Les plafonds de temps (première mise en page, lancement, minuterie, frappe) vivent dans
///    le banc d'essai, `PerfBenchTests`, là où l'écran est déjà posé.
///
/// **Quand un de ces tests casse sur ton push** : lis le message, il nomme le fichier et la
/// ligne. Un chargement, un décompte ou un délai technique (clavier, réseau, deux
/// présentations qui s'enchaînent) s'ajoute à la liste avec sa raison ; une apparition
/// retardée ou une cascade se retire.
final class PerfGuardTests: XCTestCase {
    override func record(_ issue: XCTIssue) {
        PerfVerdict.failure(in: name, issue)
        super.record(issue)
    }

    override class func tearDown() {
        PerfVerdict.write("PERF|bilan|PerfGuardTests|fini")
        super.tearDown()
    }

    // MARK: - Les sources

    /// Ce qu'un autre lot est en train de réécrire, et qu'on ne relit pas encore. Vide depuis
    /// la fin du lot 10 : le parcours d'accueil, le paywall, la Home, la leçon ouverte et Mika
    /// sont relus comme le reste.
    private static let pending: [String] = []

    private struct Allowance {
        let path: String
        let max: Int
        let why: String
    }

    /// **Les délais permis**, fichier par fichier, avec le nombre qu'on y connaît et sa raison.
    /// Un fichier peut en perdre ; il ne peut pas en gagner sans passer par ici.
    private static let delays: [Allowance] = [
        Allowance(path: "App/MicaboApp.swift", max: 1, why: "la synchro du lancement attend que la première image soit posée"),
        Allowance(path: "DesignSystem/Components/MikaMascot.swift", max: 1, why: "le clignement de Mika au repos, sa seule horloge"),
        Allowance(path: "DesignSystem/Haptics.swift", max: 1, why: "le rythme d'une salve de vibrations"),
        Allowance(path: "Features/Calendar/CalendarEditSheet.swift", max: 2, why: "deux présentations ne s'enchaînent pas dans la même passe"),
        Allowance(path: "Features/Courses/CoursesListView.swift", max: 1, why: "le recensement attend que la page soit repliée"),
        Allowance(path: "Features/Deck/Steps/DeckBuildingStepView.swift", max: 3, why: "la jauge d'un écran de chargement (parcours hérité, plus ouvert par l'app)"),
        Allowance(path: "Features/Deck/Steps/DeckMaterialsStepView.swift", max: 1, why: "le retour d'un appui (parcours hérité, plus ouvert par l'app)"),
        Allowance(path: "Features/Friends/FriendsView.swift", max: 1, why: "la recherche attend la fin de la frappe"),
        Allowance(path: "Features/Home/LessonImportPickers.swift", max: 1, why: "deux présentations ne se croisent pas"),
        Allowance(path: "Features/Home/LockedLessonPreview.swift", max: 3, why: "l'aperçu d'une leçon verrouillée se coche au rythme d'une lecture, avant le paywall"),
        Allowance(path: "Features/Lesson/LessonCircleScreen.swift", max: 1, why: "les confettis s'arrêtent d'eux-mêmes"),
        Allowance(path: "Features/Lesson/LessonMikaView.swift", max: 1, why: "le fil suit le clavier qui monte"),
        Allowance(path: "Features/Lesson/LessonPathView.swift", max: 2, why: "le mode attend que le paywall soit descendu ; la note de l'App Store attend la sortie de la leçon"),
        Allowance(path: "Features/Lesson/LessonPracticeView.swift", max: 1, why: "un message passager qui se retire"),
        Allowance(path: "Features/Lesson/LessonRatingCard.swift", max: 1, why: "le merci se retire de lui-même"),
        Allowance(path: "Features/Lesson/SheetExportView.swift", max: 1, why: "la mise en page du PDF attend que la feuille soit montée"),
        Allowance(path: "Features/Mika/TutorChatView.swift", max: 1, why: "le fil suit le clavier qui monte"),
        Allowance(path: "Features/Paywall/PaywallFlowView.swift", max: 1, why: "réseau : nouvel essai des prix"),
        Allowance(path: "Features/Paywall/PaywallPurchases.swift", max: 1, why: "réseau : nouvel essai de l'identification chez RevenueCat"),
        Allowance(path: "Features/Profile/SettingsSchoolSheet.swift", max: 1, why: "la recherche attend la fin de la frappe"),
        Allowance(path: "Features/Profile/SettingsView.swift", max: 1, why: "rejouer le parcours une fois la feuille refermée (TestFlight)"),
        Allowance(path: "Features/Writing/WritingCoachView.swift", max: 1, why: "« Copié » se retire de lui-même"),
        Allowance(path: "Features/XP/XPOverlay.swift", max: 3, why: "la durée d'affichage du gain d'XP"),
        Allowance(path: "Services/Analytics/Analytics.swift", max: 1, why: "le lot de statistiques attend sa fenêtre d'envoi"),
        Allowance(path: "Services/Auth/AuthController.swift", max: 5, why: "réseau : nouvel essai, fenêtres de garde de la connexion"),
        Allowance(path: "Services/Lesson/LessonBuilder.swift", max: 1, why: "réseau : nouvel essai d'un thème"),
    ]

    /// Les horloges d'animation (`TimelineView(.animation)`) et les minuteries qu'on connaît.
    private static let clocks: [Allowance] = [
        Allowance(path: "Features/Lesson/LessonCircleScreen.swift", max: 1, why: "les confettis, quatre secondes au plus"),
        Allowance(path: "Features/Exams/MockExamFlow.swift", max: 1, why: "la copie d'examen blanc se rend à zéro"),
    ]

    private struct Source {
        let path: String
        let lines: [String]
    }

    /// Vrai une fois le nombre de fichiers relus écrit dans `perf.txt`.
    private static var reported = false

    private func sources() throws -> [Source] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        var found: [Source] = []
        for case let url as URL in files where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            guard !Self.pending.contains(where: { relative.hasPrefix($0) }),
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            found.append(Source(path: relative, lines: text.components(separatedBy: "\n")))
        }
        guard found.count > 100 else {
            PerfVerdict.write("PERF|garde|sources|fichiers=\(found.count)|illisibles depuis ce simulateur : les garde-fous de sources sont sautés")
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        if !Self.reported {
            Self.reported = true
            PerfVerdict.write("PERF|garde|sources|fichiers=\(found.count)")
        }
        return found
    }

    /// Les lignes de code (pas les commentaires) d'un fichier qui portent l'un des motifs.
    private func hits(in source: Source, _ needles: [String]) -> [Int] {
        var numbers: [Int] = []
        for (index, line) in source.lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            if needles.contains(where: { line.contains($0) }) { numbers.append(index + 1) }
        }
        return numbers
    }

    private func offenders(_ needles: [String], allowed: [Allowance]) throws -> [String] {
        var out: [String] = []
        for source in try sources() {
            let found = hits(in: source, needles)
            guard !found.isEmpty else { continue }
            let allowance = allowed.first { $0.path == source.path }
            if found.count > (allowance?.max ?? 0) {
                let lines = found.map { String($0) }.joined(separator: ", ")
                out.append("\(source.path) : lignes \(lines) (\(found.count) au lieu de \(allowance?.max ?? 0) permis)")
            }
        }
        return out.sorted()
    }

    /// **Aucun délai de mise en scène hors de la liste.** Une apparition retardée, une cascade,
    /// un bouton qui attend avant de répondre : c'est ce que l'élève appelle « pas fluide ».
    func testNoStagedDelayOutsideTheList() throws {
        let found = try offenders(["asyncAfter(", "Task.sleep("], allowed: Self.delays)
        XCTAssertEqual(found, [], """
        Un délai (`asyncAfter` ou `Task.sleep`) hors de la liste de `PerfGuardTests.delays`. \
        Règle du lot 10 (COMMON.md § 7) : mouvement natif et immédiat, rien n'attend pour \
        s'afficher. Un chargement, un décompte ou un délai technique s'ajoute à la liste avec \
        sa raison ; une apparition retardée se retire.
        """)
    }

    /// **Aucune animation sans fin**, sauf une attente (la ligne finit par `// attente`).
    func testNoEndlessAnimationOutsideAWait() throws {
        var found: [String] = []
        for source in try sources() {
            for (index, line) in source.lines.enumerated() where line.contains("repeatForever") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.hasPrefix("//"), !trimmed.hasSuffix("// attente") else { continue }
                found.append("\(source.path):\(index + 1)")
            }
        }
        XCTAssertEqual(found, [], "une animation qui boucle sans fin hors d'une attente : elle occupe le fil principal tant que l'écran vit")
    }

    /// **Aucune horloge d'animation ni minuterie hors de celles qu'on connaît.** Une horloge
    /// tourne à chaque image ; une minuterie qui écrit un état relit tout son écran.
    func testNoClockOutsideTheList() throws {
        let found = try offenders(["TimelineView(.animation", "Timer.publish(", "Timer.scheduledTimer(", "CADisplayLink("], allowed: Self.clocks)
        XCTAssertEqual(found, [], """
        Une horloge d'animation ou une minuterie hors de la liste de `PerfGuardTests.clocks`. \
        Une minuterie d'une seconde se dessine dans une petite vue (`TimelineView(.periodic…)` \
        autour du seul chiffre), jamais par un état de l'écran entier.
        """)
    }

    // MARK: - Les raccourcis rendent la même chose

    /// **La table d'une langue est la même par les deux chemins** : `L10n` nomme chaque langue
    /// pour ne construire que la sienne, `table(for:)` passe par le dictionnaire des régionales.
    func testEachLocaleReadsItsOwnTable() {
        for locale in UiLocale.allCases {
            XCTAssertEqual(L10n.iosTable(locale), IosI18nCatalogs.table(for: locale.rawValue), "phrases iOS : \(locale.rawValue)")
            XCTAssertEqual(L10n.lessonTable(locale), LessonI18nCatalogs.table(for: locale.rawValue), "phrases de la leçon : \(locale.rawValue)")
        }
    }

    /// L'ancienne mise en forme, telle quelle : l'expression du pluriel sur chaque phrase, puis
    /// les variables.
    private static let pluralPattern = #"\{(\w+),\s*plural,\s*one\s*\{([\s\S]*?)\}\s*other\s*\{([\s\S]*?)\}\}"#

    private func referenceFormat(_ template: String, locale: UiLocale, vars: [String: String], regex: NSRegularExpression) -> String {
        var result = template
        let range = NSRange(template.startIndex..., in: template)
        for match in regex.matches(in: template, range: range).reversed() {
            guard match.numberOfRanges == 4,
                  let keyRange = Range(match.range(at: 1), in: template),
                  let oneRange = Range(match.range(at: 2), in: template),
                  let otherRange = Range(match.range(at: 3), in: template),
                  let allRange = Range(match.range(at: 0), in: result)
            else { continue }
            let raw = vars[String(template[keyRange])] ?? "0"
            let count = Int(raw) ?? 0
            let branch = L10n.isSingular(count, locale: locale) ? String(template[oneRange]) : String(template[otherRange])
            result.replaceSubrange(allRange, with: branch.replacingOccurrences(of: "#", with: raw))
        }
        for (key, value) in vars {
            result = result.replacingOccurrences(of: "{\(key)}", with: value)
        }
        return result
    }

    /// **Le raccourci de `L10n.format` ne change aucune phrase** : toutes celles de quatre
    /// langues, avec des variables, donnent exactement ce que l'ancien chemin donnait.
    func testFormattingAPhraseGivesWhatItAlwaysGave() throws {
        let regex = try NSRegularExpression(pattern: Self.pluralPattern)
        let vars = ["count": "3", "n": "1", "total": "12", "name": "Lina", "minutes": "25", "days": "0"]
        var compared = 0
        for locale in [UiLocale.fr, .en, .de, .ar] {
            let tables = [L10n.iosTable(locale), L10n.lessonTable(locale), L10n.table(for: locale)]
            for table in tables {
                for template in table.values {
                    for candidate in [vars, [:], ["count": "1"]] {
                        let expected = referenceFormat(template, locale: locale, vars: candidate, regex: regex)
                        let actual = L10n.format(template, locale: locale, vars: candidate)
                        if expected != actual {
                            XCTFail("« \(template) » (\(locale.rawValue)) : « \(actual) » au lieu de « \(expected) »")
                            return
                        }
                        compared += 1
                    }
                }
            }
        }
        XCTAssertGreaterThan(compared, 10_000)
    }

    /// La langue résolue suit toujours un choix fait dans l'app, tout de suite.
    func testAChosenLanguageIsReadAtOnce() throws {
        let suite = "micabo.perf.locale.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let system = UiLocale.resolved(defaults: defaults)
        XCTAssertEqual(system, UiLocale.fromPreferredLanguages())
        defaults.set(UiLocale.fi.rawValue, forKey: UiLocale.storageKey)
        XCTAssertEqual(UiLocale.resolved(defaults: defaults), .fi)
        defaults.set(UiLocale.ar.rawValue, forKey: UiLocale.storageKey)
        XCTAssertEqual(UiLocale.resolved(defaults: defaults), .ar)
        defaults.removeObject(forKey: UiLocale.storageKey)
        XCTAssertEqual(UiLocale.resolved(defaults: defaults), system)
    }

    /// **Un décodage gardé en mémoire rend la valeur de ses octets, et rien d'autre** : deux
    /// lectures des mêmes octets sont égales, d'autres octets donnent une autre valeur, et des
    /// octets illisibles restent illisibles.
    func testDecodingIsKeptByItsBytes() throws {
        let first = ThemeNotes(oneLiner: "Une idée", blocks: [.paragraph("Un paragraphe.")], takeaways: ["À retenir"])
        let second = ThemeNotes(oneLiner: "Une autre idée", blocks: [.paragraph("Un autre paragraphe.")], takeaways: [])
        let firstData = try XCTUnwrap(first.encoded())
        let secondData = try XCTUnwrap(second.encoded())
        XCTAssertEqual(ThemeNotes.decode(from: firstData), first)
        XCTAssertEqual(ThemeNotes.decode(from: firstData), first)
        XCTAssertEqual(ThemeNotes.decode(from: secondData), second)
        XCTAssertNil(ThemeNotes.decode(from: Data("pas du JSON".utf8)))
        XCTAssertNil(ThemeNotes.decode(from: Data("pas du JSON".utf8)))
        XCTAssertNil(ThemeNotes.decode(from: nil))

        var progress = LessonProgress()
        progress.done = ["intro", "notes:0"]
        progress.quizScores = ["quiz:0": [4, 5]]
        let progressData = try XCTUnwrap(progress.encoded())
        XCTAssertEqual(LessonProgress.decode(from: progressData), progress)
        XCTAssertEqual(LessonProgress.decode(from: progressData), progress)
        progress.done.insert("notes:1")
        XCTAssertEqual(LessonProgress.decode(from: try XCTUnwrap(progress.encoded())), progress)
        XCTAssertEqual(LessonProgress.decode(from: Data("{".utf8)), LessonProgress())

        let quiz = ThemeQuiz(questions: [QuizQuestion(id: "a:0", prompt: "Une question ?", choices: ["Oui", "Non"], answer: 0, why: "Parce que.")])
        let quizData = try XCTUnwrap(quiz.encoded())
        XCTAssertEqual(ThemeQuiz.decode(from: quizData), quiz)
        XCTAssertEqual(ThemeQuiz.decode(from: quizData), quiz)

        let path = LessonPath(
            icon: MicaboIcon.globe.rawValue,
            intro: LessonPath.Intro(lines: ["Un", "Deux"], minutes: 15),
            takeaways: ["Une phrase"],
            groups: [LessonPath.Group(name: "", themes: [0])],
            status: .ready
        )
        let pathData = try XCTUnwrap(path.encoded())
        XCTAssertEqual(LessonPath.decode(from: pathData), path)
        XCTAssertEqual(LessonPath.decode(from: pathData), path)
        XCTAssertNil(LessonPath.decode(from: Data()))
    }

    /// **L'icône d'une matière, gardée par son nom, est celle que la recherche trouve** : la
    /// seconde lecture rend la première, dans toutes les écritures.
    func testASubjectKeepsItsIcon() {
        let expected: [(String, MicaboIcon?)] = [
            ("Mathématiques", .calculator),
            ("Physique-chimie", .atom),
            ("Histoire-géographie", .scroll),
            ("SVT", .flask),
            ("Anglais", .book),
            ("Philosophie", .brain),
            ("Математика", .calculator),
            ("رياضيات", .calculator),
            ("Tricot", nil),
            ("   ", nil),
        ]
        for (subject, icon) in expected {
            XCTAssertEqual(MicaboIcon.subjectIcon(subject), icon, subject)
            XCTAssertEqual(MicaboIcon.subjectIcon(subject), icon, "\(subject), seconde lecture")
        }
        XCTAssertNil(MicaboIcon.subjectIcon(nil))
        XCTAssertEqual(MicaboIcon.guess(subject: nil, title: "La chimie organique"), .flask)
        XCTAssertEqual(MicaboIcon.guess(subject: nil, title: "La chimie organique"), .flask)
        XCTAssertEqual(MicaboIcon.guess(subject: nil, title: "Un titre sans matière"), .book)
    }

    /// Une formule sans antislash sort telle quelle, une commande est toujours transposée.
    func testPlainTextSkipsTheCommandPass() {
        XCTAssertEqual(FormulaRenderer.symbolsOnly("Une phrase sans commande."), "Une phrase sans commande.")
        XCTAssertEqual(FormulaRenderer.symbolsOnly("A \\to B"), "A → B")
        XCTAssertEqual(FormulaRenderer.stripped("1914 \\rightarrow 1918"), "1914 → 1918")
    }

    /// **Un libellé de date gardé dit ce que disait le formateur refait à chaque appel**, dans
    /// quatre langues et pour chaque gabarit du calendrier.
    func testACachedDateLabelSaysWhatAFreshFormatterSaid() {
        let days = [0, 86_400 * 200, 1_800_000_000, 1_812_345_678].map { Date(timeIntervalSince1970: TimeInterval($0)) }
        for locale in [UiLocale.fr, .en, .de, .ar] {
            for template in ["EEE", "d", "LLLL", "d MMM", "MMMM yyyy", "EEEE d MMMM", "EEEE d MMMM yyyy", "jmm"] {
                let fresh = DateFormatter()
                fresh.locale = locale.foundation
                fresh.calendar = MicaboCalendar.shared
                fresh.setLocalizedDateFormatFromTemplate(template)
                for day in days {
                    XCTAssertEqual(
                        MicaboDateFormat.template(template, locale: locale).string(from: day),
                        fresh.string(from: day),
                        "\(locale.rawValue) \(template)"
                    )
                }
            }
            let fresh = DateFormatter()
            fresh.locale = locale.foundation
            XCTAssertEqual(MicaboDateFormat.symbols(locale: locale).standaloneWeekdaySymbols, fresh.standaloneWeekdaySymbols)
            XCTAssertEqual(MicaboDateFormat.symbols(locale: locale).veryShortStandaloneWeekdaySymbols, fresh.veryShortStandaloneWeekdaySymbols)
        }
    }

    // MARK: - Le lancement

    /// **Rien de lourd ne revient dans `MicaboApp.init`.** Tout ce qui s'y trouve s'exécute sur
    /// le fil principal avant la première image : pas de lecture de table, pas de fichier lu,
    /// pas de JSON décodé, pas d'attente.
    func testNothingHeavyReturnsToTheLaunch() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo/App/MicaboApp.swift")
        guard let text = try? String(contentsOf: root, encoding: .utf8) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        let start = try XCTUnwrap(text.range(of: "    init() {"))
        let end = try XCTUnwrap(text.range(of: "    var body: some Scene {"))
        let body = String(text[start.upperBound..<end.lowerBound])
        let forbidden = [
            ".fetch(", "fetchCount(", "Data(contentsOf", "String(contentsOf", "JSONDecoder(", "JSONEncoder(",
            "Thread.sleep", "DispatchSemaphore", ".wait(", "DispatchQueue.main.sync", "URLSession",
        ]
        for needle in forbidden {
            XCTAssertFalse(body.contains(needle), "`MicaboApp.init` fait `\(needle)` sur le fil principal, avant la première image")
        }
    }
}
