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
/// Les nombres — trois appuis, vingt-quatre heures, 3,30 € — sont tous dans
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

    @State private var stage: Stage
    /// L'instant d'origine de la minuterie. Posé à l'ouverture du cadeau.
    @State private var startedAt: Date?
    @State private var isPurchasing = false
    @State private var failure: String?

    init(
        startsAtPaywall: Bool = false,
        onDismiss: @escaping () -> Void,
        onSubscribed: @escaping () -> Void
    ) {
        self.startsAtPaywall = startsAtPaywall
        self.onDismiss = onDismiss
        self.onSubscribed = onSubscribed
        _stage = State(initialValue: startsAtPaywall ? .paywall : .gift)
        _startedAt = State(initialValue: startsAtPaywall ? DiscountOffer.begin() : nil)
    }

    var body: some View {
        ZStack(alignment: .top) {
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

// MARK: - La couleur de l'offre

/// **Le dégradé de l'offre** : bleu ciel en haut, blanc en bas.
///
/// Le même sur le cadeau et sur le paywall. Deux bleus à une seconde d'intervalle feraient
/// deux offres, et le paywall aurait l'air d'arriver d'ailleurs que du cadeau qu'on vient
/// d'ouvrir.
///
/// Un `LinearGradient` et non une vue : il sert de fond au pop-up du cadeau **et** à
/// la feuille du tarif, et seul un `ShapeStyle` peut faire les deux.
private enum DiscountWash {
    static let gradient = LinearGradient(
        colors: [MicaboColor.offerWash, MicaboColor.offerWashSoft, MicaboColor.surface],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Premier temps : le cadeau

/// Le cadeau, en **pop-up** : la carte, pas l'écran.
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
                Spacer(minLength: 0)
                DiscountCloseButton(action: onDismiss)
            }

            VStack(spacing: MicaboSpacing.sm) {
                Text("On a un cadeau pour toi")
                    .font(MicaboFont.hanken(26, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.tight)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 0)

                Text("Ton premier cours est écrit. Ouvre-le.")
                    .font(MicaboFont.hanken(15, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .onboardingAppear(index: 1)
            }
            .padding(.horizontal, MicaboSpacing.md)

            Button(action: tap) {
                DiscountGiftBox(lidLift: CGFloat(taps), isBursting: bursting)
                    .frame(width: 176, height: 176)
                    .scaleEffect(squash ? 0.9 : 1)
                    .rotationEffect(.degrees(wobble))
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: Haptics.Press.none))
            .accessibilityLabel("Ouvrir le cadeau")
            .accessibilityHint("Appuie \(DiscountOffer.taps) fois")
            .padding(.top, MicaboSpacing.md)
            .onboardingAppear(index: 2)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(0 ..< DiscountOffer.taps, id: \.self) { index in
                        Capsule()
                            .fill(index < taps ? MicaboColor.offerSky : MicaboColor.offerSky.opacity(0.25))
                            .frame(width: index < taps ? 26 : 9, height: 9)
                    }
                }
                .animation(OnboardingMotion.tap, value: taps)

                Text(remainingTaps == 0 ? "Ça s'ouvre…" : "Encore \(remainingTaps)")
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .contentTransition(.numericText())
            }
            .padding(.top, MicaboSpacing.md)
            .onboardingAppear(index: 3)
        }
        .frame(maxWidth: .infinity)
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
                .fill(MicaboColor.offerSky)
                .frame(width: 132, height: 96)
                .overlay {
                    Rectangle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 18)
                }
                .offset(y: 30)

            // Couvercle
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MicaboColor.offerSkyDeep)
                .frame(width: 150, height: 34)
                .overlay {
                    Rectangle()
                        .fill(Color.white.opacity(0.45))
                        .frame(width: 18)
                }
                .offset(y: -24 + lidOffset)
                .rotationEffect(.degrees(isBursting ? -12 : 0), anchor: .bottomLeading)

            // Nœud
            DiscountBow()
                .fill(MicaboColor.offerSkyDeep)
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
                    .fill(MicaboColor.offerSky.opacity(0.9))
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

