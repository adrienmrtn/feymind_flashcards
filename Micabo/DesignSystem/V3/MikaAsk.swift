import SwiftUI

/// **Mika parle dans sa bulle** : un petit Mika (76 pt) à gauche, sa bulle à droite, en haut de
/// l'écran. C'est lui qui pose les questions d'un parcours, qui propose la séance sur la Home,
/// qui présente l'offre sur le paywall — l'une des signatures de Micabo.
///
/// La bulle est une surface aux coins 20/20/20/6 — le petit coin du côté de Mika —, le texte en
/// Sofia Sans Condensed Black de 24 pt. `highlight`, le groupe de mots à faire ressortir, passe
/// en **bleu clair** (un seul par phrase). Quand le texte change (Mika réagit à une réponse), il
/// fait un fondu ; la bulle suit sa nouvelle taille sans à-coup. En arabe, Mika passe à droite
/// et le petit coin avec lui. Le texte passe à la ligne, il ne se coupe jamais.
///
/// La vue n'a pas de marge horizontale : `V3Screen` pose les 20 pt.
struct MikaAsk: View {
    private let text: String
    private let highlight: String?
    private let mood: MikaMood

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ text: String, highlight: String? = nil, mood: MikaMood = .idle) {
        self.text = text
        self.highlight = highlight
        self.mood = mood
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            MikaMascot(mood: mood, size: V3Metric.mikaAsk)
                .accessibilityHidden(true)
            Text(v3: text, highlight: highlight)
                .font(V3Font.title)
                .tracking(V3Tracking.title)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    V3Color.surface,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: V3Metric.radiusBubble,
                        bottomLeadingRadius: V3Metric.radiusBubbleTail,
                        bottomTrailingRadius: V3Metric.radiusBubble,
                        topTrailingRadius: V3Metric.radiusBubble,
                        style: .continuous
                    )
                )
        }
        .padding(.top, 10)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text.v3Plain))
        .accessibilityAddTraits(.isHeader)
    }
}
