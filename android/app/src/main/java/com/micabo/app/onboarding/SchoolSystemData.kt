package com.micabo.app.onboarding

// Engendré par android/tools/generate_school_systems.py depuis SchoolSystem.swift et
// SchoolSystemWorld.swift. Ne pas éditer à la main : relancer le script.

@Suppress("LargeClass")
internal object SchoolSystemData {
    /** Les filières d'un pays décrit, par son code ISO en capitales. */
    fun tracks(code: String, germanSwiss: Boolean): List<SchoolTrack> = when (code) {
        "FR" -> france
        "TR" -> turkey
        "DE" -> germany
        "ES" -> spain
        "GB" -> unitedKingdom
        "US" -> unitedStates
        "IT" -> italy
        "PT" -> portugal
        "BR" -> brazil
        "NL" -> netherlands
        "GR" -> greece
        "HU" -> hungary
        "PL" -> poland
        "CZ" -> czechia
        "SK" -> slovakia
        "RO" -> romania
        "SE" -> sweden
        "DK" -> denmark
        "FI" -> finland
        "EE" -> estonia
        "HR" -> croatia
        "SI" -> slovenia
        "RS" -> serbia
        "BG" -> bulgaria
        "RU" -> russia
        "AT" -> austria
        "BE" -> belgium
        "CA" -> canada
        "LU" -> luxembourg
        "MA" -> morocco
        "DZ" -> algeria
        "TN" -> tunisia
        "SN" -> senegal
        "CI" -> ivoryCoast
        "MX" -> mexico
        "CO" -> colombia
        "CL" -> chile
        "EG" -> egypt
        "SA" -> saudiArabia
        "CH" -> switzerland(germanSwiss)
        else -> emptyList()
    }

    val describedRegions: List<String> = listOf("FR", "TR", "DE", "ES", "GB", "US", "IT", "PT", "BR", "NL", "GR", "HU", "PL", "CZ", "SK", "RO", "SE", "DK", "FI", "EE", "HR", "SI", "RS", "BG", "RU", "AT", "CH", "BE", "CA", "LU", "MA", "DZ", "TN", "SN", "CI", "MX", "CO", "CL", "EG", "SA")

    private fun trLiseYears(prefix: String, subjects: List<String>): List<SchoolYear> = listOf(
        SchoolYear("$prefix.9", "9. sınıf", subjects = subjects),
        SchoolYear("$prefix.10", "10. sınıf", subjects = subjects),
        SchoolYear("$prefix.11", "11. sınıf", subjects = subjects),
        SchoolYear("$prefix.12", "12. sınıf", subjects = subjects + listOf("YKS"), exams = listOf("tr.yks")),
    )

    /** Une suite d'années aux mêmes matières, la dernière portant l'examen. */
    private fun years(prefix: String, titles: List<String>, subjects: List<String> = emptyList(), lastExams: List<String> = emptyList(), exams: Map<Int, List<String>> = emptyMap()): List<SchoolYear> =
        titles.mapIndexed { index, title ->
            var yearExams = exams[index] ?: emptyList()
            if (index == titles.size - 1) yearExams = lastExams + yearExams
            SchoolYear("$prefix${index + 1}", title, subjects = subjects, exams = yearExams)
        }

    private fun track(id: String, title: String, emoji: String, level: String, tier: String, years: List<SchoolYear>, exams: List<String> = emptyList()): SchoolTrack =
        SchoolTrack(id = id, title = title, emoji = emoji, level = level, tier = tier, years = years, exams = exams)

    private fun switzerland(german: Boolean): List<SchoolTrack> {
            if (german) {
                return listOf(
                    track("ch.sek", "Sekundarstufe I", "🎒", "lycee", "lowerSecondary",
                          years("ch.sek", listOf("1. Sek", "2. Sek", "3. Sek"), subjects = listOf(
                              "Deutsch", "Mathematik", "Französisch", "Englisch", "Natur und Technik",
                              "Räume, Zeiten, Gesellschaften", "Informatik", "Bildnerisches Gestalten",
                              "Musik", "Sport",
                          ))),
                    track("ch.gym", "Gymnasium, Kantonsschule", "🏫", "lycee", "upperSecondary",
                          years("ch.gym", listOf("1. Jahr", "2. Jahr", "3. Jahr", "4. Jahr"), subjects = listOf(
                              "Deutsch", "Mathematik", "Französisch", "Englisch", "Italienisch",
                              "Latein", "Biologie", "Chemie", "Physik", "Geschichte", "Geografie",
                              "Wirtschaft und Recht", "Informatik",
                          ), lastExams = listOf("ch.matura"))),
                    track("ch.medizin", "Medizin", "🩺", "sante", "health",
                          years("ch.med", listOf("Bachelor", "Master"), subjects = listOf(
                              "Anatomie", "Physiologie", "Biochemie", "Histologie", "Pharmakologie", "Pathologie",
                          ), lastExams = listOf("ch.eidg"))),
                    track("ch.bachelor", "Universität, ETH, FH: Bachelor", "🎓", "licence", "undergraduate",
                          years("ch.bach", listOf("1. Studienjahr", "2. Studienjahr", "3. Studienjahr"))),
                    track("ch.master", "Master", "🔬", "master", "graduate", years("ch.mas", listOf("Master"))),
                )
            }
            return listOf(
                track("ch.sek", "Secondaire I (cycle d'orientation)", "🎒", "lycee", "lowerSecondary",
                      years("ch.sek", listOf("9e", "10e", "11e"), subjects = listOf(
                          "Français", "Mathématiques", "Allemand", "Anglais", "Sciences de la nature",
                          "Histoire", "Géographie", "Informatique", "Arts visuels", "Musique",
                          "Éducation physique",
                      ))),
                track("ch.gym", "Gymnase, collège (maturité)", "🏫", "lycee", "upperSecondary",
                      years("ch.gym", listOf("1re année", "2e année", "3e année", "4e année"), subjects = listOf(
                          "Français", "Mathématiques", "Allemand", "Anglais", "Italien", "Latin",
                          "Biologie", "Chimie", "Physique", "Histoire", "Géographie",
                          "Économie et droit", "Philosophie", "Informatique",
                      ), lastExams = listOf("ch.maturite"))),
                track("ch.medizin", "Médecine", "🩺", "sante", "health",
                      years("ch.med", listOf("Bachelor", "Master"), subjects = listOf(
                          "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Pathologie",
                      ), lastExams = listOf("ch.ef"))),
                track("ch.bachelor", "Université, EPF, HES : bachelor", "🎓", "licence", "undergraduate",
                      years("ch.bach", listOf("1re année", "2e année", "3e année"))),
                track("ch.master", "Master", "🔬", "master", "graduate", years("ch.mas", listOf("Master"))),
            )
        
    }

    private val frLanguages by lazy {
        listOf("Anglais", "Espagnol", "Allemand", "Italien")
    }

