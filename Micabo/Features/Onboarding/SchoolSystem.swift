import Foundation

/// **Une filière, telle qu'elle se nomme dans son pays.**
///
/// « Lycée » ne suffit pas à savoir ce qu'un élève étudie : un élève de terminale STMG et un
/// élève de terminale générale ne partagent ni leurs matières ni leur épreuve. La filière est
/// donc une question à part entière, posée après le pays et avant l'année, et c'est elle qui
/// décide des années proposées.
///
/// L'identifiant est stable et préfixé par le pays (`fr.lyceeGeneral`) : c'est lui qu'on
/// relit dans les réglages, et il ne doit pas changer quand un libellé est reformulé.
struct SchoolTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    /// Le registre d'écriture envoyé au modèle. Deux filières différentes peuvent le
    /// partager : un lycéen général et un lycéen technologique s'écrivent pareil, ce sont
    /// leurs matières qui diffèrent.
    let level: StudyLevel
    let tier: EducationTier
    /// Les années de cette filière, de la plus basse à la plus haute.
    let years: [SchoolYear]
}

/// Une année dans une filière. Le nom est celui du pays : « Terminale », « 12. Klasse »,
/// « 2º de Bachillerato », « 12. sınıf ».
struct SchoolYear: Identifiable, Hashable {
    let id: String
    let title: String
    /// Les matières de cette année-là. Vide, on retombe sur celles de la filière.
    let subjects: [String]

    init(_ id: String, _ title: String, subjects: [String] = []) {
        self.id = id
        self.title = title
        self.subjects = subjects
    }
}

/// **Le système scolaire d'un pays, filière par filière et année par année.**
///
/// Quatre pays sont décrits en détail — France, Turquie, Allemagne, Espagne — et c'est un
/// choix, pas un état intermédiaire. Décrire un système scolaire de l'extérieur produit des
/// filières qui n'existent pas et des matières que personne n'étudie ; un élève à qui l'on
/// propose une année qui n'existe pas dans son pays comprend immédiatement que l'app n'a pas
/// été écrite pour lui. Partout ailleurs, on retombe sur les paliers larges
/// d'`EducationStage`, qui ne prétendent rien savoir de plus que le niveau.
///
/// **Les matières sont écrites dans la langue du pays.** « Türk Dili ve Edebiyatı » ne se
/// traduit pas par « Littérature turque » pour un élève turc : c'est le nom de sa matière sur
/// son emploi du temps, et c'est sous ce nom qu'il la cherche. Elles ne passent donc pas par
/// le catalogue de traduction, et c'est délibéré.
enum SchoolSystem {
    /// Les filières d'un pays, ou rien quand on ne connaît que ses paliers larges.
    static func tracks(for country: SchoolingCountry) -> [SchoolTrack] {
        switch country {
        case .fr: france
        case .tr: turkey
        case .de: germany
        case .es: spain
        default: []
        }
    }

    /// Vrai quand ce pays est décrit assez finement pour qu'on demande la filière et l'année.
    static func isDetailed(_ country: SchoolingCountry) -> Bool {
        !tracks(for: country).isEmpty
    }

    static func track(id: String?, in country: SchoolingCountry) -> SchoolTrack? {
        guard let id else { return nil }
        return tracks(for: country).first { $0.id == id }
    }

    static func year(id: String?, in track: SchoolTrack?) -> SchoolYear? {
        guard let id, let track else { return nil }
        return track.years.first { $0.id == id }
    }

    // MARK: - France

    private static let frLanguages = ["Anglais", "Espagnol", "Allemand", "Italien"]

