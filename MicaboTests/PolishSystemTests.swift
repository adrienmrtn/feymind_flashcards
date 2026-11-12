import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Les règles de la finition « entrée, compte et système »** (lot 6, agent C) qui se
/// vérifient sans écran : une seule famille de courbes et aucune boucle sans fin dans le
/// parcours, le paywall, le compte, la barre d'onglets et les composants ; des libellés
/// d'onglets qui tiennent dans toutes les langues ; l'examen, la classe et le barème de
/// chaque élève du cahier des charges.
final class PolishSystemTests: XCTestCase {
    // MARK: - Le mouvement

    /// Les dossiers de ce lot, relus depuis les sources.
    private static let perimeter = [
        "Features/Onboarding", "Features/Paywall", "Features/Auth", "Features/Profile",
        "Features/Friends", "Features/Root", "Features/I18n", "DesignSystem",
    ]

    /// Les fichiers qui ont le droit d'écrire une courbe : la famille elle-même, le moteur de
    /// Mika, la réponse au doigt (80 ms, plus court que toute courbe de la famille) et la jauge
    /// d'un appui long, qui avance à vitesse constante parce qu'elle mesure un temps.
    private static let allowed = [
        "DesignSystem/MicaboMotion.swift",
        "DesignSystem/Components/MikaMascot.swift",
        "DesignSystem/Components/MikaArt.swift",
        "DesignSystem/Components/MicaboButtons.swift",
        "Features/Onboarding/OnboardingInteractions.swift",
    ]

    private func perimeterSources() throws -> [(path: String, text: String)] {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        var found: [(String, String)] = []
        for folder in Self.perimeter {
            let root = sources.appendingPathComponent(folder, isDirectory: true)
            guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in files where url.pathExtension == "swift" {
                let relative = url.path.replacingOccurrences(of: sources.path + "/", with: "")
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                found.append((relative, text))
            }
        }
        guard !found.isEmpty else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
        return found
    }

    /// **Une seule famille de courbes** (`MicaboMotion`) dans tout le périmètre : plus de
    /// ressort à rebond pour une coche, plus de fondu de 0,9 s pour un graphe.
    func testThePerimeterMovesOnlyWithMicaboMotion() throws {
        let curve = try NSRegularExpression(pattern: #"\.(spring|easeOut|easeIn|easeInOut|linear|interactiveSpring|bouncy|snappy|smooth|timingCurve)\("#)
        var offenders: [String] = []
        for (path, text) in try perimeterSources() where !Self.allowed.contains(path) {
            for (number, line) in text.components(separatedBy: "\n").enumerated() {
                guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") else { continue }
                let range = NSRange(line.startIndex..., in: line)
                if curve.firstMatch(in: line, range: range) != nil {
                    offenders.append("\(path):\(number + 1)")
                }
            }
        }
        XCTAssertEqual(offenders, [], "une courbe hors de MicaboMotion")
    }

    /// **Aucune boucle sans fin** : une icône qui flotte, un halo qui respire, des éclats qui
    /// clignotent sous une question tirent l'œil de la question.
    func testNothingLoopsForever() throws {
        var offenders: [String] = []
        for (path, text) in try perimeterSources() where !Self.allowed.contains(path) {
            for (number, line) in text.components(separatedBy: "\n").enumerated()
            where line.contains("repeatForever") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                offenders.append("\(path):\(number + 1)")
            }
        }
        XCTAssertEqual(offenders, [])
    }

    /// Les courbes du parcours sont celles de l'app, et aucune ne dépasse quatre dixièmes.
    func testTheOnboardingCurvesAreTheAppsCurves() {
        XCTAssertLessThanOrEqual(OnboardingMotion.slideDuration, 0.4)
        XCTAssertGreaterThan(OnboardingMotion.slideDuration, 0.2)
    }

    // MARK: - La barre d'onglets

