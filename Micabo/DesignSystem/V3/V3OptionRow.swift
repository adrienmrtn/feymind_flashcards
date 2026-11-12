import SwiftUI

/// **La ligne de réponse V3** : 64 pt au moins, une pastille d'icône de 40 pt, un texte de
/// 18 pt ExtraBold, une coche ronde à droite. Choisie : bord et lèvre d'accent, fond de lavis.
/// Elle s'enfonce sur sa lèvre à l'appui.
///
/// - `emoji` ou `icon` : ce que porte la pastille (l'emoji gagne s'il y a les deux) ; sans
///   l'un ni l'autre, pas de pastille.
/// - `tone` : le fond de la pastille — un lavis (`V3Color.greenWash`) ou un plein, délayé.
/// - `multiple` : la coche devient une case, pour un choix multiple.
///
/// Une ligne réserve ses 4 pt de lèvre : dans une pile, `VStack(spacing: 10)` donne les 14 pt
/// des maquettes. Le texte passe à la ligne, la ligne grandit.
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
                badge
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(V3Font.option)
                        .foregroundStyle(isSelected ? V3Color.accentInk : V3Color.ink)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(V3Font.support)
                            .foregroundStyle(V3Color.ink2)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                V3Check(isOn: isSelected, square: multiple)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: V3Metric.optionHeight)
        }
        .buttonStyle(V3TileButtonStyle(selected: isSelected))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private var badge: some View {
        if emoji != nil || icon != nil {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(badgeFill)
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 22))
                } else if let icon {
                    MicaboIconView(icon: icon, size: 28)
                }
            }
            .frame(width: V3Metric.badge, height: V3Metric.badge)
            .accessibilityHidden(true)
        }
    }

    private var badgeFill: Color {
        if let tone { return V3Color.wash(of: tone) }
        if emoji == nil, let icon { return icon.tone.pale }
        return isSelected ? V3Color.accentWash2 : V3Color.soft
    }
}
