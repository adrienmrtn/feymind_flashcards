import Foundation

/// **Un examen, tel qu'il se nomme dans son pays** : « Bac », « Abitur », « Maturità »,
/// « PAU (Selectividad) », « ENEM ». Le nom est celui que l'élève emploie, et il ne se
/// traduit pas — c'est la règle des filières (`SchoolSystem`).
///
/// La date est **celle d'une session ordinaire**, au jour près à quelques jours : le parcours
/// la propose, l'élève la corrige en un geste. Un examen qui se passe plusieurs fois par an
/// (SAT, MCAT, Högskoleprovet…) n'a pas de jour fixe : on propose dans deux mois.
struct SchoolExam: Identifiable, Hashable {
    let id: String
    let title: String
    /// Le mois et le jour d'une session ordinaire, ou `nil` quand il y en a plusieurs par an.
    let month: Int?
    let day: Int?
    let emoji: String

    init(_ id: String, _ title: String, month: Int? = nil, day: Int? = nil, emoji: String = "📝") {
        self.id = id
        self.title = title
        self.month = month
        self.day = day
        self.emoji = emoji
    }
}

/// **Le prochain examen, tel que l'élève l'a choisi** : un examen de son pays, un contrôle,
/// ses partiels, ou rien. Écrit dans les préférences par son identifiant et sa date.
enum ExamChoice: Hashable {
    case named(SchoolExam)
    /// Un contrôle, une interro : dans deux semaines.
    case test
    /// Les examens de fin de semestre, à l'université.
    case finals
    /// Pas d'examen en vue. (Pas `none` : l'optionnel en a déjà un.)
    case noExam

    var id: String {
        switch self {
        case .named(let exam): exam.id
        case .test: SchoolExams.testID
        case .finals: SchoolExams.finalsID
        case .noExam: SchoolExams.noneID
        }
    }

    /// Le nom à l'écran et dans le calendrier : celui du pays, ou une phrase de l'app.
    func title(locale: UiLocale) -> String {
        switch self {
        case .named(let exam): exam.title
        case .test: L10n.t("ios.onb5.exam.testName", locale: locale)
        case .finals: L10n.t("ios.onb5.exam.finalsName", locale: locale)
        case .noExam: L10n.t("ios.onb5.exam.none", locale: locale)
        }
    }

    /// Le libellé de la rangée de réponse.
    func rowTitle(locale: UiLocale) -> String {
        switch self {
        case .named(let exam): exam.title
        case .test: L10n.t("ios.onb5.exam.test", locale: locale)
        case .finals: L10n.t("ios.onb5.exam.finals", locale: locale)
        case .noExam: L10n.t("ios.onb5.exam.none", locale: locale)
        }
    }

    var emoji: String {
        switch self {
        case .named(let exam): exam.emoji
        case .test: "✏️"
        case .finals: "📚"
        case .noExam: "🌱"
        }
    }

    var hasDate: Bool { self != .noExam }
}

enum SchoolExams {
    static let testID = "exam.test"
    static let finalsID = "exam.finals"
    static let noneID = "exam.none"

    /// **Les examens proposés à cet élève**, du plus précis au plus large : ceux de son année,
    /// sinon ceux de sa filière ; puis un contrôle (au collège, au lycée) ou ses partiels (après
    /// le bac) ; et « pas d'examen en vue », toujours en dernier.
    static func choices(track: SchoolTrack?, year: SchoolYear?, tier: EducationTier?) -> [ExamChoice] {
        let ids = (year?.exams.nilIfEmpty ?? track?.exams ?? [])
        var result: [ExamChoice] = ids.compactMap { catalog[$0] }.map(ExamChoice.named)
        let level = track?.tier ?? tier
        switch level {
        case .undergraduate?, .graduate?, .health?, .preUniversity?, .competitive?:
            result.append(.finals)
        default:
            result.append(.test)
        }
        result.append(.noExam)
        return result
    }

    static func choice(id: String?) -> ExamChoice? {
        switch id {
        case nil: nil
        case testID?: .test
        case finalsID?: .finals
        case noneID?: .noExam
        case let id?: catalog[id].map(ExamChoice.named)
        }
    }

    // MARK: - La date

