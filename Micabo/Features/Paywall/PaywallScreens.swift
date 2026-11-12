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

/// **Ce que le paywall écrit**, à part de ce qu'il dessine : le titre, la chronologie de
/// l'essai, la ligne d'une offre, le bouton et la mention. Des fonctions pures : chaque
/// promesse — « gratuitement », « je te préviens », « tu ne paies rien » — se vérifie sans
/// écran.
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

    /// La ligne sous le nom d'une offre : ce qui est prélevé, et à quel rythme. Dans
    /// l'en-tête « contexte », où la chronologie n'est pas là pour le dire, elle porte aussi
    /// les jours gratuits — quand ce compte y a droit.
    static func planDetail(
        for plan: PaywallPlan,
        mentionsTrial: Bool,
        locale: UiLocale = .resolved()
    ) -> String {
        let trial = mentionsTrial && plan.hasTrial
            ? L10n.t("ios.pay10.plan.trialDays", locale: locale, vars: ["n": "\(plan.trialDays)"])
            : nil
        guard plan.period == .year else { return trial ?? plan.caption }
        let perYear = L10n.t("ios.pay10.plan.perYear", locale: locale, vars: ["price": plan.displayPrice])
        guard let trial else { return perYear }
        return "\(perYear) · \(trial)"
    }

    /// **Le bouton ne promet l'essai que si ce compte y a droit** : un « Essayer
    /// gratuitement » suivi d'un prélèvement immédiat est la pire façon de découvrir la règle
    /// d'Apple.
    static func callToAction(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        L10n.t(plan.hasTrial ? "ios.pay10.cta.trial" : "ios.pay10.cta.continue", locale: locale)
    }

    /// **La mention sous le bouton** : ce qui sera prélevé, quand, et la sortie. Avec essai :
    /// « 3 jours gratuits, puis 49,99 € par an. Annule quand tu veux. » Sans : la somme
    /// seule, précédée de « Essai gratuit déjà utilisé. » quand c'est la raison.
    static func legal(for plan: PaywallPlan, locale: UiLocale = .resolved()) -> String {
        let yearly = plan.period == .year
        if plan.hasTrial {
            return L10n.t(
                yearly ? "ios.pay10.legal.trialYear" : "ios.pay10.legal.trialWeek",
                locale: locale,
                vars: ["n": "\(plan.trialDays)", "price": plan.displayPrice]
            )
        }
        let price = L10n.t(
            yearly ? "ios.pay10.legal.year" : "ios.pay10.legal.week",
            locale: locale,
            vars: ["price": plan.displayPrice]
        )
        guard plan.missingTrialReason == .consumed else { return price }
        return L10n.t("ios.pay10.legal.trialUsed", locale: locale) + " " + price
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
/// prélèvement.
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
            case .reminder: "bell.badge"
            case .end: "crown"
            }
        }

        var tone: LessonTone {
            switch kind {
            case .today: .blue
            case .reminder: .yellow
            case .end: .lilac
            }
        }
    }

    /// La longueur au-delà de laquelle le sujet d'une leçon est abrégé dans la première étape.
    static let longestTopic = 40

    static func steps(
        trialDays: Int,
        now: Date = Date(),
        reminderKept: Bool,
        topic: String? = nil,
        locale: UiLocale = .resolved(),
        calendar: Calendar = .current
    ) -> [Step] {
        var steps = [
            Step(
                kind: .today,
                title: L10n.t("ios.pay10.timeline.today", locale: locale),
                detail: todayDetail(topic: topic, locale: locale)
            ),
        ]
        if reminderKept, let fire = TrialEndReminder.fireDate(purchasedAt: now, trialDays: trialDays) {
            steps.append(Step(
                kind: .reminder,
                title: dayText(fire, locale: locale, calendar: calendar),
                detail: L10n.t("ios.pay10.timeline.reminderSub", locale: locale)
            ))
        }
        steps.append(Step(
            kind: .end,
            title: dayText(endDate(from: now, trialDays: trialDays), locale: locale, calendar: calendar),
            detail: L10n.t("ios.pay10.timeline.endSub", locale: locale)
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

    /// « Tout est débloqué », et la leçon que l'élève a demandée dans le parcours quand il
    /// en a demandé une : elle s'écrit dès qu'il entre.
    private static func todayDetail(topic: String?, locale: UiLocale) -> String {
        guard let topic = topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty else {
            return L10n.t("ios.pay10.timeline.todaySub", locale: locale)
        }
        let shown = topic.count > longestTopic ? String(topic.prefix(longestTopic - 1)) + "…" : topic
        return L10n.t("ios.pay10.timeline.todayTopic", locale: locale, vars: ["topic": shown])
    }
}

// MARK: - Le paywall, en un écran

/// **Le paywall, en un seul écran** — celui de l'app et celui de la fin du parcours d'accueil.
///
/// De haut en bas : la marque (« Micabo PRO · Pour Lina ») et la croix ; l'en-tête ; les deux
/// offres, l'annuelle cochée d'avance ; puis, en pied fixe, « Rien à payer aujourd'hui », **un
/// seul bouton**, la mention de ce qui sera prélevé, la restauration et les liens.
///
/// **Deux en-têtes pour un même écran** (`PaywallTrigger.showsTrialHeader`) :
/// - « essai », quand on n'a buté sur rien : le plan de l'élève en titre, et la chronologie
///   datée de ses jours gratuits ;
/// - « contexte », derrière une porte de l'app : Mika dit dans sa bulle ce qu'il fera avec
///   Pro, puis trois bénéfices, celui de la porte d'abord.
///
/// **Rien ne se cache, rien ne ment** : la croix est là dès l'ouverture, ce qui sera prélevé
/// est écrit sous le bouton, et l'essai ne s'annonce — titre, coche verte, bouton, mention —
/// que si Apple l'accordera à ce compte (`PaywallPlan.hasTrial`). Le prix et l'essai viennent
/// de la boutique du pays, l'écriture du prix du test `PriceDisplay`.
///
/// **Tout tient sans défiler quand l'écran le permet** ; sinon le contenu défile et le pied
/// reste fixe.
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

    var body: some View {
        VStack(spacing: 0) {
            PaywallTopBar(name: name, isBusy: isPurchasing, onClose: onClose)

            ViewThatFits(in: .vertical) {
                content(compact: false)
                content(compact: true)
                ScrollView {
                    content(compact: true)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            PaywallFooter(
                plan: selectedPlan,
                prices: prices,
                isPurchasing: isPurchasing,
                notice: notice,
                onSubscribe: { onSubscribe(selectedPlan) },
                onRetry: onRetry,
                onRestore: onRestore
            )
        }
        .background(V3Color.bg.ignoresSafeArea())
        .task {
            guard context.reminderKept == nil else { return }
            reminderAllowed = await TrialEndReminder.canBeKept()
        }
    }

    // MARK: Le contenu

    private func content(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 16 : 24) {
            header(compact: compact)
            plans
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, compact ? 12 : 22)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func header(compact: Bool) -> some View {
        if let trigger, !showsTrialHeader {
            VStack(alignment: .leading, spacing: compact ? 14 : 20) {
                PaywallMikaLine(line: PaywallCopy.hook(for: trigger), mood: .wink)
                PaywallRows(rows: benefitRows(for: trigger), compact: compact)
            }
        } else {
            VStack(alignment: .leading, spacing: compact ? 14 : 22) {
                PaywallCopy.title(
                    profile: context.profile,
                    offersTrial: selectedPlan.hasTrial,
                    trialDays: selectedPlan.trialDays
                )
                .styled()
                .font(compact ? PaywallStyle.titleCompact : PaywallStyle.title)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

                PaywallRows(rows: selectedPlan.hasTrial ? timelineRows : benefitRows(for: nil), compact: compact)
            }
        }
    }

    /// La chronologie de l'essai : aujourd'hui, le rappel, le premier prélèvement.
    private var timelineRows: [PaywallHeaderRow] {
        PaywallTimeline.steps(
            trialDays: selectedPlan.trialDays,
            now: context.now,
            reminderKept: reminderKept,
            topic: context.topic
        )
        .map { PaywallHeaderRow(id: $0.id, symbol: $0.symbol, tone: $0.tone, title: $0.title, detail: $0.detail) }
    }

    /// Ce que Pro ouvre, le bénéfice de la porte d'abord.
    private func benefitRows(for trigger: PaywallTrigger?) -> [PaywallHeaderRow] {
        PaywallBenefit.shown(for: trigger).map { benefit in
            PaywallHeaderRow(
                id: benefit.rawValue,
                symbol: benefit.symbol,
                tone: benefit.tone,
                title: L10n.t(benefit.titleKey, locale: .resolved()),
                detail: L10n.t(benefit.detailKey, locale: .resolved())
            )
        }
    }

    @ViewBuilder
    private var plans: some View {
        switch prices {
        case .ready:
            VStack(spacing: PaywallStyle.planSpacing) {
                ForEach(PaywallCatalog.all) { plan in
                    PaywallPlanRow(
                        plan: plan,
                        isSelected: plan.kind == selection,
                        storeRevision: storeRevision,
                        savings: plan.kind == PaywallCatalog.recommended.kind ? savingsLabel : nil,
                        detail: PaywallCopy.planDetail(for: plan, mentionsTrial: !showsTrialHeader)
                    ) {
                        select(plan.kind)
                    }
                    .disabled(isPurchasing)
                }
            }
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

// MARK: - Les rangées de l'en-tête

/// Une rangée de l'en-tête : une étape de la chronologie, ou un bénéfice.
struct PaywallHeaderRow: Identifiable, Equatable {
    let id: String
    /// Le symbole du système, sans « .fill ».
    let symbol: String
    let tone: LessonTone
    let title: String
    let detail: String
}

/// Les rangées de l'en-tête, l'une sous l'autre : trois au plus.
private struct PaywallRows: View {
    let rows: [PaywallHeaderRow]
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            ForEach(rows) { row in
                PaywallInfoRow(symbol: row.symbol, tone: row.tone, title: row.title, detail: row.detail)
            }
        }
    }
}

// MARK: - Les offres

/// **Une offre**, comme une ligne qu'on choisit : son nom et la remise qu'elle fait, ce qui
/// est prélevé ; à droite, le chiffre qu'on compare, dans l'écriture du test de prix
/// (`PriceDisplay`). Choisie, la ligne prend le filet et le lavis de l'accent.
struct PaywallPlanRow: View {
    let plan: PaywallPlan
    let isSelected: Bool
    /// Voir `PaywallScreen.storeRevision` : sans lui, la ligne — dont les autres entrées ne
    /// changent pas — garderait le prix d'avant la réponse de la boutique.
    let storeRevision: Int
    /// « −81 % », à côté du nom ; `nil` pour une offre sans remise à annoncer.
    let savings: String?
    /// La ligne sous le nom : ce qui est prélevé, et à quel rythme.
    let detail: String
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
                        .font(PaywallStyle.price)
                        .foregroundStyle(V3Color.ink)
                    Text(plan.priceHeadlineUnit(for: .current))
                        .font(PaywallStyle.priceUnit)
                        .foregroundStyle(V3Color.ink2)
                }
                .lineLimit(1)
                .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: PaywallStyle.planHeight)
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
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: PaywallStyle.planHeight)
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
            .font(PaywallStyle.rowDetail)
            .foregroundStyle(V3Color.ink2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, minHeight: PaywallStyle.planHeight)
            .v3Card(radius: PaywallStyle.planRadius)
    }
}

