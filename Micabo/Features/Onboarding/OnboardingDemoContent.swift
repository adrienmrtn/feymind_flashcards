import Foundation

// MARK: - La matière de la démonstration

/// **Ce que la démonstration montre, et dans quelle matière.**
///
/// Les écrans de démonstration ne montrent plus une fiche d'histoire à tout le monde : ils
/// montrent une fiche **de la matière que l'élève vient de cocher**, écrite dans la langue
/// où l'app lui écrira. Un lycéen turc qui a coché « Matematik » voit une fiche de
/// mathématiques en turc ; un élève espagnol qui a coché « Historia de España » voit la
/// Transición. C'est ce qui fait passer la démonstration de « voilà ce que l'app sait
/// faire » à « voilà ton prochain cours ».
///
/// Trois matières décrites, et c'est un choix : une fiche de démonstration doit être
/// **juste**, et trois fiches justes dans cinq langues valent mieux que trente fiches
/// approximatives. Tout ce qui ressemble à des sciences va sur les mathématiques ou la
/// biologie, tout ce qui ressemble aux humanités va sur l'histoire, et le reste retombe
/// sur les mathématiques, la matière la plus cochée dans tous les pays servis.
enum DemoSubject: CaseIterable {
    case maths
    case biology
    case history

    /// La matière de démonstration qui correspond à une matière cochée, dans n'importe
    /// laquelle des langues du catalogue. Les mots-clés sont des racines, pas des noms :
    /// « Matematik », « Mathematik », « Matemáticas » et « Maths » partagent « mat ».
    static func matching(_ subject: String?) -> DemoSubject {
        guard let subject else { return .maths }
        let needle = subject.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).lowercased()

        let biology = ["bio", "svt", "fen bil", "natur", "cienc", "vie et", "geolog", "jeol", "anatom", "physiol"]
        if biology.contains(where: { needle.contains($0) }) { return .biology }

        let history = [
            "hist", "tarih", "geschich", "geo", "cogra", "erdk", "philo", "felsefe", "socio",
            "polit", "econ", "droit", "recht", "derech", "hukuk", "litt", "edebiyat", "lengua",
            "deutsch", "francais", "turk", "anglais", "english", "ingl", "espagnol", "spanish",
            "allemand", "latin", "art", "musi", "psycho", "sozial", "sosyal", "religion", "din"
        ]
        if history.contains(where: { needle.contains($0) }) { return .history }

        return .maths
    }
}

// MARK: - La fiche

/// Le graphe qui accompagne la fiche. Un par matière : une frise pour l'histoire, une
/// courbe pour les mathématiques, des barres pour la biologie. C'est ce que l'app dessine
/// vraiment à partir d'un cours, et c'est ce qui distingue une fiche d'un résumé.
enum DemoChart {
    /// Des repères sur une ligne du temps, de gauche à droite.
    case timeline(title: String, marks: [DemoChartMark])
    /// La suite géométrique pour q = 1,5, tracée point par point.
    case curve(title: String)
    /// Des barres, chaque valeur entre 0 et 100.
    case bars(title: String, bars: [DemoChartMark])
}

struct DemoChartMark {
    let label: String
    let caption: String
    /// Position sur la frise, ou hauteur de la barre : entre 0 et 1.
    let value: Double
}

/// Une carte de révision tirée de la fiche : la question au recto, la réponse au verso.
struct DemoFlashcard {
    let front: String
    let back: String
}

/// Un extrait d'examen blanc : la question, la réponse écrite, et la correction.
struct DemoMock {
    let question: String
    let answer: String
    let feedback: String
}

/// **Une fiche telle que l'app l'écrit**, réduite à ce qu'un écran de téléphone montre :
/// le chapitre, le titre, un paragraphe avec sa phrase surlignée, l'encadré à retenir, et
/// le graphe. Tout est écrit dans la langue de rédaction, pas celle de l'interface : un
/// élève allemand dont le téléphone est en anglais lira quand même sa fiche en allemand.
struct DemoSheet {
    let subjectName: String
    let sourceFile: String
    let chapter: Int
    let cards: Int
    let title: String
    let lead: String
    let mark: String
    let keyLabel: String
    let key: String
    /// La formule composée, pour les mathématiques seulement.
    let formula: String?
    let chart: DemoChart
    let card: DemoFlashcard
    let mock: DemoMock
}

