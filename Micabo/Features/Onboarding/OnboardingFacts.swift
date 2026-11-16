import Foundation

// **Ce que le parcours dit de l'élève, et rien d'inventé.** Tout ce que les écrans
// affichent (l'examen et sa date, la classe, les matières, les notes dans son barème, l'heure
// du rappel, la première leçon) est tiré ici de ses réponses. Une réponse absente retire sa
// ligne : aucun écran ne remplit un vide par un exemple.

extension OnboardingModel {
    // MARK: L'examen

    /// L'examen daté choisi (un examen du pays, un contrôle, des partiels) et son jour.
    /// Rien pour « rien pour l'instant », ou sans date.
    var datedExam: (choice: ExamChoice, date: Date)? {
        guard let examChoice, examChoice.hasDate, let examDate else { return nil }
        return (examChoice, examDate)
    }

    /// Le nom de cet examen, tel qu'il se dit dans le pays de l'élève.
    func examName(locale: UiLocale) -> String? {
        datedExam?.choice.title(locale: locale)
    }

    // MARK: La classe et les matières

    /// La classe de l'élève : son année (« Terminale »), sinon sa filière, sinon son palier.
    var classLabel: String? {
        year?.title ?? track?.title ?? stage?.localizedTitle
    }

    /// Les matières cochées, dans la langue de l'app, dans un ordre qui ne change pas d'un
    /// affichage à l'autre.
    func subjectNames(locale: UiLocale) -> [String] {
        subjects.sorted().map { SubjectDisplay.subject($0, locale: locale) }
    }

    /// Sa première matière, pour l'exemple de notification.
    func firstSubjectName(locale: UiLocale) -> String? {
        subjectNames(locale: locale).first
    }

    // MARK: Les notes

    /// Une note de la droite 10-20 du produit, écrite dans le barème de l'élève. Sous le
    /// barème : « Moins de 10/20 ».
    func gradeLabel(for score: Int, locale: UiLocale) -> String {
        let scale = gradeScale.scale
        guard score >= TargetScore.min else {
            return L10n.t("ios.averageBelow", locale: locale, vars: ["grade": scale.choices.first?.label ?? ""])
        }
        return scale.label(for: score)
    }

    /// La moyenne d'aujourd'hui, dans son barème.
    func currentLabel(locale: UiLocale) -> String? {
        currentScore.map { gradeLabel(for: $0, locale: locale) }
    }

    /// La moyenne visée, dans son barème.
    func targetLabel(locale: UiLocale) -> String? {
        targetScore.map { gradeLabel(for: $0, locale: locale) }
    }

    /// Les notes qu'on peut viser : celle d'aujourd'hui (« tenir ») et toutes celles
    /// au-dessus. Jamais en dessous.
    var targetChoices: [GradeTick] {
        let floor = currentScore ?? DesiredGradeScale.belowScore
        return gradeScale.scale.choices.filter { $0.score >= floor }
    }

    /// L'écart entre les deux moyennes, quand les deux sont données.
    func gradeGap(locale: UiLocale) -> OnboardingGradeGap? {
        guard let currentScore, let targetScore else { return nil }
        return OnboardingGradeGap(
            current: currentScore,
            target: targetScore,
            scale: gradeScale,
            from: gradeLabel(for: currentScore, locale: locale),
            to: gradeLabel(for: targetScore, locale: locale),
            locale: locale
        )
    }

    // MARK: Le rappel

    /// L'heure du rappel quotidien : celle que l'élève a réglée, sinon celle que l'écran
    /// propose.
    var reminderHour: Int {
        studyHour ?? DailyReminder.defaultHour
    }

    // MARK: Le plan

