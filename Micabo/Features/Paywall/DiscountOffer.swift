import Foundation

/// **L'offre de réduction : ses règles, et les mêmes nombres que le web.**
///
/// **Elle arrive au moment où l'élève referme un paywall sans acheter**, et à la place de ce
/// paywall : la croix ne ferme pas l'écran, elle le remplace (`PaywallFlowView`). Un seul
/// écran : le pourcentage en géant, le tarif réduit de l'annuel à côté du prix qu'il barre,
/// et le temps qu'il reste. Rien à déballer, aucun appui à compter. Tous les paywalls
/// comptent, celui du parcours d'accueil compris.
///
/// **Une seule durée, un seul instant d'origine** : celui où l'offre s'est affichée pour la
/// première fois. La fenêtre court vingt-quatre heures, et son décompte est vrai partout où
/// il s'écrit — sur l'écran de l'offre et sur la pastille de la Home (`DiscountChip`). Deux
/// horloges finiraient par se contredire, et un prix qui revient après avoir expiré ne se
/// croit plus.
///
/// **Tant que la fenêtre court**, refermer un paywall remontre l'offre, et la Home garde sa
/// pastille. Finie, l'offre se repose quarante-huit heures ; ensuite elle peut revenir, à la
/// prochaine fermeture d'un paywall.
///
/// **Refusée, elle n'insiste pas** : pas deux fois dans la même session (`declinedThisSession`).
/// La pastille et la rangée des Réglages restent, pour qui change d'avis.
///
/// `web/packages/core/src/discount.ts` porte les mêmes durées, et `freemium-parity.test.ts`
/// relit ce fichier pour qu'elles ne divergent pas.
enum DiscountOffer {
    /// Appuis avant de voir le tarif réduit. Aucun : il n'y a plus de cadeau à ouvrir,
    /// l'offre arrive ouverte.
    static let taps = 0

    /// La durée de l'offre. Vingt-quatre heures, comptées à la seconde.
    static let windowSeconds = 86400

    /// **Le repos entre deux fenêtres.** Quarante-huit heures.
    ///
    /// L'offre ne meurt pas au bout de vingt-quatre heures : elle se retire, puis elle
    /// revient. Une offre qui disparaît pour toujours parce qu'on a fermé un écran un soir
    /// de semaine est une offre qu'on a perdue sans l'avoir refusée - et, plus gênant, un
    /// tarif que plus rien dans le produit ne permet d'atteindre.
    ///
    /// Deux jours, parce que le repos doit se sentir : une urgence qui repart le lendemain
    /// matin n'est plus une urgence, c'est un prix affiché.
    static let restSeconds = 172800

    enum Key {
        /// L'instant d'ouverture, en secondes depuis 1970. Zéro : jamais ouvert ici.
        static let startedAt = "micabo.discount.startedAt"
        /// Le dernier nombre de cours importés connu. Les Réglages le relisent pour leur
        /// rangée de l'offre ; aucun cours n'est plus demandé (`giftAfterCourses`).
        static let ownedCourses = "micabo.discount.ownedCourses"

        // Les deux clés d'avant le lot 10. Plus rien ne les lit : l'offre ne se met plus en
        // attente derrière un paywall refermé, elle le remplace. `forget` les efface.
        static let seen = "micabo.discount.seen"
        static let pending = "micabo.discount.pending"
    }

    // MARK: - Le temps

    /// Combien de secondes restent sur `span`, depuis `startedAt`.
    ///
    /// Jamais négatif, et jamais plus que `span` : une horloge remise en arrière donnerait
    /// sinon un décompte qui grandit.
    static func remaining(startedAt: Date, now: Date = Date(), span: Int) -> Int {
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return min(span, max(0, span - elapsed))
    }

    static func windowRemaining(startedAt: Date, now: Date = Date()) -> Int {
        remaining(startedAt: startedAt, now: now, span: windowSeconds)
    }

    /// L'offre est encore achetable. Passé vingt-quatre heures, la pastille disparaît.
    static func isLive(startedAt: Date, now: Date = Date()) -> Bool {
        windowRemaining(startedAt: startedAt, now: now) > 0
    }

