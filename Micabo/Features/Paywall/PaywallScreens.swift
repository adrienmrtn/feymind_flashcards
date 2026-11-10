import SwiftUI

// MARK: - Le paywall, en un écran

/// **Le paywall, en un seul écran** — celui de l'app et celui de la fin du parcours d'accueil.
///
/// De haut en bas : la scène bleue de la marque, Mika qui sort de son bord bas, le titre (au
/// prénom quand on le connaît) et ce qui a ouvert l'écran ; quatre choses que Pro ouvre ; la
/// note des élèves ; les deux offres, l'annuelle cochée d'avance ; puis, en pied fixe, la
/// phrase du prix, le bouton, la promesse du rappel et les mentions.
///
/// **Rien ne se cache** : la croix est là dès l'ouverture, les deux offres sont côte à côte,
/// et ce qui sera prélevé est écrit au-dessus du bouton. Le prix et l'essai viennent de
/// `PaywallPlan` (la boutique du pays), l'écriture du prix du test `PriceDisplay`.
struct PaywallScreen: View {
    /// Ce qui a ouvert l'écran. Absent à la sortie du parcours d'accueil : on n'y vient de
    /// nulle part, on y arrive.
    var trigger: PaywallTrigger?
    /// Le prénom de l'élève, pour le titre.
    var name: String?
    var isPurchasing: Bool
    /// La dernière réponse de la boutique (`PaywallStorePrices.revision`). Elle ne sert qu'à
    /// redessiner l'écran quand le prix du pays ou l'essai arrivent après son ouverture.
    var storeRevision: Int = 0
    var onClose: () -> Void
    var onSubscribe: (PaywallPlan) -> Void
    var onRestore: () -> Void
    /// Une autre offre est cochée : les statistiques comptent la comparaison.
    var onSelect: (PaywallPlan.Kind) -> Void = { _ in }

    @State private var selection: PaywallPlan.Kind = PaywallCatalog.recommended.kind
    @State private var shown = false
    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var selectedPlan: PaywallPlan {
        PaywallCatalog.plan(selection)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if still {
                    // Les rendus ne dessinent pas ce qui défile : la page entière, posée.
                    content
                } else {
                    ScrollView { content }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                }
            }

            PaywallFooter(
                plan: selectedPlan,
                isPurchasing: isPurchasing,
                storeRevision: storeRevision,
                onSubscribe: { onSubscribe(selectedPlan) },
                onRestore: onRestore
            )
        }
        .onAppear {
            guard !shown else { return }
            if reduceMotion || still {
                shown = true
            } else {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { shown = true }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            PaywallBrandHero(
                title: title,
                subtitle: trigger?.headline ?? L10n.t("ios.pay3.sub", locale: .resolved()),
                mood: trigger == .lessonReady ? .happy : .celebrate,
                onClose: onClose
            )

            VStack(spacing: 22) {
                PaywallBenefits()
                    .entrance(1, shown: shown || still)
                PaywallProofLine()
                    .entrance(2, shown: shown || still)
                VStack(spacing: 12) {
                    ForEach(PaywallCatalog.all) { plan in
                        PaywallPlanOption(
                            plan: plan,
                            isSelected: plan.kind == selection,
                            storeRevision: storeRevision,
                            badge: plan.kind == PaywallCatalog.recommended.kind
                                ? L10n.t("ios.pay3.bestValue", locale: .resolved())
                                : nil
                        ) {
                            guard plan.kind != selection else { return }
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                                selection = plan.kind
                            }
                            onSelect(plan.kind)
                        }
                    }
                }
                .entrance(3, shown: shown || still)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 22)
            .padding(.bottom, MicaboSpacing.lg)
        }
    }

    private var title: String {
        if let name = name?.nilIfBlank {
            return L10n.t("ios.pay3.titleName", locale: .resolved(), vars: ["name": name])
        }
        return L10n.t("ios.pay3.title", locale: .resolved())
    }
}

private extension View {
    /// L'arrivée d'un bloc du paywall, l'un après l'autre.
    func entrance(_ index: Int, shown: Bool) -> some View {
        opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 14)
            .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.07 * Double(index)), value: shown)
    }
}

// MARK: - La scène

/// **La scène du paywall** : le bleu de la marque jusque sous la barre d'état, la croix
/// blanche, « ✦ Micabo Pro », le titre et sa ligne, et Mika en buste qui sort du bord bas —
/// coupé par lui, comme sur l'icône.
struct PaywallBrandHero: View {
    let title: String
    let subtitle: String
    var mood: MikaMood = .celebrate
    var onClose: (() -> Void)?

    @Environment(\.onboardingStill) private var still

