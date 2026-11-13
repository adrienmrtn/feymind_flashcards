import SwiftUI

// MARK: - Ce que l'écran sait

/// **Ce que le paywall lit de l'appareil**, réuni pour que les rendus et les tests puissent
/// le poser à sa place : le profil de l'élève, l'instant (les dates de la chronologie en
/// sortent), si le rappel de fin d'essai pourra partir, et la leçon qu'il a demandée pendant
/// le parcours d'accueil.
struct PaywallContext: Equatable {
    var profile: PaywallProfile
    var now: Date
    /// `nil` : l'écran le demande à iOS (`TrialEndReminder.canBeKept`).
    var reminderKept: Bool?
    /// Le sujet de la première leçon, choisi dans le parcours (`FirstLessonIntent`).
    var topic: String?

    static func current(now: Date = Date()) -> PaywallContext {
        var topic: String?
        if case .topic(let chosen)? = FirstLessonIntent.pending {
            topic = chosen
        }
        return PaywallContext(profile: .current(now: now), now: now, reminderKept: nil, topic: topic)
    }
}

// MARK: - Les mots du paywall

/// **Ce que le paywall écrit**, à part de ce qu'il dessine : le titre, la ligne d'une offre,
/// le bouton et la mention. Des fonctions pures : chaque promesse — « gratuit », « je te
/// préviens », la somme et sa date — se vérifie sans écran.
enum PaywallCopy {
    /// **Le titre de l'en-tête « essai »**, en deux phrases : le plan de l'élève, puis ce
    /// qu'on lui propose, en bleu clair. « Gratuitement » ne s'écrit que si l'essai lui est
    /// réellement offert (`offersTrial`) : qui a déjà pris le sien lit « Débloque-le avec
    /// Micabo Pro. »
    static func title(
        profile: PaywallProfile,
        offersTrial: Bool,
        trialDays: Int,
        locale: UiLocale = .resolved()
    ) -> PaywallEmphasis {
        let lead: String
        if let exam = profile.examPhrase(locale: locale) {
            lead = L10n.t("ios.pay10.title.planExam", locale: locale, vars: ["exam": exam])
        } else {
            lead = L10n.t("ios.pay10.title.plan", locale: locale)
        }
        let accent = offersTrial
            ? L10n.t("ios.pay10.title.trial", locale: locale, vars: ["n": "\(trialDays)"])
            : L10n.t("ios.pay10.title.noTrial", locale: locale)
        return PaywallEmphasis(text: "\(lead)\n\(accent)", highlight: accent)
    }

    /// **L'accroche d'une porte de l'app**, dite par Mika : le catalogue y marque le groupe
    /// de mots à mettre en avant.
    static func hook(for trigger: PaywallTrigger, locale: UiLocale = .resolved()) -> PaywallEmphasis {
        PaywallEmphasis(marked: L10n.t(trigger.hookKey, locale: locale))
    }

    /// **La ligne sous le nom d'une offre : ce qui est prélevé, et à quel rythme**, précédé
    /// des jours gratuits quand ce compte y a droit — « 3 jours gratuits, puis 49,99 € par
    /// an ». Sans essai : « 49,99 € par an », « facturé chaque semaine ».
    static func planDetail(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        let yearly = plan.period == .year
        if plan.hasTrial {
            return L10n.t(
                yearly ? "ios.pay11.plan.trialThenYear" : "ios.pay11.plan.trialThenWeek",
                locale: locale,
                vars: ["n": "\(plan.trialDays)", "price": plan.displayPrice]
            )
        }
        return yearly
            ? L10n.t("ios.pay10.plan.perYear", locale: locale, vars: ["price": plan.displayPrice])
            : plan.caption
    }

    /// **Le bouton dit ce qu'il fait.** Avec essai : « Commencer mes 3 jours gratuits » ;
    /// sans : « S'abonner · 49,99 € par an ». Un « Essayer gratuitement » suivi d'un
    /// prélèvement immédiat est la pire façon de découvrir la règle d'Apple, et un
    /// « Continuer » ne dit pas qu'on paie.
    static func callToAction(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        if plan.hasTrial {
            return L10n.t("ios.pay11.cta.trial", locale: locale, vars: ["n": "\(plan.trialDays)"])
        }
        return L10n.t(
            plan.period == .year ? "ios.pay11.cta.year" : "ios.pay11.cta.week",
            locale: locale,
            vars: ["price": plan.displayPrice]
        )
    }