// MARK: - Le catalogue

enum OnboardingDemoContent {
    /// La fiche pour cette matière, dans cette langue. Les langues que le catalogue ne
    /// décrit pas retombent sur l'anglais : c'est aussi la langue dans laquelle l'app
    /// écrit pour un pays qu'elle ne connaît pas.
    static func sheet(for subject: DemoSubject, language: ContentLanguage) -> DemoSheet {
        switch language {
        case .fr: french(subject)
        case .de: german(subject)
        case .es: spanish(subject)
        case .tr: turkish(subject)
        default: english(subject)
        }
    }

    // MARK: Français

    private static func french(_ subject: DemoSubject) -> DemoSheet {
        switch subject {
        case .maths:
            DemoSheet(
                subjectName: "Mathématiques",
                sourceFile: "chap3-suites.pdf",
                chapter: 3,
                cards: 18,
                title: "Les suites géométriques",
                lead: "Une suite est géométrique quand on passe d'un terme au suivant en ",
                mark: "multipliant toujours par le même nombre q.",
                keyLabel: "À retenir",
                key: "Si q > 1, la suite explose. Si 0 < q < 1, elle tend vers 0.",
                formula: "$u_n = u_0 \\times q^{n}$",
                chart: .curve(title: "La suite pour q = 1,5"),
                card: DemoFlashcard(
                    front: "Comment reconnaît-on une suite géométrique ?",
                    back: "Le rapport entre deux termes consécutifs est constant : uₙ₊₁ ÷ uₙ = q."
                ),
                mock: DemoMock(
                    question: "Une suite géométrique a pour premier terme u₀ = 3 et pour raison q = 2. Calcule u₄.",
                    answer: "u₄ = u₀ × q⁴ = 3 × 16 = 48.",
                    feedback: "Bonne formule et bon calcul. Précise que l'indice 4 compte quatre multiplications depuis u₀."
                )
            )
        case .biology:
            DemoSheet(
                subjectName: "SVT",
                sourceFile: "cours-photosynthese.pdf",
                chapter: 2,
                cards: 21,
                title: "La photosynthèse",
                lead: "Dans les chloroplastes, la plante fabrique son glucose à partir d'eau et de CO₂ : ",
                mark: "c'est la lumière qui fournit l'énergie.",
                keyLabel: "À retenir",
                key: "6 CO₂ + 6 H₂O → C₆H₁₂O₆ + 6 O₂, uniquement à la lumière.",
                formula: nil,
                chart: .bars(title: "Photosynthèse selon la lumière", bars: [
                    DemoChartMark(label: "0 %", caption: "nuit", value: 0.04),
                    DemoChartMark(label: "25 %", caption: "", value: 0.34),
                    DemoChartMark(label: "50 %", caption: "", value: 0.62),
                    DemoChartMark(label: "75 %", caption: "", value: 0.84),
                    DemoChartMark(label: "100 %", caption: "midi", value: 0.92),
                ]),
                card: DemoFlashcard(
                    front: "Où se déroule la photosynthèse ?",
                    back: "Dans les chloroplastes, grâce à la chlorophylle, en présence de lumière, d'eau et de CO₂."
                ),
                mock: DemoMock(
                    question: "Explique pourquoi la photosynthèse s'arrête la nuit, et ce que la plante continue de faire.",
                    answer: "Sans lumière, la chlorophylle ne capte plus d'énergie : plus de glucose produit. La respiration, elle, continue.",
                    feedback: "Juste et complet. Tu aurais pu nommer le CO₂ rejeté par la respiration nocturne."
                )
            )
        case .history:
            DemoSheet(
                subjectName: "Histoire",
                sourceFile: "chap5-guerre-froide.pdf",
                chapter: 5,
                cards: 24,
                title: "La guerre froide, 1947-1991",
                lead: "Deux blocs, deux modèles, et jamais d'affrontement direct : ",
                mark: "la guerre se joue par pressions indirectes.",
                keyLabel: "À retenir",
                key: "Blocus, propagande, aide économique, guerres par procuration.",
                formula: nil,
                chart: .timeline(title: "Les grandes dates", marks: [
                    DemoChartMark(label: "1947", caption: "Plan Marshall", value: 0.06),
                    DemoChartMark(label: "1949", caption: "OTAN", value: 0.3),
                    DemoChartMark(label: "1962", caption: "Cuba", value: 0.62),
                    DemoChartMark(label: "1989", caption: "Le Mur", value: 0.94),
                ]),
                card: DemoFlashcard(
                    front: "Que marque la chute du mur de Berlin, en 1989 ?",
                    back: "La fin de la division de l'Europe en deux blocs, et le début de la fin de la guerre froide."
                ),
                mock: DemoMock(
                    question: "Pourquoi parle-t-on de guerre « froide » ? Appuie-toi sur un exemple daté.",
                    answer: "Les deux blocs s'affrontent sans combat direct : alliances, propagande, crises. En 1962, la crise de Cuba s'arrête avant la guerre.",
                    feedback: "Définition juste, exemple bien choisi. Un mot sur la dissuasion nucléaire aurait fermé la réponse."
                )
            )
        }
    }

