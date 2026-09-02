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
