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

    /// **Le grand titre du héros** (lot 12, refonte) : une promesse courte, à l'élève — son
    /// plan pour son examen, l'examen en bleu clair. Sans examen : « Ton plan est prêt. »
    static func headline(profile: PaywallProfile, locale: UiLocale = .resolved()) -> PaywallEmphasis {
        guard let exam = profile.examPhrase(locale: locale) else {
            return PaywallEmphasis(text: L10n.t("ios.pay10.title.plan", locale: locale), highlight: nil)
        }
        return PaywallEmphasis(
            text: L10n.t("ios.pay10.title.planExam", locale: locale, vars: ["exam": exam]),
            highlight: exam
        )
    }

    /// **La ligne sous le grand titre : ce qu'on propose.** « Essaie-le 3 jours,
    /// gratuitement. » seulement si l'essai est réellement offert ; sinon « Débloque-le avec
    /// Micabo Pro. »
    static func promise(offersTrial: Bool, trialDays: Int, locale: UiLocale = .resolved()) -> String {
        offersTrial
            ? L10n.t("ios.pay10.title.trial", locale: locale, vars: ["n": "\(trialDays)"])
            : L10n.t("ios.pay10.title.noTrial", locale: locale)
    }

    /// **La chronologie de l'essai, en une ligne** : « Rien à payer aujourd'hui · je te
    /// préviens le 14 novembre ». Le rappel ne s'écrit que s'il partira (`reminder` non nul) ;
    /// la date et la somme du premier paiement sont dans la mention sous le bouton.
    static func trialLine(
        reminder: Date?,
        locale: UiLocale = .resolved(),
        calendar: Calendar = .current
    ) -> String {
        let today = L10n.t("ios.pay10.nothingToday", locale: locale)
        guard let reminder else { return today }
        let warn = L10n.t("ios.pay12.remindOn", locale: locale, vars: [
            "date": PaywallTimeline.dayText(reminder, locale: locale, calendar: calendar),
        ])
        return "\(today) · \(warn)"
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
/// **Lot 12, refait : trois zones nettes, et on voit d'abord le titre, puis le bouton.**
/// 1. **Le héros** : Mika grand et heureux sur son halo, la marque « Micabo PRO » et la croix
///    discrète dans la barre ; une promesse courte en très grand titre (« Ton plan pour le
///    Bac est prêt. »), et ce qu'on propose dessous (« Essaie-le 3 jours, gratuitement. »).
///    Derrière une porte de l'app, le titre est ce que Mika dit de la porte.
/// 2. **Ce qu'il gagne** : trois bénéfices, une ligne et un pictogramme chacun, tirés des
///    vraies limites du gratuit (`PaywallFeature`) — la ligne de la porte en tête. Puis
///    l'essai en une ligne : « Rien à payer aujourd'hui · je te préviens le 14 novembre ».
/// 3. **Le pied léger** (`PaywallFooter`), un tiers de l'écran au plus : les deux formules
///    côte à côte, l'annuelle cochée avec sa remise ; le bouton ; une mention — ce qui sera
///    prélevé, et quand ; les liens en petit.
///
/// **Rien ne se cache, rien ne ment** : la croix est là dès l'ouverture, et l'essai ne
/// s'annonce — promesse, ligne verte, bouton, mention — que si Apple l'accordera à ce compte
/// (`PaywallPlan.hasTrial`). Le prix et l'essai viennent de la boutique du pays, l'écriture du
/// prix du test `PriceDisplay`.
///
/// **Tout tient sans défiler quand l'écran le permet** (`PaywallDensity`, Mika et le titre
/// rapetissent) ; sinon le contenu défile et le pied reste fixe.
struct PaywallScreen: View {
    /// Ce qui a ouvert l'écran. Absent à la sortie du parcours d'accueil : on n'y vient de
    /// nulle part, on y arrive.
    var trigger: PaywallTrigger?
    /// Le prénom de l'élève (les statistiques et l'offre qui suit le lisent ; le titre parle
    /// de son examen).
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

    var body: some View {
        PaywallSafeFrame { area in
            VStack(spacing: 0) {
                PaywallTopBar(isBusy: isPurchasing, onClose: onClose)

                ViewThatFits(in: .vertical) {
                    content(.regular)
                    content(.compact)
                    content(.tight)
                    ScrollView {
                        content(.tight)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // **Les formules et le bouton sont dans le pied fixe** : quoi qu'il arrive au
                // contenu au-dessus (une langue longue, un petit écran), ce qu'on achète, son
                // prix et le bouton restent visibles sans défiler.
                PaywallFooter(
                    plans: plans,
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
        .background(PaywallBackdrop())
        .task {
            guard context.reminderKept == nil else { return }
            reminderAllowed = await TrialEndReminder.canBeKept()
        }
    }

    // MARK: Le héros et ce qu'il gagne

    private func content(_ density: PaywallDensity) -> some View {
        VStack(spacing: 0) {
            PaywallHeroMika(mood: showsTrialHeader ? .celebrate : .wink, size: density.mikaSize)

            PaywallTitle(title: heroTitle, size: density.titleSize, alignment: .center)
                .padding(.top, density.titleGap)

            Text(PaywallCopy.promise(offersTrial: selectedPlan.hasTrial, trialDays: selectedPlan.trialDays))
                .font(PaywallStyle.heroText)
                .foregroundStyle(PaywallStyle.keyword)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            PaywallBenefits(
                features: PaywallFeature.shown(for: showsTrialHeader ? nil : trigger, count: PaywallDensity.benefitCount),
                spacing: density.benefitSpacing
            )
            .padding(.top, density.sectionGap)

            if let trialLine {
                PaywallTrialLine(text: trialLine)
                    .padding(.top, density.sectionGap)
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
    }

    /// Le grand titre : la promesse du plan ; derrière une porte, ce que Mika dit d'elle.
    private var heroTitle: PaywallEmphasis {
        if let trigger, !showsTrialHeader {
            return PaywallCopy.hook(for: trigger)
        }
        return PaywallCopy.headline(profile: context.profile)
    }

    /// L'essai en une ligne, seulement quand il est réellement offert et les prix connus.
    private var trialLine: String? {
        guard selectedPlan.hasTrial, prices == .ready else { return nil }
        let reminder = reminderKept
            ? TrialEndReminder.fireDate(purchasedAt: context.now, trialDays: selectedPlan.trialDays)
            : nil
        return PaywallCopy.trialLine(reminder: reminder)
    }

    // MARK: Les formules

    /// Les deux formules, côte à côte ; l'annuelle d'abord, cochée, avec sa remise.
    @ViewBuilder
    private var plans: some View {
        switch prices {
        case .ready:
            HStack(alignment: .top, spacing: PaywallStyle.planSpacing) {
                ForEach(PaywallCatalog.all) { plan in
                    let recommended = plan.kind == PaywallCatalog.recommended.kind
                    PaywallPlanCard(
                        plan: plan,
                        isSelected: plan.kind == selection,
                        storeRevision: storeRevision,
                        savings: recommended ? savingsLabel : nil
                    ) {
                        select(plan.kind)
                    }
                    .disabled(isPurchasing)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        case .loading:
            PaywallPlanSkeleton()
        case .failed(let message):
            PaywallPriceFailure(message: message)
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

// MARK: - Le fond et le héros

/// **Le fond des écrans qui vendent** : le marine de l'app, éclairé d'en haut d'un dégradé
/// discret de sa teinte — le bleu de l'app pour le paywall et la bienvenue, le jaune de la
/// remise pour l'offre. Le bas reste le fond de l'app : le pied s'y pose sans couture.
struct PaywallBackdrop: View {
    var tone: Color = V3Color.accent

    var body: some View {
        ZStack {
            V3Color.bg
            LinearGradient(
                colors: [tone.opacity(0.30), tone.opacity(0.10), tone.opacity(0)],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.55)
            )
        }
        .ignoresSafeArea()
    }
}

/// **Mika en grand, sur son halo** : le visuel fort du haut de l'écran. Le halo est un fond :
/// il déborde sans prendre de place.
struct PaywallHeroMika: View {
    var mood: MikaMood
    var size: CGFloat
    var tone: Color = V3Color.accent

    var body: some View {
        MikaMascot(mood: mood, size: size)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(RadialGradient(
                        colors: [tone.opacity(0.45), tone.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.85
                    ))
                    .frame(width: size * 1.7, height: size * 1.7)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Ce qu'il gagne

extension PaywallFeature {
    /// Ce que Pro ouvre, en une ligne : la phrase d'un bénéfice (lot 12, refonte).
    var benefitKey: String {
        switch self {
        case .lessons: "ios.pay12.benefit.lessons"
        case .mika: "ios.pay12.benefit.mika"
        case .exams: "ios.pay12.benefit.exams"
        case .practice: "ios.pay12.benefit.practice"
        case .pdf: "ios.pay12.benefit.pdf"
        }
    }
}

/// **Trois bénéfices, une ligne chacun** : un pictogramme deux tons, une phrase. Le bloc est
/// centré, ses lignes alignées à gauche.
struct PaywallBenefits: View {
    let features: [PaywallFeature]
    var spacing: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(features) { feature in
                HStack(spacing: 12) {
                    PaywallGlyph(
                        symbol: feature.symbol,
                        tone: feature.tone,
                        size: PaywallStyle.benefitGlyph,
                        column: PaywallStyle.benefitGlyphColumn
                    )
                    Text(L10n.t(feature.benefitKey, locale: .resolved()))
                        .font(PaywallStyle.heroText)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// **L'essai, en une ligne verte** : rien à payer aujourd'hui, et le jour du rappel.
struct PaywallTrialLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .accessibilityHidden(true)
            Text(text)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(PaywallStyle.trialLine)
        .foregroundStyle(PaywallStyle.free)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Les offres

/// **Une offre, en petite carte** : son nom, le chiffre qu'on compare (dans l'écriture du test
/// `PriceDisplay`) et ce qui part vraiment du compte. Les deux cartes sont côte à côte ;
/// cochée, la carte prend le filet et le lavis de l'accent. La remise de l'annuelle est une
/// pastille jaune posée sur son coin.
struct PaywallPlanCard: View {
    let plan: PaywallPlan
    let isSelected: Bool
    /// Voir `PaywallScreen.storeRevision` : sans lui, la carte garderait le prix d'avant la
    /// réponse de la boutique.
    let storeRevision: Int
    /// « −81 % » ; `nil` pour une offre sans remise à annoncer.
    let savings: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(plan.title)
                    .font(PaywallStyle.planName)
                    .foregroundStyle(isSelected ? V3Color.ink : V3Color.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                // **Le prix ne se coupe jamais** : il rapetisse plutôt.
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(plan.priceHeadline(for: .current))
                        .font(PaywallStyle.cardPrice)
                        .foregroundStyle(V3Color.ink)
                    Text(plan.priceHeadlineUnit(for: .current))
                        .font(PaywallStyle.planDetail)
                        .foregroundStyle(V3Color.ink2)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(plan.caption)
                    .font(PaywallStyle.planDetail)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .v3Card(selected: isSelected, radius: PaywallStyle.planRadius)
            .overlay(alignment: .topTrailing) {
                if let savings {
                    PaywallYellowPill(horizontal: 8, vertical: 2) {
                        Text(savings)
                            .font(PaywallStyle.badge)
                    }
                    .fixedSize()
                    .padding(.trailing, 10)
                    .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PaywallStyle.planRadius, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        let price = "\(plan.priceHeadline(for: .current)) \(plan.priceHeadlineUnit(for: .current))"
        return [plan.title, savings, price, plan.caption].compactMap { $0 }.joined(separator: ", ")
    }
}

/// **Les deux offres, pendant que la boutique répond** : leurs silhouettes, à leur place et à
/// leur taille. L'écran n'est jamais vide, et rien ne saute quand les prix arrivent.
private struct PaywallPlanSkeleton: View {
    var body: some View {
        HStack(spacing: PaywallStyle.planSpacing) {
            ForEach(0 ..< PaywallCatalog.all.count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    bar(width: 64, height: 10)
                    bar(width: 92, height: 18)
                    bar(width: 110, height: 10)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: PaywallStyle.planCardHeight, alignment: .topLeading)
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

    var body: some View {
        Text(message)
            .font(PaywallStyle.planDetail)
            .foregroundStyle(V3Color.ink2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: PaywallStyle.planCardHeight)
            .v3Card(radius: PaywallStyle.planRadius)
    }
}

// MARK: - Le pied

/// **Le pied du paywall**, fixe sous la page : les deux formules, le bouton, le message d'un
/// achat qui n'a pas abouti, **une** mention — ce qui sera prélevé, et quand — puis la
/// restauration et les liens, en petit.
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
        VStack(spacing: 10) {
            plans
            button
                .padding(.top, 4)
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
        .padding(.top, 14)
        .padding(.bottom, bottomGap)
        .frame(maxWidth: .infinity)
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

/// **Trois serrages pour un même écran** : le paywall prend le premier qui tient sans défiler
/// (`ViewThatFits`). Mika et le titre rapetissent, l'air entre les zones se resserre ; **rien
/// de ce qui est promis ni de ce qui sera prélevé n'est retiré** — les trois bénéfices, la
/// ligne de l'essai, les formules et la mention restent entiers.
enum PaywallDensity: CaseIterable {
    case regular
    case compact
    case tight

    /// Les bénéfices : trois, jamais plus.
    static let benefitCount = 3

    /// Mika, en grand : le visuel fort du héros.
    var mikaSize: CGFloat {
        switch self {
        case .regular: PaywallStyle.heroMika
        case .compact: PaywallStyle.heroMika * 0.74
        case .tight: PaywallStyle.heroMika * 0.52
        }
    }

    /// Le grand titre.
    var titleSize: CGFloat {
        switch self {
        case .regular: PaywallStyle.titleSize
        case .compact: PaywallStyle.titleMediumSize
        case .tight: PaywallStyle.titleCompactSize
        }
    }

    /// Entre Mika et le titre.
    var titleGap: CGFloat {
        switch self {
        case .regular: 14
        case .compact: 10
        case .tight: 6
        }
    }

    /// Entre deux zones.
    var sectionGap: CGFloat {
        switch self {
        case .regular: 26
        case .compact: 18
        case .tight: 12
        }
    }

    /// Entre deux bénéfices.
    var benefitSpacing: CGFloat {
        switch self {
        case .regular: 14
        case .compact: 10
        case .tight: 7
        }
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

// MARK: - La bienvenue

/// **L'achat a abouti** : Mika fête ça sur son halo, et « C'est parti » rend l'élève à ce
/// qu'il faisait — ce qu'il demandait s'ouvre derrière. Le fond et le héros sont ceux du
/// paywall : les trois écrans vont ensemble.
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
                PaywallHeroMika(mood: .celebrate, size: PaywallStyle.welcomeMika)
                PaywallTitle(
                    title: PaywallCopy.welcome(name: name),
                    size: PaywallStyle.momentSize,
                    alignment: .center
                )
                .padding(.top, 22)
                Text(L10n.t("ios.pay10.welcome.sub", locale: .resolved()))
                    .font(PaywallStyle.heroText)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                if let trialEnd {
                    PaywallTrialLine(text: L10n.t("ios.pay12.welcome.trial", locale: .resolved(), vars: [
                        "date": PaywallTimeline.dayText(trialEnd, locale: .resolved()),
                    ]))
                    .padding(.top, 22)
                }
                Spacer(minLength: 24)
                V3Button(L10n.t("ios.pay10.welcome.cta", locale: .resolved()), action: onContinue)
                    .padding(.bottom, area.bottomGap + 8)
            }
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .background(PaywallBackdrop())
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
                PaywallHeroMika(mood: .wave, size: PaywallStyle.welcomeMika * 0.85)
                PaywallTitle(title: title, size: PaywallStyle.momentSize, alignment: .center)
                    .padding(.top, 18)

                VStack(alignment: .leading, spacing: 14) {
                    row(icon: .book, tone: V3Color.iconGreen, text: lesson)
                    row(icon: .crown, tone: V3Color.iconYellow, text: L10n.t("ios.pay12.bye.offer", locale: .resolved()))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)

                Spacer(minLength: 24)
                V3Button(L10n.t(topic == nil ? "ios.pay12.bye.ctaAny" : "ios.pay12.bye.cta", locale: .resolved()), action: onContinue)
                    .padding(.bottom, area.bottomGap + 8)
            }
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .background(PaywallBackdrop())
    }

    private func row(icon: MicaboIcon, tone: Color, text: String) -> some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: icon, size: 26 * 1.35, tint: tone)
                .frame(width: 30, height: 30)
            Text(text)
                .font(PaywallStyle.heroText)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
