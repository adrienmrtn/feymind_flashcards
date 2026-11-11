import Foundation

/// **Le pays d'un élève, par son code ISO.**
///
/// Les pays de la liste courte (`SchoolingCountry`) ont leur code ; ceux qu'on choisit dans
/// « Autre pays » (`WorldCountry`) aussi. C'est ce code, et lui seul, qui choisit le système
/// scolaire, les examens et le barème : un élève autrichien passé par « Autre pays » a sa
/// Matura, un élève brésilien son ENEM.
enum SchoolRegion {
    static func code(country: SchoolingCountry, custom: WorldCountry?) -> String? {
        country == .other ? custom?.code.uppercased() : country.regionCode
    }
}

extension SchoolingCountry {
    /// Le code ISO 3166-1 du pays (« GB » pour le Royaume-Uni), `nil` pour « Autre pays ».
    var regionCode: String? {
        switch self {
        case .uk: "GB"
        case .cz: "CZ"
        case .other: nil
        default: rawValue.uppercased()
        }
    }
}

// MARK: - Les autres pays

/// **Les systèmes scolaires écrits dans leur langue.** Chaque filière, chaque année et chaque
/// matière porte le nom que l'élève lit sur son emploi du temps ; c'est délibéré, et c'est la
/// même règle que pour la France ou la Turquie (voir `SchoolSystem`).
///
/// Les identifiants sont préfixés par le code du pays en minuscules (`it.liceo5`) : ils sont
/// relus dans les réglages, et `SchoolSystem.track(id:in:)` retrouve le pays par ce préfixe.
extension SchoolSystem {
    static func world(_ code: String) -> [SchoolTrack] {
        switch code {
        case "GB": unitedKingdom
        case "US": unitedStates
        case "IT": italy
        case "PT": portugal
        case "BR": brazil
        case "NL": netherlands
        case "GR": greece
        case "HU": hungary
        case "PL": poland
        case "CZ": czechia
        case "SK": slovakia
        case "RO": romania
        case "SE": sweden
        case "DK": denmark
        case "FI": finland
        case "EE": estonia
        case "HR": croatia
        case "SI": slovenia
        case "RS": serbia
        case "BG": bulgaria
        case "RU": russia
        case "AT": austria
        case "CH": switzerland(german: UiLocale.resolved() == .de)
        case "BE": belgium
        case "CA": canada
        case "LU": luxembourg
        case "MA": morocco
        case "DZ": algeria
        case "TN": tunisia
        case "SN": senegal
        case "CI": ivoryCoast
        case "MX": mexico
        case "CO": colombia
        case "CL": chile
        case "EG": egypt
        case "SA": saudiArabia
        default: []
        }
    }

    /// Les codes des pays décrits, pour les tests et les rendus.
    static let describedRegions: [String] = [
        "FR", "TR", "DE", "ES", "GB", "US", "IT", "PT", "BR", "NL", "GR", "HU", "PL", "CZ", "SK",
        "RO", "SE", "DK", "FI", "EE", "HR", "SI", "RS", "BG", "RU", "AT", "CH", "BE", "CA", "LU",
        "MA", "DZ", "TN", "SN", "CI", "MX", "CO", "CL", "EG", "SA",
    ]

    // MARK: Les briques

    /// Une suite d'années aux mêmes matières, la dernière portant l'examen.
    private static func years(
        _ prefix: String,
        _ titles: [String],
        subjects: [String] = [],
        lastExams: [String] = [],
        exams: [Int: [String]] = [:]
    ) -> [SchoolYear] {
        titles.enumerated().map { index, title in
            var yearExams = exams[index] ?? []
            if index == titles.count - 1 { yearExams = lastExams + yearExams }
            return SchoolYear("\(prefix)\(index + 1)", title, subjects: subjects, exams: yearExams)
        }
    }

    private static func track(
        _ id: String,
        _ title: String,
        _ emoji: String,
        _ level: StudyLevel,
        _ tier: EducationTier,
        _ years: [SchoolYear],
        exams: [String] = []
    ) -> SchoolTrack {
        SchoolTrack(id: id, title: title, emoji: emoji, level: level, tier: tier, years: years, exams: exams)
    }

    // MARK: - United Kingdom

    private static let unitedKingdom: [SchoolTrack] = [
        track("uk.ks3", "Secondary school (Years 7–9)", "🎒", .lycee, .lowerSecondary,
              years("uk.y", ["Year 7", "Year 8", "Year 9"], subjects: [
                  "English", "Maths", "Science", "History", "Geography", "French", "Spanish",
                  "Computing", "Art", "Music", "PE", "RE",
              ])),
        track("uk.gcse", "GCSEs (Years 10–11)", "📗", .lycee, .lowerSecondary,
              [
                  SchoolYear("uk.y10", "Year 10", subjects: ukGCSE),
                  SchoolYear("uk.y11", "Year 11", subjects: ukGCSE, exams: ["uk.gcse"]),
              ]),
        track("uk.alevels", "Sixth form, A-levels", "🏫", .lycee, .upperSecondary,
              [
                  SchoolYear("uk.y12", "Year 12", subjects: ukALevel),
                  SchoolYear("uk.y13", "Year 13", subjects: ukALevel, exams: ["uk.alevels"]),
              ]),
        track("uk.medicine", "Medicine", "🩺", .sante, .health,
              years("uk.med", ["Pre-clinical years", "Clinical years"], subjects: medicineEN)),
        track("uk.university", "University", "🎓", .licence, .undergraduate,
              years("uk.uni", ["First year", "Second year", "Final year"])),
        track("uk.postgraduate", "Postgraduate", "🔬", .master, .graduate,
              years("uk.pg", ["Master's", "PhD"])),
    ]

    private static let ukGCSE = [
        "English Language", "English Literature", "Maths", "Combined Science", "Biology",
        "Chemistry", "Physics", "History", "Geography", "French", "Spanish",
        "Computer Science", "Religious Studies", "Business",
    ]

    private static let ukALevel = [
        "Maths", "Further Maths", "Biology", "Chemistry", "Physics", "English Literature",
        "History", "Geography", "Psychology", "Economics", "Sociology", "Politics",
        "Computer Science", "French", "Spanish", "Business",
    ]

    private static let medicineEN = [
        "Anatomy", "Physiology", "Biochemistry", "Pharmacology", "Pathology", "Microbiology",
    ]

    // MARK: - United States

    private static let unitedStates: [SchoolTrack] = [
        track("us.middle", "Middle school", "🎒", .lycee, .lowerSecondary,
              years("us.g", ["6th grade", "7th grade", "8th grade"], subjects: [
                  "Math", "English Language Arts", "Science", "Social Studies", "Spanish",
                  "French", "Computer Science", "Art", "Music", "PE",
              ])),
        track("us.high", "High school", "🏫", .lycee, .upperSecondary,
              [
                  SchoolYear("us.hs9", "9th grade (Freshman)", subjects: usHigh),
                  SchoolYear("us.hs10", "10th grade (Sophomore)", subjects: usHigh, exams: ["us.psat", "us.ap"]),
                  SchoolYear("us.hs11", "11th grade (Junior)", subjects: usHigh, exams: ["us.sat", "us.act", "us.ap", "us.psat"]),
                  SchoolYear("us.hs12", "12th grade (Senior)", subjects: usHigh, exams: ["us.sat", "us.act", "us.ap"]),
              ]),
        track("us.college", "College", "🎓", .licence, .undergraduate,
              years("us.col", ["Freshman year", "Sophomore year", "Junior year", "Senior year"], lastExams: ["us.gre"])),
        track("us.premed", "Pre-med, medical school", "🩺", .sante, .health,
              [
                  SchoolYear("us.premed1", "Pre-med", subjects: medicineEN, exams: ["us.mcat"]),
                  SchoolYear("us.medschool", "Medical school", subjects: medicineEN, exams: ["us.usmle"]),
              ]),
        track("us.graduate", "Graduate school", "🔬", .master, .graduate,
              years("us.grad", ["Master's", "PhD"])),
    ]

