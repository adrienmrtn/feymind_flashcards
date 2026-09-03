import SwiftUI

/// **Le paywall qui arrête une session au bout de cinq cartes.**
///
/// C'est le seul écran d'abonnement de l'app qui interrompt quelque chose en cours, et il
/// est donc le seul à être écrit autrement. Il ne propose pas, il **tranche** : la session
/// ne reprendra pas sans abonnement, et il le dit dans son titre plutôt que de le laisser
/// découvrir en réappuyant.
///
/// Deux issues, et elles sont toutes les deux écrites en toutes lettres — s'abonner, ou
/// rentrer. **Aucune des deux ne se cache derrière la croix**, parce qu'une sortie qu'il
/// faut deviner n'est pas une sortie : c'est un écran dont on sort en tuant l'app.
///
/// La croix, elle, demande confirmation. C'est le seul endroit de Micabo où une croix
/// pose une question, et c'est justifié : ailleurs elle referme un écran, ici elle
/// abandonne une session commencée.
struct SessionPaywallView: View {
    /// Ce qui vient d'être révisé. Le dire au lieu de l'annoncer en abstrait — « tu as
    /// révisé 5 cartes » plutôt que « limite atteinte » — change ce que l'écran raconte :
    /// un travail fait qui s'arrête, pas une porte fermée au nez.
    let reviewedCount: Int
    var onGoHome: () -> Void
    var onSubscribed: () -> Void

    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isPurchasing = false
    @State private var isAbandoning = false
    /// Ce que la boutique n'a pas pu faire. Un bouton muet passe pour cassé.
    @State private var failure: String?

    private var plan: PaywallPlan { PaywallCatalog.recommended }

    var body: some View {
        ZStack {
            paywall
                .blur(radius: isAbandoning ? 6 : 0)
                .allowsHitTesting(!isAbandoning)

            if isAbandoning {
                AbandonConfirmation(
                    onReturn: { withAnimation(OnboardingMotion.enter) { isAbandoning = false } },
                    onAbandon: onGoHome
                )
                .transition(.opacity)
            }
        }
        .micaboScreenBackground()
        .alert(i18n?.t("app.common.oops") ?? "Oups", isPresented: .constant(failure != nil)) {
            Button(i18n?.t("app.a11y.close") ?? "Fermer", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    // MARK: - Le paywall

    private var paywall: some View {
        VStack(spacing: 0) {
            PaywallHeader {
                withAnimation(OnboardingMotion.enter) { isAbandoning = true }
            }

            Spacer(minLength: MicaboSpacing.lg)

            VStack(spacing: 18) {
                counter
                    .onboardingAppear(index: 0)

                VStack(spacing: 10) {
                    Text(i18n?.t("app.paywall.session.title", ["reviewed": "\(reviewedCount)"])
                        ?? "Tes \(reviewedCount) cartes gratuites\nsont faites.")
                        .font(MicaboFont.hanken(26, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.6)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(i18n?.t("ios.paywallSessionBody")
                        ?? "La session s'arrête là. Micabo Pro la laisse aller jusqu'au bout, tous les jours, sur tous tes cours.")
                        .font(MicaboFont.hanken(14.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                .onboardingAppear(index: 1)

                PaywallPitch.text(for: plan)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 2)
            }
            .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)
            Spacer(minLength: 0)

            VStack(spacing: 12) {
                PaywallCallToAction(isPurchasing: isPurchasing) {
                    Task { await buy() }
                }

                // La sortie est un vrai bouton, pas un lien gris en bas de page : c'est
                // l'une des deux issues de l'écran, elle ne se murmure pas.
                Button(action: onGoHome) {
                    Text(i18n?.t("app.paywall.session.home") ?? "Revenir à l'accueil")
                }
                .buttonStyle(MicaboSecondaryButtonStyle())

                PaywallLegalFooter { Task { await restore() } }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.sm)
            .onboardingAppear(index: 3)
        }
    }

    private var counter: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))

            Text(i18n?.t("app.paywall.session.progress", [
                "reviewed": "\(reviewedCount)",
                "limit": "\(FreeTier.cardsPerSession)"
            ]) ?? "\(reviewedCount) / \(FreeTier.cardsPerSession) cartes révisées")
                .font(MicaboFont.hanken(13, weight: .semibold))
                .monospacedDigit()
        }
        .foregroundStyle(MicaboColor.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(MicaboColor.accentSoft, in: Capsule())
    }

    // MARK: - Achat

    /// **Seul un achat confirmé reprend la session.** Offrir sur `unavailable` ferait de
    /// chaque panne de réseau un abonnement gratuit.
    @MainActor
    private func buy() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        failure = nil

        let outcome = await PaywallPurchases.buy(plan)
        isPurchasing = false

        switch outcome {
        case .purchased:
            pro?.unlock()
            Haptics.success()
            onSubscribed()
        case .unavailable:
            failure = PaywallPurchases.isReady
                ? (i18n?.t("ios.paywallBuyFail") ?? "L'achat n'a pas abouti. Réessaie dans un instant.")
                : (i18n?.t("app.paywall.checkoutClosed") ?? "L'abonnement n'est pas encore ouvert.")
        case .cancelled:
            break
        }
    }

    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        failure = nil

        let outcome = await PaywallPurchases.restore()
        isPurchasing = false

        guard outcome == .purchased else {
            failure = i18n?.t("ios.paywallNoRestore") ?? "Aucun abonnement à restaurer sur ce compte."
            return
        }
        pro?.unlock()
        Haptics.success()
        onSubscribed()
    }
}

/// « Tu es sûr d'abandonner ta progression ? »
///
/// Posée par-dessus le paywall flouté, et pas à sa place : on doit voir qu'on est en train
/// de quitter quelque chose, sinon la question n'a pas de sujet.
private struct AbandonConfirmation: View {
    var onReturn: () -> Void
    var onAbandon: () -> Void
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture(perform: onReturn)

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(MicaboColor.caution)
                    .frame(width: 56, height: 56)
                    .background(MicaboColor.cautionSoft, in: Circle())

                VStack(spacing: 8) {
                    Text(i18n?.t("app.paywall.session.abandonTitle") ?? "Tu es sûr d'abandonner\nta progression ?")
                        .font(MicaboFont.hanken(20, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .tracking(-0.4)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(i18n?.t("app.paywall.session.abandonBody")
                        ?? "Les cartes déjà notées sont enregistrées. Les suivantes attendront ta prochaine session.")
                        .font(MicaboFont.hanken(13.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    Button(action: onReturn) {
                        Text(i18n?.t("ios.paywallBack") ?? "Revenir")
                    }
                    .buttonStyle(MicaboPrimaryButtonStyle())

                    Button(action: onAbandon) {
                        Text(i18n?.t("app.paywall.session.abandonConfirm") ?? "Abandonner la session")
                            .font(MicaboFont.hanken(14, weight: .semibold))
                            .foregroundStyle(MicaboColor.negative)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .warning))
                }
            }
            .padding(MicaboSpacing.lg)
            .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.sheet, style: .continuous))
            .micaboSoftShadow(strength: 0.18)
            .padding(.horizontal, MicaboSpacing.xl)
        }
    }
}