    /// **Chaque nom d'onglet tient dans un cinquième de barre**, sur un iPhone SE, dans les
    /// vingt-six langues, sans descendre sous 85 % de sa taille. La barre ne montre plus que des
    /// icônes (V3.3) ; les noms restent courts pour VoiceOver et pour la visionneuse en très
    /// grand texte. « Concentration », « Keskittyminen » et « Συγκέντρωση » tombaient à 62 %.
    func testTabLabelsFitOnASmallPhoneInEveryLanguage() {
        // Le nom d'un onglet : 11 points en gras, police système (`V3Font.tab`).
        let font = UIFont.systemFont(ofSize: 11, weight: .bold)
        // 375 points, moins les marges de la barre (6 + 6) et les quatre espaces entre onglets
        // (2 chacun), puis 2 + 2 autour du libellé.
        let slot = (375.0 - 12 - 8) / 5 - 4
        var tooLong: [String] = []
        for locale in UiLocale.allCases {
            for tab in RootTab.tabs {
                let label = tab.barLabel(t: { L10n.t($0, locale: locale) })
                let width = (label as NSString).size(withAttributes: [.font: font]).width
                if width * 0.85 > slot {
                    tooLong.append("\(locale.rawValue) « \(label) » \(Int(width)) pt")
                }
            }
        }
        XCTAssertEqual(tooLong, [])
    }

    /// Le libellé court ne vaut que pour la barre : la page garde son titre entier.
    func testTheShortTabLabelOnlyLivesInTheBar() {
        XCTAssertEqual(RootTab.focus.label(t: { L10n.t($0, locale: .fr) }), "Concentration")
        XCTAssertEqual(RootTab.focus.barLabel(t: { L10n.t($0, locale: .fr) }), "Focus")
        XCTAssertEqual(RootTab.profile.barLabel(t: { L10n.t($0, locale: .de) }), RootTab.profile.label(t: { L10n.t($0, locale: .de) }))
    }

    /// **Les cinq onglets gardent leur nom** — Accueil, Leçons, Calendrier, Focus, Profil — même
    /// si la barre ne montre que leurs icônes : c'est ce que VoiceOver lit.
    func testTheFiveTabsAreNamed() {
        let french = RootTab.tabs.map { $0.barLabel(t: { L10n.t($0, locale: .fr) }) }
        XCTAssertEqual(french, ["Accueil", "Leçons", "Calendrier", "Focus", "Profil"])
        for locale in UiLocale.allCases {
            for tab in RootTab.tabs {
                let label = tab.barLabel(t: { L10n.t($0, locale: locale) })
                XCTAssertFalse(label.isEmpty, locale.rawValue)
                XCTAssertFalse(label.contains("."), "\(locale.rawValue) : la clé s'afficherait telle quelle (« \(label) »)")
            }
        }
    }

    // MARK: - Les mots du pays

    /// « J-12 » est une tournure française : ailleurs, le compte à rebours se dit dans la
    /// langue de l'élève.
    func testTheCountdownSpeaksTheStudentsLanguage() {
        XCTAssertEqual(L10n.t("ios.pol.sys.daysLeft", locale: .fr, vars: ["days": "12"]), "J-12")
        for locale in UiLocale.allCases where locale != .fr {
            let text = L10n.t("ios.pol.sys.daysLeft", locale: locale, vars: ["days": "12"])
            XCTAssertFalse(text.contains("J-"), locale.rawValue)
            XCTAssertTrue(text.contains("12"), "\(locale.rawValue) : \(text)")
        }
    }

    private func year(_ id: String, region: String) -> (SchoolTrack, SchoolYear)? {
        for track in SchoolSystem.tracks(region: region) {
            if let year = track.years.first(where: { $0.id == id }) { return (track, year) }
        }
        return nil
    }

    private func examTitles(_ yearID: String, region: String) -> [String] {
        guard let found = year(yearID, region: region) else { return [] }
        return SchoolExams.choices(track: found.0, year: found.1, tier: found.0.tier).compactMap {
            if case .named(let exam) = $0 { return exam.title }
            return nil
        }
    }