    private static let usHigh = [
        "Algebra", "Geometry", "Precalculus", "Calculus", "Biology", "Chemistry", "Physics",
        "English", "US History", "World History", "Government", "Economics", "Spanish",
        "French", "Computer Science", "Psychology",
    ]

    // MARK: - Italia

    private static let italy: [SchoolTrack] = [
        track("it.media", "Scuola media", "🎒", .lycee, .lowerSecondary,
              years("it.media", ["Prima media", "Seconda media", "Terza media"], subjects: [
                  "Italiano", "Matematica", "Scienze", "Storia", "Geografia", "Inglese",
                  "Francese", "Spagnolo", "Tecnologia", "Arte e immagine", "Musica",
                  "Educazione fisica",
              ], lastExams: ["it.terzaMedia", "it.invalsi"])),
        track("it.liceo", "Liceo", "🏫", .lycee, .upperSecondary,
              years("it.liceo", ["Primo anno", "Secondo anno", "Terzo anno", "Quarto anno", "Quinto anno"], subjects: [
                  "Italiano", "Matematica", "Fisica", "Scienze naturali", "Storia", "Filosofia",
                  "Inglese", "Latino", "Greco", "Storia dell'arte", "Informatica",
                  "Scienze motorie",
              ], lastExams: ["it.maturita"])),
        track("it.tecnico", "Istituto tecnico o professionale", "⚙️", .lycee, .upperSecondary,
              years("it.tecnico", ["Primo anno", "Secondo anno", "Terzo anno", "Quarto anno", "Quinto anno"], subjects: [
                  "Italiano", "Matematica", "Inglese", "Storia", "Economia aziendale",
                  "Diritto ed economia", "Informatica", "Fisica", "Chimica", "Materie di indirizzo",
              ], lastExams: ["it.maturita"])),
        track("it.medicina", "Medicina e chirurgia", "🩺", .sante, .health,
              years("it.med", ["Primo triennio", "Secondo triennio"], subjects: [
                  "Anatomia", "Fisiologia", "Biochimica", "Istologia", "Farmacologia", "Patologia",
              ])),
        track("it.triennale", "Università, laurea triennale", "🎓", .licence, .undergraduate,
              years("it.uni", ["Primo anno", "Secondo anno", "Terzo anno"])),
        track("it.magistrale", "Laurea magistrale", "🔬", .master, .graduate,
              years("it.mag", ["Primo anno", "Secondo anno"])),
    ]

    // MARK: - Portugal

    private static let portugal: [SchoolTrack] = [
        track("pt.ciclo3", "3.º ciclo", "🎒", .lycee, .lowerSecondary,
              years("pt.b", ["7.º ano", "8.º ano", "9.º ano"], subjects: [
                  "Português", "Matemática", "Inglês", "Francês", "Ciências Naturais",
                  "Físico-Química", "História", "Geografia", "TIC", "Educação Visual",
                  "Educação Física",
              ], lastExams: ["pt.provasFinais"])),
        track("pt.secundario", "Ensino secundário", "🏫", .lycee, .upperSecondary,
              years("pt.s", ["10.º ano", "11.º ano", "12.º ano"], subjects: [
                  "Português", "Matemática A", "Física e Química A", "Biologia e Geologia",
                  "História A", "Geografia A", "Economia A", "Geometria Descritiva A",
                  "Filosofia", "Inglês", "Educação Física",
              ], lastExams: ["pt.exames"], exams: [1: ["pt.exames"]])),
        track("pt.medicina", "Medicina", "🩺", .sante, .health,
              years("pt.med", ["Ciclo básico", "Ciclo clínico"], subjects: [
                  "Anatomia", "Fisiologia", "Bioquímica", "Histologia", "Farmacologia", "Patologia",
              ])),
        track("pt.licenciatura", "Licenciatura", "🎓", .licence, .undergraduate,
              years("pt.lic", ["1.º ano", "2.º ano", "3.º ano"])),
        track("pt.mestrado", "Mestrado", "🔬", .master, .graduate,
              years("pt.mes", ["1.º ano", "2.º ano"])),
    ]

    // MARK: - Brasil

    private static let brazil: [SchoolTrack] = [
        track("br.fundamental", "Ensino fundamental (anos finais)", "🎒", .lycee, .lowerSecondary,
              years("br.f", ["6º ano", "7º ano", "8º ano", "9º ano"], subjects: [
                  "Matemática", "Português", "Ciências", "História", "Geografia", "Inglês",
                  "Arte", "Educação Física",
              ])),
        track("br.medio", "Ensino médio", "🏫", .lycee, .upperSecondary,
              years("br.m", ["1º ano", "2º ano", "3º ano"], subjects: [
                  "Matemática", "Português", "Literatura", "Redação", "Física", "Química",
                  "Biologia", "História", "Geografia", "Inglês", "Espanhol", "Filosofia",
                  "Sociologia", "Educação Física",
              ], lastExams: ["br.enem", "br.vestibular"], exams: [1: ["br.enem"]])),
        track("br.medicina", "Medicina", "🩺", .sante, .health,
              years("br.med", ["Ciclo básico", "Ciclo clínico", "Internato"], subjects: [
                  "Anatomia", "Fisiologia", "Bioquímica", "Histologia", "Farmacologia", "Patologia",
              ])),
        track("br.faculdade", "Faculdade", "🎓", .licence, .undergraduate,
              years("br.fac", ["1º ano", "2º ano", "3º ano", "4º ano", "5º ano"])),
        track("br.posgraduacao", "Pós-graduação", "🔬", .master, .graduate,
              years("br.pos", ["Mestrado", "Doutorado"])),
    ]

    // MARK: - Nederland

    private static let netherlands: [SchoolTrack] = [
        track("nl.onderbouw", "Onderbouw", "🎒", .lycee, .lowerSecondary,
              years("nl.o", ["Klas 1", "Klas 2", "Klas 3"], subjects: nlSubjects)),
        track("nl.vmbo", "Vmbo", "📗", .lycee, .lowerSecondary,
              years("nl.vmbo", ["Vmbo 3", "Vmbo 4"], subjects: nlSubjects, lastExams: ["nl.eindexamen"])),
        track("nl.havo", "Havo", "🏫", .lycee, .upperSecondary,
              years("nl.havo", ["Havo 4", "Havo 5"], subjects: nlSubjects, lastExams: ["nl.eindexamen"])),
        track("nl.vwo", "Vwo", "📐", .lycee, .upperSecondary,
              years("nl.vwo", ["Vwo 4", "Vwo 5", "Vwo 6"], subjects: nlSubjects + ["Latijn", "Grieks"], lastExams: ["nl.eindexamen"])),
        track("nl.hbo", "Hbo of universiteit (bachelor)", "🎓", .licence, .undergraduate,
              years("nl.bach", ["Jaar 1", "Jaar 2", "Jaar 3", "Jaar 4"])),
        track("nl.master", "Master", "🔬", .master, .graduate,
              years("nl.mas", ["Master"])),
    ]

    private static let nlSubjects = [
        "Nederlands", "Engels", "Wiskunde A", "Wiskunde B", "Natuurkunde", "Scheikunde",
        "Biologie", "Economie", "Geschiedenis", "Aardrijkskunde", "Frans", "Duits",
        "Maatschappijleer", "Lichamelijke opvoeding",
    ]