    private val france by lazy {
        listOf(
        SchoolTrack(
            id = "fr.college",
            title = "Collège",
            emoji = "🎒",
            level = "lycee",
            tier = "lowerSecondary",
            years = listOf(
                SchoolYear("fr.6e", "Sixième", subjects = listOf(
                    "Français", "Mathématiques", "Histoire-Géographie", "SVT",
                    "Physique-Chimie", "Technologie", "Anglais", "EMC", "Arts plastiques",
                    "Éducation musicale", "EPS"
                )),
                SchoolYear("fr.5e", "Cinquième", subjects = frCollege),
                SchoolYear("fr.4e", "Quatrième", subjects = frCollege),
                SchoolYear("fr.3e", "Troisième", subjects = frCollege + listOf("Brevet"), exams = listOf("fr.brevet"))
            )
        ),
        SchoolTrack(
            id = "fr.lyceeGeneral",
            title = "Lycée général",
            emoji = "🏫",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("fr.seconde", "Seconde", subjects = listOf(
                    "Français", "Mathématiques", "Histoire-Géographie", "SVT",
                    "Physique-Chimie", "SES", "SNT", "Anglais", "Espagnol", "Allemand",
                    "EMC", "EPS"
                )),
                SchoolYear("fr.premiere", "Première", subjects = listOf(
                    "Français", "Histoire-Géographie", "Enseignement scientifique",
                    "Mathématiques", "Physique-Chimie", "SVT", "SES", "HGGSP", "HLP",
                    "LLCER", "NSI", "Sciences de l'ingénieur", "Arts", "Anglais",
                    "Espagnol", "Allemand", "EMC", "EPS"
                ), exams = listOf("fr.bacFrancais")),
                SchoolYear("fr.terminale", "Terminale", subjects = listOf(
                    "Philosophie", "Histoire-Géographie", "Enseignement scientifique",
                    "Mathématiques", "Maths complémentaires", "Maths expertes",
                    "Physique-Chimie", "SVT", "SES", "HGGSP", "HLP", "LLCER", "NSI",
                    "Sciences de l'ingénieur", "Arts", "Anglais", "Espagnol", "Allemand",
                    "Grand oral", "EMC", "EPS"
                ), exams = listOf("fr.bac"))
            )
        ),
        SchoolTrack(
            id = "fr.lyceeTechno",
            title = "Lycée technologique",
            emoji = "⚙️",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("fr.technoSeconde", "Seconde", subjects = frTechno),
                SchoolYear("fr.technoPremiere", "Première", subjects = frTechno, exams = listOf("fr.bacFrancais")),
                SchoolYear("fr.technoTerminale", "Terminale", subjects = frTechno + listOf("Grand oral"), exams = listOf("fr.bac"))
            )
        ),
        SchoolTrack(
            id = "fr.lyceePro",
            title = "Lycée professionnel",
            emoji = "🔧",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("fr.proSeconde", "Seconde pro", subjects = frPro),
                SchoolYear("fr.proPremiere", "Première pro", subjects = frPro),
                SchoolYear("fr.proTerminale", "Terminale pro", subjects = frPro, exams = listOf("fr.bacPro"))
            )
        ),
        SchoolTrack(
            id = "fr.prepa",
            title = "Prépa",
            emoji = "📐",
            level = "prepa",
            tier = "preUniversity",
            years = listOf(
                SchoolYear("fr.prepa1", "Première année", subjects = frPrepa),
                SchoolYear("fr.prepa2", "Deuxième année", subjects = frPrepa)
            ),
            exams = listOf("fr.concours")
        ),
        SchoolTrack(
            id = "fr.sante",
            title = "Études de santé",
            emoji = "🩺",
            level = "sante",
            tier = "health",
            years = listOf(
                SchoolYear("fr.pass", "PASS / L.AS", subjects = frSante),
                SchoolYear("fr.sante2", "Deuxième année", subjects = frSante),
                SchoolYear("fr.sante3", "Troisième année et plus", subjects = frSante)
            )
        ),
        SchoolTrack(
            id = "fr.universite",
            title = "Université",
            emoji = "🎓",
            level = "licence",
            tier = "undergraduate",
            years = listOf(
                SchoolYear("fr.l1", "Licence 1"),
                SchoolYear("fr.l2", "Licence 2"),
                SchoolYear("fr.l3", "Licence 3"),
                SchoolYear("fr.m1", "Master 1"),
                SchoolYear("fr.m2", "Master 2")
            )
        )
    )
    }

    private val frCollege by lazy {
        listOf(
        "Français", "Mathématiques", "Histoire-Géographie", "SVT", "Physique-Chimie",
        "Technologie", "Anglais", "Espagnol", "Allemand", "EMC", "Arts plastiques",
        "Éducation musicale", "EPS"
    )
    }

    private val frTechno by lazy {
        listOf(
        "Français", "Mathématiques", "Histoire-Géographie", "Physique-Chimie",
        "STMG", "STI2D", "ST2S", "STL", "STD2A", "STHR",
        "Management", "Droit", "Économie", "Anglais", "Espagnol", "EMC", "EPS"
    )
    }

    private val frPro by lazy {
        listOf(
        "Français", "Mathématiques", "Histoire-Géographie", "Physique-Chimie",
        "Enseignement professionnel", "Économie-gestion", "PSE", "Anglais", "EMC", "EPS"
    )
    }

    private val frPrepa by lazy {
        listOf(
        "Mathématiques", "Physique", "Chimie", "SI", "Informatique", "SVT",
        "Français-Philosophie", "Anglais", "Espagnol", "Allemand",
        "Histoire-Géographie", "Économie", "ESH", "Culture générale"
    )
    }

    private val frSante by lazy {
        listOf(
        "Anatomie", "Biologie cellulaire", "Biochimie", "Physiologie", "Pharmacologie",
        "Histologie", "Embryologie", "Biophysique", "Santé publique", "Sémiologie"
    )
    }

    private val turkey by lazy {
        listOf(
        SchoolTrack(
            id = "tr.ortaokul",
            title = "Ortaokul",
            emoji = "🎒",
            level = "lycee",
            tier = "lowerSecondary",
            years = listOf(
                SchoolYear("tr.5", "5. sınıf", subjects = trOrtaokul),
                SchoolYear("tr.6", "6. sınıf", subjects = trOrtaokul),
                SchoolYear("tr.7", "7. sınıf", subjects = trOrtaokul),
                SchoolYear("tr.8", "8. sınıf", subjects = trOrtaokul + listOf("LGS"), exams = listOf("tr.lgs"))
            )
        ),
        SchoolTrack(
            id = "tr.anadolu",
            title = "Anadolu Lisesi",
            emoji = "🏫",
            level = "lycee",
            tier = "upperSecondary",
            years = trLiseYears(prefix = "tr.anadolu", subjects = trLise)
        ),
        SchoolTrack(
            id = "tr.fen",
            title = "Fen Lisesi",
            emoji = "🔬",
            level = "lycee",
            tier = "upperSecondary",
            years = trLiseYears(prefix = "tr.fen", subjects = trFen)
        ),
        SchoolTrack(
            id = "tr.meslek",
            title = "Meslek Lisesi",
            emoji = "🔧",
            level = "lycee",
            tier = "upperSecondary",
            years = trLiseYears(prefix = "tr.meslek", subjects = trMeslek)
        ),
        SchoolTrack(
            id = "tr.imamhatip",
            title = "İmam Hatip Lisesi",
            emoji = "🕌",
            level = "lycee",
            tier = "upperSecondary",
            years = trLiseYears(prefix = "tr.imamhatip", subjects = trImamHatip)
        ),
        SchoolTrack(
            id = "tr.yks",
            title = "YKS hazırlık",
            emoji = "🏁",
            level = "concours",
            tier = "competitive",
            years = listOf(
                SchoolYear("tr.tyt", "TYT", subjects = trTYT),
                SchoolYear("tr.ayt", "AYT", subjects = trAYT)
            ),
            exams = listOf("tr.yks")
        ),
        SchoolTrack(
            id = "tr.universite",
            title = "Üniversite",
            emoji = "🎓",
            level = "licence",
            tier = "undergraduate",
            years = listOf(
                SchoolYear("tr.uni1", "1. sınıf"),
                SchoolYear("tr.uni2", "2. sınıf"),
                SchoolYear("tr.uni3", "3. sınıf"),
                SchoolYear("tr.uni4", "4. sınıf"),
                SchoolYear("tr.yukseklisans", "Yüksek lisans")
            )
        )
    )
    }

    private val trOrtaokul by lazy {
        listOf(
        "Matematik", "Türkçe", "Fen Bilimleri", "Sosyal Bilgiler", "İngilizce",
        "Din Kültürü", "Görsel Sanatlar", "Müzik", "Beden Eğitimi"
    )
    }

    private val trLise by lazy {
        listOf(
        "Matematik", "Geometri", "Türk Dili ve Edebiyatı", "Fizik", "Kimya", "Biyoloji",
        "Tarih", "Coğrafya", "İngilizce", "Felsefe", "Din Kültürü", "Beden Eğitimi"
    )
    }

    private val trFen by lazy {
        listOf(
        "Matematik", "Geometri", "Fizik", "Kimya", "Biyoloji", "Türk Dili ve Edebiyatı",
        "Tarih", "Coğrafya", "İngilizce", "Felsefe", "Bilgisayar Bilimi"
    )
    }

    private val trMeslek by lazy {
        listOf(
        "Matematik", "Türk Dili ve Edebiyatı", "Meslek Dersleri", "Fizik", "Kimya",
        "Tarih", "Coğrafya", "İngilizce", "Din Kültürü", "Beden Eğitimi"
    )
    }

    private val trImamHatip by lazy {
        listOf(
        "Matematik", "Türk Dili ve Edebiyatı", "Arapça", "Kur'an-ı Kerim",
        "Temel Dini Bilgiler", "Siyer", "Fizik", "Kimya", "Biyoloji", "Tarih",
        "Coğrafya", "İngilizce"
    )
    }

    private val trTYT by lazy {
        listOf(
        "TYT Matematik", "TYT Türkçe", "TYT Fen Bilimleri", "TYT Sosyal Bilimler",
        "Geometri"
    )
    }

    private val trAYT by lazy {
        listOf(
        "AYT Matematik", "AYT Fizik", "AYT Kimya", "AYT Biyoloji", "AYT Edebiyat",
        "AYT Tarih", "AYT Coğrafya", "AYT Felsefe", "YDT İngilizce"
    )
    }

    private val germany by lazy {
        listOf(
        SchoolTrack(
            id = "de.mittelstufe",
            title = "Mittelstufe",
            emoji = "🎒",
            level = "lycee",
            tier = "lowerSecondary",
            years = (5..10).map { SchoolYear("de.klasse${it}", "${it}. Klasse", subjects = deMittelstufe) }
        ),
        SchoolTrack(
            id = "de.gymnasium",
            title = "Gymnasium, Oberstufe",
            emoji = "🏫",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("de.klasse11", "11. Klasse", subjects = deOberstufe),
                SchoolYear("de.klasse12", "12. Klasse", subjects = deOberstufe, exams = listOf("de.abitur")),
                SchoolYear("de.klasse13", "13. Klasse, Abitur", subjects = deOberstufe + listOf("Abitur"), exams = listOf("de.abitur"))
            )
        ),
        SchoolTrack(
            id = "de.realschule",
            title = "Realschule",
            emoji = "📗",
            level = "lycee",
            tier = "lowerSecondary",
            years = (5..10).map { SchoolYear("de.real${it}", "${it}. Klasse", subjects = deMittelstufe, exams = if (it == 10) listOf("de.msa") else listOf()) }
        ),
        SchoolTrack(
            id = "de.berufsschule",
            title = "Berufsschule",
            emoji = "🔧",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("de.beruf1", "1. Lehrjahr", subjects = deBeruf),
                SchoolYear("de.beruf2", "2. Lehrjahr", subjects = deBeruf),
                SchoolYear("de.beruf3", "3. Lehrjahr", subjects = deBeruf)
            )
        ),
        SchoolTrack(
            id = "de.medizin",
            title = "Medizin",
            emoji = "🩺",
            level = "sante",
            tier = "health",
            years = listOf(
                SchoolYear("de.vorklinik", "Vorklinik", subjects = deMedizin, exams = listOf("de.physikum")),
                SchoolYear("de.klinik", "Klinik", subjects = deMedizin, exams = listOf("de.staatsexamen")),
                SchoolYear("de.pj", "Praktisches Jahr", subjects = deMedizin)
            )
        ),
        SchoolTrack(
            id = "de.universitaet",
            title = "Universität",
            emoji = "🎓",
            level = "licence",
            tier = "undergraduate",
            years = listOf(
                SchoolYear("de.bachelor1", "Bachelor, 1. Jahr"),
                SchoolYear("de.bachelor2", "Bachelor, 2. Jahr"),
                SchoolYear("de.bachelor3", "Bachelor, 3. Jahr"),
                SchoolYear("de.master", "Master")
            )
        )
    )
    }

    private val deMittelstufe by lazy {
        listOf(
        "Mathematik", "Deutsch", "Englisch", "Biologie", "Chemie", "Physik",
        "Geschichte", "Erdkunde", "Politik", "Französisch", "Latein", "Spanisch",
        "Informatik", "Kunst", "Musik", "Religion", "Ethik", "Sport"
    )
    }

    private val deOberstufe by lazy {
        listOf(
        "Mathematik", "Deutsch", "Englisch", "Biologie", "Chemie", "Physik",
        "Geschichte", "Geographie", "Politik und Wirtschaft", "Französisch", "Latein",
        "Spanisch", "Informatik", "Philosophie", "Kunst", "Musik", "Religion", "Sport"
    )
    }

    private val deBeruf by lazy {
        listOf(
        "Fachrechnen", "Deutsch", "Englisch", "Wirtschafts- und Sozialkunde",
        "Fachtheorie", "Fachpraxis", "Politik", "Sport"
    )
    }

    private val deMedizin by lazy {
        listOf(
        "Anatomie", "Biochemie", "Physiologie", "Histologie", "Pharmakologie",
        "Pathologie", "Mikrobiologie", "Innere Medizin", "Chirurgie"
    )
    }

    private val spain by lazy {
        listOf(
        SchoolTrack(
            id = "es.eso",
            title = "ESO",
            emoji = "🎒",
            level = "lycee",
            tier = "lowerSecondary",
            years = listOf(
                SchoolYear("es.eso1", "1º de ESO", subjects = esESO),
                SchoolYear("es.eso2", "2º de ESO", subjects = esESO),
                SchoolYear("es.eso3", "3º de ESO", subjects = esESO),
                SchoolYear("es.eso4", "4º de ESO", subjects = esESO)
            )
        ),
        SchoolTrack(
            id = "es.bachCiencias",
            title = "Bachillerato de Ciencias",
            emoji = "🔬",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("es.bachCiencias1", "1º de Bachillerato", subjects = esCiencias),
                SchoolYear("es.bachCiencias2", "2º de Bachillerato", subjects = esCiencias + listOf("Selectividad"), exams = listOf("es.pau"))
            )
        ),
        SchoolTrack(
            id = "es.bachHumanidades",
            title = "Bachillerato de Humanidades y CCSS",
            emoji = "📚",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("es.bachHum1", "1º de Bachillerato", subjects = esHumanidades),
                SchoolYear("es.bachHum2", "2º de Bachillerato", subjects = esHumanidades + listOf("Selectividad"), exams = listOf("es.pau"))
            )
        ),
        SchoolTrack(
            id = "es.bachArtes",
            title = "Bachillerato de Artes",
            emoji = "🎨",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("es.bachArtes1", "1º de Bachillerato", subjects = esArtes),
                SchoolYear("es.bachArtes2", "2º de Bachillerato", subjects = esArtes + listOf("Selectividad"), exams = listOf("es.pau"))
            )
        ),
        SchoolTrack(
            id = "es.fp",
            title = "Formación Profesional",
            emoji = "🔧",
            level = "lycee",
            tier = "upperSecondary",
            years = listOf(
                SchoolYear("es.fpMedio", "Grado medio", subjects = esFP),
                SchoolYear("es.fpSuperior", "Grado superior", subjects = esFP)
            )
        ),
        SchoolTrack(
            id = "es.medicina",
            title = "Medicina",
            emoji = "🩺",
            level = "sante",
            tier = "health",
            years = listOf(
                SchoolYear("es.medicina1", "Ciclo básico", subjects = esMedicina),
                SchoolYear("es.medicina2", "Ciclo clínico", subjects = esMedicina),
                SchoolYear("es.mir", "MIR", subjects = esMedicina, exams = listOf("es.mir"))
            )
        ),
        SchoolTrack(
            id = "es.universidad",
            title = "Universidad",
            emoji = "🎓",
            level = "licence",
            tier = "undergraduate",
            years = listOf(
                SchoolYear("es.grado1", "1º de grado"),
                SchoolYear("es.grado2", "2º de grado"),
                SchoolYear("es.grado3", "3º de grado"),
                SchoolYear("es.grado4", "4º de grado"),
                SchoolYear("es.master", "Máster")
            )
        )
    )
    }

    private val esESO by lazy {
        listOf(
        "Matemáticas", "Lengua Castellana y Literatura", "Inglés", "Biología y Geología",
        "Física y Química", "Geografía e Historia", "Tecnología", "Educación Plástica",
        "Música", "Educación Física", "Francés", "Valores Éticos"
    )
    }

    private val esCiencias by lazy {
        listOf(
        "Matemáticas", "Física", "Química", "Biología", "Geología", "Dibujo Técnico",
        "Lengua Castellana y Literatura", "Inglés", "Filosofía", "Historia de España",
        "Tecnología e Ingeniería", "Educación Física"
    )
    }

    private val esHumanidades by lazy {
        listOf(
        "Matemáticas Aplicadas a las CCSS", "Economía", "Historia del Mundo Contemporáneo",
        "Historia de España", "Latín", "Griego", "Literatura Universal",
        "Lengua Castellana y Literatura", "Inglés", "Filosofía", "Geografía",
        "Educación Física"
    )
    }

    private val esArtes by lazy {
        listOf(
        "Dibujo Artístico", "Dibujo Técnico", "Fundamentos Artísticos", "Volumen",
        "Historia del Arte", "Lengua Castellana y Literatura", "Inglés", "Filosofía",
        "Historia de España", "Educación Física"
    )
    }

    private val esFP by lazy {
        listOf(
        "Módulos Profesionales", "Formación en Centros de Trabajo", "Inglés Técnico",
        "Formación y Orientación Laboral", "Empresa e Iniciativa Emprendedora"
    )
    }

    private val esMedicina by lazy {
        listOf(
        "Anatomía", "Bioquímica", "Fisiología", "Histología", "Farmacología",
        "Patología", "Microbiología", "Medicina Interna", "Cirugía"
    )
    }

    private val unitedKingdom by lazy {
        listOf(
        track("uk.ks3", "Secondary school (Years 7–9)", "🎒", "lycee", "lowerSecondary",
              years("uk.y", listOf("Year 7", "Year 8", "Year 9"), subjects = listOf(
                  "English", "Maths", "Science", "History", "Geography", "French", "Spanish",
                  "Computing", "Art", "Music", "PE", "RE",
              ))),
        track("uk.gcse", "GCSEs (Years 10–11)", "📗", "lycee", "lowerSecondary",
              listOf(
                  SchoolYear("uk.y10", "Year 10", subjects = ukGCSE),
                  SchoolYear("uk.y11", "Year 11", subjects = ukGCSE, exams = listOf("uk.gcse")),
              )),
        track("uk.alevels", "Sixth form, A-levels", "🏫", "lycee", "upperSecondary",
              listOf(
                  SchoolYear("uk.y12", "Year 12", subjects = ukALevel),
                  SchoolYear("uk.y13", "Year 13", subjects = ukALevel, exams = listOf("uk.alevels")),
              )),
        track("uk.medicine", "Medicine", "🩺", "sante", "health",
              years("uk.med", listOf("Pre-clinical years", "Clinical years"), subjects = medicineEN)),
        track("uk.university", "University", "🎓", "licence", "undergraduate",
              years("uk.uni", listOf("First year", "Second year", "Final year"))),
        track("uk.postgraduate", "Postgraduate", "🔬", "master", "graduate",
              years("uk.pg", listOf("Master's", "PhD"))),
    )
    }

    private val ukGCSE by lazy {
        listOf(
        "English Language", "English Literature", "Maths", "Combined Science", "Biology",
        "Chemistry", "Physics", "History", "Geography", "French", "Spanish",
        "Computer Science", "Religious Studies", "Business",
    )
    }

    private val ukALevel by lazy {
        listOf(
        "Maths", "Further Maths", "Biology", "Chemistry", "Physics", "English Literature",
        "History", "Geography", "Psychology", "Economics", "Sociology", "Politics",
        "Computer Science", "French", "Spanish", "Business",
    )
    }

    private val medicineEN by lazy {
        listOf(
        "Anatomy", "Physiology", "Biochemistry", "Pharmacology", "Pathology", "Microbiology",
    )
    }

    private val unitedStates by lazy {
        listOf(
        track("us.middle", "Middle school", "🎒", "lycee", "lowerSecondary",
              years("us.g", listOf("6th grade", "7th grade", "8th grade"), subjects = listOf(
                  "Math", "English Language Arts", "Science", "Social Studies", "Spanish",
                  "French", "Computer Science", "Art", "Music", "PE",
              ))),
        track("us.high", "High school", "🏫", "lycee", "upperSecondary",
              listOf(
                  SchoolYear("us.hs9", "9th grade (Freshman)", subjects = usHigh),
                  SchoolYear("us.hs10", "10th grade (Sophomore)", subjects = usHigh, exams = listOf("us.psat", "us.ap")),
                  SchoolYear("us.hs11", "11th grade (Junior)", subjects = usHigh, exams = listOf("us.sat", "us.act", "us.ap", "us.psat")),
                  SchoolYear("us.hs12", "12th grade (Senior)", subjects = usHigh, exams = listOf("us.sat", "us.act", "us.ap")),
              )),
        track("us.college", "College", "🎓", "licence", "undergraduate",
              years("us.col", listOf("Freshman year", "Sophomore year", "Junior year", "Senior year"), lastExams = listOf("us.gre"))),
        track("us.premed", "Pre-med, medical school", "🩺", "sante", "health",
              listOf(
                  SchoolYear("us.premed1", "Pre-med", subjects = medicineEN, exams = listOf("us.mcat")),
                  SchoolYear("us.medschool", "Medical school", subjects = medicineEN, exams = listOf("us.usmle")),
              )),
        track("us.graduate", "Graduate school", "🔬", "master", "graduate",
              years("us.grad", listOf("Master's", "PhD"))),
    )
    }

    private val usHigh by lazy {
        listOf(
        "Algebra", "Geometry", "Precalculus", "Calculus", "Biology", "Chemistry", "Physics",
        "English", "US History", "World History", "Government", "Economics", "Spanish",
        "French", "Computer Science", "Psychology",
    )
    }

    private val italy by lazy {
        listOf(
        track("it.media", "Scuola media", "🎒", "lycee", "lowerSecondary",
              years("it.media", listOf("Prima media", "Seconda media", "Terza media"), subjects = listOf(
                  "Italiano", "Matematica", "Scienze", "Storia", "Geografia", "Inglese",
                  "Francese", "Spagnolo", "Tecnologia", "Arte e immagine", "Musica",
                  "Educazione fisica",
              ), lastExams = listOf("it.terzaMedia", "it.invalsi"))),
        track("it.liceo", "Liceo", "🏫", "lycee", "upperSecondary",
              years("it.liceo", listOf("Primo anno", "Secondo anno", "Terzo anno", "Quarto anno", "Quinto anno"), subjects = listOf(
                  "Italiano", "Matematica", "Fisica", "Scienze naturali", "Storia", "Filosofia",
                  "Inglese", "Latino", "Greco", "Storia dell'arte", "Informatica",
                  "Scienze motorie",
              ), lastExams = listOf("it.maturita"))),
        track("it.tecnico", "Istituto tecnico o professionale", "⚙️", "lycee", "upperSecondary",
              years("it.tecnico", listOf("Primo anno", "Secondo anno", "Terzo anno", "Quarto anno", "Quinto anno"), subjects = listOf(
                  "Italiano", "Matematica", "Inglese", "Storia", "Economia aziendale",
                  "Diritto ed economia", "Informatica", "Fisica", "Chimica", "Materie di indirizzo",
              ), lastExams = listOf("it.maturita"))),
        track("it.medicina", "Medicina e chirurgia", "🩺", "sante", "health",
              years("it.med", listOf("Primo triennio", "Secondo triennio"), subjects = listOf(
                  "Anatomia", "Fisiologia", "Biochimica", "Istologia", "Farmacologia", "Patologia",
              ))),
        track("it.triennale", "Università, laurea triennale", "🎓", "licence", "undergraduate",
              years("it.uni", listOf("Primo anno", "Secondo anno", "Terzo anno"))),
        track("it.magistrale", "Laurea magistrale", "🔬", "master", "graduate",
              years("it.mag", listOf("Primo anno", "Secondo anno"))),
    )
    }

    private val portugal by lazy {
        listOf(
        track("pt.ciclo3", "3.º ciclo", "🎒", "lycee", "lowerSecondary",
              years("pt.b", listOf("7.º ano", "8.º ano", "9.º ano"), subjects = listOf(
                  "Português", "Matemática", "Inglês", "Francês", "Ciências Naturais",
                  "Físico-Química", "História", "Geografia", "TIC", "Educação Visual",
                  "Educação Física",
              ), lastExams = listOf("pt.provasFinais"))),
        track("pt.secundario", "Ensino secundário", "🏫", "lycee", "upperSecondary",
              years("pt.s", listOf("10.º ano", "11.º ano", "12.º ano"), subjects = listOf(
                  "Português", "Matemática A", "Física e Química A", "Biologia e Geologia",
                  "História A", "Geografia A", "Economia A", "Geometria Descritiva A",
                  "Filosofia", "Inglês", "Educação Física",
              ), lastExams = listOf("pt.exames"), exams = mapOf(1 to listOf("pt.exames")))),
        track("pt.medicina", "Medicina", "🩺", "sante", "health",
              years("pt.med", listOf("Ciclo básico", "Ciclo clínico"), subjects = listOf(
                  "Anatomia", "Fisiologia", "Bioquímica", "Histologia", "Farmacologia", "Patologia",
              ))),
        track("pt.licenciatura", "Licenciatura", "🎓", "licence", "undergraduate",
              years("pt.lic", listOf("1.º ano", "2.º ano", "3.º ano"))),
        track("pt.mestrado", "Mestrado", "🔬", "master", "graduate",
              years("pt.mes", listOf("1.º ano", "2.º ano"))),
    )
    }

    private val brazil by lazy {
        listOf(
        track("br.fundamental", "Ensino fundamental (anos finais)", "🎒", "lycee", "lowerSecondary",
              years("br.f", listOf("6º ano", "7º ano", "8º ano", "9º ano"), subjects = listOf(
                  "Matemática", "Português", "Ciências", "História", "Geografia", "Inglês",
                  "Arte", "Educação Física",
              ))),
        track("br.medio", "Ensino médio", "🏫", "lycee", "upperSecondary",
              years("br.m", listOf("1º ano", "2º ano", "3º ano"), subjects = listOf(
                  "Matemática", "Português", "Literatura", "Redação", "Física", "Química",
                  "Biologia", "História", "Geografia", "Inglês", "Espanhol", "Filosofia",
                  "Sociologia", "Educação Física",
              ), lastExams = listOf("br.enem", "br.vestibular"), exams = mapOf(1 to listOf("br.enem")))),
        track("br.medicina", "Medicina", "🩺", "sante", "health",
              years("br.med", listOf("Ciclo básico", "Ciclo clínico", "Internato"), subjects = listOf(
                  "Anatomia", "Fisiologia", "Bioquímica", "Histologia", "Farmacologia", "Patologia",
              ))),
        track("br.faculdade", "Faculdade", "🎓", "licence", "undergraduate",
              years("br.fac", listOf("1º ano", "2º ano", "3º ano", "4º ano", "5º ano"))),
        track("br.posgraduacao", "Pós-graduação", "🔬", "master", "graduate",
              years("br.pos", listOf("Mestrado", "Doutorado"))),
    )
    }

    private val netherlands by lazy {
        listOf(
        track("nl.onderbouw", "Onderbouw", "🎒", "lycee", "lowerSecondary",
              years("nl.o", listOf("Klas 1", "Klas 2", "Klas 3"), subjects = nlSubjects)),
        track("nl.vmbo", "Vmbo", "📗", "lycee", "lowerSecondary",
              years("nl.vmbo", listOf("Vmbo 3", "Vmbo 4"), subjects = nlSubjects, lastExams = listOf("nl.eindexamen"))),
        track("nl.havo", "Havo", "🏫", "lycee", "upperSecondary",
              years("nl.havo", listOf("Havo 4", "Havo 5"), subjects = nlSubjects, lastExams = listOf("nl.eindexamen"))),
        track("nl.vwo", "Vwo", "📐", "lycee", "upperSecondary",
              years("nl.vwo", listOf("Vwo 4", "Vwo 5", "Vwo 6"), subjects = nlSubjects + listOf("Latijn", "Grieks"), lastExams = listOf("nl.eindexamen"))),
        track("nl.hbo", "Hbo of universiteit (bachelor)", "🎓", "licence", "undergraduate",
              years("nl.bach", listOf("Jaar 1", "Jaar 2", "Jaar 3", "Jaar 4"))),
        track("nl.master", "Master", "🔬", "master", "graduate",
              years("nl.mas", listOf("Master"))),
    )
    }

    private val nlSubjects by lazy {
        listOf(
        "Nederlands", "Engels", "Wiskunde A", "Wiskunde B", "Natuurkunde", "Scheikunde",
        "Biologie", "Economie", "Geschiedenis", "Aardrijkskunde", "Frans", "Duits",
        "Maatschappijleer", "Lichamelijke opvoeding",
    )
    }

    private val greece by lazy {
        listOf(
        track("gr.gymnasio", "Γυμνάσιο", "🎒", "lycee", "lowerSecondary",
              years("gr.g", listOf("Α΄ Γυμνασίου", "Β΄ Γυμνασίου", "Γ΄ Γυμνασίου"), subjects = grSubjects)),
        track("gr.lykeio", "Γενικό Λύκειο", "🏫", "lycee", "upperSecondary",
              years("gr.l", listOf("Α΄ Λυκείου", "Β΄ Λυκείου", "Γ΄ Λυκείου"), subjects = grSubjects + listOf("Λατινικά", "Οικονομία"), lastExams = listOf("gr.panelladikes"))),
        track("gr.iatriki", "Ιατρική", "🩺", "sante", "health",
              years("gr.iat", listOf("Προκλινικά έτη", "Κλινικά έτη"), subjects = listOf(
                  "Ανατομία", "Φυσιολογία", "Βιοχημεία", "Ιστολογία", "Φαρμακολογία", "Παθολογία",
              ))),
        track("gr.panepistimio", "Πανεπιστήμιο", "🎓", "licence", "undergraduate",
              years("gr.uni", listOf("1ο έτος", "2ο έτος", "3ο έτος", "4ο έτος"))),
        track("gr.metaptychiako", "Μεταπτυχιακό", "🔬", "master", "graduate",
              years("gr.msc", listOf("Μεταπτυχιακό"))),
    )
    }

    private val grSubjects by lazy {
        listOf(
        "Νεοελληνική Γλώσσα", "Λογοτεχνία", "Μαθηματικά", "Φυσική", "Χημεία", "Βιολογία",
        "Ιστορία", "Αρχαία Ελληνικά", "Αγγλικά", "Πληροφορική", "Φυσική Αγωγή",
    )
    }

    private val hungary by lazy {
        listOf(
        track("hu.altalanos", "Általános iskola (felső tagozat)", "🎒", "lycee", "lowerSecondary",
              years("hu.a", listOf("5. osztály", "6. osztály", "7. osztály", "8. osztály"), subjects = huSubjects, lastExams = listOf("hu.felveteli"))),
        track("hu.gimnazium", "Gimnázium", "🏫", "lycee", "upperSecondary",
              years("hu.g", listOf("9. osztály", "10. osztály", "11. osztály", "12. osztály"), subjects = huSubjects, lastExams = listOf("hu.erettsegi"))),
        track("hu.technikum", "Technikum", "⚙️", "lycee", "upperSecondary",
              years("hu.t", listOf("9. évfolyam", "10. évfolyam", "11. évfolyam", "12. évfolyam", "13. évfolyam"), subjects = huSubjects + listOf("Szakmai tárgyak"), lastExams = listOf("hu.erettsegi"))),
        track("hu.orvosi", "Orvosképzés", "🩺", "sante", "health",
              years("hu.orv", listOf("Preklinikum", "Klinikum"), subjects = listOf(
                  "Anatómia", "Élettan", "Biokémia", "Szövettan", "Farmakológia", "Patológia",
              ))),
        track("hu.egyetem", "Egyetem (alapképzés)", "🎓", "licence", "undergraduate",
              years("hu.bsc", listOf("1. év", "2. év", "3. év"))),
        track("hu.mester", "Mesterképzés", "🔬", "master", "graduate",
              years("hu.msc", listOf("Mesterképzés"))),
    )
    }

    private val huSubjects by lazy {
        listOf(
        "Magyar nyelv és irodalom", "Matematika", "Történelem", "Angol", "Német", "Fizika",
        "Kémia", "Biológia", "Földrajz", "Informatika", "Testnevelés",
    )
    }

    private val poland by lazy {
        listOf(
        track("pl.podstawowa", "Szkoła podstawowa (klasy 7–8)", "🎒", "lycee", "lowerSecondary",
              years("pl.sp", listOf("Klasa 7", "Klasa 8"), subjects = plSubjects, lastExams = listOf("pl.osmoklasisty"))),
        track("pl.liceum", "Liceum", "🏫", "lycee", "upperSecondary",
              years("pl.lo", listOf("Klasa 1", "Klasa 2", "Klasa 3", "Klasa 4"), subjects = plSubjects + listOf("WOS", "Filozofia"), lastExams = listOf("pl.matura"))),
        track("pl.technikum", "Technikum", "⚙️", "lycee", "upperSecondary",
              years("pl.tech", listOf("Klasa 1", "Klasa 2", "Klasa 3", "Klasa 4", "Klasa 5"), subjects = plSubjects + listOf("Przedmioty zawodowe"), lastExams = listOf("pl.matura"))),
        track("pl.medycyna", "Medycyna", "🩺", "sante", "health",
              years("pl.med", listOf("Lata przedkliniczne", "Lata kliniczne"), subjects = listOf(
                  "Anatomia", "Fizjologia", "Biochemia", "Histologia", "Farmakologia", "Patologia",
              ))),
        track("pl.licencjat", "Studia licencjackie", "🎓", "licence", "undergraduate",
              years("pl.lic", listOf("1. rok", "2. rok", "3. rok"))),
        track("pl.magister", "Studia magisterskie", "🔬", "master", "graduate",
              years("pl.mgr", listOf("1. rok", "2. rok"))),
    )
    }

    private val plSubjects by lazy {
        listOf(
        "Język polski", "Matematyka", "Język angielski", "Język niemiecki", "Historia",
        "Biologia", "Chemia", "Fizyka", "Geografia", "Informatyka", "Wychowanie fizyczne",
    )
    }

    private val czechia by lazy {
        listOf(
        track("cz.zakladni", "Základní škola (2. stupeň)", "🎒", "lycee", "lowerSecondary",
              years("cz.zs", listOf("6. třída", "7. třída", "8. třída", "9. třída"), subjects = czSubjects, lastExams = listOf("cz.prijimacky"))),
        track("cz.gymnazium", "Gymnázium", "🏫", "lycee", "upperSecondary",
              years("cz.gym", listOf("1. ročník", "2. ročník", "3. ročník", "4. ročník"), subjects = czSubjects + listOf("Základy společenských věd"), lastExams = listOf("cz.maturita"))),
        track("cz.sos", "Střední odborná škola", "⚙️", "lycee", "upperSecondary",
              years("cz.sos", listOf("1. ročník", "2. ročník", "3. ročník", "4. ročník"), subjects = czSubjects + listOf("Odborné předměty"), lastExams = listOf("cz.maturita"))),
        track("cz.medicina", "Medicína", "🩺", "sante", "health",
              years("cz.med", listOf("Preklinika", "Klinika"), subjects = listOf(
                  "Anatomie", "Fyziologie", "Biochemie", "Histologie", "Farmakologie", "Patologie",
              ))),
        track("cz.bakalar", "Bakalářské studium", "🎓", "licence", "undergraduate",
              years("cz.bc", listOf("1. ročník", "2. ročník", "3. ročník"))),
        track("cz.magistr", "Magisterské studium", "🔬", "master", "graduate",
              years("cz.mgr", listOf("1. ročník", "2. ročník"))),
    )
    }

    private val czSubjects by lazy {
        listOf(
        "Český jazyk a literatura", "Matematika", "Anglický jazyk", "Německý jazyk", "Fyzika",
        "Chemie", "Biologie", "Dějepis", "Zeměpis", "Informatika", "Tělesná výchova",
    )
    }

    private val slovakia by lazy {
        listOf(
        track("sk.zakladna", "Základná škola (2. stupeň)", "🎒", "lycee", "lowerSecondary",
              years("sk.zs", listOf("5. ročník", "6. ročník", "7. ročník", "8. ročník", "9. ročník"), subjects = skSubjects, lastExams = listOf("sk.testovanie9"))),
        track("sk.gymnazium", "Gymnázium", "🏫", "lycee", "upperSecondary",
              years("sk.gym", listOf("1. ročník", "2. ročník", "3. ročník", "4. ročník"), subjects = skSubjects + listOf("Občianska náuka"), lastExams = listOf("sk.maturita"))),
        track("sk.sos", "Stredná odborná škola", "⚙️", "lycee", "upperSecondary",
              years("sk.sos", listOf("1. ročník", "2. ročník", "3. ročník", "4. ročník"), subjects = skSubjects + listOf("Odborné predmety"), lastExams = listOf("sk.maturita"))),
        track("sk.medicina", "Medicína", "🩺", "sante", "health",
              years("sk.med", listOf("Predklinika", "Klinika"), subjects = listOf(
                  "Anatómia", "Fyziológia", "Biochémia", "Histológia", "Farmakológia", "Patológia",
              ))),
        track("sk.bakalar", "Bakalárske štúdium", "🎓", "licence", "undergraduate",
              years("sk.bc", listOf("1. ročník", "2. ročník", "3. ročník"))),
        track("sk.magister", "Magisterské štúdium", "🔬", "master", "graduate",
              years("sk.mgr", listOf("1. ročník", "2. ročník"))),
    )
    }

    private val skSubjects by lazy {
        listOf(
        "Slovenský jazyk a literatúra", "Matematika", "Anglický jazyk", "Nemecký jazyk",
        "Fyzika", "Chémia", "Biológia", "Dejepis", "Geografia", "Informatika",
        "Telesná a športová výchova",
    )
    }

    private val romania by lazy {
        listOf(
        track("ro.gimnaziu", "Gimnaziu", "🎒", "lycee", "lowerSecondary",
              years("ro.g", listOf("Clasa a V-a", "Clasa a VI-a", "Clasa a VII-a", "Clasa a VIII-a"), subjects = roSubjects, lastExams = listOf("ro.en"))),
        track("ro.liceu", "Liceu", "🏫", "lycee", "upperSecondary",
              years("ro.l", listOf("Clasa a IX-a", "Clasa a X-a", "Clasa a XI-a", "Clasa a XII-a"), subjects = roSubjects + listOf("Logică", "Psihologie"), lastExams = listOf("ro.bac"))),
        track("ro.medicina", "Medicină", "🩺", "sante", "health",
              years("ro.med", listOf("Anii preclinici", "Anii clinici"), subjects = listOf(
                  "Anatomie", "Fiziologie", "Biochimie", "Histologie", "Farmacologie", "Patologie",
              ))),
        track("ro.licenta", "Facultate (licență)", "🎓", "licence", "undergraduate",
              years("ro.lic", listOf("Anul I", "Anul II", "Anul III", "Anul IV"))),
        track("ro.master", "Master", "🔬", "master", "graduate",
              years("ro.mas", listOf("Anul I", "Anul II"))),
    )
    }

    private val roSubjects by lazy {
        listOf(
        "Limba și literatura română", "Matematică", "Fizică", "Chimie", "Biologie", "Istorie",
        "Geografie", "Limba engleză", "Limba franceză", "Informatică", "Educație fizică",
    )
    }

    private val sweden by lazy {
        listOf(
        track("se.hogstadiet", "Högstadiet", "🎒", "lycee", "lowerSecondary",
              years("se.h", listOf("Årskurs 7", "Årskurs 8", "Årskurs 9"), subjects = seSubjects, lastExams = listOf("se.np"))),
        track("se.gymnasiet", "Gymnasiet", "🏫", "lycee", "upperSecondary",
              years("se.g", listOf("År 1", "År 2", "År 3"), subjects = seSubjects + listOf("Psykologi", "Filosofi"), lastExams = listOf("se.np", "se.hp"), exams = mapOf(1 to listOf("se.hp")))),
        track("se.lakare", "Läkarprogrammet", "🩺", "sante", "health",
              years("se.lak", listOf("Preklinisk del", "Klinisk del"), subjects = listOf(
                  "Anatomi", "Fysiologi", "Biokemi", "Histologi", "Farmakologi", "Patologi",
              ))),
        track("se.kandidat", "Universitet (kandidat)", "🎓", "licence", "undergraduate",
              years("se.kand", listOf("År 1", "År 2", "År 3"))),
        track("se.master", "Master", "🔬", "master", "graduate",
              years("se.mas", listOf("Master"))),
    )
    }

    private val seSubjects by lazy {
        listOf(
        "Svenska", "Matematik", "Engelska", "Biologi", "Fysik", "Kemi", "Historia",
        "Samhällskunskap", "Geografi", "Religionskunskap", "Moderna språk", "Idrott och hälsa",
    )
    }

    private val denmark by lazy {
        listOf(
        track("dk.folkeskole", "Folkeskolen (udskolingen)", "🎒", "lycee", "lowerSecondary",
              years("dk.f", listOf("7. klasse", "8. klasse", "9. klasse", "10. klasse"), subjects = dkSubjects, lastExams = listOf("dk.afgangsprove"), exams = mapOf(2 to listOf("dk.afgangsprove")))),
        track("dk.gymnasium", "Gymnasiet (stx, hhx, htx)", "🏫", "lycee", "upperSecondary",
              years("dk.g", listOf("1.g", "2.g", "3.g"), subjects = dkSubjects + listOf("Samfundsfag", "Kemi"), lastExams = listOf("dk.studentereksamen"))),
        track("dk.medicin", "Medicin", "🩺", "sante", "health",
              years("dk.med", listOf("Bachelordelen", "Kandidatdelen"), subjects = listOf(
                  "Anatomi", "Fysiologi", "Biokemi", "Histologi", "Farmakologi", "Patologi",
              ))),
        track("dk.bachelor", "Universitet (bachelor)", "🎓", "licence", "undergraduate",
              years("dk.bach", listOf("1. år", "2. år", "3. år"))),
        track("dk.kandidat", "Kandidat", "🔬", "master", "graduate",
              years("dk.kand", listOf("Kandidat"))),
    )
    }

    private val dkSubjects by lazy {
        listOf(
        "Dansk", "Matematik", "Engelsk", "Tysk", "Fysik/kemi", "Biologi", "Geografi",
        "Historie", "Kristendomskundskab", "Idræt",
    )
    }

    private val finland by lazy {
        listOf(
        track("fi.ylakoulu", "Yläkoulu", "🎒", "lycee", "lowerSecondary",
              years("fi.y", listOf("7. luokka", "8. luokka", "9. luokka"), subjects = fiSubjects)),
        track("fi.lukio", "Lukio", "🏫", "lycee", "upperSecondary",
              years("fi.l", listOf("1. vuosi", "2. vuosi", "3. vuosi"), subjects = fiSubjects + listOf("Psykologia", "Filosofia"), lastExams = listOf("fi.yo"), exams = mapOf(1 to listOf("fi.yo")))),
        track("fi.laaketiede", "Lääketiede", "🩺", "sante", "health",
              years("fi.lt", listOf("Prekliininen vaihe", "Kliininen vaihe"), subjects = listOf(
                  "Anatomia", "Fysiologia", "Biokemia", "Histologia", "Farmakologia", "Patologia",
              ))),
        track("fi.kandidaatti", "Yliopisto (kandidaatti)", "🎓", "licence", "undergraduate",
              years("fi.kand", listOf("1. vuosi", "2. vuosi", "3. vuosi"))),
        track("fi.maisteri", "Maisteri", "🔬", "master", "graduate",
              years("fi.mais", listOf("Maisteri"))),
    )
    }

    private val fiSubjects by lazy {
        listOf(
        "Äidinkieli ja kirjallisuus", "Matematiikka", "Englanti", "Ruotsi", "Fysiikka",
        "Kemia", "Biologia", "Maantieto", "Historia", "Yhteiskuntaoppi", "Liikunta",
    )
    }

    private val estonia by lazy {
        listOf(
        track("ee.pohikool", "Põhikool (III kooliaste)", "🎒", "lycee", "lowerSecondary",
              years("ee.p", listOf("7. klass", "8. klass", "9. klass"), subjects = eeSubjects, lastExams = listOf("ee.pohikool"))),
        track("ee.gumnaasium", "Gümnaasium", "🏫", "lycee", "upperSecondary",
              years("ee.g", listOf("10. klass", "11. klass", "12. klass"), subjects = eeSubjects, lastExams = listOf("ee.riigieksam"))),
        track("ee.arstiteadus", "Arstiteadus", "🩺", "sante", "health",
              years("ee.arst", listOf("Prekliiniline õpe", "Kliiniline õpe"), subjects = listOf(
                  "Anatoomia", "Füsioloogia", "Biokeemia", "Histoloogia", "Farmakoloogia", "Patoloogia",
              ))),
        track("ee.bakalaureus", "Bakalaureuseõpe", "🎓", "licence", "undergraduate",
              years("ee.bak", listOf("1. aasta", "2. aasta", "3. aasta"))),
        track("ee.magister", "Magistriõpe", "🔬", "master", "graduate",
              years("ee.mag", listOf("Magistriõpe"))),
    )
    }

    private val eeSubjects by lazy {
        listOf(
        "Eesti keel", "Kirjandus", "Matemaatika", "Inglise keel", "Vene keel", "Füüsika",
        "Keemia", "Bioloogia", "Geograafia", "Ajalugu", "Ühiskonnaõpetus", "Kehaline kasvatus",
    )
    }

    private val croatia by lazy {
        listOf(
        track("hr.osnovna", "Osnovna škola (viši razredi)", "🎒", "lycee", "lowerSecondary",
              years("hr.os", listOf("5. razred", "6. razred", "7. razred", "8. razred"), subjects = hrSubjects)),
        track("hr.gimnazija", "Gimnazija", "🏫", "lycee", "upperSecondary",
              years("hr.gim", listOf("1. razred", "2. razred", "3. razred", "4. razred"), subjects = hrSubjects + listOf("Latinski jezik"), lastExams = listOf("hr.matura"))),
        track("hr.strukovna", "Strukovna škola", "⚙️", "lycee", "upperSecondary",
              years("hr.str", listOf("1. razred", "2. razred", "3. razred", "4. razred"), subjects = hrSubjects + listOf("Strukovni predmeti"), lastExams = listOf("hr.matura"))),
        track("hr.medicina", "Medicina", "🩺", "sante", "health",
              years("hr.med", listOf("Pretklinika", "Klinika"), subjects = listOf(
                  "Anatomija", "Fiziologija", "Biokemija", "Histologija", "Farmakologija", "Patologija",
              ))),
        track("hr.preddiplomski", "Prijediplomski studij", "🎓", "licence", "undergraduate",
              years("hr.pred", listOf("1. godina", "2. godina", "3. godina"))),
        track("hr.diplomski", "Diplomski studij", "🔬", "master", "graduate",
              years("hr.dipl", listOf("1. godina", "2. godina"))),
    )
    }

    private val hrSubjects by lazy {
        listOf(
        "Hrvatski jezik", "Matematika", "Engleski jezik", "Njemački jezik", "Fizika", "Kemija",
        "Biologija", "Povijest", "Geografija", "Informatika", "Tjelesna i zdravstvena kultura",
    )
    }

    private val slovenia by lazy {
        listOf(
        track("si.osnovna", "Osnovna šola (tretje triletje)", "🎒", "lycee", "lowerSecondary",
              years("si.os", listOf("7. razred", "8. razred", "9. razred"), subjects = siSubjects, lastExams = listOf("si.npz"))),
        track("si.gimnazija", "Gimnazija", "🏫", "lycee", "upperSecondary",
              years("si.gim", listOf("1. letnik", "2. letnik", "3. letnik", "4. letnik"), subjects = siSubjects + listOf("Psihologija", "Filozofija"), lastExams = listOf("si.matura"))),
        track("si.medicina", "Medicina", "🩺", "sante", "health",
              years("si.med", listOf("Predklinični del", "Klinični del"), subjects = listOf(
                  "Anatomija", "Fiziologija", "Biokemija", "Histologija", "Farmakologija", "Patologija",
              ))),
        track("si.dodiplomski", "Univerza (1. stopnja)", "🎓", "licence", "undergraduate",
              years("si.uni", listOf("1. letnik", "2. letnik", "3. letnik"))),
        track("si.magistrski", "Magistrski študij", "🔬", "master", "graduate",
              years("si.mag", listOf("1. letnik", "2. letnik"))),
    )
    }

    private val siSubjects by lazy {
        listOf(
        "Slovenščina", "Matematika", "Angleščina", "Nemščina", "Fizika", "Kemija", "Biologija",
        "Zgodovina", "Geografija", "Informatika", "Športna vzgoja",
    )
    }

    private val serbia by lazy {
        listOf(
        track("rs.osnovna", "Osnovna škola (viši razredi)", "🎒", "lycee", "lowerSecondary",
              years("rs.os", listOf("5. razred", "6. razred", "7. razred", "8. razred"), subjects = rsSubjects, lastExams = listOf("rs.zavrsni"))),
        track("rs.gimnazija", "Gimnazija", "🏫", "lycee", "upperSecondary",
              years("rs.gim", listOf("1. razred", "2. razred", "3. razred", "4. razred"), subjects = rsSubjects + listOf("Latinski jezik", "Filozofija"), lastExams = listOf("rs.matura"))),
        track("rs.srednja", "Srednja stručna škola", "⚙️", "lycee", "upperSecondary",
              years("rs.ss", listOf("1. razred", "2. razred", "3. razred", "4. razred"), subjects = rsSubjects + listOf("Stručni predmeti"), lastExams = listOf("rs.matura"))),
        track("rs.medicina", "Medicina", "🩺", "sante", "health",
              years("rs.med", listOf("Pretklinika", "Klinika"), subjects = listOf(
                  "Anatomija", "Fiziologija", "Biohemija", "Histologija", "Farmakologija", "Patologija",
              ))),
        track("rs.osnovne", "Osnovne studije", "🎓", "licence", "undergraduate",
              years("rs.os.st", listOf("1. godina", "2. godina", "3. godina", "4. godina"))),
        track("rs.master", "Master studije", "🔬", "master", "graduate",
              years("rs.mas", listOf("Master"))),
    )
    }

    private val rsSubjects by lazy {
        listOf(
        "Srpski jezik i književnost", "Matematika", "Engleski jezik", "Fizika", "Hemija",
        "Biologija", "Istorija", "Geografija", "Informatika i računarstvo", "Fizičko vaspitanje",
    )
    }

    private val bulgaria by lazy {
        listOf(
        track("bg.progimnazia", "Прогимназия", "🎒", "lycee", "lowerSecondary",
              years("bg.p", listOf("5. клас", "6. клас", "7. клас"), subjects = bgSubjects, lastExams = listOf("bg.nvo7"))),
        track("bg.gimnazia", "Гимназия", "🏫", "lycee", "upperSecondary",
              years("bg.g", listOf("8. клас", "9. клас", "10. клас", "11. клас", "12. клас"), subjects = bgSubjects + listOf("Философия"), lastExams = listOf("bg.dzi"), exams = mapOf(2 to listOf("bg.nvo10")))),
        track("bg.medicina", "Медицина", "🩺", "sante", "health",
              years("bg.med", listOf("Предклинични години", "Клинични години"), subjects = listOf(
                  "Анатомия", "Физиология", "Биохимия", "Хистология", "Фармакология", "Патология",
              ))),
        track("bg.bakalavar", "Бакалавър", "🎓", "licence", "undergraduate",
              years("bg.bak", listOf("1. курс", "2. курс", "3. курс", "4. курс"))),
        track("bg.magistar", "Магистър", "🔬", "master", "graduate",
              years("bg.mag", listOf("Магистър"))),
    )
    }

    private val bgSubjects by lazy {
        listOf(
        "Български език и литература", "Математика", "Английски език", "Немски език",
        "Физика и астрономия", "Химия и опазване на околната среда",
        "Биология и здравно образование", "История и цивилизации", "География и икономика",
        "Информационни технологии", "Физическо възпитание и спорт",
    )
    }

    private val russia by lazy {
        listOf(
        track("ru.osnovnaya", "Основная школа", "🎒", "lycee", "lowerSecondary",
              years("ru.o", listOf("5 класс", "6 класс", "7 класс", "8 класс", "9 класс"), subjects = ruSubjects, lastExams = listOf("ru.oge"))),
        track("ru.starshaya", "Старшая школа", "🏫", "lycee", "upperSecondary",
              years("ru.s", listOf("10 класс", "11 класс"), subjects = ruSubjects + listOf("Обществознание"), lastExams = listOf("ru.ege"))),
        track("ru.meditsina", "Медицинский вуз", "🩺", "sante", "health",
              years("ru.med", listOf("Доклинические курсы", "Клинические курсы"), subjects = listOf(
                  "Анатомия", "Физиология", "Биохимия", "Гистология", "Фармакология", "Патология",
              ))),
        track("ru.bakalavriat", "Бакалавриат", "🎓", "licence", "undergraduate",
              years("ru.bak", listOf("1 курс", "2 курс", "3 курс", "4 курс"))),
        track("ru.magistratura", "Магистратура", "🔬", "master", "graduate",
              years("ru.mag", listOf("1 курс", "2 курс"))),
    )
    }

    private val ruSubjects by lazy {
        listOf(
        "Русский язык", "Литература", "Алгебра", "Геометрия", "Физика", "Химия", "Биология",
        "История", "География", "Английский язык", "Информатика", "Физкультура",
    )
    }

    private val austria by lazy {
        listOf(
        track("at.unterstufe", "Unterstufe (AHS, Mittelschule)", "🎒", "lycee", "lowerSecondary",
              years("at.u", listOf("1. Klasse", "2. Klasse", "3. Klasse", "4. Klasse"), subjects = atSubjects)),
        track("at.oberstufe", "AHS-Oberstufe", "🏫", "lycee", "upperSecondary",
              years("at.o", listOf("5. Klasse", "6. Klasse", "7. Klasse", "8. Klasse"), subjects = atSubjects + listOf("Psychologie und Philosophie"), lastExams = listOf("at.matura"))),
        track("at.bhs", "BHS (HAK, HTL, HLW …)", "⚙️", "lycee", "upperSecondary",
              years("at.bhs", listOf("1. Jahrgang", "2. Jahrgang", "3. Jahrgang", "4. Jahrgang", "5. Jahrgang"), subjects = listOf(
                  "Deutsch", "Englisch", "Angewandte Mathematik", "Betriebswirtschaft",
                  "Rechnungswesen", "Informatik", "Zweite lebende Fremdsprache", "Fachtheorie",
              ), lastExams = listOf("at.matura"))),
        track("at.medizin", "Medizin", "🩺", "sante", "health",
              years("at.med", listOf("1. Studienabschnitt", "2. und 3. Studienabschnitt"), subjects = listOf(
                  "Anatomie", "Physiologie", "Biochemie", "Histologie", "Pharmakologie", "Pathologie",
              ))),
        track("at.bachelor", "Universität, Bachelor", "🎓", "licence", "undergraduate",
              years("at.bach", listOf("1. Studienjahr", "2. Studienjahr", "3. Studienjahr"))),
        track("at.master", "Master", "🔬", "master", "graduate",
              years("at.mas", listOf("Master"))),
    )
    }

    private val atSubjects by lazy {
        listOf(
        "Deutsch", "Mathematik", "Englisch", "Biologie und Umweltbildung",
        "Geographie und wirtschaftliche Bildung", "Geschichte und Politische Bildung", "Physik",
        "Chemie", "Latein", "Französisch", "Informatik", "Bewegung und Sport",
    )
    }

    private val belgium by lazy {
        listOf(
        track("be.inferieur", "Secondaire, 1er degré", "🎒", "lycee", "lowerSecondary",
              years("be.s", listOf("1re secondaire", "2e secondaire"), subjects = beSubjects, lastExams = listOf("be.ce1d"))),
        track("be.superieur", "Secondaire, 2e et 3e degrés", "🏫", "lycee", "upperSecondary",
              listOf(
                  SchoolYear("be.s3", "3e secondaire", subjects = beSubjects),
                  SchoolYear("be.s4", "4e secondaire", subjects = beSubjects),
                  SchoolYear("be.s5", "5e secondaire", subjects = beSubjects + listOf("Chimie", "Physique", "Biologie")),
                  SchoolYear("be.s6", "6e secondaire", subjects = beSubjects + listOf("Chimie", "Physique", "Biologie"), exams = listOf("be.cess", "be.medecine")),
              )),
        track("be.medecine", "Médecine, santé", "🩺", "sante", "health",
              years("be.med", listOf("Bachelier", "Master"), subjects = listOf(
                  "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Pathologie",
              ))),
        track("be.bachelier", "Haute école, université : bachelier", "🎓", "licence", "undergraduate",
              years("be.bloc", listOf("Bloc 1", "Bloc 2", "Bloc 3"))),
        track("be.master", "Master", "🔬", "master", "graduate",
              years("be.mas", listOf("Master 1", "Master 2"))),
    )
    }

    private val beSubjects by lazy {
        listOf(
        "Français", "Mathématiques", "Néerlandais", "Anglais", "Sciences", "Histoire",
        "Géographie", "Latin", "Éducation physique", "Religion ou morale",
    )
    }

    private val canada by lazy {
        listOf(
        track("ca.secondaire", "Secondaire", "🎒", "lycee", "upperSecondary",
              listOf(
                  SchoolYear("ca.sec1", "Secondaire 1", subjects = caSubjects),
                  SchoolYear("ca.sec2", "Secondaire 2", subjects = caSubjects),
                  SchoolYear("ca.sec3", "Secondaire 3", subjects = caSubjects),
                  SchoolYear("ca.sec4", "Secondaire 4", subjects = caSubjects, exams = listOf("ca.ministerielles")),
                  SchoolYear("ca.sec5", "Secondaire 5", subjects = caSubjects + listOf("Chimie", "Physique"), exams = listOf("ca.ministerielles")),
              )),
        track("ca.cegep", "Cégep", "📐", "lycee", "preUniversity",
              years("ca.cegep", listOf("1re année", "2e année", "3e année (technique)"), subjects = listOf(
                  "Français", "Philosophie", "Anglais", "Mathématiques", "Chimie", "Physique",
                  "Biologie", "Psychologie", "Économie",
              ), exams = mapOf(1 to listOf("ca.euf")))),
        track("ca.medecine", "Médecine, santé", "🩺", "sante", "health",
              years("ca.med", listOf("Préclinique", "Externat"), subjects = listOf(
                  "Anatomie", "Physiologie", "Biochimie", "Histologie", "Pharmacologie", "Pathologie",
              ))),
        track("ca.bac", "Université : baccalauréat", "🎓", "licence", "undergraduate",
              years("ca.bac", listOf("1re année", "2e année", "3e année"))),
        track("ca.maitrise", "Maîtrise", "🔬", "master", "graduate",
              years("ca.mai", listOf("Maîtrise"))),
    )
    }

    private val caSubjects by lazy {
        listOf(
        "Français", "Mathématiques", "Anglais", "Science et technologie", "Histoire",
        "Géographie", "Culture et citoyenneté québécoise", "Arts", "Éducation physique",
    )
    }

    private val luxembourg by lazy {
        listOf(
        track("lu.inferieur", "Secondaire, classes inférieures", "🎒", "lycee", "lowerSecondary",
              years("lu.i", listOf("7e", "6e", "5e"), subjects = luSubjects)),
        track("lu.superieur", "Secondaire, classes supérieures", "🏫", "lycee", "upperSecondary",
              years("lu.s", listOf("4e", "3e", "2e", "1re"), subjects = luSubjects + listOf("Philosophie", "Chimie", "Physique"), lastExams = listOf("lu.examen"))),
        track("lu.bachelor", "Bachelor", "🎓", "licence", "undergraduate",
              years("lu.bach", listOf("1re année", "2e année", "3e année"))),
        track("lu.master", "Master", "🔬", "master", "graduate",
              years("lu.mas", listOf("Master"))),
    )
    }

    private val luSubjects by lazy {
        listOf(
        "Français", "Allemand", "Luxembourgeois", "Anglais", "Mathématiques", "Biologie",
        "Histoire", "Géographie", "Informatique", "Éducation physique",
    )
    }

    private val maghrebSubjects by lazy {
        listOf(
        "Mathématiques", "Physique-Chimie", "SVT", "Arabe", "Français", "Anglais",
        "Histoire-Géographie", "Philosophie", "Éducation islamique", "Informatique",
    )
    }

    private val westAfricaSubjects by lazy {
        listOf(
        "Mathématiques", "Physique-Chimie", "SVT", "Français", "Anglais", "Espagnol",
        "Histoire-Géographie", "Philosophie", "Éducation civique", "EPS",
    )
    }

    private val morocco by lazy {
        listOf(
        track("ma.college", "Collège", "🎒", "lycee", "lowerSecondary",
              years("ma.c", listOf("1re année collège", "2e année collège", "3e année collège"), subjects = maghrebSubjects, lastExams = listOf("ma.regional3"))),
        track("ma.lycee", "Lycée", "🏫", "lycee", "upperSecondary",
              listOf(
                  SchoolYear("ma.tc", "Tronc commun", subjects = maghrebSubjects),
                  SchoolYear("ma.1bac", "1re année bac", subjects = maghrebSubjects, exams = listOf("ma.regional")),
                  SchoolYear("ma.2bac", "2e année bac", subjects = maghrebSubjects, exams = listOf("ma.bac")),
              )),
        track("ma.prepa", "Classes prépa (CPGE)", "📐", "prepa", "preUniversity",
              years("ma.cpge", listOf("1re année", "2e année"), subjects = listOf(
                  "Mathématiques", "Physique", "Chimie", "Sciences de l'ingénieur", "Informatique",
                  "Français", "Anglais",
              ), lastExams = listOf("ma.cnc"))),
    )
    }

    private val algeria by lazy {
        listOf(
        track("dz.moyen", "Moyen (CEM)", "🎒", "lycee", "lowerSecondary",
              years("dz.am", listOf("1re AM", "2e AM", "3e AM", "4e AM"), subjects = maghrebSubjects + listOf("Tamazight"), lastExams = listOf("dz.bem"))),
        track("dz.lycee", "Lycée", "🏫", "lycee", "upperSecondary",
              years("dz.as", listOf("1re AS", "2e AS", "3e AS"), subjects = maghrebSubjects + listOf("Tamazight"), lastExams = listOf("dz.bac"))),
    )
    }

    private val tunisia by lazy {
        listOf(
        track("tn.college", "Collège", "🎒", "lycee", "lowerSecondary",
              years("tn.c", listOf("7e année de base", "8e année de base", "9e année de base"), subjects = maghrebSubjects, lastExams = listOf("tn.neuvieme"))),
        track("tn.lycee", "Lycée", "🏫", "lycee", "upperSecondary",
              years("tn.l", listOf("1re année secondaire", "2e année secondaire", "3e année secondaire", "4e année (bac)"), subjects = maghrebSubjects, lastExams = listOf("tn.bac"))),
    )
    }

    private val senegal by lazy {
        listOf(
        track("sn.moyen", "Collège (moyen)", "🎒", "lycee", "lowerSecondary",
              years("sn.c", listOf("6e", "5e", "4e", "3e"), subjects = westAfricaSubjects, lastExams = listOf("sn.bfem"))),
        track("sn.lycee", "Lycée", "🏫", "lycee", "upperSecondary",
              years("sn.l", listOf("Seconde", "Première", "Terminale"), subjects = westAfricaSubjects, lastExams = listOf("sn.bac"))),
    )
    }

    private val ivoryCoast by lazy {
        listOf(
        track("ci.college", "Collège", "🎒", "lycee", "lowerSecondary",
              years("ci.c", listOf("6e", "5e", "4e", "3e"), subjects = westAfricaSubjects, lastExams = listOf("ci.bepc"))),
        track("ci.lycee", "Lycée", "🏫", "lycee", "upperSecondary",
              years("ci.l", listOf("Seconde", "Première", "Terminale"), subjects = westAfricaSubjects, lastExams = listOf("ci.bac"))),
    )
    }

    private val latamSubjects by lazy {
        listOf(
        "Matemáticas", "Español", "Literatura", "Física", "Química", "Biología", "Historia",
        "Geografía", "Inglés", "Filosofía", "Informática", "Educación Física",
    )
    }

    private val mexico by lazy {
        listOf(
        track("mx.secundaria", "Secundaria", "🎒", "lycee", "lowerSecondary",
              years("mx.sec", listOf("1.º de secundaria", "2.º de secundaria", "3.º de secundaria"), subjects = listOf(
                  "Matemáticas", "Español", "Ciencias (Biología, Física, Química)", "Historia",
                  "Geografía", "Formación Cívica y Ética", "Inglés", "Tecnología", "Artes",
                  "Educación Física",
              ), lastExams = listOf("mx.prepa"))),
        track("mx.preparatoria", "Preparatoria (bachillerato)", "🏫", "lycee", "upperSecondary",
              years("mx.prep", listOf("1.er año de prepa", "2.º año de prepa", "3.er año de prepa"), subjects = latamSubjects, lastExams = listOf("mx.universidad"))),
    )
    }

    private val colombia by lazy {
        listOf(
        track("co.basica", "Básica secundaria", "🎒", "lycee", "lowerSecondary",
              years("co.b", listOf("Grado 6.º", "Grado 7.º", "Grado 8.º", "Grado 9.º"), subjects = latamSubjects)),
        track("co.media", "Educación media", "🏫", "lycee", "upperSecondary",
              years("co.m", listOf("Grado 10.º", "Grado 11.º"), subjects = latamSubjects + listOf("Ciencias Sociales"), lastExams = listOf("co.saber11"))),
    )
    }

    private val chile by lazy {
        listOf(
        track("cl.basica", "Enseñanza básica", "🎒", "lycee", "lowerSecondary",
              years("cl.b", listOf("7.º básico", "8.º básico"), subjects = latamSubjects)),
        track("cl.media", "Enseñanza media", "🏫", "lycee", "upperSecondary",
              years("cl.m", listOf("1.º medio", "2.º medio", "3.º medio", "4.º medio"), subjects = latamSubjects, lastExams = listOf("cl.paes"))),
    )
    }

    private val egypt by lazy {
        listOf(
        track("eg.idadi", "المرحلة الإعدادية", "🎒", "lycee", "lowerSecondary",
              years("eg.i", listOf("الصف الأول الإعدادي", "الصف الثاني الإعدادي", "الصف الثالث الإعدادي"), subjects = arabicSubjects, lastExams = listOf("eg.idadiya"))),
        track("eg.thanawi", "المرحلة الثانوية", "🏫", "lycee", "upperSecondary",
              years("eg.t", listOf("الصف الأول الثانوي", "الصف الثاني الثانوي", "الصف الثالث الثانوي"), subjects = arabicSubjects + listOf("الفلسفة والمنطق", "علم النفس"), lastExams = listOf("eg.thanawiya"))),
        track("eg.tib", "كلية الطب", "🩺", "sante", "health",
              years("eg.tib", listOf("السنوات الأساسية", "السنوات الإكلينيكية"), subjects = arabicMedicine)),
        track("eg.jamia", "الجامعة (البكالوريوس)", "🎓", "licence", "undergraduate",
              years("eg.uni", listOf("الفرقة الأولى", "الفرقة الثانية", "الفرقة الثالثة", "الفرقة الرابعة"))),
        track("eg.majister", "الدراسات العليا", "🔬", "master", "graduate",
              years("eg.grad", listOf("الماجستير", "الدكتوراه"))),
    )
    }

    private val saudiArabia by lazy {
        listOf(
        track("sa.mutawassit", "المرحلة المتوسطة", "🎒", "lycee", "lowerSecondary",
              years("sa.m", listOf("الأول المتوسط", "الثاني المتوسط", "الثالث المتوسط"), subjects = arabicSubjects)),
        track("sa.thanawi", "المرحلة الثانوية", "🏫", "lycee", "upperSecondary",
              years("sa.t", listOf("الأول الثانوي", "الثاني الثانوي", "الثالث الثانوي"), subjects = arabicSubjects + listOf("علم الأرض والفضاء", "التقنية الرقمية"), lastExams = listOf("sa.qudurat", "sa.tahsili"))),
        track("sa.tib", "كلية الطب", "🩺", "sante", "health",
              years("sa.tib", listOf("السنوات الأساسية", "السنوات الإكلينيكية"), subjects = arabicMedicine)),
        track("sa.jamia", "الجامعة (البكالوريوس)", "🎓", "licence", "undergraduate",
              years("sa.uni", listOf("السنة الأولى", "السنة الثانية", "السنة الثالثة", "السنة الرابعة"))),
        track("sa.ulya", "الدراسات العليا", "🔬", "master", "graduate",
              years("sa.grad", listOf("الماجستير", "الدكتوراه"))),
    )
    }

    private val arabicSubjects by lazy {
        listOf(
        "اللغة العربية", "الرياضيات", "الفيزياء", "الكيمياء", "الأحياء", "التاريخ",
        "الجغرافيا", "اللغة الإنجليزية", "اللغة الفرنسية", "الدراسات الإسلامية", "الحاسب الآلي",
    )
    }

    private val arabicMedicine by lazy {
        listOf(
        "التشريح", "علم وظائف الأعضاء", "الكيمياء الحيوية", "علم الأنسجة", "علم الأدوية", "علم الأمراض",
    )
    }

    /** Les examens de chaque pays, leur date habituelle (`SchoolExams.all`). */
    val exams: List<SchoolExam> by lazy {
        listOf(
        SchoolExam("fr.brevet", "Brevet", month = 6, day = 25, emoji = "🎒"),
        SchoolExam("fr.bacFrancais", "Bac de français", month = 6, day = 12, emoji = "✍️"),
        SchoolExam("fr.bac", "Bac", month = 6, day = 15, emoji = "🎓"),
        SchoolExam("fr.bacPro", "Bac pro", month = 6, day = 15, emoji = "🎓"),
        SchoolExam("fr.concours", "Concours", month = 4, day = 15, emoji = "🏁"),
        SchoolExam("be.ce1d", "CE1D", month = 6, day = 15, emoji = "🎒"),
        SchoolExam("be.cess", "CESS", month = 6, day = 10, emoji = "🎓"),
        SchoolExam("be.medecine", "Examen d'entrée en médecine", month = 7, day = 3, emoji = "🩺"),
        SchoolExam("ch.maturite", "Examens de maturité", month = 6, day = 1, emoji = "🎓"),
        SchoolExam("ch.matura", "Matura", month = 6, day = 1, emoji = "🎓"),
        SchoolExam("ch.ef", "Examen fédéral de médecine", month = 8, day = 25, emoji = "🩺"),
        SchoolExam("ch.eidg", "Eidgenössische Prüfung Humanmedizin", month = 8, day = 25, emoji = "🩺"),
        SchoolExam("lu.examen", "Examen de fin d'études secondaires", month = 5, day = 20, emoji = "🎓"),
        SchoolExam("ca.ministerielles", "Épreuves ministérielles", month = 6, day = 5, emoji = "📝"),
        SchoolExam("ca.euf", "Épreuve uniforme de français", month = 5, day = 7, emoji = "✍️"),
        SchoolExam("ma.regional3", "Examen régional (3e année collège)", month = 6, day = 10, emoji = "🎒"),
        SchoolExam("ma.regional", "Examen régional du bac", month = 6, day = 5, emoji = "📝"),
        SchoolExam("ma.bac", "Bac national", month = 6, day = 1, emoji = "🎓"),
        SchoolExam("ma.cnc", "Concours national commun (CNC)", month = 5, day = 1, emoji = "🏁"),
        SchoolExam("dz.bem", "BEM", month = 5, day = 20, emoji = "🎒"),
        SchoolExam("dz.bac", "Bac", month = 6, day = 12, emoji = "🎓"),
        SchoolExam("tn.neuvieme", "Concours de la 9e", month = 6, day = 15, emoji = "🎒"),
        SchoolExam("tn.bac", "Bac", month = 6, day = 5, emoji = "🎓"),
        SchoolExam("sn.bfem", "BFEM", month = 7, day = 7, emoji = "🎒"),
        SchoolExam("sn.bac", "Bac", month = 7, day = 1, emoji = "🎓"),
        SchoolExam("ci.bepc", "BEPC", month = 6, day = 1, emoji = "🎒"),
        SchoolExam("ci.bac", "Bac", month = 6, day = 10, emoji = "🎓"),
        SchoolExam("de.msa", "Realschulabschluss (MSA)", month = 5, day = 15, emoji = "🎒"),
        SchoolExam("de.abitur", "Abitur", month = 4, day = 20, emoji = "🎓"),
        SchoolExam("de.physikum", "Physikum", month = 8, day = 18, emoji = "🩺"),
        SchoolExam("de.staatsexamen", "Staatsexamen", month = 4, day = 8, emoji = "🩺"),
        SchoolExam("at.matura", "Matura", month = 5, day = 5, emoji = "🎓"),
        SchoolExam("uk.gcse", "GCSEs", month = 5, day = 11, emoji = "📗"),
        SchoolExam("uk.alevels", "A-levels", month = 5, day = 12, emoji = "🎓"),
        SchoolExam("us.sat", "SAT", emoji = "🎯"),
        SchoolExam("us.act", "ACT", emoji = "🎯"),
        SchoolExam("us.ap", "AP Exams", month = 5, day = 4, emoji = "📘"),
        SchoolExam("us.psat", "PSAT/NMSQT", month = 10, day = 14, emoji = "📝"),
        SchoolExam("us.gre", "GRE", emoji = "🎯"),
        SchoolExam("us.mcat", "MCAT", emoji = "🩺"),
        SchoolExam("us.usmle", "USMLE Step 1", emoji = "🩺"),
        SchoolExam("it.terzaMedia", "Esame di terza media", month = 6, day = 12, emoji = "🎒"),
        SchoolExam("it.invalsi", "Prove INVALSI", month = 4, day = 8, emoji = "📝"),
        SchoolExam("it.maturita", "Maturità", month = 6, day = 18, emoji = "🎓"),
        SchoolExam("es.pau", "PAU (Selectividad)", month = 6, day = 2, emoji = "🎓"),
        SchoolExam("es.mir", "MIR", month = 1, day = 24, emoji = "🩺"),
        SchoolExam("pt.provasFinais", "Provas finais do 9.º ano", month = 6, day = 17, emoji = "🎒"),
        SchoolExam("pt.exames", "Exames nacionais", month = 6, day = 17, emoji = "🎓"),
        SchoolExam("gr.panelladikes", "Πανελλαδικές Εξετάσεις", month = 5, day = 29, emoji = "🎓"),
        SchoolExam("nl.eindexamen", "Centraal eindexamen", month = 5, day = 12, emoji = "🎓"),
        SchoolExam("hu.felveteli", "Központi felvételi", month = 1, day = 17, emoji = "🎒"),
        SchoolExam("hu.erettsegi", "Érettségi", month = 5, day = 4, emoji = "🎓"),
        SchoolExam("pl.osmoklasisty", "Egzamin ósmoklasisty", month = 5, day = 19, emoji = "🎒"),
        SchoolExam("pl.matura", "Matura", month = 5, day = 4, emoji = "🎓"),
        SchoolExam("cz.prijimacky", "Přijímací zkoušky na SŠ", month = 4, day = 14, emoji = "🎒"),
        SchoolExam("cz.maturita", "Maturita", month = 5, day = 3, emoji = "🎓"),
        SchoolExam("sk.testovanie9", "Testovanie 9", month = 3, day = 18, emoji = "🎒"),
        SchoolExam("sk.maturita", "Maturita", month = 3, day = 17, emoji = "🎓"),
        SchoolExam("ro.en", "Evaluarea Națională", month = 6, day = 16, emoji = "🎒"),
        SchoolExam("ro.bac", "Bacalaureat", month = 6, day = 22, emoji = "🎓"),
        SchoolExam("se.np", "Nationella prov", month = 3, day = 10, emoji = "📝"),
        SchoolExam("se.hp", "Högskoleprovet", emoji = "🎯"),
        SchoolExam("dk.afgangsprove", "Folkeskolens afgangsprøve", month = 5, day = 6, emoji = "🎒"),
        SchoolExam("dk.studentereksamen", "Studentereksamen", month = 5, day = 20, emoji = "🎓"),
        SchoolExam("fi.yo", "Ylioppilaskoe", month = 3, day = 16, emoji = "🎓"),
        SchoolExam("ee.pohikool", "Põhikooli lõpueksamid", month = 6, day = 2, emoji = "🎒"),
        SchoolExam("ee.riigieksam", "Riigieksamid", month = 4, day = 24, emoji = "🎓"),
        SchoolExam("hr.matura", "Državna matura", month = 6, day = 2, emoji = "🎓"),
        SchoolExam("si.npz", "NPZ", month = 5, day = 6, emoji = "🎒"),
        SchoolExam("si.matura", "Splošna matura", month = 5, day = 30, emoji = "🎓"),
        SchoolExam("rs.zavrsni", "Završni ispit", month = 6, day = 17, emoji = "🎒"),
        SchoolExam("rs.matura", "Maturski ispit", month = 6, day = 1, emoji = "🎓"),
        SchoolExam("bg.nvo7", "НВО след 7. клас", month = 6, day = 17, emoji = "🎒"),
        SchoolExam("bg.nvo10", "НВО след 10. клас", month = 6, day = 12, emoji = "📝"),
        SchoolExam("bg.dzi", "ДЗИ (матури)", month = 5, day = 20, emoji = "🎓"),
        SchoolExam("ru.oge", "ОГЭ", month = 5, day = 25, emoji = "🎒"),
        SchoolExam("ru.ege", "ЕГЭ", month = 6, day = 1, emoji = "🎓"),
        SchoolExam("tr.lgs", "LGS", month = 6, day = 7, emoji = "🎒"),
        SchoolExam("tr.yks", "YKS", month = 6, day = 20, emoji = "🎓"),
        SchoolExam("br.enem", "ENEM", month = 11, day = 8, emoji = "🎓"),
        SchoolExam("br.vestibular", "Vestibular (Fuvest, Unicamp…)", month = 11, day = 22, emoji = "🏁"),
        SchoolExam("mx.prepa", "Examen de admisión a la prepa", month = 6, day = 20, emoji = "🎒"),
        SchoolExam("mx.universidad", "Examen de admisión a la universidad", month = 5, day = 25, emoji = "🎓"),
        SchoolExam("co.saber11", "Pruebas Saber 11", month = 8, day = 9, emoji = "🎓"),
        SchoolExam("cl.paes", "PAES", month = 12, day = 1, emoji = "🎓"),
        SchoolExam("eg.idadiya", "الشهادة الإعدادية", month = 6, day = 1, emoji = "🎒"),
        SchoolExam("eg.thanawiya", "الثانوية العامة", month = 6, day = 20, emoji = "🎓"),
        SchoolExam("sa.qudurat", "اختبار القدرات العامة", emoji = "🎯"),
        SchoolExam("sa.tahsili", "الاختبار التحصيلي", emoji = "🎓"),
    )
    }

    /** Le nom d'une matière du catalogue dans chaque langue de l'app (`SubjectDisplay`). */
    val subjectNames: Map<String, Map<String, String>> by lazy {
        hashMapOf(
            "Algorithmique" to mapOf("ar" to "الخوارزميات", "bg" to "Алгоритми", "cs" to "Algoritmy", "da" to "Algoritmer", "de" to "Algorithmen", "el" to "Αλγόριθμοι", "en" to "Algorithms", "es" to "Algoritmos", "es-419" to "Algoritmos", "et" to "Algoritmid", "fi" to "Algoritmit", "fr" to "Algorithmique", "he" to "אלגוריתמים", "hr" to "Algoritmi", "hu" to "Algoritmusok", "it" to "Algoritmi", "ja" to "アルゴリズム", "ko" to "알고리즘", "lt" to "Algoritmai", "lv" to "Algoritmi", "nb" to "Algoritmer", "nl" to "Algoritmen", "pl" to "Algorytmika", "pt-BR" to "Algoritmos", "pt-PT" to "Algoritmia", "ro" to "Algoritmică", "ru" to "Алгоритмы", "sk" to "Algoritmy", "sl" to "Algoritmi", "sr" to "Algoritmi", "sv" to "Algoritmer", "tr" to "Algoritma"),
            "Allemand" to mapOf("ar" to "الألمانية", "bg" to "Немски", "cs" to "Němčina", "da" to "Tysk", "de" to "Deutsch", "el" to "Γερμανικά", "en" to "German", "es" to "Alemán", "es-419" to "Alemán", "et" to "Saksa keel", "fi" to "Saksa", "fr" to "Allemand", "he" to "גרמנית", "hr" to "Njemački", "hu" to "Német", "it" to "Tedesco", "ja" to "ドイツ語", "ko" to "독일어", "lt" to "Vokiečių k.", "lv" to "Vācu val.", "nb" to "Tysk", "nl" to "Duits", "pl" to "Niemiecki", "pt-BR" to "Alemão", "pt-PT" to "Alemão", "ro" to "Germană", "ru" to "Немецкий", "sk" to "Nemčina", "sl" to "Nemščina", "sr" to "Nemački", "sv" to "Tyska", "tr" to "Almanca"),
            "Anatomie" to mapOf("ar" to "التشريح", "bg" to "Анатомия", "cs" to "Anatomie", "da" to "Anatomi", "de" to "Anatomie", "el" to "Ανατομία", "en" to "Anatomy", "es" to "Anatomía", "es-419" to "Anatomía", "et" to "Anatoomia", "fi" to "Anatomia", "fr" to "Anatomie", "he" to "אנטומיה", "hr" to "Anatomija", "hu" to "Anatómia", "it" to "Anatomia", "ja" to "解剖学", "ko" to "해부학", "lt" to "Anatomija", "lv" to "Anatomija", "nb" to "Anatomi", "nl" to "Anatomie", "pl" to "Anatomia", "pt-BR" to "Anatomia", "pt-PT" to "Anatomia", "ro" to "Anatomie", "ru" to "Анатомия", "sk" to "Anatómia", "sl" to "Anatomija", "sr" to "Anatomija", "sv" to "Anatomi", "tr" to "Anatomi"),
            "Anglais" to mapOf("ar" to "الإنجليزية", "bg" to "Английски", "cs" to "Angličtina", "da" to "Engelsk", "de" to "Englisch", "el" to "Αγγλικά", "en" to "English", "es" to "Inglés", "es-419" to "Inglés", "et" to "Inglise keel", "fi" to "Englanti", "fr" to "Anglais", "he" to "אנגלית", "hr" to "Engleski", "hu" to "Angol", "it" to "Inglese", "ja" to "英語", "ko" to "영어", "lt" to "Anglų k.", "lv" to "Angļu val.", "nb" to "Engelsk", "nl" to "Engels", "pl" to "Angielski", "pt-BR" to "Inglês", "pt-PT" to "Inglês", "ro" to "Engleză", "ru" to "Английский", "sk" to "Angličtina", "sl" to "Angleščina", "sr" to "Engleski", "sv" to "Engelska", "tr" to "İngilizce"),
            "Arabe" to mapOf("ar" to "العربية", "bg" to "Арабски", "cs" to "Arabština", "da" to "Arabisk", "de" to "Arabisch", "el" to "Αραβικά", "en" to "Arabic", "es" to "Árabe", "es-419" to "Árabe", "et" to "Araabia keel", "fi" to "Arabia", "fr" to "Arabe", "he" to "ערבית", "hr" to "Arapski", "hu" to "Arab", "it" to "Arabo", "ja" to "アラビア語", "ko" to "아랍어", "lt" to "Arabų k.", "lv" to "Arābu val.", "nb" to "Arabisk", "nl" to "Arabisch", "pl" to "Arabski", "pt-BR" to "Árabe", "pt-PT" to "Árabe", "ro" to "Arabă", "ru" to "Арабский", "sk" to "Arabčina", "sl" to "Arabščina", "sr" to "Arapski", "sv" to "Arabiska", "tr" to "Arapça"),
            "Architecture" to mapOf("ar" to "العمارة", "bg" to "Архитектура", "cs" to "Architektura", "da" to "Arkitektur", "de" to "Architektur", "el" to "Αρχιτεκτονική", "en" to "Architecture", "es" to "Arquitectura", "es-419" to "Arquitectura", "et" to "Arhitektuur", "fi" to "Arkkitehtuuri", "fr" to "Architecture", "he" to "אדריכלות", "hr" to "Arhitektura", "hu" to "Építészet", "it" to "Architettura", "ja" to "建築", "ko" to "건축", "lt" to "Architektūra", "lv" to "Arhitektūra", "nb" to "Arkitektur", "nl" to "Architectuur", "pl" to "Architektura", "pt-BR" to "Arquitetura", "pt-PT" to "Arquitetura", "ro" to "Arhitectură", "ru" to "Архитектура", "sk" to "Architektúra", "sl" to "Arhitektura", "sr" to "Arhitektura", "sv" to "Arkitektur", "tr" to "Mimarlık"),
            "Arts" to mapOf("ar" to "الفنون", "bg" to "Изкуство", "cs" to "Umění", "da" to "Billedkunst", "de" to "Kunst", "el" to "Τέχνες", "en" to "Art", "es" to "Artes", "es-419" to "Arte", "et" to "Kunst", "fi" to "Kuvataide", "fr" to "Arts", "he" to "אמנות", "hr" to "Likovna umjetnost", "hu" to "Művészet", "it" to "Arte", "ja" to "美術", "ko" to "미술", "lt" to "Dailė", "lv" to "Vizuālā māksla", "nb" to "Kunst", "nl" to "Kunst", "pl" to "Sztuka", "pt-BR" to "Artes", "pt-PT" to "Artes", "ro" to "Arte", "ru" to "Искусство", "sk" to "Umenie", "sl" to "Likovna umetnost", "sr" to "Likovna umetnost", "sv" to "Bild & konst", "tr" to "Sanat"),
            "Astronomie" to mapOf("ar" to "علم الفلك", "bg" to "Астрономия", "cs" to "Astronomie", "da" to "Astronomi", "de" to "Astronomie", "el" to "Αστρονομία", "en" to "Astronomy", "es" to "Astronomía", "es-419" to "Astronomía", "et" to "Astronoomia", "fi" to "Tähtitiede", "fr" to "Astronomie", "he" to "אסטרונומיה", "hr" to "Astronomija", "hu" to "Csillagászat", "it" to "Astronomia", "ja" to "天文学", "ko" to "천문학", "lt" to "Astronomija", "lv" to "Astronomija", "nb" to "Astronomi", "nl" to "Sterrenkunde", "pl" to "Astronomia", "pt-BR" to "Astronomia", "pt-PT" to "Astronomia", "ro" to "Astronomie", "ru" to "Астрономия", "sk" to "Astronómia", "sl" to "Astronomija", "sr" to "Astronomija", "sv" to "Astronomi", "tr" to "Astronomi"),
            "Chimie" to mapOf("ar" to "الكيمياء", "bg" to "Химия", "cs" to "Chemie", "da" to "Kemi", "de" to "Chemie", "el" to "Χημεία", "en" to "Chemistry", "es" to "Química", "es-419" to "Química", "et" to "Keemia", "fi" to "Kemia", "fr" to "Chimie", "he" to "כימיה", "hr" to "Kemija", "hu" to "Kémia", "it" to "Chimica", "ja" to "化学", "ko" to "화학", "lt" to "Chemija", "lv" to "Ķīmija", "nb" to "Kjemi", "nl" to "Scheikunde", "pl" to "Chemia", "pt-BR" to "Química", "pt-PT" to "Química", "ro" to "Chimie", "ru" to "Химия", "sk" to "Chémia", "sl" to "Kemija", "sr" to "Hemija", "sv" to "Kemi", "tr" to "Kimya"),
            "Chinois" to mapOf("ar" to "الصينية", "bg" to "Китайски", "cs" to "Čínština", "da" to "Kinesisk", "de" to "Chinesisch", "el" to "Κινεζικά", "en" to "Chinese", "es" to "Chino", "es-419" to "Chino", "et" to "Hiina keel", "fi" to "Kiina", "fr" to "Chinois", "he" to "סינית", "hr" to "Kineski", "hu" to "Kínai", "it" to "Cinese", "ja" to "中国語", "ko" to "중국어", "lt" to "Kinų k.", "lv" to "Ķīniešu val.", "nb" to "Kinesisk", "nl" to "Chinees", "pl" to "Chiński", "pt-BR" to "Chinês", "pt-PT" to "Chinês", "ro" to "Chineză", "ru" to "Китайский", "sk" to "Čínština", "sl" to "Kitajščina", "sr" to "Kineski", "sv" to "Kinesiska", "tr" to "Çince"),
            "Cinéma" to mapOf("ar" to "السينما", "bg" to "Кино", "cs" to "Film", "da" to "Film", "de" to "Film", "el" to "Κινηματογράφος", "en" to "Film", "es" to "Cine", "es-419" to "Cine", "et" to "Film", "fi" to "Elokuva", "fr" to "Cinéma", "he" to "קולנוע", "hr" to "Film", "hu" to "Film", "it" to "Cinema", "ja" to "映画", "ko" to "영화", "lt" to "Kinas", "lv" to "Kino", "nb" to "Film", "nl" to "Film", "pl" to "Film", "pt-BR" to "Cinema", "pt-PT" to "Cinema", "ro" to "Film", "ru" to "Кино", "sk" to "Film", "sl" to "Film", "sr" to "Film", "sv" to "Film", "tr" to "Sinema"),
            "Code de la route" to mapOf("ar" to "قواعد المرور", "bg" to "Шофьорски изпит", "cs" to "Autoškola", "da" to "Køreteori", "de" to "Führerschein", "el" to "Κ.Ο.Κ.", "en" to "Driving theory", "es" to "Tráfico", "es-419" to "Examen de manejo", "et" to "Liikluseeskiri", "fi" to "Teoriakoe", "fr" to "Code de la route", "he" to "תאוריה", "hr" to "Vozački ispit", "hu" to "KRESZ", "it" to "Teoria della patente", "ja" to "運転免許の学科", "ko" to "운전면허 필기", "lt" to "Kelių eismas", "lv" to "Ceļu satiksme", "nb" to "Teoriprøven", "nl" to "Theorie-examen", "pl" to "Prawo jazdy", "pt-BR" to "Legislação de trânsito", "pt-PT" to "Código da estrada", "ro" to "Sala auto", "ru" to "ПДД", "sk" to "Autoškola", "sl" to "Cestni predpisi", "sr" to "Vozački ispit", "sv" to "Körkortsteori", "tr" to "Trafik"),
            "Comptabilité" to mapOf("ar" to "المحاسبة", "bg" to "Счетоводство", "cs" to "Účetnictví", "da" to "Regnskab", "de" to "Buchhaltung", "el" to "Λογιστική", "en" to "Accounting", "es" to "Contabilidad", "es-419" to "Contabilidad", "et" to "Raamatupidamine", "fi" to "Kirjanpito", "fr" to "Comptabilité", "he" to "חשבונאות", "hr" to "Računovodstvo", "hu" to "Számvitel", "it" to "Contabilità", "ja" to "会計", "ko" to "회계", "lt" to "Apskaita", "lv" to "Grāmatvedība", "nb" to "Regnskap", "nl" to "Boekhouden", "pl" to "Rachunkowość", "pt-BR" to "Contabilidade", "pt-PT" to "Contabilidade", "ro" to "Contabilitate", "ru" to "Бухучёт", "sk" to "Účtovníctvo", "sl" to "Računovodstvo", "sr" to "Računovodstvo", "sv" to "Redovisning", "tr" to "Muhasebe"),
            "Culture générale" to mapOf("ar" to "الثقافة العامة", "bg" to "Обща култура", "cs" to "Všeobecný přehled", "da" to "Almen viden", "de" to "Allgemeinwissen", "el" to "Γενικές γνώσεις", "en" to "General knowledge", "es" to "Cultura general", "es-419" to "Cultura general", "et" to "Üldteadmised", "fi" to "Yleissivistys", "fr" to "Culture générale", "he" to "ידע כללי", "hr" to "Opća kultura", "hu" to "Általános műveltség", "it" to "Cultura generale", "ja" to "一般教養", "ko" to "일반 상식", "lt" to "Bendrosios žinios", "lv" to "Vispārējās zināšanas", "nb" to "Allmennkunnskap", "nl" to "Algemene kennis", "pl" to "Wiedza ogólna", "pt-BR" to "Conhecimentos gerais", "pt-PT" to "Cultura geral", "ro" to "Cultură generală", "ru" to "Общая эрудиция", "sk" to "Všeobecný prehľad", "sl" to "Splošna razgledanost", "sr" to "Opšta kultura", "sv" to "Allmänbildning", "tr" to "Genel kültür"),
            "Danse" to mapOf("ar" to "الرقص", "bg" to "Танци", "cs" to "Tanec", "da" to "Dans", "de" to "Tanz", "el" to "Χορός", "en" to "Dance", "es" to "Danza", "es-419" to "Danza", "et" to "Tants", "fi" to "Tanssi", "fr" to "Danse", "he" to "מחול", "hr" to "Ples", "hu" to "Tánc", "it" to "Danza", "ja" to "ダンス", "ko" to "무용", "lt" to "Šokis", "lv" to "Deja", "nb" to "Dans", "nl" to "Dans", "pl" to "Taniec", "pt-BR" to "Dança", "pt-PT" to "Dança", "ro" to "Dans", "ru" to "Танцы", "sk" to "Tanec", "sl" to "Ples", "sr" to "Ples", "sv" to "Dans", "tr" to "Dans"),
            "Droit" to mapOf("ar" to "القانون", "bg" to "Право", "cs" to "Právo", "da" to "Jura", "de" to "Recht", "el" to "Νομικά", "en" to "Law", "es" to "Derecho", "es-419" to "Derecho", "et" to "Õigus", "fi" to "Oikeustiede", "fr" to "Droit", "he" to "משפטים", "hr" to "Pravo", "hu" to "Jog", "it" to "Diritto", "ja" to "法学", "ko" to "법학", "lt" to "Teisė", "lv" to "Tiesības", "nb" to "Jus", "nl" to "Recht", "pl" to "Prawo", "pt-BR" to "Direito", "pt-PT" to "Direito", "ro" to "Drept", "ru" to "Право", "sk" to "Právo", "sl" to "Pravo", "sr" to "Pravo", "sv" to "Juridik", "tr" to "Hukuk"),
            "Espagnol" to mapOf("ar" to "الإسبانية", "bg" to "Испански", "cs" to "Španělština", "da" to "Spansk", "de" to "Spanisch", "el" to "Ισπανικά", "en" to "Spanish", "es" to "Español", "es-419" to "Español", "et" to "Hispaania keel", "fi" to "Espanja", "fr" to "Espagnol", "he" to "ספרדית", "hr" to "Španjolski", "hu" to "Spanyol", "it" to "Spagnolo", "ja" to "スペイン語", "ko" to "스페인어", "lt" to "Ispanų k.", "lv" to "Spāņu val.", "nb" to "Spansk", "nl" to "Spaans", "pl" to "Hiszpański", "pt-BR" to "Espanhol", "pt-PT" to "Espanhol", "ro" to "Spaniolă", "ru" to "Испанский", "sk" to "Španielčina", "sl" to "Španščina", "sr" to "Španski", "sv" to "Spanska", "tr" to "İspanyolca"),
            "Finance" to mapOf("ar" to "المالية", "bg" to "Финанси", "cs" to "Finance", "da" to "Finansiering", "de" to "Finanzen", "el" to "Χρηματοοικονομικά", "en" to "Finance", "es" to "Finanzas", "es-419" to "Finanzas", "et" to "Rahandus", "fi" to "Rahoitus", "fr" to "Finance", "he" to "מימון", "hr" to "Financije", "hu" to "Pénzügy", "it" to "Finanza", "ja" to "金融", "ko" to "금융", "lt" to "Finansai", "lv" to "Finanses", "nb" to "Finans", "nl" to "Financiën", "pl" to "Finanse", "pt-BR" to "Finanças", "pt-PT" to "Finanças", "ro" to "Finanțe", "ru" to "Финансы", "sk" to "Financie", "sl" to "Finance", "sr" to "Finansije", "sv" to "Finans", "tr" to "Finans"),
            "Français" to mapOf("ar" to "الفرنسية", "bg" to "Френски", "cs" to "Francouzština", "da" to "Fransk", "de" to "Französisch", "el" to "Γαλλικά", "en" to "French", "es" to "Francés", "es-419" to "Francés", "et" to "Prantsuse keel", "fi" to "Ranska", "fr" to "Français", "he" to "צרפתית", "hr" to "Francuski", "hu" to "Francia", "it" to "Francese", "ja" to "フランス語", "ko" to "프랑스어", "lt" to "Prancūzų k.", "lv" to "Franču val.", "nb" to "Fransk", "nl" to "Frans", "pl" to "Francuski", "pt-BR" to "Francês", "pt-PT" to "Francês", "ro" to "Franceză", "ru" to "Французский", "sk" to "Francúzština", "sl" to "Francoščina", "sr" to "Francuski", "sv" to "Franska", "tr" to "Fransızca"),
            "Génie civil" to mapOf("ar" to "الهندسة المدنية", "bg" to "Строителство", "cs" to "Stavebnictví", "da" to "Byggeteknik", "de" to "Bauwesen", "el" to "Πολ. μηχανική", "en" to "Civil eng.", "es" to "Obra civil", "es-419" to "Ing. civil", "et" to "Ehitus", "fi" to "Rakennustekniikka", "fr" to "Génie civil", "he" to "הנדסה אזרחית", "hr" to "Građevina", "hu" to "Építőmérnöki", "it" to "Ing. civile", "ja" to "土木工学", "ko" to "토목공학", "lt" to "Statyba", "lv" to "Būvniecība", "nb" to "Bygg", "nl" to "Civiele techniek", "pl" to "Budownictwo", "pt-BR" to "Eng. civil", "pt-PT" to "Eng. civil", "ro" to "Construcții", "ru" to "Стройка", "sk" to "Stavebníctvo", "sl" to "Gradbeništvo", "sr" to "Građevina", "sv" to "Byggteknik", "tr" to "İnşaat"),
            "Géographie" to mapOf("ar" to "الجغرافيا", "bg" to "География", "cs" to "Zeměpis", "da" to "Geografi", "de" to "Geografie", "el" to "Γεωγραφία", "en" to "Geography", "es" to "Geografía", "es-419" to "Geografía", "et" to "Geograafia", "fi" to "Maantieto", "fr" to "Géographie", "he" to "גאוגרפיה", "hr" to "Geografija", "hu" to "Földrajz", "it" to "Geografia", "ja" to "地理", "ko" to "지리", "lt" to "Geografija", "lv" to "Ģeogrāfija", "nb" to "Geografi", "nl" to "Aardrijkskunde", "pl" to "Geografia", "pt-BR" to "Geografia", "pt-PT" to "Geografia", "ro" to "Geografie", "ru" to "География", "sk" to "Zemepis", "sl" to "Geografija", "sr" to "Geografija", "sv" to "Geografi", "tr" to "Coğrafya"),
            "Géologie" to mapOf("ar" to "الجيولوجيا", "bg" to "Геология", "cs" to "Geologie", "da" to "Geologi", "de" to "Geologie", "el" to "Γεωλογία", "en" to "Geology", "es" to "Geología", "es-419" to "Geología", "et" to "Geoloogia", "fi" to "Geologia", "fr" to "Géologie", "he" to "גאולוגיה", "hr" to "Geologija", "hu" to "Geológia", "it" to "Geologia", "ja" to "地学", "ko" to "지구과학", "lt" to "Geologija", "lv" to "Ģeoloģija", "nb" to "Geologi", "nl" to "Geologie", "pl" to "Geologia", "pt-BR" to "Geologia", "pt-PT" to "Geologia", "ro" to "Geologie", "ru" to "Геология", "sk" to "Geológia", "sl" to "Geologija", "sr" to "Geologija", "sv" to "Geologi", "tr" to "Jeoloji"),
            "Histoire" to mapOf("ar" to "التاريخ", "bg" to "История", "cs" to "Dějepis", "da" to "Historie", "de" to "Geschichte", "el" to "Ιστορία", "en" to "History", "es" to "Historia", "es-419" to "Historia", "et" to "Ajalugu", "fi" to "Historia", "fr" to "Histoire", "he" to "היסטוריה", "hr" to "Povijest", "hu" to "Történelem", "it" to "Storia", "ja" to "歴史", "ko" to "역사", "lt" to "Istorija", "lv" to "Vēsture", "nb" to "Historie", "nl" to "Geschiedenis", "pl" to "Historia", "pt-BR" to "História", "pt-PT" to "História", "ro" to "Istorie", "ru" to "История", "sk" to "Dejepis", "sl" to "Zgodovina", "sr" to "Istorija", "sv" to "Historia", "tr" to "Tarih"),
            "Informatique" to mapOf("ar" to "الحاسوب", "bg" to "Информатика", "cs" to "Informatika", "da" to "Datalogi", "de" to "Informatik", "el" to "Πληροφορική", "en" to "Computing", "es" to "Informática", "es-419" to "Computación", "et" to "Informaatika", "fi" to "Tietotekniikka", "fr" to "Informatique", "he" to "מדעי המחשב", "hr" to "Informatika", "hu" to "Informatika", "it" to "Informatica", "ja" to "情報", "ko" to "정보·컴퓨터", "lt" to "Informatika", "lv" to "Datorzinātne", "nb" to "IT", "nl" to "Informatica", "pl" to "Informatyka", "pt-BR" to "Informática", "pt-PT" to "Informática", "ro" to "Informatică", "ru" to "Информатика", "sk" to "Informatika", "sl" to "Računalništvo", "sr" to "Informatika", "sv" to "Datavetenskap", "tr" to "Bilişim"),
            "Italien" to mapOf("ar" to "الإيطالية", "bg" to "Италиански", "cs" to "Italština", "da" to "Italiensk", "de" to "Italienisch", "el" to "Ιταλικά", "en" to "Italian", "es" to "Italiano", "es-419" to "Italiano", "et" to "Itaalia keel", "fi" to "Italia", "fr" to "Italien", "he" to "איטלקית", "hr" to "Talijanski", "hu" to "Olasz", "it" to "Italiano", "ja" to "イタリア語", "ko" to "이탈리아어", "lt" to "Italų k.", "lv" to "Itāļu val.", "nb" to "Italiensk", "nl" to "Italiaans", "pl" to "Włoski", "pt-BR" to "Italiano", "pt-PT" to "Italiano", "ro" to "Italiană", "ru" to "Итальянский", "sk" to "Taliančina", "sl" to "Italijanščina", "sr" to "Italijanski", "sv" to "Italienska", "tr" to "İtalyanca"),
            "Japonais" to mapOf("ar" to "اليابانية", "bg" to "Японски", "cs" to "Japonština", "da" to "Japansk", "de" to "Japanisch", "el" to "Ιαπωνικά", "en" to "Japanese", "es" to "Japonés", "es-419" to "Japonés", "et" to "Jaapani keel", "fi" to "Japani", "fr" to "Japonais", "he" to "יפנית", "hr" to "Japanski", "hu" to "Japán", "it" to "Giapponese", "ja" to "日本語", "ko" to "일본어", "lt" to "Japonų k.", "lv" to "Japāņu val.", "nb" to "Japansk", "nl" to "Japans", "pl" to "Japoński", "pt-BR" to "Japonês", "pt-PT" to "Japonês", "ro" to "Japoneză", "ru" to "Японский", "sk" to "Japončina", "sl" to "Japonščina", "sr" to "Japanski", "sv" to "Japanska", "tr" to "Japonca"),
            "Journalisme" to mapOf("ar" to "الصحافة", "bg" to "Журналистика", "cs" to "Žurnalistika", "da" to "Journalistik", "de" to "Journalismus", "el" to "Δημοσιογραφία", "en" to "Journalism", "es" to "Periodismo", "es-419" to "Periodismo", "et" to "Ajakirjandus", "fi" to "Journalismi", "fr" to "Journalisme", "he" to "עיתונאות", "hr" to "Novinarstvo", "hu" to "Újságírás", "it" to "Giornalismo", "ja" to "ジャーナリズム", "ko" to "저널리즘", "lt" to "Žurnalistika", "lv" to "Žurnālistika", "nb" to "Journalistikk", "nl" to "Journalistiek", "pl" to "Dziennikarstwo", "pt-BR" to "Jornalismo", "pt-PT" to "Jornalismo", "ro" to "Jurnalism", "ru" to "Журналистика", "sk" to "Žurnalistika", "sl" to "Novinarstvo", "sr" to "Novinarstvo", "sv" to "Journalistik", "tr" to "Gazetecilik"),
            "Kinésithérapie" to mapOf("ar" to "العلاج الطبيعي", "bg" to "Кинезитерапия", "cs" to "Fyzioterapie", "da" to "Fysioterapi", "de" to "Physioth.", "el" to "Φυσικοθεραπεία", "en" to "Physiother.", "es" to "Fisioterapia", "es-419" to "Fisioterapia", "et" to "Füsioteraapia", "fi" to "Fysioterapia", "fr" to "Kinésithérapie", "he" to "פיזיותרפיה", "hr" to "Fizioterapija", "hu" to "Gyógytorna", "it" to "Fisioterapia", "ja" to "理学療法", "ko" to "물리치료", "lt" to "Kineziterapija", "lv" to "Fizioterapija", "nb" to "Fysioterapi", "nl" to "Fysiotherapie", "pl" to "Fizjoterapia", "pt-BR" to "Fisioterapia", "pt-PT" to "Fisioterapia", "ro" to "Kinetoterapie", "ru" to "Физиотерапия", "sk" to "Fyzioterapia", "sl" to "Fizioterapija", "sr" to "Fizioterapija", "sv" to "Fysioterapi", "tr" to "Fizyoterapi"),
            "Latin & grec" to mapOf("ar" to "اللاتينية واليونانية", "bg" to "Латински и гръцки", "cs" to "Latina a řečtina", "da" to "Latin & græsk", "de" to "Latein", "el" to "Λατινικά & Αρχαία", "en" to "Latin & Greek", "es" to "Latín y griego", "es-419" to "Latín y griego", "et" to "Ladina ja kreeka", "fi" to "Latina & kreikka", "fr" to "Latin & grec", "he" to "לטינית ויוונית", "hr" to "Latinski i grčki", "hu" to "Latin és görög", "it" to "Latino e greco", "ja" to "古典語", "ko" to "라틴어·그리스어", "lt" to "Lotynų ir graikų", "lv" to "Latīņu un grieķu", "nb" to "Latin og gresk", "nl" to "Latijn & Grieks", "pl" to "Łacina i greka", "pt-BR" to "Latim e grego", "pt-PT" to "Latim e grego", "ro" to "Latină & greacă", "ru" to "Латынь и греческий", "sk" to "Latinčina a gréčtina", "sl" to "Latinščina in grščina", "sr" to "Latinski i grčki", "sv" to "Latin & grekiska", "tr" to "Latince"),
            "Management" to mapOf("ar" to "الإدارة", "bg" to "Мениджмънт", "cs" to "Management", "da" to "Ledelse", "de" to "Management", "el" to "Διοίκηση", "en" to "Management", "es" to "Management", "es-419" to "Administración", "et" to "Juhtimine", "fi" to "Johtaminen", "fr" to "Management", "he" to "ניהול", "hr" to "Menadžment", "hu" to "Menedzsment", "it" to "Management", "ja" to "経営", "ko" to "경영", "lt" to "Vadyba", "lv" to "Vadība", "nb" to "Ledelse", "nl" to "Management", "pl" to "Zarządzanie", "pt-BR" to "Administração", "pt-PT" to "Gestão", "ro" to "Management", "ru" to "Менеджмент", "sk" to "Manažment", "sl" to "Management", "sr" to "Menadžment", "sv" to "Ledarskap", "tr" to "Yönetim"),
            "Marketing" to mapOf("ar" to "التسويق", "bg" to "Маркетинг", "cs" to "Marketing", "da" to "Marketing", "de" to "Marketing", "el" to "Μάρκετινγκ", "en" to "Marketing", "es" to "Marketing", "es-419" to "Marketing", "et" to "Turundus", "fi" to "Markkinointi", "fr" to "Marketing", "he" to "שיווק", "hr" to "Marketing", "hu" to "Marketing", "it" to "Marketing", "ja" to "マーケティング", "ko" to "마케팅", "lt" to "Rinkodara", "lv" to "Mārketings", "nb" to "Markedsføring", "nl" to "Marketing", "pl" to "Marketing", "pt-BR" to "Marketing", "pt-PT" to "Marketing", "ro" to "Marketing", "ru" to "Маркетинг", "sk" to "Marketing", "sl" to "Trženje", "sr" to "Marketing", "sv" to "Marknadsföring", "tr" to "Pazarlama"),
            "Mathématiques" to mapOf("ar" to "الرياضيات", "bg" to "Математика", "cs" to "Matematika", "da" to "Matematik", "de" to "Mathematik", "el" to "Μαθηματικά", "en" to "Maths", "es" to "Matemáticas", "es-419" to "Matemáticas", "et" to "Matemaatika", "fi" to "Matematiikka", "fr" to "Mathématiques", "he" to "מתמטיקה", "hr" to "Matematika", "hu" to "Matek", "it" to "Matematica", "ja" to "数学", "ko" to "수학", "lt" to "Matematika", "lv" to "Matemātika", "nb" to "Matte", "nl" to "Wiskunde", "pl" to "Matematyka", "pt-BR" to "Matemática", "pt-PT" to "Matemática", "ro" to "Matematică", "ru" to "Математика", "sk" to "Matematika", "sl" to "Matematika", "sr" to "Matematika", "sv" to "Matematik", "tr" to "Matematik"),
            "Musique" to mapOf("ar" to "الموسيقى", "bg" to "Музика", "cs" to "Hudba", "da" to "Musik", "de" to "Musik", "el" to "Μουσική", "en" to "Music", "es" to "Música", "es-419" to "Música", "et" to "Muusika", "fi" to "Musiikki", "fr" to "Musique", "he" to "מוזיקה", "hr" to "Glazba", "hu" to "Ének-zene", "it" to "Musica", "ja" to "音楽", "ko" to "음악", "lt" to "Muzika", "lv" to "Mūzika", "nb" to "Musikk", "nl" to "Muziek", "pl" to "Muzyka", "pt-BR" to "Música", "pt-PT" to "Música", "ro" to "Muzică", "ru" to "Музыка", "sk" to "Hudba", "sl" to "Glasba", "sr" to "Muzika", "sv" to "Musik", "tr" to "Müzik"),
            "Mécanique" to mapOf("ar" to "الميكانيكا", "bg" to "Механика", "cs" to "Mechanika", "da" to "Mekanik", "de" to "Mechanik", "el" to "Μηχανική", "en" to "Mechanics", "es" to "Mecánica", "es-419" to "Mecánica", "et" to "Mehaanika", "fi" to "Mekaniikka", "fr" to "Mécanique", "he" to "מכניקה", "hr" to "Mehanika", "hu" to "Mechanika", "it" to "Meccanica", "ja" to "機械工学", "ko" to "기계공학", "lt" to "Mechanika", "lv" to "Mehānika", "nb" to "Mekanikk", "nl" to "Mechanica", "pl" to "Mechanika", "pt-BR" to "Mecânica", "pt-PT" to "Mecânica", "ro" to "Mecanică", "ru" to "Механика", "sk" to "Mechanika", "sl" to "Mehanika", "sr" to "Mehanika", "sv" to "Mekanik", "tr" to "Mekanik"),
            "Médecine" to mapOf("ar" to "الطب", "bg" to "Медицина", "cs" to "Medicína", "da" to "Medicin", "de" to "Medizin", "el" to "Ιατρική", "en" to "Medicine", "es" to "Medicina", "es-419" to "Medicina", "et" to "Meditsiin", "fi" to "Lääketiede", "fr" to "Médecine", "he" to "רפואה", "hr" to "Medicina", "hu" to "Orvostudomány", "it" to "Medicina", "ja" to "医学", "ko" to "의학", "lt" to "Medicina", "lv" to "Medicīna", "nb" to "Medisin", "nl" to "Geneeskunde", "pl" to "Medycyna", "pt-BR" to "Medicina", "pt-PT" to "Medicina", "ro" to "Medicină", "ru" to "Медицина", "sk" to "Medicína", "sl" to "Medicina", "sr" to "Medicina", "sv" to "Medicin", "tr" to "Tıp"),
            "Nutrition" to mapOf("ar" to "التغذية", "bg" to "Хранене", "cs" to "Výživa", "da" to "Ernæring", "de" to "Ernährung", "el" to "Διατροφή", "en" to "Nutrition", "es" to "Nutrición", "es-419" to "Nutrición", "et" to "Toitumine", "fi" to "Ravitsemus", "fr" to "Nutrition", "he" to "תזונה", "hr" to "Prehrana", "hu" to "Táplálkozástan", "it" to "Nutrizione", "ja" to "栄養学", "ko" to "영양학", "lt" to "Mityba", "lv" to "Uzturs", "nb" to "Ernæring", "nl" to "Voeding", "pl" to "Żywienie", "pt-BR" to "Nutrição", "pt-PT" to "Nutrição", "ro" to "Nutriție", "ru" to "Диетология", "sk" to "Výživa", "sl" to "Prehrana", "sr" to "Ishrana", "sv" to "Nutrition", "tr" to "Beslenme"),
            "Pharmacie" to mapOf("ar" to "الصيدلة", "bg" to "Фармация", "cs" to "Farmacie", "da" to "Farmaci", "de" to "Pharmazie", "el" to "Φαρμακευτική", "en" to "Pharmacy", "es" to "Farmacia", "es-419" to "Farmacia", "et" to "Farmaatsia", "fi" to "Farmasia", "fr" to "Pharmacie", "he" to "רוקחות", "hr" to "Farmacija", "hu" to "Gyógyszerészet", "it" to "Farmacia", "ja" to "薬学", "ko" to "약학", "lt" to "Farmacija", "lv" to "Farmācija", "nb" to "Farmasi", "nl" to "Farmacie", "pl" to "Farmacja", "pt-BR" to "Farmácia", "pt-PT" to "Farmácia", "ro" to "Farmacie", "ru" to "Фармация", "sk" to "Farmácia", "sl" to "Farmacija", "sr" to "Farmacija", "sv" to "Farmaci", "tr" to "Eczacılık"),
            "Philosophie" to mapOf("ar" to "الفلسفة", "bg" to "Философия", "cs" to "Filozofie", "da" to "Filosofi", "de" to "Philosophie", "el" to "Φιλοσοφία", "en" to "Philosophy", "es" to "Filosofía", "es-419" to "Filosofía", "et" to "Filosoofia", "fi" to "Filosofia", "fr" to "Philosophie", "he" to "פילוסופיה", "hr" to "Filozofija", "hu" to "Filozófia", "it" to "Filosofia", "ja" to "哲学", "ko" to "철학", "lt" to "Filosofija", "lv" to "Filozofija", "nb" to "Filosofi", "nl" to "Filosofie", "pl" to "Filozofia", "pt-BR" to "Filosofia", "pt-PT" to "Filosofia", "ro" to "Filozofie", "ru" to "Философия", "sk" to "Filozofia", "sl" to "Filozofija", "sr" to "Filozofija", "sv" to "Filosofi", "tr" to "Felsefe"),
            "Photographie" to mapOf("ar" to "التصوير", "bg" to "Фотография", "cs" to "Fotografie", "da" to "Fotografi", "de" to "Fotografie", "el" to "Φωτογραφία", "en" to "Photography", "es" to "Fotografía", "es-419" to "Fotografía", "et" to "Fotograafia", "fi" to "Valokuvaus", "fr" to "Photographie", "he" to "צילום", "hr" to "Fotografija", "hu" to "Fotográfia", "it" to "Fotografia", "ja" to "写真", "ko" to "사진", "lt" to "Fotografija", "lv" to "Fotogrāfija", "nb" to "Foto", "nl" to "Fotografie", "pl" to "Fotografia", "pt-BR" to "Fotografia", "pt-PT" to "Fotografia", "ro" to "Fotografie", "ru" to "Фотография", "sk" to "Fotografia", "sl" to "Fotografija", "sr" to "Fotografija", "sv" to "Fotografi", "tr" to "Fotoğraf"),
            "Physique" to mapOf("ar" to "الفيزياء", "bg" to "Физика", "cs" to "Fyzika", "da" to "Fysik", "de" to "Physik", "el" to "Φυσική", "en" to "Physics", "es" to "Física", "es-419" to "Física", "et" to "Füüsika", "fi" to "Fysiikka", "fr" to "Physique", "he" to "פיזיקה", "hr" to "Fizika", "hu" to "Fizika", "it" to "Fisica", "ja" to "物理", "ko" to "물리", "lt" to "Fizika", "lv" to "Fizika", "nb" to "Fysikk", "nl" to "Natuurkunde", "pl" to "Fizyka", "pt-BR" to "Física", "pt-PT" to "Física", "ro" to "Fizică", "ru" to "Физика", "sk" to "Fyzika", "sl" to "Fizika", "sr" to "Fizika", "sv" to "Fysik", "tr" to "Fizik"),
            "Portugais" to mapOf("ar" to "البرتغالية", "bg" to "Португалски", "cs" to "Portugalština", "da" to "Portugisisk", "de" to "Portugiesisch", "el" to "Πορτογαλικά", "en" to "Portuguese", "es" to "Portugués", "es-419" to "Portugués", "et" to "Portugali keel", "fi" to "Portugali", "fr" to "Portugais", "he" to "פורטוגזית", "hr" to "Portugalski", "hu" to "Portugál", "it" to "Portoghese", "ja" to "ポルトガル語", "ko" to "포르투갈어", "lt" to "Portugalų k.", "lv" to "Portugāļu val.", "nb" to "Portugisisk", "nl" to "Portugees", "pl" to "Portugalski", "pt-BR" to "Português", "pt-PT" to "Português", "ro" to "Portugheză", "ru" to "Португальский", "sk" to "Portugalčina", "sl" to "Portugalščina", "sr" to "Portugalski", "sv" to "Portugisiska", "tr" to "Portekizce"),
            "Psychologie" to mapOf("ar" to "علم النفس", "bg" to "Психология", "cs" to "Psychologie", "da" to "Psykologi", "de" to "Psychologie", "el" to "Ψυχολογία", "en" to "Psychology", "es" to "Psicología", "es-419" to "Psicología", "et" to "Psühholoogia", "fi" to "Psykologia", "fr" to "Psychologie", "he" to "פסיכולוגיה", "hr" to "Psihologija", "hu" to "Pszichológia", "it" to "Psicologia", "ja" to "心理学", "ko" to "심리학", "lt" to "Psichologija", "lv" to "Psiholoģija", "nb" to "Psykologi", "nl" to "Psychologie", "pl" to "Psychologia", "pt-BR" to "Psicologia", "pt-PT" to "Psicologia", "ro" to "Psihologie", "ru" to "Психология", "sk" to "Psychológia", "sl" to "Psihologija", "sr" to "Psihologija", "sv" to "Psykologi", "tr" to "Psikoloji"),
            "Pédagogie" to mapOf("ar" to "التربية", "bg" to "Педагогика", "cs" to "Pedagogika", "da" to "Pædagogik", "de" to "Pädagogik", "el" to "Παιδαγωγικά", "en" to "Education", "es" to "Pedagogía", "es-419" to "Pedagogía", "et" to "Pedagoogika", "fi" to "Kasvatustiede", "fr" to "Pédagogie", "he" to "חינוך", "hr" to "Pedagogija", "hu" to "Pedagógia", "it" to "Pedagogia", "ja" to "教育学", "ko" to "교육학", "lt" to "Pedagogika", "lv" to "Pedagoģija", "nb" to "Pedagogikk", "nl" to "Pedagogiek", "pl" to "Pedagogika", "pt-BR" to "Pedagogia", "pt-PT" to "Educação", "ro" to "Pedagogie", "ru" to "Педагогика", "sk" to "Pedagogika", "sl" to "Pedagogika", "sr" to "Pedagogija", "sv" to "Pedagogik", "tr" to "Pedagoji"),
            "Russe" to mapOf("ar" to "الروسية", "bg" to "Руски", "cs" to "Ruština", "da" to "Russisk", "de" to "Russisch", "el" to "Ρωσικά", "en" to "Russian", "es" to "Ruso", "es-419" to "Ruso", "et" to "Vene keel", "fi" to "Venäjä", "fr" to "Russe", "he" to "רוסית", "hr" to "Ruski", "hu" to "Orosz", "it" to "Russo", "ja" to "ロシア語", "ko" to "러시아어", "lt" to "Rusų k.", "lv" to "Krievu val.", "nb" to "Russisk", "nl" to "Russisch", "pl" to "Rosyjski", "pt-BR" to "Russo", "pt-PT" to "Russo", "ro" to "Rusă", "ru" to "Русский", "sk" to "Ruština", "sl" to "Ruščina", "sr" to "Ruski", "sv" to "Ryska", "tr" to "Rusça"),
            "Réseaux" to mapOf("ar" to "الشبكات", "bg" to "Мрежи", "cs" to "Sítě", "da" to "Netværk", "de" to "Netzwerke", "el" to "Δίκτυα", "en" to "Networks", "es" to "Redes", "es-419" to "Redes", "et" to "Võrgud", "fi" to "Verkot", "fr" to "Réseaux", "he" to "רשתות", "hr" to "Mreže", "hu" to "Hálózatok", "it" to "Reti", "ja" to "ネットワーク", "ko" to "네트워크", "lt" to "Tinklai", "lv" to "Tīkli", "nb" to "Nettverk", "nl" to "Netwerken", "pl" to "Sieci", "pt-BR" to "Redes", "pt-PT" to "Redes", "ro" to "Rețele", "ru" to "Сети", "sk" to "Siete", "sl" to "Omrežja", "sr" to "Mreže", "sv" to "Nätverk", "tr" to "Ağlar"),
            "SVT" to mapOf("ar" to "الأحياء", "bg" to "Биология", "cs" to "Biologie", "da" to "Biologi", "de" to "Biologie", "el" to "Βιολογία", "en" to "Biology", "es" to "Biología", "es-419" to "Biología", "et" to "Bioloogia", "fi" to "Biologia", "fr" to "SVT", "he" to "ביולוגיה", "hr" to "Biologija", "hu" to "Biológia", "it" to "Scienze", "ja" to "生物", "ko" to "생명과학", "lt" to "Biologija", "lv" to "Bioloģija", "nb" to "Biologi", "nl" to "Biologie", "pl" to "Biologia", "pt-BR" to "Biologia", "pt-PT" to "Biologia", "ro" to "Biologie", "ru" to "Биология", "sk" to "Biológia", "sl" to "Biologija", "sr" to "Biologija", "sv" to "Biologi", "tr" to "Biyoloji"),
            "Sciences politiques" to mapOf("ar" to "العلوم السياسية", "bg" to "Политология", "cs" to "Politologie", "da" to "Statskundskab", "de" to "Politik", "el" to "Πολιτικές επιστήμες", "en" to "Politics", "es" to "Ciencias políticas", "es-419" to "Ciencia política", "et" to "Politoloogia", "fi" to "Valtio-oppi", "fr" to "Sciences politiques", "he" to "מדע המדינה", "hr" to "Politologija", "hu" to "Politológia", "it" to "Scienze politiche", "ja" to "政治学", "ko" to "정치학", "lt" to "Politologija", "lv" to "Politoloģija", "nb" to "Statsvitenskap", "nl" to "Politicologie", "pl" to "Politologia", "pt-BR" to "Ciência Política", "pt-PT" to "Ciência Política", "ro" to "Științe politice", "ru" to "Политология", "sk" to "Politológia", "sl" to "Politologija", "sr" to "Politikologija", "sv" to "Statsvetenskap", "tr" to "Siyaset"),
            "Sociologie" to mapOf("ar" to "علم الاجتماع", "bg" to "Социология", "cs" to "Sociologie", "da" to "Sociologi", "de" to "Soziologie", "el" to "Κοινωνιολογία", "en" to "Sociology", "es" to "Sociología", "es-419" to "Sociología", "et" to "Sotsioloogia", "fi" to "Sosiologia", "fr" to "Sociologie", "he" to "סוציולוגיה", "hr" to "Sociologija", "hu" to "Szociológia", "it" to "Sociologia", "ja" to "社会学", "ko" to "사회학", "lt" to "Sociologija", "lv" to "Socioloģija", "nb" to "Sosiologi", "nl" to "Sociologie", "pl" to "Socjologia", "pt-BR" to "Sociologia", "pt-PT" to "Sociologia", "ro" to "Sociologie", "ru" to "Социология", "sk" to "Sociológia", "sl" to "Sociologija", "sr" to "Sociologija", "sv" to "Sociologi", "tr" to "Sosyoloji"),
            "Soins infirmiers" to mapOf("ar" to "التمريض", "bg" to "Сестрински грижи", "cs" to "Ošetřovatelství", "da" to "Sygepleje", "de" to "Pflege", "el" to "Νοσηλευτική", "en" to "Nursing", "es" to "Enfermería", "es-419" to "Enfermería", "et" to "Õendus", "fi" to "Hoitotyö", "fr" to "Soins infirmiers", "he" to "סיעוד", "hr" to "Sestrinstvo", "hu" to "Ápolás", "it" to "Infermieristica", "ja" to "看護", "ko" to "간호", "lt" to "Slauga", "lv" to "Māszinības", "nb" to "Sykepleie", "nl" to "Verpleegkunde", "pl" to "Pielęgniarstwo", "pt-BR" to "Enfermagem", "pt-PT" to "Enfermagem", "ro" to "Asistență medicală", "ru" to "Сестринское дело", "sk" to "Ošetrovateľstvo", "sl" to "Zdravstvena nega", "sr" to "Sestrinstvo", "sv" to "Omvårdnad", "tr" to "Hemşirelik"),
            "Sport & STAPS" to mapOf("ar" to "الرياضة", "bg" to "Спорт", "cs" to "Sport", "da" to "Idræt", "de" to "Sport", "el" to "Φυσική αγωγή", "en" to "Sport", "es" to "Deporte", "es-419" to "Deporte", "et" to "Sport", "fi" to "Liikunta", "fr" to "Sport & STAPS", "he" to "ספורט", "hr" to "Sport", "hu" to "Sport", "it" to "Scienze motorie", "ja" to "体育", "ko" to "체육", "lt" to "Kūno kultūra", "lv" to "Sports", "nb" to "Idrett", "nl" to "Sport", "pl" to "WF i sport", "pt-BR" to "Educação Física", "pt-PT" to "Educação Física", "ro" to "Sport", "ru" to "Спорт", "sk" to "Šport", "sl" to "Šport", "sr" to "Sport", "sv" to "Idrott", "tr" to "Spor"),
            "Statistiques" to mapOf("ar" to "الإحصاء", "bg" to "Статистика", "cs" to "Statistika", "da" to "Statistik", "de" to "Statistik", "el" to "Στατιστική", "en" to "Statistics", "es" to "Estadística", "es-419" to "Estadística", "et" to "Statistika", "fi" to "Tilastotiede", "fr" to "Statistiques", "he" to "סטטיסטיקה", "hr" to "Statistika", "hu" to "Statisztika", "it" to "Statistica", "ja" to "統計", "ko" to "통계", "lt" to "Statistika", "lv" to "Statistika", "nb" to "Statistikk", "nl" to "Statistiek", "pl" to "Statystyka", "pt-BR" to "Estatística", "pt-PT" to "Estatística", "ro" to "Statistică", "ru" to "Статистика", "sk" to "Štatistika", "sl" to "Statistika", "sr" to "Statistika", "sv" to "Statistik", "tr" to "İstatistik"),
            "Théâtre" to mapOf("ar" to "المسرح", "bg" to "Театър", "cs" to "Divadlo", "da" to "Teater", "de" to "Theater", "el" to "Θέατρο", "en" to "Theatre", "es" to "Teatro", "es-419" to "Teatro", "et" to "Teater", "fi" to "Teatteri", "fr" to "Théâtre", "he" to "תיאטרון", "hr" to "Kazalište", "hu" to "Színház", "it" to "Teatro", "ja" to "演劇", "ko" to "연극", "lt" to "Teatras", "lv" to "Teātris", "nb" to "Teater", "nl" to "Theater", "pl" to "Teatr", "pt-BR" to "Teatro", "pt-PT" to "Teatro", "ro" to "Teatru", "ru" to "Театр", "sk" to "Divadlo", "sl" to "Gledališče", "sr" to "Pozorište", "sv" to "Teater", "tr" to "Tiyatro"),
            "Économie" to mapOf("ar" to "الاقتصاد", "bg" to "Икономика", "cs" to "Ekonomie", "da" to "Økonomi", "de" to "Wirtschaft", "el" to "Οικονομία", "en" to "Economics", "es" to "Economía", "es-419" to "Economía", "et" to "Majandus", "fi" to "Taloustiede", "fr" to "Économie", "he" to "כלכלה", "hr" to "Ekonomija", "hu" to "Közgazdaságtan", "it" to "Economia", "ja" to "経済", "ko" to "경제", "lt" to "Ekonomika", "lv" to "Ekonomika", "nb" to "Økonomi", "nl" to "Economie", "pl" to "Ekonomia", "pt-BR" to "Economia", "pt-PT" to "Economia", "ro" to "Economie", "ru" to "Экономика", "sk" to "Ekonómia", "sl" to "Ekonomija", "sr" to "Ekonomija", "sv" to "Ekonomi", "tr" to "Ekonomi"),
            "Électronique" to mapOf("ar" to "الإلكترونيات", "bg" to "Електроника", "cs" to "Elektronika", "da" to "Elektronik", "de" to "Elektronik", "el" to "Ηλεκτρονική", "en" to "Electronics", "es" to "Electrónica", "es-419" to "Electrónica", "et" to "Elektroonika", "fi" to "Elektroniikka", "fr" to "Électronique", "he" to "אלקטרוניקה", "hr" to "Elektronika", "hu" to "Elektronika", "it" to "Elettronica", "ja" to "電子工学", "ko" to "전자공학", "lt" to "Elektronika", "lv" to "Elektronika", "nb" to "Elektronikk", "nl" to "Elektronica", "pl" to "Elektronika", "pt-BR" to "Eletrônica", "pt-PT" to "Eletrónica", "ro" to "Electronică", "ru" to "Электроника", "sk" to "Elektronika", "sl" to "Elektronika", "sr" to "Elektronika", "sv" to "Elektronik", "tr" to "Elektronik"),
        )
    }
}
