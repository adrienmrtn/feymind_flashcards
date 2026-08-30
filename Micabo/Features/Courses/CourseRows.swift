import SwiftUI

extension MicaboRow {
    /// Rangée d'un cours : vignette, titre, matière et nombre de cartes, état à droite.
    static func course(_ course: Course, action: (() -> Void)? = nil) -> MicaboRow {
        MicaboRow(
            tile: MicaboTile.course(course),
            title: course.title,
            subtitle: CourseRowLabels.meta(for: course),
            accessory: CourseRowLabels.accessory(for: course),
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
    static func meta(for course: Course) -> String {
        var parts: [String] = []
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        parts.append(MicaboCopy.cards(course.cards.count))
        parts.append(MicaboCopy.audience(of: course))
        return parts.joined(separator: " · ")
    }

    static func accessory(for course: Course) -> MicaboRowAccessory {
        let due = course.dueCount
        if due > 0 {
            return .badge("\(due) à réviser", .accent)
        }
        if course.cards.isEmpty {
            return .badge("vide", .neutral)
        }
        return .badge("à jour", .neutral)
    }
}