    /// **La mention sous le bouton : ce qui sera prélevé, et quand.** Avec essai :
    /// « Gratuit jusqu'au 15 novembre, puis 49,99 € par an. Annule quand tu veux. » — la date
    /// est celle de la chronologie. Sans essai : « Payé aujourd'hui : 49,99 €, puis chaque
    /// année. », précédé de « Essai gratuit déjà utilisé. » quand c'est la raison.
    static func legal(
        for plan: PaywallPlan,
        now: Date = Date(),
        locale: UiLocale = .resolved(),
        calendar: Calendar = .current
    ) -> String {
        let yearly = plan.period == .year
        if plan.hasTrial {
            let end = PaywallTimeline.endDate(from: now, trialDays: plan.trialDays)
            return L10n.t(
                yearly ? "ios.pay11.legal.trialYear" : "ios.pay11.legal.trialWeek",
                locale: locale,
                vars: [
                    "date": PaywallTimeline.dayText(end, locale: locale, calendar: calendar),
                    "price": plan.displayPrice,
                ]
            )
        }
        let price = L10n.t(
            yearly ? "ios.pay11.legal.year" : "ios.pay11.legal.week",
            locale: locale,
            vars: ["price": plan.displayPrice]
        )
        guard plan.missingTrialReason == .consumed else { return price }
        return L10n.t("ios.pay10.legal.trialUsed", locale: locale) + " " + price
    }

    /// **Ce que Mika dit sous le titre d'essai** (lot 12) : pourquoi essayer est sans risque.
    /// Le rappel n'est promis que s'il partira (`remindsBeforeEnd`) ; sans essai, il dit que
    /// tout est prêt et qu'on annule quand on veut.
    static func trialMika(
        name: String?,
        remindsBeforeEnd: Bool,
        offersTrial: Bool,
        locale: UiLocale = .resolved()
    ) -> PaywallEmphasis {
        let key: String
        switch (offersTrial, remindsBeforeEnd, name != nil) {
        case (true, true, true): key = "ios.pay12.trial.mika"
        case (true, true, false): key = "ios.pay12.trial.mikaAnon"
        case (_, _, true): key = "ios.pay12.trial.mikaCancel"
        case (_, _, false): key = "ios.pay12.trial.mikaCancelAnon"
        }
        return PaywallEmphasis(marked: L10n.t(key, locale: locale, vars: ["name": name ?? ""]))
    }

    /// « Bienvenue dans Micabo Pro, Lina ! », après l'achat.
    static func welcome(name: String?, locale: UiLocale = .resolved()) -> PaywallEmphasis {
        if let name {
            return PaywallEmphasis(marked: L10n.t("ios.pay10.welcome.title", locale: locale, vars: ["name": name]))
        }
        return PaywallEmphasis(marked: L10n.t("ios.pay10.welcome.titleAnon", locale: locale))
    }
}

/// **La chronologie de l'essai**, en trois étapes datées : aujourd'hui, le rappel, le premier
/// paiement — et son montant.
///
/// **De vraies dates, les mêmes que celles du rappel réellement posé** : l'étape du rappel
/// sort de `TrialEndReminder.fireDate`, celle de la fin du même instant plus la durée de
/// l'essai. Et **l'étape du rappel ne s'écrit que s'il partira** : notifications refusées,
/// ou essai trop court pour avoir une veille, elle est retirée au lieu de promettre.
enum PaywallTimeline {
    enum Kind: String {
        case today
        case reminder
        case end
    }

    struct Step: Identifiable, Equatable {
        let kind: Kind
        let title: String
        let detail: String

        var id: String { kind.rawValue }

        /// Le symbole du système qui la représente, sans « .fill ».
        var symbol: String {
            switch kind {
            case .today: "lock.open"
            case .reminder: "bell"
            case .end: "creditcard"
            }
        }

        /// La teinte de son icône : une couleur par idée.
        var tone: Color {
            switch kind {
            case .today: V3Color.iconBlue
            case .reminder: V3Color.iconYellow
            case .end: V3Color.iconLilac
            }
        }
    }

    /// La longueur au-delà de laquelle le sujet d'une leçon est abrégé.
    static let longestTopic = 40

