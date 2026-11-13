import Observation
import SwiftUI
import UIKit

// MARK: - La fenêtre, observable

/// **La fenêtre de l'offre, telle que l'app la regarde.**
///
/// `DiscountOffer` range l'instant d'ouverture dans les réglages de l'appareil et sait
/// calculer ; il ne prévient personne. Cet objet relit ces réglages et **dit quand la réponse
/// change** : la Home y lit `DiscountChip.isLive` pour savoir si elle montre la pastille de
/// l'offre ou « Passer en Pro », et se redessine quand la fenêtre s'ouvre ou se referme —
/// pas à chaque seconde du décompte.
///
/// Il relit quand un réglage de l'appareil change (l'offre qui s'affiche, un achat, « Forcer
/// Pro »), quand l'app revient au premier plan, et à chaque seconde tant qu'une pastille est
/// à l'écran : c'est elle qui voit la fenêtre finir.
///
/// Il porte aussi **l'offre que la pastille a ouverte** (`presentation`) : c'est la racine de
/// l'app qui la présente (`micaboDiscountChipOffer`, posé sur `RootTabView`), pas la pastille.
/// La pastille s'en va de la Home quand la fenêtre finit ou que l'élève s'abonne ; un écran
/// qu'elle porterait partirait avec elle, sous ses yeux.
@MainActor
@Observable
final class DiscountWindow {
    static let shared = DiscountWindow()

    /// L'instant où l'offre s'est affichée, `nil` si elle ne l'a jamais été ici.
    private(set) var startedAt: Date?

    /// Vrai tant qu'une fenêtre court pour un élève sans abonnement.
    private(set) var isLive = false

    /// L'offre ouverte à la demande, depuis la pastille de la Home ; `nil` quand elle est
    /// refermée.
    var presentation: DiscountPresentation?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refresh()

        let center = NotificationCenter.default
        let names: [(Notification.Name, Any?)] = [
            (UserDefaults.didChangeNotification, defaults),
            (UIApplication.willEnterForegroundNotification, nil),
        ]
        for (name, object) in names {
            observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            })
        }
    }

    /// Relit les réglages. Rien n'est écrit quand rien n'a changé : une affectation, même à
    /// la même valeur, redessinerait tous les écrans qui lisent la fenêtre.
    func refresh(now: Date = Date()) {
        let start = DiscountOffer.start(in: defaults)
        let live = DiscountOffer.isChipLive(
            isPro: defaults.bool(forKey: ProAccess.Key.isPro),
            startedAt: start,
            now: now
        )
        if start != startedAt { startedAt = start }
        if live != isLive { isLive = live }
    }
}

// MARK: - La pastille

/// **La pastille de l'offre, en tête de la Home** : « −40 % », et le temps qu'il reste.
///
/// Elle prend la place de « Passer en Pro » tant que la fenêtre de l'offre court
/// (`DiscountChip.isLive`), compte à la seconde tant qu'elle est à l'écran, et rouvre l'offre
/// d'un appui. Hors fenêtre, ou pour un abonné, **elle ne dessine rien**.
///
/// Le décompte est une `TimelineView` : l'horloge du système, qui ne tourne que pour une vue
/// affichée. Aucune tâche ne dort derrière.
///
/// L'offre s'ouvre depuis la racine de l'app (`DiscountWindow.presentation`) : la pastille
/// peut quitter la Home — la fenêtre finit, l'élève s'abonne — sans emporter l'écran.
struct DiscountChip: View {
    init() {}

    /// Vrai tant que la pastille a quelque chose à montrer. Observable : un écran qui le
    /// lit dans son `body` se redessine quand la fenêtre s'ouvre ou se referme.
    @MainActor static var isLive: Bool { DiscountWindow.shared.isLive }

    var body: some View {
        let window = DiscountWindow.shared
        // Une pile, et pas un groupe : même vide, elle existe.
        ZStack {
            if let startedAt = window.startedAt, window.isLive {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = DiscountOffer.windowRemaining(startedAt: startedAt, now: context.date)
                    ZStack {
                        // À zéro, plus rien à montrer.
                        if left > 0 {
                            Button {
                                DiscountWindow.shared.presentation = .paywall
                            } label: {
                                DiscountChipLabel(percent: DiscountOffer.savingsPercent, remaining: left)
                            }
                            .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
                            .accessibilityLabel(L10n.t(
                                "ios.reopenOffer",
                                locale: .resolved(),
                                vars: ["left": DiscountOffer.countdownLabel(left)]
                            ))
                        }
                    }
                    // La fenêtre vient de finir sous nos yeux — ou l'était déjà quand la
                    // pastille est revenue à l'écran : la Home reprend la main.
                    .onChange(of: left > 0, initial: true) { _, isRunning in
                        if !isRunning { DiscountWindow.shared.refresh() }
                    }
                }
            }
        }
    }
}

/// Ce que la pastille montre, sans horloge : c'est ce que les rendus dessinent. Une pastille
/// du jaune de l'offre, comme « PRO » dont elle prend la place.
struct DiscountChipLabel: View {
    let percent: Int
    /// Les secondes qui restent sur la fenêtre.
    let remaining: Int
    var locale: UiLocale = .resolved()

    var body: some View {
        PaywallYellowPill(horizontal: 12, vertical: 0) {
            HStack(spacing: 6) {
                Text(verbatim: DiscountOffer.savingsLabel(percent, locale: locale))
                Text(verbatim: "·")
                    .accessibilityHidden(true)
                // Chiffres à chasse fixe : la pastille ne change pas de largeur à chaque seconde.
                Text(verbatim: DiscountOffer.countdown(remaining))
                    .monospacedDigit()
            }
            .font(PaywallStyle.pill)
            .minimumScaleFactor(0.8)
            .frame(minHeight: PaywallStyle.pillHeight)
        }
    }
}

// MARK: - L'offre, présentée par la racine

/// **Présente l'offre que la pastille de la Home a ouverte.** Posé une fois, sur la racine des
/// onglets : elle ne quitte jamais l'écran, l'offre non plus tant qu'on ne la referme pas.
///
/// Un modificateur à part, pour que seul lui se relise quand l'offre s'ouvre ou se referme :
/// la racine, elle, ne lit rien de la fenêtre.
private struct DiscountChipOfferPresenter: ViewModifier {
    func body(content: Content) -> some View {
        @Bindable var window = DiscountWindow.shared
        return content.micaboDiscountOffer($window.presentation)
    }
}

extension View {
    /// Présente l'offre de réduction ouverte depuis la pastille de la Home (`DiscountChip`).
    /// À poser une seule fois, sur une vue qui reste : la racine des onglets.
    func micaboDiscountChipOffer() -> some View {
        modifier(DiscountChipOfferPresenter())
    }
}