    // MARK: English

    private static func english(_ subject: DemoSubject) -> DemoSheet {
        switch subject {
        case .maths:
            DemoSheet(
                subjectName: "Maths",
                sourceFile: "ch3-sequences.pdf",
                chapter: 3,
                cards: 18,
                title: "Geometric sequences",
                lead: "A sequence is geometric when each term is obtained from the previous one by ",
                mark: "multiplying by the same number q every time.",
                keyLabel: "Key point",
                key: "If q > 1 the sequence blows up. If 0 < q < 1 it tends to 0.",
                formula: "$u_n = u_0 \\times q^{n}$",
                chart: .curve(title: "The sequence for q = 1.5"),
                card: DemoFlashcard(
                    front: "How do you recognise a geometric sequence?",
                    back: "The ratio between two consecutive terms is constant: uₙ₊₁ ÷ uₙ = q."
                ),
                mock: DemoMock(
                    question: "A geometric sequence has first term u₀ = 3 and ratio q = 2. Find u₄.",
                    answer: "u₄ = u₀ × q⁴ = 3 × 16 = 48.",
                    feedback: "Right formula, right arithmetic. Say explicitly that index 4 means four multiplications from u₀."
                )
            )
        case .biology:
            DemoSheet(
                subjectName: "Biology",
                sourceFile: "photosynthesis-notes.pdf",
                chapter: 2,
                cards: 21,
                title: "Photosynthesis",
                lead: "In the chloroplasts, the plant builds glucose from water and CO₂: ",
                mark: "light provides the energy.",
                keyLabel: "Key point",
                key: "6 CO₂ + 6 H₂O → C₆H₁₂O₆ + 6 O₂, only in the light.",
                formula: nil,
                chart: .bars(title: "Photosynthesis rate vs light", bars: [
                    DemoChartMark(label: "0%", caption: "night", value: 0.04),
                    DemoChartMark(label: "25%", caption: "", value: 0.34),
                    DemoChartMark(label: "50%", caption: "", value: 0.62),
                    DemoChartMark(label: "75%", caption: "", value: 0.84),
                    DemoChartMark(label: "100%", caption: "noon", value: 0.92),
                ]),
                card: DemoFlashcard(
                    front: "Where does photosynthesis take place?",
                    back: "In the chloroplasts, thanks to chlorophyll, with light, water and CO₂."
                ),
                mock: DemoMock(
                    question: "Explain why photosynthesis stops at night, and what the plant keeps doing.",
                    answer: "Without light, chlorophyll captures no energy, so no glucose is made. Respiration carries on.",
                    feedback: "Correct and complete. You could have named the CO₂ released by night-time respiration."
                )
            )
        case .history:
            DemoSheet(
                subjectName: "History",
                sourceFile: "ch5-cold-war.pdf",
                chapter: 5,
                cards: 24,
                title: "The Cold War, 1947–1991",
                lead: "Two blocs, two models, and never a direct clash: ",
                mark: "the war is fought through indirect pressure.",
                keyLabel: "Key point",
                key: "Blockades, propaganda, economic aid, proxy wars.",
                formula: nil,
                chart: .timeline(title: "Key dates", marks: [
                    DemoChartMark(label: "1947", caption: "Marshall Plan", value: 0.06),
                    DemoChartMark(label: "1949", caption: "NATO", value: 0.3),
                    DemoChartMark(label: "1962", caption: "Cuba", value: 0.62),
                    DemoChartMark(label: "1989", caption: "The Wall", value: 0.94),
                ]),
                card: DemoFlashcard(
                    front: "What does the fall of the Berlin Wall in 1989 mark?",
                    back: "The end of Europe's division into two blocs, and the beginning of the end of the Cold War."
                ),
                mock: DemoMock(
                    question: "Why is it called a “cold” war? Use a dated example.",
                    answer: "The two blocs confront each other without direct fighting: alliances, propaganda, crises. In 1962 the Cuban crisis stopped short of war.",
                    feedback: "Sound definition, well-chosen example. A word on nuclear deterrence would have closed the answer."
                )
            )
        }
    }

