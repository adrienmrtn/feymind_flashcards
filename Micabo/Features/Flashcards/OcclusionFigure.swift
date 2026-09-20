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
    /// **Le retournement détruit cet état** : recto et verso ne sont pas la même vue, la
    /// tâche repart, et c'est le cache — pas l'identité de la vue — qui fait que le schéma
    /// est déjà là. D'où la relecture synchrone dans `content` : sans elle, chaque
    /// retournement coûterait une image vide.
    @State private var image: UIImage?

    /// La clé du cache. L'identifiant de la carte suffit : les deux endroits qui remplacent
    /// une image — la synchronisation et l'éditeur de schéma — appellent
    /// `DecodedImageCache.forget(_:)`, ce qui périme l'entrée au bon moment sans faire
    /// changer la clé à chaque note.
    private var cacheKey: String {
        DecodedImageCache.cardKey(card.id)
    }

    var body: some View {
        content
            .task(id: cacheKey) {
                // La lecture de `imageData` reste ici : c'est un accès SwiftData, il se fait
                // sur l'acteur principal. Seul le décodage part ailleurs.
                let decoded = await DecodedImageCache.image(for: cacheKey, data: card.imageData)
                // `Task.detached` n'hérite pas de l'annulation de cette tâche : sans ce
                // test, une carte quittée avant la fin du décodage poserait son schéma sur
                // la suivante.
                guard !Task.isCancelled else { return }
                image = decoded
            }
    }

    @ViewBuilder
    private var content: some View {
        // Le cache est relu ici, synchronement : une carte déjà vue se dessine dès la
        // première passe, sans attendre que la tâche ci-dessus ait reposé l'état. Sans ça,
        // chaque retournement coûterait une image vide, ce que le décodage dans le corps, lui,
        // ne faisait pas.
        if let image = image ?? DecodedImageCache.cached(cacheKey) {
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
        } else if card.imageData != nil {
            // **La place est réservée avant que l'image arrive.** Sans cette branche, la
            // toute première apparition d'une carte à occlusion — cache froid — posait le
            // corps de la carte sans son schéma, puis le faisait **sauter** quand le décodage
            // rendait la main. Un rectangle de la bonne hauteur tient la mise en page ; le
            // schéma prend sa place sans rien déplacer.
            //
            // La condition lit `imageData`, donc faulte le blob : c'est acceptable ici parce
            // qu'on n'y passe qu'une fois par carte, au tout premier rendu, et jamais quand
            // le cache répond.
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .fill(MicaboColor.surfaceMuted)
                .frame(height: maxHeight)
                .accessibilityHidden(true)
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