    private static let france: [SchoolTrack] = [
        SchoolTrack(
            id: "fr.college",
            title: "Collège",
            emoji: "🎒",
            level: .lycee,
            tier: .lowerSecondary,
            years: [
                SchoolYear("fr.6e", "Sixième", subjects: [
                    "Français", "Mathématiques", "Histoire-Géographie", "SVT",
                    "Physique-Chimie", "Technologie", "Anglais", "EMC", "Arts plastiques",
                    "Éducation musicale", "EPS"
                ]),
                SchoolYear("fr.5e", "Cinquième", subjects: frCollege),
                SchoolYear("fr.4e", "Quatrième", subjects: frCollege),
                SchoolYear("fr.3e", "Troisième", subjects: frCollege + ["Brevet"])
            ]
        ),
        SchoolTrack(
            id: "fr.lyceeGeneral",
            title: "Lycée général",
            emoji: "🏫",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("fr.seconde", "Seconde", subjects: [
                    "Français", "Mathématiques", "Histoire-Géographie", "SVT",
                    "Physique-Chimie", "SES", "SNT", "Anglais", "Espagnol", "Allemand",
                    "EMC", "EPS"
                ]),
                SchoolYear("fr.premiere", "Première", subjects: [
                    "Français", "Histoire-Géographie", "Enseignement scientifique",
                    "Mathématiques", "Physique-Chimie", "SVT", "SES", "HGGSP", "HLP",
                    "LLCER", "NSI", "Sciences de l'ingénieur", "Arts", "Anglais",
                    "Espagnol", "Allemand", "EMC", "EPS"
                ]),
                SchoolYear("fr.terminale", "Terminale", subjects: [
                    "Philosophie", "Histoire-Géographie", "Enseignement scientifique",
                    "Mathématiques", "Maths complémentaires", "Maths expertes",
                    "Physique-Chimie", "SVT", "SES", "HGGSP", "HLP", "LLCER", "NSI",
                    "Sciences de l'ingénieur", "Arts", "Anglais", "Espagnol", "Allemand",
                    "Grand oral", "EMC", "EPS"
                ])
            ]
        ),
        SchoolTrack(
            id: "fr.lyceeTechno",
            title: "Lycée technologique",
            emoji: "⚙️",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("fr.technoSeconde", "Seconde", subjects: frTechno),
                SchoolYear("fr.technoPremiere", "Première", subjects: frTechno),
                SchoolYear("fr.technoTerminale", "Terminale", subjects: frTechno + ["Grand oral"])
            ]
        ),
        SchoolTrack(
            id: "fr.lyceePro",
            title: "Lycée professionnel",
            emoji: "🔧",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("fr.proSeconde", "Seconde pro", subjects: frPro),
                SchoolYear("fr.proPremiere", "Première pro", subjects: frPro),
                SchoolYear("fr.proTerminale", "Terminale pro", subjects: frPro)
            ]
        ),
        SchoolTrack(
            id: "fr.prepa",
            title: "Prépa",
            emoji: "📐",
            level: .prepa,
            tier: .preUniversity,
            years: [
                SchoolYear("fr.prepa1", "Première année", subjects: frPrepa),
                SchoolYear("fr.prepa2", "Deuxième année", subjects: frPrepa)
            ]
        ),
        SchoolTrack(
            id: "fr.sante",
            title: "Études de santé",
            emoji: "🩺",
            level: .sante,
            tier: .health,
            years: [
                SchoolYear("fr.pass", "PASS / L.AS", subjects: frSante),
                SchoolYear("fr.sante2", "Deuxième année", subjects: frSante),
                SchoolYear("fr.sante3", "Troisième année et plus", subjects: frSante)
            ]
        ),
        SchoolTrack(
            id: "fr.universite",
            title: "Université",
            emoji: "🎓",
            level: .licence,
            tier: .undergraduate,
            years: [
                SchoolYear("fr.l1", "Licence 1"),
                SchoolYear("fr.l2", "Licence 2"),
                SchoolYear("fr.l3", "Licence 3"),
                SchoolYear("fr.m1", "Master 1"),
                SchoolYear("fr.m2", "Master 2")
            ]
        )
    ]

    private static let frCollege = [
        "Français", "Mathématiques", "Histoire-Géographie", "SVT", "Physique-Chimie",
        "Technologie", "Anglais", "Espagnol", "Allemand", "EMC", "Arts plastiques",
        "Éducation musicale", "EPS"
    ]

    private static let frTechno = [
        "Français", "Mathématiques", "Histoire-Géographie", "Physique-Chimie",
        "STMG", "STI2D", "ST2S", "STL", "STD2A", "STHR",
        "Management", "Droit", "Économie", "Anglais", "Espagnol", "EMC", "EPS"
    ]

    private static let frPro = [
        "Français", "Mathématiques", "Histoire-Géographie", "Physique-Chimie",
        "Enseignement professionnel", "Économie-gestion", "PSE", "Anglais", "EMC", "EPS"
    ]

    private static let frPrepa = [
        "Mathématiques", "Physique", "Chimie", "SI", "Informatique", "SVT",
        "Français-Philosophie", "Anglais", "Espagnol", "Allemand",
        "Histoire-Géographie", "Économie", "ESH", "Culture générale"
    ]

    private static let frSante = [
        "Anatomie", "Biologie cellulaire", "Biochimie", "Physiologie", "Pharmacologie",
        "Histologie", "Embryologie", "Biophysique", "Santé publique", "Sémiologie"
    ]

    // MARK: - Türkiye

    private static let turkey: [SchoolTrack] = [
        SchoolTrack(
            id: "tr.ortaokul",
            title: "Ortaokul",
            emoji: "🎒",
            level: .lycee,
            tier: .lowerSecondary,
            years: [
                SchoolYear("tr.5", "5. sınıf", subjects: trOrtaokul),
                SchoolYear("tr.6", "6. sınıf", subjects: trOrtaokul),
                SchoolYear("tr.7", "7. sınıf", subjects: trOrtaokul),
                SchoolYear("tr.8", "8. sınıf", subjects: trOrtaokul + ["LGS"])
            ]
        ),
        SchoolTrack(
            id: "tr.anadolu",
            title: "Anadolu Lisesi",
            emoji: "🏫",
            level: .lycee,
            tier: .upperSecondary,
            years: trLiseYears(prefix: "tr.anadolu", subjects: trLise)
        ),
        SchoolTrack(
            id: "tr.fen",
            title: "Fen Lisesi",
            emoji: "🔬",
            level: .lycee,
            tier: .upperSecondary,
            years: trLiseYears(prefix: "tr.fen", subjects: trFen)
        ),
        SchoolTrack(
            id: "tr.meslek",
            title: "Meslek Lisesi",
            emoji: "🔧",
            level: .lycee,
            tier: .upperSecondary,
            years: trLiseYears(prefix: "tr.meslek", subjects: trMeslek)
        ),
        SchoolTrack(
            id: "tr.imamhatip",
            title: "İmam Hatip Lisesi",
            emoji: "🕌",
            level: .lycee,
            tier: .upperSecondary,
            years: trLiseYears(prefix: "tr.imamhatip", subjects: trImamHatip)
        ),
        SchoolTrack(
            id: "tr.yks",
            title: "YKS hazırlık",
            emoji: "🏁",
            level: .concours,
            tier: .competitive,
            years: [
                SchoolYear("tr.tyt", "TYT", subjects: trTYT),
                SchoolYear("tr.ayt", "AYT", subjects: trAYT)
            ]
        ),
        SchoolTrack(
            id: "tr.universite",
            title: "Üniversite",
            emoji: "🎓",
            level: .licence,
            tier: .undergraduate,
            years: [
                SchoolYear("tr.uni1", "1. sınıf"),
                SchoolYear("tr.uni2", "2. sınıf"),
                SchoolYear("tr.uni3", "3. sınıf"),
                SchoolYear("tr.uni4", "4. sınıf"),
                SchoolYear("tr.yukseklisans", "Yüksek lisans")
            ]
        )
    ]

    private static func trLiseYears(prefix: String, subjects: [String]) -> [SchoolYear] {
        [
            SchoolYear("\(prefix).9", "9. sınıf", subjects: subjects),
            SchoolYear("\(prefix).10", "10. sınıf", subjects: subjects),
            SchoolYear("\(prefix).11", "11. sınıf", subjects: subjects),
            SchoolYear("\(prefix).12", "12. sınıf", subjects: subjects + ["YKS"])
        ]
    }

    private static let trOrtaokul = [
        "Matematik", "Türkçe", "Fen Bilimleri", "Sosyal Bilgiler", "İngilizce",
        "Din Kültürü", "Görsel Sanatlar", "Müzik", "Beden Eğitimi"
    ]

    private static let trLise = [
        "Matematik", "Geometri", "Türk Dili ve Edebiyatı", "Fizik", "Kimya", "Biyoloji",
        "Tarih", "Coğrafya", "İngilizce", "Felsefe", "Din Kültürü", "Beden Eğitimi"
    ]

    private static let trFen = [
        "Matematik", "Geometri", "Fizik", "Kimya", "Biyoloji", "Türk Dili ve Edebiyatı",
        "Tarih", "Coğrafya", "İngilizce", "Felsefe", "Bilgisayar Bilimi"
    ]

    private static let trMeslek = [
        "Matematik", "Türk Dili ve Edebiyatı", "Meslek Dersleri", "Fizik", "Kimya",
        "Tarih", "Coğrafya", "İngilizce", "Din Kültürü", "Beden Eğitimi"
    ]

    private static let trImamHatip = [
        "Matematik", "Türk Dili ve Edebiyatı", "Arapça", "Kur'an-ı Kerim",
        "Temel Dini Bilgiler", "Siyer", "Fizik", "Kimya", "Biyoloji", "Tarih",
        "Coğrafya", "İngilizce"
    ]

    private static let trTYT = [
        "TYT Matematik", "TYT Türkçe", "TYT Fen Bilimleri", "TYT Sosyal Bilimler",
        "Geometri"
    ]

    private static let trAYT = [
        "AYT Matematik", "AYT Fizik", "AYT Kimya", "AYT Biyoloji", "AYT Edebiyat",
        "AYT Tarih", "AYT Coğrafya", "AYT Felsefe", "YDT İngilizce"
    ]

    // MARK: - Deutschland

    private static let germany: [SchoolTrack] = [
        SchoolTrack(
            id: "de.mittelstufe",
            title: "Mittelstufe",
            emoji: "🎒",
            level: .lycee,
            tier: .lowerSecondary,
            years: (5...10).map { SchoolYear("de.klasse\($0)", "\($0). Klasse", subjects: deMittelstufe) }
        ),
        SchoolTrack(
            id: "de.gymnasium",
            title: "Gymnasium, Oberstufe",
            emoji: "🏫",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("de.klasse11", "11. Klasse", subjects: deOberstufe),
                SchoolYear("de.klasse12", "12. Klasse", subjects: deOberstufe),
                SchoolYear("de.klasse13", "13. Klasse, Abitur", subjects: deOberstufe + ["Abitur"])
            ]
        ),
        SchoolTrack(
            id: "de.realschule",
            title: "Realschule",
            emoji: "📗",
            level: .lycee,
            tier: .lowerSecondary,
            years: (5...10).map { SchoolYear("de.real\($0)", "\($0). Klasse", subjects: deMittelstufe) }
        ),
        SchoolTrack(
            id: "de.berufsschule",
            title: "Berufsschule",
            emoji: "🔧",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("de.beruf1", "1. Lehrjahr", subjects: deBeruf),
                SchoolYear("de.beruf2", "2. Lehrjahr", subjects: deBeruf),
                SchoolYear("de.beruf3", "3. Lehrjahr", subjects: deBeruf)
            ]
        ),
        SchoolTrack(
            id: "de.medizin",
            title: "Medizin",
            emoji: "🩺",
            level: .sante,
            tier: .health,
            years: [
                SchoolYear("de.vorklinik", "Vorklinik", subjects: deMedizin),
                SchoolYear("de.klinik", "Klinik", subjects: deMedizin),
                SchoolYear("de.pj", "Praktisches Jahr", subjects: deMedizin)
            ]
        ),
        SchoolTrack(
            id: "de.universitaet",
            title: "Universität",
            emoji: "🎓",
            level: .licence,
            tier: .undergraduate,
            years: [
                SchoolYear("de.bachelor1", "Bachelor, 1. Jahr"),
                SchoolYear("de.bachelor2", "Bachelor, 2. Jahr"),
                SchoolYear("de.bachelor3", "Bachelor, 3. Jahr"),
                SchoolYear("de.master", "Master")
            ]
        )
    ]

    private static let deMittelstufe = [
        "Mathematik", "Deutsch", "Englisch", "Biologie", "Chemie", "Physik",
        "Geschichte", "Erdkunde", "Politik", "Französisch", "Latein", "Spanisch",
        "Informatik", "Kunst", "Musik", "Religion", "Ethik", "Sport"
    ]

    private static let deOberstufe = [
        "Mathematik", "Deutsch", "Englisch", "Biologie", "Chemie", "Physik",
        "Geschichte", "Geographie", "Politik und Wirtschaft", "Französisch", "Latein",
        "Spanisch", "Informatik", "Philosophie", "Kunst", "Musik", "Religion", "Sport"
    ]

    private static let deBeruf = [
        "Fachrechnen", "Deutsch", "Englisch", "Wirtschafts- und Sozialkunde",
        "Fachtheorie", "Fachpraxis", "Politik", "Sport"
    ]

    private static let deMedizin = [
        "Anatomie", "Biochemie", "Physiologie", "Histologie", "Pharmakologie",
        "Pathologie", "Mikrobiologie", "Innere Medizin", "Chirurgie"
    ]

    // MARK: - España

    private static let spain: [SchoolTrack] = [
        SchoolTrack(
            id: "es.eso",
            title: "ESO",
            emoji: "🎒",
            level: .lycee,
            tier: .lowerSecondary,
            years: [
                SchoolYear("es.eso1", "1º de ESO", subjects: esESO),
                SchoolYear("es.eso2", "2º de ESO", subjects: esESO),
                SchoolYear("es.eso3", "3º de ESO", subjects: esESO),
                SchoolYear("es.eso4", "4º de ESO", subjects: esESO)
            ]
        ),
        SchoolTrack(
            id: "es.bachCiencias",
            title: "Bachillerato de Ciencias",
            emoji: "🔬",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("es.bachCiencias1", "1º de Bachillerato", subjects: esCiencias),
                SchoolYear("es.bachCiencias2", "2º de Bachillerato", subjects: esCiencias + ["Selectividad"])
            ]
        ),
        SchoolTrack(
            id: "es.bachHumanidades",
            title: "Bachillerato de Humanidades y CCSS",
            emoji: "📚",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("es.bachHum1", "1º de Bachillerato", subjects: esHumanidades),
                SchoolYear("es.bachHum2", "2º de Bachillerato", subjects: esHumanidades + ["Selectividad"])
            ]
        ),
        SchoolTrack(
            id: "es.bachArtes",
            title: "Bachillerato de Artes",
            emoji: "🎨",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("es.bachArtes1", "1º de Bachillerato", subjects: esArtes),
                SchoolYear("es.bachArtes2", "2º de Bachillerato", subjects: esArtes + ["Selectividad"])
            ]
        ),
        SchoolTrack(
            id: "es.fp",
            title: "Formación Profesional",
            emoji: "🔧",
            level: .lycee,
            tier: .upperSecondary,
            years: [
                SchoolYear("es.fpMedio", "Grado medio", subjects: esFP),
                SchoolYear("es.fpSuperior", "Grado superior", subjects: esFP)
            ]
        ),
        SchoolTrack(
            id: "es.medicina",
            title: "Medicina",
            emoji: "🩺",
            level: .sante,
            tier: .health,
            years: [
                SchoolYear("es.medicina1", "Ciclo básico", subjects: esMedicina),
                SchoolYear("es.medicina2", "Ciclo clínico", subjects: esMedicina),
                SchoolYear("es.mir", "MIR", subjects: esMedicina)
            ]
        ),
        SchoolTrack(
            id: "es.universidad",
            title: "Universidad",
            emoji: "🎓",
            level: .licence,
            tier: .undergraduate,
            years: [
                SchoolYear("es.grado1", "1º de grado"),
                SchoolYear("es.grado2", "2º de grado"),
                SchoolYear("es.grado3", "3º de grado"),
                SchoolYear("es.grado4", "4º de grado"),
                SchoolYear("es.master", "Máster")
            ]
        )
    ]

    private static let esESO = [
        "Matemáticas", "Lengua Castellana y Literatura", "Inglés", "Biología y Geología",
        "Física y Química", "Geografía e Historia", "Tecnología", "Educación Plástica",
        "Música", "Educación Física", "Francés", "Valores Éticos"
    ]

    private static let esCiencias = [
        "Matemáticas", "Física", "Química", "Biología", "Geología", "Dibujo Técnico",
        "Lengua Castellana y Literatura", "Inglés", "Filosofía", "Historia de España",
        "Tecnología e Ingeniería", "Educación Física"
    ]

    private static let esHumanidades = [
        "Matemáticas Aplicadas a las CCSS", "Economía", "Historia del Mundo Contemporáneo",
        "Historia de España", "Latín", "Griego", "Literatura Universal",
        "Lengua Castellana y Literatura", "Inglés", "Filosofía", "Geografía",
        "Educación Física"
    ]

    private static let esArtes = [
        "Dibujo Artístico", "Dibujo Técnico", "Fundamentos Artísticos", "Volumen",
        "Historia del Arte", "Lengua Castellana y Literatura", "Inglés", "Filosofía",
        "Historia de España", "Educación Física"
    ]

    private static let esFP = [
        "Módulos Profesionales", "Formación en Centros de Trabajo", "Inglés Técnico",
        "Formación y Orientación Laboral", "Empresa e Iniciativa Emprendedora"
    ]

    private static let esMedicina = [
        "Anatomía", "Bioquímica", "Fisiología", "Histología", "Farmacología",
        "Patología", "Microbiología", "Medicina Interna", "Cirugía"
    ]
}