    // MARK: - Ελλάδα

    private static let greece: [SchoolTrack] = [
        track("gr.gymnasio", "Γυμνάσιο", "🎒", .lycee, .lowerSecondary,
              years("gr.g", ["Α΄ Γυμνασίου", "Β΄ Γυμνασίου", "Γ΄ Γυμνασίου"], subjects: grSubjects)),
        track("gr.lykeio", "Γενικό Λύκειο", "🏫", .lycee, .upperSecondary,
              years("gr.l", ["Α΄ Λυκείου", "Β΄ Λυκείου", "Γ΄ Λυκείου"], subjects: grSubjects + ["Λατινικά", "Οικονομία"], lastExams: ["gr.panelladikes"])),
        track("gr.iatriki", "Ιατρική", "🩺", .sante, .health,
              years("gr.iat", ["Προκλινικά έτη", "Κλινικά έτη"], subjects: [
                  "Ανατομία", "Φυσιολογία", "Βιοχημεία", "Ιστολογία", "Φαρμακολογία", "Παθολογία",
              ])),
        track("gr.panepistimio", "Πανεπιστήμιο", "🎓", .licence, .undergraduate,
              years("gr.uni", ["1ο έτος", "2ο έτος", "3ο έτος", "4ο έτος"])),
        track("gr.metaptychiako", "Μεταπτυχιακό", "🔬", .master, .graduate,
              years("gr.msc", ["Μεταπτυχιακό"])),
    ]

    private static let grSubjects = [
        "Νεοελληνική Γλώσσα", "Λογοτεχνία", "Μαθηματικά", "Φυσική", "Χημεία", "Βιολογία",
        "Ιστορία", "Αρχαία Ελληνικά", "Αγγλικά", "Πληροφορική", "Φυσική Αγωγή",
    ]

    // MARK: - Magyarország

    private static let hungary: [SchoolTrack] = [
        track("hu.altalanos", "Általános iskola (felső tagozat)", "🎒", .lycee, .lowerSecondary,
              years("hu.a", ["5. osztály", "6. osztály", "7. osztály", "8. osztály"], subjects: huSubjects, lastExams: ["hu.felveteli"])),
        track("hu.gimnazium", "Gimnázium", "🏫", .lycee, .upperSecondary,
              years("hu.g", ["9. osztály", "10. osztály", "11. osztály", "12. osztály"], subjects: huSubjects, lastExams: ["hu.erettsegi"])),
        track("hu.technikum", "Technikum", "⚙️", .lycee, .upperSecondary,
              years("hu.t", ["9. évfolyam", "10. évfolyam", "11. évfolyam", "12. évfolyam", "13. évfolyam"], subjects: huSubjects + ["Szakmai tárgyak"], lastExams: ["hu.erettsegi"])),
        track("hu.orvosi", "Orvosképzés", "🩺", .sante, .health,
              years("hu.orv", ["Preklinikum", "Klinikum"], subjects: [
                  "Anatómia", "Élettan", "Biokémia", "Szövettan", "Farmakológia", "Patológia",
              ])),
        track("hu.egyetem", "Egyetem (alapképzés)", "🎓", .licence, .undergraduate,
              years("hu.bsc", ["1. év", "2. év", "3. év"])),
        track("hu.mester", "Mesterképzés", "🔬", .master, .graduate,
              years("hu.msc", ["Mesterképzés"])),
    ]

    private static let huSubjects = [
        "Magyar nyelv és irodalom", "Matematika", "Történelem", "Angol", "Német", "Fizika",
        "Kémia", "Biológia", "Földrajz", "Informatika", "Testnevelés",
    ]

    // MARK: - Polska

    private static let poland: [SchoolTrack] = [
        track("pl.podstawowa", "Szkoła podstawowa (klasy 7–8)", "🎒", .lycee, .lowerSecondary,
              years("pl.sp", ["Klasa 7", "Klasa 8"], subjects: plSubjects, lastExams: ["pl.osmoklasisty"])),
        track("pl.liceum", "Liceum", "🏫", .lycee, .upperSecondary,
              years("pl.lo", ["Klasa 1", "Klasa 2", "Klasa 3", "Klasa 4"], subjects: plSubjects + ["WOS", "Filozofia"], lastExams: ["pl.matura"])),
        track("pl.technikum", "Technikum", "⚙️", .lycee, .upperSecondary,
              years("pl.tech", ["Klasa 1", "Klasa 2", "Klasa 3", "Klasa 4", "Klasa 5"], subjects: plSubjects + ["Przedmioty zawodowe"], lastExams: ["pl.matura"])),
        track("pl.medycyna", "Medycyna", "🩺", .sante, .health,
              years("pl.med", ["Lata przedkliniczne", "Lata kliniczne"], subjects: [
                  "Anatomia", "Fizjologia", "Biochemia", "Histologia", "Farmakologia", "Patologia",
              ])),
        track("pl.licencjat", "Studia licencjackie", "🎓", .licence, .undergraduate,
              years("pl.lic", ["1. rok", "2. rok", "3. rok"])),
        track("pl.magister", "Studia magisterskie", "🔬", .master, .graduate,
              years("pl.mgr", ["1. rok", "2. rok"])),
    ]

    private static let plSubjects = [
        "Język polski", "Matematyka", "Język angielski", "Język niemiecki", "Historia",
        "Biologia", "Chemia", "Fizyka", "Geografia", "Informatyka", "Wychowanie fizyczne",
    ]

    // MARK: - Česko

    private static let czechia: [SchoolTrack] = [
        track("cz.zakladni", "Základní škola (2. stupeň)", "🎒", .lycee, .lowerSecondary,
              years("cz.zs", ["6. třída", "7. třída", "8. třída", "9. třída"], subjects: czSubjects, lastExams: ["cz.prijimacky"])),
        track("cz.gymnazium", "Gymnázium", "🏫", .lycee, .upperSecondary,
              years("cz.gym", ["1. ročník", "2. ročník", "3. ročník", "4. ročník"], subjects: czSubjects + ["Základy společenských věd"], lastExams: ["cz.maturita"])),
        track("cz.sos", "Střední odborná škola", "⚙️", .lycee, .upperSecondary,
              years("cz.sos", ["1. ročník", "2. ročník", "3. ročník", "4. ročník"], subjects: czSubjects + ["Odborné předměty"], lastExams: ["cz.maturita"])),
        track("cz.medicina", "Medicína", "🩺", .sante, .health,
              years("cz.med", ["Preklinika", "Klinika"], subjects: [
                  "Anatomie", "Fyziologie", "Biochemie", "Histologie", "Farmakologie", "Patologie",
              ])),
        track("cz.bakalar", "Bakalářské studium", "🎓", .licence, .undergraduate,
              years("cz.bc", ["1. ročník", "2. ročník", "3. ročník"])),
        track("cz.magistr", "Magisterské studium", "🔬", .master, .graduate,
              years("cz.mgr", ["1. ročník", "2. ročník"])),
    ]

    private static let czSubjects = [
        "Český jazyk a literatura", "Matematika", "Anglický jazyk", "Německý jazyk", "Fyzika",
        "Chemie", "Biologie", "Dějepis", "Zeměpis", "Informatika", "Tělesná výchova",
    ]

    // MARK: - Slovensko

