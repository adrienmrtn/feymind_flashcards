import Foundation

/// Le surligneur de la fiche, garanti par le code.
///
/// Le prompt réclame six à huit passages surlignés depuis plusieurs versions, et les fiches
/// arrivaient quand même sans une seule marque : une consigne de mise en forme est la
/// première chose qu'un modèle lâche quand il se concentre sur le contenu. Le surligneur est
/// donc passé de son côté à celui-ci, où il ne dépend plus de la bonne volonté du modèle. La
/// fonction jumelle vit dans `supabase/functions/_shared/sheet.ts`, comme les autres
/// garde-fous de la fiche : celle du serveur marque ce qui s'enregistre, celle-ci rattrape
/// les fiches déjà en base et les imports faits avant la mise à jour des fonctions.
///
/// Une fiche qui porte déjà ses marques n'est jamais touchée : ce code ne sait pas repérer ce
/// qui compte dans un cours, il sait seulement qu'une fiche sans marque ne se relit pas.
enum SheetHighlighter {
    /// Plancher garanti. Quatre marques, pas huit : ce que le code choisit vaut moins que ce
    /// que le modèle choisit, et une fiche entièrement jaune ne se relit pas mieux qu'une
    /// fiche nue.
    static let minimumHighlights = 4

    /// Un surlignage plus court n'est plus une phrase, plus long n'est plus une marque.
    private static let minimumLength = 40
    private static let maximumLength = 170

    /// Rend la fiche avec ses passages surlignés, en n'ajoutant que ce qui manque.
    static func ensuring(_ blocks: [SheetBlock], minimum: Int = minimumHighlights) -> [SheetBlock] {
        var result = blocks
        var total = blocks.reduce(0) { $0 + highlightCount(in: $1) }
        guard total < minimum else { return result }

        for index in candidateOrder(of: blocks) {
            guard total < minimum else { break }
            guard let marked = marking(result[index]) else { continue }
            result[index] = marked
            total += 1
        }

        return result
    }

    /// Enveloppe d'un `==` le passage du texte qui mérite le marqueur, ou rend `nil`.
    ///
    /// On cherche une phrase, pas un texte entier : un surlignage doit se lire d'un coup
    /// d'œil. La phrase qui porte un terme en gras passe devant, parce que c'est là que le
    /// modèle a déjà placé ce qui compte. Une phrase trop longue est ramenée à sa première
    /// proposition, coupée sur une virgule ou un deux-points, exactement là où on relèverait
    /// le marqueur à la main.
    static func marked(_ text: String) -> String? {
        guard !text.contains("==") else { return nil }

        let characters = Array(text)
        var choice: Range<Int>?

        for sentence in sentenceRanges(characters) {
            guard sentence.count >= minimumLength else { continue }
            // Une formule est déjà mise en valeur par son rendu : la surligner ferait double.
            guard !characters[sentence].contains("$") else { continue }
            guard let passage = clause(in: characters, sentence: sentence) else { continue }

            if choice == nil { choice = passage }
            if containsBold(characters[passage]) {
                choice = passage
                break
            }
        }

        guard let choice else { return nil }
        return String(characters[..<choice.lowerBound])
            + "==" + String(characters[choice]) + "=="
            + String(characters[choice.upperBound...])
    }

    // MARK: - Choix des blocs

    /// L'ordre dans lequel les blocs se voient proposer le marqueur.
    ///
    /// Il suit celui dans lequel un étudiant les chercherait : ce que l'encadré « essentiel »
    /// retient, l'enjeu posé par le premier paragraphe, ce qui distingue une définition de sa
    /// voisine, puis le reste. Les titres, les tableaux, les graphes et les formules
    /// n'apparaissent pas : ils portent déjà leur mise en valeur.
    private static func candidateOrder(of blocks: [SheetBlock]) -> [Int] {
        var essentials: [Int] = []
        var firstParagraph: [Int] = []
        var definitions: [Int] = []
        var others: [Int] = []

        for (index, block) in blocks.enumerated() {
            switch block {
            case .callout(let tone, _):
                if tone == .essentiel { essentials.append(index) } else { others.append(index) }
            case .paragraph:
                if firstParagraph.isEmpty { firstParagraph.append(index) } else { others.append(index) }
            case .definition:
                definitions.append(index)
            default:
                break
            }
        }

        return essentials + firstParagraph + definitions + others
    }

