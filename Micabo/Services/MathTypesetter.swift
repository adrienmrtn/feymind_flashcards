import Foundation

#if canImport(SwiftMath)
import SwiftMath
#endif

/// Le moteur de composition mathématique, quand il est là.
///
/// `FormulaRenderer` transpose du LaTeX en Unicode : `x^2` devient `x²`, `\frac{a}{b}`
/// devient `a/b`. C'est lisible pour trois symboles, et ça cesse de l'être dès qu'une
/// fraction en contient une autre, qu'une intégrale porte ses bornes, ou qu'une matrice
/// apparaît. `(a + b)/(c + d)` n'est pas une fraction : c'est sa description.
///
/// `SwiftMath` compose pour de vrai, avec les règles de LaTeX et ses fontes. Tout ce qui
/// s'appuie dessus passe **par ce fichier et par lui seul** : c'est ce qui permet au dépôt
/// de compiler dans les deux états, avec ou sans le paquet résolu, exactement comme
/// `PaywallPurchases` le fait pour RevenueCat. Sans le paquet, `canTypeset` répond toujours
/// non et le produit garde le comportement d'avant.
///
/// **La transposition reste le plancher.** Ce n'est pas de la prudence de façade : une fiche
/// est écrite par un modèle, donc du LaTeX incomplet arrivera. Le choix est entre un cadre
/// vide et une formule un peu moins belle.
enum MathTypesetter {
    /// Vrai si le paquet de composition est présent dans cette compilation.
    static var isAvailable: Bool {
        #if canImport(SwiftMath)
        return true
        #else
        return false
        #endif
    }

    /// Vrai si le moteur sait composer ce fragment.
    ///
    /// La vérification passe par l'analyseur, pas par la vue : `MTMathUILabel` affiche son
    /// erreur en rouge dans la page, et un message d'analyseur LaTeX au milieu d'une fiche
    /// se lit comme une panne du produit.
    static func canTypeset(_ latex: String) -> Bool {
        let source = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return false }

        #if canImport(SwiftMath)
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: source, error: &error)
        return error == nil && list != nil
        #else
        return false
        #endif
    }

    /// Le LaTeX d'un texte qui n'est **que** une formule, sinon `nil`.
    ///
    /// C'est la règle qui décide si une carte est composée ou transposée, et elle tient à
    /// une contrainte de SwiftUI : un `Text` ne sait pas contenir de vue. Une formule au
    /// milieu d'une phrase ne peut donc pas être composée sans casser le fil du paragraphe,
    /// alors qu'une carte qui *est* une formule n'a pas de phrase autour.
    ///
    /// Volontairement strict : un seul fragment, rien avant, rien après. Deux formules dans
    /// un même texte, ou une formule suivie d'un mot, restent transposées.
    static func soleFormula(in source: String) -> String? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)

        let inner: String
        if trimmed.hasPrefix("$$"), trimmed.hasSuffix("$$"), trimmed.count > 4 {
            inner = String(trimmed.dropFirst(2).dropLast(2))
        } else if trimmed.hasPrefix("$"), trimmed.hasSuffix("$"), trimmed.count > 2 {
            inner = String(trimmed.dropFirst().dropLast())
        } else {
            return nil
        }

        let formula = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !formula.isEmpty, !formula.contains("$") else { return nil }
        return formula
    }
}