/// **Le paywall du cadeau**, dans la feuille native.
///
/// La feuille **est** la languette : plus de voile dessiné par-dessus un plein écran. On
/// la balaye vers le bas pour la refermer, comme n'importe quelle feuille iOS.
///
/// Ce qu'elle ne fait pas est ce qui la fait marcher : pas de liste d'avantages, pas
/// d'illustration, pas de sur-titre. Le cadeau a déjà annoncé l'offre, et ce qu'on doit lire
/// pour décider tient en quatre lignes. Un écran d'offre qui argumente encore est un écran
/// qui n'a pas confiance en son prix.
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
                Spacer(minLength: 0)
                DiscountCloseButton(action: onClose)
            }

            DiscountCountdownPill(startedAt: startedAt)
                .padding(.top, MicaboSpacing.xxs)
                .onboardingAppear(index: 0)

            headline
                .padding(.top, MicaboSpacing.md)
                .onboardingAppear(index: 1)

            priceCard
                .padding(.top, MicaboSpacing.lg)
                .onboardingAppear(index: 2)

            callToAction
                .padding(.top, MicaboSpacing.md)
                .onboardingAppear(index: 3)

            // Le mensuel vend, l'annuel engage : la somme réellement prélevée est écrite
            // sous le bouton, jamais ailleurs qu'à côté de lui.
            Text("\(plan.displayPrice) facturés une fois par an, résiliable sur l'App Store.")
                .font(MicaboFont.hanken(11.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, MicaboSpacing.sm)

            PaywallLegalFooter(onRestore: onRestore)
                .padding(.top, MicaboSpacing.xs)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, MicaboSpacing.sm)
        .padding(.bottom, MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            GeometryReader { proxy in
                Color.clear.preference(key: DiscountPaywallHeightKey.self, value: proxy.size.height)
            }
        }
    }

    /// Le pourcentage porte la couleur, la promesse porte l'encre : ce qu'on retient d'un
    /// coup d'œil est le nombre, et le colorer entièrement le noierait dans une ligne bleue.
    private var headline: some View {
        (
            Text("\(DiscountOffer.savingsPercent)\u{00a0}%")
                .foregroundStyle(MicaboColor.offerSky)
                + Text(" de moins\nRévise plus vite avec Pro")
                .foregroundStyle(MicaboColor.ink)
        )
        .font(MicaboFont.hanken(29, weight: .bold))
        .tracking(MicaboTracking.tight)
        .multilineTextAlignment(.center)
        .lineSpacing(1)
        // « Révise plus vite avec Pro » tient sur une ligne sur un iPhone standard et se
        // resserre d'un cheveu sur les plus petits, plutôt que de passer à trois lignes.
        .minimumScaleFactor(0.85)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var priceCard: some View {
        HStack(spacing: 14) {
            DiscountSeal(percent: DiscountOffer.savingsPercent)
                .frame(width: 68, height: 68)

            VStack(alignment: .leading, spacing: 2) {
                Text(plan.title)
                    .font(MicaboFont.hanken(14.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.offerSky)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(DiscountOffer.monthlyText)
                        .font(MicaboFont.number(26, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)

                    Text("par mois")
                        .font(MicaboFont.hanken(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }

                Text(DiscountOffer.reference.displayPrice)
                    .font(MicaboFont.hanken(15.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .strikethrough(true, color: MicaboColor.inkTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
        .micaboSoftShadow(strength: 0.08)
    }

    private var callToAction: some View {
        Button {
            guard !isPurchasing else { return }
            onSubscribe()
        } label: {
            HStack(spacing: 9) {
                if isPurchasing {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                }
                Text("Commencer avec \(DiscountOffer.savingsPercent)\u{00a0}% de moins")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(
            MicaboPrimaryButtonStyle(
                tint: MicaboColor.offerSky,
                foreground: .white,
                isProminent: true
            )
        )
        .disabled(isPurchasing)
    }
}

/// **La minuterie de l'offre**, en pastille violette.
///
/// Les centièmes défilent, et ce n'est pas de la précision : une minuterie qui bouge à chaque
/// image se regarde, une minuterie qui saute d'une seconde à l'autre se lit une fois puis
/// s'oublie. Elle compte la même fenêtre que la languette — vingt-quatre heures — pour que
/// refermer puis rouvrir ne change pas le temps affiché.
private struct DiscountCountdownPill: View {
    let startedAt: Date

    var body: some View {
        // Vingt images par seconde, cadencées par `TimelineView` : un `Timer` retenu par la
        // vue continuerait de battre après sa disparition.
        TimelineView(.periodic(from: .now, by: 0.05)) { context in
            pill(DiscountOffer.windowMillisRemaining(startedAt: startedAt, now: context.date))
        }
    }

    private func pill(_ left: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            // La police des nombres, comme partout dans Micabo, et des chiffres de largeur
            // fixe : un décompte qui change de largeur à chaque centième ferait trembler la
            // pastille qui le porte.
            Text(DiscountOffer.preciseCountdown(left))
                .font(MicaboFont.number(15, weight: .semibold))
                .monospacedDigit()

            Text(left > 0 ? "restant" : "terminé")
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))
        }
        .foregroundStyle(Color.white)
        .padding(.vertical, 9)
        .padding(.horizontal, 15)
        .background(MicaboColor.offerUrgency, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            left > 0
                ? "Offre réservée, \(DiscountOffer.countdownLabel(left / 1000))"
                : "Offre terminée"
        )
    }
}

/// **Le sceau de la remise** : un disque à douze festons.
///
/// Festonné et non rond, parce qu'un rond bleu avec un nombre dedans est une pastille d'état
/// — la même forme que « 4 à réviser » dans toute l'app. Les festons disent « étiquette
/// collée sur un prix », ce qui est exactement ce que c'est.
private struct DiscountSeal: View {
    let percent: Int

    var body: some View {
        ZStack {
            ScallopedDisc()
                .fill(
                    LinearGradient(
                        colors: [MicaboColor.offerSky, MicaboColor.offerSkyDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 1) {
                Text("Remise")
                    .font(MicaboFont.hanken(9.5, weight: .semibold))

                HStack(alignment: .top, spacing: 0) {
                    Text("\(percent)")
                        .font(MicaboFont.number(20, weight: .bold))

                    Text("%")
                        .font(MicaboFont.hanken(10, weight: .bold))
                        .padding(.top, 2)
                }
            }
            .foregroundStyle(Color.white)
        }
        .accessibilityHidden(true)
    }
}

/// Le contour du sceau.
///
/// Le sommet d'une quadratique est en `(p0 + 2c + p1) / 4` : le point de contrôle se déduit
/// donc de la crête voulue, et non l'inverse. Sans ce calcul, poser les contrôles « à vue »
/// donne des festons d'amplitudes différentes.
private struct ScallopedDisc: Shape {
    var scallops = 12
    /// Amplitude des festons, en fraction du rayon.
    var bump: CGFloat = 0.17

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 / (1 + bump)
        let step = CGFloat.pi * 2 / CGFloat(scallops)

        func point(_ angle: CGFloat, _ distance: CGFloat) -> CGPoint {
            CGPoint(
                x: center.x + distance * cos(angle),
                y: center.y + distance * sin(angle)
            )
        }

        var path = Path()

        for index in 0 ..< scallops {
            let from = point(CGFloat(index) * step, radius)
            let to = point(CGFloat(index + 1) * step, radius)
            let crest = point((CGFloat(index) + 0.5) * step, radius * (1 + bump))
            let control = CGPoint(
                x: 2 * crest.x - (from.x + to.x) / 2,
                y: 2 * crest.y - (from.y + to.y) / 2
            )

            if index == 0 { path.move(to: from) }
            path.addQuadCurve(to: to, control: control)
        }

        path.closeSubpath()
        return path
    }
}

/// La croix de l'offre, en haut à droite.
///
/// À droite et non à gauche comme les autres paywalls : cette carte est une languette, et sur
/// une languette la croix se pose du côté où le pouce ne couvre pas le prix.
private struct DiscountCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MicaboColor.offerSky)
                .frame(width: 44, height: 44, alignment: .trailing)
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

/// Le cadeau, centré, par-dessus ce qu'on lisait. Ce n'est plus un écran : c'est une carte.
private struct DiscountGiftOverlay: View {
    var onOpened: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.36)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            DiscountGiftStage(onOpened: onOpened, onDismiss: onDismiss)
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 22)
                .frame(maxWidth: 400)
                .background(
                    RoundedRectangle(cornerRadius: MicaboRadius.sheet, style: .continuous)
                        .fill(DiscountWash.gradient)
                )
                .micaboSoftShadow(strength: 0.22)
                .padding(.horizontal, 28)
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// Feuille du tarif : elle épouse le contenu au lieu d'un detent trop haut
/// qui laissait un lavabo bleu vide sous les liens.
private struct DiscountPaywallSheet: View {
    var onDismiss: () -> Void
    var onSubscribed: () -> Void

    /// Hauteur de repli : assez pour le bloc, trop courte pour recouvrir Profil.
    @State private var height: CGFloat = 496

    var body: some View {
        DiscountFlowView(
            startsAtPaywall: true,
            onDismiss: onDismiss,
            onSubscribed: onSubscribed
        )
        .onPreferenceChange(DiscountPaywallHeightKey.self) { value in
            guard value > 200 else { return }
            let next = min(max(value + 32, 440), 530)
            if abs(next - height) > 2 { height = next }
        }
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
        .presentationBackground(DiscountWash.gradient)
    }
}

private struct DiscountPaywallHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// **Ouvre l'offre cadeau par-dessus l'écran courant.**
    ///
    /// Deux présentations, et l'ordre compte. Le cadeau est un **pop-up** : une carte
    /// centrée, pas un écran. Le tarif qui suit est une **feuille native**, balayable
    /// vers le bas — plus de languette dessinée à la main sur un plein écran.
    ///
    /// La croix marque l'offre comme vue — c'est ce qui fait apparaître la languette.
    /// Sans ça, la grande carte reviendrait à chaque fiche et le décompte n'aurait
    /// pas de sens.
    func micaboDiscountOffer(_ presentation: Binding<DiscountPresentation?>) -> some View {
        overlay {
            if presentation.wrappedValue == .gift {
                DiscountGiftOverlay(
                    onOpened: { presentation.wrappedValue = .paywall },
                    onDismiss: {
                        DiscountOffer.markSeen()
                        presentation.wrappedValue = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(OnboardingMotion.enter, value: presentation.wrappedValue == .gift)
        .sheet(
            isPresented: Binding(
                get: { presentation.wrappedValue == .paywall },
                set: { isPresented in
                    guard !isPresented else { return }
                    DiscountOffer.markSeen()
                    presentation.wrappedValue = nil
                }
            )
        ) {
            DiscountPaywallSheet(
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

/// **Le décompte des vingt-quatre heures**, collé au bord droit.
///
/// Une languette, pas une pastille dans le coin : elle ne recouvre plus le bouton de
/// session. Un appui rouvre le paywall — pas le cadeau : on ne fait pas déballer deux fois.
///
/// Elle compte en secondes, pas en centièmes : sur vingt-quatre heures, des centièmes qui
/// défilent dans un coin de l'écran sont un clignotant.
struct DiscountBadge: View {
    let startedAt: Date
    var onOpen: () -> Void

    @State private var left: Int = DiscountOffer.windowSeconds

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 8) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 16, weight: .semibold))

                Text("OFFRE")
                    .font(MicaboFont.hanken(9, weight: .bold))
                    .tracking(MicaboTracking.caps)
                    .foregroundStyle(Color.white.opacity(0.82))

                Text(DiscountOffer.countdown(left))
                    .font(MicaboFont.number(11, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.white)
            .padding(.top, 14)
            .padding(.bottom, 13)
            .padding(.leading, 10)
            .padding(.trailing, 8)
            .frame(minWidth: 56)
            .background(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0,
                    style: .continuous
                )
                .fill(MicaboColor.offerSky)
            )
            .micaboSoftShadow(strength: 0.18)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .soft))
        .accessibilityLabel("Rouvrir l'offre, \(DiscountOffer.countdownLabel(left))")
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
