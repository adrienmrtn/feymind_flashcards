import Foundation

/// **Ce que le paywall sait de l'élève**, relu des réponses du parcours d'accueil.
///
/// Le paywall ne parle plus en général : il dit l'examen qui arrive et dans combien de temps,
/// les matières, la moyenne visée dans le barème du pays (`StudentGradeScale`). Chaque phrase
/// vient d'une réponse ; une réponse absente retire sa phrase au lieu d'en inventer une. Le
/// paywall de l'app lit le même profil : c'est le même écran.
struct PaywallProfile: Equatable {
    var examTitle: String?
    var examDaysLeft: Int?
    var subjects: [String] = []
    var currentGrade: String?
    var targetGrade: String?
    var dailyMinutes: Int?

    static func current(locale: UiLocale = .resolved(), now: Date = Date()) -> PaywallProfile {
        var profile = PaywallProfile()
        if let choice = SchoolExams.choice(id: OnboardingPreferences.examID), choice.hasDate,
           let date = OnboardingPreferences.examDate, date >= MicaboCalendar.shared.startOfDay(for: now) {
            profile.examTitle = choice.title(locale: locale)
            profile.examDaysLeft = SchoolExams.daysLeft(until: date, from: now)
        }
        profile.subjects = OnboardingPreferences.subjects.map { SubjectDisplay.subject($0, locale: locale) }

        let country = OnboardingPreferences.schoolingCountry
        let track = SchoolSystem.track(id: OnboardingPreferences.schoolTrackID, in: country)
        let scale = StudentGradeScale.for(
            region: SchoolRegion.code(country: country, custom: OnboardingPreferences.customCountry),
            country: country,
            track: track,
            locale: locale
        ).scale
        if let target = OnboardingPreferences.targetScore, target >= TargetScore.min {
            profile.targetGrade = scale.label(for: target)
            if let current = OnboardingPreferences.currentScore {
                profile.currentGrade = current < TargetScore.min
                    ? L10n.t("ios.averageBelow", locale: locale, vars: ["grade": scale.choices.first?.label ?? ""])
                    : scale.label(for: current)
            }
        }
        profile.dailyMinutes = OnboardingPreferences.answeredDailyMinutes
        return profile
    }

    /// « Mathématiques, Physique +2 » : deux matières, et le compte du reste.
    func subjectsLine(locale: UiLocale) -> String? {
        guard !subjects.isEmpty else { return nil }
        let shown = subjects.prefix(2).joined(separator: ", ")
        guard subjects.count > 2 else { return shown }
        return "\(shown) +\(subjects.count - 2)"
    }

    /// La ligne sous le titre : l'examen qui arrive, sinon le plan du jour.
    func subtitle(locale: UiLocale) -> String? {
        if let examTitle, let examDaysLeft {
            return L10n.t("ios.pay5.sub.exam", locale: locale, vars: [
                "exam": examTitle,
                "time": SchoolExams.remainingText(days: examDaysLeft, locale: locale),
            ])
        }
        if let dailyMinutes {
            return L10n.t("ios.pay5.sub.daily", locale: locale, vars: ["n": "\(dailyMinutes)"])
        }
        return nil
    }
}