    /// `price` : ce que coûtera la formule cochée, écrit par la boutique du pays.
    static func steps(
        trialDays: Int,
        price: String,
        now: Date = Date(),
        reminderKept: Bool,
        locale: UiLocale = .resolved(),
        calendar: Calendar = .current
    ) -> [Step] {
        var steps = [
            Step(
                kind: .today,
                title: L10n.t("ios.pay10.timeline.today", locale: locale),
                detail: L10n.t("ios.pay11.tl.todaySub", locale: locale)
            ),
        ]
        if reminderKept, let fire = TrialEndReminder.fireDate(purchasedAt: now, trialDays: trialDays) {
            steps.append(Step(
                kind: .reminder,
                title: dayText(fire, locale: locale, calendar: calendar),
                detail: L10n.t("ios.pay11.tl.reminderSub", locale: locale)
            ))
        }
        steps.append(Step(
            kind: .end,
            title: dayText(endDate(from: now, trialDays: trialDays), locale: locale, calendar: calendar),
            detail: L10n.t("ios.pay11.tl.endSub", locale: locale, vars: ["price": price])
        ))
        return steps
    }

    /// La fin de l'essai : l'instant de l'achat, plus ses jours.
    static func endDate(from now: Date, trialDays: Int) -> Date {
        now.addingTimeInterval(TimeInterval(trialDays) * 86_400)
    }

    /// Un jour, écrit comme on le dirait : « 14 novembre », « November 14 », « 14. November ».
    static func dayText(_ date: Date, locale: UiLocale, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = calendar
        // Le fuseau vient du calendrier, et pas du système : sans lui, un minuit calculé à
        // Paris s'écrit « la veille » dès que l'appareil est réglé plus à l'ouest.
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: date)
    }
}

// MARK: - Le paywall, en un écran

/// **Le paywall, en un seul écran** — celui de l'app et celui de la fin du parcours d'accueil.
///
/// **Lot 11 : il répond, de haut en bas, aux trois questions qu'on se pose en trois
/// secondes.**
/// 1. *C'est pour moi ?* — la marque « Micabo PRO · Pour Lina », puis, selon la porte :
///    le titre du plan (« Ton plan pour le Bac est prêt. ») et ce que l'élève a déclaré en
///    pastilles (l'examen et le temps qui reste, ses matières, sa première leçon) ; ou Mika
///    qui dit ce qui vient de se passer et ce que Pro ouvre là.
/// 2. *J'ai quoi de plus ?* — le tableau Gratuit / PRO, avec les vraies limites de l'app
///    (`PaywallFeature`), la ligne de la porte en tête.
/// 3. *Je paie quoi, et quand ?* — la chronologie datée, qui finit sur le montant du premier
///    paiement ; les deux formules, l'annuelle cochée ; un bouton qui dit les jours
///    gratuits ; la phrase de ce qui sera prélevé, et à quelle date.
///
/// **Rien ne se cache, rien ne ment** : la croix est là dès l'ouverture, et l'essai ne
/// s'annonce — titre, chronologie, coche verte, bouton, mention — que si Apple l'accordera à
/// ce compte (`PaywallPlan.hasTrial`). Le prix et l'essai viennent de la boutique du pays,
/// l'écriture du prix du test `PriceDisplay`.
///
/// **Tout tient sans défiler quand l'écran le permet** (`PaywallDensity`) ; sinon le contenu
/// défile et le pied reste fixe. Le pied reste dans la zone sûre et garde une marge sous les
/// liens quand l'écran n'a pas de barre d'accueil (iPhone SE).
struct PaywallScreen: View {
    /// Ce qui a ouvert l'écran. Absent à la sortie du parcours d'accueil : on n'y vient de
    /// nulle part, on y arrive.
    var trigger: PaywallTrigger?
    /// Le prénom de l'élève, sous la marque.
    var name: String?
    var isPurchasing: Bool
    /// La dernière réponse de la boutique (`PaywallStorePrices.revision`). Elle ne sert qu'à
    /// redessiner l'écran quand le prix du pays ou l'essai arrivent après son ouverture.
    var storeRevision: Int
    var onClose: () -> Void
    var onSubscribe: (PaywallPlan) -> Void
    var onRestore: () -> Void
    /// Une autre offre est cochée : les statistiques comptent la comparaison.
    var onSelect: (PaywallPlan.Kind) -> Void
    /// Où en sont les prix : attendus, absents, ou là.
    var prices: PaywallPriceState
    /// Ce que la boutique a répondu, quand ce n'est pas un achat : posé sous le bouton.
    var notice: PaywallNotice?
    var onRetry: () -> Void
    var context: PaywallContext