    private func choices(_ yearID: String, region: String) -> [ExamChoice] {
        guard let found = year(yearID, region: region) else { return [] }
        return SchoolExams.choices(track: found.0, year: found.1, tier: found.0.tier)
    }

    /// **Les élèves du cahier des charges, chacun dans son école** : le Maroc et l'Arabie
    /// saoudite en plus des pays déjà vérifiés (`OnboardingCountryTests`), un collégien, une
    /// étudiante.
    func testTheBriefsStudentsSeeTheirOwnSchool() {
        XCTAssertEqual(examTitles("ma.2bac", region: "MA"), ["Bac national"])
        XCTAssertEqual(examTitles("ma.c3", region: "MA"), ["Examen régional (3e année collège)"])
        XCTAssertEqual(examTitles("sa.t3", region: "SA"), ["اختبار القدرات العامة", "الاختبار التحصيلي"])
        XCTAssertEqual(examTitles("fr.3e", region: "FR"), ["Brevet"])
        XCTAssertEqual(examTitles("de.klasse13", region: "DE"), ["Abitur"])
        XCTAssertEqual(examTitles("es.bachCiencias2", region: "ES"), ["PAU (Selectividad)"])
        XCTAssertEqual(examTitles("it.liceo5", region: "IT"), ["Maturità"])
        XCTAssertTrue(examTitles("us.hs11", region: "US").contains("SAT"))
        XCTAssertEqual(choices("fr.l2", region: "FR"), [.finals, .noExam], "une étudiante a des partiels, pas un bac")
    }

    /// **Aucun « Bac » pour qui ne le passe pas** : ni un Allemand, ni un Américain, ni un
    /// Espagnol, ni une Italienne, ni un Anglais, à aucune année de leur scolarité.
    func testNoBacIsOfferedOutsideTheCountriesThatHaveOne() {
        for region in ["DE", "US", "ES", "IT", "GB", "NL", "PL", "AT", "FI", "SA"] {
            for track in SchoolSystem.tracks(region: region) {
                for year in track.years {
                    let titles = examTitles(year.id, region: region)
                    XCTAssertFalse(titles.contains { $0.hasPrefix("Bac") }, "\(region) \(year.id) : \(titles)")
                }
            }
        }
    }

    /// **Les barèmes de l'élève** : sur 20 en France et au Maroc, Notenpunkte au Gymnasium,
    /// GPA aux États-Unis, pourcentage en Arabie saoudite — jamais un « /20 » américain.
    func testEachStudentGradesInTheirOwnScale() {
        func scale(_ region: String, _ country: SchoolingCountry, _ trackID: String) -> StudentGradeScale {
            let track = SchoolSystem.tracks(region: region).first { $0.id == trackID }
            return StudentGradeScale.for(region: region, country: country, track: track, locale: .fr)
        }
        XCTAssertEqual(scale("FR", .fr, "fr.lyceeGeneral").best, "20/20")
        XCTAssertEqual(scale("DE", .de, "de.gymnasium").best, "15")
        XCTAssertEqual(scale("US", .us, "us.high").best, "4.0")
        XCTAssertFalse(scale("US", .us, "us.high").scale.ticks.contains { $0.label.contains("/20") })
        XCTAssertTrue(scale("SA", .other, "sa.thanawi").best.contains("100"))
    }

    /// **Les dates proposées sont plausibles** : chaque examen à date fixe tombe dans l'année
    /// qui vient, jamais dans le passé, jamais à plus d'un an.
    func testEverySuggestedExamDateIsWithinTheComingYear() throws {
        let now = Date()
        for exam in SchoolExams.catalog.values where exam.month != nil {
            let date = try XCTUnwrap(SchoolExams.suggestedDate(for: .named(exam), from: now), exam.id)
            let days = SchoolExams.daysLeft(until: date, from: now)
            XCTAssertGreaterThanOrEqual(days, 0, exam.id)
            XCTAssertLessThanOrEqual(days, 366, exam.id)
        }
    }
}
