import AVFoundation
import CoreMedia
import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// La mascotte et son moteur : chaque humeur animée a sa vidéo HEVC avec alpha, à la taille et
/// au nombre d'images que dit `MikaArt`, et sa première image en pose fixe ; la vidéo se lit
/// hors du fil principal, une fois ; elle se décode avec sa transparence ; un seul Mika joue
/// à la fois.
final class MikaMascotTests: XCTestCase {
    /// Les mesures du lecteur à l'écran, reprises dans le rendu `mika-perf` (qui passe après :
    /// les tests d'une classe tournent dans l'ordre alphabétique).
    static var playerLines: [String] = []

    override func setUp() {
        super.setUp()
        MikaClipStore.purge()
    }

    /// Les animations embarquées sont exactement celles que les humeurs jouent, chaque vidéo a
    /// le nombre d'images, la cadence et la taille que `MikaArt` annonce — toutes ses images, à
    /// 24 par seconde.
    func testEveryAnimatedMoodHasItsVideo() throws {
        let used = Set(MikaMood.allCases.compactMap(\.clip))
        XCTAssertEqual(used, Set(MikaArt.clips.keys), "une animation embarquée sans humeur, ou l'inverse")
        for name in used.sorted() {
            let info = try XCTUnwrap(MikaArt.clips[name])
            XCTAssertNotNil(MikaLibrary.url(for: name), "mika-\(name).mov manque")
            XCTAssertEqual(info.fps, 24, "\(name) : 24 images par seconde")
            let clip = try XCTUnwrap(readOffMain(name), "\(name) ne se lit pas")
            XCTAssertEqual(clip.samples.count, info.frames, "\(name) : images")
            let format = try XCTUnwrap(CMSampleBufferGetFormatDescription(clip.samples[0]))
            let size = CMVideoFormatDescriptionGetDimensions(format)
            // Le fichier dit « hvc1 » ; la transparence se vérifie au décodage
            // (`testVideosDecodeWithAlphaAndFast`).
            XCTAssertEqual(CMFormatDescriptionGetMediaSubType(format), kCMVideoCodecType_HEVC, "\(name) : HEVC")
            XCTAssertEqual(Int(size.width), Int((info.rect.width * MikaArt.pixelsPerUnit).rounded()), "\(name) : largeur")
            XCTAssertEqual(Int(size.height), Int((info.rect.height * MikaArt.pixelsPerUnit).rounded()), "\(name) : hauteur")
            if let mood = MikaMood.allCases.first(where: { $0.clip == name }) {
                XCTAssertEqual(info.duration, mood.duration, accuracy: 0.1, "\(name) : durée")
            }
        }
        XCTAssertNil(MikaMood.idle.clip)
        XCTAssertNil(MikaMood.shake.clip)
    }

    /// Les poses fixes, la tête de l'avatar, et la première image de chaque vidéo, à la taille
    /// exacte de la vidéo (elle la remplace au pixel près pendant que le décodeur démarre).
    func testEveryStillAndPosterExists() throws {
        for still in MikaStill.allCases {
            XCTAssertNotNil(UIImage(named: still.imageName), "\(still.imageName) manque au catalogue")
            XCTAssertNotNil(MikaArt.stills[still.rawValue], "\(still.rawValue) sans cadre")
        }
        XCTAssertNotNil(UIImage(named: "Mika-tete"))
        for (name, info) in MikaArt.clips {
            let poster = try XCTUnwrap(UIImage(named: "Mika-clip-\(name)"), "Mika-clip-\(name) manque")
            XCTAssertEqual(poster.size.width * poster.scale, info.rect.width * MikaArt.pixelsPerUnit, accuracy: 1, "\(name) : largeur de la première image")
            XCTAssertEqual(poster.size.height * poster.scale, info.rect.height * MikaArt.pixelsPerUnit, accuracy: 1, "\(name) : hauteur de la première image")
        }
    }

    /// Seules la réflexion et l'écriture bouclent : l'attente d'une génération. Les gestes
    /// joyeux finissent sur un sourire.
    func testOnlyWaitingLoopsAndGesturesEndSmiling() {
        XCTAssertEqual(Set(MikaMood.allCases.filter(\.loops)), [.think, .write])
        for mood in [MikaMood.wave, .happy, .celebrate, .wink, .surprise, .appear, .look] {
            XCTAssertEqual(mood.afterglow, .smile, "\(mood) devrait finir sur un sourire")
        }
        XCTAssertNil(MikaMood.sad.afterglow)
    }

    /// Sous XCTest, les vues de Mika n'animent rien : les rendus restent des images.
    func testTestsUseStills() {
        XCTAssertTrue(MikaLibrary.isRunningTests)
    }

