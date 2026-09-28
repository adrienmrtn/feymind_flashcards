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
                .foregroundStyle(OnboardingPalette.gray)
                // La zone touchable fait 44 points, le signe reste calé sur la marge.
                .frame(width: 44, height: 44, alignment: .leading)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel(L10n.t("app.a11y.close", locale: .resolved()))
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
    /// Absent : l'écran ne vend que l'annuel. Présent : le libellé suit l'offre.
    var plan: PaywallPlan? = nil
    var action: () -> Void

    /// Le bouton ne promet l'essai que si ce compte y a droit : un « Commencer l'essai »
    /// suivi d'un prélèvement immédiat est la pire façon de découvrir la règle d'Apple.
    private var hasTrial: Bool { (plan ?? PaywallCatalog.recommended).hasTrial }

    var body: some View {
        // **Le bouton du parcours d'accueil, tel quel** : la pilule noire de cinquante-six
        // points, la même police. Le paywall est la dernière page du parcours, et un bouton
        // d'une autre forme y ferait un autre écran.
        OnboardingContinueButton(
            title: hasTrial
                ? L10n.t("ios.paywallStartTrial", locale: .resolved(), vars: ["n": "\(PaywallCatalog.freeTrialDays)"])
                : L10n.t("app.paywall.subscribe", locale: .resolved()),
            isLoading: isPurchasing,
            loadingTitle: L10n.t("ios.instant", locale: .resolved()),
            action: action
        )
        .environment(\.onboardingSurface, .canvas)
    }
}

/// Restauration et mentions légales, en pied de page.
struct PaywallLegalFooter: View {
    var onRestore: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 7) {
            entry(L10n.t("ios.paywallRestore", locale: .resolved()), action: onRestore)
            separator
            entry(L10n.t("ios.paywallTerms", locale: .resolved())) { open(PaywallLinks.terms) }
            separator
            entry(L10n.t("common.privacy", locale: .resolved())) { open(PaywallLinks.privacy) }
        }
        .frame(maxWidth: .infinity)
    }

    private var separator: some View {
        Text("·")
            .font(MicaboFont.ui(11.5, weight: .regular))
            .foregroundStyle(OnboardingPalette.grayLight)
    }

    private func entry(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.ui(11.5, weight: .regular))
                .foregroundStyle(OnboardingPalette.grayLight)
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
    /// « Essaie 3 jours gratuitement, puis 4,17 € / mois (facturé 49,99 € par an). »
    ///
    /// Le violet ne porte que la partie gratuite. Colorer la phrase entière n'aurait mis en
    /// avant que le prix, colorer le prix aurait mis en avant ce qu'on demande.
    ///
    /// Sans essai — déjà consommé, ou absent dans ce pays —, il reste le prix, et rien
    /// d'autre : la moitié verte ne s'écrit que si Apple l'honorera.
    static func text(for plan: PaywallPlan) -> Text {
        let locale = UiLocale.resolved()
        let price = Text(sentence(for: plan, locale: locale))
            .foregroundStyle(OnboardingPalette.ink)
        guard plan.hasTrial else { return price }
        let free = Text(L10n.t("ios.paywallTryDays", locale: locale, vars: ["n": "\(PaywallCatalog.freeTrialDays)"]))
            .foregroundStyle(OnboardingPalette.accent)
        return free + price
    }

    /// La moitié « prix » de la phrase. Derrière l'essai elle commence par « puis » ; seule,
    /// elle commence par le prix.
    static func sentence(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        let afterTrial = plan.hasTrial
        if let monthly = plan.monthlyEquivalent {
            return L10n.t(
                afterTrial ? "ios.paywallThenYear" : "ios.paywallPriceYear",
                locale: locale,
                vars: ["monthly": monthly, "yearly": plan.displayPrice]
            )
        }
        return L10n.t(
            afterTrial ? "ios.paywallThenPeriod" : "ios.paywallPricePeriod",
            locale: locale,
            vars: ["price": plan.displayPrice, "unit": plan.period.unit]
        )
    }

    /// La ligne grise posée juste au-dessus du bouton.
    static var reassurance: String {
        L10n.t("ios.paywallReassurance", locale: .resolved())
    }
}