    // MARK: Deutsch

    private static func german(_ subject: DemoSubject) -> DemoSheet {
        switch subject {
        case .maths:
            DemoSheet(
                subjectName: "Mathematik",
                sourceFile: "kap3-folgen.pdf",
                chapter: 3,
                cards: 18,
                title: "Geometrische Folgen",
                lead: "Eine Folge ist geometrisch, wenn man von einem Glied zum nächsten kommt, indem man ",
                mark: "immer mit derselben Zahl q multipliziert.",
                keyLabel: "Merke",
                key: "Für q > 1 wächst die Folge über alle Grenzen. Für 0 < q < 1 geht sie gegen 0.",
                formula: "$u_n = u_0 \\times q^{n}$",
                chart: .curve(title: "Die Folge für q = 1,5"),
                card: DemoFlashcard(
                    front: "Woran erkennt man eine geometrische Folge?",
                    back: "Der Quotient zweier aufeinanderfolgender Glieder ist konstant: uₙ₊₁ ÷ uₙ = q."
                ),
                mock: DemoMock(
                    question: "Eine geometrische Folge hat das Anfangsglied u₀ = 3 und den Quotienten q = 2. Berechne u₄.",
                    answer: "u₄ = u₀ · q⁴ = 3 · 16 = 48.",
                    feedback: "Richtige Formel, richtige Rechnung. Nenne, dass der Index 4 für vier Multiplikationen ab u₀ steht."
                )
            )
        case .biology:
            DemoSheet(
                subjectName: "Biologie",
                sourceFile: "fotosynthese-skript.pdf",
                chapter: 2,
                cards: 21,
                title: "Die Fotosynthese",
                lead: "In den Chloroplasten baut die Pflanze aus Wasser und CO₂ Glucose auf: ",
                mark: "die Energie dafür liefert das Licht.",
                keyLabel: "Merke",
                key: "6 CO₂ + 6 H₂O → C₆H₁₂O₆ + 6 O₂, nur bei Licht.",
                formula: nil,
                chart: .bars(title: "Fotosynthese je nach Licht", bars: [
                    DemoChartMark(label: "0 %", caption: "Nacht", value: 0.04),
                    DemoChartMark(label: "25 %", caption: "", value: 0.34),
                    DemoChartMark(label: "50 %", caption: "", value: 0.62),
                    DemoChartMark(label: "75 %", caption: "", value: 0.84),
                    DemoChartMark(label: "100 %", caption: "Mittag", value: 0.92),
                ]),
                card: DemoFlashcard(
                    front: "Wo findet die Fotosynthese statt?",
                    back: "In den Chloroplasten, mithilfe des Chlorophylls, bei Licht, Wasser und CO₂."
                ),
                mock: DemoMock(
                    question: "Erkläre, warum die Fotosynthese nachts aufhört, und was die Pflanze weiterhin tut.",
                    answer: "Ohne Licht nimmt das Chlorophyll keine Energie auf, es entsteht keine Glucose. Die Atmung läuft weiter.",
                    feedback: "Richtig und vollständig. Das bei der nächtlichen Atmung abgegebene CO₂ hättest du noch nennen können."
                )
            )
        case .history:
            DemoSheet(
                subjectName: "Geschichte",
                sourceFile: "kap5-kalter-krieg.pdf",
                chapter: 5,
                cards: 24,
                title: "Der Kalte Krieg, 1947–1991",
                lead: "Zwei Blöcke, zwei Modelle, und nie ein direkter Zusammenstoß: ",
                mark: "der Krieg wird über indirekten Druck geführt.",
                keyLabel: "Merke",
                key: "Blockaden, Propaganda, Wirtschaftshilfe, Stellvertreterkriege.",
                formula: nil,
                chart: .timeline(title: "Die wichtigsten Daten", marks: [
                    DemoChartMark(label: "1947", caption: "Marshallplan", value: 0.06),
                    DemoChartMark(label: "1949", caption: "NATO", value: 0.3),
                    DemoChartMark(label: "1962", caption: "Kuba", value: 0.62),
                    DemoChartMark(label: "1989", caption: "Mauerfall", value: 0.94),
                ]),
                card: DemoFlashcard(
                    front: "Wofür steht der Fall der Berliner Mauer 1989?",
                    back: "Für das Ende der Teilung Europas in zwei Blöcke und den Anfang vom Ende des Kalten Krieges."
                ),
                mock: DemoMock(
                    question: "Warum spricht man von einem „kalten“ Krieg? Belege es mit einem datierten Beispiel.",
                    answer: "Die Blöcke stehen sich ohne direkten Kampf gegenüber: Bündnisse, Propaganda, Krisen. 1962 endet die Kubakrise vor dem Krieg.",
                    feedback: "Treffende Definition, gutes Beispiel. Ein Satz zur nuklearen Abschreckung hätte die Antwort abgerundet."
                )
            )
        }
    }

