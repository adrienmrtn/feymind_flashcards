// **Les animations de Mika en vidéo HEVC avec alpha** — sur macOS seulement (l'encodeur HEVC
// avec alpha de VideoToolbox n'existe pas ailleurs) : `.github/workflows/mika-encode.yml` le
// lance après `scripts/mika-assets.py`.
//
//     swiftc -O -o mika-encode scripts/mika-encode.swift
//     ./mika-encode <images> <sortie> <contrôle>
//
// - `<images>` : ce qu'écrit `mika-assets.py --frames` — `clips.json` et, par animation, ses
//   images PNG traitées et rognées (`<nom>/0000.png…`) ;
// - `<sortie>` : `Micabo/Resources/Mika`, où vont les `mika-<nom>.mov` ;
// - `<contrôle>` : chaque vidéo y est **relue** et comparée à ses images (écart moyen et
//   maximal, image par image), le temps de décodage mesuré ; `rapport.json`, `rapport.txt` et
//   une planche par animation (début, milieu, fin, sur la crème du jour et le graphite de la
//   nuit) pour regarder le résultat.
//
// La vidéo : HEVC avec alpha (`hevcWithAlpha`), alpha **prémultiplié** (ce que Core Animation
// attend), 24 images par seconde, une image clé au début et aucune réorganisation d'images
// (l'ordre de décodage est l'ordre d'affichage), couleurs sRGB.

import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import UniformTypeIdentifiers
import VideoToolbox

struct ClipInfo: Codable {
    let name: String
    let fps: Int
    let frames: Int
    let width: Int
    let height: Int
}

struct Check: Codable {
    let name: String
    let frames: Int
    let width: Int
    let height: Int
    let bytes: Int
    let encodeSeconds: Double
    let decodeMillisecondsPerFrame: Double
    let meanError: Double
    let maxMeanErrorPerFrame: Double
    let alphaMeanError: Double
    let readsPremultiplied: Bool
}

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage : mika-encode <images> <sortie> <contrôle>")
    exit(2)
}
let framesDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let checkDir = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: checkDir, withIntermediateDirectories: true)

let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fatalError("illisible : \(url.path)") }
    return image
}

/// Les octets BGRA prémultipliés d'une image, à sa taille.
func pixels(_ image: CGImage, width: Int, height: Int) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    data.withUnsafeMutableBytes { raw in
        let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: srgb, bitmapInfo: bitmapInfo)!
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return data
}

func outputSettings(_ clip: ClipInfo, writer: AVAssetWriter) -> [String: Any] {
    var compression: [String: Any] = [
        AVVideoQualityKey: 0.92,
        AVVideoExpectedSourceFrameRateKey: clip.fps,
        AVVideoMaxKeyFrameIntervalKey: clip.frames,
        AVVideoAllowFrameReorderingKey: false,
        kVTCompressionPropertyKey_TargetQualityForAlpha as String: 0.95,
        kVTCompressionPropertyKey_AlphaChannelMode as String: kVTAlphaChannelMode_PremultipliedAlpha,
    ]
    let base: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.hevcWithAlpha,
        AVVideoWidthKey: clip.width,
        AVVideoHeightKey: clip.height,
    ]
    let colors: [[String: Any]] = [
        [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
         AVVideoTransferFunctionKey: "IEC_sRGB",
         AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
        [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
         AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
         AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
    ]
    // Du plus précis au plus simple : la première combinaison que l'encodeur accepte.
    for color in colors {
        for attempt in 0..<3 {
            var settings = base
            var c = compression
            if attempt >= 1 { c.removeValue(forKey: kVTCompressionPropertyKey_TargetQualityForAlpha as String) }
            if attempt >= 2 { c.removeValue(forKey: AVVideoQualityKey) }
            settings[AVVideoCompressionPropertiesKey] = c
            settings[AVVideoColorPropertiesKey] = color
            if writer.canApply(outputSettings: settings, forMediaType: .video) {
                print("  réglages : couleur \(color[AVVideoTransferFunctionKey]!), essai \(attempt)")
                return settings
            }
        }
    }
    compression.removeAll()
    fatalError("l'encodeur refuse HEVC avec alpha")
}

func encode(_ clip: ClipInfo) throws -> Double {
    let start = Date()
    let url = outDir.appendingPathComponent("mika-\(clip.name).mov")
    try? FileManager.default.removeItem(at: url)
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings(clip, writer: writer))
    input.expectsMediaDataInRealTime = false
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: clip.width,
        kCVPixelBufferHeightKey as String: clip.height,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
    ])
    writer.add(input)
    guard writer.startWriting() else { throw writer.error ?? NSError(domain: "mika", code: 1) }
    writer.startSession(atSourceTime: .zero)
    for index in 0..<clip.frames {
        while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
        let image = loadImage(framesDir.appendingPathComponent(clip.name).appendingPathComponent(String(format: "%04d.png", index)))
        guard let pool = adaptor.pixelBufferPool else { throw writer.error ?? NSError(domain: "mika", code: 2) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { throw NSError(domain: "mika", code: 3) }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: clip.width, height: clip.height,
                                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                space: srgb, bitmapInfo: bitmapInfo)!
        context.clear(CGRect(x: 0, y: 0, width: clip.width, height: clip.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: clip.width, height: clip.height))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        CVBufferSetAttachment(buffer, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_sRGB, .shouldPropagate)
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: CMTimeScale(clip.fps))) else {
            throw writer.error ?? NSError(domain: "mika", code: 4)
        }
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
    if writer.status != .completed { throw writer.error ?? NSError(domain: "mika", code: 5) }
    return Date().timeIntervalSince(start)
}

