import XCTest
@testable import Micabo

/// Verrouille **ce que la version gratuite laisse faire**.
///
/// Ces trois nombres sont les seuls de l'app dont une dérive silencieuse ne se verrait sur
/// aucun écran : une fiche coupée à la moitié au lieu des sept dixièmes reste une fiche
/// coupée, et une session qui s'arrête à la quatrième carte reste une session qui s'arrête.
/// C'est le genre de bug qu'on ne découvre qu'en lisant les chiffres de conversion.
final class FreemiumTests: XCTestCase {
    // MARK: - Les limites

    func testTheFreeTierIsOneCourseSeventyPercentAndFiveCards() {
        XCTAssertEqual(FreeTier.courses, 1)
        XCTAssertEqual(FreeTier.readableSheetRatio, 0.7, accuracy: 0.0001)
        XCTAssertEqual(FreeTier.cardsPerSession, 5)
        XCTAssertFalse(FreeTier.allowsPractice, "L'entraînement libre est dans Pro")
    }

    /// Ce n'est pas zéro cours, et c'est le point : un paywall posé avant le premier import
    /// demande de payer pour un produit qu'on n'a pas vu tourner sur ses propres cours.
    func testTheFirstCourseIsFree() {
        XCTAssertGreaterThan(FreeTier.courses, 0)
    }

    /// **Sans ligne, pas d'abonnement.** La même règle que le web
    /// (`ASSUME_PRO_WITHOUT_ROW`), et c'est la divergence la plus coûteuse du produit :
    /// à `true` d'un côté et `false` de l'autre, le site fait payer et le téléphone offre.
    /// `web/packages/core/test/freemium-parity.test.ts` relit cette constante.
    @MainActor
    func testSomeoneWithoutARowIsNotTreatedAsSubscribed() {
        XCTAssertFalse(ProAccess.assumeProWithoutRow)
    }

    /// Le nom de l'entitlement est écrit à trois endroits — ici, le noyau du web, et le
    /// webhook. Un nom qui diverge donne un abonné que personne ne reconnaît.
    func testTheEntitlementIsNamedPro() {
        XCTAssertEqual(ProEntitlement.id, "pro")
    }

    /// Sans clé publique dans `Info.plist`, le SDK n'est pas configuré et les paywalls le
    /// disent. Un SDK configuré avec une chaîne vide journalise sans jamais rien vendre.
    func testThePurchaseBridgeStaysClosedWithoutAKey() {
        if PurchasesBridge.publicKey == nil {
            XCTAssertFalse(PaywallPurchases.isReady)
        }
    }

    /// La boutique muette ne vend pas, et **n'offre pas**. C'est le cas qui compte : un
    /// échec réseau traité comme un achat serait un abonnement gratuit à chaque panne.
    func testAMutedStoreRefusesInsteadOfGivingAway() async {
        let outcome = await PaywallPurchases.buy(PaywallCatalog.recommended)
        if !PaywallPurchases.isReady {
            XCTAssertEqual(outcome, .unavailable)
        }
        XCTAssertNotEqual(outcome, .purchased, "Aucun achat ne se conclut sans boutique")
    }

    // MARK: - La coupure de la fiche

