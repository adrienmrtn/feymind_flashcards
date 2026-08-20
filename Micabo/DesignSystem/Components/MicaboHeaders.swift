import SwiftUI

/// Sur-titre en capitales : le compteur discret posé au-dessus d'un grand titre.
struct MicaboEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(MicaboFont.eyebrow)
            .tracking(MicaboTracking.caps)
            .foregroundStyle(MicaboColor.inkTertiary)
    }
}

/// En-tête d'un écran racine : un sur-titre gris, un grand titre serré, et de
/// quoi agir à droite. Rien n'est encadré, tout est posé sur le fond ivoire.
struct MicaboScreenHeader<Trailing: View>: View {
    let title: String
    var eyebrow: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: MicaboSpacing.sm) {
            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    MicaboEyebrow(text: eyebrow)
                }

                Text(title)
                    .font(MicaboFont.screenTitle)
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.display)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            trailing
        }
    }
}

extension MicaboScreenHeader where Trailing == EmptyView {
    init(title: String, eyebrow: String? = nil) {
        self.init(title: title, eyebrow: eyebrow, trailing: { EmptyView() })
    }
}

/// En-tête d'un écran poussé : bouton de retour rond, titre à côté, actions à droite.
struct MicaboNavHeader<Trailing: View>: View {
    let title: String
    var onBack: () -> Void
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: MicaboSpacing.sm) {
            MicaboCircleButton(systemImage: "chevron.left", size: 36, accessibilityTitle: "Retour", action: onBack)

            Text(title)
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
                .lineLimit(1)

            Spacer(minLength: MicaboSpacing.xs)

            trailing
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.vertical, MicaboSpacing.xs)
    }
}

extension MicaboNavHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

/// Champ de recherche large, blanc, aux coins généreux.
struct MicaboSearchField: View {
    @Binding var text: String
    var placeholder: String = "Rechercher"

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)

            TextField(placeholder, text: $text)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .autocorrectionDisabled()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
