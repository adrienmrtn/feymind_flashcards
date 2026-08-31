import SwiftUI

/// **La fin d'une fiche, pour qui n'est pas abonné.**
///
/// Les blocs restants sont bel et bien composés, puis floutés : c'est ce
/// qui fait la différence entre « il y a une suite » et « ça s'arrête là ».
/// On peut les faire défiler — voir ce qu'on y perd — sans les lire.
///
/// Le cadenas est posé **au début de la coupure**, là où le texte commence
/// à disparaître. La suite floutée continue en dessous : on scrolle, on
/// voit le reste du cours se dissoudre, et on revient au cadenas.
struct LockedSheetTail: View {
    let blocks: [SheetBlock]
    let tint: Color
    var action: () -> Void

    private var lockedPercent: Int {
        Int(((1 - FreeTier.readableSheetRatio) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            lock
                .padding(.top, MicaboSpacing.md)
                .padding(.bottom, MicaboSpacing.lg)

            ZStack {
                preview
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
        }
        .padding(.top, MicaboSpacing.md)
        .accessibilityElement(children: .contain)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                SheetBlockView(block: block, tint: tint)
                    .padding(.top, index == 0 ? 0 : SheetBlockView.spacing(before: block))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Ni le doigt ni le lecteur d'écran n'entrent ici : un texte illisible
        // qu'on peut sélectionner reste un texte qu'on peut copier.
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .blur(radius: 6.5)
        .mask {
            LinearGradient(
                stops: [
                    Gradient.Stop(color: .black.opacity(0.2), location: 0),
                    Gradient.Stop(color: .black, location: 0.06),
                    Gradient.Stop(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var lock: some View {
        Button(action: action) {
            VStack(spacing: 11) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 48, height: 48)
                    .background(MicaboColor.accent, in: Circle())

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
                .background(MicaboColor.accent, in: Capsule())
                .padding(.top, 3)
            }
            .padding(.horizontal, MicaboSpacing.md)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel("La suite de la fiche est réservée à Micabo Pro")
        .accessibilityAddTraits(.isButton)
    }
}
