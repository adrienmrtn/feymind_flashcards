import SwiftUI

extension MicaboRow {
    /// Rangée d'un cours : vignette, titre, matière et nombre de cartes, état à droite.
    ///
    /// Les totaux viennent du recensement, pas de `course.cards` : faulter la relation
    /// sur chaque rangée ouvrait une requête par cours pendant le rendu.
    static func course(
        _ course: Course,
        stats: CourseStats? = nil,
        action: (() -> Void)? = nil
    ) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile.course(course),
            title: course.title,
            subtitle: CourseRowLabels.meta(for: course, stats: stats),
            accessory: CourseRowLabels.accessory(stats: stats),
            action: action
        )
    }

    /// Rangée d'un cours qui a des cartes à réviser aujourd'hui.
    static func courseDue(_ course: Course, dueCount: Int, action: (() -> Void)? = nil) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile.course(course),
            title: course.title,
            subtitle: course.subject?.nilIfBlank,
            accessory: .badge("\(dueCount) à réviser", .accent),
            action: action
        )
    }
}

/// Ce qu'une rangée de cours raconte : la matière, le volume, et l'état de la file.
enum CourseRowLabels {
    static func meta(for course: Course, stats: CourseStats?) -> String {
        var parts: [String] = []
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        if let stats { parts.append(MicaboCopy.cards(stats.cardCount)) }
        parts.append(MicaboCopy.audience(of: course))
        return parts.joined(separator: " · ")
    }

    static func accessory(stats: CourseStats?) -> MicaboRowAccessory {
        guard let stats else { return .chevron }
        if stats.dueCount > 0 {
            return .badge("\(stats.dueCount) à réviser", .accent)
        }
        if stats.cardCount == 0 {
            return .badge("vide", .neutral)
        }
        return .badge("à jour", .neutral)
    }
}
