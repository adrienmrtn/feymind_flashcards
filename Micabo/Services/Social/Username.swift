import Foundation

/// Le nom d'utilisateur : ce qui permet de se retrouver sans échanger d'adresse.
///
/// On ne s'ajoute pas en ami avec un UUID, et une adresse électronique n'a pas à circuler dans
/// un annuaire d'école. Le nom d'utilisateur est donc un **identifiant** et pas un pseudonyme
/// d'affichage : minuscules, sans accent, sans espace, pour qu'il se dicte au téléphone sans
/// ambiguïté et qu'il ne puisse pas en imiter un autre.
///
/// Les règles sont écrites deux fois, ici et dans une contrainte de la base
/// (`profiles_username_shape`), et c'est volontaire : celle de la base est la seule qui
/// s'applique vraiment, celle-ci existe pour que l'écran refuse tout de suite au lieu
/// d'attendre un aller-retour pour dire non.
enum Username {
    static let minimumLength = 3
    static let maximumLength = 20

    enum Problem: LocalizedError, Equatable {
        case tooShort
        case tooLong
        case empty

        var errorDescription: String? {
            switch self {
            case .empty: "Choisis un nom d'utilisateur."
            case .tooShort: "Trois caractères au minimum."
            case .tooLong: "Vingt caractères au maximum."
            }
        }
    }

    /// Ramène ce qui a été tapé à la forme que la base accepte, **sans jamais refuser** ce qui
    /// peut être sauvé.
    ///
    /// « Adrien Martinot » devient « adrien-martinot », « Zoé_92 » devient « zoe_92 ». Refuser
    /// une majuscule ou un accent aurait été plus simple à écrire et pénible à utiliser : on
    /// tape son nom comme on l'écrit, et c'est à l'app de le mettre en forme.
    static func normalize(_ raw: String) -> String {
        // `Latin-ASCII` fait ce que le pliage des diacritiques seul ne fait pas : il rend un
        // équivalent ASCII là où il n'y a pas d'accent à retirer. Le « ı » turc de « Çağrı » n'a
        // pas d'accent, donc le pliage le laissait tel quel, et le filtre ASCII plus bas le
        // jetait : « Çağrı » devenait « cagr ». Il devient « cagri ».
        let latin = raw.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? raw
        let folded = latin
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "fr_FR"))
            .lowercased()

        var result = ""
        var pendingSeparator = false

        for character in folded {
            if character.isASCII, character.isLetter || character.isNumber || character == "_" {
                // Un séparateur en attente ne s'écrit que s'il a quelque chose à séparer :
                // c'est ce qui retire les tirets de fin sans un second passage.
                if pendingSeparator, !result.isEmpty { result.append("-") }
                pendingSeparator = false
                result.append(character)
            } else {
                pendingSeparator = true
            }
        }

        // Le premier caractère est une lettre ou un chiffre, et la base l'exige
        // (`^[a-z0-9]`). Un souligné en tête se confond avec un nom masqué, et « -_-martin »
        // rendait « -martin » : accepté ici, refusé là-bas, pour un message que personne
        // n'aurait compris.
        while let first = result.first, !(first.isLetter || first.isNumber) {
            result.removeFirst()
        }

        return String(result.prefix(maximumLength))
    }

    /// Le nom prêt à être écrit, ou ce qui l'en empêche.
    static func validate(_ raw: String) -> Result<String, Problem> {
        let normalized = normalize(raw)

        if normalized.isEmpty {
            // Rien de récupérable : c'était vide, ou seulement de la ponctuation.
            return .failure(raw.trimmingCharacters(in: .whitespaces).isEmpty ? .empty : .tooShort)
        }
        if normalized.count < minimumLength { return .failure(.tooShort) }
        if normalized.count > maximumLength { return .failure(.tooLong) }

        return .success(normalized)
    }

    /// Le nom précédé de son arobase, comme on l'écrit partout dans l'app.
    static func display(_ username: String) -> String {
        username.hasPrefix("@") ? username : "@" + username
    }
}
