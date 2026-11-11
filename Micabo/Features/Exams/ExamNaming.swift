import Foundation

/// **Les noms d'examen qu'un élève emploie**, pour l'exemple du champ « Nom de l'examen ».
///
/// L'exemple était une phrase fixe par langue : « Bac de français, partiel de bio… » pour
/// tout francophone — un collégien qui passe le brevet, un Belge, un Suisse qui vise la
/// Maturité. Il suit maintenant le système scolaire choisi dans le parcours (`SchoolExams`) :
/// « Bac · Contrôle » en Terminale, « Abitur · Klassenarbeit » au Gymnasium, « SAT · ACT » en
/// 11th grade, « Brevet · Contrôle » en Troisième, « Partiels » à l'université. Sans système
/// connu, la phrase de la langue revient.
enum ExamNaming {
    static func placeholder(
        country: SchoolingCountry = OnboardingPreferences.schoolingCountry,
        trackID: String? = OnboardingPreferences.schoolTrackID,
        yearID: String? = OnboardingPreferences.schoolYearID,
        tier: EducationTier? = OnboardingPreferences.educationTier,
        locale: UiLocale = .resolved()
    ) -> String {
        let track = SchoolSystem.track(id: trackID, in: country)
        let year = SchoolSystem.year(id: yearID, in: track)
        guard track != nil || tier != nil else {
            return L10n.t("lesson.exam.namePlaceholder", locale: locale)
        }
        let names = SchoolExams.choices(track: track, year: year, tier: tier)
            .filter { $0 != .noExam }
            .map { $0.title(locale: locale) }
        var unique: [String] = []
        for name in names where !unique.contains(name) {
            unique.append(name)
        }
        guard !unique.isEmpty else { return L10n.t("lesson.exam.namePlaceholder", locale: locale) }
        return unique.prefix(2).joined(separator: " · ")
    }
}
