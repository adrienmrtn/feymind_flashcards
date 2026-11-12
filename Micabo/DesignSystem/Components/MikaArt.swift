import CoreGraphics

// Généré par scripts/mika-assets.py depuis le kit de Mika. Ne pas éditer à la main.

/// **Où chaque expression de Mika se place**, dans le canevas de 512 du kit : les images
/// sont rognées autour de lui, ce cadre les remet au pixel près — deux expressions se
/// superposent exactement pendant leur fondu.
enum MikaArt {
    /// Pixels par unité du canevas, partout.
    static let pixelsPerUnit: CGFloat = 2.0

    /// Les expressions, par nom (`Mika-<nom>`).
    static let stills: [String: CGRect] = [
        "neutre": CGRect(x: 69, y: 157, width: 374, height: 358),
        "sourire": CGRect(x: 74, y: 157, width: 370, height: 358),
        "clin-doeil": CGRect(x: 75, y: 160, width: 372, height: 354),
        "coucou": CGRect(x: 62, y: 147, width: 378, height: 368),
        "surprise": CGRect(x: 61, y: 125, width: 402, height: 390),
        "reflexion": CGRect(x: 76, y: 165, width: 374, height: 350),
        "ecriture": CGRect(x: 77, y: 165, width: 372, height: 350),
        "triste": CGRect(x: 74, y: 192, width: 378, height: 322),
        "sommeil": CGRect(x: 66, y: 135, width: 406, height: 380),
    ]

    /// Le visage de l'avatar (`Mika-tete`).
    static let head = CGRect(x: 118, y: 182, width: 276, height: 276)
}
