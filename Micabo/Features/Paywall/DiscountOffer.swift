import Foundation

/// **L'offre cadeau, et les mêmes nombres que le web.**
///
/// Après le premier cours importé, Micabo offre l'annuel à tarif réduit. Le cadeau se
/// présente sur la fiche : trois appuis l'ouvrent, et le paywall qui suit affiche une
/// minuterie de vingt-quatre heures. Refermé, il laisse une pastille qui garde le même
/// décompte et le rouvre d'un appui.
///
/// Une seule durée, **un seul instant d'origine** : celui où le cadeau a été ouvert.
/// Le pop-up et la languette montrent le même temps restant. Deux horloges différentes
/// finiraient par se contredire — le pop-up disait « terminé » alors que la pastille
/// comptait encore — et un prix qui revient après avoir affiché « terminé » ne se
/// croit plus.
///
/// `web/packages/core/src/discount.ts` porte les mêmes constantes, et
/// `freemium-parity.test.ts` relit ce fichier pour qu'elles ne divergent pas.
enum DiscountOffer {
    /// Appuis sur le cadeau avant qu'il s'ouvre. Trois : un geste, pas un accident.
    static let taps = 3

    /// La durée de l'offre, sur le pop-up comme sur la pastille. Vingt-quatre heures.
    static let windowSeconds = 86400

    /// Même nombre que `windowSeconds` : le pop-up ne peut pas dire autre chose que la pastille.
    static let urgencySeconds = 86400

    /// **Le repos entre deux fenêtres.** Quarante-huit heures.
    ///
    /// L'offre ne meurt pas au bout de vingt-quatre heures : elle se retire, puis elle
    /// revient. Une offre qui disparaît pour toujours parce qu'on a fermé un cadeau un soir
    /// de semaine est une offre qu'on a perdue sans l'avoir refusée - et, plus gênant, un
    /// tarif que plus rien dans le produit ne permet d'atteindre.
    ///
    /// Deux jours, parce que le repos doit se sentir : une urgence qui repart le lendemain
    /// matin n'est plus une urgence, c'est un prix affiché.
    static let restSeconds = 172800

    enum Key {
        /// L'instant d'ouverture, en secondes depuis 1970. Zéro : jamais ouvert ici.
        static let startedAt = "micabo.discount.startedAt"
        /// Le paywall s'est déjà présenté ; la pastille prend le relais.
        static let seen = "micabo.discount.seen"
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

    static func urgencyRemaining(startedAt: Date, now: Date = Date()) -> Int {
        windowRemaining(startedAt: startedAt, now: now)
    }

    /// La même durée, **au millième**, pour la minuterie qui affiche des centièmes.
    ///
    /// `remaining` arrondit à la seconde, ce qui suffit à une pastille mais fait bégayer un
    /// affichage qui montre deux chiffres après la virgule : deux images de suite tombent
    /// dans la même seconde, et le décompte a l'air arrêté.
    static func remainingMillis(startedAt: Date, now: Date = Date(), span: Int) -> Int {
        let total = span * 1000
        let left = total - Int((now.timeIntervalSince(startedAt) * 1000).rounded(.down))
        return min(total, max(0, left))
    }

    static func windowMillisRemaining(startedAt: Date, now: Date = Date()) -> Int {
        remainingMillis(startedAt: startedAt, now: now, span: windowSeconds)
    }

    static func urgencyMillisRemaining(startedAt: Date, now: Date = Date()) -> Int {
        windowMillisRemaining(startedAt: startedAt, now: now)
    }

    /// L'offre est encore achetable. Passé vingt-quatre heures, la pastille disparaît.
    static func isLive(startedAt: Date, now: Date = Date()) -> Bool {
        windowRemaining(startedAt: startedAt, now: now) > 0
    }