    /// L'offre peut se relancer : la fenêtre est finie **et** le repos est passé.
    ///
    /// C'est ce qui fait revenir l'offre. Sans cette règle, une fenêtre expirée fermait
    /// définitivement le tarif réduit : ni offre, ni pastille, et aucun autre chemin.
    static func hasRested(startedAt: Date, now: Date = Date()) -> Bool {
        Int(now.timeIntervalSince(startedAt)) >= windowSeconds + restSeconds
    }

    /// « 59:59 » sous l'heure, « 23:14:07 » au-dessus.
    ///
    /// Deux chiffres partout : un décompte qui passe de « 9:5 » à « 10:04 » change de
    /// largeur à chaque seconde, et une pastille qui tremble attire l'œil pour rien.
    static func countdown(_ seconds: Int) -> String {
        let total = max(0, seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let rest = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, rest)
        }
        return String(format: "%02d:%02d", minutes, rest)
    }

    /// Ce que lit VoiceOver, où « 23:14:07 » ne veut rien dire.
    ///
    /// La durée se compose au lieu de s'écrire : `ios.offer.left` porte la tournure de la
    /// langue — « il reste deux heures », « two hours left » — et `ios.offer.and` la
    /// conjonction. Écrire la phrase entière en Swift revenait à écrire l'ordre des mots
    /// du français dans les cinq langues.
    static func countdownLabel(_ seconds: Int, locale: UiLocale = .resolved()) -> String {
        let total = max(0, seconds)
        guard total > 0 else { return L10n.t("app.paywall.offerEnded", locale: locale) }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        func left(_ time: String) -> String {
            L10n.t("ios.offer.left", locale: locale, vars: ["time": time])
        }

        if hours > 0 {
            let spelledHours = L10n.t("ios.offer.hours", locale: locale, vars: ["n": "\(hours)"])
            guard minutes > 0 else { return left(spelledHours) }
            let spelledMinutes = L10n.t("ios.offer.minutes", locale: locale, vars: ["n": "\(minutes)"])
            return left(L10n.t(
                "ios.offer.and",
                locale: locale,
                vars: ["first": spelledHours, "second": spelledMinutes]
            ))
        }

        guard minutes > 0 else { return L10n.t("ios.offer.underMinute", locale: locale) }
        return left(L10n.t("ios.offer.minutes", locale: locale, vars: ["n": "\(minutes)"]))
    }

    // MARK: - Ce que l'appareil retient

    /// L'instant où l'offre s'est affichée, ou `nil` si elle ne l'a jamais été ici.
    static func start(in defaults: UserDefaults = .standard) -> Date? {
        let stored = defaults.double(forKey: Key.startedAt)
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    /// **L'offre s'affiche** : la fenêtre démarre, ou celle qui court déjà est rendue.
    ///
    /// Deux règles, et elles tirent en sens contraire. Une fenêtre **en cours** ne se remet
    /// pas à zéro : sans ce garde, chaque affichage repousserait la fin des vingt-quatre
    /// heures et le décompte ne descendrait plus. Une fenêtre **finie**, elle, ouvre la
    /// suivante : l'offre revient, elle ne meurt pas.
    @discardableResult
    static func begin(now: Date = Date(), in defaults: UserDefaults = .standard) -> Date {
        if let existing = start(in: defaults), isLive(startedAt: existing, now: now) { return existing }
        defaults.set(now.timeIntervalSince1970, forKey: Key.startedAt)
        return now
    }

    /// Oublie la fenêtre et le refus de la session : l'offre peut revenir. Pour les tests et
    /// la section Test.
    static func forget(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.startedAt)
        defaults.removeObject(forKey: Key.seen)
        defaults.removeObject(forKey: Key.pending)
        declinedThisSession = false
    }

    // MARK: - Quand elle arrive

    /// **L'élève a refusé l'offre depuis le lancement** (sa croix). Elle ne se représente
    /// plus d'elle-même avant le prochain lancement ; la pastille de la Home et la rangée des
    /// Réglages la rouvrent à la demande.
    ///
    /// En mémoire, et pas dans les réglages : c'est la session qui est épargnée, pas
    /// l'appareil.
    static var declinedThisSession = false

    /// **Le paywall vient de se refermer sans achat** : l'offre prend-elle sa place ?
    ///
    /// Une fonction pure, pour qu'elle se teste sans vue ni horloge. `startedAt` à `nil` veut
    /// dire « l'offre ne s'est jamais affichée ici ».
    ///
    /// - Un abonné : jamais.
    /// - Déjà refusée depuis le lancement : non.
    /// - Jamais affichée : oui, et sa fenêtre démarre.
    /// - Une fenêtre court : oui, avec le temps qu'il lui reste.
    /// - Fenêtre finie : non pendant le repos, puis oui de nouveau.
    static func paywallClosed(
        isPro: Bool,
        startedAt: Date?,
        declined: Bool,
        now: Date = Date()
    ) -> Bool {
        guard !isPro, !declined else { return false }
        guard let startedAt else { return true }
        if isLive(startedAt: startedAt, now: now) { return true }
        return hasRested(startedAt: startedAt, now: now)
    }

    /// La même décision, pour l'appareil et la session en cours.
    static func paywallClosed(isPro: Bool, in defaults: UserDefaults = .standard) -> Bool {
        paywallClosed(isPro: isPro, startedAt: start(in: defaults), declined: declinedThisSession)
    }

    /// Aucun cours n'est demandé : c'est le paywall refermé qui amène l'offre.
    static let giftAfterCourses = 0

    /// **Le tarif réduit est-il atteignable ?**
    ///
    /// C'est la question des Réglages, et elle n'est pas celle du paywall refermé : l'offre
    /// surgit à la fermeture d'un paywall, la rangée des Réglages reste. Elle ne demande donc
    /// ni que la fenêtre coure ni que le repos soit passé — ouvrir l'offre depuis là relance
    /// une fenêtre. Sans ce chemin, une offre en repos n'était atteignable nulle part.
    static func isReachable(isPro: Bool, courseCount: Int) -> Bool {
        !isPro && courseCount >= giftAfterCourses
    }

    /// **La pastille de la Home se montre-t-elle ?** Tant que la fenêtre court, et jamais à
    /// un abonné.
    static func isChipLive(isPro: Bool, startedAt: Date?, now: Date = Date()) -> Bool {
        guard !isPro, let startedAt else { return false }
        return isLive(startedAt: startedAt, now: now)
    }

    // MARK: - Le prix

    /// L'offre vendue par l'écran du tarif réduit.
    static var plan: PaywallPlan { PaywallCatalog.discount }

    /// Le prix barré à côté : l'annuel plein, pas la somme de cinquante-deux semaines.
    /// Comparer une remise à l'offre la plus chère du catalogue gonfle le pourcentage.
    static var reference: PaywallPlan { PaywallCatalog.yearly }

    /// Ce que le tarif réduit fait économiser sur l'annuel plein, en pourcentage entier.
    ///
    /// Sur les prix du pays dès que la boutique a répondu : le grand chiffre est posé à côté
    /// des deux prix, il ne peut pas en dire un troisième. La grille garde −40 % partout.
    static var savingsPercent: Int {
        PaywallCatalog.savings(of: plan, against: reference)
    }

    /// « −40 % », écrit comme la langue l'écrit : « −40% » en anglais, « −%40 » en turc.
    ///
    /// C'est le formateur du pays qui pose le signe, le symbole et les marques de sens de
    /// lecture (l'arabe) ; seul le trait d'union devient un vrai signe moins.
    static func savingsLabel(_ percent: Int, locale: UiLocale = .resolved()) -> String {
        guard percent > 0 else { return L10n.percent(0, locale: locale) }
        return (-Double(percent) / 100)
            .formatted(.percent.precision(.fractionLength(0)).locale(locale.foundation))
            .replacingOccurrences(of: "-", with: "−")
    }
}