// MARK: - Le pied

/// **Le pied du paywall**, fixe sous la page : « Rien à payer aujourd'hui » quand c'est vrai,
/// le bouton, le message d'un achat qui n'a pas abouti, la mention de ce qui sera prélevé,
/// puis la restauration et les liens.
private struct PaywallFooter: View {
    let plan: PaywallPlan
    let prices: PaywallPriceState
    let isPurchasing: Bool
    let notice: PaywallNotice?
    var onSubscribe: () -> Void
    var onRetry: () -> Void
    var onRestore: () -> Void

    private var isReady: Bool { prices == .ready }

    var body: some View {
        VStack(spacing: 8) {
            if isReady, plan.hasTrial {
                assurance
            }
            button
            if let notice {
                PaywallNoticeLine(notice: notice)
            }
            if isReady {
                Text(PaywallCopy.legal(for: plan))
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

    private var assurance: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
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
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            MikaMascot(mood: .celebrate, size: PaywallStyle.welcomeMika)
                .accessibilityHidden(true)
            VStack(spacing: 10) {
                PaywallCopy.welcome(name: name).styled()
                    .font(PaywallStyle.moment)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.t("ios.pay10.welcome.sub", locale: .resolved()))
                    .font(PaywallStyle.momentSub)
                    .foregroundStyle(V3Color.ink2)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 18)
            Spacer(minLength: 24)
            V3Button(L10n.t("ios.pay10.welcome.cta", locale: .resolved()), action: onContinue)
                .padding(.bottom, 12)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(V3Color.bg.ignoresSafeArea())
    }
}