    /// L'offre peut se relancer : la fenêtre est finie **et** le repos est passé.
    ///
    /// C'est ce qui fait revenir le cadeau. Sans cette règle, une fenêtre expirée fermait
    /// définitivement le tarif réduit : ni cadeau, ni pastille, et aucun autre chemin.
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

    /// **Le décompte du paywall : « 00 : 29 : 48 . 69 ».**
    ///
    /// Les centièmes sont là pour une raison, et ce n'est pas la précision : une minuterie
    /// qui bouge à chaque image se regarde, une minuterie qui saute d'une seconde à l'autre
    /// se lit une fois puis s'oublie. C'est le seul endroit du produit où l'on demande de
    /// décider maintenant.
    ///
    /// Les séparateurs sont espacés — « 00 : 29 » et non « 00:29 » — parce qu'à cette taille
    /// deux-points collés entre deux chiffres se lisent comme une faute de frappe.
    static func preciseCountdown(_ millis: Int) -> String {
        let total = max(0, millis)
        let hours = total / 3_600_000
        let minutes = (total % 3_600_000) / 60_000
        let seconds = (total % 60_000) / 1000
        let hundredths = (total % 1000) / 10
        return String(format: "%02d : %02d : %02d . %02d", hours, minutes, seconds, hundredths)
    }

    /// Ce que lit VoiceOver, où « 23:14:07 » ne veut rien dire.
    ///
    /// La phrase commence par « il reste » : l'accord du participe suivrait sinon le
    /// nombre, et « 1 heure restantes » se lit comme une faute.
    static func countdownLabel(_ seconds: Int) -> String {
        let total = max(0, seconds)
        guard total > 0 else { return "offre terminée" }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            let heures = hours == 1 ? "1 heure" : "\(hours) heures"
            guard minutes > 0 else { return "il reste \(heures)" }
            let mots = minutes == 1 ? "1 minute" : "\(minutes) minutes"
            return "il reste \(heures) et \(mots)"
        }

        guard minutes > 0 else { return "il reste moins d'une minute" }
        return minutes == 1 ? "il reste 1 minute" : "il reste \(minutes) minutes"
    }

    // MARK: - Ce que l'appareil retient

    /// L'instant d'ouverture, ou `nil` si personne ne l'a ouvert ici.
    static func start(in defaults: UserDefaults = .standard) -> Date? {
        let stored = defaults.double(forKey: Key.startedAt)
        guard stored > 0 else { return nil }
        return Date(timeIntervalSince1970: stored)
    }

    /// Ouvre la fenêtre de l'offre, ou rend celle qui court déjà.
    ///
    /// Deux règles, et elles tirent en sens contraire. Une fenêtre **en cours** ne se remet
    /// pas à zéro : sans ce garde, chaque affichage repousserait la fin des vingt-quatre
    /// heures et le décompte ne descendrait plus. Une fenêtre **finie**, elle, ouvre la
    /// suivante : l'offre revient, elle ne meurt pas. Le « déjà vu » repart alors, puisqu'on
    /// parle d'une nouvelle fenêtre.
    @discardableResult
    static func begin(now: Date = Date(), in defaults: UserDefaults = .standard) -> Date {
        if let existing = start(in: defaults), isLive(startedAt: existing, now: now) { return existing }
        defaults.set(now.timeIntervalSince1970, forKey: Key.startedAt)
        defaults.set(false, forKey: Key.seen)
        return now
    }

    /// Le cadeau a été montré. **Et la fenêtre démarre ici aussi.**
    ///
    /// Sans ce démarrage, refermer le cadeau avant le troisième appui laissait un « déjà vu »
    /// sans décompte : le cadeau ne se représentait plus (déjà vu) et la pastille ne
    /// s'affichait pas (pas d'instant). Le tarif réduit devenait alors introuvable dans tout
    /// le produit, sans que rien ne le signale — et c'est exactement ce qu'App Review a
    /// constaté le 10 septembre.
    static func markSeen(now: Date = Date(), in defaults: UserDefaults = .standard) {
        begin(now: now, in: defaults)
        defaults.set(true, forKey: Key.seen)
    }

