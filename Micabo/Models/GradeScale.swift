import Foundation

/// La note qu'on vise, à la place d'une intensité abstraite.
///
/// Sous le curseur, ce sont toujours les trois paliers `light` / `standard` / `intense` :
/// deux, trois ou quatre passages. Ce qui change, c'est **ce qu'on lit** : 10/20 ou C-,
/// selon le système du pays de scolarisation.
struct DesiredGradeScale: Equatable {
    var min: String
    var mid: String
    var max: String

    static func `for`(_ country: SchoolingCountry) -> DesiredGradeScale {
        switch country {
        case .fr, .be, .ma, .dz, .tn, .sn, .ci, .pt, .gr:
            DesiredGradeScale(min: "10/20", mid: "15/20", max: "20/20")
        case .us, .other:
            DesiredGradeScale(min: "C-", mid: "B", max: "A+")
        case .uk:
            DesiredGradeScale(min: "C", mid: "B", max: "A*")
        case .se:
            DesiredGradeScale(min: "E", mid: "C", max: "A")
        case .ca, .tr:
            DesiredGradeScale(min: "60 %", mid: "80 %", max: "100 %")
        case .de:
            DesiredGradeScale(min: "4,0", mid: "2,3", max: "1,0")
        case .ch:
            DesiredGradeScale(min: "4", mid: "5", max: "6")
        case .it, .es:
            DesiredGradeScale(min: "6/10", mid: "8/10", max: "10/10")
        case .lu:
            DesiredGradeScale(min: "30/60", mid: "45/60", max: "60/60")
        case .cz:
            DesiredGradeScale(min: "4", mid: "2", max: "1")
        case .nl:
            DesiredGradeScale(min: "6", mid: "8", max: "10")
        case .hu, .pl:
            DesiredGradeScale(min: "3", mid: "4", max: "5")
        case .ro:
            DesiredGradeScale(min: "5", mid: "8", max: "10")
        }
    }

    func label(for intensity: ExamIntensity) -> String {
        switch intensity {
        case .light: min
        case .standard: mid
        case .intense: max
        }
    }
}

extension ExamIntensity {
    var gradeIndex: Double {
        switch self {
        case .light: 0
        case .standard: 1
        case .intense: 2
        }
    }

    static func from(gradeIndex: Double) -> ExamIntensity {
        switch Int(gradeIndex.rounded()) {
        case ...0: .light
        case 2...: .intense
        default: .standard
        }
    }
}
