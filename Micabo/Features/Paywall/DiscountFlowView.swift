import SwiftUI

/// **Le cadeau du premier cours, et le paywall qu'il ouvre.**
///
/// Deux temps, et l'ordre compte. D'abord un cadeau posé sur la fiche qu'on vient
/// d'obtenir : il ne dit pas de prix, il dit qu'il y a quelque chose à ouvrir, et il
/// demande trois appuis. Ensuite le tarif réduit, avec sa minuterie.
///
/// Pourquoi trois appuis plutôt qu'un bouton « Voir mon cadeau » : un paywall qui s'ouvre
/// tout seul se referme tout seul. Trois appuis, c'est une seconde et demie où la main
/// participe — et une offre qu'on a déballée se lit avant de se fermer.
///
/// Les nombres — trois appuis, une heure, vingt-quatre heures, 3,30 € — sont tous dans
/// `DiscountOffer`, qui est le miroir du module partagé avec le web.
struct DiscountFlowView: View {
    /// Vrai quand on rouvre depuis la pastille : le cadeau ne se déballe qu'une fois.
    var startsAtPaywall: Bool = false
    var onDismiss: () -> Void
    var onSubscribed: () -> Void

    @Environment(ProAccess.self) private var pro: ProAccess?

    private enum Stage {
        case gift
        case paywall
    }

    @State private var stage: Stage = .gift
    /// L'instant d'origine des deux minuteries. Posé à l'ouverture du cadeau.
    @State private var startedAt: Date?
    @State private var isPurchasing = false
    @State private var failure: String?

    var body: some View {
        ZStack {
            switch stage {
            case .gift:
                DiscountGiftStage(onOpened: openOffer, onDismiss: onDismiss)
                    .transition(.paywallStage)

            case .paywall:
                DiscountPaywallStage(
                    startedAt: startedAt ?? Date(),
                    isPurchasing: isPurchasing,
                    onClose: onDismiss,
                    onSubscribe: { Task { await buy() } },
                    onRestore: { Task { await restore() } }
                )
                .transition(.paywallStage)
            }
        }
        .animation(OnboardingMotion.page, value: stage)
        .onAppear {
            guard startsAtPaywall else { return }
            startedAt = DiscountOffer.begin()
            stage = .paywall
        }
        .alert("Oups", isPresented: .constant(failure != nil)) {
            Button("Fermer", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    /// Le troisième appui. L'instant se pose ici — pas à l'import : un décompte qui a
    /// commencé sans témoin est un décompte déjà perdu.
    private func openOffer() {
        startedAt = DiscountOffer.begin()
        stage = .paywall
    }

    /// **Seul un achat confirmé ouvre Pro.** `unavailable` veut dire « je n'ai pas pu
    /// vendre » — et l'accepter ferait de chaque panne de réseau un abonnement offert.
    @MainActor
    private func buy() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        failure = nil

        let outcome = await PaywallPurchases.buy(DiscountOffer.plan)
        isPurchasing = false

        switch outcome {
        case .purchased:
            pro?.unlock()
            Haptics.success()
            onSubscribed()
        case .unavailable:
            failure = PaywallPurchases.isReady
                ? "L'achat n'a pas abouti. Réessaie dans un instant."
                : "L'abonnement n'est pas encore ouvert."
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
            failure = "Aucun abonnement à restaurer sur ce compte."
            return
        }
        pro?.unlock()
        Haptics.success()
        onSubscribed()
    }
}

// MARK: - Premier temps : le cadeau

/// Le cadeau, plein écran, et les trois appuis qui l'ouvrent.
///
/// Chaque appui fait trois choses : la boîte encaisse le coup (elle s'écrase puis rebondit),
/// le couvercle remonte d'un cran, une vibration confirme. Au troisième, les rubans partent
/// et l'écran passe la main. Sans ces trois retours, appuyer trois fois sur une image
/// ressemble à une image qui ne répond pas.
private struct DiscountGiftStage: View {
    var onOpened: () -> Void
    var onDismiss: () -> Void

    @State private var taps = 0
    @State private var squash = false
    @State private var bursting = false

    private var remainingTaps: Int { max(0, DiscountOffer.taps - taps) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DiscountCloseButton(action: onDismiss)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)

            Spacer(minLength: MicaboSpacing.lg)

            VStack(spacing: MicaboSpacing.lg) {
                Text("Nous avons un cadeau pour vous")
                    .font(MicaboFont.hanken(28, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .tracking(MicaboTracking.tight)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 0)

                Text("Votre premier cours est écrit. Ouvrez-le.")
                    .font(MicaboFont.hanken(15, weight: .regular))
                    .foregroundStyle(MicaboColor.onInk.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .onboardingAppear(index: 1)
            }
            .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.md)

            Button(action: tap) {
                DiscountGiftBox(lidLift: CGFloat(taps), isBursting: bursting)
                    .frame(width: 190, height: 190)
                    .scaleEffect(squash ? 0.9 : 1)
                    .rotationEffect(.degrees(wobble))
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: Haptics.Press.none))
            .accessibilityLabel("Ouvrir le cadeau")
            .accessibilityHint("Appuyez \(DiscountOffer.taps) fois")
            .onboardingAppear(index: 2)

            Spacer(minLength: MicaboSpacing.md)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0 ..< DiscountOffer.taps, id: \.self) { index in
                        Capsule()
                            .fill(MicaboColor.onInk.opacity(index < taps ? 1 : 0.3))
                            .frame(width: index < taps ? 26 : 9, height: 9)
                    }
                }
                .animation(OnboardingMotion.tap, value: taps)

