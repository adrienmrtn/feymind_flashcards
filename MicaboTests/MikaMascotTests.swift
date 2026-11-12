import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Mika, fluide à coup sûr** (lot 9, après le build 170 : « il faut pas que tu fasses Mika sauter », « pas
/// fluide ») : une image fixe nette à chaque instant, à la définition du kit ; tout mouvement
/// natif (fondus, respiration, écrasement, étincelles) ; aucune vidéo embarquée ; des gestes
/// courts qui finissent sur un sourire ; des expressions qui se superposent (le corps ne pâlit
/// pas pendant un fondu) ; un seul Mika en mouvement ; et nulle part dans l'app un Mika qui
/// saute ou se déplace.
final class MikaMascotTests: XCTestCase {
    // MARK: - Les images

    /// Chaque expression est au catalogue, à 2 pixels par unité du canevas (la définition du
    /// kit, sans agrandissement), avec son cadre ; la tête de l'avatar aussi.
    func testEveryExpressionIsInTheCatalogAtKitResolution() throws {
        XCTAssertEqual(MikaArt.pixelsPerUnit, 2)
        for still in MikaStill.allCases {
            let image = try XCTUnwrap(UIImage(named: still.imageName), "\(still.imageName) manque au catalogue")
            let rect = try XCTUnwrap(MikaArt.stills[still.rawValue], "\(still.rawValue) sans cadre")
            XCTAssertEqual(image.size.width * image.scale, rect.width * MikaArt.pixelsPerUnit, accuracy: 1, "\(still.rawValue) : largeur")
            XCTAssertEqual(image.size.height * image.scale, rect.height * MikaArt.pixelsPerUnit, accuracy: 1, "\(still.rawValue) : hauteur")
            // Debout : le bas des tentacules au même sol pour toutes les expressions.
            XCTAssertEqual(rect.maxY, 515, accuracy: 2, "\(still.rawValue) ne touche pas le sol")
        }
        XCTAssertEqual(Set(MikaArt.stills.keys), Set(MikaStill.allCases.map(\.rawValue)), "une image sans expression, ou l'inverse")
        XCTAssertNotNil(UIImage(named: "Mika-tete"))
    }

    /// **Plus aucune vidéo** : une animation précalculée à 24 images par seconde saccadait à
    /// côté d'une interface à 120 Hz. Rien ne doit en revenir dans l'app.
    func testNoVideoIsShipped() {
        let videos = (Bundle.main.urls(forResourcesWithExtension: "mov", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? [])
        XCTAssertTrue(videos.filter { $0.lastPathComponent.hasPrefix("mika") }.isEmpty, "\(videos)")
        XCTAssertNil(UIImage(named: "Mika-clip-coucou"), "les premières images des vidéos sont parties avec elles")
        XCTAssertNil(UIImage(named: "Mika-saut"), "la pose du saut, en l'air, n'a plus sa place")
    }

    // MARK: - Les gestes

    /// Les gestes joyeux finissent sur un sourire ; seules la réflexion et l'écriture
    /// alternent (l'attente réseau) ; la tristesse reste triste.
    func testGesturesEndSmilingAndOnlyWaitingAlternates() {
        XCTAssertEqual(Set(MikaMood.allCases.filter(\.loops)), [.think, .write])
        for mood in [MikaMood.idle, .wave, .happy, .celebrate, .wink, .appear] {
            XCTAssertEqual(mood.rest, .smile, "\(mood) devrait finir sur un sourire")
        }
        XCTAssertEqual(MikaMood.sad.rest, .sad)
        XCTAssertEqual(MikaMood.surprise.rest, .surprise)
        XCTAssertFalse(MikaMood.sad.winksOnTap)
        XCTAssertEqual(MikaMood.shake.still, .sad)
        XCTAssertEqual(MikaMood.sleep.still, .sleep)
        XCTAssertEqual(MikaMood.wink.still, .wink, "fixe, le clin d'œil se voit")
        for mood in MikaMood.allCases where mood.loops {
            XCTAssertEqual(mood.loopPoses.count, 2)
            XCTAssertEqual(mood.loopPoses.first, mood.still)
        }
    }

    /// Un geste est court (au plus 2 secondes), chaque temps laisse au fondu le temps de finir.
    func testGesturesAreShort() {
        for mood in MikaMood.allCases {
            let total = mood.beats.reduce(0) { $0 + $1.after }
            XCTAssertLessThanOrEqual(total, 2, "\(mood) : geste trop long")
            for beat in mood.beats {
                XCTAssertGreaterThanOrEqual(beat.after, 0.4, "\(mood) : deux fondus se chevauchent")
            }
            XCTAssertGreaterThan(mood.duration, 0)
        }
    }

    /// **Le fondu ne fait pas clignoter Mika** : deux expressions qui se suivent partagent leur
    /// corps (posées dans le canevas, leurs silhouettes se recouvrent à plus de 80 %), et la
    /// nouvelle se pose sur l'ancienne restée opaque.
    func testSuccessiveExpressionsShareTheirBody() throws {
        var pairs: Set<[String]> = []
        for mood in MikaMood.allCases {
            var previous = mood.opening
            for beat in mood.beats {
                pairs.insert([previous.rawValue, beat.pose.rawValue])
                previous = beat.pose
            }
            if mood.loops { pairs.insert(mood.loopPoses.map(\.rawValue)) }
            // L'appui : un clin d'œil depuis la pose du moment, quand elle s'y prête.
            if mood.winksOnTap { pairs.insert([mood.rest.rawValue, MikaStill.wink.rawValue]) }
        }
        for pair in pairs.sorted(by: { $0.joined() < $1.joined() }) where pair[0] != pair[1] {
            let a = try silhouette(try XCTUnwrap(MikaStill(rawValue: pair[0])))
            let b = try silhouette(try XCTUnwrap(MikaStill(rawValue: pair[1])))
            var both = 0, either = 0
            for index in a.indices {
                if a[index] && b[index] { both += 1 }
                if a[index] || b[index] { either += 1 }
            }
            let overlap = Double(both) / Double(max(1, either))
            print(String(format: "MIKA-FONDU %@ → %@ : silhouettes communes à %.0f %%", pair[0], pair[1], overlap * 100))
            XCTAssertGreaterThan(overlap, 0.8, "\(pair[0]) → \(pair[1]) : le fondu se verrait")
        }
    }

    // MARK: - La scène

    /// **Un seul Mika en mouvement** : le second qui commence pose le premier.
    func testOnlyOneMikaMovesAtOnce() {
        let stage = MikaStage()
        let one = UUID(), two = UUID()
        var settled: [UUID] = []
        stage.begin(one) { settled.append(one) }
        XCTAssertEqual(stage.performer, one)
        stage.begin(two) { settled.append(two) }
        XCTAssertEqual(settled, [one])
        XCTAssertEqual(stage.performer, two)
        stage.end(one)
        XCTAssertEqual(stage.performer, two, "le premier, déjà posé, ne libère pas la scène du second")
        stage.end(two)
        XCTAssertNil(stage.performer)
    }

    /// Sous XCTest, les vues de Mika ne bougent pas : les rendus restent des images.
    func testTestsUseStills() {
        XCTAssertTrue(MikaLibrary.isRunningTests)
    }

    // MARK: - Nulle part un saut

    /// **Aucun Mika ne saute ni ne se déplace dans l'app** : à côté d'un `MikaMascot` ou d'un
    /// `MikaPeek`, pas de décalage qui dépend d'un état (`offset(y: hop ? -10 : 0)`), pas
    /// d'échelle qui le fait surgir de petit (`scaleEffect(shown ? 1 : 0.4)`). Un décalage
    /// fixe, pour le placer, reste permis.
    func testNoMikaJumpsAnywhere() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        let moving = try NSRegularExpression(pattern: #"\.offset\([^)]*\?|\.scaleEffect\([^)]*\?\s*[0-9.]+\s*:\s*0?\.[0-8]"#)
        var offenders: [String] = []
        var read = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            guard url.lastPathComponent != "MikaMascot.swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            read += 1
            let lines = text.components(separatedBy: "\n")
            for (number, line) in lines.enumerated() where line.contains("MikaMascot(") || line.contains("MikaPeek(") {
                for follow in lines[number..<min(lines.count, number + 6)] {
                    let range = NSRange(follow.startIndex..., in: follow)
                    if moving.firstMatch(in: follow, range: range) != nil {
                        offenders.append("\(url.lastPathComponent):\(number + 1) \(follow.trimmingCharacters(in: .whitespaces))")
                    }
                }
            }
        }
        guard read > 0 else { throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur") }
        XCTAssertTrue(offenders.isEmpty, "Mika bouge de place :\n" + offenders.joined(separator: "\n"))
    }

    // MARK: - Les rendus

    /// Les expressions, le milieu de chaque fondu (la nouvelle à 50 % sur l'ancienne opaque),
    /// et la fête avec ses étincelles, de jour et de nuit.
    @MainActor
    func testRenderExpressionsAndFades() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        try RenderGallery.render("mika9-expressions", night: true,
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 14) {
                ForEach(MikaStill.allCases, id: \.self) { still in
                    VStack(spacing: 4) {
                        MikaStillView(pose: still, side: 112)
                        Text(still.rawValue)
                            .font(MicaboFont.ui(12, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                }
            }
            .padding(16)
        )
        let fades: [(MikaStill, MikaStill)] = [(.wave, .smile), (.neutral, .wink), (.wink, .smile), (.neutral, .smile), (.think, .write), (.smile, .wink)]
        try RenderGallery.render("mika9-fades", night: true,
            VStack(spacing: 10) {
                ForEach(fades.indices, id: \.self) { index in
                    let fade = fades[index]
                    HStack(spacing: 8) {
                        MikaStillView(pose: fade.0, side: 96)
                        ZStack {
                            MikaStillView(pose: fade.0, side: 96)
                            MikaStillView(pose: fade.1, side: 96).opacity(0.5)
                        }
                        MikaStillView(pose: fade.1, side: 96)
                        Text("\(fade.0.rawValue) → \(fade.1.rawValue)")
                            .font(MicaboFont.ui(11, weight: .bold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                }
            }
            .padding(16)
        )
        try RenderGallery.render("mika9-celebrate", night: true,
            VStack(spacing: 18) {
                MikaMascot(mood: .celebrate, size: 180, frozenAt: 0)
                HStack(alignment: .bottom, spacing: 20) {
                    MikaMascot(mood: .celebrate, size: 120, frozenAt: 0)
                    VStack(spacing: 0) {
                        MikaPeek(mood: .celebrate, width: MikaPeek.line)
                        Capsule().fill(MicaboColor.stroke).frame(width: 140, height: 2)
                    }
                }
            }
            .padding(24)
        )
    }

    // MARK: - Outils

    /// La silhouette d'une expression posée dans le canevas de 512 (un pixel par unité).
    private func silhouette(_ still: MikaStill) throws -> [Bool] {
        let image = try XCTUnwrap(UIImage(named: still.imageName)?.cgImage)
        let side = 512
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let rect = still.rect
        // CoreGraphics compte depuis le bas.
        context.draw(image, in: CGRect(x: rect.minX, y: CGFloat(side) - rect.maxY, width: rect.width, height: rect.height))
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] > 128 }
    }
}

/// Une expression seule, debout dans un carré : pour les rendus.
private struct MikaStillView: View {
    let pose: MikaStill
    let side: CGFloat

    var body: some View {
        let placement = MikaPlacement.standing(side: side)
        let frame = placement.frame(of: pose.rect)
        Image(pose.imageName)
            .resizable()
            .frame(width: frame.width, height: frame.height)
            .offset(x: frame.minX, y: frame.minY)
            .frame(width: side, height: side, alignment: .topLeading)
    }
}
