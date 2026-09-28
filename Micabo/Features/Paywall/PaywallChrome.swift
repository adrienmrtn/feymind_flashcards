import SwiftUI

/// **Ce que tous les écrans d'abonnement ont en commun** : la croix, le bouton qui
/// engage, et les mentions du bas. Dans la charte du parcours d'accueil : blanc, encre, et
/// le seul endroit de l'app où le violet devient un dégradé, sur le bouton d'achat.
///
/// Les avoir ici plutôt que recopiés dans chaque écran n'est pas une commodité. Micabo
/// ouvre le paywall à cinq endroits, et cinq boutons d'abonnement qui ne portent pas le
/// même nom donnent l'impression de cinq offres différentes.

/// La croix, dans un rond gris.
///
/// Elle est **toujours là, et elle ne se fait pas attendre**. Un paywall dont la sortie
/// apparaît au bout de cinq secondes fait fermer l'app au lieu de la faire refuser.
struct PaywallCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(OnboardingPalette.ink)
                .frame(width: 36, height: 36)
                .background(OnboardingPalette.card, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel(L10n.t("app.a11y.close", locale: .resolved()))
    }
}

/// Bandeau du haut : la croix à droite, et rien d'autre.
struct PaywallHeader: View {
    var onClose: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            PaywallCloseButton(action: onClose)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.xs)
    }
}

/// **Le bouton d'abonnement** : une pilule de cinquante-six points, en dégradé violet.
/// C'est le seul bouton de l'app qui n'est pas noir, et c'est pour ça qu'on le voit.
struct PaywallCallToAction: View {
    var isPurchasing: Bool
    /// Absent : l'écran ne vend que l'annuel, donc l'essai. Présent : le libellé suit l'offre.
    var plan: PaywallPlan? = nil
    var action: () -> Void

    private var hasTrial: Bool { plan?.hasTrial ?? true }

    var body: some View {
        Button {
            guard !isPurchasing else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(OnboardingPalette.white)
                }

                Text(
                    hasTrial
                        ? L10n.t("ios.paywallStartTrial", locale: .resolved(), vars: ["n": "\(PaywallCatalog.freeTrialDays)"])
                        : L10n.t("app.paywall.subscribe", locale: .resolved())
                )
                .font(OnboardingPalette.button)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            }
            .foregroundStyle(OnboardingPalette.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(PaywallGradient.button, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .medium))
        .disabled(isPurchasing)
        .animation(.easeOut(duration: 0.2), value: isPurchasing)
    }
}

/// Le dégradé du bouton d'achat, et de lui seul.
enum PaywallGradient {
    static let button = LinearGradient(
        colors: [Color(hex: 0x7C3AED), Color(hex: 0x4F1DFF)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

/// « Aucun paiement aujourd'hui », avec sa coche : la ligne posée juste au-dessus du
/// bouton, sur chaque écran qui vend l'essai.
struct PaywallNoPaymentLine: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
            Text(L10n.t("ios.trial.noPayment", locale: .resolved()))
                .font(MicaboFont.ui(15, weight: .semibold))
        }
        .foregroundStyle(OnboardingPalette.ink)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
                .foregroundStyle(OnboardingPalette.gray)
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
    /// « Essaie 3 jours gratuitement, puis 5,83 € / mois (facturé 69,99 € par an). »
    static func text(for plan: PaywallPlan) -> Text {
        let locale = UiLocale.resolved()
        let free = Text(L10n.t("ios.paywallTryDays", locale: locale, vars: ["n": "\(PaywallCatalog.freeTrialDays)"]))
            .foregroundStyle(OnboardingPalette.accent)
        let price = Text(sentence(for: plan, locale: locale))
            .foregroundStyle(OnboardingPalette.ink)
        return free + price
    }

    static func sentence(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        if let monthly = plan.monthlyEquivalent {
            return L10n.t(
                "ios.paywallThenYear",
                locale: locale,
                vars: ["monthly": monthly, "yearly": plan.displayPrice]
            )
        }
        return L10n.t(
            "ios.paywallThenPeriod",
            locale: locale,
            vars: ["price": plan.displayPrice, "unit": plan.period.unit]
        )
    }

    /// **Les petites lignes sous le bouton** : ce qui sera prélevé, quand, et comment on
    /// arrête. Apple les exige, et un élève les lit.
    static func finePrint(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        if plan.hasTrial {
            return L10n.t("ios.paywall.finePrint", locale: locale, vars: [
                "n": "\(plan.trialDays)", "price": plan.displayPrice, "unit": plan.period.unit,
            ])
        }
        return L10n.t("ios.paywall.finePrintNoTrial", locale: locale, vars: [
            "price": plan.displayPrice, "unit": plan.period.unit,
        ])
    }

    /// La ligne grise posée juste au-dessus du bouton.
    static var reassurance: String {
        L10n.t("ios.paywallReassurance", locale: .resolved())
    }
}

// MARK: - Les deux offres, côte à côte

/// **Les deux cartes d'offre**, l'annuel coché d'avance avec son sceau « 3 jours gratuits ».
/// C'est le sélecteur de Cal AI et de Quizlet : deux cartes de même taille, la choisie en
/// noir, et le mois écrit en grand parce que c'est le chiffre qu'on compare.
struct PaywallPlanPicker: View {
    @Binding var selection: PaywallPlan.Kind

    var body: some View {
        HStack(spacing: 12) {
            ForEach(PaywallCatalog.all) { plan in
                card(plan)
            }
        }
    }

    private func card(_ plan: PaywallPlan) -> some View {
        let isSelected = plan.kind == selection
        return Button {
            withAnimation(OnboardingMotion.select) { selection = plan.kind }
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.title)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(isSelected ? OnboardingPalette.white.opacity(0.75) : OnboardingPalette.gray)

                HStack(alignment: .lastTextBaseline, spacing: 3) {
                    Text(plan.headlinePrice)
                        .font(MicaboFont.ui(22, weight: .bold))
                        .tracking(-0.5)
                    Text(plan.headlineUnit)
                        .font(MicaboFont.ui(12, weight: .medium))
                }
                .foregroundStyle(isSelected ? OnboardingPalette.white : OnboardingPalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

                Text(plan.caption)
                    .font(MicaboFont.ui(11.5, weight: .regular))
                    .foregroundStyle(isSelected ? OnboardingPalette.white.opacity(0.7) : OnboardingPalette.gray)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
            .background(
                isSelected ? OnboardingPalette.ink : OnboardingPalette.card,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(alignment: .top) {
                if plan.hasTrial {
                    Text(L10n.t("ios.paywall.badge.free", locale: .resolved(), vars: ["n": "\(plan.trialDays)"]).uppercased())
                        .font(MicaboFont.ui(10, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(OnboardingPalette.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(OnboardingPalette.accent, in: Capsule())
                        .offset(y: -12)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityLabel("\(plan.title), \(plan.headlinePrice) \(plan.headlineUnit), \(plan.caption)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