                Text(remainingTaps == 0 ? "Ça s'ouvre…" : "Encore \(remainingTaps)")
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.onInk.opacity(0.85))
                    .contentTransition(.numericText())
            }
            .padding(.bottom, MicaboSpacing.xxl)
            .onboardingAppear(index: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MicaboColor.info.ignoresSafeArea())
    }

    /// L'inclinaison alterne d'un appui à l'autre : une boîte qui penche toujours du même
    /// côté a l'air de tomber, pas d'être secouée.
    private var wobble: Double {
        guard squash else { return 0 }
        return taps.isMultiple(of: 2) ? -5 : 5
    }

    private func tap() {
        guard taps < DiscountOffer.taps else { return }

        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            taps += 1
            squash = true
        }
        Haptics.medium()

        // Le rebond : la boîte reprend sa taille juste après avoir encaissé.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.5)) {
                squash = false
            }
        }

        guard taps >= DiscountOffer.taps else { return }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
            bursting = true
        }
        Haptics.success()

        // Le temps que les rubans partent. Passer la main à l'instant du troisième appui
        // ferait disparaître l'animation qu'on vient de déclencher.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onOpened()
        }
    }
}

/// La boîte : un corps, un couvercle qui remonte, un nœud, et des rubans qui partent.
private struct DiscountGiftBox: View {
    /// Nombre d'appuis encaissés. Le couvercle monte d'un cran à chacun.
    var lidLift: CGFloat
    var isBursting: Bool

    private var lidOffset: CGFloat { -lidLift * 7 }

    var body: some View {
        ZStack {
            if isBursting {
                DiscountRibbons()
            }

            // Corps
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(MicaboColor.onInk)
                .frame(width: 132, height: 96)
                .overlay {
                    Rectangle()
                        .fill(MicaboColor.info.opacity(0.35))
                        .frame(width: 18)
                }
                .offset(y: 30)

            // Couvercle
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MicaboColor.onInk)
                .frame(width: 150, height: 34)
                .overlay {
                    Rectangle()
                        .fill(MicaboColor.info.opacity(0.35))
                        .frame(width: 18)
                }
                .offset(y: -24 + lidOffset)
                .rotationEffect(.degrees(isBursting ? -12 : 0), anchor: .bottomLeading)

            // Nœud
            DiscountBow()
                .fill(MicaboColor.onInk)
                .frame(width: 78, height: 34)
                .offset(y: -50 + lidOffset)
                .opacity(isBursting ? 0 : 1)
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.6), value: lidLift)
    }
}

/// Deux boucles, dessinées plutôt que posées en symbole : un `gift.fill` complet aurait sa
/// propre boîte, et on en dessine déjà une.
private struct DiscountBow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midX
        let bottom = rect.maxY

        path.move(to: CGPoint(x: mid, y: bottom))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.25),
            control1: CGPoint(x: mid - rect.width * 0.18, y: bottom - rect.height * 0.9),
            control2: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: mid, y: bottom),
            control1: CGPoint(x: rect.minX, y: bottom),
            control2: CGPoint(x: mid - rect.width * 0.24, y: bottom)
        )

        path.move(to: CGPoint(x: mid, y: bottom))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.25),
            control1: CGPoint(x: mid + rect.width * 0.18, y: bottom - rect.height * 0.9),
            control2: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: mid, y: bottom),
            control1: CGPoint(x: rect.maxX, y: bottom),
            control2: CGPoint(x: mid + rect.width * 0.24, y: bottom)
        )

        return path
    }
}

