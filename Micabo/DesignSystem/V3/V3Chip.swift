import SwiftUI

/// **La puce de l'app** : une pilule surface de 44 pt à filet, libellé de 15 pt Bold, précédé
/// d'une icône deux tons. Choisie (une matière cochée) : un aplat d'accent, texte blanc.
///
/// Pour un raccourci (« Scanner »), un filtre, un choix court dans une rangée qui passe à la
/// ligne (`MicaboFlowLayout`) ou qui défile.
///
/// - `icon` : une icône de la famille (`MicaboIcon`), dans sa teinte ou dans `tone`.
/// - `systemImage` : un SF Symbol hors famille, teinté de `tone` (l'accent par défaut).
/// - `emoji` : gardé pour ce qui n'a pas d'icône (un drapeau) ; jamais à la place d'une icône.
struct V3Chip: View {
    private let title: String
    private let systemImage: String?
    private let emoji: String?
    private let icon: MicaboIcon?
    private let tone: Color?
    private let isSelected: Bool
    private let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        emoji: String? = nil,
        icon: MicaboIcon? = nil,
        tone: Color? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.emoji = emoji
        self.icon = icon
        self.tone = tone
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                leading
                Text(title)
                    .font(V3Font.label)
                    .foregroundStyle(isSelected ? V3Color.onAccent : V3Color.ink)
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
                selectedFill: V3Color.accent,
                feedback: .light
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var leading: some View {
        if let icon {
            MicaboIconView(icon: icon, size: 30, tint: isSelected ? V3Color.onAccent : tone)
                .frame(width: 24, height: 24)
        } else if let systemImage {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? V3Color.onAccent : (tone ?? V3Color.accent))
                .accessibilityHidden(true)
        } else if let emoji {
            Text(emoji)
                .font(.system(size: 16))
                .accessibilityHidden(true)
        }
    }
}