    private static let slovakia: [SchoolTrack] = [
        track("sk.zakladna", "Základná škola (2. stupeň)", "🎒", .lycee, .lowerSecondary,
              years("sk.zs", ["5. ročník", "6. ročník", "7. ročník", "8. ročník", "9. ročník"], subjects: skSubjects, lastExams: ["sk.testovanie9"])),
        track("sk.gymnazium", "Gymnázium", "🏫", .lycee, .upperSecondary,
              years("sk.gym", ["1. ročník", "2. ročník", "3. ročník", "4. ročník"], subjects: skSubjects + ["Občianska náuka"], lastExams: ["sk.maturita"])),
        track("sk.sos", "Stredná odborná škola", "⚙️", .lycee, .upperSecondary,
              years("sk.sos", ["1. ročník", "2. ročník", "3. ročník", "4. ročník"], subjects: skSubjects + ["Odborné predmety"], lastExams: ["sk.maturita"])),
        track("sk.medicina", "Medicína", "🩺", .sante, .health,
              years("sk.med", ["Predklinika", "Klinika"], subjects: [
                  "Anatómia", "Fyziológia", "Biochémia", "Histológia", "Farmakológia", "Patológia",
              ])),
        track("sk.bakalar", "Bakalárske štúdium", "🎓", .licence, .undergraduate,
              years("sk.bc", ["1. ročník", "2. ročník", "3. ročník"])),
        track("sk.magister", "Magisterské štúdium", "🔬", .master, .graduate,
              years("sk.mgr", ["1. ročník", "2. ročník"])),
    ]

    private static let skSubjects = [
        "Slovenský jazyk a literatúra", "Matematika", "Anglický jazyk", "Nemecký jazyk",
        "Fyzika", "Chémia", "Biológia", "Dejepis", "Geografia", "Informatika",
        "Telesná a športová výchova",
    ]

    // MARK: - România

    private static let romania: [SchoolTrack] = [
        track("ro.gimnaziu", "Gimnaziu", "🎒", .lycee, .lowerSecondary,
              years("ro.g", ["Clasa a V-a", "Clasa a VI-a", "Clasa a VII-a", "Clasa a VIII-a"], subjects: roSubjects, lastExams: ["ro.en"])),
        track("ro.liceu", "Liceu", "🏫", .lycee, .upperSecondary,
              years("ro.l", ["Clasa a IX-a", "Clasa a X-a", "Clasa a XI-a", "Clasa a XII-a"], subjects: roSubjects + ["Logică", "Psihologie"], lastExams: ["ro.bac"])),
        track("ro.medicina", "Medicină", "🩺", .sante, .health,
              years("ro.med", ["Anii preclinici", "Anii clinici"], subjects: [
                  "Anatomie", "Fiziologie", "Biochimie", "Histologie", "Farmacologie", "Patologie",
              ])),
        track("ro.licenta", "Facultate (licență)", "🎓", .licence, .undergraduate,
              years("ro.lic", ["Anul I", "Anul II", "Anul III", "Anul IV"])),
        track("ro.master", "Master", "🔬", .master, .graduate,
              years("ro.mas", ["Anul I", "Anul II"])),
    ]

    private static let roSubjects = [
        "Limba și literatura română", "Matematică", "Fizică", "Chimie", "Biologie", "Istorie",
        "Geografie", "Limba engleză", "Limba franceză", "Informatică", "Educație fizică",
    ]

    // MARK: - Sverige

    private static let sweden: [SchoolTrack] = [
        track("se.hogstadiet", "Högstadiet", "🎒", .lycee, .lowerSecondary,
              years("se.h", ["Årskurs 7", "Årskurs 8", "Årskurs 9"], subjects: seSubjects, lastExams: ["se.np"])),
        track("se.gymnasiet", "Gymnasiet", "🏫", .lycee, .upperSecondary,
              years("se.g", ["År 1", "År 2", "År 3"], subjects: seSubjects + ["Psykologi", "Filosofi"], lastExams: ["se.np", "se.hp"], exams: [1: ["se.hp"]])),
        track("se.lakare", "Läkarprogrammet", "🩺", .sante, .health,
              years("se.lak", ["Preklinisk del", "Klinisk del"], subjects: [
                  "Anatomi", "Fysiologi", "Biokemi", "Histologi", "Farmakologi", "Patologi",
              ])),
        track("se.kandidat", "Universitet (kandidat)", "🎓", .licence, .undergraduate,
              years("se.kand", ["År 1", "År 2", "År 3"])),
        track("se.master", "Master", "🔬", .master, .graduate,
              years("se.mas", ["Master"])),
    ]

    private static let seSubjects = [
        "Svenska", "Matematik", "Engelska", "Biologi", "Fysik", "Kemi", "Historia",
        "Samhällskunskap", "Geografi", "Religionskunskap", "Moderna språk", "Idrott och hälsa",
    ]

    // MARK: - Danmark

    private static let denmark: [SchoolTrack] = [
        track("dk.folkeskole", "Folkeskolen (udskolingen)", "🎒", .lycee, .lowerSecondary,
              years("dk.f", ["7. klasse", "8. klasse", "9. klasse", "10. klasse"], subjects: dkSubjects, lastExams: ["dk.afgangsprove"], exams: [2: ["dk.afgangsprove"]])),
        track("dk.gymnasium", "Gymnasiet (stx, hhx, htx)", "🏫", .lycee, .upperSecondary,
              years("dk.g", ["1.g", "2.g", "3.g"], subjects: dkSubjects + ["Samfundsfag", "Kemi"], lastExams: ["dk.studentereksamen"])),
        track("dk.medicin", "Medicin", "🩺", .sante, .health,
              years("dk.med", ["Bachelordelen", "Kandidatdelen"], subjects: [
                  "Anatomi", "Fysiologi", "Biokemi", "Histologi", "Farmakologi", "Patologi",
              ])),
        track("dk.bachelor", "Universitet (bachelor)", "🎓", .licence, .undergraduate,
              years("dk.bach", ["1. år", "2. år", "3. år"])),
        track("dk.kandidat", "Kandidat", "🔬", .master, .graduate,
              years("dk.kand", ["Kandidat"])),
    ]

    private static let dkSubjects = [
        "Dansk", "Matematik", "Engelsk", "Tysk", "Fysik/kemi", "Biologi", "Geografi",
        "Historie", "Kristendomskundskab", "Idræt",
    ]

    // MARK: - Suomi

    private static let finland: [SchoolTrack] = [
        track("fi.ylakoulu", "Yläkoulu", "🎒", .lycee, .lowerSecondary,
              years("fi.y", ["7. luokka", "8. luokka", "9. luokka"], subjects: fiSubjects)),
        track("fi.lukio", "Lukio", "🏫", .lycee, .upperSecondary,
              years("fi.l", ["1. vuosi", "2. vuosi", "3. vuosi"], subjects: fiSubjects + ["Psykologia", "Filosofia"], lastExams: ["fi.yo"], exams: [1: ["fi.yo"]])),
        track("fi.laaketiede", "Lääketiede", "🩺", .sante, .health,
              years("fi.lt", ["Prekliininen vaihe", "Kliininen vaihe"], subjects: [
                  "Anatomia", "Fysiologia", "Biokemia", "Histologia", "Farmakologia", "Patologia",
              ])),
        track("fi.kandidaatti", "Yliopisto (kandidaatti)", "🎓", .licence, .undergraduate,
              years("fi.kand", ["1. vuosi", "2. vuosi", "3. vuosi"])),
        track("fi.maisteri", "Maisteri", "🔬", .master, .graduate,
              years("fi.mais", ["Maisteri"])),
    ]

    private static let fiSubjects = [
        "Äidinkieli ja kirjallisuus", "Matematiikka", "Englanti", "Ruotsi", "Fysiikka",
        "Kemia", "Biologia", "Maantieto", "Historia", "Yhteiskuntaoppi", "Liikunta",
    ]

