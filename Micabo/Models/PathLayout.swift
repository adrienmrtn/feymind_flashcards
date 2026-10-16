import Foundation

/// **Le chemin d'une leçon, toujours construit de la même façon.**
///
/// Intro, une étape Notes par thème, un **Checkpoint** après chaque palier de thèmes (sauf le
/// dernier), puis le **Quiz final**, qui reprend toute la leçon et la conclut. Les paliers font
/// 2 thèmes, ou 3 quand la leçon en a plus de 8. Les flashcards se révisent depuis la barre du
/// bas, à leur rythme : elles ne bloquent pas le chemin. Voir `docs/refonte-parcours.md` § 5.1.
///
/// | Thèmes | Paliers | Étapes |
/// | --- | --- | --- |
/// | 4 | 2 · 2 | 7 |
/// | 5 | 2 · 3 | 8 |
/// | 6 | 2 · 2 · 2 | 10 |
/// | 10 | 3 · 3 · 2 · 2 | 15 |
/// | 12 | 3 · 3 · 3 · 3 | 17 |
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

    /// Le chemin complet, dans l'ordre.
    ///
    /// `groupNames` vient du plan : le nom de chaque palier, repris sous son Checkpoint.
    static func steps(
        themes: [PathTheme],
        groupNames: [String] = [],
        singleQuiz: Bool = false
    ) -> [PathStep] {
        guard !themes.isEmpty else { return [] }
        var steps: [PathStep] = []
        var number = 0
        func add(_ circle: PathCircle.Kind, title: String, icon: MicaboIcon, symbol: String, subtitle: String? = nil) {
            number += 1
            steps.append(.circle(PathCircle(kind: circle, number: number, title: title, icon: icon, symbol: symbol, subtitle: subtitle)))
        }

        add(.intro, title: L10n.t("lesson.circle.intro", locale: .resolved()), icon: .star, symbol: "sparkles")
        let groups = groups(themeCount: themes.count, singleQuiz: singleQuiz)
        for (index, group) in groups.enumerated() {
            for theme in group {
                add(.notes(theme: theme), title: themes[theme].title, icon: themes[theme].icon, symbol: themes[theme].symbol)
            }
            if index < groups.count - 1 {
                let name = groupNames.indices.contains(index) ? groupNames[index].nilIfBlank : nil
                add(
                    .quiz(group: index, themes: group),
                    title: L10n.t("lesson.circle.checkpoint", locale: .resolved()),
                    icon: .quiz,
                    symbol: "rosette",
                    subtitle: name
                )
            }
        }
        add(
            .final(themes: Array(themes.indices)),
            title: L10n.t("lesson.circle.final", locale: .resolved()),
            icon: .trophy,
            symbol: "trophy"
        )
        return steps
    }

    /// **Une progression d'avant le Quiz final**, relue sans rien perdre : la Conclusion ou
    /// le quiz du dernier palier valaient la fin de la leçon.
    static func migrated(done: Set<String>, circles: [PathCircle], finished: Bool) -> Set<String> {
        var out = done
        guard let final = circles.last, case .final = final.kind else { return out }
        let lastGroupQuiz = "quiz:\(max(0, circles.filter { if case .quiz = $0.kind { return true } else { return false } }.count))"
        if finished || done.contains("conclusion") || done.contains(lastGroupQuiz) {
            out.insert(final.id)
        }
        return out
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
    /// Son pictogramme sur le chemin (`PathSymbol`).
    var symbol: String = PathSymbol.fallback
}

/// Une ligne du chemin : une étape.
enum PathStep: Equatable, Identifiable {
    case circle(PathCircle)

    var id: String {
        switch self {
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
        /// Le Checkpoint d'un palier, et les thèmes qu'il couvre.
        case quiz(group: Int, themes: [Int])
        /// Le Quiz final : toute la leçon, puis « À retenir ».
        case final(themes: [Int])
    }

    enum State: Equatable {
        case done
        case current
        case upcoming
    }

    let kind: Kind
    /// « ÉTAPE 4 » : le rang sur le chemin, à partir de 1.
    let number: Int
    let title: String
    /// L'icône 3D, pour l'en-tête de l'étape ouverte.
    let icon: MicaboIcon
    /// Le pictogramme du rond, sur le chemin.
    var symbol: String = PathSymbol.fallback
    /// Sous le titre : le palier qu'un Checkpoint conclut.
    var subtitle: String?

    /// Stable d'une version à l'autre : c'est la clé de la progression enregistrée.
    var id: String {
        switch kind {
        case .intro: "intro"
        case .notes(let theme): "notes:\(theme)"
        case .quiz(let group, _): "quiz:\(group)"
        case .final: "final"
        }
    }

    /// Un Checkpoint ou le Quiz final : un palier franchi, qui se fête.
    var isMilestone: Bool {
        switch kind {
        case .quiz, .final: true
        case .intro, .notes: false
        }
    }

    /// L'activité que ce cercle compte dans « X h de révision ».
    var activity: LessonActivity? {
        switch kind {
        case .notes: .notes
        case .quiz, .final: .quiz
        case .intro: nil
        }
    }
}
