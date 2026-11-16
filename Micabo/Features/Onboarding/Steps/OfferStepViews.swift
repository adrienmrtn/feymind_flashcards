import SwiftUI
import UserNotifications

// L'acte 7, avant le paywall (lot 13) : l'essai, en deux écrans, une idée chacun. Ils ne
// s'affichent que si la boutique propose encore l'essai à cet élève (`OnboardingTrial.isOffered`) :
// on ne promet pas des jours qu'Apple ne donnera pas. Les noms des statistiques restent ceux
// d'avant (`freeTrialIntro`, `trialOffer`).

// MARK: - « On veut que tu essaies Micabo Pro gratuitement »

/// **« On veut que tu essaies Micabo Pro gratuitement »** (lot 13, mots de l'utilisateur).
///
/// Lot 17 : **le cadeau, seul, sans prix** (le comment vient à l'écran suivant, le choix au
/// paywall). Le titre, Mika et « 3 jours offerts » en grand, puis **trois choses que l'essai
/// ouvre, tirées des réponses** : sa première leçon (citée seulement s'il a tapé un sujet),
/// Mika dans sa matière la plus dure, les examens blancs de son examen. Au pied, « Rien à
/// payer aujourd'hui », et « Je veux essayer ».
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
        // Lot 17 : une leçon n'est citée que si l'élève a vraiment tapé son sujet ; sinon,
        // « Ta première leçon, et toutes les suivantes » — jamais un titre inventé.
        let lesson: String = switch model.firstLessonChoice {
        case .topic:
            model.firstLessonSubject.map { L10n.t("ios.onb12.trial.unlock.lesson", locale: locale, vars: ["topic": $0]) }
                ?? L10n.t("ios.onb17.trial.unlock.lessonAny", locale: locale)
        case .importSource:
            L10n.t("ios.onb12.trial.unlock.import", locale: locale)
        case nil:
            L10n.t("ios.onb17.trial.unlock.lessonAny", locale: locale)
        }
        let mika = model.focusSubject.map {
            L10n.t("ios.onb12.trial.unlock.mika", locale: locale, vars: ["subject": SubjectDisplay.subject($0, locale: locale)])
        } ?? L10n.t("ios.pay11.row.mika", locale: locale)
        // « pour le Bac », pas « pour Bac » : en français, l'examen prend son article.
        let exam = model.examName(locale: locale).map {
            L10n.t("ios.onb12.trial.unlock.exam", locale: locale, vars: ["exam": locale == .fr ? PaywallProfile.frenchArticled($0) : $0])
        } ?? L10n.t("ios.pay11.row.exams", locale: locale)
        return [
            Unlock(icon: .book, text: lesson),
            Unlock(icon: .mika, text: mika),
            Unlock(icon: .exam, text: exam),
        ]
    }

    var body: some View {
        // Lot 15 : la grille de tout le parcours — le titre en haut à gauche, les trois lignes
        // au centre optique, au corps de lecture (20 pt, couleur principale).
        OnbScreen {
            OnbTitle(i18n.t("ios.onb12.trial.wantTitle"), size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbCentered {
                VStack(alignment: .leading, spacing: compact ? 18 : 24) {
                    gift
                        .padding(.bottom, compact ? 4 : 10)
                    ForEach(Self.unlocks(for: model, locale: i18n.locale)) { unlock in
                        HStack(spacing: 16) {
                            OnbIcon(icon: unlock.icon, size: 30)
                                .frame(width: 56, height: 56)
                                .background(V3Color.surface, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                            Text(unlock.text)
                                .font(OnbType.body)
                                .lineSpacing(OnbType.bodySpacing)
                                .foregroundStyle(V3Color.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        } footer: {
            OnbReassurance(text: i18n.t("ios.pay10.nothingToday"))
            V3Button(i18n.t("ios.onb17.trial.cta")) {
                model.advance()
            }
        }
    }

    /// **Le cadeau** (lot 17) : Mika content, « 3 jours » en très grand, « offerts, tout
    /// compris » dessous. La durée est celle que la boutique accorde (`OnboardingTrial.days`).
    private var gift: some View {
        HStack(alignment: .center, spacing: 14) {
            MikaMascot(mood: .happy, size: compact ? 72 : 100)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("ios.onb17.trial.days", ["n": "\(OnboardingTrial.days)"]))
                    .font(V3Font.display(compact ? 48 : 60))
                    .foregroundStyle(V3Color.yellow)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(i18n.t("ios.onb17.trial.daysSub"))
                    .font(OnbType.body.weight(.bold))
                    .foregroundStyle(V3Color.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
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
        // Lot 15 : la grille de tout le parcours — le titre en haut à gauche, la frise datée au
        // centre optique, au corps de lecture.
        OnbScreen {
            OnbTitle(
                i18n.t(promises ? "ios.onb12.trial.remindTitle" : "ios.onb12.trialOffer.anytime"),
                size: OnbLayout.questionTitle
            )
            .padding(.top, OnbLayout.titleTop)

            OnbCentered {
                OnbTrialTimeline(milestones: TrialTimeline.milestones(from: now, locale: i18n.locale, remindersOn: promises))
            }
        } footer: {
            switch current {
            case .granted:
                OnbReassurance(text: i18n.t("ios.onb12.trial.granted"))
                V3Button(i18n.t("common.continue")) { model.advance() }
            case .ask:
                // Lot 17 : une seule ligne pour rassurer, au-dessus du bouton.
                Text(i18n.t("ios.onb17.trial.cancel"))
                    .font(OnbType.mention)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
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
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(tint(milestone.tone))
                            .frame(width: 46, height: 46)
                            .background(V3Color.wash(of: tint(milestone.tone)), in: Circle())
                        if index < milestones.count - 1 {
                            Rectangle()
                                .fill(V3Color.line)
                                .frame(width: 2)
                                .frame(minHeight: 18, maxHeight: .infinity)
                        }
                    }
                    .accessibilityHidden(true)

                    // Lot 15 : le titre de l'étape à 20 pt, son détail à 17 pt, en couleur
                    // principale — c'est ce qu'on lit avant de payer.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title)
                            .font(.system(.title3, design: .default, weight: .bold))
                            .foregroundStyle(V3Color.ink)
                        Text(milestone.detail)
                            .font(OnbType.detail)
                            .foregroundStyle(V3Color.ink)
                    }
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.bottom, index < milestones.count - 1 ? 22 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        // Lot 14 : la chronologie se lit sans carte autour, à sa hauteur naturelle.
        .fixedSize(horizontal: false, vertical: true)
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
