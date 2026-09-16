import Foundation
import Observation

/// La langue d'interface en cours, relue par les écrans.
@Observable
final class UiLocaleStore {
    var locale: UiLocale {
        didSet {
            guard locale != oldValue else { return }
            UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
        }
    }

    init(locale: UiLocale = .resolved()) {
        self.locale = locale
    }

    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: locale, vars: vars)
    }

    func pick(_ next: UiLocale) {
        locale = next
    }
}

/// **Traduire même sans le store.**
///
/// `@Environment(UiLocaleStore.self)` rend un optionnel, et il est parfois nil pour de bon :
/// une barre d'outils posée dans un `UIHostingController` n'hérite pas de l'environnement
/// SwiftUI de l'écran qui la présente. Chaque appel portait donc son repli écrit à la main —
/// en français, quatre cent cinquante-huit fois. Une app à moitié traduite ne plante pas :
/// elle bascule de langue au milieu d'un écran, et c'est exactement ce qu'on ne voit pas en
/// relecture.
///
/// Le repli est maintenant **la langue résolue**, pas une phrase recopiée : sans store, on
/// relit `UserDefaults` et les préférences système, ce que le store aurait fait lui-même.
extension Optional where Wrapped == UiLocaleStore {
    var locale: UiLocale {
        self?.locale ?? .resolved()
    }

    func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: locale, vars: vars)
    }
}
