import Foundation

/// **Un palier d'études, tel qu'il se nomme là où l'étudiant étudie.**
///
/// « Prépa », « PASS » et « les attendus du bac » ne veulent rien dire hors de France, et un
/// Américain à qui on propose « Licence » se reconnaît dans aucune réponse. La question
/// « tu en es où ? » est donc posée **après** le pays, et ses réponses sont celles du système
/// scolaire choisi.
///
/// L'identifiant est stable et préfixé par le pays (`fr.prepa`, `us.college`) : c'est lui
/// qu'on relit pour retrouver la réponse dans les réglages.
///
/// `level` est le **registre de rédaction** envoyé à l'Edge Function, et il est
/// volontairement plus grossier que le palier : un cégep québécois et un lycée français ne
/// portent pas le même nom mais demandent la même écriture. C'est ce qui permet d'ajouter un
/// pays sans toucher aux consignes du modèle.
struct EducationStage: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let level: StudyLevel
}

private func stage(_ id: String, _ title: String, _ emoji: String, _ level: StudyLevel) -> EducationStage {
    EducationStage(id: id, title: title, emoji: emoji, level: level)
}

/// La langue dans laquelle Micabo écrit.
///
/// Elle n'est plus demandée : un écran entier disait « Micabo parle français » pour une
/// réponse qu'on ne pouvait pas changer. Elle se déduit du pays de scolarisation, qui est la
/// seule question dont la réponse la détermine vraiment.
enum ContentLanguage: String, CaseIterable, Identifiable {
    case fr
    case en

    var id: String { rawValue }

    /// Le nom de la langue, écrit dans cette langue : c'est ainsi qu'on choisit une langue.
    var label: String {
        switch self {
        case .fr: "Français"
        case .en: "English"
        }
    }
}

