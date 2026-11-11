import CoreGraphics

// Généré par scripts/mika-assets.py depuis le kit de Mika. Ne pas éditer à la main.

/// **Où chaque image de Mika se place**, dans le canevas de 512 du kit : les vidéos, leurs
/// premières images et les poses sont rognées autour de lui, ce cadre les remet au pixel près.
enum MikaArt {
    struct Clip {
        /// Le rectangle de la vidéo (et de sa première image) dans le canevas.
        let rect: CGRect
        let frames: Int
        let fps: Double

        var duration: Double { Double(frames) / fps }
    }

    /// Pixels par unité du canevas, partout.
    static let pixelsPerUnit: CGFloat = 1.5

    /// Les animations embarquées, par nom (`mika-<nom>.mov`, première image `Mika-clip-<nom>`).
    static let clips: [String: Clip] = [
        "coucou": Clip(rect: CGRect(x: 59, y: 142, width: 384, height: 372), frames: 52, fps: 24),
        "saut": Clip(rect: CGRect(x: 49, y: 24, width: 424, height: 492), frames: 38, fps: 24),
        "surprise": Clip(rect: CGRect(x: 50, y: 107, width: 416, height: 408), frames: 36, fps: 24),
        "clin-doeil": Clip(rect: CGRect(x: 71, y: 157, width: 376, height: 360), frames: 36, fps: 24),
        "apparition": Clip(rect: CGRect(x: 45, y: -2, width: 440, height: 516), frames: 32, fps: 24),
        "celebration": Clip(rect: CGRect(x: 31, y: 25, width: 484, height: 492), frames: 64, fps: 24),
        "reflexion": Clip(rect: CGRect(x: 71, y: 163, width: 380, height: 352), frames: 72, fps: 24),
        "ecriture": Clip(rect: CGRect(x: 70, y: 138, width: 392, height: 376), frames: 48, fps: 24),
        "triste": Clip(rect: CGRect(x: 74, y: 187, width: 380, height: 328), frames: 72, fps: 24),
        "regard": Clip(rect: CGRect(x: 69, y: 150, width: 376, height: 364), frames: 72, fps: 24),
        "sommeil": Clip(rect: CGRect(x: 63, y: 118, width: 412, height: 396), frames: 96, fps: 24),
    ]

    /// Les poses fixes, par nom (`Mika-<nom>`).
    static let stills: [String: CGRect] = [
        "neutre": CGRect(x: 69, y: 157, width: 374, height: 358),
        "coucou": CGRect(x: 62, y: 147, width: 378, height: 368),
        "sourire": CGRect(x: 74, y: 157, width: 370, height: 358),
        "sommeil": CGRect(x: 66, y: 135, width: 406, height: 380),
        "reflexion": CGRect(x: 76, y: 165, width: 374, height: 350),
        "surprise": CGRect(x: 61, y: 125, width: 402, height: 390),
        "saut": CGRect(x: 83, y: 24, width: 356, height: 386),
        "triste": CGRect(x: 74, y: 192, width: 378, height: 322),
        "ecriture": CGRect(x: 77, y: 165, width: 372, height: 350),
        "clin-doeil": CGRect(x: 75, y: 160, width: 372, height: 354),
    ]

    /// Le visage de l'avatar (`Mika-tete`).
    static let head = CGRect(x: 138, y: 200, width: 236, height: 236)
}
