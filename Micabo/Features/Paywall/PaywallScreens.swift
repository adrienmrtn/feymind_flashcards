import SwiftUI

// MARK: - Premier paywall : une seule offre, une seule phrase

/// Le paywall d'entrée.
///
/// Il ne montre **qu'une offre et qu'un prix**, et c'est tout son intérêt : à l'instant où
/// l'on sort du parcours, une grille de comparaison demande de choisir avant d'avoir décidé
/// d'acheter. La phrase dit les deux choses qu'on veut savoir — c'est gratuit trois jours,
/// ça coûtera tant par mois —, la ligne grise du bas dit ce qui est prélevé d'un bloc, et
/// « Voir toutes les offres » ouvre la grille à ceux qui la cherchent.
///
/// **La typographie est celle de l'app** : le titre dans la graisse des titres, le bouton
/// d'encre. Sous la phrase du prix, ce que Pro ouvre, puis l'étude de Harvard ; le bouton
/// reste en bas, toujours visible.
struct PaywallOfferView: View {
    let plan: PaywallPlan
    /// Ce qui a ouvert l'écran, en une ligne. Absent à la sortie du parcours d'accueil : on
    /// n'y vient de nulle part, on y arrive.
    var headline: String?
    var isPurchasing: Bool
    /// La dernière réponse de la boutique (`PaywallStorePrices.revision`). Elle ne sert qu'à
    /// redessiner l'écran quand le prix du pays ou l'essai arrivent après son ouverture.
    var storeRevision: Int = 0
    var onClose: () -> Void
    var onSeeAllPlans: () -> Void
    var onSubscribe: () -> Void
    var onRestore: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// **La croix n'arrive qu'après quatre secondes.** Le temps de lire la phrase : une
    /// sortie visible avant qu'on ait lu ce qu'on quitte se prend par réflexe. La feuille,
    /// elle, se balaie toujours vers le bas.
    @State private var showsClose = false

    static let closeDelay: Duration = .seconds(4)

