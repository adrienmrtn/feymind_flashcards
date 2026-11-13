import SwiftUI

/// **Un texte peint du dégradé de marque** (le bleu Micabo vers son 700), de gauche à droite.
struct MikaGradientText: View {
    let text: String
    var size: CGFloat = 24
    var weight: Font.Weight = .bold

    var body: some View {
        Text(text)
            .font(MicaboFont.ui(size, weight: weight))
            .tracking(-0.6)
            .multilineTextAlignment(.center)
            .foregroundStyle(
                LinearGradient(
                    colors: OnboardingPalette.mikaGradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .fixedSize(horizontal: false, vertical: true)
    }
}
