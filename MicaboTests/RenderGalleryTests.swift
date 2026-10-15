import SwiftUI
import XCTest
@testable import Micabo

/// **Des écrans en PNG, pour regarder l'interface sans simulateur.**
///
/// La CI compile et teste sur une machine que personne ne voit ; ces rendus sont ce qu'elle
/// rapporte de l'écran. Ils ne vérifient rien : un test qui comparerait des pixels casserait
/// à chaque retouche de la refonte. Ils dessinent, et l'artefact « rendus » les garde.
///
/// Rien ne se dessine hors de la CI : sans `MICABO_RENDER_DIR`, chaque test s'arrête aussitôt.
@MainActor
final class RenderGalleryTests: XCTestCase {
    func testMascot() throws {
        let moods: [(String, MicaboMascot.Mood)] = [
            ("happy", .happy), ("thinking", .thinking), ("celebrating", .celebrating),
            ("waving", .waving), ("curious", .curious), ("reading", .reading),
            ("unsure", .unsure), ("proud", .proud)
        ]
        try RenderGallery.render(
            "mascot-moods",
            width: 393,
            HStack(spacing: 0) {
                ForEach(moods, id: \.0) { mood in
                    MicaboMascot(mood: mood.1, size: 44)
                }
            }
            .padding(16)
        )
    }
}

/// Le dessin d'une vue en PNG, à la densité d'un iPhone.
@MainActor
enum RenderGallery {
    static var directory: URL? {
        guard let path = ProcessInfo.processInfo.environment["MICABO_RENDER_DIR"],
              !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    /// Dessine `view` sur la largeur d'un écran, à sa hauteur naturelle (ou à `height`), et
    /// l'écrit sous `<nom>.png`. Sans dossier de rendu, ne fait rien.
    static func render<V: View>(
        _ name: String,
        width: CGFloat = 393,
        height: CGFloat? = nil,
        _ view: V
    ) throws {
        guard let directory else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        FontLoader.registerFonts()
        let framed = view
            .frame(width: width, height: height)
            .background(MicaboColor.canvas)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = 3
        guard let data = renderer.uiImage?.pngData() else {
            XCTFail("rendu vide : \(name)")
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
