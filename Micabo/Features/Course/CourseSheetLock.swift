import SwiftUI

/// **La fin d'une fiche, pour qui n'est pas abonné.**
///
/// Les blocs restants sont bel et bien composés, puis floutés et fondus dans le papier :
/// c'est ce qui fait la différence entre « il y a une suite » et « ça s'arrête là ». Une
/// fiche coupée net se lit comme une fiche courte, et une fiche courte ne donne envie de
/// rien ; une fiche dont on voit la suite se dissoudre donne envie de la lire.
///
/// Le cadenas est posé **au bas du fondu**, là où le texte a fini de disparaître : posé
/// par-dessus le flou, il aurait caché ce qu'il est censé faire désirer.
struct LockedSheetTail: View {
    let blocks: [SheetBlock]
    let tint: Color
    var action: () -> Void

    /// La hauteur de l'aperçu, et elle est volontairement fixe. Flouter trente pour cent
    /// d'une fiche de trente blocs ferait défiler dix écrans de brouillard avant d'atteindre
    /// le cadenas.
    private let previewHeight: CGFloat = 300

    private var lockedPercent: Int {
        Int(((1 - FreeTier.readableSheetRatio) * 100).rounded())
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                preview
                lock
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .padding(.top, MicaboSpacing.md)
        .accessibilityLabel("La suite de la fiche est réservée à Micabo Pro")
        .accessibilityAddTraits(.isButton)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                SheetBlockView(block: block, tint: tint)
                    .padding(.top, index == 0 ? 0 : SheetBlockView.spacing(before: block))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Ni le doigt ni le lecteur d'écran n'entrent ici : un texte illisible qu'on peut
        // sélectionner reste un texte qu'on peut copier.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .blur(radius: 6.5)
        .frame(height: previewHeight, alignment: .top)
        .clipped()
        .mask {
            LinearGradient(
                stops: [
                    Gradient.Stop(color: .black, location: 0),
                    Gradient.Stop(color: .black.opacity(0.4), location: 0.5),
                    Gradient.Stop(color: .black.opacity(0), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var lock: some View {
        VStack(spacing: 11) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 48, height: 48)
                .background(MicaboColor.ink, in: Circle())

            VStack(spacing: 5) {
                Text("La suite de la fiche est dans Pro")
                    .font(MicaboFont.hanken(16.5, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.3)

                Text("Il te reste \(lockedPercent) % de ce cours à lire, et tous les suivants à importer.")
                    .font(MicaboFont.hanken(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Text("Débloquer la fiche")
                    .font(MicaboFont.hanken(14.5, weight: .semibold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(MicaboColor.onInk)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(MicaboColor.ink, in: Capsule())
            .padding(.top, 3)
        }
        .padding(.horizontal, MicaboSpacing.md)
        .frame(maxWidth: .infinity)
    }
}
