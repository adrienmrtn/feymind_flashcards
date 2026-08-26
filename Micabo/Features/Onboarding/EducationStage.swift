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
///
/// `tier` sert à une seule chose, et le registre ne pouvait pas s'en charger : **retrouver
/// le palier équivalent quand on change de pays.** Un lycéen français et un high schooler
/// américain écrivent pareil, donc partagent le même `level` ; mais un middle schooler aussi,
/// et chercher par registre ramenait systématiquement le premier de la liste — un lycéen qui
/// passait aux États-Unis se retrouvait en « Middle school ».
struct EducationStage: Identifiable, Hashable {
    let id: String
    let title: String
    let emoji: String
    let level: StudyLevel
    let tier: EducationTier
}

/// Le palier ramené à une échelle comparable d'un pays à l'autre.
///
/// **L'ordre de déclaration des cas est l'ordre de l'échelle**, du plus bas au plus haut :
/// `ladder` s'en déduit, et un cas ajouté au milieu se place donc à sa vraie hauteur. C'est
/// cette échelle qui permet de trouver le voisin le plus proche quand le nouveau pays n'a pas
/// l'équivalent exact.
///
/// Les trois derniers cas n'en font pas partie, et c'est volontaire : la santé, les concours
/// et « autre » sont des voies, pas des marches. Un étudiant en santé ne devient pas
/// « undergraduate » parce que son pays d'accueil n'a pas de filière santé nommée.
enum EducationTier: String, CaseIterable, Hashable {
    case lowerSecondary
    case upperSecondary
    case preUniversity
    case undergraduate
    case graduate
    case health
    case competitive
    case other

    /// Vrai pour les paliers qui se comparent en hauteur d'un pays à l'autre.
    ///
    /// Le `switch` est exhaustif exprès : ajouter un palier oblige à dire s'il est une marche
    /// de l'échelle, plutôt qu'à l'oublier dans une liste écrite à la main — un palier absent
    /// de l'échelle perd silencieusement la recherche du voisin le plus proche.
    var isRung: Bool {
        switch self {
        case .lowerSecondary, .upperSecondary, .preUniversity, .undergraduate, .graduate: true
        case .health, .competitive, .other: false
        }
    }

    /// Les marches de l'échelle, de la plus basse à la plus haute.
    static let ladder: [EducationTier] = allCases.filter { $0.isRung }

    var ladderIndex: Int? {
        Self.ladder.firstIndex(of: self)
    }
}

private func stage(
    _ id: String,
    _ title: String,
    _ emoji: String,
    _ level: StudyLevel,
    _ tier: EducationTier
) -> EducationStage {
    EducationStage(id: id, title: title, emoji: emoji, level: level, tier: tier)
}

extension StudyLevel {
    /// La marche que ce registre désigne quand on n'a que lui.
    ///
    /// Plusieurs paliers peuvent partager un registre — « lycee » couvre le collège, le lycée
    /// et le cégep — et il faut alors savoir lequel il désignait. Sans cette table, le profil
    /// rendu par le cloud, qui ne transporte que le registre, retombait sur le premier palier
    /// de la liste : un « lycee » américain devenait « Middle school ».
    var canonicalTier: EducationTier {
        switch self {
        case .lycee: .upperSecondary
        case .prepa: .preUniversity
        case .licence: .undergraduate
        case .sante: .health
        case .master: .graduate
        case .concours: .competitive
        case .other: .other
        }
    }
}

/// La langue dans laquelle Micabo écrit.
///
/// Elle n'est plus demandée : un écran entier disait « Micabo parle français » pour une
/// réponse qu'on ne pouvait pas changer. Elle se déduit du pays de scolarisation, qui est la
/// seule question dont la réponse la détermine vraiment.
///
/// Les codes sont ceux d'ISO 639-1, et ils ne suivent pas toujours le code du pays :
/// la Tchéquie (`cz`) écrit en `cs`, la Grèce (`gr`) en `el`, la Suède (`se`) en `sv`. Le
/// serveur reçoit ces deux lettres et en tire sa consigne de sortie.
enum ContentLanguage: String, CaseIterable, Identifiable {
    case fr
    case en
    case de
    case it
    case es
    case pt
    case cs
    case nl
    case el
    case hu
    case pl
    case ro
    case sv
    case tr

    var id: String { rawValue }