    // MARK: Español

    private static func spanish(_ subject: DemoSubject) -> DemoSheet {
        switch subject {
        case .maths:
            DemoSheet(
                subjectName: "Matemáticas",
                sourceFile: "tema3-progresiones.pdf",
                chapter: 3,
                cards: 18,
                title: "Progresiones geométricas",
                lead: "Una sucesión es geométrica cuando se pasa de un término al siguiente ",
                mark: "multiplicando siempre por el mismo número r.",
                keyLabel: "Para recordar",
                key: "Si r > 1, la sucesión crece sin límite. Si 0 < r < 1, tiende a 0.",
                formula: "$a_n = a_0 \\times r^{n}$",
                chart: .curve(title: "La sucesión para r = 1,5"),
                card: DemoFlashcard(
                    front: "¿Cómo se reconoce una progresión geométrica?",
                    back: "El cociente entre dos términos consecutivos es constante: aₙ₊₁ ÷ aₙ = r."
                ),
                mock: DemoMock(
                    question: "Una progresión geométrica tiene primer término a₀ = 3 y razón r = 2. Calcula a₄.",
                    answer: "a₄ = a₀ · r⁴ = 3 · 16 = 48.",
                    feedback: "Fórmula y cálculo correctos. Indica que el índice 4 son cuatro multiplicaciones desde a₀."
                )
            )
        case .biology:
            DemoSheet(
                subjectName: "Biología",
                sourceFile: "apuntes-fotosintesis.pdf",
                chapter: 2,
                cards: 21,
                title: "La fotosíntesis",
                lead: "En los cloroplastos, la planta fabrica glucosa a partir de agua y CO₂: ",
                mark: "la luz aporta la energía.",
                keyLabel: "Para recordar",
                key: "6 CO₂ + 6 H₂O → C₆H₁₂O₆ + 6 O₂, solo con luz.",
                formula: nil,
                chart: .bars(title: "Fotosíntesis según la luz", bars: [
                    DemoChartMark(label: "0 %", caption: "noche", value: 0.04),
                    DemoChartMark(label: "25 %", caption: "", value: 0.34),
                    DemoChartMark(label: "50 %", caption: "", value: 0.62),
                    DemoChartMark(label: "75 %", caption: "", value: 0.84),
                    DemoChartMark(label: "100 %", caption: "mediodía", value: 0.92),
                ]),
                card: DemoFlashcard(
                    front: "¿Dónde ocurre la fotosíntesis?",
                    back: "En los cloroplastos, gracias a la clorofila, con luz, agua y CO₂."
                ),
                mock: DemoMock(
                    question: "Explica por qué la fotosíntesis se detiene de noche y qué sigue haciendo la planta.",
                    answer: "Sin luz, la clorofila no capta energía: no se produce glucosa. La respiración, en cambio, continúa.",
                    feedback: "Correcto y completo. Podías nombrar el CO₂ que libera la respiración nocturna."
                )
            )
        case .history:
            DemoSheet(
                subjectName: "Historia de España",
                sourceFile: "tema9-transicion.pdf",
                chapter: 9,
                cards: 24,
                title: "La Transición, 1975-1982",
                lead: "De la dictadura a la democracia sin ruptura violenta: ",
                mark: "el cambio se pacta entre reformistas y oposición.",
                keyLabel: "Para recordar",
                key: "Ley para la Reforma Política, elecciones, Constitución, 23-F, alternancia.",
                formula: nil,
                chart: .timeline(title: "Las fechas clave", marks: [
                    DemoChartMark(label: "1975", caption: "Muere Franco", value: 0.06),
                    DemoChartMark(label: "1977", caption: "Elecciones", value: 0.34),
                    DemoChartMark(label: "1978", caption: "Constitución", value: 0.52),
                    DemoChartMark(label: "1982", caption: "PSOE", value: 0.94),
                ]),
                card: DemoFlashcard(
                    front: "¿Qué supuso la Constitución de 1978?",
                    back: "El paso definitivo a la democracia: derechos, monarquía parlamentaria y Estado de las autonomías."
                ),
                mock: DemoMock(
                    question: "¿Por qué se habla de una transición «pactada»? Apóyate en un ejemplo con fecha.",
                    answer: "Porque el cambio se negoció en vez de imponerse: los Pactos de la Moncloa de 1977 reunieron a gobierno y oposición.",
                    feedback: "Definición ajustada y ejemplo bien elegido. Faltó citar la Ley para la Reforma Política de 1976."
                )
            )
        }
    }

