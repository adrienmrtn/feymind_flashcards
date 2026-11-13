import Foundation

/// **Un cours vu comme une leçon** : son plan, sa progression, sa couleur, son icône.
///
/// Les données vivent dans les champs de `Course` et `Chapter` (JSON pour ce qui se lit d'un
/// bloc) ; cette extension les rend lisibles. Le décodage n'est pas gratuit : un écran lit le
/// plan et la progression une fois et les garde, il ne les appelle pas depuis un corps de vue.
extension Course {
    /// Vrai dès que le cours a un parcours. Un ancien cours ne l'a pas avant sa conversion.
    var isLesson: Bool { pathData?.isEmpty == false }

    var lessonPath: LessonPath? { LessonPath.decode(from: pathData) }

    func setLessonPath(_ path: LessonPath?) {
        pathData = path?.encoded()
        updatedAt = Date()
    }

    var progress: LessonProgress { LessonProgress.decode(from: progressData) }

    /// Modifie la progression et date le cours, pour qu'elle parte à la prochaine synchro.
    func updateProgress(_ change: (inout LessonProgress) -> Void) {
        var progress = self.progress
        change(&progress)
        progressData = progress.encoded()
        updatedAt = Date()
    }

    /// **La couleur de la leçon : celle de sa matière** (lot 7). Toutes les leçons de maths
    /// sont bleues, toutes celles d'histoire jaunes : la liste se lit d'un coup d'œil. Une
    /// matière que l'app ne reconnaît pas garde le ton reçu à la création ; un ancien cours en
    /// reçoit un stable, tiré de son identifiant.
    var tone: LessonTone {
        if let subjectIcon = MicaboIcon.subjectIcon(subject) { return LessonTone.forSubject(subjectIcon) }
        return toneRaw.isEmpty ? LessonTone.stable(for: id) : LessonTone(raw: toneRaw)
    }

    /// **L'icône de la leçon : celle de sa matière** (lot 7), sinon celle que le modèle a
    /// choisie, sinon une déduite du titre. Le modèle donnait le globe à presque tout ce qui
    /// parlait « du monde » : une liste de leçons portait le même globe partout.
    var icon: MicaboIcon {
        if let subjectIcon = MicaboIcon.subjectIcon(subject) { return subjectIcon }
        return iconID.isEmpty ? MicaboIcon.guess(subject: subject, title: title) : MicaboIcon(id: iconID)
    }

    /// Les thèmes, dans l'ordre du chemin, chacun avec son pictogramme : celui du plan, sinon
    /// celui qui va avec son icône 3D. Jamais deux fois le même.
    func pathThemes(plan: LessonPath? = nil) -> [PathTheme] {
        let chapters = orderedChapters
        let planned = (plan ?? lessonPath)?.symbols ?? []
        let wanted = chapters.enumerated().map { index, chapter in
            planned.indices.contains(index) && !planned[index].isEmpty ? planned[index] : PathSymbol.forIcon(chapter.iconID)
        }
        let symbols = PathSymbol.unique(wanted)
        return chapters.enumerated().map { index, chapter in
            PathTheme(title: chapter.title, icon: chapter.icon, symbol: symbols[index])
        }
    }

    /// Le chemin, étape par étape. Vide sans plan.
    func pathSteps(plan: LessonPath? = nil) -> [PathStep] {
        guard let plan = plan ?? lessonPath else { return [] }
        return PathLayout.steps(
            themes: pathThemes(plan: plan),
            groupNames: plan.groups.map(\.name),
            singleQuiz: plan.singleQuiz
        )
    }

    /// Vrai quand la leçon est arrivée à « Leçon terminée ».
    var isLearned: Bool { progress.finishedAt != nil }

    /// Les flashcards apprises : celles dont le prochain rappel est à plus de sept jours.
    func learnedCardCount(now: Date = Date()) -> Int {
        let horizon = now.addingTimeInterval(7 * 24 * 3600)
        var count = 0
        for card in cards where !card.isSuspended && card.state != .new && card.dueDate > horizon {
            count += 1
        }
        return count
    }
}

extension Chapter {
    var icon: MicaboIcon { MicaboIcon(id: iconID.isEmpty ? nil : iconID) }

    var notes: ThemeNotes? { ThemeNotes.decode(from: notesData) }

    func setNotes(_ notes: ThemeNotes?) {
        notesData = notes?.encoded()
        updatedAt = Date()
    }

    var quiz: ThemeQuiz? { ThemeQuiz.decode(from: quizData) }

    func setQuiz(_ quiz: ThemeQuiz?) {
        quizData = quiz?.encoded()
        updatedAt = Date()
    }