    // MARK: - Eesti

    private static let estonia: [SchoolTrack] = [
        track("ee.pohikool", "Põhikool (III kooliaste)", "🎒", .lycee, .lowerSecondary,
              years("ee.p", ["7. klass", "8. klass", "9. klass"], subjects: eeSubjects, lastExams: ["ee.pohikool"])),
        track("ee.gumnaasium", "Gümnaasium", "🏫", .lycee, .upperSecondary,
              years("ee.g", ["10. klass", "11. klass", "12. klass"], subjects: eeSubjects, lastExams: ["ee.riigieksam"])),
        track("ee.arstiteadus", "Arstiteadus", "🩺", .sante, .health,
              years("ee.arst", ["Prekliiniline õpe", "Kliiniline õpe"], subjects: [
                  "Anatoomia", "Füsioloogia", "Biokeemia", "Histoloogia", "Farmakoloogia", "Patoloogia",
              ])),
        track("ee.bakalaureus", "Bakalaureuseõpe", "🎓", .licence, .undergraduate,
              years("ee.bak", ["1. aasta", "2. aasta", "3. aasta"])),
        track("ee.magister", "Magistriõpe", "🔬", .master, .graduate,
              years("ee.mag", ["Magistriõpe"])),
    ]

    private static let eeSubjects = [
        "Eesti keel", "Kirjandus", "Matemaatika", "Inglise keel", "Vene keel", "Füüsika",
        "Keemia", "Bioloogia", "Geograafia", "Ajalugu", "Ühiskonnaõpetus", "Kehaline kasvatus",
    ]

    // MARK: - Hrvatska

    private static let croatia: [SchoolTrack] = [
        track("hr.osnovna", "Osnovna škola (viši razredi)", "🎒", .lycee, .lowerSecondary,
              years("hr.os", ["5. razred", "6. razred", "7. razred", "8. razred"], subjects: hrSubjects)),
        track("hr.gimnazija", "Gimnazija", "🏫", .lycee, .upperSecondary,
              years("hr.gim", ["1. razred", "2. razred", "3. razred", "4. razred"], subjects: hrSubjects + ["Latinski jezik"], lastExams: ["hr.matura"])),
        track("hr.strukovna", "Strukovna škola", "⚙️", .lycee, .upperSecondary,
              years("hr.str", ["1. razred", "2. razred", "3. razred", "4. razred"], subjects: hrSubjects + ["Strukovni predmeti"], lastExams: ["hr.matura"])),
        track("hr.medicina", "Medicina", "🩺", .sante, .health,
              years("hr.med", ["Pretklinika", "Klinika"], subjects: [
                  "Anatomija", "Fiziologija", "Biokemija", "Histologija", "Farmakologija", "Patologija",
              ])),
        track("hr.preddiplomski", "Prijediplomski studij", "🎓", .licence, .undergraduate,
              years("hr.pred", ["1. godina", "2. godina", "3. godina"])),
        track("hr.diplomski", "Diplomski studij", "🔬", .master, .graduate,
              years("hr.dipl", ["1. godina", "2. godina"])),
    ]

    private static let hrSubjects = [
        "Hrvatski jezik", "Matematika", "Engleski jezik", "Njemački jezik", "Fizika", "Kemija",
        "Biologija", "Povijest", "Geografija", "Informatika", "Tjelesna i zdravstvena kultura",
    ]

    // MARK: - Slovenija

    private static let slovenia: [SchoolTrack] = [
        track("si.osnovna", "Osnovna šola (tretje triletje)", "🎒", .lycee, .lowerSecondary,
              years("si.os", ["7. razred", "8. razred", "9. razred"], subjects: siSubjects, lastExams: ["si.npz"])),
        track("si.gimnazija", "Gimnazija", "🏫", .lycee, .upperSecondary,
              years("si.gim", ["1. letnik", "2. letnik", "3. letnik", "4. letnik"], subjects: siSubjects + ["Psihologija", "Filozofija"], lastExams: ["si.matura"])),
        track("si.medicina", "Medicina", "🩺", .sante, .health,
              years("si.med", ["Predklinični del", "Klinični del"], subjects: [
                  "Anatomija", "Fiziologija", "Biokemija", "Histologija", "Farmakologija", "Patologija",
              ])),
        track("si.dodiplomski", "Univerza (1. stopnja)", "🎓", .licence, .undergraduate,
              years("si.uni", ["1. letnik", "2. letnik", "3. letnik"])),
        track("si.magistrski", "Magistrski študij", "🔬", .master, .graduate,
              years("si.mag", ["1. letnik", "2. letnik"])),
    ]

    private static let siSubjects = [
        "Slovenščina", "Matematika", "Angleščina", "Nemščina", "Fizika", "Kemija", "Biologija",
        "Zgodovina", "Geografija", "Informatika", "Športna vzgoja",
    ]

    // MARK: - Srbija

    private static let serbia: [SchoolTrack] = [
        track("rs.osnovna", "Osnovna škola (viši razredi)", "🎒", .lycee, .lowerSecondary,
              years("rs.os", ["5. razred", "6. razred", "7. razred", "8. razred"], subjects: rsSubjects, lastExams: ["rs.zavrsni"])),
        track("rs.gimnazija", "Gimnazija", "🏫", .lycee, .upperSecondary,
              years("rs.gim", ["1. razred", "2. razred", "3. razred", "4. razred"], subjects: rsSubjects + ["Latinski jezik", "Filozofija"], lastExams: ["rs.matura"])),
        track("rs.srednja", "Srednja stručna škola", "⚙️", .lycee, .upperSecondary,
              years("rs.ss", ["1. razred", "2. razred", "3. razred", "4. razred"], subjects: rsSubjects + ["Stručni predmeti"], lastExams: ["rs.matura"])),
        track("rs.medicina", "Medicina", "🩺", .sante, .health,
              years("rs.med", ["Pretklinika", "Klinika"], subjects: [
                  "Anatomija", "Fiziologija", "Biohemija", "Histologija", "Farmakologija", "Patologija",
              ])),
        track("rs.osnovne", "Osnovne studije", "🎓", .licence, .undergraduate,
              years("rs.os.st", ["1. godina", "2. godina", "3. godina", "4. godina"])),
        track("rs.master", "Master studije", "🔬", .master, .graduate,
              years("rs.mas", ["Master"])),
    ]

    private static let rsSubjects = [
        "Srpski jezik i književnost", "Matematika", "Engleski jezik", "Fizika", "Hemija",
        "Biologija", "Istorija", "Geografija", "Informatika i računarstvo", "Fizičko vaspitanje",
    ]

    // MARK: - България

    private static let bulgaria: [SchoolTrack] = [
        track("bg.progimnazia", "Прогимназия", "🎒", .lycee, .lowerSecondary,
              years("bg.p", ["5. клас", "6. клас", "7. клас"], subjects: bgSubjects, lastExams: ["bg.nvo7"])),
        track("bg.gimnazia", "Гимназия", "🏫", .lycee, .upperSecondary,
              years("bg.g", ["8. клас", "9. клас", "10. клас", "11. клас", "12. клас"], subjects: bgSubjects + ["Философия"], lastExams: ["bg.dzi"], exams: [2: ["bg.nvo10"]])),
        track("bg.medicina", "Медицина", "🩺", .sante, .health,
              years("bg.med", ["Предклинични години", "Клинични години"], subjects: [
                  "Анатомия", "Физиология", "Биохимия", "Хистология", "Фармакология", "Патология",
              ])),
        track("bg.bakalavar", "Бакалавър", "🎓", .licence, .undergraduate,
              years("bg.bak", ["1. курс", "2. курс", "3. курс", "4. курс"])),
        track("bg.magistar", "Магистър", "🔬", .master, .graduate,
              years("bg.mag", ["Магистър"])),
    ]