    // MARK: Türkçe

    private static func turkish(_ subject: DemoSubject) -> DemoSheet {
        switch subject {
        case .maths:
            DemoSheet(
                subjectName: "Matematik",
                sourceFile: "unite3-diziler.pdf",
                chapter: 3,
                cards: 18,
                title: "Geometrik diziler",
                lead: "Bir dizi, her terimden bir sonrakine ",
                mark: "hep aynı q sayısıyla çarparak geçiliyorsa geometriktir.",
                keyLabel: "Aklında kalsın",
                key: "q > 1 ise dizi sınırsız büyür. 0 < q < 1 ise 0'a yaklaşır.",
                formula: "$a_n = a_0 \\times q^{n}$",
                chart: .curve(title: "q = 1,5 için dizi"),
                card: DemoFlashcard(
                    front: "Bir dizinin geometrik olduğu nasıl anlaşılır?",
                    back: "Ardışık iki terimin oranı sabittir: aₙ₊₁ ÷ aₙ = q."
                ),
                mock: DemoMock(
                    question: "Bir geometrik dizinin ilk terimi a₀ = 3, ortak çarpanı q = 2'dir. a₄ terimini bul.",
                    answer: "a₄ = a₀ · q⁴ = 3 · 16 = 48.",
                    feedback: "Formül ve işlem doğru. 4 indisinin a₀'dan itibaren dört çarpma anlamına geldiğini belirt."
                )
            )
        case .biology:
            DemoSheet(
                subjectName: "Biyoloji",
                sourceFile: "fotosentez-notlari.pdf",
                chapter: 2,
                cards: 21,
                title: "Fotosentez",
                lead: "Bitki, kloroplastlarda su ve CO₂'den glikoz üretir: ",
                mark: "enerjiyi ışık sağlar.",
                keyLabel: "Aklında kalsın",
                key: "6 CO₂ + 6 H₂O → C₆H₁₂O₆ + 6 O₂, yalnızca ışıkta.",
                formula: nil,
                chart: .bars(title: "Işığa göre fotosentez hızı", bars: [
                    DemoChartMark(label: "%0", caption: "gece", value: 0.04),
                    DemoChartMark(label: "%25", caption: "", value: 0.34),
                    DemoChartMark(label: "%50", caption: "", value: 0.62),
                    DemoChartMark(label: "%75", caption: "", value: 0.84),
                    DemoChartMark(label: "%100", caption: "öğle", value: 0.92),
                ]),
                card: DemoFlashcard(
                    front: "Fotosentez nerede gerçekleşir?",
                    back: "Kloroplastlarda, klorofil sayesinde; ışık, su ve CO₂ varlığında."
                ),
                mock: DemoMock(
                    question: "Fotosentezin geceleri neden durduğunu ve bitkinin neyi sürdürdüğünü açıkla.",
                    answer: "Işık olmayınca klorofil enerji alamaz, glikoz üretilmez. Solunum ise devam eder.",
                    feedback: "Doğru ve eksiksiz. Gece solunumunda açığa çıkan CO₂'yi de anabilirdin."
                )
            )
        case .history:
            DemoSheet(
                subjectName: "Tarih",
                sourceFile: "unite5-soguk-savas.pdf",
                chapter: 5,
                cards: 24,
                title: "Soğuk Savaş, 1947-1991",
                lead: "İki blok, iki model ve hiç doğrudan çatışma yok: ",
                mark: "savaş dolaylı baskılarla yürütülür.",
                keyLabel: "Aklında kalsın",
                key: "Ablukalar, propaganda, ekonomik yardım, vekâlet savaşları.",
                formula: nil,
                chart: .timeline(title: "Önemli tarihler", marks: [
                    DemoChartMark(label: "1947", caption: "Marshall Planı", value: 0.06),
                    DemoChartMark(label: "1949", caption: "NATO", value: 0.3),
                    DemoChartMark(label: "1962", caption: "Küba", value: 0.62),
                    DemoChartMark(label: "1989", caption: "Duvar", value: 0.94),
                ]),
                card: DemoFlashcard(
                    front: "1989'da Berlin Duvarı'nın yıkılması neyi simgeler?",
                    back: "Avrupa'nın iki bloğa bölünmüşlüğünün sonunu ve Soğuk Savaş'ın sonunun başlangıcını."
                ),
                mock: DemoMock(
                    question: "Neden \"soğuk\" savaş denir? Tarihli bir örnekle açıkla.",
                    answer: "İki blok doğrudan savaşmadan karşı karşıya gelir: ittifaklar, propaganda, krizler. 1962 Küba Krizi savaşa varmadan biter.",
                    feedback: "Tanım doğru, örnek yerinde. Nükleer caydırıcılığa bir cümle cevabı tamamlardı."
                )
            )
        }
    }
}

