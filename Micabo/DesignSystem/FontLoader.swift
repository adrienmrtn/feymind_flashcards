import CoreText
import UIKit

/// Enregistre les fichiers de police du bundle (complément de `UIAppFonts` dans
/// Info.plist) pour qu'ils soient disponibles dès le premier rendu.
///
/// Une seule famille embarquée : **Sofia Sans Condensed**, la police d'affichage de Micabo, en
/// ExtraBold et en Black (`V3Typeface.displayFiles`). Tout le reste du texte est en police système. Un
/// fichier manquant, et la graisse qu'il porte retombe sur San Francisco sans rien dire :
/// `FoundationsTests` vérifie qu'ils sont tous là.
enum FontLoader {
    static let fileNames = V3Typeface.displayFiles

    private static var didRegister = false

    static func registerFonts() {
        guard !didRegister else { return }
        didRegister = true

        for name in fileNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                continue
            }
            // Les polices sont parfois rangées dans un sous-dossier Fonts du bundle.
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