    /// **La date proposée** pour un examen, à partir d'aujourd'hui.
    ///
    /// - un examen à session fixe : sa prochaine session, au moins dans une semaine (une
    ///   session passée de trois jours se lit comme la suivante) ;
    /// - à sessions multiples : dans deux mois ;
    /// - un contrôle : dans deux semaines ;
    /// - des partiels : mi-janvier ou début juin, le premier des deux qui laisse trois semaines.
    static func suggestedDate(for choice: ExamChoice, from now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch choice {
        case .noExam:
            return nil
        case .test:
            return calendar.date(byAdding: .day, value: 14, to: today)
        case .finals:
            let earliest = calendar.date(byAdding: .day, value: 21, to: today) ?? today
            return [(1, 15), (6, 5)]
                .compactMap { next(month: $0.0, day: $0.1, after: earliest, calendar: calendar) }
                .min()
        case .named(let exam):
            guard let month = exam.month, let day = exam.day else {
                return calendar.date(byAdding: .day, value: 60, to: today)
            }
            let earliest = calendar.date(byAdding: .day, value: 7, to: today) ?? today
            return next(month: month, day: day, after: earliest, calendar: calendar)
        }
    }

    /// Le prochain `mois/jour` qui tombe le jour donné ou après.
    static func next(month: Int, day: Int, after date: Date, calendar: Calendar) -> Date? {
        let year = calendar.component(.year, from: date)
        for candidate in [year, year + 1] {
            if let found = calendar.date(from: DateComponents(year: candidate, month: month, day: day)),
               found >= calendar.startOfDay(for: date) {
                return found
            }
        }
        return nil
    }

