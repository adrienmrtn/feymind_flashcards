import SwiftUI

/// **La puce V3** : une pilule de 44 pt, bord de 2 pt, lèvre de 3 pt, libellé de 15 pt
/// ExtraBold, précédé d'un emoji ou d'un pictogramme. Choisie : bord et lèvre d'accent, fond
/// de lavis. Elle s'enfonce sur sa lèvre à l'appui.
///
/// Pour un raccourci (« Scanner un exo »), un filtre, un choix court dans une rangée qui
/// passe à la ligne (`MicaboFlowLayout`) ou qui défile.
struct V3Chip: View {
    private let title: String
    private let systemImage: String?
    private let emoji: String?
    private let isSelected: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        emoji: String? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.emoji = emoji
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 16))
                        .accessibilityHidden(true)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(isSelected ? V3Color.accentInk : V3Color.accent)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(V3Font.label)
                    .foregroundStyle(isSelected ? V3Color.accentInk : V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: V3Metric.chipHeight)
        }
        .buttonStyle(
            V3TileButtonStyle(
                selected: isSelected,
                radius: V3Metric.chipHeight / 2,
                lip: V3Metric.chipLip,
                feedback: .light
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
