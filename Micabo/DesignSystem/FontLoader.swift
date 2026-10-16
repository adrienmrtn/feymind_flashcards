import CoreText
import UIKit

/// Enregistre les fichiers de police du bundle (complément de `UIAppFonts` dans
/// Info.plist) pour qu'ils soient disponibles dès le premier rendu.
///
/// Une seule famille, Nunito, en six graisses et deux italiques. Un fichier manquant, et la
/// graisse qu'il porte retombe sur San Francisco sans rien dire : `FontTests` vérifie qu'ils
/// sont tous là.
enum FontLoader {
    static let fileNames = [
        "Nunito-Regular",
        "Nunito-Medium",
        "Nunito-SemiBold",
        "Nunito-Bold",
        "Nunito-ExtraBold",
        "Nunito-Black",
        "Nunito-Italic",
        "Nunito-BoldItalic"
    ]

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
