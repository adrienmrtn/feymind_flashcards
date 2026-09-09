import Foundation

/// **Ce qui voyage entre le doigt et le dossier.**
///
/// Un identifiant nu ne se distingue pas d'une chaîne quelconque. Le lâcher acceptait donc
/// n'importe quel texte, essayait d'en faire un `UUID`, échouait, et rendait `false` sans que
/// rien ne le dise : le cours restait à sa place, le dossier s'ouvrait sous le doigt - un
/// lâcher sur un bouton l'appuie - et de l'extérieur les deux avaient disparu de la liste.
///
/// Le préfixe règle la moitié du problème : ce qui n'est pas de nous n'entre pas. L'autre
/// moitié est traitée dans `CoursesListView`, où une rangée qui vient de recevoir un dépôt
/// n'accepte pas l'appui qui suit.
enum CourseDrag {
    private static let prefix = "micabo.course:"

    static func payload(for course: Course) -> String {
        "\(prefix)\(course.id.uuidString)"
    }

    /// L'identifiant transporté, ou `nil` quand ce texte ne vient pas d'une rangée de Micabo.
    ///
    /// La forme nue reste acceptée : un appareil peut porter une version antérieure de l'app
    /// dans son presse-papiers de glisser, et refuser un dépôt qui marchait hier serait une
    /// régression pour rien.
    static func identifier(in raw: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix(prefix) {
            return UUID(uuidString: String(trimmed.dropFirst(prefix.count)))
        }
        return UUID(uuidString: trimmed)
    }
}
