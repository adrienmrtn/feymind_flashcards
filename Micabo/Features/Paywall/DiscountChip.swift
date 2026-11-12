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
/// Il relit quand un réglage de l'appareil change (l'ouverture du cadeau, un achat, « Forcer
/// Pro »), quand l'app revient au premier plan, et à chaque seconde tant qu'une pastille est
/// à l'écran : c'est elle qui voit la fenêtre finir.
@MainActor
@Observable
final class DiscountWindow {
    static let shared = DiscountWindow()

    /// L'instant d'ouverture du cadeau, `nil` si personne ne l'a ouvert ici.
    private(set) var startedAt: Date?

    /// Vrai tant qu'une fenêtre court pour un élève sans abonnement.
    private(set) var isLive = false

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

extension DiscountOffer {
    /// **La pastille de la Home se montre-t-elle ?** Tant que la fenêtre court, et jamais à
    /// un abonné. Une fonction pure, pour qu'elle se teste sans vue ni horloge.
    static func isChipLive(isPro: Bool, startedAt: Date?, now: Date = Date()) -> Bool {
        guard !isPro, let startedAt else { return false }
        return isLive(startedAt: startedAt, now: now)
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

// MARK: - La pastille

/// **La pastille de l'offre, en tête de la Home** : « 🎁 −40 % · 23:41:10 ».
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

    @State private var presentation: DiscountPresentation?

    var body: some View {
        let window = DiscountWindow.shared
        Group {
            // L'offre ouverte garde la pastille montée : une fenêtre qui finit pendant qu'on
            // la lit ne doit pas refermer l'écran d'un coup.
            if let startedAt = window.startedAt, window.isLive || presentation != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = DiscountOffer.windowRemaining(startedAt: startedAt, now: context.date)
                    Button {
                        presentation = .paywall
                    } label: {
                        DiscountChipLabel(percent: DiscountOffer.savingsPercent, remaining: left)
                    }
                    .buttonStyle(DiscountChipPressStyle())
                    .accessibilityLabel(L10n.t(
                        "ios.reopenOffer",
                        locale: .resolved(),
                        vars: ["left": DiscountOffer.countdownLabel(left)]
                    ))
                    // La fenêtre vient de finir sous nos yeux : la Home reprend la main.
                    .onChange(of: left > 0) { _, _ in
                        DiscountWindow.shared.refresh()
                    }
                }
                .micaboDiscountOffer($presentation)
            }
        }
    }
}

/// Ce que la pastille montre, sans horloge : c'est ce que les rendus dessinent.
struct DiscountChipLabel: View {
    let percent: Int
    /// Les secondes qui restent sur la fenêtre.
    let remaining: Int
    var locale: UiLocale = .resolved()

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: "🎁")
            Text(verbatim: DiscountOffer.savingsLabel(percent, locale: locale))
            Text(verbatim: "·")
            // Chiffres à chasse fixe : la pastille ne change pas de largeur à chaque seconde.
            Text(verbatim: DiscountOffer.countdown(remaining))
                .monospacedDigit()
        }
        .font(MicaboFont.ui(15, weight: .heavy))
        .foregroundStyle(DiscountChipTone.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 16)
        .frame(minHeight: 38)
        .background(DiscountChipTone.fill, in: Capsule())
        .overlay(Capsule().strokeBorder(DiscountChipTone.edge, lineWidth: 2))
    }
}

/// La lèvre de la pastille : trois points pleins dessous, qui disparaissent sous le doigt.
private struct DiscountChipPressStyle: ButtonStyle {
    private let lip: CGFloat = 3

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? lip : 0)
            .background {
                Capsule()
                    .fill(DiscountChipTone.edge)
                    .offset(y: lip)
            }
            .padding(.bottom, lip)
            .contentShape(Capsule())
            .animation(MicaboPress.animation(isPressed: configuration.isPressed), value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: .light)
    }
}

/// Le jaune de l'offre : lavis, bord et encre, le jour et la nuit.
private enum DiscountChipTone {
    static let fill = adaptive(light: 0xFFF4D6, dark: 0x3A2E10)
    static let edge = adaptive(light: 0xF4D98A, dark: 0x6B5417)
    static let ink = adaptive(light: 0x7A4E00, dark: 0xFFD25E)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        let light = UIColor(Color(hex: light))
        let dark = UIColor(Color(hex: dark))
        return Color(UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
}
