import SwiftUI

/// **« Qu'est-ce qui arrive en premier ? »**
///
/// Les réponses sont les examens du pays et de l'année déclarés (le brevet en troisième, le
/// bac de français en première, l'Abitur, la Maturità, la PAU, les GCSE, le SAT, l'ENEM, le
/// YKS…), puis un contrôle (ou ses partiels, après le bac), puis « rien pour l'instant ».
/// La date se propose d'elle-même (la session ordinaire du pays) et se corrige d'un appui.
///
/// **Mika réagit dès la réponse** : sa bulle dit le temps qu'il reste, avec le nom de
/// l'examen. À la fin du parcours, l'examen se pose dans le Calendrier
/// (`OnboardingExamPlacement`).
struct ExamStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var showsDatePicker = false

    private var reaction: String? {
        Self.reaction(choice: model.examChoice, date: model.examDate, locale: i18n.locale)
    }

    /// Le jour de l'examen choisi, quand il en a un.
    private var examDay: Date? {
        guard let choice = model.examChoice, choice.hasDate else { return nil }
        return model.examDate
    }

    var body: some View {
        OnbQuestion(
            reaction ?? i18n.t("ios.onb10.q.exam"),
            mood: model.examChoice == nil ? .idle : .happy
        ) {
            VStack(spacing: OnbLayout.rowGap) {
                ForEach(model.examChoices, id: \.id) { choice in
                    V3OptionRow(
                        Self.rowTitle(choice, locale: i18n.locale),
                        icon: choice.icon,
                        isSelected: model.examChoice == choice
                    ) {
                        withAnimation(MicaboMotion.standard) { model.choose(exam: choice) }
                    }
                }

                if let examDay {
                    dateRow(examDay)
                        .transition(.opacity)
                }
            }
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: model.examChoice != nil) {
                model.advance()
            }
        }
        .sheet(isPresented: $showsDatePicker) {
            datePicker
        }
    }

    // MARK: Les mots

    /// Le libellé d'une réponse : le nom de l'examen dans son pays, ou une phrase de l'app.
    static func rowTitle(_ choice: ExamChoice, locale: UiLocale) -> String {
        choice == .noExam ? L10n.t("ios.onb10.exam.none", locale: locale) : choice.rowTitle(locale: locale)
    }

    /// **Ce que Mika répond** : le temps qu'il reste avant l'examen (loin, on a le temps ; à
    /// moins de trente jours, on s'y met), un mot pour un contrôle, un autre pour rien.
    static func reaction(choice: ExamChoice?, date: Date?, now: Date = Date(), locale: UiLocale) -> String? {
        guard let choice else { return nil }
        switch choice {
        case .noExam:
            return L10n.t("ios.onb10.react.exam.none", locale: locale)
        case .test:
            return L10n.t("ios.onb10.react.exam.test", locale: locale)
        case .named, .finals:
            guard let date else { return nil }
            let days = SchoolExams.daysLeft(until: date, from: now)
            let vars = [
                "exam": choice.title(locale: locale),
                "time": SchoolExams.remainingText(days: days, locale: locale),
            ]
            if days < Self.soonDays {
                return L10n.t("ios.onb10.react.exam.soon", locale: locale, vars: vars)
            }
            return L10n.t("ios.onb10.react.exam.far", locale: locale, vars: vars)
        }
    }

    /// En dessous de trente jours, l'examen est « bientôt ».
    static let soonDays = 30

    // MARK: La date

    /// « Date de l'examen · 15 juin 2027 · Modifier » : la ligne ouvre le choix du jour.
    private func dateRow(_ date: Date) -> some View {
        Button {
            showsDatePicker = true
        } label: {
            HStack(spacing: 12) {
                OnbIcon(icon: .exam, size: 26)

                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("ios.onb5.exam.dateLabel"))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                    Text(OnbWords.date(date, locale: i18n.locale))
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(i18n.t("ios.onb10.exam.edit"))
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.accentBright)
            }
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: V3Metric.optionHeight)
            .v3Card(radius: V3Metric.radiusInner)
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityElement(children: .combine)
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: { model.examDate ?? Date() },
            set: { model.examDate = MicaboCalendar.shared.startOfDay(for: $0) }
        )
    }

    /// Le choix du jour : la roue de dates du système, dans une feuille.
    private var datePicker: some View {
        VStack(spacing: 16) {
            Text(i18n.t("ios.onb5.exam.dateLabel"))
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)

            DatePicker(
                i18n.t("ios.onb5.exam.dateLabel"),
                selection: dateBinding,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()

            V3Button(i18n.t("ios.done")) {
                showsDatePicker = false
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
}