    @State private var selection: PaywallPlan.Kind = PaywallCatalog.recommended.kind
    /// **Le rappel ne se promet que s'il sera tenu** : faux seulement quand l'élève a refusé
    /// les notifications à iOS. Jamais demandées, elles le seront à l'achat de l'essai.
    @State private var reminderAllowed = true

    init(
        trigger: PaywallTrigger? = nil,
        name: String?,
        isPurchasing: Bool,
        storeRevision: Int = 0,
        onClose: @escaping () -> Void,
        onSubscribe: @escaping (PaywallPlan) -> Void,
        onRestore: @escaping () -> Void,
        onSelect: @escaping (PaywallPlan.Kind) -> Void = { _ in },
        prices: PaywallPriceState = .ready,
        notice: PaywallNotice? = nil,
        onRetry: @escaping () -> Void = {},
        context: PaywallContext = .current()
    ) {
        self.trigger = trigger
        self.name = name
        self.isPurchasing = isPurchasing
        self.storeRevision = storeRevision
        self.onClose = onClose
        self.onSubscribe = onSubscribe
        self.onRestore = onRestore
        self.onSelect = onSelect
        self.prices = prices
        self.notice = notice
        self.onRetry = onRetry
        self.context = context
    }

    private var selectedPlan: PaywallPlan { PaywallCatalog.plan(selection) }
    private var showsTrialHeader: Bool { PaywallTrigger.showsTrialHeader(trigger) }
    private var reminderKept: Bool { context.reminderKept ?? reminderAllowed }
    /// La chronologie ne se montre que pour un essai réellement offert, prix connus.
    private var showsTimeline: Bool { selectedPlan.hasTrial && prices == .ready }