    /// **Les lignes du plan qui se prépare**, dans l'ordre où elles se cochent : la classe,
    /// les matières, l'examen et son jour, le temps par jour et l'heure, la première leçon.
    /// Une information absente retire sa ligne.
    func planLines(locale: UiLocale) -> [String] {
        var lines: [String] = []
        // « Le programme de Terminale » quand on connaît l'année ; ailleurs le palier, dit
        // sans article (« Ton niveau : Université »).
        if let year {
            lines.append(L10n.t("ios.onb10.build.class", locale: locale, vars: ["class": year.title]))
        } else if let classLabel {
            lines.append(L10n.t("ios.onb10.build.level", locale: locale, vars: ["class": classLabel]))
        }
        if !subjects.isEmpty {
            lines.append(L10n.t("ios.onb10.build.subjects", locale: locale, vars: ["count": "\(subjects.count)"]))
        }
        // Lot 12 : la matière la plus dure passe en tête, et l'objectif se règle.
        if let hardestSubject {
            lines.append(L10n.t("ios.onb12.build.hardest", locale: locale, vars: [
                "subject": SubjectDisplay.subject(hardestSubject, locale: locale),
            ]))
        }
        if let target = targetLabel(locale: locale) {
            let value = currentLabel(locale: locale).map { OnbWords.range(from: $0, to: target, locale: locale) } ?? target
            lines.append(L10n.t("ios.onb12.build.goal", locale: locale, vars: ["range": value]))
        }
        if let exam = datedExam {
            lines.append(L10n.t("ios.onb10.build.exam", locale: locale, vars: [
                "exam": exam.choice.title(locale: locale),
                "date": OnbWords.day(exam.date, locale: locale),
            ]))
        }
        lines.append(L10n.t("ios.onb10.build.daily", locale: locale, vars: [
            "min": "\(minutesPerDay)",
            "hour": OnbWords.hour(reminderHour, locale: locale),
        ]))
        switch firstLessonChoice {
        case .topic:
            if let topic = firstLessonSubject {
                lines.append(L10n.t("ios.onb10.build.lesson", locale: locale, vars: ["topic": topic]))
            }
        case .importSource:
            lines.append(L10n.t("ios.onb10.build.lessonImport", locale: locale))
        case nil:
            break
        }
        return lines
    }

    /// La première leçon, telle que le plan la nomme : le sujet écrit, ou « ton cours à
    /// importer ». Rien après « Plus tard ».
    func firstLessonLine(locale: UiLocale) -> String? {
        switch firstLessonChoice {
        case .topic: firstLessonSubject
        case .importSource: L10n.t("ios.onb10.plan.lessonImport", locale: locale)
        case nil: nil
        }
    }

    /// **Les lignes du plan révélé** : un libellé et sa valeur, tirée des réponses.
    func planSummary(locale: UiLocale) -> [OnboardingPlanRow] {
        var rows: [OnboardingPlanRow] = []
        if let exam = datedExam {
            rows.append(OnboardingPlanRow(
                id: "exam",
                icon: .diploma,
                label: L10n.t("ios.onb5.plan.exam", locale: locale),
                value: "\(exam.choice.title(locale: locale)) · \(OnbWords.date(exam.date, locale: locale))"
            ))
        }
        let names = subjectNames(locale: locale)
        if !names.isEmpty {
            rows.append(OnboardingPlanRow(
                id: "subjects",
                icon: .book,
                label: L10n.t("ios.onb5.plan.subjects", locale: locale),
                value: OnbWords.list(names, locale: locale)
            ))
        }
        rows.append(OnboardingPlanRow(
            id: "daily",
            icon: .alarm,
            label: L10n.t("ios.onb5.plan.daily", locale: locale),
            value: L10n.t("ios.onb5.plan.dailyValue", locale: locale, vars: [
                "n": "\(minutesPerDay)",
                "hour": OnbWords.hour(reminderHour, locale: locale),
            ])
        ))
        if let target = targetLabel(locale: locale) {
            let value = currentLabel(locale: locale).map {
                OnbWords.range(from: $0, to: target, locale: locale)
            } ?? target
            rows.append(OnboardingPlanRow(
                id: "goal",
                icon: .trophy,
                label: L10n.t("ios.onb5.plan.goal", locale: locale),
                value: value,
                isAccent: true
            ))
        }
        if let lesson = firstLessonLine(locale: locale) {
            rows.append(OnboardingPlanRow(
                id: "lesson",
                icon: .notes,
                label: L10n.t("ios.onb10.plan.lesson", locale: locale),
                value: lesson
            ))
        }
        return rows
    }
}

/// Une ligne du plan révélé.
struct OnboardingPlanRow: Identifiable, Equatable {
    let id: String
    let icon: MicaboIcon
    let label: String
    let value: String
    /// La valeur prend l'accent (l'objectif).
    var isAccent = false
}

// MARK: - L'écart entre les deux moyennes

/// **Ce qui sépare la note d'aujourd'hui de celle qu'on vise, dit dans le barème de l'élève.**
///
/// L'écart ne se chiffre que là où il se compte : « +4 points » de 12/20 à 16/20, « +0.8 »
/// de 3.0 à 3.8, « +4 points » en Notenpunkte. Des lettres (B → A), un barème où la meilleure
/// note est la plus petite (2,7 → 1,7), ou une moyenne sous le barème : la phrase se dit sans
/// chiffre, plutôt qu'avec un chiffre faux.
struct OnboardingGradeGap: Equatable {
    enum Size: Equatable {
        /// La même note : tenir.
        case hold
        case small
        case medium
        case large
    }

