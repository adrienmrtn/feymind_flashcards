import SwiftUI
import UIKit

/// Schéma d'une carte à occlusion. La zone à trouver est couverte d'un cache à l'accent au
/// recto ; au verso le cache se lève et laisse un cadre qui montre où regarder.
///
/// Les coordonnées de la zone sont relatives (0…1) : le même schéma se rend correctement
/// en pleine carte, en vignette de liste ou sur un autre appareil.
struct OcclusionFigure: View {
    let card: Flashcard
    var isRevealed: Bool
    var maxHeight: CGFloat = 260

    /// **Le schéma décodé, hors du corps de la vue.**
    ///
    /// `UIImage(data:)` vivait ici, dans `body` : un décodage JPEG de dix à quarante
    /// millisecondes sur iPhone 13, refait à chaque évaluation — donc à chaque retournement
    /// de carte, en pleine session. Le décodage part maintenant hors de l'acteur principal et
    /// ne se refait pas : voir `DecodedImageCache`.
    ///
    /// Le retournement ne coûte rien : recto et verso sont la même vue, même identité, donc
    /// la tâche ne repart pas et l'image reste. Seule la **première** apparition d'une carte
    /// attend une passe, et le cache supprime cette attente dès la deuxième.
    @State private var image: UIImage?

    var body: some View {
        content
            .task(id: card.id) {
                // La lecture de `imageData` reste ici : c'est un accès SwiftData, il se fait
                // sur l'acteur principal. Seul le décodage part ailleurs.
                image = await DecodedImageCache.image(for: card.id.uuidString, data: card.imageData)
            }
    }

    @ViewBuilder
    private var content: some View {
        // Le cache est relu ici, synchronement : une carte déjà vue se dessine dès la
        // première passe, sans attendre que la tâche ci-dessus ait reposé l'état. Sans ça,
        // revenir sur une carte connue coûterait une image vide, ce que le décodage dans le
        // corps, lui, ne faisait pas.
        if let image = image ?? DecodedImageCache.cached(card.id.uuidString) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: maxHeight)
                .overlay {
                    GeometryReader { proxy in
                        let frame = maskFrame(in: proxy.size)

                        ZStack {
                            if isRevealed {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(MicaboColor.accent, lineWidth: 2.5)
                                    .background(
                                        MicaboColor.accent.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    )
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                            } else {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(MicaboColor.accent)
                                    .overlay {
                                        Text("?")
                                            .font(MicaboFont.ui(min(frame.height * 0.6, 22), weight: .bold))
                                            .foregroundStyle(MicaboColor.onInk)
                                    }
                                    .frame(width: frame.width, height: frame.height)
                                    .position(x: frame.midX, y: frame.midY)
                            }
                        }
                        .animation(.easeOut(duration: 0.25), value: isRevealed)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                .accessibilityLabel(
                    isRevealed
                        ? L10n.t("ios.schemaRevealed", locale: .resolved())
                        : L10n.t("ios.schemaMasked", locale: .resolved())
                )
        }
    }

    /// La zone masquée ramenée aux points de l'image telle qu'elle est affichée.
    private func maskFrame(in size: CGSize) -> CGRect {
        let rect = card.maskRect
        return CGRect(
            x: rect.origin.x * size.width,
            y: rect.origin.y * size.height,
            width: max(12, rect.size.width * size.width),
            height: max(12, rect.size.height * size.height)
        )
    }
}
