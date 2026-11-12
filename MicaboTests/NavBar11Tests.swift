import XCTest
@testable import Micabo

/// **Lot 11 : la barre d'onglets de Micabo** — la pilule flottante dont l'onglet actif dit son
/// nom. Les zones tactiles, la place que les pages réservent, et un nom pour chaque onglet.
@MainActor
final class NavBar11Tests: XCTestCase {
    func testEveryTabIsAComfortableTarget() {
        XCTAssertGreaterThanOrEqual(MicaboTabBar.tabHeight, 44)
        XCTAssertLessThanOrEqual(MicaboTabBar.tabHeight, MicaboTabBar.pillHeight)
        // Cinq onglets, un actif élargi : sur l'écran le plus étroit (375 pt, 16 pt de marge de
        // chaque côté), chaque icône garde au moins 44 pt de large.
        let pill: CGFloat = 375 - 2 * 16 - 2 * 6
        let activeLabel: CGFloat = 130
        XCTAssertGreaterThanOrEqual((pill - activeLabel) / 4, 44)
    }

    /// Les pages réservent la place de la barre entière : rien ne passe dessous.
    func testPagesReserveTheWholeBar() {
        XCTAssertEqual(MicaboLayout.tabBarHeight, MicaboTabBar.pillHeight + MicaboTabBar.bottomAir)
        XCTAssertGreaterThan(MicaboTabBar.bottomAir, 0, "la pilule ne touche jamais le bord d'un iPhone SE")
        XCTAssertEqual(MicaboLayout.tabBarSpace, MicaboLayout.tabBarGap + MicaboLayout.tabBarHeight)
    }

    /// L'onglet actif écrit son nom : chaque onglet en a un, dans chaque langue écrite.
    func testEveryTabHasANameInEveryWrittenLanguage() {
        for locale in [UiLocale.fr, .en, .de, .es, .tr, .ar] {
            for tab in RootTab.tabs {
                let name = tab.barLabel(t: { L10n.t($0, locale: locale) })
                XCTAssertFalse(name.isEmpty, "\(locale) \(tab)")
                XCTAssertFalse(name.hasPrefix("ios.") || name.hasPrefix("lesson."), "\(locale) \(tab) : \(name)")
                XCTAssertLessThanOrEqual(name.count, 12, "\(locale) \(tab) : « \(name) » est trop long pour la pilule")
            }
        }
    }
}