    private static let bgSubjects = [
        "Български език и литература", "Математика", "Английски език", "Немски език",
        "Физика и астрономия", "Химия и опазване на околната среда",
        "Биология и здравно образование", "История и цивилизации", "География и икономика",
        "Информационни технологии", "Физическо възпитание и спорт",
    ]

    // MARK: - Россия

    private static let russia: [SchoolTrack] = [
        track("ru.osnovnaya", "Основная школа", "🎒", .lycee, .lowerSecondary,
              years("ru.o", ["5 класс", "6 класс", "7 класс", "8 класс", "9 класс"], subjects: ruSubjects, lastExams: ["ru.oge"])),
        track("ru.starshaya", "Старшая школа", "🏫", .lycee, .upperSecondary,
              years("ru.s", ["10 класс", "11 класс"], subjects: ruSubjects + ["Обществознание"], lastExams: ["ru.ege"])),
        track("ru.meditsina", "Медицинский вуз", "🩺", .sante, .health,
              years("ru.med", ["Доклинические курсы", "Клинические курсы"], subjects: [
                  "Анатомия", "Физиология", "Биохимия", "Гистология", "Фармакология", "Патология",
              ])),
        track("ru.bakalavriat", "Бакалавриат", "🎓", .licence, .undergraduate,
              years("ru.bak", ["1 курс", "2 курс", "3 курс", "4 курс"])),
        track("ru.magistratura", "Магистратура", "🔬", .master, .graduate,
              years("ru.mag", ["1 курс", "2 курс"])),
    ]

    private static let ruSubjects = [
        "Русский язык", "Литература", "Алгебра", "Геометрия", "Физика", "Химия", "Биология",
        "История", "География", "Английский язык", "Информатика", "Физкультура",
    ]

    // MARK: - Österreich

    private static let austria: [SchoolTrack] = [
        track("at.unterstufe", "Unterstufe (AHS, Mittelschule)", "🎒", .lycee, .lowerSecondary,
              years("at.u", ["1. Klasse", "2. Klasse", "3. Klasse", "4. Klasse"], subjects: atSubjects)),
        track("at.oberstufe", "AHS-Oberstufe", "🏫", .lycee, .upperSecondary,
              years("at.o", ["5. Klasse", "6. Klasse", "7. Klasse", "8. Klasse"], subjects: atSubjects + ["Psychologie und Philosophie"], lastExams: ["at.matura"])),
        track("at.bhs", "BHS (HAK, HTL, HLW …)", "⚙️", .lycee, .upperSecondary,
              years("at.bhs", ["1. Jahrgang", "2. Jahrgang", "3. Jahrgang", "4. Jahrgang", "5. Jahrgang"], subjects: [
                  "Deutsch", "Englisch", "Angewandte Mathematik", "Betriebswirtschaft",
                  "Rechnungswesen", "Informatik", "Zweite lebende Fremdsprache", "Fachtheorie",
              ], lastExams: ["at.matura"])),
        track("at.medizin", "Medizin", "🩺", .sante, .health,
              years("at.med", ["1. Studienabschnitt", "2. und 3. Studienabschnitt"], subjects: [
                  "Anatomie", "Physiologie", "Biochemie", "Histologie", "Pharmakologie", "Pathologie",
              ])),
        track("at.bachelor", "Universität, Bachelor", "🎓", .licence, .undergraduate,
              years("at.bach", ["1. Studienjahr", "2. Studienjahr", "3. Studienjahr"])),
        track("at.master", "Master", "🔬", .master, .graduate,
              years("at.mas", ["Master"])),
    ]

    private static let atSubjects = [
        "Deutsch", "Mathematik", "Englisch", "Biologie und Umweltbildung",
        "Geographie und wirtschaftliche Bildung", "Geschichte und Politische Bildung", "Physik",
        "Chemie", "Latein", "Französisch", "Informatik", "Bewegung und Sport",
    ]

    // MARK: - Suisse, Schweiz

    /// La Suisse se nomme dans la langue de l'app : un élève de Zurich lit « Gymnasium » et
    /// « Matura », un élève de Lausanne « Gymnase » et « maturité ».
    private static func switzerland(german: Bool) -> [SchoolTrack] {
        if german {
            return [
                track("ch.sek", "Sekundarstufe I", "🎒", .lycee, .lowerSecondary,
                      years("ch.sek", ["1. Sek", "2. Sek", "3. Sek"], subjects: [
                          "Deutsch", "Mathematik", "Französisch", "Englisch", "Natur und Technik",
                          "Räume, Zeiten, Gesellschaften", "Informatik", "Bildnerisches Gestalten",
                          "Musik", "Sport",
                      ])),
                track("ch.gym", "Gymnasium, Kantonsschule", "🏫", .lycee, .upperSecondary,
                      years("ch.gym", ["1. Jahr", "2. Jahr", "3. Jahr", "4. Jahr"], subjects: [
                          "Deutsch", "Mathematik", "Französisch", "Englisch", "Italienisch",
                          "Latein", "Biologie", "Chemie", "Physik", "Geschichte", "Geografie",
                          "Wirtschaft und Recht", "Informatik",
                      ], lastExams: ["ch.matura"])),
                track("ch.medizin", "Medizin", "🩺", .sante, .health,
                      years("ch.med", ["Bachelor", "Master"], subjects: [
                          "Anatomie", "Physiologie", "Biochemie", "Histologie", "Pharmakologie", "Pathologie",
                      ], lastExams: ["ch.eidg"])),
                track("ch.bachelor", "Universität, ETH, FH: Bachelor", "🎓", .licence, .undergraduate,
                      years("ch.bach", ["1. Studienjahr", "2. Studienjahr", "3. Studienjahr"])),
                track("ch.master", "Master", "🔬", .master, .graduate, years("ch.mas", ["Master"])),
            ]
        }
        return [
            track("ch.sek", "Secondaire I (cycle d'orientation)", "🎒", .lycee, .lowerSecondary,
                  years("ch.sek", ["9e", "10e", "11e"], subjects: [
                      "Français", "Mathématiques", "Allemand", "Anglais", "Sciences de la nature",
                      "Histoire", "Géographie", "Informatique", "Arts visuels", "Musique",
                      "Éducation physique",
                  ])),
            track("ch.gym", "Gymnase, collège (maturité)", "🏫", .lycee, .upperSecondary,
                  years("ch.gym", ["1re année", "2e année", "3e année", "4e année"], subjects: [
                      "Français", "Mathématiques", "Allemand", "Anglais", "Italien", "Latin",
                      "Biologie", "Chimie", "Physique", "Histoire", "Géographie",
                      "Économie et droit", "Philosophie", "Informatique",
                  ], lastExams: ["ch.maturite"])),
            track("ch.medizin", "Médecine", "🩺", .sante, .health,
                  years("ch.med", ["Bachelor", "Master"], subjects: [
                      "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Pathologie",
                  ], lastExams: ["ch.ef"])),
            track("ch.bachelor", "Université, EPF, HES : bachelor", "🎓", .licence, .undergraduate,
                  years("ch.bach", ["1re année", "2e année", "3e année"])),
            track("ch.master", "Master", "🔬", .master, .graduate, years("ch.mas", ["Master"])),
        ]
    }

    // MARK: - Belgique