/// Les rubans du troisième appui. Huit traits qui partent du centre, et c'est tout : des
/// confettis qui retombent demanderaient une simulation pour un demi-tiers de seconde.
private struct DiscountRibbons: View {
    @State private var out = false

    var body: some View {
        ZStack {
            ForEach(0 ..< 8, id: \.self) { index in
                Capsule()
                    .fill(MicaboColor.onInk.opacity(0.9))
                    .frame(width: 6, height: 22)
                    .offset(y: out ? -104 : -34)
                    .rotationEffect(.degrees(Double(index) / 8 * 360))
                    .opacity(out ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.55)) { out = true }
        }
    }
}

// MARK: - Second temps : le tarif réduit

/// Le paywall du cadeau : fond bleu, et une languette blanche en bas.
///
/// La languette n'est pas un ornement. Ce paywall ne vend **qu'une** offre : tout ce qui
/// engage — le prix barré, la somme prélevée, le bouton, les mentions — tient dans un
/// panneau posé sur le bas de l'écran, à portée de pouce, et le bleu au-dessus ne porte que
/// l'argument. Un écran d'offre unique n'a pas de liste à faire défiler.
private struct DiscountPaywallStage: View {
    let startedAt: Date
    var isPurchasing: Bool
    var onClose: () -> Void
    var onSubscribe: () -> Void
    var onRestore: () -> Void

    private var plan: PaywallPlan { DiscountOffer.plan }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                DiscountCloseButton(action: onClose)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)

            Spacer(minLength: MicaboSpacing.md)

            VStack(spacing: MicaboSpacing.md) {
                DiscountCountdownPill(startedAt: startedAt)
                    .onboardingAppear(index: 0)

                Text("Votre cadeau : Pro à \(DiscountOffer.savingsPercent) % de moins")
                    .font(MicaboFont.hanken(27, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .tracking(MicaboTracking.tight)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text(DiscountOffer.monthlyText)
                        .font(MicaboFont.number(56, weight: .bold))
                        .foregroundStyle(MicaboColor.onInk)
                        .tracking(MicaboTracking.display)

                    Text("/ mois")
                        .font(MicaboFont.hanken(17, weight: .semibold))
                        .foregroundStyle(MicaboColor.onInk.opacity(0.8))
                }
                .onboardingAppear(index: 2)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Self.perks, id: \.self) { perk in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(MicaboColor.onInk)

                            Text(perk)
                                .font(MicaboFont.hanken(14.5, weight: .medium))
                                .foregroundStyle(MicaboColor.onInk.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, MicaboSpacing.xs)
                .onboardingAppear(index: 3)
            }
            .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)

            // La languette se mesure elle-même : sa hauteur dépend de la longueur des
            // mentions, et une réserve écrite à la main se serait décalée au premier mot
            // ajouté.
            languette
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MicaboColor.info.ignoresSafeArea())
    }

    /// La languette : le prix qu'on paie vraiment, le bouton, les mentions.
    private var languette: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(MicaboColor.strokeStrong)
                .frame(width: 40, height: 4)

            HStack(spacing: 10) {
                Text(DiscountOffer.reference.displayPrice)
                    .font(MicaboFont.hanken(16, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .strikethrough(true, color: MicaboColor.inkTertiary)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)

                Text("\(plan.displayPrice) / an")
                    .font(MicaboFont.hanken(17, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
            }

            Button {
                guard !isPurchasing else { return }
                onSubscribe()
            } label: {
                HStack(spacing: 9) {
                    if isPurchasing {
                        ProgressView()
                            .controlSize(.small)
                            .tint(MicaboColor.onInk)
                    }
                    Text("Profiter du cadeau")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MicaboPrimaryButtonStyle(isProminent: true))
            .disabled(isPurchasing)

            Text("\(plan.displayPrice) facturés une fois par an. Sans essai, résiliable à tout moment.")
                .font(MicaboFont.hanken(11.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            PaywallLegalFooter(onRestore: onRestore)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.sm)
        .padding(.bottom, MicaboSpacing.md)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: MicaboRadius.sheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: MicaboRadius.sheet,
                style: .continuous
            )
            .fill(MicaboColor.canvas)
            .ignoresSafeArea(edges: .bottom)
        )
        .onboardingAppear(index: 4)
    }

    private static let perks = [
        "Cours illimités, et la fiche entière",
        "Sessions sans coupure à la cinquième carte",
        "Entraînement libre, quand l'examen approche"
    ]
}

/// La minuterie de l'heure, en pastille.
private struct DiscountCountdownPill: View {
    let startedAt: Date

    @State private var left: Int = DiscountOffer.urgencySeconds

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.fill")
                .font(.system(size: 13, weight: .semibold))

            Text(DiscountOffer.countdown(left))
                .font(MicaboFont.number(18, weight: .bold))
                .monospacedDigit()

            Text(left > 0 ? "réservé pour vous" : "dernier appel")
                .font(MicaboFont.hanken(13, weight: .medium))
        }
        .foregroundStyle(MicaboColor.onInk)
        .padding(.vertical, 9)
        .padding(.horizontal, 15)
        .background(MicaboColor.onInk.opacity(0.16), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            left > 0 ? "Offre réservée, \(DiscountOffer.countdownLabel(left))" : "Offre terminée"
        )
        .onAppear { refresh() }
        .task {
            // Une seconde qui tombe, tant que l'écran est là. Un `Timer` retenu par la vue
            // continuerait de battre après sa disparition.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                refresh()
            }
        }
    }

    private func refresh() {
        left = DiscountOffer.urgencyRemaining(startedAt: startedAt)
    }
}

