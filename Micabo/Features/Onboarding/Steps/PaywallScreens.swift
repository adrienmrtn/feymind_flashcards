import SwiftUI

// MARK: - Habillage commun aux deux paywalls

/// La croix, en haut à gauche.
///
/// Elle est **toujours là, et elle ne se fait pas attendre**. Un paywall dont la sortie
/// apparaît au bout de cinq secondes fait fermer l'app au lieu de la faire refuser : on perd
/// l'utilisateur au lieu de perdre l'abonnement.
private struct PaywallCloseButton: View {
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
private struct PaywallHeader: View {
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

/// Le bouton d'abonnement, identique sur les deux écrans.
private struct PaywallCallToAction: View {
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
        .buttonStyle(MicaboPrimaryButtonStyle())
        .disabled(isPurchasing)
        .animation(.easeOut(duration: 0.2), value: isPurchasing)
    }
}

/// Restauration et mentions légales, en pied de page.
private struct PaywallLegalFooter: View {
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

// MARK: - Premier paywall : une seule offre, une seule phrase

/// Le paywall d'entrée.
///
/// Il ne montre **qu'une offre et qu'un prix**, et c'est tout son intérêt : à l'instant où
/// l'on sort du parcours, une grille de comparaison demande de choisir avant d'avoir décidé
/// d'acheter. La phrase dit les trois choses qu'on veut savoir — c'est gratuit trois jours,
/// ça coûtera tant par mois, c'est prélevé une fois par an — et « Voir toutes les offres »
/// ouvre la grille à ceux qui la cherchent.
struct PaywallOfferView: View {
    let plan: PaywallPlan
    var isPurchasing: Bool
    var onClose: () -> Void
    var onSeeAllPlans: () -> Void
    var onSubscribe: () -> Void
    var onRestore: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaywallHeader(onClose: onClose)

            Spacer(minLength: MicaboSpacing.lg)

            VStack(spacing: 20) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 38, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .onboardingAppear(index: 0)

                pitch
                    .font(MicaboFont.hanken(21, weight: .bold))
                    .tracking(-0.4)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1)

                Button(action: onSeeAllPlans) {
                    Text("Voir toutes les offres")
                        .font(MicaboFont.hanken(15, weight: .medium))
                        .foregroundStyle(MicaboColor.info)
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: true))
                .onboardingAppear(index: 2)
            }
            .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)
            Spacer(minLength: 0)

            VStack(spacing: 14) {
                Text("Deux appuis pour commencer, résiliable en quinze secondes.")
                    .font(MicaboFont.hanken(12.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .multilineTextAlignment(.center)

                PaywallCallToAction(isPurchasing: isPurchasing, action: onSubscribe)

                PaywallLegalFooter(onRestore: onRestore)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.sm)
            .onboardingAppear(index: 3)
        }
    }

    /// Le vert ne porte que la partie gratuite. Colorer la phrase entière n'aurait mis en
    /// avant que le prix, colorer le prix aurait mis en avant ce qu'on demande.
    private var pitch: Text {
        let free = Text("Essaie \(PaywallCatalog.freeTrialDays) jours gratuitement, ")
            .foregroundStyle(MicaboColor.accent)
        let price = Text(priceSentence)
            .foregroundStyle(MicaboColor.ink)
        return free + price
    }

    private var priceSentence: String {
        if let monthly = plan.monthlyEquivalent {
            return "puis \(monthly) / mois (facturé \(plan.displayPrice) par an)."
        }
        return "puis \(plan.displayPrice) par \(plan.period.unit)."
    }
}

// MARK: - Second paywall : la comparaison, et le choix de l'offre

