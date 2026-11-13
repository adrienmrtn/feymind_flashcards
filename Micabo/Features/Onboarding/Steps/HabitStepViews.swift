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
        OnbQuestion(
            i18n.t("ios.onb12.q.time"),
            say: OnbSay(i18n.t("ios.onb12.say.time"), mood: .idle)
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(OnboardingDailyTime.allCases) { time in
                    OnbOption(
                        title: time.title(locale: i18n.locale),
                        subtitle: time == Self.advised ? i18n.t("ios.onb10.time.advised") : nil,
                        icon: time.icon,
                        isSelected: model.dailyMinutes == time.rawValue
                    ) {
                        OnbPick.choose(on: .dailyTime, model: model) { model.dailyMinutes = time.rawValue }
                    }
                }
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

// MARK: - L'engagement

/// **« On s'engage ensemble ? »** (lot 12) Le geste d'engagement du parcours.
///
/// Deux promesses, écrites avec ses réponses : la sienne (« Moi, Lina, je révise 15 min par
/// jour jusqu'au Bac ») et celle de Mika (« je prépare chaque séance et je te fais signe à
/// 18 h »). On **maintient le doigt** sur le sceau : l'anneau se remplit sous le doigt ; lâché
/// trop tôt, il redescend. Tenu jusqu'au bout : c'est signé — Mika fête, des confettis, une
/// vibration de réussite. Le bouton du pied ne s'allume qu'après.
///
/// Rien n'attend : l'anneau suit le doigt, et la fête répond à l'appui tenu.
struct CommitmentStepView: View {
    /// Pour les rendus : l'engagement déjà pris.
    var previewCommitted = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onbCompact) private var compact

    /// L'anneau sous le doigt, de 0 à 1.
    @State private var fill: Double = 0
    /// Vrai le temps que l'engagement vienne d'être pris sur cet écran : la fête.
    @State private var celebrates = false

    /// La durée de l'appui long.
    static let holdSeconds = 1.2

    private var isCommitted: Bool { model.hasCommitted || previewCommitted }

    private var name: String? { model.displayName.nilIfBlank }

    private var title: String {
        if isCommitted {
            guard let name else { return i18n.t("ios.onb12.commit.doneNoName") }
            return i18n.t("ios.onb12.commit.done", ["name": name])
        }
        return i18n.t("ios.onb12.commit.title")
    }

    /// La promesse de l'élève, écrite avec ses réponses.
    static func studentPromise(for model: OnboardingModel, locale: UiLocale) -> String {
        let minutes = "\(model.minutesPerDay)"
        let name = model.displayName.nilIfBlank
        if let exam = model.datedExam {
            let date = OnbWords.day(exam.date, locale: locale)
            if let name {
                return L10n.t("ios.onb12.commit.me", locale: locale, vars: ["name": name, "min": minutes, "date": date])
            }
            return L10n.t("ios.onb12.commit.meNoName", locale: locale, vars: ["min": minutes, "date": date])
        }
        if let name {
            return L10n.t("ios.onb12.commit.meAny", locale: locale, vars: ["name": name, "min": minutes])
        }
        return L10n.t("ios.onb12.commit.meAnyNoName", locale: locale, vars: ["min": minutes])
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbMikaRow(say: isCommitted
                ? OnbSay(i18n.t("ios.onb12.commit.proud"), mood: .celebrate)
                : OnbSay(i18n.t("ios.onb12.commit.say"), mood: .wink))
                .padding(.top, OnbLayout.mikaGap)

            contract
                .padding(.top, OnbLayout.answersGap)

            seal
                .padding(.top, compact ? 14 : 24)
                .frame(maxWidth: .infinity)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: isCommitted) {
                model.advance()
            }
        }
        .overlay {
            OnbConfetti(isOn: celebrates)
        }
    }

    /// Les deux promesses, côte à côte dans une carte : la sienne, puis celle de Mika.
    private var contract: some View {
        VStack(alignment: .leading, spacing: 14) {
            promise(icon: .profile, tone: V3Color.iconBlue, text: Self.studentPromise(for: model, locale: i18n.locale))
            Rectangle()
                .fill(V3Color.line)
                .frame(height: 1.5)
            promise(icon: .mika, tone: V3Color.iconLilac, text: i18n.t("ios.onb12.commit.mika", [
                "hour": OnbWords.hour(model.reminderHour, locale: i18n.locale),
            ]))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(selected: isCommitted)
    }

    private func promise(icon: MicaboIcon, tone: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MicaboIconView(icon: icon, size: 24 * 1.35, tint: tone)
                .frame(width: 30, height: 30)
            Text(text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    /// **Le sceau** : un grand rond à tenir. L'anneau se remplit sous le doigt ; signé, il
    /// passe au vert avec une coche.
    private var seal: some View {
        let size: CGFloat = compact ? 104 : 128
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isCommitted ? V3Color.greenWash : V3Color.accentWash)
                Circle()
                    .stroke(V3Color.line, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: isCommitted ? 1 : fill)
                    .stroke(isCommitted ? V3Color.green : V3Color.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: isCommitted ? "checkmark" : "hand.point.up.left.fill")
                    .font(.system(size: size * 0.32, weight: .black))
                    .foregroundStyle(isCommitted ? V3Color.green : V3Color.accentBright)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
            .scaleEffect(fill > 0 && !isCommitted ? 0.96 : 1)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: Self.holdSeconds) {
                commit()
            } onPressingChanged: { pressing in
                guard !isCommitted else { return }
                if pressing {
                    Haptics.light()
                    withAnimation(MicaboMotion.hold(seconds: Self.holdSeconds)) { fill = 1 }
                } else {
                    withAnimation(MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: reduceMotion)) { fill = 0 }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(i18n.t("ios.onb12.commit.hold")))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { commit() }

            Text(i18n.t(isCommitted ? "ios.onb12.commit.signed" : "ios.onb12.commit.hold"))
                .font(V3Font.label)
                .foregroundStyle(isCommitted ? V3Color.green : V3Color.ink2)
                .multilineTextAlignment(.center)
        }
    }

    private func commit() {
        guard !isCommitted else { return }
        Haptics.success()
        withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion)) {
            model.hasCommitted = true
            fill = 1
        }
        celebrates = true
    }
}
