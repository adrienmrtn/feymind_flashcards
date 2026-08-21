import SwiftUI
import UIKit

/// Schéma d'une carte à occlusion. La zone à trouver est couverte d'un cache indigo au
/// recto ; au verso le cache se lève et laisse un cadre qui montre où regarder.
///
/// Les coordonnées de la zone sont relatives (0…1) : le même schéma se rend correctement
/// en pleine carte, en vignette de liste ou sur un autre appareil.
struct OcclusionFigure: View {
    let card: Flashcard
    var isRevealed: Bool
    var maxHeight: CGFloat = 260

    var body: some View {
        if let data = card.imageData, let image = UIImage(data: data) {
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
                                            .font(MicaboFont.hanken(min(frame.height * 0.6, 22), weight: .bold))
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
                .accessibilityLabel(isRevealed ? "Schéma, zone révélée" : "Schéma, une zone est masquée")
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
