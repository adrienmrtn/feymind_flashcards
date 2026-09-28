import SwiftUI

// MARK: - Premier paywall : l'essai, sa frise, et les deux offres

/// **Le paywall d'entrée : « Commence tes 3 jours gratuits. »**
///
/// C'est l'écran de Cal AI et de Quizlet, et il répond dans l'ordre aux trois questions
/// qu'on se pose devant un essai : *qu'est-ce qui se passe aujourd'hui, quand est-ce qu'on
/// me prévient, quand est-ce qu'on me prélève* — une frise de trois moments, avec la date.
/// Puis les deux offres côte à côte, l'annuel coché, « aucun paiement aujourd'hui », et le
/// bouton. Sa croix n'annule pas, elle ouvre la comparaison.
struct PaywallOfferView: View {
    let plan: PaywallPlan
    /// Ce qui a ouvert l'écran, en une ligne. Absent à la sortie du parcours d'accueil.
    var headline: String?
    var isPurchasing: Bool
    var onClose: () -> Void
    var onSeeAllPlans: () -> Void
    var onSubscribe: (PaywallPlan) -> Void
    var onRestore: () -> Void

    @State private var selection: PaywallPlan.Kind = PaywallCatalog.recommended.kind

    private var selectedPlan: PaywallPlan { PaywallCatalog.plan(selection) }

    var body: some View {
        VStack(spacing: 0) {
            PaywallHeader(onClose: onClose)

            ScrollView {
                VStack(spacing: 26) {
                    if let headline {
                        Text(headline)
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.accent)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 7)
                            .padding(.horizontal, 14)
                            .background(OnboardingPalette.accentWash, in: Capsule())
                            .onboardingAppear(index: 0)
                    }

                    OnboardingAccentText(
                        template: L10n.t("ios.paywall.title", locale: .resolved(), vars: ["n": "\(PaywallCatalog.freeTrialDays)"]),
                        size: 32
                    )
                    .onboardingAppear(index: 1)

                    PaywallTrialTimeline()
                        .onboardingAppear(index: 2)

                    PaywallPlanPicker(selection: $selection)
                        .padding(.top, 6)
                        .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 12) {
                    if selectedPlan.hasTrial {
                        PaywallNoPaymentLine()
                    }

                    PaywallCallToAction(isPurchasing: isPurchasing, plan: selectedPlan) {
                        onSubscribe(selectedPlan)
                    }

                    Text(PaywallPitch.finePrint(for: selectedPlan))
                        .font(MicaboFont.ui(11.5, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    PaywallLegalFooter(onRestore: onRestore)
                }
                .onboardingAppear(index: 4)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

/// **Aujourd'hui, le rappel, le prélèvement.** Trois ronds reliés par un trait, le premier
/// en violet parce que c'est maintenant, le dernier avec la date parce que c'est la seule
/// chose qu'on peut vérifier avec un calendrier.
struct PaywallTrialTimeline: View {
    private var locale: UiLocale { .resolved() }

    private struct Step: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let detail: String
        let isNow: Bool
    }

    private var steps: [Step] {
        let days = TrialTimeline.freeDays
        return [
            Step(
                icon: "lock.open.fill",
                title: L10n.t("ios.paywall.step.today", locale: locale),
                detail: L10n.t("ios.paywall.step.todayDetail", locale: locale),
                isNow: true
            ),
            Step(
                icon: "bell.fill",
                title: L10n.t("ios.paywall.step.reminder", locale: locale, vars: ["day": "\(max(1, days - 1))"]),
                detail: L10n.t("ios.paywall.step.reminderDetail", locale: locale),
                isNow: false
            ),
            Step(
                icon: "creditcard.fill",
                title: L10n.t("ios.paywall.step.billing", locale: locale, vars: ["day": "\(days)"]),
                detail: L10n.t("ios.paywall.step.billingDetail", locale: locale, vars: ["date": TrialTimeline.billingDateText(locale: locale)]),
                isNow: false
            ),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Image(systemName: step.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.white)
                            .frame(width: 36, height: 36)
                            .background(step.isNow ? OnboardingPalette.accent : OnboardingPalette.ink, in: Circle())

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(OnboardingPalette.cardStrong)
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                                .padding(.vertical, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(OnboardingPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(step.detail)
                            .font(MicaboFont.ui(13.5, weight: .regular))
                            .foregroundStyle(OnboardingPalette.gray)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 6)
                    .padding(.bottom, index < steps.count - 1 ? 22 : 0)

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Second paywall : la comparaison, et le choix de l'offre

/// Le paywall détaillé, ouvert par la croix du premier.
///
/// Il répond à la question que le premier écran laisse ouverte — qu'est-ce que ça change,
/// au juste ? — avec la grille de Coconote : la colonne Pro en violet, six coches, des
/// tirets en face. Puis les deux offres, et le même bouton.
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
                    Text(L10n.t("ios.paywallPlansTitle", locale: .resolved()))
                        .font(OnboardingPalette.title(30))
                        .foregroundStyle(OnboardingPalette.ink)
                        .tracking(-0.8)
                        .lineSpacing(-2)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 0)

                    PaywallComparisonTable()
                        .onboardingAppear(index: 1)

                    PaywallPlanPicker(selection: $selection)
                        .padding(.top, 6)
                        .onboardingAppear(index: 2)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 12) {
                    if selectedPlan.hasTrial {
                        PaywallNoPaymentLine()
                    }

                    PaywallCallToAction(isPurchasing: isPurchasing, plan: selectedPlan) {
                        onSubscribe(selectedPlan)
                    }

                    Text(PaywallPitch.finePrint(for: selectedPlan))
                        .font(MicaboFont.ui(11.5, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    PaywallLegalFooter(onRestore: onRestore)
                }
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

/// **Ce que Pro ouvre, en face de ce que la version gratuite laisse fermé.** La colonne
/// Pro est une bande violette qui descend sur toute la hauteur du tableau, et les coches
/// s'y alignent : c'est la grille de Coconote, et elle se lit sans lire.
private struct PaywallComparisonTable: View {
    private var features: [String] {
        (1...6).map { L10n.t("ios.paywallFeat\($0)", locale: .resolved()) }
    }

    private let columnWidth: CGFloat = 64

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 4)

            ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                row(feature, isLast: index == features.count - 1)
            }
        }
        .background(alignment: .trailing) {
            // La bande violette, sous la colonne Pro.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(OnboardingPalette.accentWash)
                .frame(width: columnWidth + 8)
                .padding(.trailing, -4)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(L10n.t("ios.paywallFree", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .semibold))
                .foregroundStyle(OnboardingPalette.gray)
                .frame(width: columnWidth, height: 36)

            Text("PRO")
                .font(MicaboFont.ui(12, weight: .bold))
                .tracking(1)
                .foregroundStyle(OnboardingPalette.accent)
                .frame(width: columnWidth, height: 36)
        }
    }

    private func row(_ feature: String, isLast: Bool) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, MicaboSpacing.xs)

            Text("—")
                .font(MicaboFont.ui(15, weight: .regular))
                .foregroundStyle(OnboardingPalette.grayLight)
                .frame(width: columnWidth)

            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(OnboardingPalette.white)
                .frame(width: 24, height: 24)
                .background(OnboardingPalette.accent, in: Circle())
                .frame(width: columnWidth)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(OnboardingPalette.cardStrong)
                    .frame(height: 1)
                    .padding(.trailing, columnWidth * 2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("ios.featureLockedAria", locale: .resolved(), vars: ["feature": feature]))
    }
}
