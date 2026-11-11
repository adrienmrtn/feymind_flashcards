import SwiftUI

// MARK: - Le paywall, en un écran

/// **Le paywall, en un seul écran** — celui de l'app et celui de la fin du parcours d'accueil.
///
/// De haut en bas : la scène claire, Mika en buste coupé par son bord bas, le titre (au
/// prénom quand on le connaît) et l'examen qui arrive (`PaywallProfile`) ; ce que Pro ouvre,
/// dit avec les réponses de l'élève ; la recherche, sans chiffre inventé ; les deux offres,
/// l'annuelle cochée d'avance ; puis, en pied fixe, la phrase du prix, **un seul bouton**, la
/// promesse du rappel (réellement posé : `TrialEndReminder`) et les mentions.
///
/// **Mika vit sur le papier de l'app**, crème le jour et nuit la nuit, plus dans une scène
/// bleue : c'est la même DA que les questions du parcours.
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
    /// Les réponses du parcours, relues à l'ouverture.
    @State private var profile = PaywallProfile.current()
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
                withAnimation(MicaboMotion.standard.delay(0.05)) { shown = true }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            PaywallBrandHero(
                title: title,
                subtitle: subtitle,
                mood: trigger == .lessonReady ? .happy : .celebrate,
                onClose: onClose
            )

            VStack(spacing: 22) {
                PaywallBenefits(profile: profile)
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
                            withAnimation(MicaboMotion.quick) {
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

    /// Ce qui a ouvert l'écran, en une ligne ; « Passer en Pro » n'a rien buté, il garde la
    /// ligne générale (son accroche redirait « Micabo Pro » sous la pastille du même nom).
    private var subtitle: String {
        guard let trigger, trigger != .upgrade else {
            return profile.subtitle(locale: .resolved()) ?? L10n.t("ios.pay3.sub", locale: .resolved())
        }
        return trigger.headline
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
            .animation(MicaboMotion.standard.delay(0.05 * Double(index)), value: shown)
    }
}

// MARK: - La scène

/// **La scène du paywall, claire** : une carte du blanc de l'app jusque sous la barre
/// d'état, la croix, « ✦ Micabo Pro » sur sa pastille bleue, le titre et sa ligne, et Mika en
/// buste qui sort du bord bas — coupé par lui, comme sur l'icône. Le jour, son étincelle est
/// bleue ; la nuit, la carte est sombre, l'étincelle blanche et un halo bleu garde sa
/// silhouette (`MikaBackdrop.surface`).
struct PaywallBrandHero: View {
    let title: String
    let subtitle: String
    var mood: MikaMood = .celebrate
    var onClose: (() -> Void)?

    @Environment(\.onboardingStill) private var still

    /// Mika en demi, qui dépasse du bas de l'en-tête (`MikaPeek.hero`).
    static let mikaSize: CGFloat = MikaPeek.hero

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if let onClose {
                    PaywallCloseButton(tint: MicaboColor.inkSecondary, action: onClose)
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
                .background(MicaboBrand.blue, in: Capsule())

                Text(title)
                    .font(MicaboFont.display(30))
                    .tracking(MicaboTracking.tight)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                Text(subtitle)
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.trailing, Self.mikaSize - 8)
            .padding(.top, 4)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, minHeight: 236, alignment: .topLeading)
        .background(alignment: .bottomTrailing) {
            MikaPeek(mood: mood, width: Self.mikaSize, animates: !still)
                .padding(.trailing, 14)
        }
        // Sous la barre d'état et quand on tire la page, c'est le fond de `PaywallFlowView`,
        // du même blanc, qui prend le relais.
        .background(MicaboColor.surface)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: MicaboStage.heroRadius, bottomTrailingRadius: MicaboStage.heroRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 14, y: 6)
    }
}

// MARK: - Ce que Pro ouvre

/// **Ce que Pro ouvre, en quatre rangées** : une icône sur sa pastille de couleur, ce que
/// c'est, et une ligne pour le dire concrètement.
struct PaywallBenefits: View {
    /// Les réponses du parcours : l'objectif, les matières et l'examen remplacent les lignes
    /// générales quand on les connaît.
    var profile = PaywallProfile()

    private static let rows: [(icon: MicaboIcon, tone: LessonTone)] = [
        (.pdf, .blue),
        (.mika, .lilac),
        (.exam, .pink),
        (.photo, .mint),
    ]

    private func sub(_ index: Int) -> String {
        let locale = UiLocale.resolved()
        switch index {
        case 0:
            if let subjects = profile.subjectsLine(locale: locale) {
                return L10n.t("ios.pay5.benefit.subjects", locale: locale, vars: ["subjects": subjects])
            }
        case 2:
            if let exam = profile.examTitle {
                return L10n.t("ios.pay5.benefit.exam", locale: locale, vars: ["exam": exam])
            }
        default:
            break
        }
        return L10n.t("ios.pay3.benefit\(index + 1).sub", locale: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let target = profile.targetGrade {
                goalRow(target: target)
            }
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
                        Text(sub(index))
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

    /// **L'objectif de l'élève, en tête** : la note visée, dans son barème, et d'où il part.
    private func goalRow(target: String) -> some View {
        let locale = UiLocale.resolved()
        return HStack(spacing: 14) {
            MicaboIconView(icon: .trophy, size: 28)
                .frame(width: 46, height: 46)
                .background(LessonTone.yellow.pale, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t("ios.pay5.goal.title", locale: locale, vars: ["grade": target]))
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(profile.currentGrade.map { L10n.t("ios.pay5.goal.sub", locale: locale, vars: ["grade": $0]) }
                    ?? L10n.t("ios.pay5.goal.subAny", locale: locale))
                    .font(MicaboFont.ui(13.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// **La preuve, en une ligne, et sourcée.** Elle disait « 4,8 sur l'App Store · 45 000+
/// élèves » : rien dans le dépôt ne sourçait ces deux chiffres. Elle dit maintenant ce que la
/// recherche a mesuré sur la méthode de Mika (Karpicke & Roediger, Science, 2008 : 80 % retenu
/// en se testant contre 36 % en relisant), sans chiffre à nous.
struct PaywallProofLine: View {
    var body: some View {
        HStack(spacing: 8) {
            MicaboIconView(icon: .diploma, size: 20)
            Text(L10n.t("ios.pay5.proof", locale: .resolved()))
                .font(MicaboFont.ui(13.5, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
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
        .animation(MicaboMotion.quick, value: isSelected)
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
