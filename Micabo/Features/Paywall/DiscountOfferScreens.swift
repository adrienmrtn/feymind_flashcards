import SwiftUI

// MARK: - L'offre de réduction, en un écran

/// **L'offre de réduction : un seul écran.**
///
/// De haut en bas : la croix et le décompte ; « Offre de bienvenue » ; **« −40 % », géant, en
/// jaune** ; « sur ton année Micabo Pro » ; Mika en fête ; la carte du prix — l'annuel plein
/// barré, le tarif réduit, et ce qu'il fait par mois ou par semaine (`PriceDisplay`) ; puis le
/// bouton jaune, la mention de ce qui sera prélevé, la restauration et les liens.
///
/// Rien à déballer, aucun appui à compter : l'écran arrive ouvert, à la place du paywall
/// qu'on vient de refermer. C'est une vue sans mécanique — `PaywallFlowView` la pose, ouvre
/// la fenêtre et vend ; les rendus la dessinent telle quelle.
///
/// **Rien n'est écrit en dur** : le pourcentage se calcule sur les deux prix de la boutique
/// (`DiscountOffer.savingsPercent`), le décompte descend de l'instant où l'offre s'est
/// affichée pour la première fois. À zéro, le bouton s'éteint : un tarif expiré ne se vend
/// plus.
struct DiscountOfferScreen: View {
    /// Les secondes qui restent sur la fenêtre.
    var remaining: Int
    var isPurchasing: Bool
    /// Où en sont les prix du tarif réduit et de l'annuel qu'il barre.
    var prices: PaywallPriceState = .ready
    /// Ce que la boutique a répondu, quand ce n'est pas un achat : posé sous le bouton.
    var notice: PaywallNotice?
    /// Voir `PaywallScreen.storeRevision`.
    var storeRevision: Int = 0
    /// Faux dans les rendus : le pourcentage est posé, sans son arrivée.
    var animatesArrival = true
    var onClose: () -> Void
    var onBuy: () -> Void
    var onRestore: () -> Void
    var onRetry: () -> Void = {}

    private var plan: PaywallPlan { DiscountOffer.plan }
    private var reference: PaywallPlan { DiscountOffer.reference }
    private var savings: String { DiscountOffer.savingsLabel(DiscountOffer.savingsPercent) }
    private var isOver: Bool { remaining <= 0 }