    func testTheSheetIsCutAtSevenTenthsOfItsBlocks() {
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 10), 7)
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 20), 14)
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 14), 10, "9,8 s'arrondit à 10")
    }

    /// Une fiche courte se lit quand même : au moins un bloc reste lisible, et jamais plus
    /// que ce que la fiche contient.
    func testAShortSheetAlwaysKeepsSomethingReadable() {
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 0), 0)
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 1), 1, "Un bloc unique se lit en entier")
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 2), 1)
        XCTAssertEqual(SheetGate.lockIndex(blockCount: 3), 2)

        for count in 1...60 {
            let index = SheetGate.lockIndex(blockCount: count)
            XCTAssertGreaterThanOrEqual(index, 1, "\(count) blocs sans rien à lire")
            XCTAssertLessThanOrEqual(index, count, "\(count) blocs, et on en cache plus qu'il n'y en a")
        }
    }

    func testTheSplitKeepsEveryBlockExactlyOnce() {
        let blocks = SampleData.photosynthesisSheet.blocks
        let parts = SheetGate.split(blocks, isPro: false)

        XCTAssertEqual(parts.readable.count + parts.locked.count, blocks.count)
        XCTAssertFalse(parts.readable.isEmpty)
        XCTAssertFalse(parts.locked.isEmpty, "Une fiche de \(blocks.count) blocs doit se couper")
        XCTAssertEqual(parts.readable + parts.locked, blocks, "L'ordre des blocs ne change pas")
    }

    /// L'abonné ne voit jamais la coupure, et surtout pas une liste vide : c'est la même
    /// vue qui affiche les deux cas.
    func testAnAbonneReadsTheWholeSheet() {
        let blocks = SampleData.affineFunctionsSheet.blocks
        let parts = SheetGate.split(blocks, isPro: true)

        XCTAssertEqual(parts.readable, blocks)
        XCTAssertTrue(parts.locked.isEmpty)
    }

    func testAnEmptySheetHasNothingToLock() {
        let parts = SheetGate.split([], isPro: false)
        XCTAssertTrue(parts.readable.isEmpty)
        XCTAssertTrue(parts.locked.isEmpty)
    }

    // MARK: - Les portes

    @MainActor
    func testTheSessionStopsOnTheFifthCardAndNotBefore() {
        let pro = ProAccess(defaults: isolatedDefaults())

        XCTAssertFalse(pro.hasReachedSessionLimit(answered: 0))
        XCTAssertFalse(pro.hasReachedSessionLimit(answered: 4), "La cinquième carte se révise")
        XCTAssertTrue(pro.hasReachedSessionLimit(answered: 5))
        XCTAssertTrue(pro.hasReachedSessionLimit(answered: 12))

        pro.unlock()
        XCTAssertFalse(pro.hasReachedSessionLimit(answered: 999), "Un abonné n'a plus de plafond")
    }

    @MainActor
    func testTheSecondImportIsRefusedAndTheFirstIsNot() {
        let pro = ProAccess(defaults: isolatedDefaults())

        XCTAssertTrue(pro.canImportCourse(existingCourses: []))

        let mine = Course(title: "Photosynthèse")
        XCTAssertFalse(pro.canImportCourse(existingCourses: [mine]))

        pro.unlock()
        XCTAssertTrue(pro.canImportCourse(existingCourses: [mine, Course(title: "Fonctions affines")]))
    }

    /// Un cours repris dans la bibliothèque n'a rien coûté à produire : le faire compter
    /// dans le quota ferait payer un import qu'on n'a pas fait.
    @MainActor
    func testALibraryCourseDoesNotUseUpTheFreeImport() {
        let pro = ProAccess(defaults: isolatedDefaults())
        let adopted = Course(title: "Cours partagé", isFromLibrary: true)

        XCTAssertTrue(pro.canImportCourse(existingCourses: [adopted]))
    }

    @MainActor
    func testPracticeIsBehindTheSubscription() {
        let pro = ProAccess(defaults: isolatedDefaults())

        XCTAssertFalse(pro.canPractice)
        pro.unlock()
        XCTAssertTrue(pro.canPractice)
    }

    /// L'état survit au relancement de l'app : sans ça, un abonné retrouverait ses cadenas
    /// à chaque démarrage.
    @MainActor
    func testTheSubscriptionIsRememberedAcrossLaunches() async {
        let defaults = isolatedDefaults()

        let first = ProAccess(defaults: defaults)
        XCTAssertFalse(first.isPro)
        first.unlock()

        let second = ProAccess(defaults: defaults)
        XCTAssertTrue(second.isPro)

        second.lock()
        await second.refresh()
        XCTAssertFalse(second.isPro)
    }

    // MARK: - Outillage

    /// Un domaine par test : les réglages partagés feraient dépendre un test de l'ordre
    /// dans lequel les autres ont tourné.
    private func isolatedDefaults(function: String = #function) -> UserDefaults {
        let name = "micabo.tests.\(function).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }
}