/// Relit la vidéo et la compare à ses images.
func verify(_ clip: ClipInfo, encodeSeconds: Double) throws -> (Check, [CGImage]) {
    let url = outDir.appendingPathComponent("mika-\(clip.name).mov")
    let asset = AVURLAsset(url: url)
    let semaphore = DispatchSemaphore(value: 0)
    var track: AVAssetTrack?
    asset.loadTracks(withMediaType: .video) { tracks, _ in
        track = tracks?.first
        semaphore.signal()
    }
    semaphore.wait()
    guard let track else { throw NSError(domain: "mika", code: 6, userInfo: [NSLocalizedDescriptionKey: "\(clip.name) : pas de piste vidéo"]) }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ])
    output.alwaysCopiesSampleData = false
    reader.add(output)
    reader.startReading()
    var count = 0
    var total = 0.0, worst = 0.0, alphaTotal = 0.0
    var premultipliedVotes = 0
    var decodeTime = 0.0
    var keep: [CGImage] = []
    let picks = Set([0, clip.frames / 2, clip.frames - 1])
    while true {
        let t0 = Date()
        guard let sample = output.copyNextSampleBuffer() else { break }
        decodeTime += Date().timeIntervalSince(t0)
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let row = CVPixelBufferGetBytesPerRow(buffer)
        let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        if count < clip.frames {
            let source = pixels(loadImage(framesDir.appendingPathComponent(clip.name).appendingPathComponent(String(format: "%04d.png", count))), width: width, height: height)
            var errorPremultiplied = 0.0, errorStraight = 0.0, errorAlpha = 0.0
            for y in Swift.stride(from: 0, to: height, by: 2) {
                for x in Swift.stride(from: 0, to: width, by: 2) {
                    let o = y * row + x * 4
                    let s = (y * width + x) * 4
                    let a = Double(base[o + 3])
                    errorAlpha += abs(a - Double(source[s + 3]))
                    for c in 0..<3 {
                        let v = Double(base[o + c])
                        errorPremultiplied += abs(v - Double(source[s + c]))
                        errorStraight += abs(v * a / 255 - Double(source[s + c]))
                    }
                }
            }
            let samples = Double(((height + 1) / 2) * ((width + 1) / 2))
            let e = min(errorPremultiplied, errorStraight) / samples / 3
            if errorPremultiplied <= errorStraight { premultipliedVotes += 1 }
            total += e
            worst = max(worst, e)
            alphaTotal += errorAlpha / samples
        }
        if picks.contains(count) {
            let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: srgb, bitmapInfo: bitmapInfo)!
            let dest = context.data!.assumingMemoryBound(to: UInt8.self)
            let destRow = context.bytesPerRow
            let straight = premultipliedVotes * 2 < (count + 1)
            for y in 0..<height {
                for x in 0..<width {
                    let o = y * row + x * 4, d = y * destRow + x * 4
                    let a = base[o + 3]
                    dest[d + 3] = a
                    for c in 0..<3 {
                        dest[d + c] = straight ? UInt8(Int(base[o + c]) * Int(a) / 255) : min(base[o + c], a)
                    }
                }
            }
            keep.append(context.makeImage()!)
        }
        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
        count += 1
    }
    guard reader.status == .completed else { throw reader.error ?? NSError(domain: "mika", code: 7) }
    let bytes = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    let check = Check(
        name: clip.name, frames: count, width: clip.width, height: clip.height, bytes: bytes,
        encodeSeconds: encodeSeconds,
        decodeMillisecondsPerFrame: decodeTime * 1000 / Double(max(1, count)),
        meanError: total / Double(max(1, count)), maxMeanErrorPerFrame: worst,
        alphaMeanError: alphaTotal / Double(max(1, count)),
        readsPremultiplied: premultipliedVotes * 2 >= count
    )
    return (check, keep)
}

