import Foundation

/// Qui peut retrouver ce cours dans la bibliothèque.
///
/// La visibilité est portée par **le cours**, et pas par le compte, et c'est le fond de
/// l'affaire : le même étudiant partage volontiers son chapitre de SVT et garde ses notes de
/// psychanalyse pour lui. Un réglage global l'aurait forcé à choisir entre tout ouvrir et tout
/// fermer, c'est-à-dire à tout fermer.
///
/// On ne propose plus `public` : uniquement les amis, ou soi seul. `public` reste une valeur
/// lue pour les cours déjà déposés. Le défaut est `private`.
enum CourseVisibility: String, Codable, CaseIterable, Identifiable {
    /// Les camarades du même établissement, et les amis. Plus proposé à l'import.
    case `public`
    /// Les amis seulement, quel que soit leur établissement.
    case friends
    /// Personne d'autre.
    case `private`

    var id: String { rawValue }

    /// Ce que l'app suppose quand rien n'a été choisi.
    static let standard = CourseVisibility.private

    /// Les visibilités encore proposées : plus de dépôt public.
    static let choosable: [CourseVisibility] = [.friends, .private]

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

    /// Recolle une ancienne valeur `public` sur un choix encore proposé.
    var asChoice: CourseVisibility {
        Self.choosable.contains(self) ? self : .private
    }
}
