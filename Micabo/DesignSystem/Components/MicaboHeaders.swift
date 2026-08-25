import SwiftUI

/// Sur-titre en capitales : le compteur discret posé au-dessus d'un grand titre.
struct MicaboEyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(MicaboFont.eyebrow)
            .tracking(MicaboTracking.caps)
            .foregroundStyle(MicaboColor.inkTertiary)
            .lineLimit(2)
    }
}

/// Bouton de sortie d'un en-tête : chevron sur un écran poussé, croix sur une feuille.
struct MicaboHeaderBack {
    var systemImage: String = "chevron.left"
    var accessibilityTitle: String = "Retour"
    var action: () -> Void

    static func back(_ action: @escaping () -> Void) -> MicaboHeaderBack {
        MicaboHeaderBack(action: action)
    }

    static func close(_ action: @escaping () -> Void) -> MicaboHeaderBack {
        MicaboHeaderBack(systemImage: "xmark", accessibilityTitle: "Fermer", action: action)
    }
}

/// **L'unique en-tête d'écran de l'app.** Fond crème, sur-titre en capitales grises,
/// grand titre serré, et de quoi agir à droite.
///
/// Aucun écran n'a droit à son propre traitement : ni bandeau pleine largeur, ni fond
/// sombre, ni titre en petit à côté du chevron. Un écran poussé ou une feuille ajoute
/// simplement un bouton rond au-dessus du sur-titre. Si une page doit porter une
/// couleur — le détail d'un cours, par exemple — c'est la **tuile** qui la porte, pas
/// le bandeau.
struct MicaboScreenHeader<Trailing: View>: View {
    let title: String
    var eyebrow: String?
    var tile: MicaboTile?
    var back: MicaboHeaderBack?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Sur un écran poussé, les actions rejoignent le bouton de sortie ; sur un
            // écran racine, elles restent à hauteur du titre.
            if let back {
                HStack(spacing: MicaboSpacing.sm) {
                    MicaboCircleButton(
                        systemImage: back.systemImage,
                        size: 38,
                        accessibilityTitle: back.accessibilityTitle,
                        action: back.action
                    )

                    Spacer(minLength: 0)

                    trailing
                }
            }

            HStack(alignment: .center, spacing: MicaboSpacing.sm) {
                titleBlock

                Spacer(minLength: 0)

                if back == nil {
                    trailing
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let tile {
                tile
            }

            VStack(alignment: .leading, spacing: 5) {
                if let eyebrow {
                    MicaboEyebrow(text: eyebrow)
                }

                Text(title)
                    .font(MicaboFont.screenTitle)
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.display)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension MicaboScreenHeader where Trailing == EmptyView {
    init(
        title: String,
        eyebrow: String? = nil,
        tile: MicaboTile? = nil,
        back: MicaboHeaderBack? = nil
    ) {
        self.init(title: title, eyebrow: eyebrow, tile: tile, back: back, trailing: { EmptyView() })
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
                .buttonStyle(MicaboPressableButtonStyle())
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
