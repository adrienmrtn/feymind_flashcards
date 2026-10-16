import Foundation

/// **Le chemin d'une leçon, toujours construit de la même façon.**
///
/// Intro, un cercle Notes par thème, un cercle Quiz après chaque groupe de thèmes, un cercle
/// Flashcards, la Conclusion. Les groupes font 2 thèmes, ou 3 quand la leçon en a plus de 8 ;
/// un quiz ne couvre jamais plus de 3 thèmes. Voir `docs/refonte-parcours.md` § 5.1.
///
/// | Thèmes | Groupes | Cercles |
/// | --- | --- | --- |
/// | 4 | 2 · 2 | 9 |
/// | 5 | 2 · 3 | 10 |
/// | 6 | 2 · 2 · 2 | 12 |
/// | 10 | 3 · 3 · 2 · 2 | 17 |
/// | 12 | 3 · 3 · 3 · 3 | 19 |
///
/// Une fonction pure, sans SwiftData : l'écran, l'app et les tests calculent le même chemin.
enum PathLayout {
    /// La taille des groupes : 2 thèmes, ou 3 au-delà de 8.
    static func groupSize(themeCount: Int) -> Int {
        themeCount > 8 ? 3 : 2
    }

    /// Le découpage des thèmes en groupes, chaque groupe donnant les rangs de ses thèmes.
    ///
    /// Le compte ne tombe pas toujours juste : avec des groupes de 2, le dernier prend le
    /// thème en trop (5 → 2 · 3) ; avec des groupes de 3, un reste de 1 coupe les quatre
    /// derniers en 2 · 2 (10 → 3 · 3 · 2 · 2) et un reste de 2 fait un dernier groupe de 2.
    /// Une leçon très courte n'a qu'un groupe : un seul quiz pour tout.
    static func groups(themeCount: Int, singleQuiz: Bool = false) -> [[Int]] {
        guard themeCount > 0 else { return [] }
        if singleQuiz { return [Array(0..<themeCount)] }
        let size = groupSize(themeCount: themeCount)
        var sizes: [Int] = Array(repeating: size, count: themeCount / size)
        let rest = themeCount % size
        if size == 2 {
            if rest == 1 {
                if sizes.isEmpty { sizes = [1] } else { sizes[sizes.count - 1] += 1 }
            }
        } else {
            switch rest {
            case 1:
                if sizes.isEmpty {
                    sizes = [1]
                } else {
                    sizes.removeLast()
                    sizes += [2, 2]
                }
            case 2:
                sizes.append(2)
            default:
                break
            }
        }
        var start = 0
        return sizes.map { count in
            defer { start += count }
            return Array(start..<(start + count))
        }
    }

    /// Le chemin complet, dans l'ordre, avec les en-têtes de palier.
    ///
    /// `groupNames` vient du plan : le nom de chaque groupe, dans l'ordre. Un nom manquant
    /// (plan d'avant, groupe que le modèle n'a pas nommé) laisse l'en-tête sans nom.
    static func steps(
        themes: [PathTheme],
        groupNames: [String] = [],
        singleQuiz: Bool = false
    ) -> [PathStep] {
        guard !themes.isEmpty else { return [] }
        var steps: [PathStep] = []
        var number = 0
        func add(_ circle: PathCircle.Kind, title: String, icon: MicaboIcon) {
            number += 1
            steps.append(.circle(PathCircle(kind: circle, number: number, title: title, icon: icon)))
        }

        add(.intro, title: L10n.t("lesson.circle.intro", locale: .resolved()), icon: .star)
        for (index, group) in groups(themeCount: themes.count, singleQuiz: singleQuiz).enumerated() {
            let name = groupNames.indices.contains(index) ? groupNames[index] : ""
            steps.append(.palier(number: index + 1, name: name))
            for theme in group {
                add(.notes(theme: theme), title: themes[theme].title, icon: themes[theme].icon)
            }
            add(.quiz(group: index, themes: group), title: L10n.t("lesson.circle.quiz", locale: .resolved()), icon: .quiz)
        }
        add(.flashcards, title: L10n.t("lesson.circle.flashcards", locale: .resolved()), icon: .cards)
        add(.conclusion, title: L10n.t("lesson.circle.conclusion", locale: .resolved()), icon: .trophy)
        return steps
    }

    /// Les seuls cercles, sans les en-têtes.
    static func circles(themes: [PathTheme], groupNames: [String] = [], singleQuiz: Bool = false) -> [PathCircle] {
        steps(themes: themes, groupNames: groupNames, singleQuiz: singleQuiz).compactMap(\.circle)
    }

    /// Le cercle en cours : le premier qui n'est pas coché. `nil` quand tout est fait.
    static func current(in circles: [PathCircle], done: Set<String>) -> PathCircle? {
        circles.first { !done.contains($0.id) }
    }

    /// L'état d'un cercle sur le chemin. On ne saute pas : tout ce qui suit le cercle en
    /// cours est à venir.
    static func state(of circle: PathCircle, in circles: [PathCircle], done: Set<String>) -> PathCircle.State {
        if done.contains(circle.id) { return .done }
        if current(in: circles, done: done)?.id == circle.id { return .current }
        return .upcoming
    }
}

/// Ce que le chemin a besoin de savoir d'un thème.
struct PathTheme: Equatable {
    var title: String
    var icon: MicaboIcon
}

/// Une ligne du chemin : un cercle, ou l'en-tête d'un palier.
enum PathStep: Equatable, Identifiable {
    case palier(number: Int, name: String)
    case circle(PathCircle)

    var id: String {
        switch self {
        case .palier(let number, _): "palier:\(number)"
        case .circle(let circle): circle.id
        }
    }

    var circle: PathCircle? {
        if case .circle(let circle) = self { return circle }
        return nil
    }
}

/// **Un cercle du chemin.**
struct PathCircle: Equatable, Identifiable {
    enum Kind: Equatable {
        case intro
        /// Les notes d'un thème, par son rang.
        case notes(theme: Int)
        /// Le quiz d'un groupe, et les thèmes qu'il couvre.
        case quiz(group: Int, themes: [Int])
        case flashcards
        case conclusion
    }

    enum State: Equatable {
        case done
        case current
        case upcoming
    }

    let kind: Kind
    /// « CERCLE 4 » : le rang sur le chemin, à partir de 1.
    let number: Int
    let title: String
    let icon: MicaboIcon

    /// Stable d'une version à l'autre : c'est la clé de la progression enregistrée.
    var id: String {
        switch kind {
        case .intro: "intro"
        case .notes(let theme): "notes:\(theme)"
        case .quiz(let group, _): "quiz:\(group)"
        case .flashcards: "flashcards"
        case .conclusion: "conclusion"
        }
    }

    /// L'activité que ce cercle compte dans « X h de révision ».
    var activity: LessonActivity? {
        switch kind {
        case .notes: .notes
        case .quiz: .quiz
        case .flashcards: .flashcards
        case .intro, .conclusion: nil
        }
    }
}