    /// **Le décodage, mesuré** : chaque vidéo, lue en mémoire puis décodée image par image comme
    /// le fait le lecteur, avec sa transparence (le tour transparent, Mika opaque au milieu).
    /// Les chiffres partent dans le journal (`MIKA-PERF`) et en image (`mika-perf`) ; les
    /// images décodées, sur la crème et le graphite, dans `mika-video-frames`.
    @MainActor
    func testVideosDecodeWithAlphaAndFast() throws {
        var lines: [String] = []
        var totalRead = 0.0, totalDecode = 0.0, totalFrames = 0, totalBytes = 0
        var shots: [(String, [CGImage])] = []
        for name in MikaClipStore.warmOrder {
            let cold = CFAbsoluteTimeGetCurrent()
            _ = try XCTUnwrap(readOffMain(name))
            let first = (CFAbsoluteTimeGetCurrent() - cold) * 1000
            let start = CFAbsoluteTimeGetCurrent()
            let clip = try XCTUnwrap(readOffMain(name))
            let read = (CFAbsoluteTimeGetCurrent() - start) * 1000
            let decoded = try decodeAll(name)
            XCTAssertEqual(decoded.count, clip.samples.count, "\(name) : images décodées")
            let middle = decoded.images[decoded.images.count / 2]
            XCTAssertTrue(alpha(middle, atX: 0.5, y: 0.55) > 200, "\(name) : Mika n'est pas opaque au milieu")
            XCTAssertTrue(alpha(middle, atX: 0.01, y: 0.01) < 10, "\(name) : le coin n'est pas transparent")
            totalRead += read
            totalDecode += decoded.milliseconds
            totalFrames += decoded.count
            totalBytes += clip.bytes
            shots.append((name, decoded.images))
            lines.append(String(format: "%@ : %d images, %d Ko, lue %.0f ms (1re fois %.0f), décodée %.1f ms/image",
                                name, clip.samples.count, clip.bytes / 1024, read, first, decoded.milliseconds / Double(decoded.count)))
        }
        lines.append(String(format: "Total : %d images, %d Ko en mémoire, lecture %.0f ms (une fois, en tâche de fond), décodage %.1f ms/image (budget d'une image à 24 i/s : 41,7 ms)",
                            totalFrames, totalBytes / 1024, totalRead, totalDecode / Double(totalFrames)))
        lines.append(contentsOf: Self.playerLines)
        lines.forEach { print("MIKA-PERF \($0)") }
        guard RenderGallery.directory != nil else { return }
        do {
            try RenderGallery.render("mika-perf", VStack(alignment: .leading, spacing: 6) {
                Text("Vidéos HEVC avec alpha : lues une fois hors du fil principal, décodées image par image (simulateur)")
                    .font(.system(size: 13, weight: .bold))
                ForEach(lines, id: \.self) { Text($0).font(.system(size: 11, design: .monospaced)) }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading))
            try RenderGallery.render("mika-video-frames", width: 393, night: true, VStack(spacing: 6) {
                ForEach(shots, id: \.0) { shot in
                    HStack(spacing: 4) {
                        ForEach(Array(shot.1.enumerated()), id: \.offset) { item in
                            Image(decorative: item.element, scale: 1)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70, height: 70)
                        }
                    }
                }
            }
            .padding(12))
        }
    }

    /// Le cache : la seconde demande ne relit rien, et la réponse arrive sur le fil principal.
    func testLoadingTwiceReadsOnce() throws {
        let first = expectation(description: "première")
        var clip: MikaClip?
        MikaClipStore.load("saut") { loaded in
            XCTAssertTrue(Thread.isMainThread)
            clip = loaded
            first.fulfill()
        }
        wait(for: [first], timeout: 10)
        XCTAssertNotNil(clip)
        let second = expectation(description: "seconde")
        let start = CFAbsoluteTimeGetCurrent()
        MikaClipStore.load("saut") { loaded in
            XCTAssertTrue(loaded === clip, "la seconde demande a relu la vidéo")
            second.fulfill()
        }
        wait(for: [second], timeout: 1)
        print(String(format: "MIKA-PERF cache %.2f ms", (CFAbsoluteTimeGetCurrent() - start) * 1000))
        XCTAssertNotNil(MikaClipStore.cached("saut"))
    }

    /// **Le lecteur, à l'écran** : un vrai `MikaPlayerView` dans une fenêtre joue le coucou ;
    /// le temps entre la demande et la première image qui bouge est mesuré ; l'écran est
    /// photographié pendant la lecture, sur un fond rouge vif (la transparence doit laisser voir
    /// le rouge autour de Mika) — `mika-player`.
    @MainActor
    func testPlayerStartsFastAndKeepsAlpha() throws {
        let window = try makeWindow()
        defer { window.isHidden = true }
        let host = UIView(frame: window.bounds)
        host.backgroundColor = .systemRed
        window.addSubview(host)
        let player = MikaPlayerView(frame: CGRect(x: 40, y: 40, width: 240, height: 240))
        host.addSubview(player)
        player.placement = .standing(side: 240)
        var started = false
        player.onEvent = { if case .started = $0 { started = true } }
        // Lu d'avance, comme après `warm()` au premier Mika affiché.
        var ready = false
        MikaClipStore.load("coucou") { _ in ready = true }
        try waitUntil("le coucou ne se lit pas") { ready }
        let before = MikaPerf.startLatencies.count
        player.apply(MikaPlayRequest(clip: "coucou", loops: false, take: 1, mood: .wave))
        try waitUntil("le coucou ne démarre pas") { started }
        let latency = try XCTUnwrap(MikaPerf.startLatencies.dropFirst(before).first)
        let line = String(format: "Lecteur : du geste demandé à la première image qui bouge, %.0f ms (dont %.0f ms laissés au décodeur)", latency * 1000, MikaPlayerView.decodeLead * 1000)
        print("MIKA-PERF \(line)")
        Self.playerLines.append(line)
        XCTAssertLessThan(latency, 0.25, "le coucou met trop longtemps à démarrer")
        // Au milieu du geste.
        RunLoop.main.run(until: Date().addingTimeInterval(0.9))
        let shot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        if RenderGallery.directory != nil {
            try RenderGallery.render("mika-player", width: 320, height: 320, Image(uiImage: shot).resizable().scaledToFit())
        }
        try waitUntil("le coucou ne finit pas", timeout: 4) { !player.isPlaying }
        player.removeFromSuperview()
    }

    /// **Un seul Mika joue à la fois** : le second qui commence arrête le premier.
    @MainActor
    func testOnlyOneMikaPlaysAtOnce() throws {
        let window = try makeWindow()
        defer { window.isHidden = true }
        let one = MikaPlayerView(frame: CGRect(x: 0, y: 0, width: 120, height: 120))
        let two = MikaPlayerView(frame: CGRect(x: 0, y: 200, width: 120, height: 120))
        window.addSubview(one)
        window.addSubview(two)
        one.placement = .standing(side: 120)
        two.placement = .standing(side: 120)

        one.apply(MikaPlayRequest(clip: "reflexion", loops: true, take: 1, mood: .think))
        try waitUntil("le premier ne joue pas") { one.isPlaying }
        two.apply(MikaPlayRequest(clip: "ecriture", loops: true, take: 1, mood: .write))
        try waitUntil("le second n'a pas arrêté le premier") { two.isPlaying && !one.isPlaying }
        XCTAssertTrue(MikaStage.shared.isPlaying)

        // Quitter l'écran arrête la lecture.
        two.removeFromSuperview()
        try waitUntil("hors de l'écran, il joue encore") { !two.isPlaying }
        one.removeFromSuperview()
    }

    // MARK: - Outils

    @MainActor
    private func makeWindow() throws -> UIWindow {
        let state = UIApplication.shared.applicationState
        guard state != .background else {
            throw XCTSkip("l'app des tests est en arrière-plan : Mika n'y joue pas, c'est voulu")
        }
        // Une vraie fenêtre de la scène de l'app : sans elle, rien ne s'affiche.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        window.isHidden = false
        return window
    }

    private func readOffMain(_ name: String) -> MikaClip? {
        var result: MikaClip?
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .userInitiated).async {
            result = MikaClipStore.read(name)
            done.signal()
        }
        done.wait()
        return result
    }

    /// Décode toute la vidéo en BGRA (le chemin du décodeur matériel), en mesurant le temps
    /// par image ; garde trois images (début, milieu, fin) en CGImage prémultipliée.
    private func decodeAll(_ name: String) throws -> (count: Int, milliseconds: Double, images: [CGImage]) {
        let url = try XCTUnwrap(MikaLibrary.url(for: name))
        let asset = AVURLAsset(url: url)
        let loaded = DispatchSemaphore(value: 0)
        var track: AVAssetTrack?
        asset.loadTracks(withMediaType: .video) { tracks, _ in
            track = tracks?.first
            loaded.signal()
        }
        loaded.wait()
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: try XCTUnwrap(track), outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()
        var buffers: [CVPixelBuffer] = []
        var count = 0
        let start = CFAbsoluteTimeGetCurrent()
        var all: [CVPixelBuffer] = []
        while let sample = output.copyNextSampleBuffer() {
            if let buffer = CMSampleBufferGetImageBuffer(sample) {
                all.append(buffer)
                count += 1
            }
            if all.count > 3 { all.removeFirst() }
            if count == 1 || count == 18 { buffers.append(all.last!) }
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        if let last = all.last { buffers.append(last) }
        let images = buffers.compactMap(cgImage)
        return (count, elapsed, images)
    }

    private func cgImage(_ buffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              let context = CGContext(
                  data: base, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer),
                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
              )
        else { return nil }
        return context.makeImage()
    }

    private func alpha(_ image: CGImage, atX x: CGFloat, y: CGFloat) -> UInt8 {
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        let width = CGFloat(image.width), height = CGFloat(image.height)
        context.draw(image, in: CGRect(x: -x * width, y: -(1 - y) * height, width: width, height: height))
        return pixel[3]
    }

    @MainActor
    private func waitUntil(_ what: String, timeout: TimeInterval = 5, _ condition: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return XCTFail(what) }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
