import Foundation

// Les icônes des réponses du parcours : une par idée, dans la famille de l'app (`MicaboIcon`,
// deux tons). Elles sont toutes ici, pour qu'une réponse garde la même icône partout où elle
// paraît (la question, la carte de `solutionMap`, le plan), et qu'on les relise d'un coup.

extension LearningGoal {
    /// L'icône de l'objectif, à gauche de sa ligne de réponse.
    var icon: MicaboIcon {
        switch self {
        case .grades: .trophy
        case .dreamSchool: .diploma
        case .understand: .lightbulb
        case .faster: .hourglass
        case .ahead: .rocket
        case .passYear: .check
        case .competition: .flag
        case .profession: .folder
        case .curiosity: .brain
        case .language: .language
        case .exam: .exam
        case .lectures: .book
        case .other: .star
        }
    }
}

extension StudyWorry {
    /// L'icône du blocage, sur la question.
    var icon: MicaboIcon {
        switch self {
        case .examStress: .alarm
        case .hardLessons: .lock
        case .homework: .hourglass
        case .forgetting: .brain
        case .noStart: .pin
        case .motivation: .flame
        }
    }

    /// L'icône de la fonctionnalité qui y répond, sur `solutionMap`.
    var solutionIcon: MicaboIcon {
        switch self {
        case .examStress: .quiz
        case .hardLessons: .mika
        case .homework: .photo
        case .forgetting: .cards
        case .noStart: .exam
        case .motivation: .flame
        }
    }
}

extension ExamChoice {
    /// L'icône de ce qui arrive en premier : un examen, un contrôle, des partiels, ou rien.
    var icon: MicaboIcon {
        switch self {
        case .named: .diploma
        case .test: .quill
        case .finals: .book
        case .noExam: .check
        }
    }
}

extension OnboardingDailyTime {
    var icon: MicaboIcon {
        switch self {
        case .five: .hourglass
        case .ten: .book
        case .fifteen: .flame
        case .thirty: .rocket
        }
    }
}

extension EducationTier {
    /// L'icône d'une filière ou d'un palier, selon sa marche.
    var icon: MicaboIcon {
        switch self {
        case .lowerSecondary: .book
        case .upperSecondary: .lessons
        case .preUniversity: .calculator
        case .undergraduate: .diploma
        case .graduate: .magnifier
        case .health: .flask
        case .competitive: .flag
        case .other: .star
        }
    }
}
