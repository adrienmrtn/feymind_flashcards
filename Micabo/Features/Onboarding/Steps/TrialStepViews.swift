import Foundation
import SwiftUI

/// Les quatre moments de l'essai, du compte créé au premier prélèvement.
///
/// La chronologie est calculée à partir d'une date reçue en paramètre plutôt que lue
/// depuis `Date.now` au fond d'une vue : c'est ce qui permet de vérifier la date de
/// premier prélèvement sans attendre trois jours.
enum TrialTimeline {
    /// Durée de l'essai, et seule source de vérité à ce sujet dans le parcours : la date
    /// annoncée sur la chronologie et celle facturée par la boutique doivent être la même.
    static let freeDays = 3

    enum Tone {
        /// Ce qui est déjà fait.
        case done
        /// Ce qui commence maintenant.
        case current
        /// Ce qui arrivera.
        case upcoming
    }

    struct Milestone: Identifiable {
        /// Le libellé fait l'identité. Un `UUID()` tiré à la construction changerait à
        /// chaque recomposition de l'écran, et la cascade repartirait de zéro sous les yeux.
        var id: String { title }
        let title: String
        let detail: String
        let systemImage: String
        let tone: Tone
    }

    static func milestones(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr
    ) -> [Milestone] {
        let dateText = billingDateText(from: date, calendar: calendar, locale: locale)
        return [
            Milestone(
                title: L10n.t("ios.accountCreated", locale: locale),
                detail: L10n.t("ios.trialCreatedDetail", locale: locale),
                systemImage: "checkmark",
                tone: .done
            ),
            Milestone(
                title: L10n.t("ios.trialToday", locale: locale),
                detail: L10n.t("ios.trialTodayDetail", locale: locale),
                systemImage: "lock.open.fill",
                tone: .current
            ),
            Milestone(
                title: L10n.t("ios.trialDay2", locale: locale),
                detail: L10n.t("ios.trialDay2Detail", locale: locale),
                systemImage: "bell.fill",
                tone: .upcoming
            ),
            Milestone(
                title: L10n.t("ios.trialLast", locale: locale, vars: ["n": "\(freeDays)"]),
                detail: L10n.t("ios.trialLastDetail", locale: locale, vars: ["date": dateText]),
                systemImage: "star.fill",
                tone: .upcoming
            )
        ]
    }

    /// Le jour du premier prélèvement, écrit comme on le dirait : « 28 août ».
    static func billingDateText(
        from date: Date = .now,
        calendar: Calendar = .current,
        locale: UiLocale = .fr
    ) -> String {
        let billingDate = calendar.date(byAdding: .day, value: freeDays, to: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.calendar = calendar
        // Le fuseau vient du calendrier, et pas du système : sans lui, un minuit calculé à
        // Paris s'écrit « la veille » dès que l'appareil est réglé plus à l'ouest.
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMMM")
        return formatter.string(from: billingDate)
    }
}

/// **« On veut que tu essaies Micabo gratuitement. »**
///
/// Le premier des écrans d'offre, et il ne parle pas de prix : le produit dans le
/// téléphone, une phrase, « aucun paiement aujourd'hui », un bouton. C'est l'écran de Cal
/// AI, et il fait une seule chose : dire que ce qui vient est gratuit avant de dire ce que
/// ça coûtera.
struct TrialOfferStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var plan: PaywallPlan { PaywallCatalog.recommended }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(showsBack: false)

            Spacer(minLength: MicaboSpacing.sm)

            OnboardingAccentText(template: i18n.t("ios.trial.title"), size: 32)
                .padding(.horizontal, MicaboSpacing.screen)
                .onboardingAppear(index: 1)

            Spacer(minLength: MicaboSpacing.md)

            // Le téléphone de l'accroche, réduit : la même fiche, pour que l'offre parle de
            // ce qu'on a déjà vu.
            OnboardingPhoneMockup()
                .scaleEffect(0.68)
                .frame(height: 360)
                .frame(maxWidth: .infinity)
                .onboardingAppear(index: 2)

            Spacer(minLength: MicaboSpacing.md)
            Spacer(minLength: 0)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 12) {
                    PaywallNoPaymentLine()

                    OnboardingContinueButton(title: i18n.t("ios.tryFree")) {
                        model.advance()
                    }

                    Text(i18n.t("ios.trial.price", ["yearly": plan.displayPrice, "monthly": plan.monthlyEquivalent ?? plan.displayPrice]))
                        .font(MicaboFont.ui(12.5, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                }
                .onboardingAppear(index: 3)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

/// **« On t'enverra un rappel avant la fin de ton essai. »**
///
/// Le seul écran du parcours qui **répond à une question qu'on ne pose jamais à voix
/// haute** : est-ce que je vais me faire prélever sans le voir venir ? Une cloche avec sa
/// pastille, une phrase, « aucun paiement aujourd'hui », et un bouton qui dit « continuer
/// gratuitement ». Y répondre avant le paywall coûte un écran et évite les trois jours
/// d'inquiétude qui font annuler un essai dès la première minute.
struct TrialReminderStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(showsBack: false)

            Spacer(minLength: MicaboSpacing.lg)

            OnboardingAccentText(template: i18n.t("ios.trial.reminder.title"), size: 32)
                .padding(.horizontal, MicaboSpacing.screen)
                .onboardingAppear(index: 1)

            Spacer(minLength: MicaboSpacing.xl)

            PaywallBell()
                .onboardingAppear(index: 2)

            Text(i18n.t("ios.trial.reminder.sub", ["day": "\(max(1, TrialTimeline.freeDays - 1))"]))
                .font(MicaboFont.ui(15, weight: .regular))
                .foregroundStyle(OnboardingPalette.gray)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, MicaboSpacing.xl)
                .padding(.top, MicaboSpacing.xl)
                .onboardingAppear(index: 3)

            Spacer(minLength: MicaboSpacing.lg)
            Spacer(minLength: 0)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 12) {
                    PaywallNoPaymentLine()

                    OnboardingContinueButton(title: i18n.t("ios.trial.reminder.cta")) {
                        model.advance()
                    }
                }
                .onboardingAppear(index: 4)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

/// **La cloche, avec sa pastille rouge.** Grise, immobile, et la pastille qui arrive un
/// instant après elle : c'est une notification qui vient de tomber, pas une cloche qui
/// sonne. Le rouge est celui d'iOS, et c'est la seule fois qu'il apparaît dans le parcours.
private struct PaywallBell: View {
    @State private var hasBadge = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.system(size: 120, weight: .regular))
                .foregroundStyle(OnboardingPalette.cardStrong)

            Text("1")
                .font(MicaboFont.ui(22, weight: .bold))
                .foregroundStyle(OnboardingPalette.white)
                .frame(width: 44, height: 44)
                .background(Color(hex: 0xEF4444), in: Circle())
                .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 3))
                .offset(x: 10, y: -6)
                .opacity(hasBadge ? 1 : 0)
                .animation(OnboardingMotion.enter, value: hasBadge)
        }
        .accessibilityHidden(true)
        .task {
            try? await Task.sleep(for: .milliseconds(700))
            hasBadge = true
            Haptics.light()
        }
    }
}