    var body: some View {
        VStack(spacing: 0) {
            PaywallHeader(onClose: onClose)
                .opacity(showsClose ? 1 : 0)
                .allowsHitTesting(showsClose)
                .animation(.easeOut(duration: 0.35), value: showsClose)

            ScrollView {
                VStack(spacing: 20) {
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

                    PaywallHero(size: 108)
                        .onboardingAppear(index: 1)

                    PaywallPitch.headline(for: plan, locale: i18n.locale)
                        .font(OnboardingPalette.title(31))
                        .tracking(-0.6)
                        .lineSpacing(-1)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingAppear(index: 2)

                    PaywallFeatureList()
                        .onboardingAppear(index: 3)

                    // L'étude de Harvard, sous ce que Pro ouvre : la preuve après la promesse.
                    ResearchQuoteCard(compact: true)
                        .onboardingAppear(index: 3)

                    Button(action: onSeeAllPlans) {
                        Text(i18n.t("ios.paywallSeeAll"))
                            .font(MicaboFont.ui(16, weight: .bold))
                            .foregroundStyle(OnboardingPalette.accent)
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: true))
                    .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            PaywallFooter(plan: plan, isPurchasing: isPurchasing, storeRevision: storeRevision, onSubscribe: onSubscribe, onRestore: onRestore)
                .onboardingAppear(index: 4)
        }
        .task {
            try? await Task.sleep(for: Self.closeDelay)
            guard !Task.isCancelled else { return }
            showsClose = true
        }
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
    /// Voir `PaywallOfferView.storeRevision`.
    var storeRevision: Int = 0
    var onClose: () -> Void
    var onSubscribe: (PaywallPlan) -> Void
    var onRestore: () -> Void

    @State private var selection: PaywallPlan.Kind = PaywallCatalog.recommended.kind
    /// **La croix des formules arrive deux secondes après l'écran**, le temps de voir les deux
    /// offres côte à côte. Le balayage de la feuille, lui, referme toujours.
    @State private var showsClose = false

    static let closeDelay: Duration = .seconds(2)

    private var selectedPlan: PaywallPlan {
        PaywallCatalog.plan(selection)
    }

    var body: some View {
        VStack(spacing: 0) {
            PaywallHeader(onClose: onClose)
                .opacity(showsClose ? 1 : 0)
                .allowsHitTesting(showsClose)
                .animation(.easeOut(duration: 0.35), value: showsClose)
                .task {
                    try? await Task.sleep(for: Self.closeDelay)
                    guard !Task.isCancelled else { return }
                    showsClose = true
                }

            // **Le second paywall a la forme du premier** : la couronne, un titre centré, puis
            // les offres en cartes de l'app, ce que Pro ouvre, et la recherche.
            ScrollView {
                VStack(spacing: 20) {
                    PaywallHero(size: 104)
                        .onboardingAppear(index: 0)

                    OnboardingAccentText(template: L10n.t("ios.paywallPlansTitle", locale: .resolved()), size: 31, alignment: .center)
                        .onboardingAppear(index: 1)

                    VStack(spacing: 12) {
                        ForEach(PaywallCatalog.all) { plan in
                            PaywallPlanCard(
                                plan: plan,
                                isSelected: plan.kind == selection,
                                storeRevision: storeRevision,
                                badge: plan.kind == .yearly
                                    ? L10n.t("ios.paywallSave", locale: .resolved(), vars: ["pct": "\(PaywallCatalog.savingsPercent)"])
                                    : nil
                            ) {
                                withAnimation(OnboardingMotion.select) {
                                    selection = plan.kind
                                }
                            }
                        }
                    }
                    .onboardingAppear(index: 2)

                    PaywallFeatureList()
                        .onboardingAppear(index: 3)

                    ResearchQuoteCard(compact: true)
                        .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            PaywallFooter(
                plan: selectedPlan,
                isPurchasing: isPurchasing,
                storeRevision: storeRevision,
                onSubscribe: { onSubscribe(selectedPlan) },
                onRestore: onRestore
            )
        }
    }
}

/// **La couronne de Pro**, en tête des deux paywalls : elle arrive en ressort sur son halo,
/// flotte et brille, et trois des choses que Pro ouvre — un PDF, un quiz, un examen — se
/// posent autour d'elle l'une après l'autre. Plus de Mika ici : l'offre parle d'elle-même.
///
/// Toutes les icônes restent sous 85 points : dessinées en 256 pixels, elles sont nettes
/// jusque-là et floues au-delà.
struct PaywallHero: View {
    var size: CGFloat = 124

    @State private var shown = false
    @State private var float = false
    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var crown: CGFloat { min(84, size * 0.66) }
    private var satellite: CGFloat { min(40, size * 0.32) }

    /// Les trois satellites : l'icône, sa place autour de la couronne, son retard.
    private var satellites: [(icon: MicaboIcon, x: CGFloat, y: CGFloat, delay: Double)] {
        [
            (.pdf, -size * 0.78, size * 0.12, 0.25),
            (.quiz, size * 0.8, -size * 0.18, 0.4),
            (.exam, size * 0.56, size * 0.36, 0.55),
        ]
    }

    var body: some View {
        let isShown = shown || still
        return ZStack {
            Circle()
                .fill(RadialGradient(colors: [MicaboColor.accent.opacity(0.24), MicaboColor.accent.opacity(0)], center: .center, startRadius: 4, endRadius: size * 0.7))
                .frame(width: size * 1.4, height: size * 1.4)

            ForEach(Array(satellites.enumerated()), id: \.offset) { _, item in
                MicaboIconView(icon: item.icon, size: satellite)
                    .padding(8)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                    .micaboElevation(.card)
                    .rotationEffect(.degrees(item.x < 0 ? -8 : 8))
                    .offset(x: item.x, y: item.y + (float ? -3 : 3))
                    .scaleEffect(isShown ? 1 : 0.3)
                    .opacity(isShown ? 1 : 0)
                    .animation(.spring(duration: 0.5, bounce: 0.45).delay(still ? 0 : item.delay), value: isShown)
            }

            MicaboIconView(icon: .crown, size: crown)
                .shadow(color: MicaboColor.accent.opacity(0.28), radius: 18, y: 10)
                .rotationEffect(.degrees(float ? -4 : 4))
                .offset(y: float ? -5 : 4)
                .scaleEffect(isShown ? 1 : 0.4)
                .opacity(isShown ? 1 : 0)
                .animation(.spring(duration: 0.6, bounce: 0.45), value: isShown)
        }
        .frame(maxWidth: .infinity)
        // **Le halo tient dans le cadre** : plus grand que lui, il débordait au-dessus et la
        // page qui défile le coupait net sous l'en-tête, en une bande droite.
        .frame(height: size * 1.4)
        .accessibilityHidden(true)
        .onAppear {
            shown = true
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(0.6)) { float = true }
        }
    }
}

/// Ce que l'abonnement ouvre, en face de ce que la version gratuite laisse fermé.
private struct PaywallComparisonTable: View {
    /// Ce que Pro ouvre, et ce que le gratuit en laisse : « 1 » leçon, « 1 lot » de
    /// questions, « — » quand le gratuit n'y a pas accès. Une croix partout aurait dit que le
    /// gratuit n'a rien, ce qui est faux.
    private var features: [(title: String, free: String)] {
        (1...5).map {
            (L10n.t("ios.paywallFeat\($0)", locale: .resolved()), L10n.t("ios.paywallFree\($0)", locale: .resolved()))
        }
    }

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
                row(feature.title, free: feature.free)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)

            Text(L10n.t("ios.paywallFree", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .medium))
                .foregroundStyle(OnboardingPalette.grayLight)
                .frame(width: columnWidth)

            Text("PRO")
                .font(MicaboFont.ui(11.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.white)
                .frame(width: columnWidth, height: 26)
                .background(OnboardingPalette.accent, in: Capsule())
        }
    }

    private func row(_ feature: String, free: String) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(MicaboFont.ui(14.5, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, MicaboSpacing.xs)

            Text(free)
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(OnboardingPalette.gray)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: columnWidth)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(OnboardingPalette.accent)
                .frame(width: columnWidth)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("ios.featureLockedAria", locale: .resolved(), vars: ["feature": feature]))
    }
}

