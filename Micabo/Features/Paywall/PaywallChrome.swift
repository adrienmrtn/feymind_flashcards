import SwiftUI

/// **Ce que tous les écrans d'abonnement ont en commun** : la croix en haut à gauche, le
/// bouton qui engage, et les mentions du bas.
///
/// Les avoir ici plutôt que recopiés dans chaque écran n'est pas une commodité. Micabo
/// ouvre le paywall à cinq endroits — la fin du parcours, la fiche coupée, le deuxième
/// import, l'entraînement libre, la cinquième carte — et cinq boutons d'abonnement qui ne
/// portent pas le même nom donnent l'impression de cinq offres différentes.

/// La croix, en haut à gauche.
///
/// Elle est **toujours là, et elle ne se fait pas attendre**. Un paywall dont la sortie
/// apparaît au bout de cinq secondes fait fermer l'app au lieu de la faire refuser : on perd
/// l'utilisateur au lieu de perdre l'abonnement. Ce qu'elle fait derrière peut varier — sur
/// le premier paywall elle ouvre le second, sur celui d'une session elle demande confirmation
/// — mais elle réagit toujours au premier appui.
struct PaywallCloseButton: View {
    /// La couleur de la croix : le gris de l'encre sur la page, le blanc sur la scène bleue.
    var tint: Color = OnboardingPalette.gray
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: Circle())
                // La zone touchable fait 44 points, le rond reste calé sur la marge.
                .frame(width: 44, height: 44, alignment: .leading)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .accessibilityLabel(L10n.t("app.a11y.close", locale: .resolved()))
    }
}

/// Bandeau du haut : la croix, et rien d'autre.
struct PaywallHeader: View {
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

/// Le bouton d'abonnement, identique partout où il apparaît.
struct PaywallCallToAction: View {
    var isPurchasing: Bool
    /// Absent : l'écran ne vend que l'annuel. Présent : le libellé suit l'offre.
    var plan: PaywallPlan? = nil
    /// Voir `PaywallScreen.storeRevision` : l'essai peut se révéler consommé après
    /// l'ouverture, et le bouton ne doit plus le promettre.
    var storeRevision: Int = 0
    var action: () -> Void

    /// Le bouton ne promet l'essai que si ce compte y a droit : un « Commencer l'essai »
    /// suivi d'un prélèvement immédiat est la pire façon de découvrir la règle d'Apple.
    private var hasTrial: Bool { (plan ?? PaywallCatalog.recommended).hasTrial }

    var body: some View {
        // **Le bouton de l'offre** : le grand bouton de la marque (`MicaboBrandButtonStyle`),
        // le même sur tous les paywalls, sur Home et sur l'aperçu verrouillé.
        Button {
            guard !isPurchasing else { return }
            action()
        } label: {
            HStack(spacing: 9) {
                if isPurchasing {
                    ProgressView().controlSize(.small).tint(.white)
                }
                Text(isPurchasing
                    ? L10n.t("ios.instant", locale: .resolved())
                    : (hasTrial
                        ? L10n.t("ios.paywallStartTrial", locale: .resolved(), vars: ["n": "\(PaywallCatalog.freeTrialDays)"])
                        : L10n.t("app.paywall.subscribe", locale: .resolved())))
            }
        }
        .buttonStyle(MicaboBrandButtonStyle(minHeight: 58, fontSize: 18))
        .disabled(isPurchasing)
    }
}

/// **Le pied du paywall**, fixe sous la page : la phrase du prix (`PaywallPitch`, dans
/// l'écriture du test `PriceDisplay`), le bouton, la promesse — le rappel avant la fin de
/// l'essai, l'annulation à tout moment — puis les mentions.
struct PaywallFooter: View {
    let plan: PaywallPlan
    var isPurchasing: Bool
    var storeRevision: Int = 0
    var onSubscribe: () -> Void
    var onRestore: () -> Void

    /// **Le rappel ne se promet que s'il sera tenu** (lot 7) : faux seulement quand l'élève a
    /// refusé les notifications à iOS — le rappel ne partirait pas. Jamais demandées, elles le
    /// seront à l'achat de l'essai (`TrialEndReminder`).
    @State private var reminderKept = true

