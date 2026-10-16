import SwiftUI

/// **Ce que dit la recherche**, en une carte.
///
/// L'essai contrôlé mené à Harvard (Kestin et al., *AI tutoring outperforms in-class active
/// learning*, Scientific Reports, 2025) : des étudiants accompagnés d'un tuteur IA ont appris
/// plus de deux fois plus, en moins de temps, qu'en cours en classe fondé sur l'apprentissage
/// actif. La phrase dit ce que l'étude mesure — la comparaison est avec un cours interactif,
/// pas avec un cours magistral —, et l'étude porte sur un tuteur IA de physique, pas sur
/// Micabo : la carte la cite, elle ne la revendique pas.
///
/// Pas de blason : le nom de l'université et la référence suffisent, et un logo d'université
/// sur un écran d'offre se lirait comme un partenariat.
struct ResearchQuoteCard: View {
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 12 : 16) {
            HStack(spacing: 8) {
                MicaboIconView(icon: .diploma, size: compact ? 26 : 30)
                Text(L10n.t("ios.research.eyebrow", locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .heavy))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.accent)
            }

            HStack(alignment: .center, spacing: compact ? 12 : 16) {
                Text(L10n.t("ios.research.badge", locale: .resolved()))
                    .font(MicaboFont.number(compact ? 30 : 38))
                    .foregroundStyle(LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: compact ? 66 : 80, height: compact ? 66 : 80)
                    .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Self.quote(L10n.t("ios.research.quote", locale: .resolved()))
                    .font(MicaboFont.ui(compact ? 15.5 : 17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(L10n.t("ios.research.source", locale: .resolved()))
                .font(MicaboFont.ui(12.5, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(compact ? 16 : 20)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        // Le guillemet reste dans la carte : posé à cheval sur le bord, il débordait sur ce
        // qui est au-dessus.
        .overlay(alignment: .topTrailing) {
            Text("”")
                .font(MicaboFont.display(compact ? 46 : 58))
                .foregroundStyle(MicaboColor.accentSoft)
                .frame(height: compact ? 34 : 42, alignment: .top)
                .padding(.top, 6)
                .padding(.trailing, 16)
                .accessibilityHidden(true)
        }
        .micaboElevation(.card)
        .accessibilityElement(children: .combine)
    }

    /// La phrase, le passage marqué au dégradé de l'app.
    static func quote(_ template: String) -> Text {
        var result = Text("")
        for (index, part) in template.components(separatedBy: "**").enumerated() where !part.isEmpty {
            if index % 2 == 1 {
                result = result + Text(part)
                    .font(MicaboFont.ui(17, weight: .heavy))
                    .foregroundStyle(LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .leading, endPoint: .trailing))
            } else {
                result = result + Text(part)
            }
        }
        return result
    }
}

/// **Ce que Pro ouvre**, en rangées : une icône 3D, une ligne, une coche. Les mêmes lignes que
/// la grille du second paywall, dans le même ordre.
struct PaywallFeatureList: View {
    static let icons: [MicaboIcon] = [.lightbulb, .pdf, .quiz, .exam, .mika]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("ios.paywallIncluded", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
            ForEach(Array(Self.icons.enumerated()), id: \.offset) { index, icon in
                HStack(spacing: 12) {
                    MicaboIconView(icon: icon, size: 34)
                    Text(L10n.t("ios.paywallFeat\(index + 1)", locale: .resolved()))
                        .font(MicaboFont.ui(16, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(MicaboColor.onInk, MicaboColor.correct)
                }
            }
        }
        .padding(18)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }
}
