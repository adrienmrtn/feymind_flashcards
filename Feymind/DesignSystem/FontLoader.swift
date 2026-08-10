import CoreText
import UIKit

/// Enregistre les fichiers Hanken Grotesk embarqués dans le bundle, pour qu'ils soient
/// utilisables via `Font.custom` sans passer par `UIAppFonts` dans l'Info.plist.
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
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
