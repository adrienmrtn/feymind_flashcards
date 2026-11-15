import SwiftUI
import UserNotifications

// L'acte 7, avant le paywall (lot 13) : l'essai, en deux écrans, une idée chacun. Ils ne
// s'affichent que si la boutique propose encore l'essai à cet élève (`OnboardingTrial.isOffered`) :
// on ne promet pas des jours qu'Apple ne donnera pas. Les noms des statistiques restent ceux
// d'avant (`freeTrialIntro`, `trialOffer`).

// MARK: - « On veut que tu essaies Micabo Pro gratuitement »

/// **« On veut que tu essaies Micabo Pro gratuitement »** (lot 13, mots de l'utilisateur).
///
/// Mika en grand, le titre, puis **trois choses que l'essai ouvre, tirées des réponses** : sa
/// première leçon (le sujet qu'il vient d'écrire), Mika dans sa matière la plus dure, les
/// examens blancs de son examen. Au pied, « Rien à payer aujourd'hui », et le bouton.
struct FreeTrialIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    /// Ce que l'essai ouvre : une icône, une phrase.
    struct Unlock: Identifiable, Equatable {
        var id: String { text }
        let icon: MicaboIcon
        let text: String
    }

    /// **Les trois choses**, dans l'ordre où l'élève les a dites : sa leçon, sa matière, son
    /// examen. Une réponse absente prend la phrase de tout le monde (les vraies limites du
    /// gratuit, `PaywallFeature`).
    static func unlocks(for model: OnboardingModel, locale: UiLocale) -> [Unlock] {
        let lesson: String = switch model.firstLessonChoice {
        case .topic:
            model.firstLessonSubject.map { L10n.t("ios.onb12.trial.unlock.lesson", locale: locale, vars: ["topic": $0]) }
                ?? L10n.t("ios.pay12.benefit.lessons", locale: locale)
        case .importSource:
            L10n.t("ios.onb12.trial.unlock.import", locale: locale)
        case nil:
            L10n.t("ios.pay12.benefit.lessons", locale: locale)
        }
        let mika = model.focusSubject.map {
            L10n.t("ios.onb12.trial.unlock.mika", locale: locale, vars: ["subject": SubjectDisplay.subject($0, locale: locale)])
        } ?? L10n.t("ios.pay12.benefit.mika", locale: locale)
        // « pour le Bac », pas « pour Bac » : en français, l'examen prend son article.
        let exam = model.examName(locale: locale).map {
            L10n.t("ios.onb12.trial.unlock.exam", locale: locale, vars: ["exam": locale == .fr ? PaywallProfile.frenchArticled($0) : $0])
        } ?? L10n.t("ios.pay12.benefit.exams", locale: locale)
        return [
            Unlock(icon: .book, text: lesson),
            Unlock(icon: .mika, text: mika),
            Unlock(icon: .exam, text: exam),
        ]
    }

    var body: some View {
        OnbScreen {
            OnbHeroMika(mood: .happy, max: compact ? 96 : 150, min: 72)
                .padding(.top, 4)

            OnbTitle(i18n.t("ios.onb12.trial.wantTitle"), size: OnbLayout.display, alignment: .center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: compact ? 14 : 20) {
                ForEach(Self.unlocks(for: model, locale: i18n.locale)) { unlock in
                    HStack(spacing: 14) {
                        OnbIcon(icon: unlock.icon, size: 28)
                        Text(unlock.text)
                            .font(V3Font.bodyStrong)
                            .foregroundStyle(V3Color.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            // Lot 14 : sans carte autour — trois lignes, de l'air.
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, compact ? 18 : 28)
        } footer: {
            OnbReassurance(text: i18n.t("ios.pay10.nothingToday"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}

// MARK: - « On t'enverra un rappel avant la fin de ton essai »

/// **« On t'enverra un rappel avant la fin de ton essai »** (lot 13) : une cloche, la
/// chronologie aux vraies dates — aujourd'hui tout s'ouvre, la veille de la fin le rappel, puis
/// l'abonnement commence sauf annulation —, et l'autorisation des notifications.
///
/// - **Jamais demandée** : « Activer le rappel » ouvre la demande d'iOS, puis le paywall, quoi
///   qu'elle réponde.
/// - **Déjà accordée** : une simple confirmation, et « Continuer ».
/// - **Refusée** : l'écran ne promet plus de rappel qu'il ne pourrait pas envoyer ; le titre dit
///   ce qui reste vrai (« Tu annules quand tu veux »), et comment le réactiver.
struct TrialOfferStepView: View {
    /// L'état de l'autorisation des notifications.
    enum Permission: Equatable {
        case ask
        case granted
        case denied
    }

    /// Pour les rendus : l'état à montrer, sans le demander à iOS.
    var previewPermission: Permission?
    /// **L'instant d'où partent les dates**, le même que celui du paywall qui suit (les rendus
    /// posent le leur, celui des rendus du paywall).
    var now = Date()

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    @State private var permission: Permission = .ask
    /// Vrai le temps que la boîte du système soit à l'écran.
    @State private var isAsking = false

    private var current: Permission { previewPermission ?? permission }

    /// **Le rappel peut-il être promis ?** Pas avec des notifications refusées, ni pour un
    /// essai trop court pour avoir une veille (`TrialEndReminder` ne pose rien alors).
    static func promises(_ permission: Permission, trialDays: Int, now: Date = Date()) -> Bool {
        permission != .denied && TrialEndReminder.fireDate(purchasedAt: now, trialDays: trialDays) != nil
    }

    private var promises: Bool {
        Self.promises(current, trialDays: OnboardingTrial.days, now: now)
    }

    var body: some View {
        OnbScreen {
            bell
                .padding(.top, compact ? 4 : 12)
                .frame(maxWidth: .infinity)

            OnbTitle(
                i18n.t(promises ? "ios.onb12.trial.remindTitle" : "ios.onb12.trialOffer.anytime"),
                size: OnbLayout.questionTitle,
                alignment: .center
            )
            .padding(.top, 12)

            OnbTrialTimeline(milestones: TrialTimeline.milestones(from: now, locale: i18n.locale, remindersOn: promises))
                .padding(.top, compact ? 14 : 20)
        } footer: {
            switch current {
            case .granted:
                OnbReassurance(text: i18n.t("ios.onb12.trial.granted"))
                V3Button(i18n.t("common.continue")) { model.advance() }
            case .ask:
                V3Button(i18n.t("ios.onb12.trial.enable"), isLoading: isAsking) {
                    Task { await ask() }
                }
            case .denied:
                OnbReassurance(text: i18n.t("ios.onb12.trial.denied"))
                V3Button(i18n.t("common.continue")) { model.advance() }
            }
        }
        .task {
            guard previewPermission == nil else { return }
            permission = await Self.currentPermission()
        }
    }

    /// La cloche du rappel, dans le jaune de l'offre.
    private var bell: some View {
        Image(systemName: promises ? "bell.badge.fill" : "bell.slash.fill")
            .font(.system(size: compact ? 34 : 44, weight: .bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(V3Color.yellow)
            .frame(width: compact ? 76 : 96, height: compact ? 76 : 96)
            .background(V3Color.wash(of: V3Color.yellow), in: Circle())
            .accessibilityHidden(true)
    }

    /// L'autorisation, telle qu'iOS la donne.
    static func currentPermission() async -> Permission {
        switch await UNUserNotificationCenter.current().notificationSettings().authorizationStatus {
        case .notDetermined: .ask
        case .denied: .denied
        default: .granted
        }
    }

    /// **« Activer le rappel »** : la demande d'iOS, puis le paywall, quoi qu'elle réponde (le
    /// paywall, lui non plus, ne promet pas un rappel refusé).
    private func ask() async {
        guard !isAsking else { return }
        isAsking = true
        let outcome = await NotificationPermission.request()
        isAsking = false
        if case .denied = outcome { permission = .denied }
        model.advance()
    }
}

// MARK: - La chronologie de l'essai

/// **Ce qui se passe, jour par jour, avec de vraies dates** : aujourd'hui tout s'ouvre, la
/// veille de la fin un rappel (ou comment l'activer), puis le jour où l'abonnement commence,
/// sauf si l'élève a annulé.
struct OnbTrialTimeline: View {
    let milestones: [TrialTimeline.Milestone]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Image(systemName: milestone.systemImage)
                            .font(V3Font.label)
                            .foregroundStyle(tint(milestone.tone))
                            .frame(width: 34, height: 34)
                            .background(V3Color.wash(of: tint(milestone.tone)), in: Circle())
                        if index < milestones.count - 1 {
                            Rectangle()
                                .fill(V3Color.line)
                                .frame(width: 2)
                                .frame(minHeight: 18, maxHeight: .infinity)
                        }
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(milestone.title)
                            .font(V3Font.cardTitle)
                            .foregroundStyle(V3Color.ink)
                        Text(milestone.detail)
                            .font(V3Font.support)
                            .foregroundStyle(V3Color.ink2)
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 5)
                    .padding(.bottom, index < milestones.count - 1 ? 12 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        // Lot 14 : la chronologie se lit sans carte autour.
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tint(_ tone: TrialTimeline.Tone) -> Color {
        switch tone {
        case .done: V3Color.green
        case .current: V3Color.accentBright
        case .upcoming: V3Color.yellow
        }
    }
}
