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
    /// Voir `PaywallOfferView.storeRevision` : l'essai peut se révéler consommé après
    /// l'ouverture, et le bouton ne doit plus le promettre.
    var storeRevision: Int = 0
    var action: () -> Void

    /// Le bouton ne promet l'essai que si ce compte y a droit : un « Commencer l'essai »
    /// suivi d'un prélèvement immédiat est la pire façon de découvrir la règle d'Apple.
    private var hasTrial: Bool { (plan ?? PaywallCatalog.recommended).hasTrial }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        // **Le bouton de l'offre** : une pilule pleine largeur au dégradé de l'app, du bleu au
        // violet, la même sur tous les paywalls.
        Button {
            guard !isPurchasing else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isPurchasing {
                    ProgressView().controlSize(.small).tint(.white)
                }
                Text(isPurchasing
                    ? L10n.t("ios.instant", locale: .resolved())
                    : (hasTrial
                        ? L10n.t("ios.paywallStartTrial", locale: .resolved(), vars: ["n": "\(PaywallCatalog.freeTrialDays)"])
                        : L10n.t("app.paywall.subscribe", locale: .resolved())))
                    .font(MicaboFont.ui(19, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(height: 24)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)
                    .blur(radius: 6)
                    .allowsHitTesting(false)
            }
            .shadow(color: MicaboColor.accent.opacity(scheme == .dark ? 0.35 : 0.3), radius: 16, y: 8)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .medium))
        .disabled(isPurchasing)
    }
}

/// **Le pied des paywalls**, le même sur les deux : « rien à payer aujourd'hui » avec son
/// bouclier, le bouton, ce qui sera prélevé, puis les mentions. Posé sur une carte qui monte
/// du bas, il reste visible pendant qu'on lit l'offre.
struct PaywallFooter: View {
    let plan: PaywallPlan
    var isPurchasing: Bool
    var storeRevision: Int = 0
    var onSubscribe: () -> Void
    var onRestore: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.correct)
                Text(L10n.t(plan.hasTrial ? "ios.paywallNoCharge" : "ios.paywallCancelAnytime", locale: .resolved()))
                    .font(MicaboFont.ui(14.5, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            PaywallCallToAction(isPurchasing: isPurchasing, plan: plan, storeRevision: storeRevision, action: onSubscribe)

            Text(plan.billedLine(locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)

            PaywallLegalFooter(onRestore: onRestore)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 18)
        .padding(.bottom, MicaboSpacing.sm)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                .fill(MicaboColor.surface)
                .shadow(color: .black.opacity(0.08), radius: 18, y: -6)
                .ignoresSafeArea(edges: .bottom)
        }
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

    /// **La phrase du premier paywall** : « Essaie 3 jours gratuitement, puis seulement
    /// 4,17 € / mois ». Le vert porte la partie gratuite, l'encre le prix ; ce qui est
    /// prélevé d'un bloc descend dans la ligne grise du bas (`PaywallPlan.billedLine`).
    ///
    /// Sans essai — déjà utilisé par ce compte, ou absent dans ce pays —, il reste
    /// « Seulement 4,17 € / mois » : la moitié verte ne s'écrit que si Apple l'honorera.
    static func headline(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> Text {
        guard plan.hasTrial else {
            return Text(headlineSentence(for: plan, locale: locale)).foregroundStyle(OnboardingPalette.ink)
        }
        // « Essaie **3 jours gratuitement**, puis seulement 4,17 €/mois » : les jours offerts
        // sont surlignés, comme au marqueur.
        let days = "\(PaywallCatalog.freeTrialDays)"
        var lead = AttributedString(L10n.t("ios.paywallTry.lead", locale: locale))
        lead.foregroundColor = OnboardingPalette.ink
        var free = AttributedString(L10n.t("ios.paywallTry.free", locale: locale, vars: ["n": days]))
        free.foregroundColor = MicaboColor.correctInk
        free.backgroundColor = MicaboColor.correctSoft
        let monthly = plan.monthlyEquivalent ?? plan.displayPrice
        var then = AttributedString(L10n.t("ios.paywallTry.then", locale: locale, vars: ["monthly": monthly]))
        then.foregroundColor = OnboardingPalette.ink
        return Text(lead + free + then)
    }

    /// La moitié « prix » de la phrase du premier paywall, sans la somme annuelle.
    static func headlineSentence(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        let afterTrial = plan.hasTrial
        if let monthly = plan.monthlyEquivalent {
            return L10n.t(afterTrial ? "ios.paywallThenOnly" : "ios.paywallOnly", locale: locale, vars: ["monthly": monthly])
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