/// **Les matières à proposer à cet étudiant-là.**
///
/// Trois sources, de la plus précise à la plus large : l'année, la filière, puis le
/// catalogue général. Une seule règle les gouverne, et elle vient de ce que fait un écran de
/// choix : **proposer quelque chose de faux coûte plus cher que de proposer trop large.** Un
/// élève de terminale à qui l'on propose « Technologie » se demande si l'app l'a confondu
/// avec son petit frère ; à qui l'on propose le catalogue entier, il cherche un peu.
enum SchoolSubjects {
    /// Les matières du niveau de l'étudiant, ou le catalogue général à défaut.
    static func suggested(
        stage: EducationStage?,
        country: SchoolingCountry,
        trackID: String? = OnboardingPreferences.schoolTrackID,
        yearID: String? = OnboardingPreferences.schoolYearID
    ) -> [String] {
        if let precise = forYear(trackID: trackID, yearID: yearID, country: country) {
            return precise
        }
        // Pas de filière connue mais un palier large : on prend la première filière du pays
        // qui tombe sur le même palier. C'est plus juste que le catalogue entier, et ça ne
        // prétend rien de plus que ce que le palier disait déjà.
        if let tier = stage?.tier,
           let track = SchoolSystem.tracks(for: country).first(where: { $0.tier == tier }),
           let subjects = track.years.first?.subjects.nilIfEmpty {
            return subjects
        }
        return SubjectCatalog.allSubjects
    }

    /// Les matières d'une année précise, quand la filière et l'année sont connues.
    static func forYear(
        trackID: String?,
        yearID: String?,
        country: SchoolingCountry
    ) -> [String]? {
        guard let track = SchoolSystem.track(id: trackID, in: country) else { return nil }
        if let year = SchoolSystem.year(id: yearID, in: track), let subjects = year.subjects.nilIfEmpty {
            return subjects
        }
        // Une filière universitaire n'a pas de matières fixes : une licence de droit et une
        // licence de physique ne partagent rien. On rend le catalogue plutôt qu'une liste
        // inventée.
        return track.years.compactMap { $0.subjects.nilIfEmpty }.first
    }
}

extension Array {
    /// `nil` plutôt qu'un tableau vide, pour enchaîner les replis sans tester la longueur à
    /// chaque étape.
    var nilIfEmpty: [Element]? {
        isEmpty ? nil : self
    }
}
