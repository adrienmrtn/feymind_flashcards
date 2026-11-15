import SwiftUI

// MARK: - Le temps par jour

/// **« Combien de temps par jour sur Micabo ? »** (lot 14 : un curseur jusqu'à 2 h.) Les crans
/// de `DailyLoad.steps` : 5 minutes jusqu'à une demi-heure, puis 15 minutes jusqu'à 2 h. La
/// durée en très grand, et un mot qui qualifie le rythme. C'est de ce temps que `DailyLoad`
/// tire le nombre de cartes du plan.
struct DailyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    /// Le cran proposé d'abord : quinze minutes.
    static let advised = 15

    /// « 15 min », « 1 h 30 », « 1時間30分 » : une durée écrite par le système, dans la langue.
    static func duration(_ minutes: Int, locale: UiLocale) -> String {
        Duration.seconds(minutes * 60).formatted(
            .units(allowed: [.hours, .minutes], width: .abbreviated)
                .locale(locale.foundation)
        )
    }

    /// **Le mot du rythme** : tranquille, régulier, sérieux, intense, à fond.
    static func qualifierKey(_ minutes: Int) -> String {
        switch minutes {
        case ..<10: "ios.onb10.time.5"
        case ..<15: "ios.onb10.time.10"
        case ..<30: "ios.onb10.time.15"
        case ..<60: "ios.onb10.time.30"
        default: "ios.onb14.time.max"
        }
    }

    private var minutes: Int { DailyLoad.nearestStep(to: model.dailyMinutes ?? Self.advised) }

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb12.q.time"),
            say: OnbSay(i18n.t("ios.onb12.say.time"), mood: .idle)
        ) {
            VStack(spacing: compact ? 18 : 30) {
                OnbSliderValue(
                    label: Self.duration(minutes, locale: i18n.locale),
                    qualifier: i18n.t(Self.qualifierKey(minutes))
                )
                OnbNotchSlider(
                    count: DailyLoad.steps.count,
                    index: Binding(
                        get: { DailyLoad.stepIndex(for: minutes) },
                        set: { model.dailyMinutes = DailyLoad.minutes(atStepIndex: $0) }
                    ),
                    lowerBound: Self.duration(DailyLoad.minimumMinutes, locale: i18n.locale),
                    upperBound: Self.duration(DailyLoad.maximumMinutes, locale: i18n.locale),
                    accessibilityLabel: OnbPhrase.plain(i18n.t("ios.onb12.q.time")),
                    valueText: { Self.duration(DailyLoad.minutes(atStepIndex: $0), locale: i18n.locale) }
                )
            }
            .padding(.top, compact ? 8 : 28)
            .frame(maxWidth: .infinity)
            .onAppear {
                // La réponse existe dès l'affichage, comme le curseur le montre.
                if model.dailyMinutes == nil { model.dailyMinutes = Self.advised }
            }
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: model.dailyMinutes != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - Le rappel quotidien

/// **« Je te fais signe chaque jour à 18 h ? »** Le rappel, montré avant d'être demandé.
///
/// La page montre le rappel tel qu'iOS l'afficherait : le prénom, le nombre de cartes que son
/// temps par jour donne vraiment (`DailyLoad`), sa matière. L'heure se change d'un appui. Le
/// bouton ouvre **la vraie boîte de dialogue d'iOS** ; « Plus tard » avance sans l'ouvrir.
struct NotificationsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Vrai le temps que la boîte du système soit à l'écran.
    @State private var isAsking = false
    @State private var showsHourPicker = false

    /// De cinq heures à vingt-trois heures : personne ne se fait rappeler à trois heures.
    static let hours = Array(5...23)

    private var hourText: String {
        OnbWords.hour(model.reminderHour, locale: i18n.locale)
    }

    var body: some View {
        OnbScreen {
            OnbTitle(i18n.t("ios.onb10.notif.title", ["hour": hourText]), size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbMikaRow(say: OnbSay(i18n.t("ios.onb7.notif.one"), mood: .wink))
                .padding(.top, OnbLayout.mikaGap)

            notification
                .padding(.top, OnbLayout.answersGap + 4)

            V3Chip(i18n.t("ios.onb10.notif.change", ["hour": hourText]), systemImage: "clock") {
                showsHourPicker = true
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
        } footer: {
            V3Button(i18n.t("ios.onb10.notif.enable"), isLoading: isAsking) {
                Task { await ask() }
            }
            V3Button(i18n.t("ios.onb10.later"), kind: .ghost, isEnabled: !isAsking) {
                model.advance()
            }
        }
        .onAppear {
            // L'heure affichée est une réponse : elle s'enregistre telle qu'on la voit.
            if model.studyHour == nil { model.studyHour = DailyReminder.defaultHour }
        }
        .sheet(isPresented: $showsHourPicker) {
            hourPicker
        }
    }

    // MARK: La notification

    /// La phrase de l'exemple, tirée des réponses : le prénom, les cartes de son temps par
    /// jour, sa matière (la plus dure d'abord) ; « avant ton contrôle » s'il en a annoncé un.
    static func message(for model: OnboardingModel, locale: UiLocale) -> String {
        let subject = model.focusSubject.map { SubjectDisplay.subject($0, locale: locale) } ?? model.firstSubjectName(locale: locale)
        let vars = [
            "name": model.displayName.nilIfBlank ?? "",
            "count": "\(model.cardsPerDay)",
            "subject": subject ?? "",
            "min": "\(model.minutesPerDay)",
        ]
        guard model.displayName.nilIfBlank != nil, subject != nil else {
            return L10n.t("ios.onb10.notif.bodyPlain", locale: locale, vars: vars)
        }
        if model.examChoice == .test {
            return L10n.t("ios.onb10.notif.bodyTest", locale: locale, vars: vars)
        }
        return L10n.t("ios.onb10.notif.body", locale: locale, vars: vars)
    }

    /// L'exemple, tel qu'iOS affiche un rappel : l'avatar de Mika, son nom, l'heure.
    private var notification: some View {
        HStack(alignment: .top, spacing: 12) {
            MikaAvatar(size: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Micabo")
                        .font(V3Font.label)
                        .foregroundStyle(V3Color.ink)
                    Spacer(minLength: 8)
                    Text(hourText)
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink3)
                }
                Text(Self.message(for: model, locale: i18n.locale))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card()
        .accessibilityElement(children: .combine)
    }

    // MARK: L'heure

    private var hourBinding: Binding<Int> {
        Binding(
            get: { model.reminderHour },
            set: { model.studyHour = $0 }
        )
    }

    /// Le choix de l'heure : la roue du système, dans une feuille.
    private var hourPicker: some View {
        VStack(spacing: 16) {
            Text(i18n.t("ios.onb10.hour.title"))
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Picker(i18n.t("ios.onb10.hour.title"), selection: hourBinding) {
                ForEach(Self.hours, id: \.self) { hour in
                    Text(OnbWords.hour(hour, locale: i18n.locale))
                        .tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()

            V3Button(i18n.t("ios.done")) {
                showsHourPicker = false
            }
        }
        .padding(.horizontal, OnbLayout.margin)
        .padding(.top, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.locale, i18n.locale.foundation)
        .environment(\.layoutDirection, i18n.locale.isRightToLeft ? .rightToLeft : .leftToRight)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(V3Color.bg)
    }

    // MARK: La vraie demande

    /// Ouvre la boîte du système, puis avance quoi qu'elle réponde.
    private func ask() async {
        guard !isAsking else { return }
        isAsking = true
        await NotificationPermission.request()
        isAsking = false
        model.advance()
    }
}

