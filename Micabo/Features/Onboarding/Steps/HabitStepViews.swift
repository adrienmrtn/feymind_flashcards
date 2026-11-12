import SwiftUI

// MARK: - Le temps par jour

/// **« Combien de temps par jour ? »** Quatre crans, du plus tranquille au plus intense ;
/// quinze minutes est celui qu'on conseille. Un appui avance. C'est de ce temps que
/// `DailyLoad` tire le nombre de cartes du plan.
struct DailyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Le cran conseillé.
    static let advised = OnboardingDailyTime.fifteen

    var body: some View {
        OnbQuestion(i18n.t("ios.onb10.q.time")) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(OnboardingDailyTime.allCases) { time in
                    V3OptionRow(
                        time.title(locale: i18n.locale),
                        subtitle: time == Self.advised ? i18n.t("ios.onb10.time.advised") : nil,
                        icon: time.icon,
                        isSelected: model.dailyMinutes == time.rawValue
                    ) {
                        model.dailyMinutes = time.rawValue
                        model.advance()
                    }
                }
            }
        }
    }
}

// MARK: - Le rappel quotidien

/// **« Je te fais signe chaque jour à 18 h ? »** Le rappel, montré avant d'être demandé.
///
/// La page montre un exemple du rappel : le prénom, le nombre de cartes que son temps par
/// jour donne vraiment (`DailyLoad`), sa première matière. L'heure se
/// change d'un appui (c'était un écran à part, `studyTime`). Le bouton ouvre **la vraie boîte
/// de dialogue d'iOS**, qu'on ne pose qu'une fois ; « Plus tard » avance sans l'ouvrir, et
/// elle reste disponible ensuite. Un refus n'arrête rien : rien dans Micabo ne dépend des
/// notifications.
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
            OnbTitle(i18n.t("ios.onb10.notif.title", ["hour": hourText]), size: OnbLayout.display)
                .padding(.top, OnbLayout.titleTop)

            notification
                .padding(.top, OnbLayout.titleGap)

            V3Chip(i18n.t("ios.onb10.notif.change", ["hour": hourText]), systemImage: "clock") {
                showsHourPicker = true
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 18)
        } footer: {
            Text(i18n.t("ios.onb7.notif.one"))
                .font(V3Font.caption)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 4)
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
    /// jour, sa première matière ; « avant ton contrôle » s'il en a annoncé un.
    static func message(for model: OnboardingModel, locale: UiLocale) -> String {
        let vars = [
            "name": model.displayName.nilIfBlank ?? "",
            "count": "\(model.cardsPerDay)",
            "subject": model.firstSubjectName(locale: locale) ?? "",
            "min": "\(model.minutesPerDay)",
        ]
        guard model.displayName.nilIfBlank != nil, model.firstSubjectName(locale: locale) != nil else {
            return L10n.t("ios.onb10.notif.bodyPlain", locale: locale, vars: vars)
        }
        if model.examChoice == .test {
            return L10n.t("ios.onb10.notif.bodyTest", locale: locale, vars: vars)
        }
        return L10n.t("ios.onb10.notif.body", locale: locale, vars: vars)
    }

    /// L'exemple, tel qu'iOS affiche un rappel : l'avatar de Mika, son nom, « maintenant ».
    private var notification: some View {
        HStack(alignment: .top, spacing: 12) {
            MikaAvatar(size: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "Mika")
                        .font(V3Font.label)
                        .foregroundStyle(V3Color.ink)
                    Spacer(minLength: 8)
                    Text(i18n.t("ios.notifNow"))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink3)
                }
                Text(Self.message(for: model, locale: i18n.locale))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
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
