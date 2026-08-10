import CoreText
import UIKit

/// Enregistre les fichiers Hanken Grotesk du bundle (complément de `UIAppFonts`
/// dans Info.plist) pour qu'ils soient disponibles dès le premier rendu.
enum FontLoader {
    private static let fileNames = [
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