    static func isSeen(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: Key.seen)
    }

    static func forget(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: Key.startedAt)
        defaults.removeObject(forKey: Key.seen)
    }

    // MARK: - Les règles d'affichage

    /// Faut-il poser le cadeau sur cette fiche ?
    ///
    /// Une fonction pure, pour qu'elle se teste sans vue ni horloge. `startedAt` à `nil`
    /// veut dire « le cadeau n'a pas encore été ouvert ici » : il se présente, et c'est son
    /// ouverture qui pose l'instant.
    static func shouldPresentGift(
        isPro: Bool,
        courseCount: Int,
        seen: Bool,
        startedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard !isPro else { return false }
        // Le cadeau vient après le premier cours. Sans cours importé, il n'y a rien à
        // récompenser et l'offre passe pour une réclame.
        guard courseCount >= FreeTier.courses else { return false }
        // Un « déjà vu » sans instant d'ouverture est un état bâtard, laissé par une version
        // qui marquait le cadeau vu sans démarrer son décompte. On le représente : rien n'a
        // jamais été chronométré, donc rien n'a été offert.
        guard let startedAt else { return true }
        // Fenêtre en cours : une seule fois, la pastille prend ensuite le relais.
        if isLive(startedAt: startedAt, now: now) { return !seen }
        // Fenêtre finie : l'offre revient, après son repos.
        return hasRested(startedAt: startedAt, now: now)
    }

    /// **Le tarif réduit est-il atteignable ?**
    ///
    /// C'est la question des Réglages, et elle n'est pas celle du cadeau : le cadeau surgit
    /// une fois, la rangée des Réglages reste. Elle ne demande donc ni que la fenêtre coure
    /// ni que le cadeau n'ait pas été vu — l'ouvrir depuis là relance une fenêtre. Sans ce
    /// chemin, une offre en repos n'était atteignable nulle part.
    static func isReachable(isPro: Bool, courseCount: Int) -> Bool {
        !isPro && courseCount >= FreeTier.courses
    }

    /// Faut-il garder la pastille et son décompte ?
    static func shouldShowBadge(
        isPro: Bool,
        courseCount: Int,
        seen: Bool,
        startedAt: Date?,
        now: Date = Date()
    ) -> Bool {
        guard !isPro, seen, courseCount >= FreeTier.courses else { return false }
        guard let startedAt else { return false }
        return isLive(startedAt: startedAt, now: now)
    }

    // MARK: - Le prix

    /// Le tarif réduit, écrit une fois : 3,30 € / mois.
    ///
    /// **Écrit et non calculé** — 39,99 ÷ 12 fait 3,3325, que le formateur rendrait
    /// « 3,33 € ». Le paywall affiche donc ce mensuel **et** la somme réellement prélevée
    /// juste à côté : un prix mensuel sans son annuel serait une allégation qu'on ne
    /// facture pas.
    static let monthlyPrice: Decimal = 3.30

    static var monthlyText: String { PaywallPrice.text(monthlyPrice) }

    /// L'offre vendue par ce paywall.
    static var plan: PaywallPlan { PaywallCatalog.discount }

    /// Le prix barré à côté : l'annuel plein, pas la somme de cinquante-deux semaines.
    /// Comparer une remise à l'offre la plus chère du catalogue gonfle le pourcentage.
    static var reference: PaywallPlan { PaywallCatalog.yearly }

    /// Ce que le tarif réduit fait économiser sur l'annuel plein, en pourcentage entier.
    static var savingsPercent: Int {
        let full = NSDecimalNumber(decimal: reference.annualCost).doubleValue
        let discounted = NSDecimalNumber(decimal: plan.annualCost).doubleValue
        guard full > 0 else { return 0 }
        return Int(((1 - discounted / full) * 100).rounded())
    }
}