    private static let belgium: [SchoolTrack] = [
        track("be.inferieur", "Secondaire, 1er degré", "🎒", .lycee, .lowerSecondary,
              years("be.s", ["1re secondaire", "2e secondaire"], subjects: beSubjects, lastExams: ["be.ce1d"])),
        track("be.superieur", "Secondaire, 2e et 3e degrés", "🏫", .lycee, .upperSecondary,
              [
                  SchoolYear("be.s3", "3e secondaire", subjects: beSubjects),
                  SchoolYear("be.s4", "4e secondaire", subjects: beSubjects),
                  SchoolYear("be.s5", "5e secondaire", subjects: beSubjects + ["Chimie", "Physique", "Biologie"]),
                  SchoolYear("be.s6", "6e secondaire", subjects: beSubjects + ["Chimie", "Physique", "Biologie"], exams: ["be.cess", "be.medecine"]),
              ]),
        track("be.medecine", "Médecine, santé", "🩺", .sante, .health,
              years("be.med", ["Bachelier", "Master"], subjects: [
                  "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Pathologie",
              ])),
        track("be.bachelier", "Haute école, université : bachelier", "🎓", .licence, .undergraduate,
              years("be.bloc", ["Bloc 1", "Bloc 2", "Bloc 3"])),
        track("be.master", "Master", "🔬", .master, .graduate,
              years("be.mas", ["Master 1", "Master 2"])),
    ]

    private static let beSubjects = [
        "Français", "Mathématiques", "Néerlandais", "Anglais", "Sciences", "Histoire",
        "Géographie", "Latin", "Éducation physique", "Religion ou morale",
    ]

    // MARK: - Canada (Québec)

    private static let canada: [SchoolTrack] = [
        track("ca.secondaire", "Secondaire", "🎒", .lycee, .upperSecondary,
              [
                  SchoolYear("ca.sec1", "Secondaire 1", subjects: caSubjects),
                  SchoolYear("ca.sec2", "Secondaire 2", subjects: caSubjects),
                  SchoolYear("ca.sec3", "Secondaire 3", subjects: caSubjects),
                  SchoolYear("ca.sec4", "Secondaire 4", subjects: caSubjects, exams: ["ca.ministerielles"]),
                  SchoolYear("ca.sec5", "Secondaire 5", subjects: caSubjects + ["Chimie", "Physique"], exams: ["ca.ministerielles"]),
              ]),
        track("ca.cegep", "Cégep", "📐", .lycee, .preUniversity,
              years("ca.cegep", ["1re année", "2e année", "3e année (technique)"], subjects: [
                  "Français", "Philosophie", "Anglais", "Mathématiques", "Chimie", "Physique",
                  "Biologie", "Psychologie", "Économie",
              ], exams: [1: ["ca.euf"]])),
        track("ca.medecine", "Médecine, santé", "🩺", .sante, .health,
              years("ca.med", ["Préclinique", "Externat"], subjects: [
                  "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Pathologie",
              ])),
        track("ca.bac", "Université : baccalauréat", "🎓", .licence, .undergraduate,
              years("ca.bac", ["1re année", "2e année", "3e année"])),
        track("ca.maitrise", "Maîtrise", "🔬", .master, .graduate,
              years("ca.mai", ["Maîtrise"])),
    ]

    private static let caSubjects = [
        "Français", "Mathématiques", "Anglais", "Science et technologie", "Histoire",
        "Géographie", "Culture et citoyenneté québécoise", "Arts", "Éducation physique",
    ]

    // MARK: - Luxembourg

    private static let luxembourg: [SchoolTrack] = [
        track("lu.inferieur", "Secondaire, classes inférieures", "🎒", .lycee, .lowerSecondary,
              years("lu.i", ["7e", "6e", "5e"], subjects: luSubjects)),
        track("lu.superieur", "Secondaire, classes supérieures", "🏫", .lycee, .upperSecondary,
              years("lu.s", ["4e", "3e", "2e", "1re"], subjects: luSubjects + ["Philosophie", "Chimie", "Physique"], lastExams: ["lu.examen"])),
        track("lu.bachelor", "Bachelor", "🎓", .licence, .undergraduate,
              years("lu.bach", ["1re année", "2e année", "3e année"])),
        track("lu.master", "Master", "🔬", .master, .graduate,
              years("lu.mas", ["Master"])),
    ]

    private static let luSubjects = [
        "Français", "Allemand", "Luxembourgeois", "Anglais", "Mathématiques", "Biologie",
        "Histoire", "Géographie", "Informatique", "Éducation physique",
    ]

    // MARK: - Maghreb et Afrique de l'Ouest

    private static let maghrebSubjects = [
        "Mathématiques", "Physique-Chimie", "SVT", "Arabe", "Français", "Anglais",
        "Histoire-Géographie", "Philosophie", "Éducation islamique", "Informatique",
    ]

    private static let westAfricaSubjects = [
        "Mathématiques", "Physique-Chimie", "SVT", "Français", "Anglais", "Espagnol",
        "Histoire-Géographie", "Philosophie", "Éducation civique", "EPS",
    ]

    private static func university(_ code: String, medicine: String = "Médecine") -> [SchoolTrack] {
        [
            track("\(code).medecine", medicine, "🩺", .sante, .health,
                  years("\(code).med", ["Années précliniques", "Années cliniques"], subjects: [
                      "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Sémiologie",
                  ])),
            track("\(code).licence", "Université : licence", "🎓", .licence, .undergraduate,
                  years("\(code).lic", ["Licence 1", "Licence 2", "Licence 3"])),
            track("\(code).master", "Master", "🔬", .master, .graduate,
                  years("\(code).mas", ["Master 1", "Master 2"])),
        ]
    }

    private static let morocco: [SchoolTrack] = [
        track("ma.college", "Collège", "🎒", .lycee, .lowerSecondary,
              years("ma.c", ["1re année collège", "2e année collège", "3e année collège"], subjects: maghrebSubjects, lastExams: ["ma.regional3"])),
        track("ma.lycee", "Lycée", "🏫", .lycee, .upperSecondary,
              [
                  SchoolYear("ma.tc", "Tronc commun", subjects: maghrebSubjects),
                  SchoolYear("ma.1bac", "1re année bac", subjects: maghrebSubjects, exams: ["ma.regional"]),
                  SchoolYear("ma.2bac", "2e année bac", subjects: maghrebSubjects, exams: ["ma.bac"]),
              ]),
        track("ma.prepa", "Classes prépa (CPGE)", "📐", .prepa, .preUniversity,
              years("ma.cpge", ["1re année", "2e année"], subjects: [
                  "Mathématiques", "Physique", "Chimie", "Sciences de l'ingénieur", "Informatique",
                  "Français", "Anglais",
              ], lastExams: ["ma.cnc"])),
    ] + university("ma")

    private static let algeria: [SchoolTrack] = [
        track("dz.moyen", "Moyen (CEM)", "🎒", .lycee, .lowerSecondary,
              years("dz.am", ["1re AM", "2e AM", "3e AM", "4e AM"], subjects: maghrebSubjects + ["Tamazight"], lastExams: ["dz.bem"])),
        track("dz.lycee", "Lycée", "🏫", .lycee, .upperSecondary,
              years("dz.as", ["1re AS", "2e AS", "3e AS"], subjects: maghrebSubjects + ["Tamazight"], lastExams: ["dz.bac"])),
    ] + university("dz")

