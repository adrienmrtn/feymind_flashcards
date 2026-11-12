import SwiftUI

/// **Mika pose une question** : un petit Mika (84 pt) à gauche, sa bulle à droite, en haut de
/// l'écran. C'est l'une des deux seules places de Mika en V3 (l'autre : le grand Mika centré
/// d'un « moment »).
///
/// La bulle est un fond doux aux coins 22/22/22/6 — le petit coin du côté de Mika —, le texte
/// en 22 pt Black. Quand le texte change (Mika réagit à une réponse), il fait un fondu ; la
/// bulle suit sa nouvelle taille sans à-coup. En arabe, Mika passe à droite et le petit coin
/// avec lui. Le texte passe à la ligne, il ne se coupe jamais.
///
/// La vue n'a pas de marge horizontale : `V3Screen` pose les 20 pt.
struct MikaAsk: View {
    private let text: String
    private let mood: MikaMood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, mood: MikaMood = .idle) {
        self.text = text
        self.mood = mood
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            MikaMascot(mood: mood, size: 84)
                .accessibilityHidden(true)
            Text(text)
                .font(V3Font.title)
                .tracking(V3Tracking.title)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    V3Color.soft,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: V3Metric.radiusBubble,
                        bottomLeadingRadius: 6,
                        bottomTrailingRadius: V3Metric.radiusBubble,
                        topTrailingRadius: V3Metric.radiusBubble,
                        style: .continuous
                    )
                )
        }
        .padding(.top, 8)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: text)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}