    var body: some View {
        VStack(spacing: 0) {
            DiscountTopBar(remaining: remaining, isBusy: isPurchasing, onClose: onClose)

            ViewThatFits(in: .vertical) {
                content(mika: PaywallStyle.offerMika)
                content(mika: PaywallStyle.offerMika * 0.7)
                content(mika: nil)
                ScrollView {
                    content(mika: nil)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer
        }
        .background(V3Color.bg.ignoresSafeArea())
    }

    // MARK: Le contenu

    /// `mika` : la taille de Mika, ou `nil` quand l'écran est trop court pour lui.
    private func content(mika: CGFloat?) -> some View {
        VStack(spacing: 0) {
            Text(L10n.t("ios.pay10.offer.badge", locale: .resolved()))
                .font(PaywallStyle.pillQuiet)
                .foregroundStyle(V3Color.ink2)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(V3Color.surface, in: Capsule())

            DiscountPercent(savings: savings, animatesArrival: animatesArrival)
                .padding(.top, 10)

            Text(L10n.t("ios.pay10.offer.sub", locale: .resolved()))
                .font(PaywallStyle.offerSub)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let mika {
                MikaMascot(mood: .celebrate, size: mika)
                    .padding(.top, 8)
                    .accessibilityHidden(true)
            }

            priceCard
                .padding(.top, mika == nil ? 18 : 0)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var priceCard: some View {
        switch prices {
        case .ready:
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    priceColumn
                    Spacer(minLength: 0)
                    equivalentColumn(.trailing)
                }
                VStack(alignment: .leading, spacing: 10) {
                    priceColumn
                    equivalentColumn(.leading)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
        case .loading:
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    bar(width: 104, height: 10)
                    bar(width: 148, height: 22)
                }
                Spacer(minLength: 0)
                bar(width: 92, height: 16)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.t("ios.pay10.loading", locale: .resolved()))
        case .failed(let message):
            Text(message)
                .font(PaywallStyle.rowDetail)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .v3Card()
        }
    }

    /// L'annuel plein, barré, et le tarif réduit dessous : la somme en grand, le reste de la
    /// phrase en petit, dans l'ordre de la langue.
    private var priceColumn: some View {
        let phrase = PaywallPriceTemplate.split("ios.pay10.plan.perYear")
        let old = L10n.t("ios.pay10.plan.perYear", locale: .resolved(), vars: ["price": reference.displayPrice])
        return VStack(alignment: .leading, spacing: 2) {
            Text(old)
                .font(PaywallStyle.offerPriceUnit)
                .foregroundStyle(V3Color.ink3)
                .strikethrough(true, color: V3Color.ink3)
            (Text(phrase.before).font(PaywallStyle.offerPriceUnit).foregroundStyle(V3Color.ink2)
                + Text(plan.displayPrice).font(PaywallStyle.offerPrice).foregroundStyle(V3Color.ink)
                + Text(phrase.after).font(PaywallStyle.offerPriceUnit).foregroundStyle(V3Color.ink2))
        }
        .lineLimit(1)
        .fixedSize()
    }

    /// Ce que le tarif fait par mois ou par semaine, selon le test de prix.
    private func equivalentColumn(_ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(L10n.t("ios.pay10.offer.thatIs", locale: .resolved()))
                .font(PaywallStyle.offerEquivalentLead)
                .foregroundStyle(V3Color.ink2)
            Text("\(plan.priceHeadline(for: .current)) \(plan.priceHeadlineUnit(for: .current))")
                .font(PaywallStyle.offerEquivalent)
                .foregroundStyle(PaywallStyle.keyword)
        }
        .lineLimit(1)
        .fixedSize()
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(V3Color.line)
            .frame(width: width, height: height)
    }

    // MARK: Le pied

    private var footer: some View {
        VStack(spacing: 8) {
            button
            if let notice {
                PaywallNoticeLine(notice: notice)
            } else if isOver {
                PaywallNoticeLine(notice: .info(L10n.t("ios.pay10.offer.ended", locale: .resolved())))
            }
            if prices == .ready {
                Text(L10n.t("ios.pay10.offer.legal", locale: .resolved(), vars: ["price": plan.displayPrice]))
                    .font(PaywallStyle.legal)
                    .foregroundStyle(V3Color.ink3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PaywallLegalLinks(isBusy: isPurchasing, onRestore: onRestore)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(V3Color.bg)
    }

    @ViewBuilder
    private var button: some View {
        let title = L10n.t("ios.pay10.offer.cta", locale: .resolved(), vars: ["percent": savings])
        switch prices {
        case .ready:
            V3Button(
                title,
                kind: PaywallStyle.offerButton,
                isEnabled: !isOver,
                isLoading: isPurchasing,
                action: onBuy
            )
        case .loading:
            V3Button(title, kind: PaywallStyle.offerButton, isLoading: true, action: {})
        case .failed:
            V3Button(L10n.t("ios.retry", locale: .resolved()), action: onRetry)
        }
    }
}

// MARK: - Le grand pourcentage

/// **« −40 % », en géant** : le jaune de l'offre, le même dans les deux thèmes. Il arrive une
/// fois, avec la courbe des réussites — un rien plus petit, puis à sa taille.
struct DiscountPercent: View {
    /// « −40 % », écrit comme la langue l'écrit.
    let savings: String
    var animatesArrival = true

    @State private var arrived: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(savings: String, animatesArrival: Bool = true) {
        self.savings = savings
        self.animatesArrival = animatesArrival
        _arrived = State(initialValue: !animatesArrival)
    }

    var body: some View {
        Text(savings)
            .font(PaywallStyle.percent)
            .foregroundStyle(PaywallStyle.yellow)
            .lineLimit(1)
            .tracking(PaywallStyle.percentTracking)
            .minimumScaleFactor(0.4)
            .scaleEffect(arrived ? 1 : 0.9)
            .accessibilityAddTraits(.isHeader)
            .onAppear {
                guard !arrived else { return }
                withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion)) {
                    arrived = true
                }
            }
    }
}

// MARK: - Le décompte

/// **Le décompte de l'offre**, dans sa pastille : le temps qu'il reste sur les vingt-quatre
/// heures, à la seconde. Les chiffres sont à chasse fixe : la pastille ne change pas de
/// largeur en comptant.
struct DiscountCountdownPill: View {
    /// Les secondes qui restent sur la fenêtre.
    let remaining: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer")
                .foregroundStyle(PaywallStyle.yellow)
                .accessibilityHidden(true)
            Text(verbatim: DiscountOffer.countdown(remaining))
                .monospacedDigit()
                .foregroundStyle(V3Color.ink)
        }
        .font(PaywallStyle.pill)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .frame(minHeight: PaywallStyle.pillHeight)
        .background(V3Color.surface, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(DiscountOffer.countdownLabel(remaining))
    }
}
