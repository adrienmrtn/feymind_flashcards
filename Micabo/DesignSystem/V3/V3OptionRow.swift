import SwiftUI

/// **La ligne de réponse de l'app** : une surface plate de 58 pt au moins, rayon 16, filet de
/// 1,5 pt ; une icône deux tons de 26 pt à gauche, le texte en 16 pt Bold, et une coche ronde à
/// droite **seulement quand elle est choisie**. Choisie : filet d'accent, lavis de sélection.
///
/// - `icon` : l'icône deux tons de la ligne (`MicaboIcon`), dans sa teinte ou dans `tone`.
/// - `emoji` : gardé pour ce qui n'a pas d'icône (un drapeau) ; jamais à la place d'une icône.
/// - `tone` : la teinte de l'icône (`V3Color.iconGreen`…).
/// - `multiple` : la case reste visible, vide, tant que la ligne n'est pas choisie — on peut en
///   cocher plusieurs.
///
/// Dans une pile, `VStack(spacing: 10)` donne l'écart des maquettes. Le texte passe à la ligne,
/// la ligne grandit.
struct V3OptionRow: View {
    private let title: String
    private let subtitle: String?
    private let icon: MicaboIcon?
    private let tone: Color?
    private let emoji: String?
    private let isSelected: Bool
    private let multiple: Bool
    private let action: () -> Void

    init(
        _ title: String,
        subtitle: String? = nil,
        icon: MicaboIcon? = nil,
        tone: Color? = nil,
        emoji: String? = nil,
        isSelected: Bool,
        multiple: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tone = tone
        self.emoji = emoji
        self.isSelected = isSelected
        self.multiple = multiple
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(V3Font.option)
                        .foregroundStyle(V3Color.ink)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(V3Font.support)
                            .foregroundStyle(V3Color.ink2)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                if isSelected || multiple {
                    V3Check(isOn: isSelected)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: V3Metric.optionHeight)
        }
        .buttonStyle(V3TileButtonStyle(selected: isSelected))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var leading: some View {
        if let icon {
            // `MicaboIconView` dessine son symbole aux deux tiers de sa case : on lui donne une
            // case plus grande, pour un dessin de 26 pt à l'œil.
            MicaboIconView(icon: icon, size: V3Metric.optionIcon * 1.35, tint: tone)
                .frame(width: V3Metric.optionIcon + 2, height: V3Metric.optionIcon + 2)
        } else if let emoji {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: V3Metric.optionIcon, height: V3Metric.optionIcon)
                .accessibilityHidden(true)
        }
    }
}
