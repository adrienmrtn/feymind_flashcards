import SwiftUI

// L'acte 4, avant le paywall : l'essai offert, puis le rappel promis. Deux écrans, une idée
// chacun. Ils ne s'affichent que si la boutique propose encore l'essai à cet élève
// (`OnboardingTrial.isOffered`) : on ne promet pas des jours qu'Apple ne donnera pas.

// MARK: - Ce que l'essai débloque

/// **« {n jours} pour tout essayer »** (lot 11) : ce que l'essai ouvre, dit avec ce que
/// l'élève vient de construire. Sa première leçon (offerte de toute façon : on le dit), ses
/// matières, les quiz et les cartes, le scanner, son plan jusqu'à son examen, Mika. La durée
/// est lue sur le produit (`OnboardingTrial.days`), jamais écrite ici.
///
/// L'écran disait « Je t'offre 3 jours pour essayer ton plan » au-dessus d'un grand Mika :
/// l'élève ne savait pas ce que « essayer » ouvrait. Le nom de l'étape reste `freeTrialIntro`.
struct FreeTrialIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var title: String {
        i18n.t("ios.onb11.unlock.title", ["days": OnbWords.duration(days: OnboardingTrial.days, locale: i18n.locale)])
    }

    /// Ce que l'essai ouvre, dans l'ordre où l'élève l'a vu passer.
    struct Unlock: Identifiable {
        var id: String { text }
        let icon: MicaboIcon
        let text: String
        /// Vrai pour la première leçon : elle reste offerte sans abonnement.
        var isFree = false
    }

    static func unlocks(for model: OnboardingModel, locale: UiLocale) -> [Unlock] {
        let lesson: String = switch model.firstLessonChoice {
        case .topic:
            model.firstLessonSubject.map { L10n.t("ios.onb11.unlock.lesson", locale: locale, vars: ["topic": $0]) }
                ?? L10n.t("ios.onb11.unlock.lessonAny", locale: locale)
        case .importSource:
            L10n.t("ios.onb11.unlock.lessonImport", locale: locale)
        case nil:
            L10n.t("ios.onb11.unlock.lessonAny", locale: locale)
        }
        let plan = model.examName(locale: locale).map {
            L10n.t("ios.onb11.unlock.plan", locale: locale, vars: ["exam": $0])
        } ?? L10n.t("ios.onb11.unlock.planAny", locale: locale)
        return [
            Unlock(icon: .book, text: lesson, isFree: true),
            Unlock(icon: .notes, text: L10n.t("ios.onb11.unlock.subjects", locale: locale)),
            Unlock(icon: .quiz, text: L10n.t("ios.onb11.unlock.quiz", locale: locale)),
            Unlock(icon: .photo, text: L10n.t("ios.onb11.unlock.scan", locale: locale)),
            Unlock(icon: .exam, text: plan),
            Unlock(icon: .mika, text: L10n.t("ios.onb11.unlock.mika", locale: locale)),
        ]
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.pageTitle + 2, alignment: .center, keyword: V3Color.yellow)
                .padding(.top, OnbLayout.titleTop)

            Spacer(minLength: OnbLayout.titleGap)
                .layoutPriority(-1)

            VStack(spacing: 0) {
                ForEach(Array(Self.unlocks(for: model, locale: i18n.locale).enumerated()), id: \.element.id) { index, unlock in
                    if index > 0 {
                        Rectangle()
                            .fill(V3Color.line)
                            .frame(height: 1.5)
                    }
                    row(unlock)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .v3Card()

            Text(i18n.t("ios.onb11.unlock.freeNote"))
                .font(V3Font.caption)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)

            Spacer(minLength: 12)
                .layoutPriority(-1)
        } footer: {
            OnbReassurance(text: i18n.t("ios.onb5.trial.noCharge"))
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }

    private func row(_ unlock: Unlock) -> some View {
        HStack(spacing: 12) {
            OnbIcon(icon: unlock.icon, size: 26)
            Text(unlock.text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if unlock.isFree {
                StoryTag(text: i18n.t("ios.onb11.unlock.free"), tone: V3Color.green)
            } else {
                Image(systemName: "checkmark")
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.green)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Le rappel promis

/// **« Je te préviens avant la fin de ton essai »** : la promesse d'un rappel, faite seulement
/// si elle peut être tenue.
///
/// Le rappel est une notification locale, posée à l'achat de l'essai (`TrialEndReminder`). Si
/// l'élève n'a jamais vu la demande d'iOS, « Continuer » l'ouvre ici, pour ce rappel-là. S'il
/// a refusé les notifications, l'écran ne promet plus rien qu'il ne puisse envoyer : le titre
/// devient « Tu annules quand tu veux, en 2 touches », et la ligne du rappel dit comment
/// l'activer.
///
/// **Ce qui se passe à la fin de l'essai, en dates** (lot 11) : la chronologie remplace la
/// cloche dessinée à côté de Mika, que les élèves ne reliaient pas à l'abonnement.
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
        OnbScreen {
            OnbTitle(i18n.t(Self.titleKey(canRemind: promises)), size: OnbLayout.pageTitle + 2, alignment: .center)
                .padding(.top, OnbLayout.titleTop)

            Spacer(minLength: OnbLayout.titleGap)
                .layoutPriority(-1)

            OnbTrialTimeline(milestones: TrialTimeline.milestones(locale: i18n.locale, remindersOn: promises))

            Spacer(minLength: 12)
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

// MARK: - La chronologie de l'essai

/// **Ce qui se passe, jour par jour, avec de vraies dates** (repris du lot 7, où « Jour 2 » se
/// lisait le lendemain) : aujourd'hui tout s'ouvre, la veille de la fin un rappel (ou comment
/// l'activer), puis le jour où l'abonnement commence, sauf si l'élève a annulé.
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
                            .frame(width: 40, height: 40)
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
                    .padding(.top, 8)
                    .padding(.bottom, index < milestones.count - 1 ? 18 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card()
    }

    private func tint(_ tone: TrialTimeline.Tone) -> Color {
        switch tone {
        case .done: V3Color.green
        case .current: V3Color.accentBright
        case .upcoming: V3Color.yellow
        }
    }
}

// MARK: - Pourquoi maintenant

/// **Le dernier écran avant l'offre : pourquoi commencer ce soir** (lot 11). Rien d'inventé :
/// le temps qu'il reste avant son examen, les séances que ça laisse à sa durée (une par jour,
/// à partir d'aujourd'hui), sa première leçon prête, son rappel. Sans examen daté : la
/// première séance de ce soir.
struct WhyNowStepView: View {
    var now = Date()

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Les séances d'ici l'examen, une par jour à partir d'aujourd'hui : rien sans examen daté
    /// ou le jour même.
    static func sessionsLeft(daysLeft: Int?) -> Int? {
        guard let daysLeft, daysLeft > 1 else { return nil }
        return daysLeft
    }

    private var daysLeft: Int? { model.examDaysLeft(now: now) }

    private var title: String {
        if let exam = model.examName(locale: i18n.locale), let days = daysLeft, days > 0 {
            return i18n.t("ios.onb11.now.title", [
                "exam": exam,
                "time": OnbWords.duration(days: days, locale: i18n.locale),
            ])
        }
        return i18n.t("ios.onb11.now.titleAny")
    }

    private var rows: [(icon: MicaboIcon, text: String)] {
        let minutes = "\(model.minutesPerDay)"
        let hour = OnbWords.hour(model.reminderHour, locale: i18n.locale)
        var rows: [(icon: MicaboIcon, text: String)] = []
        if let sessions = Self.sessionsLeft(daysLeft: daysLeft) {
            rows.append((icon: .flame, text: i18n.t("ios.onb11.now.sessions", ["n": "\(sessions)", "min": minutes])))
        }
        switch model.firstLessonChoice {
        case .topic:
            if let topic = model.firstLessonSubject {
                rows.append((icon: .book, text: i18n.t("ios.onb11.now.lesson", ["topic": topic])))
            }
        case .importSource:
            rows.append((icon: .photo, text: i18n.t("ios.onb11.now.import")))
        case nil:
            break
        }
        rows.append((icon: .alarm, text: i18n.t("ios.onb11.now.tonight", ["hour": hour, "min": minutes])))
        return rows
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.display, alignment: .center, keyword: V3Color.yellow)
                .padding(.top, OnbLayout.titleTop)

            Spacer(minLength: 12)
                .layoutPriority(-1)

            OnbHeroMika(mood: .happy, max: 150, min: 90)

            Spacer(minLength: 12)
                .layoutPriority(-1)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .center, spacing: 12) {
                        OnbIcon(icon: row.icon, size: 28)
                        Text(row.text)
                            .font(V3Font.bodyStrong)
                            .foregroundStyle(V3Color.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
        } footer: {
            V3Button(i18n.t(OnboardingTrial.isOffered ? "ios.onb11.now.cta" : "common.continue")) {
                model.advance()
            }
        }
    }
}