/// Le paywall détaillé, ouvert par « Voir toutes les offres » ou par la croix du premier.
///
/// Il répond à la question que le premier écran laisse ouverte — qu'est-ce que ça change,
/// au juste ? — puis met les deux offres côte à côte. La grille est courte à dessein : six
/// lignes se lisent d'un regard, quinze se survolent.
struct PaywallPlansView: View {
    var isPurchasing: Bool
    var onClose: () -> Void
    var onSubscribe: (PaywallPlan) -> Void
    var onRestore: () -> Void

    @State private var selection: PaywallPlan.Kind = PaywallCatalog.recommended.kind

    private var selectedPlan: PaywallPlan {
        PaywallCatalog.plan(selection)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaywallHeader(onClose: onClose)

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Les abonnés Pro\napprennent plus, plus vite")
                        .font(MicaboFont.hanken(26, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.7)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 0)

                    PaywallComparisonTable()
                        .onboardingAppear(index: 1)

                    VStack(spacing: 10) {
                        ForEach(PaywallCatalog.all) { plan in
                            PaywallPlanCard(
                                plan: plan,
                                isSelected: plan.kind == selection,
                                badge: plan.kind == .yearly ? "Économise \(PaywallCatalog.savingsPercent) %" : nil
                            ) {
                                withAnimation(OnboardingMotion.tap) {
                                    selection = plan.kind
                                }
                            }
                        }
                    }
                    .onboardingAppear(index: 2)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            MicaboBottomBar {
                VStack(spacing: 12) {
                    PaywallCallToAction(isPurchasing: isPurchasing) {
                        onSubscribe(selectedPlan)
                    }

                    PaywallLegalFooter(onRestore: onRestore)
                }
            }
        }
    }
}

/// Ce que l'abonnement ouvre, en face de ce que la version gratuite laisse fermé.
private struct PaywallComparisonTable: View {
    private let features = [
        "Toutes les matières",
        "Cours illimités",
        "Cartes générées par l'IA",
        "Import PDF, photos et Word",
        "Répétition espacée et statistiques",
        "Sans publicité"
    ]

    /// Les deux colonnes ont la même largeur : une croix et une coche qui ne tombent pas
    /// l'une sous l'autre transforment un tableau en liste mal alignée.
    private let columnWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 12)

            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                if index > 0 {
                    // Le tableau est posé à même l'ivoire, pas dans un bloc blanc : c'est
                    // le filet du fond qu'il lui faut, l'autre s'y verrait à peine.
                    MicaboHairline(onCanvas: true)
                }
                row(feature)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Text("Gratuit")
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .frame(width: columnWidth)

            Text("PRO")
                .font(MicaboFont.hanken(11.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: columnWidth, height: 26)
                .background(MicaboColor.ink, in: Capsule())
        }
    }

    private func row(_ feature: String) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(MicaboFont.hanken(14.5, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, MicaboSpacing.xs)

            Text("—")
                .font(MicaboFont.hanken(15, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .frame(width: columnWidth)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: columnWidth)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(feature) : réservé à Pro")
    }
}

/// Une offre, dans la liste des offres.
private struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let isSelected: Bool
    let badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: MicaboSpacing.sm) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(MicaboFont.hanken(17, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)

                    Text(plan.caption)
                        .font(MicaboFont.hanken(13, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(plan.displayPrice)
                        .font(MicaboFont.hanken(17, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)

                    Text("\(PaywallCatalog.freeTrialDays) jours offerts")
                        .font(MicaboFont.hanken(13, weight: .medium))
                        .foregroundStyle(MicaboColor.accent)
                }
            }
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? MicaboColor.accentSoft : MicaboColor.surface,
                in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                    .strokeBorder(
                        isSelected ? MicaboColor.ink : MicaboColor.stroke,
                        lineWidth: isSelected ? 1.8 : 1
                    )
            }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(MicaboFont.hanken(11, weight: .bold))
                        .foregroundStyle(MicaboColor.onInk)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 9)
                        .background(MicaboColor.ink, in: Capsule())
                        .offset(x: -12, y: -9)
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityLabel("\(plan.title), \(plan.displayPrice)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
