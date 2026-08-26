import SwiftUI

/// **Ce que tous les écrans d'abonnement ont en commun** : la croix en haut à gauche, le
/// bouton qui engage, et les mentions du bas.
///
/// Les avoir ici plutôt que recopiés dans chaque écran n'est pas une commodité. Micabo
/// ouvre le paywall à cinq endroits — la fin du parcours, la fiche coupée, le deuxième
/// import, l'entraînement libre, la cinquième carte — et cinq boutons d'abonnement qui ne
/// portent pas le même nom donnent l'impression de cinq offres différentes.

/// La croix, en haut à gauche.
///
/// Elle est **toujours là, et elle ne se fait pas attendre**. Un paywall dont la sortie
/// apparaît au bout de cinq secondes fait fermer l'app au lieu de la faire refuser : on perd
/// l'utilisateur au lieu de perdre l'abonnement. Ce qu'elle fait derrière peut varier — sur
/// le premier paywall elle ouvre le second, sur celui d'une session elle demande confirmation
/// — mais elle réagit toujours au premier appui.
struct PaywallCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                // La zone touchable fait 44 points, le signe reste calé sur la marge.
                .frame(width: 44, height: 44, alignment: .leading)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel("Fermer")
    }
}

/// Bandeau du haut : la croix, et rien d'autre.
struct PaywallHeader: View {
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            PaywallCloseButton(action: onClose)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
    }
}

/// Le bouton d'abonnement, identique partout où il apparaît.
struct PaywallCallToAction: View {
    var isPurchasing: Bool
    var action: () -> Void

    var body: some View {
        Button {
            guard !isPurchasing else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MicaboColor.onInk)
                }

                Text("Démarrer mes \(PaywallCatalog.freeTrialDays) jours gratuits")
            }
            .frame(maxWidth: .infinity)
        }
        // Aussi grand que le bouton du parcours d'accueil : le paywall en est la dernière
        // page, et un bouton qui rapetisse à l'écran de l'offre se lit comme une hésitation.
        .buttonStyle(MicaboPrimaryButtonStyle(isProminent: true))
        .disabled(isPurchasing)
        .animation(.easeOut(duration: 0.2), value: isPurchasing)
    }
}

/// Restauration et mentions légales, en pied de page.
struct PaywallLegalFooter: View {
    var onRestore: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 7) {
            entry("Restaurer", action: onRestore)
            separator
            entry("Conditions d'utilisation") { open(PaywallLinks.terms) }
            separator
            entry("Confidentialité") { open(PaywallLinks.privacy) }
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Text("·")
            .font(MicaboFont.hanken(11.5, weight: .regular))
            .foregroundStyle(MicaboColor.inkTertiary)
    }

    private func entry(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.hanken(11.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true))
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        openURL(url)
    }
}

/// La phrase qui dit le prix, et la seule de l'app qui le dise.
enum PaywallPitch {
    /// « Essaie 3 jours gratuitement, puis 5,00 € / mois (facturé 59,99 € par an). »
    ///
    /// Le vert ne porte que la partie gratuite. Colorer la phrase entière n'aurait mis en
    /// avant que le prix, colorer le prix aurait mis en avant ce qu'on demande.
    static func text(for plan: PaywallPlan) -> Text {
        let free = Text("Essaie \(PaywallCatalog.freeTrialDays) jours gratuitement, ")
            .foregroundStyle(MicaboColor.accent)
        let price = Text(sentence(for: plan))
            .foregroundStyle(MicaboColor.ink)
        return free + price
    }

    static func sentence(for plan: PaywallPlan) -> String {
        if let monthly = plan.monthlyEquivalent {
            return "puis \(monthly) / mois (facturé \(plan.displayPrice) par an)."
        }
        return "puis \(plan.displayPrice) par \(plan.period.unit)."
    }

    /// La ligne grise posée juste au-dessus du bouton.
    static let reassurance = "Deux appuis pour commencer, résiliable en quinze secondes."
}
