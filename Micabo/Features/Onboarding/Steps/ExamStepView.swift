import SwiftUI

/// **« Quel est ton prochain gros examen ? »**
///
/// Les réponses sont les examens du pays et de l'année déclarés — le brevet en troisième, le
/// bac de français en première, l'Abitur, la Maturità, la PAU, les GCSE, le SAT, l'ENEM, le
/// YKS… —, puis un contrôle (ou ses partiels, après le bac), puis « pas d'examen en vue ».
/// La date se propose d'elle-même (la session ordinaire du pays) et se corrige d'un geste.
///
/// Mika y répond : « Bac : encore 7 mois. On a le temps de bien faire 💪 ». À la fin du
/// parcours, l'examen se pose dans le Calendrier (`OnboardingExamPlacement`).
struct ExamStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb5.q.exam"),
            reaction: reaction
        ) {
            VStack(spacing: 10) {
                ForEach(Array(model.examChoices.enumerated()), id: \.element.id) { rank, choice in
                    OnboardingChoiceRow(
                        title: choice.rowTitle(locale: i18n.locale),
                        emoji: choice.emoji,
                        isSelected: model.examChoice == choice,
                        rank: rank
                    ) {
                        withAnimation(OnboardingMotion.shift) { model.choose(exam: choice) }
                    }
                }

                if let choice = model.examChoice, choice.hasDate, model.examDate != nil {
                    dateCard
                        .padding(.top, 6)
                        .transition(.opacity.combined(with: .offset(y: -6)))
                }
            }
            .animation(OnboardingMotion.shift, value: model.examChoice)
        } footer: {
            OnboardingArrowButton(isEnabled: model.examChoice != nil) { model.advance() }
        }
    }

    /// Ce que Mika dit de l'échéance : loin, on a le temps ; proche, on va droit au but.
    static func reaction(choice: ExamChoice?, date: Date?, now: Date = Date(), locale: UiLocale) -> String? {
        guard let choice else { return nil }
        guard choice.hasDate, let date else {
            return L10n.t("ios.onb5.react.exam.none", locale: locale)
        }
        let days = SchoolExams.daysLeft(until: date, from: now)
        let vars = [
            "exam": choice.title(locale: locale),
            "time": SchoolExams.remainingText(days: days, locale: locale),
        ]
        switch days {
        case 61...: return L10n.t("ios.onb5.react.exam.far", locale: locale, vars: vars)
        case 15...: return L10n.t("ios.onb5.react.exam.mid", locale: locale, vars: vars)
        default: return L10n.t("ios.onb5.react.exam.near", locale: locale, vars: vars)
        }
    }

    private var reaction: String? {
        Self.reaction(choice: model.examChoice, date: model.examDate, locale: i18n.locale)
    }

    // MARK: La date

    private var dateBinding: Binding<Date> {
        Binding(
            get: { model.examDate ?? Date() },
            set: { model.examDate = MicaboCalendar.shared.startOfDay(for: $0) }
        )
    }

    private var dateCard: some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: .exam, size: 30)
                .frame(width: 44, height: 44)
                .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(i18n.t("ios.onb5.exam.dateLabel"))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                if still {
                    Text(Self.dateText(model.examDate ?? Date(), locale: i18n.locale))
                        .font(MicaboFont.ui(17, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                }
            }

            Spacer(minLength: 0)

            if !still {
                DatePicker(
                    i18n.t("ios.onb5.exam.dateLabel"),
                    selection: dateBinding,
                    in: Date()...,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .tint(MicaboColor.accent)
            }
        }
        .padding(12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .accessibilityElement(children: .contain)
    }

    static func dateText(_ date: Date, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return formatter.string(from: date)
    }
}
