import Foundation
import SwiftData
import SwiftUI
import UIKit

/// Couleurs de surlignage disponibles pour l'étudiant.
enum HighlightColor: String, Codable, CaseIterable, Identifiable {
    case yellow
    case mint
    case lilac

    var id: String { rawValue }

    var label: String {
        switch self {
        case .yellow: "Jaune"
        case .mint: "Menthe"
        case .lilac: "Lilas"
        }
    }

    var systemImage: String {
        switch self {
        case .yellow: "highlighter"
        case .mint: "leaf.fill"
        case .lilac: "paintbrush.pointed.fill"
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow: FeyColor.highlightYellow
        case .mint: FeyColor.highlightMint
        case .lilac: FeyColor.highlightLilac
        }
    }

    var uiColor: UIColor {
        UIColor(swiftUIColor)
    }
}

/// Surlignage créé par l'étudiant sur un bloc de cours.
@Model
final class TextHighlight {
    var id: UUID = UUID()
    /// Identifiant du `CourseBlockEntity` concerné.
    var blockId: UUID = UUID()
    /// Début dans le texte brut (sans balisage).
    var start: Int = 0
    var length: Int = 0
    var colorRaw: String = HighlightColor.yellow.rawValue
    var createdAt: Date = Date()
    var course: Course?

    init(
        blockId: UUID,
        start: Int,
        length: Int,
        color: HighlightColor = .yellow,
        course: Course? = nil
    ) {
        self.id = UUID()
        self.blockId = blockId
        self.start = max(0, start)
        self.length = max(0, length)
        self.colorRaw = color.rawValue
        self.createdAt = Date()
        self.course = course
    }

    var color: HighlightColor {
        get { HighlightColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue }
    }

    var range: NSRange {
        NSRange(location: start, length: length)
    }

    func overlaps(_ other: NSRange) -> Bool {
        NSIntersectionRange(range, other).length > 0
    }
}