// MARK: - L'examen du pays

/// **La date qu'un élève de ce pays a en tête.**
///
/// Le calendrier de la démonstration ne montre plus « un mois de mars » avec trois
/// contrôles inventés : il montre le mois de **l'examen du pays**, avec sa date posée, et
/// le compte à rebours réel jusqu'à lui. Un lycéen turc voit le YKS de juin, un élève
/// allemand l'Abitur d'avril, un Français le bac de juin. C'est la seule date du parcours
/// qui ne soit pas une réponse de l'élève, et c'est celle qui le fait s'arrêter.
///
/// Les dates sont des repères, pas des convocations : la session exacte change d'une année
/// et d'un Land à l'autre, et on prend le jour le plus courant. Un examen déjà passé cette
/// année renvoie à celui de l'année prochaine.
struct OnboardingDemoExam {
    let name: String
    let month: Int
    let day: Int

    static func of(_ country: SchoolingCountry) -> OnboardingDemoExam {
        switch country {
        case .fr: OnboardingDemoExam(name: "Bac", month: 6, day: 15)
        case .tr: OnboardingDemoExam(name: "YKS", month: 6, day: 20)
        case .de: OnboardingDemoExam(name: "Abitur", month: 4, day: 28)
        case .es: OnboardingDemoExam(name: "PAU", month: 6, day: 3)
        case .it: OnboardingDemoExam(name: "Maturità", month: 6, day: 18)
        case .pt: OnboardingDemoExam(name: "Exames nacionais", month: 6, day: 17)
        case .cz: OnboardingDemoExam(name: "Maturita", month: 5, day: 5)
        case .nl: OnboardingDemoExam(name: "Eindexamen", month: 5, day: 14)
        case .gr: OnboardingDemoExam(name: "Πανελλήνιες", month: 6, day: 2)
        case .hu: OnboardingDemoExam(name: "Érettségi", month: 5, day: 5)
        case .pl: OnboardingDemoExam(name: "Matura", month: 5, day: 6)
        case .ro: OnboardingDemoExam(name: "Bacalaureat", month: 6, day: 29)
        case .se: OnboardingDemoExam(name: "Nationella prov", month: 5, day: 15)
        case .uk: OnboardingDemoExam(name: "A-Levels", month: 6, day: 15)
        case .us: OnboardingDemoExam(name: "Finals", month: 6, day: 10)
        case .be: OnboardingDemoExam(name: "Examens de juin", month: 6, day: 15)
        case .ch: OnboardingDemoExam(name: "Maturité", month: 6, day: 15)
        case .ca: OnboardingDemoExam(name: "Examens finaux", month: 6, day: 15)
        case .lu: OnboardingDemoExam(name: "Examen de fin d'études", month: 6, day: 15)
        case .ma, .dz, .tn, .sn, .ci: OnboardingDemoExam(name: "Bac", month: 6, day: 15)
        case .other: OnboardingDemoExam(name: "Exams", month: 6, day: 15)
        }
    }