    private var promise: String {
        guard plan.hasTrial else { return L10n.t("ios.paywallCancelAnytime", locale: .resolved()) }
        return L10n.t(reminderKept ? "ios.pay3.reassure" : "ios.paywallCancelAnytime", locale: .resolved())
    }

    var body: some View {
        VStack(spacing: 10) {
            PaywallPitch.text(for: plan)
                .font(MicaboFont.ui(13.5, weight: .semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            PaywallCallToAction(isPurchasing: isPurchasing, plan: plan, storeRevision: storeRevision, action: onSubscribe)

            HStack(spacing: 6) {
                Image(systemName: plan.hasTrial && reminderKept ? "bell.badge.fill" : "checkmark.shield.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MicaboColor.correct)
                Text(promise)
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PaywallLegalFooter(onRestore: onRestore)
        }
        .task { reminderKept = await TrialEndReminder.canBeKept() }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 14)
        .padding(.bottom, MicaboSpacing.xs)
        .frame(maxWidth: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: MicaboRadius.sheet, topTrailingRadius: MicaboRadius.sheet, style: .continuous)
                .fill(MicaboColor.surface)
                .shadow(color: .black.opacity(0.07), radius: 16, y: -6)
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

/// Restauration et mentions légales, en pied de page.
struct PaywallLegalFooter: View {
    var onRestore: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        // **Sur une ligne quand elle tient, sinon l'une sous l'autre** : en allemand et en
        // très grand texte, « Nutzungsbeding… » se coupait, et des conditions qu'on ne peut
        // pas lire ne sont pas des conditions visibles.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                restore
                separator
                terms
                separator
                privacy
            }
            .fixedSize()
            VStack(spacing: 4) {
                restore
                terms
                privacy
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var restore: some View {
        entry(L10n.t("ios.paywallRestore", locale: .resolved()), action: onRestore)
    }

    private var terms: some View {
        entry(L10n.t("ios.paywallTerms", locale: .resolved())) { open(PaywallLinks.terms) }
    }

    private var privacy: some View {
        entry(L10n.t("common.privacy", locale: .resolved())) { open(PaywallLinks.privacy) }
    }

    private var separator: some View {
        Text("·")
            .font(MicaboFont.ui(12, weight: .regular))
            .foregroundStyle(MicaboColor.inkTertiary)
    }

    /// Le gris secondaire de l'app, pas le tertiaire : la restauration et les conditions
    /// doivent se lire sans plisser les yeux (le tertiaire tombait sous 3:1 sur le blanc).
    private func entry(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.ui(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)
                .frame(minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true))
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        openURL(url)
    }
}

/// La phrase qui dit le prix, et la seule de l'app qui le dise.
///
/// **Le test de prix** (`PriceDisplay`) : chaque phrase prend la variante de l'installation,
/// le mois (« 4,17 € / mois ») ou la semaine (« 0,96 € / semaine »), toujours avec la somme
/// prélevée d'un bloc. Le prix, lui, est le même.
enum PaywallPitch {
    /// « Essaie 3 jours gratuitement, puis 4,17 € / mois (facturé 49,99 € par an). »
    ///
    /// Le violet ne porte que la partie gratuite. Colorer la phrase entière n'aurait mis en
    /// avant que le prix, colorer le prix aurait mis en avant ce qu'on demande.
    ///
    /// Sans essai — déjà consommé, ou absent dans ce pays —, il reste le prix, et rien
    /// d'autre : la moitié verte ne s'écrit que si Apple l'honorera.
    static func text(for plan: PaywallPlan, display: PriceDisplay = .current) -> Text {
        let locale = UiLocale.resolved()
        let price = Text(sentence(for: plan, locale: locale, display: display))
            .foregroundStyle(OnboardingPalette.ink)
        guard plan.hasTrial else { return price }
        let free = Text(L10n.t("ios.paywallTryDays", locale: locale, vars: ["n": "\(PaywallCatalog.freeTrialDays)"]))
            .foregroundStyle(OnboardingPalette.accent)
        return free + price
    }

    /// La moitié « prix » de la phrase. Derrière l'essai elle commence par « puis » ; seule,
    /// elle commence par le prix.
    static func sentence(for plan: PaywallPlan, locale: UiLocale = .resolved(), display: PriceDisplay = .current) -> String {
        let afterTrial = plan.hasTrial
        if display == .weekly, let weekly = plan.weeklyEquivalent {
            return L10n.t(
                afterTrial ? "ios.conv.paywallThenYearWeekly" : "ios.conv.paywallPriceYearWeekly",
                locale: locale,
                vars: ["weekly": weekly, "yearly": plan.displayPrice]
            )
        }
        if let monthly = plan.monthlyEquivalent {
            return L10n.t(
                afterTrial ? "ios.paywallThenYear" : "ios.paywallPriceYear",
                locale: locale,
                vars: ["monthly": monthly, "yearly": plan.displayPrice]
            )
        }
        return L10n.t(
            afterTrial ? "ios.paywallThenPeriod" : "ios.paywallPricePeriod",
            locale: locale,
            vars: ["price": plan.displayPrice, "unit": plan.period.unit]
        )
    }

    /// **La phrase du premier paywall** : « Essaie 3 jours gratuitement, puis seulement
    /// 4,17 € / mois ». Le vert porte la partie gratuite, l'encre le prix ; ce qui est
    /// prélevé d'un bloc descend dans la ligne grise du bas (`PaywallPlan.billedLine`).
    ///
    /// Sans essai — déjà utilisé par ce compte, ou absent dans ce pays —, il reste
    /// « Seulement 4,17 € / mois » : la moitié verte ne s'écrit que si Apple l'honorera.
    static func headline(for plan: PaywallPlan, locale: UiLocale = .resolved(), display: PriceDisplay = .current) -> Text {
        guard plan.hasTrial else {
            return Text(headlineSentence(for: plan, locale: locale, display: display)).foregroundStyle(OnboardingPalette.ink)
        }
        // « Essaie **3 jours gratuitement**, puis seulement 4,17 €/mois » : les jours offerts
        // sont surlignés, comme au marqueur.
        let days = "\(PaywallCatalog.freeTrialDays)"
        var lead = AttributedString(L10n.t("ios.paywallTry.lead", locale: locale))
        lead.foregroundColor = OnboardingPalette.ink
        var free = AttributedString(L10n.t("ios.paywallTry.free", locale: locale, vars: ["n": days]))
        free.foregroundColor = MicaboColor.correctInk
        free.backgroundColor = MicaboColor.correctSoft
        var then: AttributedString
        if display == .weekly, let weekly = plan.weeklyEquivalent {
            then = AttributedString(L10n.t("ios.conv.paywallTryThenWeekly", locale: locale, vars: ["weekly": weekly]))
        } else {
            let monthly = plan.monthlyEquivalent ?? plan.displayPrice
            then = AttributedString(L10n.t("ios.paywallTry.then", locale: locale, vars: ["monthly": monthly]))
        }
        then.foregroundColor = OnboardingPalette.ink
        return Text(lead + free + then)
    }

    /// La moitié « prix » de la phrase du premier paywall, sans la somme annuelle.
    static func headlineSentence(for plan: PaywallPlan, locale: UiLocale = .resolved(), display: PriceDisplay = .current) -> String {
        let afterTrial = plan.hasTrial
        if display == .weekly, let weekly = plan.weeklyEquivalent {
            return L10n.t(afterTrial ? "ios.conv.paywallThenOnlyWeekly" : "ios.conv.paywallOnlyWeekly", locale: locale, vars: ["weekly": weekly])
        }
        if let monthly = plan.monthlyEquivalent {
            return L10n.t(afterTrial ? "ios.paywallThenOnly" : "ios.paywallOnly", locale: locale, vars: ["monthly": monthly])
        }
        return L10n.t(
            afterTrial ? "ios.paywallThenPeriod" : "ios.paywallPricePeriod",
            locale: locale,
            vars: ["price": plan.displayPrice, "unit": plan.period.unit]
        )
    }

    /// La ligne grise posée juste au-dessus du bouton.
    static var reassurance: String {
        L10n.t("ios.paywallReassurance", locale: .resolved())
    }
}

// MARK: - Les prix du pays, ou l'attente

/// Ce que `PaywallPriceGate` règle sans dépendre de son contenu : un type générique ne peut
/// pas porter de constantes.
enum PaywallPriceLoading {
    /// Les pauses avant chaque demande des prix : la première part tout de suite, les
    /// suivantes s'espacent. Sept secondes en tout, puis « Réessayer ».
    static let retryDelays: [Duration] = [.zero, .seconds(1), .seconds(2), .seconds(4)]

    /// Vrai quand le paywall peut montrer ses prix : la boutique a répondu pour chacun de ses
    /// produits, ou il n'y a pas de boutique branchée (aperçus, constructions sans clé), et
    /// rien ne viendra.
    static func hasPrices(for productIDs: [String]) -> Bool {
        !PaywallPurchases.isReady || productIDs.allSatisfy { PaywallStorePrices.price(for: $0) != nil }
    }
}

/// **Les prix du pays, ou rien.**
///
/// Quand la boutique n'avait pas encore répondu - un premier lancement sur un réseau lent,
/// un App Store qui tarde -, le paywall montrait les prix écrits en dur : ceux de la France,
/// en euros, à tout le monde. Un prix faux à côté d'un bouton d'achat. Le paywall attend
/// maintenant la réponse, la redemande en espaçant (`PaywallPriceLoading.retryDelays`), puis
/// propose « Réessayer » avec la cause.
///
/// **La croix est là tout de suite** pendant l'attente : on ne retient personne derrière un
/// chargement.
struct PaywallPriceGate<Content: View>: View {
    /// Les produits dont le paywall affiche le prix.
    let productIDs: [String]
    var onClose: () -> Void
    /// Rappelé à chaque réponse de la boutique, avec `PaywallStorePrices.revision` : les
    /// écrans redessinent l'essai et les prix qui arrivent après leur ouverture.
    var onRevision: (Int) -> Void
    let content: () -> Content

    private enum Phase: Equatable {
        case loading
        case failed(String)
        case ready
    }

    @State private var phase: Phase

    init(
        productIDs: [String],
        onClose: @escaping () -> Void,
        onRevision: @escaping (Int) -> Void = { _ in },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.productIDs = productIDs
        self.onClose = onClose
        self.onRevision = onRevision
        self.content = content
        _phase = State(initialValue: PaywallPriceLoading.hasPrices(for: productIDs) ? .ready : .loading)
    }

    var body: some View {
        Group {
            if phase == .ready {
                content()
            } else {
                waiting
            }
        }
        .task { await load() }
    }

    private var waiting: some View {
        VStack(spacing: 0) {
            PaywallHeader(onClose: onClose)
            Spacer(minLength: 0)
            VStack(spacing: 18) {
                if case .failed(let message) = phase {
                    Text(message)
                        .font(MicaboFont.ui(16, weight: .medium))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(L10n.t("ios.retry", locale: .resolved())) {
                        Task { await load() }
                    }
                    .buttonStyle(MicaboSecondaryButtonStyle())
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(OnboardingPalette.accent)
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque : le fond du paywall, bleu en haut, est celui de la page prête.
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    /// Demande les prix jusqu'à ce qu'ils soient là, ou que les essais soient épuisés.
    ///
    /// Déjà là, ils sont relus quand même, sans rien cacher : l'essai d'un compte et un prix
    /// changé dans App Store Connect arrivent par la même réponse.
    @MainActor
    private func load() async {
        if phase == .ready {
            await PaywallPurchases.refreshPrices()
            onRevision(PaywallStorePrices.revision)
            return
        }
        phase = .loading
        var failure: PaywallFailure?
        for delay in PaywallPriceLoading.retryDelays {
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            if Task.isCancelled { return }
            failure = await PaywallPurchases.fetchPrices()
            onRevision(PaywallStorePrices.revision)
            if PaywallPriceLoading.hasPrices(for: productIDs) {
                phase = .ready
                return
            }
        }
        // La boutique a répondu sans ces produits : l'offre n'est pas ouverte dans ce pays.
        phase = .failed((failure ?? .productUnavailable).message)
    }
}
