import CoreText
import UIKit

/// Enregistre les fichiers de police du bundle (complément de `UIAppFonts` dans
/// Info.plist) pour qu'ils soient disponibles dès le premier rendu.
///
/// Les deux familles sont enregistrées ensemble parce qu'elles servent ensemble : Outfit
/// écrit l'interface, Hanken Grotesk écrit le texte qu'on lit. Une seule des deux
/// manquante, et la moitié de l'app retombe sur San Francisco sans rien dire.
enum FontLoader {
    private static let fileNames = [
        "Outfit-Regular",
        "Outfit-Medium",
        "Outfit-SemiBold",
        "Outfit-Bold",
        "HankenGrotesk-Regular",
        "HankenGrotesk-Medium",
        "HankenGrotesk-SemiBold",
        "HankenGrotesk-Bold"
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