func sheet(_ name: String, _ images: [CGImage]) {
    guard let first = images.first else { return }
    let cell = CGSize(width: first.width, height: first.height)
    let backgrounds: [CGColor] = [
        CGColor(srgbRed: 0.965, green: 0.957, blue: 0.929, alpha: 1),
        CGColor(srgbRed: 0.110, green: 0.118, blue: 0.141, alpha: 1),
        CGColor(srgbRed: 0.212, green: 0.455, blue: 0.992, alpha: 1),
    ]
    let width = Int(cell.width) * images.count, height = Int(cell.height) * backgrounds.count
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: srgb, bitmapInfo: bitmapInfo)!
    for (row, color) in backgrounds.enumerated() {
        context.setFillColor(color)
        let y = CGFloat(backgrounds.count - 1 - row) * cell.height
        context.fill(CGRect(x: 0, y: y, width: CGFloat(width), height: cell.height))
        for (column, image) in images.enumerated() {
            context.draw(image, in: CGRect(x: CGFloat(column) * cell.width, y: y, width: cell.width, height: cell.height))
        }
    }
    let url = checkDir.appendingPathComponent("planche-\(name).png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    CGImageDestinationFinalize(destination)
}

let clips = try JSONDecoder().decode([ClipInfo].self, from: Data(contentsOf: framesDir.appendingPathComponent("clips.json")))
var checks: [Check] = []
var failed = false
for clip in clips {
    print("\(clip.name) : \(clip.frames) images \(clip.width)x\(clip.height)")
    let seconds = try encode(clip)
    let (check, images) = try verify(clip, encodeSeconds: seconds)
    sheet(clip.name, images)
    checks.append(check)
    let line = String(format: "  %d Ko, %d images relues, écart moyen %.2f (pire image %.2f) sur 255, alpha %.2f, décodage %.2f ms/image, %@",
                      check.bytes / 1024, check.frames, check.meanError, check.maxMeanErrorPerFrame, check.alphaMeanError,
                      check.decodeMillisecondsPerFrame, check.readsPremultiplied ? "relu prémultiplié" : "relu non prémultiplié")
    print(line)
    // Une vidéo qui perd des images, ou qui s'écarte visiblement de ses images, ne part pas.
    if check.frames != clip.frames || check.meanError > 4 || check.alphaMeanError > 4 {
        print("  ÉCHEC : \(clip.name) ne ressemble pas à ses images")
        failed = true
    }
}
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try encoder.encode(checks).write(to: checkDir.appendingPathComponent("rapport.json"))
let total = checks.reduce(0) { $0 + $1.bytes }
let summary = checks.map {
    String(format: "%@ : %d images %dx%d, %d Ko, écart %.2f/255, alpha %.2f, décodage %.2f ms/image",
           $0.name, $0.frames, $0.width, $0.height, $0.bytes / 1024, $0.meanError, $0.alphaMeanError, $0.decodeMillisecondsPerFrame)
}.joined(separator: "\n") + "\nTotal : \(total / 1024) Ko\n"
try summary.write(to: checkDir.appendingPathComponent("rapport.txt"), atomically: true, encoding: .utf8)
print(summary)
exit(failed ? 1 : 0)