    /// Le nom de la langue, écrit dans cette langue : c'est ainsi qu'on choisit une langue.
    var label: String {
        switch self {
        case .fr: "Français"
        case .en: "English"
        case .de: "Deutsch"
        case .it: "Italiano"
        case .es: "Español"
        case .pt: "Português"
        case .cs: "Čeština"
        case .nl: "Nederlands"
        case .el: "Ελληνικά"
        case .hu: "Magyar"
        case .pl: "Polski"
        case .ro: "Română"
        case .sv: "Svenska"
        case .tr: "Türkçe"
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
                stage("fr.lycee", "Lycée", "🎒", .lycee, .upperSecondary),
                stage("fr.prepa", "Prépa", "📐", .prepa, .preUniversity),
                stage("fr.licence", "Licence", "🎓", .licence, .undergraduate),
                stage("fr.sante", "PASS, santé", "🩺", .sante, .health),
                stage("fr.master", "Master", "🔬", .master, .graduate),
                stage("fr.concours", "Concours", "🏁", .concours, .competitive),
                stage("fr.other", "Autre", "✨", .other, .other)
            ]

        case .be:
            [
                stage("be.secondaire", "Secondaire", "🎒", .lycee, .upperSecondary),
                stage("be.bachelier", "Bachelier", "🎓", .licence, .undergraduate),
                stage("be.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("be.master", "Master", "🔬", .master, .graduate),
                stage("be.concours", "Examen d'entrée", "🏁", .concours, .competitive),
                stage("be.other", "Autre", "✨", .other, .other)
            ]

        case .ch:
            [
                stage("ch.gymnase", "Gymnase, maturité", "🎒", .lycee, .upperSecondary),
                stage("ch.bachelor", "Bachelor", "🎓", .licence, .undergraduate),
                stage("ch.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("ch.master", "Master", "🔬", .master, .graduate),
                stage("ch.other", "Autre", "✨", .other, .other)
            ]

        case .ca:
            // « Baccalauréat » désigne ici un diplôme universitaire, pas l'examen de fin de
            // secondaire : proposer les deux sens dans la même liste serait un piège.
            [
                stage("ca.secondaire", "Secondaire", "🎒", .lycee, .upperSecondary),
                stage("ca.cegep", "Cégep", "📐", .lycee, .preUniversity),
                stage("ca.bac", "Baccalauréat", "🎓", .licence, .undergraduate),
                stage("ca.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("ca.maitrise", "Maîtrise", "🔬", .master, .graduate),
                stage("ca.other", "Autre", "✨", .other, .other)
            ]

        case .lu:
            [
                stage("lu.secondaire", "Secondaire", "🎒", .lycee, .upperSecondary),
                stage("lu.bachelor", "Bachelor", "🎓", .licence, .undergraduate),
                stage("lu.master", "Master", "🔬", .master, .graduate),
                stage("lu.other", "Autre", "✨", .other, .other)
            ]

        case .ma:
            [
                stage("ma.lycee", "Lycée, bac", "🎒", .lycee, .upperSecondary),
                stage("ma.prepa", "Prépa", "📐", .prepa, .preUniversity),
                stage("ma.licence", "Licence", "🎓", .licence, .undergraduate),
                stage("ma.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("ma.master", "Master", "🔬", .master, .graduate),
                stage("ma.concours", "Concours", "🏁", .concours, .competitive),
                stage("ma.other", "Autre", "✨", .other, .other)
            ]

        case .dz:
            [
                stage("dz.lycee", "Lycée, bac", "🎒", .lycee, .upperSecondary),
                stage("dz.licence", "Licence", "🎓", .licence, .undergraduate),
                stage("dz.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("dz.master", "Master", "🔬", .master, .graduate),
                stage("dz.other", "Autre", "✨", .other, .other)
            ]

        case .tn:
            [
                stage("tn.lycee", "Lycée, bac", "🎒", .lycee, .upperSecondary),
                stage("tn.licence", "Licence", "🎓", .licence, .undergraduate),
                stage("tn.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("tn.mastere", "Mastère", "🔬", .master, .graduate),
                stage("tn.other", "Autre", "✨", .other, .other)
            ]

        case .sn:
            [
                stage("sn.lycee", "Lycée, bac", "🎒", .lycee, .upperSecondary),
                stage("sn.licence", "Licence", "🎓", .licence, .undergraduate),
                stage("sn.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("sn.master", "Master", "🔬", .master, .graduate),
                stage("sn.concours", "Grandes écoles", "🏁", .concours, .competitive),
                stage("sn.other", "Autre", "✨", .other, .other)
            ]

        case .ci:
            [
                stage("ci.lycee", "Lycée, bac", "🎒", .lycee, .upperSecondary),
                stage("ci.licence", "Licence", "🎓", .licence, .undergraduate),
                stage("ci.medecine", "Médecine, santé", "🩺", .sante, .health),
                stage("ci.master", "Master", "🔬", .master, .graduate),
                stage("ci.concours", "Grandes écoles", "🏁", .concours, .competitive),
                stage("ci.other", "Autre", "✨", .other, .other)
            ]

        // Les paliers des pays européens sont écrits **dans leur langue**, et pas traduits :
        // un lycéen polonais cherche « Liceum », pas « Lycée ». C'est la même règle que pour
        // « A-Levels » ou « Cégep », qui n'ont jamais eu de traduction non plus.
        case .de:
            [
                stage("de.mittelstufe", "Mittelstufe", "🎒", .lycee, .lowerSecondary),
                stage("de.abitur", "Gymnasium, Abitur", "🏫", .lycee, .upperSecondary),
                stage("de.bachelor", "Bachelor", "🎓", .licence, .undergraduate),
                stage("de.medizin", "Medizin", "🩺", .sante, .health),
                stage("de.master", "Master", "🔬", .master, .graduate),
                stage("de.other", "Sonstiges", "✨", .other, .other)
            ]

        case .it:
            [
                stage("it.medie", "Scuola media", "🎒", .lycee, .lowerSecondary),
                stage("it.liceo", "Liceo, maturità", "🏫", .lycee, .upperSecondary),
                stage("it.triennale", "Laurea triennale", "🎓", .licence, .undergraduate),
                stage("it.medicina", "Medicina", "🩺", .sante, .health),
                stage("it.magistrale", "Laurea magistrale", "🔬", .master, .graduate),
                stage("it.other", "Altro", "✨", .other, .other)
            ]

        case .es:
            [
                stage("es.eso", "ESO", "🎒", .lycee, .lowerSecondary),
                stage("es.bachillerato", "Bachillerato", "🏫", .lycee, .upperSecondary),
                stage("es.grado", "Grado", "🎓", .licence, .undergraduate),
                stage("es.medicina", "Medicina", "🩺", .sante, .health),
                stage("es.master", "Máster", "🔬", .master, .graduate),
                stage("es.other", "Otro", "✨", .other, .other)
            ]

        case .pt:
            [
                stage("pt.basico", "Ensino básico", "🎒", .lycee, .lowerSecondary),
                stage("pt.secundario", "Ensino secundário", "🏫", .lycee, .upperSecondary),
                stage("pt.licenciatura", "Licenciatura", "🎓", .licence, .undergraduate),
                stage("pt.medicina", "Medicina", "🩺", .sante, .health),
                stage("pt.mestrado", "Mestrado", "🔬", .master, .graduate),
                stage("pt.other", "Outro", "✨", .other, .other)
            ]

        case .cz:
            [
                stage("cz.zakladni", "Základní škola", "🎒", .lycee, .lowerSecondary),
                stage("cz.maturita", "Gymnázium, maturita", "🏫", .lycee, .upperSecondary),
                stage("cz.bakalar", "Bakalářské studium", "🎓", .licence, .undergraduate),
                stage("cz.medicina", "Medicína", "🩺", .sante, .health),
                stage("cz.magistr", "Magisterské studium", "🔬", .master, .graduate),
                stage("cz.other", "Jiné", "✨", .other, .other)
            ]

        case .nl:
            [
                stage("nl.onderbouw", "Onderbouw", "🎒", .lycee, .lowerSecondary),
                stage("nl.eindexamen", "Havo, vwo", "🏫", .lycee, .upperSecondary),
                stage("nl.bachelor", "Bachelor", "🎓", .licence, .undergraduate),
                stage("nl.geneeskunde", "Geneeskunde", "🩺", .sante, .health),
                stage("nl.master", "Master", "🔬", .master, .graduate),
                stage("nl.other", "Anders", "✨", .other, .other)
            ]

        case .gr:
            [
                stage("gr.gymnasio", "Γυμνάσιο", "🎒", .lycee, .lowerSecondary),
                stage("gr.lykeio", "Λύκειο, Πανελλήνιες", "🏫", .lycee, .upperSecondary),
                stage("gr.ptychio", "Πτυχίο", "🎓", .licence, .undergraduate),
                stage("gr.iatriki", "Ιατρική", "🩺", .sante, .health),
                stage("gr.metaptychiako", "Μεταπτυχιακό", "🔬", .master, .graduate),
                stage("gr.other", "Άλλο", "✨", .other, .other)
            ]

        case .hu:
            [
                stage("hu.altalanos", "Általános iskola", "🎒", .lycee, .lowerSecondary),
                stage("hu.erettsegi", "Gimnázium, érettségi", "🏫", .lycee, .upperSecondary),
                stage("hu.alapkepzes", "Alapképzés", "🎓", .licence, .undergraduate),
                stage("hu.orvosi", "Orvostudomány", "🩺", .sante, .health),
                stage("hu.mesterkepzes", "Mesterképzés", "🔬", .master, .graduate),
                stage("hu.other", "Egyéb", "✨", .other, .other)
            ]

        case .pl:
            [
                stage("pl.podstawowa", "Szkoła podstawowa", "🎒", .lycee, .lowerSecondary),
                stage("pl.matura", "Liceum, matura", "🏫", .lycee, .upperSecondary),
                stage("pl.licencjat", "Licencjat", "🎓", .licence, .undergraduate),
                stage("pl.medycyna", "Medycyna", "🩺", .sante, .health),
                stage("pl.magister", "Studia magisterskie", "🔬", .master, .graduate),
                stage("pl.other", "Inne", "✨", .other, .other)
            ]

        case .ro:
            [
                stage("ro.gimnaziu", "Gimnaziu", "🎒", .lycee, .lowerSecondary),
                stage("ro.bacalaureat", "Liceu, bacalaureat", "🏫", .lycee, .upperSecondary),
                stage("ro.licenta", "Licență", "🎓", .licence, .undergraduate),
                stage("ro.medicina", "Medicină", "🩺", .sante, .health),
                stage("ro.master", "Master", "🔬", .master, .graduate),
                stage("ro.other", "Altele", "✨", .other, .other)
            ]

        case .se:
            [
                stage("se.grundskola", "Grundskola", "🎒", .lycee, .lowerSecondary),
                stage("se.gymnasium", "Gymnasium", "🏫", .lycee, .upperSecondary),
                stage("se.kandidat", "Kandidatexamen", "🎓", .licence, .undergraduate),
                stage("se.lakarprogrammet", "Läkarprogrammet", "🩺", .sante, .health),
                stage("se.master", "Masterexamen", "🔬", .master, .graduate),
                stage("se.other", "Annat", "✨", .other, .other)
            ]

        case .tr:
            [
                stage("tr.ortaokul", "Ortaokul", "🎒", .lycee, .lowerSecondary),
                stage("tr.lise", "Lise, YKS", "🏫", .lycee, .upperSecondary),
                stage("tr.lisans", "Lisans", "🎓", .licence, .undergraduate),
                stage("tr.tip", "Tıp", "🩺", .sante, .health),
                stage("tr.yukseklisans", "Yüksek lisans", "🔬", .master, .graduate),
                stage("tr.other", "Diğer", "✨", .other, .other)
            ]

        case .uk:
            [
                stage("uk.gcse", "GCSE", "🎒", .lycee, .lowerSecondary),
                stage("uk.alevels", "A-Levels", "📐", .lycee, .upperSecondary),
                stage("uk.undergraduate", "Undergraduate", "🎓", .licence, .undergraduate),
                stage("uk.medicine", "Medicine", "🩺", .sante, .health),
                stage("uk.postgraduate", "Postgraduate", "🔬", .master, .graduate),
                stage("uk.other", "Other", "✨", .other, .other)
            ]

        case .us:
            [
                stage("us.middle", "Middle school", "🎒", .lycee, .lowerSecondary),
                stage("us.high", "High school", "🏫", .lycee, .upperSecondary),
                stage("us.college", "College", "🎓", .licence, .undergraduate),
                stage("us.premed", "Pre-med, MCAT", "🩺", .sante, .health),
                stage("us.graduate", "Graduate school", "🔬", .master, .graduate),
                stage("us.other", "Other", "✨", .other, .other)
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
        stage("generic.middle", "Middle school", "🎒", .lycee, .lowerSecondary),
        stage("generic.high", "High school", "🏫", .lycee, .upperSecondary),
        stage("generic.college", "College", "🎓", .licence, .undergraduate),
        stage("generic.university", "University", "🔬", .master, .graduate),
        stage("generic.other", "Other", "✨", .other, .other)
    ]

    /// La langue dans laquelle Micabo écrit pour cet étudiant.
    ///
    /// Un pays hors liste retombe sur l'anglais : c'est la langue dans laquelle on a le plus
    /// de chances de tomber juste quand on ne sait rien du système scolaire, et la seule
    /// alternative honnête serait de reposer la question.
    var language: ContentLanguage {
        switch self {
        case .fr, .be, .ch, .ca, .lu, .ma, .dz, .tn, .sn, .ci: .fr
        case .uk, .us, .other: .en
        case .de: .de
        case .it: .it
        case .es: .es
        case .pt: .pt
        case .cz: .cs
        case .nl: .nl
        case .gr: .el
        case .hu: .hu
        case .pl: .pl
        case .ro: .ro
        case .se: .sv
        case .tr: .tr
        }
    }

    /// Le palier de ce pays qui correspond à une réponse déjà donnée.
    ///
    /// C'est ce qui permet de changer de pays sans redemander où l'on en est, et l'ordre des
    /// tentatives est celui du plus précis au plus grossier :
    ///
    /// 1. **l'identifiant**, quand la réponse vient du même pays ;
    /// 2. **le palier exact** : un lycéen français devient high schooler américain, un
    ///    étudiant en santé retrouve la filière santé locale ;
    /// 3. **la marche la plus proche sur l'échelle**, en montant à égalité de distance : un
    ///    élève de prépa n'a pas d'équivalent britannique, et « Undergraduate » le sert mieux
    ///    qu'une question reposée ;
    /// 4. **le registre de rédaction**, seule chose que le cloud transporte.
    ///
    /// Rien ne correspond, on rend `nil` et l'écran redemande : la santé, les concours et
    /// « autre » ne sont pas des marches d'échelle, et transformer un étudiant en santé en
    /// « undergraduate » parce que son pays n'a pas de filière nommée serait une réponse
    /// fausse écrite à sa place.
    func resolvedStage(id: String?, tier: EducationTier?, level: StudyLevel?) -> EducationStage? {
        if let id, let match = stages.first(where: { $0.id == id }) { return match }

        if let tier {
            if let exact = stages.first(where: { $0.tier == tier }) { return exact }
            if let neighbour = nearestOnLadder(to: tier) { return neighbour }
        }

        guard let level else { return nil }
        return matchingStage(for: level)
    }

    /// Le palier de ce pays qui écrit dans ce registre, à la marche que le registre désigne.
    ///
    /// C'est le dernier recours, et il ne sert qu'à une donnée sans marche : le profil que le
    /// cloud renvoie ne transporte que le registre. Prendre le premier de la liste ramenait un
    /// « lycee » américain sur « Middle school », c'est-à-dire exactement l'erreur que la
    /// marche existe pour éviter ; prendre le plus haut ramenait un « lycee » québécois sur
    /// « Cégep », qui est post-secondaire. Chaque registre a une marche de référence
    /// (`StudyLevel.canonicalTier`), et c'est celle-là qu'on cherche.
    private func matchingStage(for level: StudyLevel) -> EducationStage? {
        let matching = stages.filter { $0.level == level }
        return matching.first { $0.tier == level.canonicalTier } ?? matching.first
    }

    /// La marche la plus proche de celle demandée. À distance égale, on monte : un palier
    /// au-dessus se rattrape en lisant, un palier en dessous se paye en fiches trop simples.
    private func nearestOnLadder(to tier: EducationTier) -> EducationStage? {
        guard let target = tier.ladderIndex else { return nil }

        return stages
            .compactMap { candidate -> (stage: EducationStage, distance: Int, index: Int)? in
                guard let index = candidate.tier.ladderIndex else { return nil }
                return (candidate, abs(index - target), index)
            }
            .min { left, right in
                left.distance == right.distance
                    ? left.index > right.index
                    : left.distance < right.distance
            }?
            .stage
    }
}
