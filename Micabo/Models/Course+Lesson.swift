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

    /// La couleur de la leçon. Un ancien cours en reçoit une stable, tirée de son identifiant.
    var tone: LessonTone {
        toneRaw.isEmpty ? LessonTone.stable(for: id) : LessonTone(raw: toneRaw)
    }

    /// L'icône de la leçon : celle que le modèle a choisie, sinon celle de sa matière.
    var icon: MicaboIcon {
        iconID.isEmpty ? MicaboIcon.guess(subject: subject, title: title) : MicaboIcon(id: iconID)
    }

    /// Les thèmes, dans l'ordre du chemin.
    var pathThemes: [PathTheme] {
        orderedChapters.map { PathTheme(title: $0.title, icon: $0.icon) }
    }

    /// Le chemin, cercle par cercle, avec les en-têtes de palier. Vide sans plan.
    func pathSteps(plan: LessonPath? = nil) -> [PathStep] {
        guard let plan = plan ?? lessonPath else { return [] }
        return PathLayout.steps(
            themes: pathThemes,
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
        let text = ((subject ?? "") + " " + title).lowercased()
            .folding(options: .diacriticInsensitive, locale: nil)
        for (icon, keys) in subjectKeywords where keys.contains(where: text.contains) {
            return icon
        }
        return .book
    }

    /// Dans l'ordre : la première matière reconnue gagne. Les maths passent avant la physique
    /// (« physique mathématique » reste des maths), la chimie avant la biologie.
    private static let subjectKeywords: [(MicaboIcon, [String])] = [
        (.calculator, ["math", "algebr", "geometr", "statisti", "calcul", "matemat", "probabil"]),
        (.atom, ["physi", "fizik", "fisica", "mecaniq", "electric", "optique", "quantum"]),
        (.flask, ["chimi", "chemi", "kimya", "quimic", "biolog", "svt", "biyoloji", "life science"]),
        (.globe, ["geograph", "geografi", "cografya", "erdkunde", "environnement", "climat"]),
        (.scroll, ["histoir", "history", "histori", "tarih", "geschicht", "droit", "law", "recht"]),
        (.brain, ["philo", "psycho", "socio", "neuro"]),
        (.palette, ["arts", "dessin", "design", "musique", "music", "muzik"]),
        (.quill, ["litter", "literat", "francais", "french", "edebiyat", "poesie", "lettres"]),
        (.diploma, ["econom", "finance", "gestion", "ekonomi", "wirtschaft"]),
        (.rocket, ["informati", "computer", "program", "bilgisayar"]),
    ]
}