    var status: ThemeStatus {
        get { ThemeStatus(rawValue: statusRaw) ?? .ready }
        set {
            statusRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    /// Le texte du thème à plat : ses notes au nouveau format, sinon sa fiche.
    var plainText: String {
        if let notes { return notes.plainText }
        return decodedSheet()?.plainText() ?? ""
    }
}

extension MicaboIcon {
    /// **L'icône d'une leçon qui n'en a pas reçu**, déduite de sa matière ou de son titre :
    /// globe pour la géographie, fiole pour la chimie, parchemin pour l'histoire, calculatrice
    /// pour les maths, atome pour la physique, livre sinon. Les mots-clés couvrent les cinq
    /// langues de l'app, sans accents.
    static func guess(subject: String?, title: String) -> MicaboIcon {
        let source = (subject ?? "") + " " + title
        return guessed.value(for: source) {
            let text = source.lowercased().folding(options: .diacriticInsensitive, locale: nil)
            for (icon, keys) in subjectKeywords where keys.contains(where: text.contains) {
                return icon
            }
            return .book
        }
    }

    /// **L'icône d'une matière**, lue dans le nom de la matière seul (pas dans le titre), ou
    /// `nil` quand la matière n'est pas reconnue. C'est elle qui donne à une leçon son icône et
    /// sa couleur (`Course.icon`, `Course.tone`) : deux leçons de maths se ressemblent.
    static func subjectIcon(_ subject: String?) -> MicaboIcon? {
        guard let subject, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return subjectIcons.value(for: subject) {
            let text = folded(subject)
            // Les mots-clés passent par le même pliage que le texte : un hamza arabe ou un « й »
            // russe plié d'un côté et pas de l'autre ne se retrouveraient plus.
            let matches: (String) -> Bool = { text.contains($0) }
            for (icon, keys) in foldedSubjectKeywords where keys.contains(where: matches) {
                return icon
            }
            return foldedLanguageKeywords.contains(where: matches) ? .book : nil
        }
    }

    private static func folded(_ text: String) -> String {
        text.lowercased().folding(options: .diacriticInsensitive, locale: nil)
    }

    /// **L'icône d'une matière ne se recherche qu'une fois par nom.** `Course.icon` et
    /// `Course.tone` passent ici à chaque passe de chaque rangée : plier le nom puis cent
    /// vingt mots-clés, à chaque fois, coûtait plus que dessiner la rangée. Les mots-clés sont
    /// pliés une fois (`foldedSubjectKeywords`), et la réponse est gardée par nom de matière
    /// (`MemoCache`) : un élève en a une dizaine.
    private static let subjectIcons = MemoCache<String, MicaboIcon?>(limit: 512)
    private static let guessed = MemoCache<String, MicaboIcon>(limit: 512)

    private static let foldedSubjectKeywords: [(MicaboIcon, [String])] = subjectKeywords.map { icon, keys in
        (icon, keys.map { folded($0) })
    }

    private static let foldedLanguageKeywords: [String] = languageKeywords.map { folded($0) }

    /// Dans l'ordre : la première matière reconnue gagne. Les maths passent avant la physique
    /// (« physique mathématique » reste des maths), la chimie avant la biologie, l'histoire
    /// avant la géographie (« Histoire-géographie » prend le parchemin). Les mots-clés couvrent
    /// les langues de l'app les plus parlées, sans accents.
    private static let subjectKeywords: [(MicaboIcon, [String])] = [
        (.calculator, ["math", "algebr", "geometr", "statisti", "calcul", "matemat", "probabil", "wiskunde", "matma", "математ", "رياضيات"]),
        (.atom, ["physi", "fizik", "fisica", "fysik", "fyzik", "fizyk", "natuurkunde", "mecaniq", "electric", "optique", "quantum", "физик", "فيزياء"]),
        (.flask, ["chimi", "chemi", "kimya", "quimic", "kemi", "biolog", "svt", "biyoloji", "life science", "scienze naturali", "ciencias naturales", "хими", "биолог", "كيمياء", "أحياء", "احياء", "علوم"]),
        (.scroll, ["histoir", "history", "histori", "tarih", "geschicht", "storia", "dejepis", "droit", "law", "recht", "derecho", "diritto", "истори", "تاريخ"]),
        (.globe, ["geograph", "geografi", "cografya", "erdkunde", "aardrijkskunde", "maantieto", "environnement", "climat", "географ", "جغرافيا"]),
        (.brain, ["philo", "psycho", "socio", "neuro", "filosof", "felsefe", "ethik", "ethique", "философ", "فلسفة"]),
        (.palette, ["arts", "dessin", "design", "musique", "music", "muzik", "musik", "musica", "kunst"]),
        (.quill, ["litter", "literat", "francais", "french", "edebiyat", "poesie", "lettres", "deutsch", "turkce", "lengua castellana", "عربية"]),
        (.diploma, ["econom", "finance", "gestion", "ekonomi", "wirtschaft"]),
        (.rocket, ["informati", "computer", "program", "bilgisayar", "numerique"]),
    ]

    /// Les langues étrangères : le livre, comme la lecture. Seulement pour une matière : dans
    /// un titre, « anglais » ne dit rien du sujet de la leçon.
    private static let languageKeywords = [
        "anglais", "english", "englisch", "ingles", "inglese", "engels", "ingilizce",
        "espagnol", "spanish", "spanisch", "espanol", "spagnolo",
        "allemand", "german", "aleman", "tedesco", "almanca",
        "italien", "italian", "italiano", "latin", "latein", "grec", "greek",
        "langue", "language", "sprache", "idioma", "lingua", "langues vivantes",
        "английск", "إنجليزية", "انجليزية", "فرنسية",
    ]
}

extension LessonTone {
    /// **La couleur d'une matière**, tirée de son icône : des teintes douces qui se répondent
    /// (bleu pour les maths et l'informatique, lilas pour la physique et la philosophie, menthe
    /// pour le vivant et la Terre, jaune pour l'histoire et l'économie, rose pour les lettres,
    /// les langues et les arts).
    static func forSubject(_ icon: MicaboIcon) -> LessonTone {
        switch icon {
        case .calculator, .rocket: .blue
        case .atom, .brain: .lilac
        case .flask, .globe: .mint
        case .scroll, .diploma: .yellow
        case .quill, .book, .palette: .pink
        default: .blue
        }
    }
}