    private static func marking(_ block: SheetBlock) -> SheetBlock? {
        switch block {
        case .paragraph(let text):
            return marked(text).map { SheetBlock.paragraph(text: $0) }
        case .callout(let tone, let text):
            return marked(text).map { SheetBlock.callout(tone: tone, text: $0) }
        case .definition(let term, let text):
            return marked(text).map { SheetBlock.definition(term: term, text: $0) }
        default:
            return nil
        }
    }

    /// Un délimiteur seul ne compte pas : il faut une ouverture et une fermeture pour qu'un
    /// passage soit surligné à l'écran.
    private static func highlightCount(in block: SheetBlock) -> Int {
        markupTexts(of: block).reduce(0) { total, text in
            total + (text.components(separatedBy: "==").count - 1) / 2
        }
    }

    /// Les textes du bloc **avec** leur balisage. `plainLines()` ne peut pas servir ici :
    /// c'est justement lui qui retire les marques qu'on vient compter.
    private static func markupTexts(of block: SheetBlock) -> [String] {
        switch block {
        case .heading(_, let text), .paragraph(let text), .callout(_, let text):
            return [text]
        case .definition(let term, let text):
            return [term, text]
        case .steps(let title, let items):
            return (title.map { [$0] } ?? []) + items
        case .table(let table):
            return [table.title, table.caption].compactMap { $0 } + table.headers + table.rows.flatMap { $0 }
        case .chart(let chart):
            return [chart.title, chart.caption].compactMap { $0 } + chart.bars.map(\.label)
        case .formula(_, let caption):
            return caption.map { [$0] } ?? []
        }
    }

    // MARK: - Découpage du texte

    /// Bornes de chaque phrase du texte, ponctuation finale comprise.
    ///
    /// Un point suivi d'autre chose qu'une espace n'est pas une fin de phrase : c'est une
    /// décimale ou une abréviation, et « 0.05 » ne se coupe pas en deux.
    private static func sentenceRanges(_ characters: [Character]) -> [Range<Int>] {
        var ranges: [Range<Int>] = []
        var start = 0

        for index in characters.indices where ".!?".contains(characters[index]) {
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            guard next == nil || next == " " else { continue }
            guard start <= index else { continue }
            ranges.append(start..<(index + 1))
            start = index + 2
        }

        if start < characters.count { ranges.append(start..<characters.count) }
        return ranges
    }

    /// Le morceau de phrase à marquer : la phrase sans sa ponctuation finale, ou sa première
    /// proposition quand elle est trop longue.
    private static func clause(in characters: [Character], sentence: Range<Int>) -> Range<Int>? {
        let trailing = Set(" .!?,;:")
        var end = sentence.upperBound
        while end > sentence.lowerBound, trailing.contains(characters[end - 1]) { end -= 1 }

        var start = sentence.lowerBound
        while start < end, characters[start] == " " { start += 1 }

        let length = end - start
        guard length >= minimumLength else { return nil }
        if length <= maximumLength { return start..<end }

        var cut: Int?
        for index in start..<min(start + maximumLength, end) where ",;:".contains(characters[index]) {
            cut = index
        }
        guard let cut, cut - start >= minimumLength else { return nil }
        return start..<cut
    }

    private static func containsBold(_ characters: ArraySlice<Character>) -> Bool {
        var previous: Character?
        for character in characters {
            if character == "*", previous == "*" { return true }
            previous = character
        }
        return false
    }
}

extension CourseSheet {
    /// La fiche avec son surligneur garanti. Appliquée à la lecture, elle rattrape les
    /// fiches enregistrées avant que le surligneur passe côté code.
    func highlighted() -> CourseSheet {
        CourseSheet(blocks: SheetHighlighter.ensuring(blocks))
    }
}
