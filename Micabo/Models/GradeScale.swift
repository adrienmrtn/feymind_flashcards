import Foundation

/// La note qu'on vise, sur une droite 10–20.
///
/// Le curseur est fluide : chaque cran compte. L'intensité (deux, trois ou
/// quatre passages) se déduit ensuite : 10–13 léger, 14–17 standard, au-delà
/// intensif. Les autres systèmes se ramènent à la même droite : onze crans
/// partout, c'est le libellé qui change.
enum TargetScore {
    static let min = 10
    static let max = 20
    static let `default` = 15

    static func clamp(_ score: Int) -> Int {
        Swift.min(max, Swift.max(min, score))
    }

    static func intensity(from score: Int) -> ExamIntensity {
        switch clamp(score) {
        case ...13: .light
        case ...17: .standard
        default: .intense
        }
    }

    /// Quand on n'a que l'ancien palier, on reprend le milieu de sa bande.
    static func score(from intensity: ExamIntensity) -> Int {
        switch intensity {
        case .light: 12
        case .standard: 15
        case .intense: 19
        }
    }
}

struct GradeTick: Equatable {
    var score: Int
    var label: String
}

/// La note qu'on vise, à la place d'une intensité abstraite.
struct DesiredGradeScale: Equatable {
    var ticks: [GradeTick]

    var min: String { ticks.first?.label ?? "" }
    var mid: String { ticks.count > 5 ? ticks[5].label : ticks.last?.label ?? "" }
    var max: String { ticks.last?.label ?? "" }

    static func `for`(_ country: SchoolingCountry) -> DesiredGradeScale {
        DesiredGradeScale(
            ticks: labels(for: country).enumerated().map { index, label in
                GradeTick(score: TargetScore.min + index, label: label)
            }
        )
    }

    func label(for score: Int) -> String {
        let clamped = TargetScore.clamp(score)
        return ticks[clamped - TargetScore.min].label
    }

    func label(for intensity: ExamIntensity) -> String {
        label(for: TargetScore.score(from: intensity))
    }

    private static func labels(for country: SchoolingCountry) -> [String] {
        switch country {
        case .fr, .be, .ma, .dz, .tn, .sn, .ci, .pt, .gr:
            (10...20).map { "\($0)/20" }
        case .us, .other:
            ["C-", "C-", "C", "C+", "B-", "B", "B+", "A-", "A", "A", "A+"]
        case .uk:
            ["C", "C", "C", "B", "B", "B", "A", "A", "A", "A*", "A*"]
        case .se:
            ["E", "E", "D", "D", "C", "C", "B", "B", "A", "A", "A"]
        case .ca, .tr:
            (10...20).map { "\(60 + ($0 - 10) * 4) %" }
        case .de:
            ["4,0", "3,7", "3,3", "3,0", "2,7", "2,3", "2,0", "1,7", "1,3", "1,0", "1,0"]
        case .ch:
            ["4", "4", "4,5", "4,5", "5", "5", "5,5", "5,5", "6", "6", "6"]
        case .it, .es:
            ["6/10", "6/10", "7/10", "7/10", "8/10", "8/10", "9/10", "9/10", "10/10", "10/10", "10/10"]
        case .lu:
            (10...20).map { "\(30 + ($0 - 10) * 3)/60" }
        case .cz:
            ["4", "4", "3", "3", "3", "2", "2", "2", "1", "1", "1"]
        case .nl:
            ["6", "6", "7", "7", "8", "8", "9", "9", "10", "10", "10"]
        case .hu, .pl:
            ["3", "3", "3", "3", "4", "4", "4", "4", "5", "5", "5"]
        case .ro:
            ["5", "5", "6", "6", "7", "8", "8", "9", "9", "10", "10"]
        }
    }
}

extension ExamIntensity {
    var gradeIndex: Double {
        Double(TargetScore.score(from: self))
    }

    static func from(targetScore: Int) -> ExamIntensity {
        TargetScore.intensity(from: targetScore)
    }

    static func from(gradeIndex: Double) -> ExamIntensity {
        TargetScore.intensity(from: Int(gradeIndex.rounded()))
    }
}