extension SchoolingCountry {
    /// Les paliers proposés par la question « tu en es où ? ».
    ///
    /// Chaque liste se termine par une sortie : un système scolaire ne se résume jamais à
    /// cinq lignes, et un écran de question sans réponse possible se quitte en quittant
    /// l'app.
    var stages: [EducationStage] {
        switch self {
        case .fr:
            [
                stage("fr.lycee", "Lycée", "🎒", .lycee),
                stage("fr.prepa", "Prépa", "📐", .prepa),
                stage("fr.licence", "Licence", "🎓", .licence),
                stage("fr.sante", "PASS, santé", "🩺", .sante),
                stage("fr.master", "Master", "🔬", .master),
                stage("fr.concours", "Concours", "🏁", .concours),
                stage("fr.other", "Autre", "✨", .other)
            ]

        case .be:
            [
                stage("be.secondaire", "Secondaire", "🎒", .lycee),
                stage("be.bachelier", "Bachelier", "🎓", .licence),
                stage("be.medecine", "Médecine, santé", "🩺", .sante),
                stage("be.master", "Master", "🔬", .master),
                stage("be.concours", "Examen d'entrée", "🏁", .concours),
                stage("be.other", "Autre", "✨", .other)
            ]

        case .ch:
            [
                stage("ch.gymnase", "Gymnase, maturité", "🎒", .lycee),
                stage("ch.bachelor", "Bachelor", "🎓", .licence),
                stage("ch.medecine", "Médecine, santé", "🩺", .sante),
                stage("ch.master", "Master", "🔬", .master),
                stage("ch.other", "Autre", "✨", .other)
            ]

        case .ca:
            // « Baccalauréat » désigne ici un diplôme universitaire, pas l'examen de fin de
            // secondaire : proposer les deux sens dans la même liste serait un piège.
            [
                stage("ca.secondaire", "Secondaire", "🎒", .lycee),
                stage("ca.cegep", "Cégep", "📐", .lycee),
                stage("ca.bac", "Baccalauréat", "🎓", .licence),
                stage("ca.medecine", "Médecine, santé", "🩺", .sante),
                stage("ca.maitrise", "Maîtrise", "🔬", .master),
                stage("ca.other", "Autre", "✨", .other)
            ]

        case .lu:
            [
                stage("lu.secondaire", "Secondaire", "🎒", .lycee),
                stage("lu.bachelor", "Bachelor", "🎓", .licence),
                stage("lu.master", "Master", "🔬", .master),
                stage("lu.other", "Autre", "✨", .other)
            ]

        case .ma:
            [
                stage("ma.lycee", "Lycée, bac", "🎒", .lycee),
                stage("ma.prepa", "Prépa", "📐", .prepa),
                stage("ma.licence", "Licence", "🎓", .licence),
                stage("ma.medecine", "Médecine, santé", "🩺", .sante),
                stage("ma.master", "Master", "🔬", .master),
                stage("ma.concours", "Concours", "🏁", .concours),
                stage("ma.other", "Autre", "✨", .other)
            ]

        case .dz:
            [
                stage("dz.lycee", "Lycée, bac", "🎒", .lycee),
                stage("dz.licence", "Licence", "🎓", .licence),
                stage("dz.medecine", "Médecine, santé", "🩺", .sante),
                stage("dz.master", "Master", "🔬", .master),
                stage("dz.other", "Autre", "✨", .other)
            ]

        case .tn:
            [
                stage("tn.lycee", "Lycée, bac", "🎒", .lycee),
                stage("tn.licence", "Licence", "🎓", .licence),
                stage("tn.medecine", "Médecine, santé", "🩺", .sante),
                stage("tn.mastere", "Mastère", "🔬", .master),
                stage("tn.other", "Autre", "✨", .other)
            ]

        case .sn:
            [
                stage("sn.lycee", "Lycée, bac", "🎒", .lycee),
                stage("sn.licence", "Licence", "🎓", .licence),
                stage("sn.medecine", "Médecine, santé", "🩺", .sante),
                stage("sn.master", "Master", "🔬", .master),
                stage("sn.concours", "Grandes écoles", "🏁", .concours),
                stage("sn.other", "Autre", "✨", .other)
            ]

        case .ci:
            [
                stage("ci.lycee", "Lycée, bac", "🎒", .lycee),
                stage("ci.licence", "Licence", "🎓", .licence),
                stage("ci.medecine", "Médecine, santé", "🩺", .sante),
                stage("ci.master", "Master", "🔬", .master),
                stage("ci.concours", "Grandes écoles", "🏁", .concours),
                stage("ci.other", "Autre", "✨", .other)
            ]

        case .uk:
            [
                stage("uk.gcse", "GCSE", "🎒", .lycee),
                stage("uk.alevels", "A-Levels", "📐", .lycee),
                stage("uk.undergraduate", "Undergraduate", "🎓", .licence),
                stage("uk.medicine", "Medicine", "🩺", .sante),
                stage("uk.postgraduate", "Postgraduate", "🔬", .master),
                stage("uk.other", "Other", "✨", .other)
            ]

        case .us:
            [
                stage("us.middle", "Middle school", "🎒", .lycee),
                stage("us.high", "High school", "🏫", .lycee),
                stage("us.college", "College", "🎓", .licence),
                stage("us.premed", "Pre-med, MCAT", "🩺", .sante),
                stage("us.graduate", "Graduate school", "🔬", .master),
                stage("us.other", "Other", "✨", .other)
            ]

        case .other:
            Self.genericStages
        }
    }

    /// L'échelle générique, en anglais, pour un pays dont on ne connaît pas le système.
    ///
    /// Elle est délibérément courte et dans l'ordre du parcours scolaire : inventer des
    /// paliers pour un pays qu'on ne connaît pas produirait des réponses fausses, et une
    /// réponse fausse est pire qu'une réponse large.
    static let genericStages: [EducationStage] = [
        stage("generic.middle", "Middle school", "🎒", .lycee),
        stage("generic.high", "High school", "🏫", .lycee),
        stage("generic.college", "College", "🎓", .licence),
        stage("generic.university", "University", "🔬", .master),
        stage("generic.other", "Other", "✨", .other)
    ]

    /// La langue dans laquelle Micabo écrit pour cet étudiant.
    var language: ContentLanguage {
        switch self {
        case .fr, .be, .ch, .ca, .lu, .ma, .dz, .tn, .sn, .ci: .fr
        case .uk, .us, .other: .en
        }
    }

    /// Le palier correspondant à un identifiant, puis à défaut au registre enregistré.
    ///
    /// Le repli par registre est ce qui permet de changer de pays sans perdre sa réponse :
    /// un étudiant en licence en France reste en « Undergraduate » s'il passe au
    /// Royaume-Uni, parce que les deux paliers écrivent pareil.
    func resolvedStage(id: String?, orLevel level: StudyLevel?) -> EducationStage? {
        if let id, let match = stages.first(where: { $0.id == id }) { return match }
        guard let level else { return nil }
        return stages.first { $0.level == level }
    }
}
