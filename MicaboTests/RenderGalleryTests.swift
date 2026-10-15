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

    /// La base d'icônes, et les replis dessinés de ce qui n'y est pas.
    func testIcons() throws {
        let columns = Array(repeating: GridItem(.fixed(58), spacing: 6), count: 6)
        try RenderGallery.render(
            "icons",
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(MicaboIcon.allCases) { icon in
                    VStack(spacing: 2) {
                        MicaboIconView(icon: icon, size: 40)
                        Text(icon.rawValue)
                            .font(MicaboFont.ui(8, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
        )
    }

    /// Le papier, l'encre, l'accent, les cinq tons, et le barème typographique des notes.
    func testPaletteAndType() throws {
        try RenderGallery.render(
            "palette-type",
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    swatch(MicaboColor.canvas, "ivoire")
                    swatch(MicaboColor.surface, "surface")
                    swatch(MicaboColor.ink, "encre")
                    swatch(MicaboColor.accent, "bleu")
                    swatch(MicaboColor.keyword, "violet")
                    swatch(MicaboColor.correct, "juste")
                    swatch(MicaboColor.wrong, "faux")
                }
                HStack(spacing: 8) {
                    ForEach(LessonTone.allCases) { tone in
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 10).fill(tone.pale).frame(height: 28)
                            Circle().fill(tone.vivid).frame(width: 28, height: 28)
                            Text(tone.rawValue).font(MicaboFont.small).foregroundStyle(tone.ink)
                        }
                    }
                }
                Text("La guerre froide").font(MicaboFont.title).foregroundStyle(MicaboColor.ink)
                Text("Deux blocs face à face").font(MicaboFont.subtitle).foregroundStyle(MicaboColor.ink)
                (Text("Après 1945, les ")
                    + Text("États-Unis").font(MicaboFont.keyword).foregroundColor(MicaboColor.keyword)
                    + Text(" et l'URSS s'opposent sans jamais se faire directement la guerre."))
                    .font(MicaboFont.notes)
                    .foregroundStyle(MicaboColor.ink)
                Text("Cercle 4 · 12 min")
                    .font(MicaboFont.small)
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            .padding(20)
        )
    }

    private func swatch(_ color: Color, _ name: String) -> some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(MicaboColor.stroke))
                .frame(width: 44, height: 44)
            Text(name).font(MicaboFont.ui(9, weight: .bold)).foregroundStyle(MicaboColor.inkSecondary)
        }
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
