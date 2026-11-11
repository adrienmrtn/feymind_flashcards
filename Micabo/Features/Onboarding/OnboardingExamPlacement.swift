import Foundation
import SwiftData

/// **Le prochain examen du parcours devient un examen du Calendrier**, à la fin du parcours.
///
/// C'est le même examen que celui qu'on ajoute à la main (`ExamRepository.create`) : un nom,
/// un jour, la moyenne visée, aucune leçon encore. Le Calendrier et Home le montrent aussitôt,
/// et les leçons s'y rattachent plus tard. Il n'est posé qu'une fois par installation, jamais
/// pour « pas d'examen en vue », jamais pour une date passée, et pas s'il existe déjà un examen
/// du même nom le même jour (un examen rendu par la synchro après une réinstallation).
enum OnboardingExamPlacement {
    @discardableResult
    static func placeIfNeeded(
        in context: ModelContext,
        now: Date = Date(),
        locale: UiLocale = .resolved(),
        calendar: Calendar = MicaboCalendar.shared
    ) -> Exam? {
        guard !OnboardingPreferences.examPlaced,
              let choice = SchoolExams.choice(id: OnboardingPreferences.examID),
              choice.hasDate,
              let date = OnboardingPreferences.examDate,
              calendar.startOfDay(for: date) >= calendar.startOfDay(for: now)
        else { return nil }
        let name = choice.title(locale: locale)
        let day = calendar.startOfDay(for: date)
        OnboardingPreferences.examPlaced = true
        if let existing = ExamRepository.all(in: context).first(where: {
            $0.name == name && calendar.isDate($0.date, inSameDayAs: day)
        }) {
            return existing
        }
        let target = OnboardingPreferences.targetScore.map { max(TargetScore.min, $0) }
        let exam = try? ExamRepository.create(
            name: name,
            date: day,
            courseIDs: [],
            intensity: .standard,
            targetScore: target,
            in: context,
            calendar: calendar
        )
        if exam != nil {
            Analytics.track(.onboardingAnswer, ["field": "examPlaced", "value": .text(choice.id)])
        }
        return exam
    }
}