/// Une offre, dans la liste des offres.
private struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let isSelected: Bool
    /// Voir `PaywallOfferView.storeRevision` : sans lui, la carte — dont les autres entrées
    /// ne changent pas — garderait le prix et l'essai d'avant la réponse de la boutique.
    let storeRevision: Int
    let badge: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: MicaboSpacing.sm) {
                OnboardingCheck(isOn: isSelected)

                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(MicaboFont.ui(18, weight: .heavy))
                        .foregroundStyle(OnboardingPalette.ink)

                    Text(plan.caption)
                        .font(MicaboFont.ui(13, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 3) {
                    // Le mois en gras, son unité juste à côté sur la même ligne de base :
                    // c'est le chiffre qu'on compare, et il ne se lit qu'avec son unité.
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text(plan.headlinePrice)
                            .font(MicaboFont.number(20))
                            .foregroundStyle(OnboardingPalette.ink)

                        Text(plan.headlineUnit)
                            .font(MicaboFont.ui(12, weight: .medium))
                            .foregroundStyle(OnboardingPalette.gray)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                    Text(trialLine)
                        .font(MicaboFont.ui(13, weight: .medium))
                        .foregroundStyle(plan.hasTrial ? OnboardingPalette.accent : OnboardingPalette.grayLight)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
            .padding(.vertical, 17)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            // La carte de réponse de l'app : blanche, bordée, avec son relief ; bleue quand
            // elle est choisie.
            .onboardingCard(selected: isSelected, radius: 22)
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(MicaboFont.ui(12, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .lineLimit(1)
                        .background(LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .leading, endPoint: .trailing), in: Capsule())
                        .offset(x: -14, y: -11)
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityLabel("\(plan.title), \(plan.headlinePrice) \(plan.headlineUnit), \(plan.caption), \(trialLine)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
