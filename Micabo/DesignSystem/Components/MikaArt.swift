import CoreGraphics

// Généré par scripts/mika-assets.py depuis le kit de Mika. Ne pas éditer à la main.

/// **Où chaque image de Mika se place**, dans le canevas de 512 du kit : les animations et
/// les poses sont rognées autour de lui, ce cadre les remet au pixel près.
enum MikaArt {
    struct Clip {
        /// Le rectangle de l'animation dans le canevas.
        let rect: CGRect
        let frames: Int
        let fps: Double
    }

    /// Les animations embarquées, par nom de fichier (`mika-<nom>.webp`).
    static let clips: [String: Clip] = [
        "coucou": Clip(rect: CGRect(x: 91, y: 165, width: 326, height: 326), frames: 52, fps: 24),
        "saut": Clip(rect: CGRect(x: 79, y: 48, width: 370, height: 442), frames: 38, fps: 24),
        "surprise": Clip(rect: CGRect(x: 81, y: 130, width: 358, height: 364), frames: 36, fps: 24),
        "clin-doeil": Clip(rect: CGRect(x: 103, y: 180, width: 308, height: 310), frames: 36, fps: 24),
        "apparition": Clip(rect: CGRect(x: 75, y: 0, width: 378, height: 494), frames: 32, fps: 24),
        "celebration": Clip(rect: CGRect(x: 56, y: 51, width: 434, height: 442), frames: 32, fps: 12),
        "reflexion": Clip(rect: CGRect(x: 103, y: 189, width: 320, height: 302), frames: 36, fps: 12),
        "ecriture": Clip(rect: CGRect(x: 102, y: 149, width: 336, height: 342), frames: 24, fps: 12),
        "triste": Clip(rect: CGRect(x: 106, y: 205, width: 328, height: 290), frames: 36, fps: 12),
        "regard": Clip(rect: CGRect(x: 101, y: 173, width: 308, height: 318), frames: 36, fps: 12),
        "sommeil": Clip(rect: CGRect(x: 94, y: 134, width: 358, height: 360), frames: 48, fps: 12),
    ]

    /// Les poses fixes, par nom (`Mika-<nom>`).
    static let stills: [String: CGRect] = [
        "neutre": CGRect(x: 101, y: 180, width: 308, height: 312),
        "coucou": CGRect(x: 94, y: 170, width: 312, height: 318),
        "sourire": CGRect(x: 105, y: 184, width: 305, height: 306),
        "sommeil": CGRect(x: 98, y: 161, width: 354, height: 331),
        "reflexion": CGRect(x: 107, y: 188, width: 307, height: 301),
        "surprise": CGRect(x: 92, y: 148, width: 346, height: 336),
        "saut": CGRect(x: 116, y: 48, width: 288, height: 330),
        "triste": CGRect(x: 106, y: 210, width: 325, height: 286),
        "ecriture": CGRect(x: 110, y: 190, width: 310, height: 298),
        "clin-doeil": CGRect(x: 107, y: 186, width: 304, height: 300),
    ]

    /// La tête de l'avatar (`Mika-tete`).
    static let head = CGRect(x: 104, y: 176, width: 308, height: 308)
}