    /// Les jours entiers qui restent avant `date`.
    static func daysLeft(until date: Date, from now: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Int {
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    /// **« 7 mois », « 3 semaines », « 12 jours »**, écrits par le système dans la langue de
    /// l'app : il connaît les pluriels de chaque langue (le russe en a trois), que le catalogue
    /// n'écrit qu'en deux branches.
    static func remainingText(days: Int, locale: UiLocale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale.foundation
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        var components = DateComponents()
        switch days {
        case 61...:
            formatter.allowedUnits = [.month]
            components.month = Int((Double(days) / 30.4).rounded())
        case 15...:
            formatter.allowedUnits = [.weekOfMonth]
            components.weekOfMonth = Int((Double(days) / 7).rounded())
        default:
            formatter.allowedUnits = [.day]
            components.day = max(1, days)
        }
        return formatter.string(from: components) ?? "\(days)"
    }

    // MARK: - Le catalogue

    static let catalog: [String: SchoolExam] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    private static let all: [SchoolExam] = [
        // France
        SchoolExam("fr.brevet", "Brevet", month: 6, day: 25, emoji: "🎒"),
        SchoolExam("fr.bacFrancais", "Bac de français", month: 6, day: 12, emoji: "✍️"),
        SchoolExam("fr.bac", "Bac", month: 6, day: 15, emoji: "🎓"),
        SchoolExam("fr.bacPro", "Bac pro", month: 6, day: 15, emoji: "🎓"),
        SchoolExam("fr.concours", "Concours", month: 4, day: 15, emoji: "🏁"),
        // Belgique, Suisse, Luxembourg, Québec
        SchoolExam("be.ce1d", "CE1D", month: 6, day: 15, emoji: "🎒"),
        SchoolExam("be.cess", "CESS", month: 6, day: 10, emoji: "🎓"),
        SchoolExam("be.medecine", "Examen d'entrée en médecine", month: 7, day: 3, emoji: "🩺"),
        SchoolExam("ch.maturite", "Examens de maturité", month: 6, day: 1, emoji: "🎓"),
        SchoolExam("ch.matura", "Matura", month: 6, day: 1, emoji: "🎓"),
        SchoolExam("ch.ef", "Examen fédéral de médecine", month: 8, day: 25, emoji: "🩺"),
        SchoolExam("ch.eidg", "Eidgenössische Prüfung Humanmedizin", month: 8, day: 25, emoji: "🩺"),
        SchoolExam("lu.examen", "Examen de fin d'études secondaires", month: 5, day: 20, emoji: "🎓"),
        SchoolExam("ca.ministerielles", "Épreuves ministérielles", month: 6, day: 5, emoji: "📝"),
        SchoolExam("ca.euf", "Épreuve uniforme de français", month: 5, day: 7, emoji: "✍️"),
        // Maghreb, Afrique de l'Ouest
        SchoolExam("ma.regional3", "Examen régional (3e année collège)", month: 6, day: 10, emoji: "🎒"),
        SchoolExam("ma.regional", "Examen régional du bac", month: 6, day: 5, emoji: "📝"),
        SchoolExam("ma.bac", "Bac national", month: 6, day: 1, emoji: "🎓"),
        SchoolExam("ma.cnc", "Concours national commun (CNC)", month: 5, day: 1, emoji: "🏁"),
        SchoolExam("dz.bem", "BEM", month: 5, day: 20, emoji: "🎒"),
        SchoolExam("dz.bac", "Bac", month: 6, day: 12, emoji: "🎓"),
        SchoolExam("tn.neuvieme", "Concours de la 9e", month: 6, day: 15, emoji: "🎒"),
        SchoolExam("tn.bac", "Bac", month: 6, day: 5, emoji: "🎓"),
        SchoolExam("sn.bfem", "BFEM", month: 7, day: 7, emoji: "🎒"),
        SchoolExam("sn.bac", "Bac", month: 7, day: 1, emoji: "🎓"),
        SchoolExam("ci.bepc", "BEPC", month: 6, day: 1, emoji: "🎒"),
        SchoolExam("ci.bac", "Bac", month: 6, day: 10, emoji: "🎓"),
        // Deutschland, Österreich
        SchoolExam("de.msa", "Realschulabschluss (MSA)", month: 5, day: 15, emoji: "🎒"),
        SchoolExam("de.abitur", "Abitur", month: 4, day: 20, emoji: "🎓"),
        SchoolExam("de.physikum", "Physikum", month: 8, day: 18, emoji: "🩺"),
        SchoolExam("de.staatsexamen", "Staatsexamen", month: 4, day: 8, emoji: "🩺"),
        SchoolExam("at.matura", "Matura", month: 5, day: 5, emoji: "🎓"),
        // Royaume-Uni, États-Unis
        SchoolExam("uk.gcse", "GCSEs", month: 5, day: 11, emoji: "📗"),
        SchoolExam("uk.alevels", "A-levels", month: 5, day: 12, emoji: "🎓"),
        SchoolExam("us.sat", "SAT", emoji: "🎯"),
        SchoolExam("us.act", "ACT", emoji: "🎯"),
        SchoolExam("us.ap", "AP Exams", month: 5, day: 4, emoji: "📘"),
        SchoolExam("us.psat", "PSAT/NMSQT", month: 10, day: 14, emoji: "📝"),
        SchoolExam("us.gre", "GRE", emoji: "🎯"),
        SchoolExam("us.mcat", "MCAT", emoji: "🩺"),
        SchoolExam("us.usmle", "USMLE Step 1", emoji: "🩺"),
        // Europe du Sud
        SchoolExam("it.terzaMedia", "Esame di terza media", month: 6, day: 12, emoji: "🎒"),
        SchoolExam("it.invalsi", "Prove INVALSI", month: 4, day: 8, emoji: "📝"),
        SchoolExam("it.maturita", "Maturità", month: 6, day: 18, emoji: "🎓"),
        SchoolExam("es.pau", "PAU (Selectividad)", month: 6, day: 2, emoji: "🎓"),
        SchoolExam("es.mir", "MIR", month: 1, day: 24, emoji: "🩺"),
        SchoolExam("pt.provasFinais", "Provas finais do 9.º ano", month: 6, day: 17, emoji: "🎒"),
        SchoolExam("pt.exames", "Exames nacionais", month: 6, day: 17, emoji: "🎓"),
        SchoolExam("gr.panelladikes", "Πανελλαδικές Εξετάσεις", month: 5, day: 29, emoji: "🎓"),
        // Europe du Nord et de l'Est
        SchoolExam("nl.eindexamen", "Centraal eindexamen", month: 5, day: 12, emoji: "🎓"),
        SchoolExam("hu.felveteli", "Központi felvételi", month: 1, day: 17, emoji: "🎒"),
        SchoolExam("hu.erettsegi", "Érettségi", month: 5, day: 4, emoji: "🎓"),
        SchoolExam("pl.osmoklasisty", "Egzamin ósmoklasisty", month: 5, day: 19, emoji: "🎒"),
        SchoolExam("pl.matura", "Matura", month: 5, day: 4, emoji: "🎓"),
        SchoolExam("cz.prijimacky", "Přijímací zkoušky na SŠ", month: 4, day: 14, emoji: "🎒"),
        SchoolExam("cz.maturita", "Maturita", month: 5, day: 3, emoji: "🎓"),
        SchoolExam("sk.testovanie9", "Testovanie 9", month: 3, day: 18, emoji: "🎒"),
        SchoolExam("sk.maturita", "Maturita", month: 3, day: 17, emoji: "🎓"),
        SchoolExam("ro.en", "Evaluarea Națională", month: 6, day: 16, emoji: "🎒"),
        SchoolExam("ro.bac", "Bacalaureat", month: 6, day: 22, emoji: "🎓"),
        SchoolExam("se.np", "Nationella prov", month: 3, day: 10, emoji: "📝"),
        SchoolExam("se.hp", "Högskoleprovet", emoji: "🎯"),
        SchoolExam("dk.afgangsprove", "Folkeskolens afgangsprøve", month: 5, day: 6, emoji: "🎒"),
        SchoolExam("dk.studentereksamen", "Studentereksamen", month: 5, day: 20, emoji: "🎓"),
        SchoolExam("fi.yo", "Ylioppilaskoe", month: 3, day: 16, emoji: "🎓"),
        SchoolExam("ee.pohikool", "Põhikooli lõpueksamid", month: 6, day: 2, emoji: "🎒"),
        SchoolExam("ee.riigieksam", "Riigieksamid", month: 4, day: 24, emoji: "🎓"),
        SchoolExam("hr.matura", "Državna matura", month: 6, day: 2, emoji: "🎓"),
        SchoolExam("si.npz", "NPZ", month: 5, day: 6, emoji: "🎒"),
        SchoolExam("si.matura", "Splošna matura", month: 5, day: 30, emoji: "🎓"),
        SchoolExam("rs.zavrsni", "Završni ispit", month: 6, day: 17, emoji: "🎒"),
        SchoolExam("rs.matura", "Maturski ispit", month: 6, day: 1, emoji: "🎓"),
        SchoolExam("bg.nvo7", "НВО след 7. клас", month: 6, day: 17, emoji: "🎒"),
        SchoolExam("bg.nvo10", "НВО след 10. клас", month: 6, day: 12, emoji: "📝"),
        SchoolExam("bg.dzi", "ДЗИ (матури)", month: 5, day: 20, emoji: "🎓"),
        SchoolExam("ru.oge", "ОГЭ", month: 5, day: 25, emoji: "🎒"),
        SchoolExam("ru.ege", "ЕГЭ", month: 6, day: 1, emoji: "🎓"),
        SchoolExam("tr.lgs", "LGS", month: 6, day: 7, emoji: "🎒"),
        SchoolExam("tr.yks", "YKS", month: 6, day: 20, emoji: "🎓"),
        // Amérique latine
        SchoolExam("br.enem", "ENEM", month: 11, day: 8, emoji: "🎓"),
        SchoolExam("br.vestibular", "Vestibular (Fuvest, Unicamp…)", month: 11, day: 22, emoji: "🏁"),
        SchoolExam("mx.prepa", "Examen de admisión a la prepa", month: 6, day: 20, emoji: "🎒"),
        SchoolExam("mx.universidad", "Examen de admisión a la universidad", month: 5, day: 25, emoji: "🎓"),
        SchoolExam("co.saber11", "Pruebas Saber 11", month: 8, day: 9, emoji: "🎓"),
        SchoolExam("cl.paes", "PAES", month: 12, day: 1, emoji: "🎓"),
        // Monde arabe
        SchoolExam("eg.idadiya", "الشهادة الإعدادية", month: 6, day: 1, emoji: "🎒"),
        SchoolExam("eg.thanawiya", "الثانوية العامة", month: 6, day: 20, emoji: "🎓"),
        SchoolExam("sa.qudurat", "اختبار القدرات العامة", emoji: "🎯"),
        SchoolExam("sa.tahsili", "الاختبار التحصيلي", emoji: "🎓"),
    ]
}

// MARK: - Le barème de l'élève

/// **Le barème que l'élève connaît**, plus fin que celui de son pays seul : un élève de
/// Oberstufe compte en Notenpunkte, un collégien allemand de 1 à 6 ; un élève de GCSE de 9 à
/// 1, un élève de A-level en lettres ; un Brésilien sur dix, un Italien à l'université sur
/// trente.
///
/// Les notes restent sur la droite 10–20 du produit (`TargetScore`) : seuls les libellés
/// changent, onze crans du plus faible au meilleur. `note` dit, quand il le faut, que le
/// meilleur est en bas (« 1 = la meilleure note »).
struct StudentGradeScale: Equatable {
    let scale: DesiredGradeScale
    /// La meilleure note est le plus petit chiffre : on le dit sous la roue.
    let lowerIsBetter: Bool
    /// L'unité, quand le chiffre seul ne la dit pas (Notenpunkte).
    let unitKey: String?

    static func `for`(region: String?, country: SchoolingCountry, track: SchoolTrack?, locale: UiLocale = .resolved()) -> StudentGradeScale {
        let tier = track?.tier
        let university = tier == .undergraduate || tier == .graduate || tier == .health
        func make(_ labels: [String], lowerIsBetter: Bool = false, unit: String? = nil) -> StudentGradeScale {
            StudentGradeScale(
                scale: DesiredGradeScale(ticks: labels.enumerated().map { GradeTick(score: TargetScore.min + $0.offset, label: $0.element) }),
                lowerIsBetter: lowerIsBetter,
                unitKey: unit
            )
        }
        func percent(from low: Int) -> [String] {
            (0...10).map { L10n.percent(low + $0 * (100 - low) / 10, locale: locale) }
        }
        switch (region ?? "").uppercased() {
        case "DE" where track?.id == "de.gymnasium":
            return make(["05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15"], unit: "ios.onb5.grade.points")
        case "AT":
            return make(["4", "4", "3", "3", "3", "2", "2", "2", "1", "1", "1"], lowerIsBetter: true)
        case "SK":
            return make(["4", "4", "3", "3", "3", "2", "2", "2", "1", "1", "1"], lowerIsBetter: true)
        case "GB" where track?.id == "uk.gcse" || track?.id == "uk.ks3":
            return make(["4", "4", "5", "5", "6", "6", "7", "7", "8", "8", "9"])
        case "GB" where university:
            return make(["Third", "Third", "2:2", "2:2", "2:1", "2:1", "2:1", "First", "First", "First", "First"])
        case "GB":
            return make(["E", "D", "C", "C", "B", "B", "A", "A", "A", "A*", "A*"])
        case "US":
            return make(["2.0", "2.3", "2.5", "2.7", "3.0", "3.3", "3.5", "3.7", "3.8", "3.9", "4.0"])
        case "IT" where university:
            return make(["18", "20", "22", "24", "25", "26", "27", "28", "29", "30", "30L"])
        case "BR":
            return make(["5", "5,5", "6", "6,5", "7", "7,5", "8", "8,5", "9", "9,5", "10"])
        case "MX":
            return make(["6", "6", "7", "7", "8", "8", "9", "9", "10", "10", "10"])
        case "CO":
            return make(["3,0", "3,2", "3,5", "3,7", "4,0", "4,2", "4,4", "4,6", "4,8", "5,0", "5,0"])
        case "CL":
            return make(["4,0", "4,3", "4,6", "5,0", "5,3", "5,6", "6,0", "6,3", "6,6", "6,8", "7,0"])
        case "PL":
            return make(["2", "3", "3", "3", "4", "4", "4", "5", "5", "5", "6"])
        case "HU", "EE", "HR", "SI", "RS":
            return make(["2", "2", "3", "3", "3", "4", "4", "4", "5", "5", "5"])
        case "RU":
            return make(["3", "3", "3", "4", "4", "4", "4", "5", "5", "5", "5"])
        case "BG":
            return make(["3", "3", "4", "4", "4", "5", "5", "5", "6", "6", "6"])
        case "DK":
            return make(["02", "02", "4", "4", "4", "7", "7", "7", "10", "12", "12"])
        case "FI":
            return make(["6", "6", "7", "7", "7", "8", "8", "9", "9", "10", "10"])
        case "NL":
            return make(["5,5", "6", "6,5", "7", "7,5", "8", "8,5", "9", "9,5", "10", "10"])
        case "TR":
            return make(["50", "55", "60", "65", "70", "75", "80", "85", "90", "95", "100"])
        case "EG", "SA":
            return make(percent(from: 50))
        case "CA":
            return make(percent(from: 60))
        default:
            break
        }
        let base = DesiredGradeScale.for(country)
        let inverted = region?.uppercased() == "DE" || region?.uppercased() == "CZ"
        return StudentGradeScale(scale: base, lowerIsBetter: inverted, unitKey: nil)
    }

    /// La meilleure note du barème, pour la ligne « 1 = la meilleure note ».
    var best: String { scale.ticks.last?.label ?? "" }

    /// **La ligne sous la roue**, quand le chiffre seul ne suffit pas : l'unité (Notenpunkte),
    /// ou que la meilleure note est la plus petite (« 1 = la meilleure note »).
    func caption(locale: UiLocale) -> String? {
        if let unitKey { return L10n.t(unitKey, locale: locale) }
        if lowerIsBetter { return L10n.t("ios.onb5.grade.best", locale: locale, vars: ["best": best]) }
        return nil
    }
}
