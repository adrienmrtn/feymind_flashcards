import ImageIO
import UIKit
import XCTest
@testable import Micabo

/// La mascotte et son moteur : chaque humeur animée a son fichier, rogné comme le dit
/// `MikaArt` ; chaque pose a son image ; le décodage se fait hors du fil principal, une fois,
/// et un seul Mika joue à la fois.
final class MikaMascotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MikaClipStore.purge()
    }

    /// Les animations embarquées sont exactement celles que les humeurs jouent, et chaque
    /// fichier a le nombre d'images et la taille que `MikaArt` annonce.
    func testEveryAnimatedMoodHasItsClip() throws {
        let used = Set(MikaMood.allCases.compactMap(\.clip))
        XCTAssertEqual(used, Set(MikaArt.clips.keys), "une animation embarquée sans humeur, ou l'inverse")
        for name in used {
            let info = try XCTUnwrap(MikaArt.clips[name])
            let url = try XCTUnwrap(MikaLibrary.url(for: name), "mika-\(name).webp manque")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            XCTAssertEqual(CGImageSourceGetCount(source), info.frames, "\(name) : images")
            let first = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, info.frames / 2, nil))
            XCTAssertEqual(first.width, Int(info.rect.width), "\(name) : largeur")
            XCTAssertEqual(first.height, Int(info.rect.height), "\(name) : hauteur")
            // 12 ou 24 images par seconde, la durée du kit.
            if let mood = MikaMood.allCases.first(where: { $0.clip == name }) {
                XCTAssertEqual(Double(info.frames) / info.fps, mood.duration, accuracy: 0.1, "\(name) : durée")
            }
        }
        // Le repos et le « non » sont toujours fixes.
        XCTAssertNil(MikaMood.idle.clip)
        XCTAssertNil(MikaMood.shake.clip)
    }

    /// Les poses fixes, la tête de l'avatar, et chaque pose a sa place dans le canevas.
    func testEveryStillExists() {
        for still in MikaStill.allCases {
            XCTAssertNotNil(UIImage(named: still.imageName), "\(still.imageName) manque au catalogue")
            XCTAssertNotNil(MikaArt.stills[still.rawValue], "\(still.rawValue) sans cadre")
        }
        XCTAssertNotNil(UIImage(named: "Mika-tete"))
    }

    /// Seules la réflexion et l'écriture bouclent : l'attente d'une génération. Le reste se
    /// joue une fois.
    func testOnlyWaitingLoops() {
        XCTAssertEqual(Set(MikaMood.allCases.filter(\.loops)), [.think, .write])
    }

    /// Sous XCTest, les vues de Mika n'animent rien : les rendus restent des images.
    func testTestsUseStills() {
        XCTAssertTrue(MikaLibrary.isRunningTests)
    }

    /// **Le temps de préparer une animation**, hors du fil principal (le chemin de décodage
    /// le vérifie lui-même en DEBUG) : toutes les animations, à la taille d'un Mika de 120
    /// points sur un écran 3x. Les chiffres s'écrivent dans le journal (`MIKA-PERF`).
    func testPreparingAnAnimationIsFastAndOffTheMainThread() throws {
        let resolution = MikaClipStore.resolution(MikaPlacement.standing(side: 120).scale * 3)
        var total = 0.0
        var frames = 0
        for name in MikaArt.clips.keys.sorted() {
            let start = CFAbsoluteTimeGetCurrent()
            let clip = try XCTUnwrap(decodeOffMain(name, resolution: resolution), "\(name) ne se décode pas")
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            total += elapsed
            frames += clip.images.count
            XCTAssertLessThanOrEqual(clip.bytes, MikaClipStore.budget, "\(name) dépasse le budget")
            XCTAssertTrue(Set(clip.images.map(\.width)).count == 1, "\(name) : images de tailles différentes")
            XCTAssertTrue(isOpaqueNearCenter(clip.images[clip.images.count / 2]), "\(name) : image vide")
            print(String(format: "MIKA-PERF %@ %d images %dx%d %.1f Mo %.0f ms (%.1f ms/image)",
                         name, clip.images.count, clip.images[0].width, clip.images[0].height,
                         Double(clip.bytes) / 1_048_576, elapsed, elapsed / Double(clip.images.count)))
        }
        print(String(format: "MIKA-PERF total %d images %.0f ms (%.1f ms/image)", frames, total, total / Double(frames)))

        // La mesure XCTest : préparer le coucou (52 images, la plus longue des 24 i/s).
        measure(metrics: [XCTClockMetric()]) {
            _ = decodeOffMain("coucou", resolution: resolution)
        }
    }

    /// Le cache : la deuxième demande ne décode rien, et la réponse arrive sur le fil principal.
    func testLoadingTwiceDecodesOnce() throws {
        let first = expectation(description: "première")
        var clip: MikaFrames?
        MikaClipStore.load("saut", pixelsPerUnit: 1) { frames in
            XCTAssertTrue(Thread.isMainThread)
            clip = frames
            first.fulfill()
        }
        wait(for: [first], timeout: 10)
        let second = expectation(description: "seconde")
        let start = CFAbsoluteTimeGetCurrent()
        MikaClipStore.load("saut", pixelsPerUnit: 1) { frames in
            XCTAssertTrue(frames === clip, "la seconde demande a redécodé")
            second.fulfill()
        }
        wait(for: [second], timeout: 1)
        print(String(format: "MIKA-PERF cache %.1f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000))
        XCTAssertNotNil(MikaClipStore.cached("saut", pixelsPerUnit: 1))
    }

    /// **Un seul Mika joue à la fois** : le second qui commence arrête le premier.
    @MainActor
    func testOnlyOneMikaPlaysAtOnce() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 400))
        window.isHidden = false
        let one = MikaPlayerView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        let two = MikaPlayerView(frame: CGRect(x: 0, y: 200, width: 120, height: 120))
        window.addSubview(one)
        window.addSubview(two)
        one.placement = .standing(side: 120)
        two.placement = .standing(side: 120)

        one.apply(MikaPlayRequest(clip: "reflexion", loops: true, take: 1, mood: .think))
        try waitUntil { one.isPlaying }
        two.apply(MikaPlayRequest(clip: "ecriture", loops: true, take: 1, mood: .write))
        try waitUntil { two.isPlaying && !one.isPlaying }
        XCTAssertTrue(MikaStage.shared.isPlaying)

        // Quitter l'écran arrête la lecture.
        two.removeFromSuperview()
        try waitUntil { !two.isPlaying }
        one.removeFromSuperview()
    }

    // MARK: - Outils

    private func decodeOffMain(_ name: String, resolution: CGFloat) -> MikaFrames? {
        var result: MikaFrames?
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            result = MikaClipStore.decode(name, resolution: resolution)
            done.signal()
        }
        done.wait()
        return result
    }

    /// L'image n'est pas vide : Mika y est, opaque quelque part.
    private func isOpaqueNearCenter(_ image: CGImage) -> Bool {
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let alphas = stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
        return alphas.filter { $0 > 200 }.count >= 4
    }

    @MainActor
    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return XCTFail("délai dépassé") }
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }
}