/// La croix du cadeau. Celle du paywall ordinaire est en encre : sur le bleu, elle
/// disparaîtrait, et une sortie qu'on ne voit pas n'est pas une sortie.
private struct DiscountCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 34, height: 34)
                .background(MicaboColor.onInk.opacity(0.18), in: Circle())
                .frame(width: 44, height: 44, alignment: .leading)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel("Fermer")
    }
}

// MARK: - Présentation

/// Par quel bout on entre dans l'offre.
enum DiscountPresentation: String, Identifiable {
    /// Le premier passage : la boîte à déballer.
    case gift
    /// Le retour, depuis la pastille. On ne fait pas déballer deux fois.
    case paywall

    var id: String { rawValue }
}

extension View {
    /// **Ouvre l'offre cadeau par-dessus l'écran courant.**
    ///
    /// En plein écran, comme le paywall ordinaire : une feuille se balaye vers le bas, et
    /// un cadeau qu'on écarte du pouce sans l'avoir ouvert n'a rien dit.
    ///
    /// La croix marque l'offre comme vue — c'est ce qui fait apparaître la pastille. Sans
    /// ça, la grande carte reviendrait à chaque fiche et le décompte n'aurait pas de sens.
    func micaboDiscountOffer(_ presentation: Binding<DiscountPresentation?>) -> some View {
        fullScreenCover(item: presentation) { value in
            DiscountFlowView(
                startsAtPaywall: value == .paywall,
                onDismiss: {
                    DiscountOffer.markSeen()
                    presentation.wrappedValue = nil
                },
                onSubscribed: { presentation.wrappedValue = nil }
            )
        }
    }
}

// MARK: - La pastille, quand le paywall s'est refermé

/// **Le décompte des vingt-quatre heures**, posé au-dessus de la page.
///
/// C'est la différence entre une offre refusée et une offre remise à plus tard, et seule la
/// seconde se vend. Un appui rouvre le paywall — pas le cadeau : on ne fait pas déballer
/// deux fois.
struct DiscountBadge: View {
    let startedAt: Date
    var onOpen: () -> Void

    @State private var left: Int = DiscountOffer.windowSeconds

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16, weight: .semibold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("VOTRE CADEAU")
                        .font(MicaboFont.hanken(10, weight: .bold))
                        .tracking(MicaboTracking.caps)
                        .foregroundStyle(MicaboColor.onInk.opacity(0.75))

                    Text(DiscountOffer.countdown(left))
                        .font(MicaboFont.number(15, weight: .bold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(MicaboColor.onInk)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(MicaboColor.info, in: Capsule())
            .micaboSoftShadow(strength: 0.18)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .soft))
        .accessibilityLabel("Rouvrir le cadeau, \(DiscountOffer.countdownLabel(left))")
        .opacity(left > 0 ? 1 : 0)
        .allowsHitTesting(left > 0)
        .onAppear { refresh() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                refresh()
            }
        }
    }

    private func refresh() {
        left = DiscountOffer.windowRemaining(startedAt: startedAt)
    }
}
