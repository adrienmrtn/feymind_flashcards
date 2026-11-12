import SwiftUI

// L'acte 4, avant le paywall : l'essai offert, puis le rappel promis. Deux écrans, une idée
// chacun. Ils ne s'affichent que si la boutique propose encore l'essai à cet élève
// (`OnboardingTrial.isOffered`) : on ne promet pas des jours qu'Apple ne donnera pas.

// MARK: - L'essai offert

/// **« Je t'offre 3 jours pour essayer ton plan »** : la durée est lue sur le produit
/// (`OnboardingTrial.days`), jamais écrite ici. Un grand Mika heureux, et ce qui rassure :
/// rien à payer aujourd'hui.
struct FreeTrialIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var title: String {
        i18n.t("ios.onb10.trial.title", ["days": OnbWords.duration(days: OnboardingTrial.days, locale: i18n.locale)])
    }

    var body: some View {
        V3Screen {
            OnbTitle(title, size: OnbLayout.display, alignment: .center)
                .padding(.top, OnbLayout.titleTop)

            Spacer(minLength: 16)
                .layoutPriority(-1)

            OnbHeroMika(mood: .happy, max: OnbLayout.heroWelcome)

            Spacer(minLength: 16)
                .layoutPriority(-1)
        } footer: {
            OnbReassurance(text: i18n.t("ios.onb5.trial.noCharge"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}

// MARK: - Le rappel promis

/// **« Je te préviens avant la fin de ton essai »** : la promesse d'un rappel, faite seulement
/// si elle peut être tenue.
///
/// Le rappel est une notification locale, posée à l'achat de l'essai (`TrialEndReminder`). Si
/// l'élève n'a jamais vu la demande d'iOS, « Continuer » l'ouvre ici, pour ce rappel-là. S'il
/// a refusé les notifications, l'écran ne promet plus rien qu'il ne puisse envoyer : le titre
/// devient « Tu annules quand tu veux, en 2 touches », et la cloche un cadenas ouvert.
struct TrialOfferStepView: View {
    /// Pour les rendus : l'écran tel que le voit quelqu'un qui a refusé les notifications.
    var previewDenied: Bool?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Vrai tant que le rappel peut partir : notifications permises, ou jamais demandées.
    @State private var canRemind = true
    /// Vrai le temps que la boîte du système soit à l'écran.
    @State private var isAsking = false

    private var promises: Bool {
        previewDenied.map { !$0 } ?? canRemind
    }

    /// **Le rappel peut-il être promis ?** Il faut que les notifications ne soient pas
    /// refusées, et que l'essai soit assez long pour avoir une veille (`TrialEndReminder`
    /// ne pose rien pour un essai d'un jour).
    static func canPromise(notificationsAllowed: Bool, trialDays: Int, now: Date = Date()) -> Bool {
        notificationsAllowed && TrialEndReminder.fireDate(purchasedAt: now, trialDays: trialDays) != nil
    }

    /// **Le titre, selon que le rappel peut partir ou non.** Refusé, l'écran ne parle plus de
    /// prévenir : il dit ce qui reste vrai, qu'on annule quand on veut.
    static func titleKey(canRemind: Bool) -> String {
        canRemind ? "ios.onb10.trial.remind" : "ios.onb10.trial.anytime"
    }

    /// La ligne verte au-dessus du bouton. Refusé, le titre dit déjà qu'on annule quand on
    /// veut ; la ligne dit le reste.
    static func reassuranceKey(canRemind: Bool) -> String {
        canRemind ? "ios.onb10.trial.cancel" : "ios.onb5.trial.noCharge"
    }

    var body: some View {
        V3Screen {
            OnbTitle(i18n.t(Self.titleKey(canRemind: promises)), size: OnbLayout.display, alignment: .center)
                .padding(.top, OnbLayout.titleTop)

            Spacer(minLength: 16)
                .layoutPriority(-1)

            scene

            Spacer(minLength: 16)
                .layoutPriority(-1)
        } footer: {
            OnbReassurance(text: i18n.t(Self.reassuranceKey(canRemind: promises)))
            V3Button(i18n.t("common.continue"), isLoading: isAsking) {
                Task { await proceed() }
            }
        }
        .task {
            guard previewDenied == nil else { return }
            let allowed = await TrialEndReminder.canBeKept()
            canRemind = Self.canPromise(notificationsAllowed: allowed, trialDays: OnboardingTrial.days)
        }
    }

    /// Mika, et à côté de lui ce qu'il promet : une cloche et son « 1 », ou un cadenas ouvert.
    private var scene: some View {
        HStack(alignment: .bottom, spacing: 6) {
            MikaMascot(mood: promises ? .happy : .wink, size: 170)
            emblem
                .padding(.bottom, 26)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }

    private var emblem: some View {
        Image(systemName: promises ? "bell.fill" : "lock.open.fill")
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(promises ? V3Color.yellow : V3Color.green)
            .frame(width: 92, height: 92)
            .overlay(alignment: .topTrailing) {
                if promises {
                    Text(verbatim: "1")
                        .font(V3Font.label)
                        .monospacedDigit()
                        .foregroundStyle(V3Color.onAccent)
                        .frame(width: 30, height: 30)
                        .background(V3Color.red, in: Circle())
                        .overlay(Circle().strokeBorder(V3Color.bg, lineWidth: 3))
                        .padding(.trailing, 4)
                        .padding(.top, -2)
                }
            }
            .contentTransition(.symbolEffect(.replace))
    }

    /// **« Continuer »** : si la demande d'iOS n'a jamais été montrée, elle s'ouvre ici (le
    /// rappel en dépend) ; déjà tranchée, rien ne s'affiche. Puis le parcours avance, quoi
    /// qu'elle réponde : le paywall, lui non plus, ne promet pas un rappel refusé.
    private func proceed() async {
        guard !isAsking else { return }
        guard promises, previewDenied == nil else {
            model.advance()
            return
        }
        isAsking = true
        let outcome = await NotificationPermission.request()
        isAsking = false
        if case .denied = outcome { canRemind = false }
        model.advance()
    }
}