    static let mikaSize: CGFloat = 176

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let onClose {
                    PaywallCloseButton(tint: .white, action: onClose)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 5) {
                    MicaboSparkleShape()
                        .fill(Color.white)
                        .frame(width: 11, height: 11)
                    Text("Micabo Pro")
                        .font(MicaboFont.ui(13, weight: .black))
                        .tracking(0.6)
                }
                .foregroundStyle(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.18), in: Capsule())

                Text(title)
                    .font(MicaboFont.display(30))
                    .tracking(MicaboTracking.tight)
                    .foregroundStyle(MicaboStage.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboStage.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.trailing, Self.mikaSize - 40)
            .padding(.top, 4)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
        .background(alignment: .bottomTrailing) {
            MikaMascot(mood: mood, size: Self.mikaSize, frozenAt: still ? 0.5 : nil, backdrop: .blue)
                .offset(x: 10)
        }
        // Sous la barre d'état et quand on tire la page, c'est le fond de `PaywallFlowView`,
        // du même bleu, qui prend le relais.
        .background { MicaboBrandBackdrop() }
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: MicaboStage.heroRadius, bottomTrailingRadius: MicaboStage.heroRadius, style: .continuous))
    }
}

// MARK: - Ce que Pro ouvre

/// **Ce que Pro ouvre, en quatre rangées** : une icône sur sa pastille de couleur, ce que
/// c'est, et une ligne pour le dire concrètement.
struct PaywallBenefits: View {
    private static let rows: [(icon: MicaboIcon, tone: LessonTone)] = [
        (.pdf, .blue),
        (.mika, .lilac),
        (.exam, .pink),
        (.photo, .mint),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(Self.rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 14) {
                    MicaboIconView(icon: row.icon, size: 28)
                        .frame(width: 46, height: 46)
                        .background(row.tone.pale, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(L10n.t("ios.pay3.benefit\(index + 1)", locale: .resolved()))
                            .font(MicaboFont.ui(16, weight: .heavy))
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.t("ios.pay3.benefit\(index + 1).sub", locale: .resolved()))
                            .font(MicaboFont.ui(13.5, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// **La note des élèves, en une ligne** : cinq étoiles du jaune du crayon, la note et le nombre
/// d'élèves — les chiffres du parcours d'accueil (`OnboardingProofFigures`).
struct PaywallProofLine: View {
    var body: some View {
        let locale = UiLocale.resolved()
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MicaboBrand.pencil)
                }
            }
            Text(L10n.t("ios.pay3.proof", locale: locale, vars: [
                "rating": OnboardingProofFigures.text(OnboardingProofFigures.rating, locale: locale),
                "n": OnboardingProofFigures.text(OnboardingProofFigures.students, locale: locale),
            ]))
            .font(MicaboFont.ui(13.5, weight: .bold))
            .foregroundStyle(MicaboColor.inkSecondary)
            .lineLimit(2)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Les offres

/// **Une offre**, comme une carte qu'on coche : le rond à gauche, le nom et ce qui est prélevé,
/// l'essai quand Apple l'honorera ; à droite, le chiffre qu'on compare, dans l'écriture du
/// test de prix (`PriceDisplay`). Cochée, la carte prend le bleu de la marque.
struct PaywallPlanOption: View {
    let plan: PaywallPlan
    let isSelected: Bool
    /// Voir `PaywallScreen.storeRevision` : sans lui, la carte — dont les autres entrées ne
    /// changent pas — garderait le prix et l'essai d'avant la réponse de la boutique.
    let storeRevision: Int
    let badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                check

                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.title)
                        .font(MicaboFont.ui(17, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                    Text(plan.caption)
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(trialLine)
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .foregroundStyle(plan.hasTrial ? MicaboColor.correctInk : MicaboColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 0) {
                    Text(plan.priceHeadline(for: .current))
                        .font(MicaboFont.number(20))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(plan.priceHeadlineUnit(for: .current))
                        .font(MicaboFont.ui(12.5, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? MicaboColor.accentSoft.opacity(0.55) : MicaboColor.surface,
                in: RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MicaboStage.tileRadius, style: .continuous)
                    .strokeBorder(isSelected ? MicaboColor.accent : MicaboColor.stroke, lineWidth: isSelected ? 2 : 1.5)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(MicaboFont.ui(12, weight: .black))
                        .foregroundStyle(Color(hex: 0x3B2A00))
                        .lineLimit(1)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .background(MicaboBrand.pencil, in: Capsule())
                        .offset(x: -14, y: -11)
                }
            }
            .padding(.top, badge == nil ? 0 : 6)
        }
        .buttonStyle(HomePressStyle(scale: 0.98, feedback: .selection))
        .accessibilityLabel("\(plan.title), \(plan.priceHeadline(for: .current)) \(plan.priceHeadlineUnit(for: .current)), \(plan.caption), \(trialLine)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var check: some View {
        ZStack {
            Circle()
                .strokeBorder(isSelected ? MicaboColor.accent : MicaboColor.strokeStrong, lineWidth: 2)
            if isSelected {
                Circle().fill(MicaboColor.accent)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: 24, height: 24)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    /// « 3 jours gratuits », ou pourquoi il n'y en a pas : **déjà utilisé** par ce compte
    /// Apple — un seul essai par groupe d'abonnements —, ou absent de ce pays.
    private var trialLine: String {
        if plan.hasTrial {
            return L10n.t("app.paywall.trialBadge", locale: .resolved(), vars: ["days": "\(plan.trialDays)"])
        }
        return plan.missingTrialReason == .consumed
            ? L10n.t("ios.trialUsed", locale: .resolved())
            : L10n.t("ios.noTrial", locale: .resolved())
    }
}