    private static let tunisia: [SchoolTrack] = [
        track("tn.college", "Collège", "🎒", .lycee, .lowerSecondary,
              years("tn.c", ["7e année de base", "8e année de base", "9e année de base"], subjects: maghrebSubjects, lastExams: ["tn.neuvieme"])),
        track("tn.lycee", "Lycée", "🏫", .lycee, .upperSecondary,
              years("tn.l", ["1re année secondaire", "2e année secondaire", "3e année secondaire", "4e année (bac)"], subjects: maghrebSubjects, lastExams: ["tn.bac"])),
    ] + university("tn")

    private static let senegal: [SchoolTrack] = [
        track("sn.moyen", "Collège (moyen)", "🎒", .lycee, .lowerSecondary,
              years("sn.c", ["6e", "5e", "4e", "3e"], subjects: westAfricaSubjects, lastExams: ["sn.bfem"])),
        track("sn.lycee", "Lycée", "🏫", .lycee, .upperSecondary,
              years("sn.l", ["Seconde", "Première", "Terminale"], subjects: westAfricaSubjects, lastExams: ["sn.bac"])),
    ] + university("sn")

    private static let ivoryCoast: [SchoolTrack] = [
        track("ci.college", "Collège", "🎒", .lycee, .lowerSecondary,
              years("ci.c", ["6e", "5e", "4e", "3e"], subjects: westAfricaSubjects, lastExams: ["ci.bepc"])),
        track("ci.lycee", "Lycée", "🏫", .lycee, .upperSecondary,
              years("ci.l", ["Seconde", "Première", "Terminale"], subjects: westAfricaSubjects, lastExams: ["ci.bac"])),
    ] + university("ci")

    // MARK: - México, Colombia, Chile

    private static let latamSubjects = [
        "Matemáticas", "Español", "Literatura", "Física", "Química", "Biología", "Historia",
        "Geografía", "Inglés", "Filosofía", "Informática", "Educación Física",
    ]

    private static func latamUniversity(_ code: String) -> [SchoolTrack] {
        [
            track("\(code).medicina", "Medicina", "🩺", .sante, .health,
                  years("\(code).med", ["Ciclo básico", "Ciclo clínico", "Internado"], subjects: [
                      "Anatomía", "Fisiología", "Bioquímica", "Histología", "Farmacología", "Patología",
                  ])),
            track("\(code).licenciatura", code == "mx" ? "Universidad (licenciatura)" : "Universidad (pregrado)", "🎓", .licence, .undergraduate,
                  years("\(code).uni", ["1.er año", "2.º año", "3.er año", "4.º año", "5.º año"])),
            track("\(code).posgrado", "Posgrado", "🔬", .master, .graduate,
                  years("\(code).pos", ["Maestría", "Doctorado"])),
        ]
    }

    private static let mexico: [SchoolTrack] = [
        track("mx.secundaria", "Secundaria", "🎒", .lycee, .lowerSecondary,
              years("mx.sec", ["1.º de secundaria", "2.º de secundaria", "3.º de secundaria"], subjects: [
                  "Matemáticas", "Español", "Ciencias (Biología, Física, Química)", "Historia",
                  "Geografía", "Formación Cívica y Ética", "Inglés", "Tecnología", "Artes",
                  "Educación Física",
              ], lastExams: ["mx.prepa"])),
        track("mx.preparatoria", "Preparatoria (bachillerato)", "🏫", .lycee, .upperSecondary,
              years("mx.prep", ["1.er año de prepa", "2.º año de prepa", "3.er año de prepa"], subjects: latamSubjects, lastExams: ["mx.universidad"])),
    ] + latamUniversity("mx")

    private static let colombia: [SchoolTrack] = [
        track("co.basica", "Básica secundaria", "🎒", .lycee, .lowerSecondary,
              years("co.b", ["Grado 6.º", "Grado 7.º", "Grado 8.º", "Grado 9.º"], subjects: latamSubjects)),
        track("co.media", "Educación media", "🏫", .lycee, .upperSecondary,
              years("co.m", ["Grado 10.º", "Grado 11.º"], subjects: latamSubjects + ["Ciencias Sociales"], lastExams: ["co.saber11"])),
    ] + latamUniversity("co")

    private static let chile: [SchoolTrack] = [
        track("cl.basica", "Enseñanza básica", "🎒", .lycee, .lowerSecondary,
              years("cl.b", ["7.º básico", "8.º básico"], subjects: latamSubjects)),
        track("cl.media", "Enseñanza media", "🏫", .lycee, .upperSecondary,
              years("cl.m", ["1.º medio", "2.º medio", "3.º medio", "4.º medio"], subjects: latamSubjects, lastExams: ["cl.paes"])),
    ] + latamUniversity("cl")

    // MARK: - مصر، السعودية

    private static let egypt: [SchoolTrack] = [
        track("eg.idadi", "المرحلة الإعدادية", "🎒", .lycee, .lowerSecondary,
              years("eg.i", ["الصف الأول الإعدادي", "الصف الثاني الإعدادي", "الصف الثالث الإعدادي"], subjects: arabicSubjects, lastExams: ["eg.idadiya"])),
        track("eg.thanawi", "المرحلة الثانوية", "🏫", .lycee, .upperSecondary,
              years("eg.t", ["الصف الأول الثانوي", "الصف الثاني الثانوي", "الصف الثالث الثانوي"], subjects: arabicSubjects + ["الفلسفة والمنطق", "علم النفس"], lastExams: ["eg.thanawiya"])),
        track("eg.tib", "كلية الطب", "🩺", .sante, .health,
              years("eg.tib", ["السنوات الأساسية", "السنوات الإكلينيكية"], subjects: arabicMedicine)),
        track("eg.jamia", "الجامعة (البكالوريوس)", "🎓", .licence, .undergraduate,
              years("eg.uni", ["الفرقة الأولى", "الفرقة الثانية", "الفرقة الثالثة", "الفرقة الرابعة"])),
        track("eg.majister", "الدراسات العليا", "🔬", .master, .graduate,
              years("eg.grad", ["الماجستير", "الدكتوراه"])),
    ]

    private static let saudiArabia: [SchoolTrack] = [
        track("sa.mutawassit", "المرحلة المتوسطة", "🎒", .lycee, .lowerSecondary,
              years("sa.m", ["الأول المتوسط", "الثاني المتوسط", "الثالث المتوسط"], subjects: arabicSubjects)),
        track("sa.thanawi", "المرحلة الثانوية", "🏫", .lycee, .upperSecondary,
              years("sa.t", ["الأول الثانوي", "الثاني الثانوي", "الثالث الثانوي"], subjects: arabicSubjects + ["علم الأرض والفضاء", "التقنية الرقمية"], lastExams: ["sa.qudurat", "sa.tahsili"])),
        track("sa.tib", "كلية الطب", "🩺", .sante, .health,
              years("sa.tib", ["السنوات الأساسية", "السنوات الإكلينيكية"], subjects: arabicMedicine)),
        track("sa.jamia", "الجامعة (البكالوريوس)", "🎓", .licence, .undergraduate,
              years("sa.uni", ["السنة الأولى", "السنة الثانية", "السنة الثالثة", "السنة الرابعة"])),
        track("sa.ulya", "الدراسات العليا", "🔬", .master, .graduate,
              years("sa.grad", ["الماجستير", "الدكتوراه"])),
    ]

    private static let arabicSubjects = [
        "اللغة العربية", "الرياضيات", "الفيزياء", "الكيمياء", "الأحياء", "التاريخ",
        "الجغرافيا", "اللغة الإنجليزية", "اللغة الفرنسية", "الدراسات الإسلامية", "الحاسب الآلي",
    ]

    private static let arabicMedicine = [
        "التشريح", "علم وظائف الأعضاء", "الكيمياء الحيوية", "علم الأنسجة", "علم الأدوية", "علم الأمراض",
    ]
}