    /// La prochaine occurrence de l'examen, à partir d'une date donnée.
    ///
    /// La date de référence est un paramètre et non `Date.now` lu au fond d'une vue : c'est
    /// ce qui permet de vérifier qu'un examen passé renvoie bien à l'année suivante sans
    /// attendre juillet.
    func nextDate(from reference: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Date {
        let year = calendar.component(.year, from: reference)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        let today = calendar.startOfDay(for: reference)
        guard let thisYear = calendar.date(from: components) else { return reference }
        if thisYear >= today { return thisYear }
        components.year = year + 1
        return calendar.date(from: components) ?? thisYear
    }

    /// Le nombre de jours qui restent, jamais négatif.
    func daysLeft(from reference: Date = Date(), calendar: Calendar = MicaboCalendar.shared) -> Int {
        let start = calendar.startOfDay(for: reference)
        let end = nextDate(from: reference, calendar: calendar)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}

// MARK: - Les nombres, écrits comme le pays les écrit

/// « 12 800 » en France, « 12.800 » en Turquie, « 12,800 » en anglais : un nombre de la
/// preuve sociale s'écrit dans la langue de l'interface, ou il ne se lit pas comme un nombre.
enum OnboardingNumbers {
    static func text(_ value: Int, locale: UiLocale) -> String {
        value.formatted(.number.locale(locale.foundation))
    }

    static func text(_ value: Double, fraction: Int = 1, locale: UiLocale) -> String {
        value.formatted(.number.precision(.fractionLength(fraction)).locale(locale.foundation))
    }
}

// MARK: - Les chiffres de la preuve sociale

/// **Les nombres que le parcours affiche pour dire qu'on n'est pas seul.**
///
/// Ils sont écrits ici, et ils sont **provisoires** : ce sont des ordres de grandeur posés
/// pour construire les écrans, pas des mesures. La vue serveur `social_proof_stats` les
/// remplacera ligne à ligne, avec repli sur ces valeurs hors ligne. Les rassembler dans un
/// seul type est ce qui permettra de les brancher sans rouvrir six écrans.
enum OnboardingProofFigures {
    /// La note App Store, et le nombre d'avis qui la porte.
    static let rating = 4.8
    static let reviews = 2_140

    /// Les élèves inscrits, en tout et cette semaine.
    static let students = 500_000
    static let studentsThisWeek = 1_240

    /// Les fiches écrites cette semaine.
    static let sheetsThisWeek = 12_800

    /// La progression mesurée sur un trimestre, en points de moyenne sur vingt, et le
    /// nombre d'élèves derrière le chiffre.
    static let gainedPoints = 2.4
    static let gainedSample = 1_240

    /// Combien de fois plus souvent révisent ceux qui ont activé les rappels.
    static let reminderMultiplier = 2

    /// Les élèves d'un pays. Un ordre de grandeur par marché, et le reste au plancher.
    static func students(in country: SchoolingCountry) -> Int {
        switch country {
        case .fr: 6_200
        case .tr: 3_400
        case .de: 1_900
        case .es: 900
        case .be, .ch, .ca, .ma: 600
        case .uk, .us, .it, .pt, .nl, .pl: 450
        default: 300
        }
    }
}
