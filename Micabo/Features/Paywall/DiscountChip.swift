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
@MainActor
@Observable
final class DiscountWindow {
    static let shared = DiscountWindow()

    /// L'instant où l'offre s'est affichée, `nil` si elle ne l'a jamais été ici.
    private(set) var startedAt: Date?

    /// Vrai tant qu'une fenêtre court pour un élève sans abonnement — et tant que l'offre
    /// ouverte depuis la pastille est à l'écran (`hold`).
    private(set) var isLive = false

    /// L'offre ouverte depuis la pastille est à l'écran.
    @ObservationIgnored private var isHeld = false

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
        if (live || isHeld) != isLive { isLive = live || isHeld }
    }

    /// **L'offre ouverte depuis la pastille tient la pastille en place.** C'est la pastille
    /// qui porte l'écran de l'offre : une fenêtre qui finit pendant qu'on le lit, ou l'achat
    /// qu'on y fait, la retirerait de la Home — et l'écran avec elle, sous les yeux de
    /// l'élève. Elle reste donc jusqu'à ce qu'il le referme.
    func hold(_ held: Bool) {
        isHeld = held
        refresh()
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
struct DiscountChip: View {
    init() {}

    /// Vrai tant que la pastille a quelque chose à montrer. Observable : un écran qui le
    /// lit dans son `body` se redessine quand la fenêtre s'ouvre ou se referme.
    @MainActor static var isLive: Bool { DiscountWindow.shared.isLive }

    @State private var presentation: DiscountPresentation? = nil

    var body: some View {
        let window = DiscountWindow.shared
        Group {
            if let startedAt = window.startedAt, window.isLive || presentation != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = DiscountOffer.windowRemaining(startedAt: startedAt, now: context.date)
                    // Une pile, et pas un groupe : même vide, elle existe, et c'est elle qui
                    // voit la fenêtre finir.
                    ZStack {
                        // À zéro, plus rien à montrer : la pastille ne reste montée que pour
                        // l'offre qu'elle a ouverte.
                        if left > 0 {
                            Button {
                                presentation = .paywall
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
                .micaboDiscountOffer($presentation)
                .onChange(of: presentation != nil) { _, isOpen in
                    DiscountWindow.shared.hold(isOpen)
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
