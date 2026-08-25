import Foundation

/// Qui peut retrouver ce cours dans la bibliothèque.
///
/// La visibilité est portée par **le cours**, et pas par le compte, et c'est le fond de
/// l'affaire : le même étudiant partage volontiers son chapitre de SVT et garde ses notes de
/// psychanalyse pour lui. Un réglage global l'aurait forcé à choisir entre tout ouvrir et tout
/// fermer, c'est-à-dire à tout fermer.
///
/// Le défaut est `public`, et c'est un choix assumé : une bibliothèque où personne ne dépose
/// rien n'intéresse personne, et c'est ce que l'app annonce à l'inscription. Les deux autres
/// valeurs existent pour que ce défaut soit acceptable — on ne demande pas à quelqu'un
/// d'ouvrir ses cours sans lui donner le moyen d'en refermer un.
enum CourseVisibility: String, Codable, CaseIterable, Identifiable {
    /// Les camarades du même établissement, et les amis.
    case `public`
    /// Les amis seulement, quel que soit leur établissement.
    case friends
    /// Personne d'autre.
    case `private`

    var id: String { rawValue }

    /// Ce que l'app suppose quand rien n'a été choisi, et ce que la base met par défaut.
    static let standard = CourseVisibility.public

    /// Le choix retenu à l'import, gardé d'un document à l'autre.
    ///
    /// Il vit dans les réglages de l'app et non dans le cours, parce que c'est une habitude
    /// plutôt qu'une propriété : quelqu'un qui travaille en privé n'a pas à le redire à chaque
    /// import. Le cours, lui, garde la visibilité qu'il avait au moment où il a été créé.
    static let importKey = "micabo.course.visibility.default"

    var title: String {
        switch self {
        case .public: "Public"
        case .friends: "Mes amis"
        case .private: "Privé"
        }
    }

    /// Qui voit le cours, dit du point de vue de l'étudiant. Un réglage de partage dont on ne
    /// comprend pas la portée ne se touche pas, et reste donc au défaut.
    var detail: String {
        switch self {
        case .public: "Visible par ton école et tes amis dans la bibliothèque."
        case .friends: "Visible par tes amis seulement."
        case .private: "Visible par toi seul."
        }
    }

    var systemImage: String {
        switch self {
        case .public: "building.columns"
        case .friends: "person.2"
        case .private: "lock"
        }
    }

    /// Vrai quand le cours sort de l'appareil pour être trouvable par quelqu'un d'autre.
    var isShared: Bool {
        self != .private
    }
}