    var body: some View {
        PaywallSafeFrame { area in
            VStack(spacing: 0) {
                PaywallTopBar(name: name, isBusy: isPurchasing, onClose: onClose)

                ViewThatFits(in: .vertical) {
                    content(.regular)
                    content(.compact)
                    content(.tight)
                    content(.minimal)
                    content(.bare)
                    ScrollView {
                        content(.compact)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // **Les formules et le bouton sont dans le pied fixe** : quoi qu'il arrive au
                // contenu au-dessus (une langue longue, un petit écran), ce qu'on achète, son
                // prix et le bouton restent visibles sans défiler.
                PaywallFooter(
                    plans: plans(short: area.isShort),
                    plan: selectedPlan,
                    now: context.now,
                    prices: prices,
                    isPurchasing: isPurchasing,
                    notice: notice,
                    bottomGap: area.bottomGap,
                    onSubscribe: { onSubscribe(selectedPlan) },
                    onRetry: onRetry,
                    onRestore: onRestore
                )
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
        .task {
            guard context.reminderKept == nil else { return }
            reminderAllowed = await TrialEndReminder.canBeKept()
        }
    }

    // MARK: Le contenu

    private func content(_ density: PaywallDensity) -> some View {
        VStack(alignment: .leading, spacing: density.sectionSpacing) {
            header(density)
            PaywallFeatureTable(
                features: PaywallFeature.shown(for: showsTrialHeader ? nil : trigger, count: density.rows(trialHeader: showsTrialHeader)),
                highlighted: showsTrialHeader ? nil : trigger?.feature,
                rowHeight: density.tableRowHeight
            )
            if showsTimeline, showsTrialHeader || density.keepsDoorTimeline {
                PaywallTimelineStrip(steps: timelineSteps, compact: density.isTight)
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, density.topPadding)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func header(_ density: PaywallDensity) -> some View {
        if let trigger, !showsTrialHeader {
            PaywallMikaLine(line: PaywallCopy.hook(for: trigger), mood: .wink)
        } else {
            VStack(alignment: .leading, spacing: density.headerSpacing) {
                // **La promesse d'abord** : le plan de l'élève, et ce qu'on lui propose.
                PaywallTitle(
                    title: PaywallCopy.title(
                        profile: context.profile,
                        offersTrial: selectedPlan.hasTrial,
                        trialDays: selectedPlan.trialDays
                    ),
                    size: density.titleSize
                )
                // **Puis Mika** (lot 12), qui a construit le plan avec l'élève : il dit pourquoi
                // c'est sans risque — le rappel s'il partira, l'annulation sinon.
                if let size = density.mikaSize {
                    DiscountMikaLine(
                        line: PaywallCopy.trialMika(
                            name: name,
                            remindsBeforeEnd: selectedPlan.hasTrial && reminderKept,
                            offersTrial: selectedPlan.hasTrial
                        ),
                        mood: .proud,
                        size: size
                    )
                }
                if density.showsFacts {
                    PaywallFactsRow(facts: context.profile.facts(topic: context.topic, now: context.now))
                }
            }
        }
    }

    /// La chronologie de l'essai : aujourd'hui, le rappel, le premier paiement et son
    /// montant — celui de la formule cochée.
    private var timelineSteps: [PaywallTimeline.Step] {
        PaywallTimeline.steps(
            trialDays: selectedPlan.trialDays,
            price: selectedPlan.displayPrice,
            now: context.now,
            reminderKept: reminderKept
        )
    }

    /// Les deux formules. `short` : un écran court (iPhone SE), où elles prennent la hauteur
    /// d'une ligne de réponse.
    @ViewBuilder
    private func plans(short: Bool) -> some View {
        let density: PaywallDensity = short ? .tight : .regular
        switch prices {
        case .ready:
            VStack(spacing: PaywallStyle.planSpacing) {
                ForEach(PaywallCatalog.all) { plan in
                    let recommended = plan.kind == PaywallCatalog.recommended.kind
                    PaywallPlanRow(
                        plan: plan,
                        isSelected: plan.kind == selection,
                        storeRevision: storeRevision,
                        savings: recommended ? savingsLabel : nil,
                        detail: PaywallCopy.planDetail(for: plan),
                        height: recommended ? density.planHeight : density.secondaryPlanHeight,
                        prominent: recommended
                    ) {
                        select(plan.kind)
                    }
                    .disabled(isPurchasing)
                }
            }
        case .loading:
            PaywallPlanSkeleton(height: density.planHeight)
        case .failed(let message):
            PaywallPriceFailure(message: message, height: density.planHeight)
        }
    }

    /// « −81 % » : ce que l'annuel fait économiser sur cinquante-deux semaines, calculé sur
    /// les prix du pays. Rien quand le calcul ne dit pas une remise.
    private var savingsLabel: String? {
        let percent = PaywallCatalog.savingsPercent
        return percent > 0 ? DiscountOffer.savingsLabel(percent) : nil
    }

    private func select(_ kind: PaywallPlan.Kind) {
        guard kind != selection else { return }
        withAnimation(MicaboMotion.quick) { selection = kind }
        onSelect(kind)
    }
}

// MARK: - La zone sûre

/// **Le paywall et l'offre restent dans la zone sûre de l'appareil** — sous l'encoche ou la
/// Dynamic Island, au-dessus de la barre d'accueil — et le fond seul déborde.
///
/// Sur un appareil sans barre d'accueil (iPhone SE), la zone sûre s'arrête au bord de
/// l'écran : le pied y garde une marge (`PaywallStyle.bottomGapWithoutHomeBar`) pour que
/// « Restaurer · Conditions » ne colle pas au bord. Avec une barre d'accueil, la zone sûre
/// fait déjà cet espace.
struct PaywallSafeFrame<Content: View>: View {
    @ViewBuilder var content: (PaywallSafeArea) -> Content

    var body: some View {
        GeometryReader { proxy in
            content(PaywallSafeArea(
                bottomGap: proxy.safeAreaInsets.bottom > 0
                    ? PaywallStyle.bottomGapAboveHomeBar
                    : PaywallStyle.bottomGapWithoutHomeBar,
                isShort: proxy.size.height < PaywallStyle.shortScreen
            ))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

/// Ce que la zone sûre dit à l'écran : la marge à garder sous les liens, et si l'écran est
/// court (la hauteur utile d'un iPhone SE).
struct PaywallSafeArea {
    let bottomGap: CGFloat
    let isShort: Bool
}

// MARK: - Les serrages

/// **Cinq serrages pour un même écran** : le paywall prend le premier qui tient sans défiler
/// (`ViewThatFits`). Aéré sur un grand téléphone ; resserré quand la langue est longue ; puis,
/// sur un iPhone SE, sans les pastilles de l'élève, le tableau sur quatre puis trois puis
/// deux lignes. **Rien de ce qui est promis ni de ce qui sera prélevé n'est jamais retiré** :
/// la chronologie de l'essai d'accueil, les formules et la mention restent entières. Derrière
/// une porte, la chronologie compacte part au dernier cran : la ligne de l'offre et la
/// mention disent déjà les jours gratuits et la date.
enum PaywallDensity: CaseIterable {
    case regular
    case compact
    case tight
    case minimal
    case bare

    /// La taille du titre de l'en-tête « essai ».
    var titleSize: CGFloat {
        switch self {
        case .regular: PaywallStyle.titleSize
        case .compact, .tight, .minimal, .bare: PaywallStyle.titleCompactSize
        }
    }

    /// Serré : les trois derniers crans, ceux d'un petit écran.
    var isTight: Bool { self == .tight || self == .minimal || self == .bare }

    /// Les pastilles de ce que l'élève a déclaré : aux deux premiers crans.
    var showsFacts: Bool { !isTight }

    /// **Mika et sa réplique** sous le titre d'essai (lot 12) : à sa taille au premier cran,
    /// plus petit au deuxième et au troisième, retiré ensuite.
    var mikaSize: CGFloat? {
        switch self {
        case .regular: PaywallStyle.trialMika
        case .compact: PaywallStyle.trialMika * 0.86
        case .tight: PaywallStyle.trialMika * 0.78
        case .minimal, .bare: nil
        }
    }

    /// **Les lignes du tableau sous l'en-tête d'essai** : Mika y prend la place d'une ligne
    /// (la quatrième, les séries d'entraînement, reste dans Pro et sur les portes).
    func rows(trialHeader: Bool) -> Int {
        trialHeader && mikaSize != nil ? min(rowCount, 3) : rowCount
    }

    /// Les lignes du tableau : quatre, puis trois, puis deux.
    var rowCount: Int {
        switch self {
        case .regular, .compact, .tight: 4
        case .minimal: 3
        case .bare: 2
        }
    }

    /// La chronologie compacte reste derrière une porte, sauf au dernier cran.
    var keepsDoorTimeline: Bool { self != .bare }

    /// Entre deux blocs.
    var sectionSpacing: CGFloat {
        switch self {
        case .regular: 20
        case .compact: 12
        case .tight: 12
        case .minimal, .bare: 10
        }
    }

    /// Entre le titre et les pastilles.
    var headerSpacing: CGFloat {
        switch self {
        case .regular: 14
        case .compact: 10
        case .tight, .minimal, .bare: 8
        }
    }

    /// Au-dessus du contenu, sous la barre du haut.
    var topPadding: CGFloat {
        switch self {
        case .regular: 14
        case .compact: 8
        case .tight, .minimal, .bare: 4
        }
    }

    /// Une ligne du tableau.
    var tableRowHeight: CGFloat {
        self == .regular ? PaywallStyle.tableRow : PaywallStyle.tableRowTight
    }

    /// La formule recommandée, et l'autre, plus basse.
    var planHeight: CGFloat {
        isTight ? V3Metric.optionHeight : PaywallStyle.planHeight
    }

    var secondaryPlanHeight: CGFloat {
        isTight ? PaywallStyle.secondaryPlanTight : PaywallStyle.secondaryPlanHeight
    }
}

// MARK: - Le titre

/// **Un titre du paywall** : le titre de l'app (`V3Title`), son mot-clé en bleu clair.
struct PaywallTitle: View {
    let title: PaywallEmphasis
    var size: CGFloat
    var alignment: TextAlignment = .leading

    var body: some View {
        V3Title(title.text, highlight: title.highlight, size: size, alignment: alignment)
    }
}

// MARK: - Les offres

/// **Une offre**, comme une ligne qu'on choisit : son nom et la remise qu'elle fait, ce qui
/// est prélevé ; à droite, le chiffre qu'on compare, dans l'écriture du test de prix
/// (`PriceDisplay`). Choisie, la ligne prend le filet et le lavis de l'accent. L'offre
/// recommandée (`prominent`) est plus haute et son prix plus grand : l'œil la lit d'abord.
struct PaywallPlanRow: View {
    let plan: PaywallPlan
    let isSelected: Bool
    /// Voir `PaywallScreen.storeRevision` : sans lui, la ligne — dont les autres entrées ne
    /// changent pas — garderait le prix d'avant la réponse de la boutique.
    let storeRevision: Int
    /// « −81 % », à côté du nom ; `nil` pour une offre sans remise à annoncer.
    let savings: String?
    /// La ligne sous le nom : les jours gratuits, ce qui est prélevé, et à quel rythme.
    let detail: String
    /// La hauteur de la ligne, au moins : elle grandit avec son texte.
    var height: CGFloat = PaywallStyle.planHeight
    var prominent = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    name
                    Text(detail)
                        .font(PaywallStyle.planDetail)
                        .foregroundStyle(V3Color.ink2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // **Le prix ne se coupe jamais** : c'est lui qu'on compare. En allemand et en
                // très grand texte, c'est le nom de l'offre, à gauche, qui passe à la ligne.
                VStack(alignment: .trailing, spacing: 0) {
                    Text(plan.priceHeadline(for: .current))
                        .font(prominent ? PaywallStyle.price : PaywallStyle.priceSecondary)
                        .foregroundStyle(V3Color.ink)
                    Text(plan.priceHeadlineUnit(for: .current))
                        .font(PaywallStyle.priceUnit)
                        .foregroundStyle(V3Color.ink2)
                }
                .lineLimit(1)
                .fixedSize()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: height)
            .v3Card(selected: isSelected, radius: PaywallStyle.planRadius)
            .contentShape(RoundedRectangle(cornerRadius: PaywallStyle.planRadius, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Le nom et sa pastille, côte à côte quand ils tiennent, l'un sous l'autre sinon.
    private var name: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                title
                badge
            }
            VStack(alignment: .leading, spacing: 4) {
                title
                badge
            }
        }
    }

    private var title: some View {
        Text(plan.title)
            .font(PaywallStyle.planTitle)
            .foregroundStyle(V3Color.ink)
            .lineLimit(1)
    }

    @ViewBuilder
    private var badge: some View {
        if let savings {
            PaywallYellowPill {
                Text(savings)
                    .font(PaywallStyle.badge)
            }
            .fixedSize()
        }
    }

    private var accessibilityText: String {
        let price = "\(plan.priceHeadline(for: .current)) \(plan.priceHeadlineUnit(for: .current))"
        return [plan.title, savings, price, detail].compactMap { $0 }.joined(separator: ", ")
    }
}

/// **Les deux offres, pendant que la boutique répond** : leurs silhouettes, à leur place et à
/// leur taille. L'écran n'est jamais vide, et rien ne saute quand les prix arrivent.
private struct PaywallPlanSkeleton: View {
    var height: CGFloat = PaywallStyle.planHeight

    var body: some View {
        VStack(spacing: PaywallStyle.planSpacing) {
            ForEach(0 ..< PaywallCatalog.all.count, id: \.self) { _ in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        bar(width: 96, height: 14)
                        bar(width: 132, height: 10)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 8) {
                        bar(width: 64, height: 16)
                        bar(width: 48, height: 10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: height)
                .v3Card(radius: PaywallStyle.planRadius)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.t("ios.pay10.loading", locale: .resolved()))
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(V3Color.line)
            .frame(width: width, height: height)
    }
}

/// **Les prix ne sont pas venus** : la phrase dit pourquoi, à la place des offres. Le bouton
/// du pied devient « Réessayer », et la croix est toujours là.
private struct PaywallPriceFailure: View {
    let message: String
    var height: CGFloat = PaywallStyle.planHeight

    var body: some View {
        Text(message)
            .font(PaywallStyle.rowDetail)
            .foregroundStyle(V3Color.ink2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: height * 2 + PaywallStyle.planSpacing)
            .v3Card(radius: PaywallStyle.planRadius)
    }
}

// MARK: - Le pied

/// **Le pied du paywall**, fixe sous la page : « Rien à payer aujourd'hui » quand c'est vrai,
/// le bouton, le message d'un achat qui n'a pas abouti, la mention de ce qui sera prélevé et
/// quand, puis la restauration et les liens.
private struct PaywallFooter<Plans: View>: View {
    let plans: Plans
    let plan: PaywallPlan
    let now: Date
    let prices: PaywallPriceState
    let isPurchasing: Bool
    let notice: PaywallNotice?
    var bottomGap: CGFloat
    var onSubscribe: () -> Void
    var onRetry: () -> Void
    var onRestore: () -> Void

    private var isReady: Bool { prices == .ready }

    var body: some View {
        VStack(spacing: 8) {
            plans
                .padding(.bottom, 4)
            if isReady, plan.hasTrial {
                assurance
            }
            button
            if let notice {
                PaywallNoticeLine(notice: notice)
            }
            if isReady {
                Text(PaywallCopy.legal(for: plan, now: now))
                    .font(PaywallStyle.legal)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PaywallLegalLinks(isBusy: isPurchasing, onRestore: onRestore)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 8)
        .padding(.bottom, bottomGap)
        .frame(maxWidth: .infinity)
        .background(V3Color.bg)
    }

    private var assurance: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(PaywallStyle.assurance.weight(.black))
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(L10n.t("ios.pay10.nothingToday", locale: .resolved()))
                .font(PaywallStyle.assurance)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(PaywallStyle.free)
    }

    @ViewBuilder
    private var button: some View {
        switch prices {
        case .ready:
            V3Button(PaywallCopy.callToAction(for: plan), isLoading: isPurchasing, action: onSubscribe)
        case .loading:
            V3Button(PaywallCopy.callToAction(for: plan), isLoading: true, action: {})
        case .failed:
            V3Button(L10n.t("ios.retry", locale: .resolved()), action: onRetry)
        }
    }
}

// MARK: - La bienvenue

/// **L'achat a abouti** : Mika fête ça, et « C'est parti » rend l'élève à ce qu'il faisait —
/// ce qu'il demandait s'ouvre derrière.
struct PaywallWelcomeScreen: View {
    /// Le prénom de l'élève, pour le titre.
    var name: String?
    /// **La fin de l'essai qui vient de commencer** (lot 12), `nil` sans essai : la bienvenue
    /// dit la date, et comment annuler.
    var trialEnd: Date?
    var onContinue: () -> Void

    var body: some View {
        PaywallSafeFrame { area in
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                MikaMascot(mood: .celebrate, size: PaywallStyle.welcomeMika)
                    .accessibilityHidden(true)
                VStack(spacing: 10) {
                    PaywallTitle(
                        title: PaywallCopy.welcome(name: name),
                        size: PaywallStyle.momentSize,
                        alignment: .center
                    )
                    Text(L10n.t("ios.pay10.welcome.sub", locale: .resolved()))
                        .font(PaywallStyle.momentSub)
                        .foregroundStyle(V3Color.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                if let trialEnd {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .font(V3Font.title)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(V3Color.yellow)
                            .accessibilityHidden(true)
                        Text(L10n.t("ios.pay12.welcome.trial", locale: .resolved(), vars: [
                            "date": PaywallTimeline.dayText(trialEnd, locale: .resolved()),
                        ]))
                        .font(V3Font.support)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .v3Card()
                    .padding(.top, 22)
                }
                Spacer(minLength: 24)
                V3Button(L10n.t("ios.pay10.welcome.cta", locale: .resolved()), action: onContinue)
                    .padding(.bottom, area.bottomGap + 8)
            }
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .background(V3Color.bg.ignoresSafeArea())
    }
}

// MARK: - La sortie propre

/// **L'offre refusée, à la fin du parcours d'accueil** (lot 12) : Mika ne retient personne. Il
/// dit ce qui reste vrai — la première leçon est offerte, le prix réduit attend sur l'accueil
/// jusqu'à la fin de son décompte — et ouvre l'app sur cette leçon. Aucun reproche, aucune
/// urgence de plus.
struct PaywallFarewellScreen: View {
    var name: String?
    /// Le sujet de la première leçon, quand il a été écrit.
    var topic: String?
    var onContinue: () -> Void

    private var title: PaywallEmphasis {
        if let name {
            return PaywallEmphasis(marked: L10n.t("ios.pay12.bye.title", locale: .resolved(), vars: ["name": name]))
        }
        return PaywallEmphasis(marked: L10n.t("ios.pay12.bye.titleAnon", locale: .resolved()))
    }

    private var lesson: String {
        if let topic {
            return L10n.t("ios.pay12.bye.lesson", locale: .resolved(), vars: ["topic": topic])
        }
        return L10n.t("ios.pay12.bye.lessonAny", locale: .resolved())
    }

    var body: some View {
        PaywallSafeFrame { area in
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                MikaMascot(mood: .wave, size: PaywallStyle.welcomeMika * 0.85)
                    .accessibilityHidden(true)
                PaywallTitle(title: title, size: PaywallStyle.momentSize, alignment: .center)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 14) {
                    row(icon: .book, tone: V3Color.iconGreen, text: lesson)
                    row(icon: .crown, tone: V3Color.iconYellow, text: L10n.t("ios.pay12.bye.offer", locale: .resolved()))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .v3Card()
                .padding(.top, 22)

                Spacer(minLength: 24)
                V3Button(L10n.t(topic == nil ? "ios.pay12.bye.ctaAny" : "ios.pay12.bye.cta", locale: .resolved()), action: onContinue)
                    .padding(.bottom, area.bottomGap + 8)
            }
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .background(V3Color.bg.ignoresSafeArea())
    }

    private func row(icon: MicaboIcon, tone: Color, text: String) -> some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: icon, size: 26 * 1.35, tint: tone)
                .frame(width: 30, height: 30)
            Text(text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
