import Foundation

/// **Les trois chiffres de Home** (`docs/refonte-parcours.md` § 3) : le temps passé à
/// réviser, les leçons apprises, les flashcards apprises. Tout est mesuré, rien n'est estimé.
struct HomeStats: Equatable {
    /// Le temps passé dans Notes, Quiz et Flashcards, toutes leçons confondues.
    var seconds: Double = 0
    /// Les leçons arrivées à « Leçon terminée ».
    var learnedLessons = 0
    /// Les cartes dont le prochain rappel est à plus de sept jours.
    var learnedCards = 0

    init(seconds: Double = 0, learnedLessons: Int = 0, learnedCards: Int = 0) {
        self.seconds = seconds
        self.learnedLessons = learnedLessons
        self.learnedCards = learnedCards
    }

    init(courses: [Course], now: Date = Date()) {
        for course in courses {
            let progress = course.progress
            seconds += progress.totalSeconds
            if progress.finishedAt != nil { learnedLessons += 1 }
            learnedCards += course.learnedCardCount(now: now)
        }
    }

    /// « 12 min » sous l'heure, « 1,5 h » sous dix heures, « 14 h » au-delà.
    func formattedTime(locale: UiLocale = .resolved()) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 {
            return L10n.t("lesson.home.minutes", locale: locale, vars: ["n": String(minutes)])
        }
        let hours = seconds / 3600
        let value: String
        if hours < 10 {
            let formatter = NumberFormatter()
            formatter.locale = Locale(identifier: locale.rawValue)
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 1
            value = formatter.string(from: NSNumber(value: (hours * 10).rounded() / 10)) ?? String(format: "%.1f", hours)
        } else {
            value = String(Int(hours.rounded()))
        }
        return L10n.t("lesson.home.hours", locale: locale, vars: ["n": value])
    }
}

/// **« Reprendre »** : la dernière leçon ouverte, et le cercle où elle attend.
struct ResumeTarget: Equatable {
    var courseID: UUID
    var title: String
    var circleNumber: Int?
    var circleTitle: String?
    var percent: Int

    /// La leçon ouverte le plus récemment, terminée ou non : c'est celle qu'on veut retrouver.
    /// Un cours jamais ouvert dans la refonte ne compte pas.
    static func pick(from courses: [Course]) -> (Course, ResumeTarget)? {
        guard let course = courses
            .filter({ $0.lastOpenedAt != nil })
            .max(by: { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) })
        else { return nil }
        let circles = course.pathSteps().compactMap(\.circle)
        let done = course.progress.done
        let current = PathLayout.current(in: circles, done: done)
        let doneCount = circles.filter { done.contains($0.id) }.count
        let percent = circles.isEmpty ? 0 : Int((Double(doneCount) / Double(circles.count) * 100).rounded())
        return (course, ResumeTarget(
            courseID: course.id,
            title: course.title,
            circleNumber: current?.number,
            circleTitle: current?.title,
            percent: percent
        ))
    }
}