    let size: Size
    /// La note d'aujourd'hui et la note visée, dans le barème de l'élève.
    let from: String
    let to: String
    /// L'écart chiffré, quand il se compte dans ce barème (« 4 », « 0,8 »).
    let amount: String?
    /// Vrai quand l'écart est un nombre entier : il prend son unité (« 4 points »).
    let isWhole: Bool

    init(current: Int, target: Int, scale: StudentGradeScale, from: String, to: String, locale: UiLocale) {
        self.from = from
        self.to = to

        // La taille se lit sur la droite 10-20 du produit, la même pour tous les barèmes.
        let steps = max(0, target - current)
        switch steps {
        case 0: size = .hold
        case ...2: size = .small
        case ...4: size = .medium
        default: size = .large
        }

        var amount: String?
        var isWhole = false
        if steps > 0, !scale.lowerIsBetter, current >= TargetScore.min,
           let low = Self.number(in: scale.scale.label(for: current)),
           let high = Self.number(in: scale.scale.label(for: target)),
           low.denominator == high.denominator, high.value > low.value {
            let difference = high.value - low.value
            isWhole = low.isWhole && high.isWhole
            if isWhole {
                amount = "\(Int(difference.rounded()))"
            } else {
                let text = String(format: "%.1f", difference)
                amount = low.usesComma || high.usesComma ? text.replacingOccurrences(of: ".", with: ",") : text
            }
        }
        self.amount = amount
        self.isWhole = isWhole
    }

    /// **La phrase de la carte** : « +4 points : ambitieux, et faisable », ou sans chiffre.
    func title(locale: UiLocale) -> String {
        if size == .hold {
            return L10n.t("ios.onb10.target.hold", locale: locale, vars: ["target": to])
        }
        guard let amount else {
            switch size {
            case .small: return L10n.t("ios.onb10.target.small.plain", locale: locale)
            case .medium: return L10n.t("ios.onb10.target.medium.plain", locale: locale)
            default: return L10n.t("ios.onb10.target.large.plain", locale: locale)
            }
        }
        // Des points entiers : la phrase accorde son unité (« +1 point », « +4 points »).
        if isWhole {
            let vars = ["count": amount]
            switch size {
            case .small: return L10n.t("ios.onb10.target.small.points", locale: locale, vars: vars)
            case .medium: return L10n.t("ios.onb10.target.medium.points", locale: locale, vars: vars)
            default: return L10n.t("ios.onb10.target.large.points", locale: locale, vars: vars)
            }
        }
        let vars = ["gap": amount]
        switch size {
        case .small: return L10n.t("ios.onb10.target.small", locale: locale, vars: vars)
        case .medium: return L10n.t("ios.onb10.target.medium", locale: locale, vars: vars)
        default: return L10n.t("ios.onb10.target.large", locale: locale, vars: vars)
        }
    }

    /// « 12/20 → 16/20 d'ici le 15 juin », ou sans date.
    func line(until date: Date?, locale: UiLocale) -> String {
        guard let date else {
            return OnbWords.range(from: from, to: to, locale: locale)
        }
        return L10n.t("ios.onb10.target.line", locale: locale, vars: [
            // La plage entière : de droite à gauche, elle s'écrit en un bloc (`OnbWords.range`).
            "range": OnbWords.range(from: from, to: to, locale: locale),
            "date": OnbWords.day(date, locale: locale),
        ])
    }

    // MARK: Lire une note

    struct Number: Equatable {
        let value: Double
        /// Le dénominateur écrit dans la note (« /20 », « /10 »), quand il y en a un.
        let denominator: String?
        let isWhole: Bool
        let usesComma: Bool
    }

    /// Le nombre d'une note, quand elle en est un : « 12/20 », « 3.7 », « 2,7 », « 08 »,
    /// « 60 % ». Une lettre, « 2:1 » ou « 30L » n'en sont pas.
    static func number(in label: String) -> Number? {
        var text = label
        for sign in ["%", "٪", "\u{00A0}", "\u{202F}", " "] {
            text = text.replacingOccurrences(of: sign, with: "")
        }
        var denominator: String?
        if let slash = text.firstIndex(of: "/") {
            denominator = String(text[text.index(after: slash)...])
            text = String(text[..<slash])
        }
        guard !text.isEmpty else { return nil }
        var digits = ""
        var usesComma = false
        var separators = 0
        for character in text {
            if let digit = character.wholeNumberValue, character.isNumber {
                digits.append(String(digit))
            } else if character == "," || character == "." || character == "٫" {
                usesComma = usesComma || character != "."
                separators += 1
                digits.append(".")
            } else {
                return nil
            }
        }
        guard separators <= 1, let value = Double(digits) else { return nil }
        return Number(value: value, denominator: denominator, isWhole: separators == 0, usesComma: usesComma)
    }
}
