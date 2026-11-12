import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Mika, dessiné dans le code** (lot 10, après le build 173 : « la mascotte est pas belle »,
/// « pas fluide ») : un personnage plat et vectoriel, dont chaque humeur est une pose — un
/// vecteur de nombres que SwiftUI interpole. Ces tests tiennent ce qui ne se voit pas dans un
/// rendu : chaque humeur a sa pose et son geste, deux poses qui se suivent s'interpolent sans
/// que rien ne se déforme, aucun geste ne le déplace ni ne le fait monter, un seul Mika bouge à
/// la fois, rien ne tourne hors écran — et le dessin est celui de la maquette.
final class MikaMascotTests: XCTestCase {
    // MARK: - Les poses

    /// Chaque humeur a sa pose (les douze expressions de la maquette, plus « non » et
    /// l'arrivée qui en reprennent une), un geste, et une scène à dessiner.
    func testEveryMoodHasAPose() {
        for mood in MikaMood.allCases {
            let pose = mood.pose
            XCTAssertEqual(pose.values.count, MikaPose.count, "\(mood)")
            XCTAssertTrue(pose.values.allSatisfy(\.isFinite), "\(mood)")
            XCTAssertFalse(mood.beats.isEmpty, "\(mood) n'a pas de geste")
            XCTAssertEqual(mood.rest.values.count, MikaPose.count, "\(mood)")
            XCTAssertGreaterThanOrEqual(MikaArt.scene(pose).count, 12, "\(mood) : il manque des pièces")
        }
        let expressions = MikaMockup.expressions.map(\.pose)
        for (index, pose) in expressions.enumerated() {
            for other in expressions[(index + 1)...] {
                XCTAssertNotEqual(pose, other, "deux expressions de la maquette se confondent")
            }
        }
        XCTAssertEqual(MikaMood.shake.pose, MikaPose.sad)
        XCTAssertEqual(MikaMood.appear.pose, MikaPose.idle)
    }

    /// Les nombres des poses sont ceux de la table `set` de la maquette.
    func testThePosesAreTheMockupOnes() {
        let idle = MikaPose.idle
        XCTAssertEqual(idle.eyeOpen, 1)
        XCTAssertEqual(idle.mouthCurve, 1)
        XCTAssertEqual(idle.pencilAngle, 14)
        XCTAssertEqual(idle.sparkX, 320)
        XCTAssertEqual(idle.sparkY, 44)
        assertPoint(idle.leftArm.hand, 76, 316, "la main gauche au repos")
        assertPoint(idle.rightArm.hand, 346, 192, "la main du crayon")

        XCTAssertEqual(MikaPose.happy.eyeHappy, 1)
        XCTAssertEqual(MikaPose.happy.mouthOpen, 1)
        assertPoint(MikaPose.wave.leftArm.hand, 64, 122, "la main du coucou")
        XCTAssertEqual(MikaPose.wink.eyeWink, 1)

        let party = MikaPose.celebrate
        assertPoint(party.leftArm.hand, 74, 96, "le bras gauche de la fête")
        assertPoint(party.rightArm.hand, 326, 96, "le bras droit de la fête")
        XCTAssertEqual(party.pencilAngle, -12)
        XCTAssertEqual(party.sparkX, 372)
        XCTAssertEqual(party.sparkY, 30)
        XCTAssertEqual(party.confetti, 1)

        XCTAssertEqual(MikaPose.think.pupilX, 8)
        XCTAssertEqual(MikaPose.think.pupilY, -13)
        XCTAssertEqual(MikaPose.think.dots, 1)
        XCTAssertEqual(MikaPose.think.spark, 0)
        XCTAssertEqual(MikaPose.write.pencilAngle, -24)
        XCTAssertEqual(MikaPose.write.pencilPivot, 0)
        XCTAssertEqual(MikaPose.write.lines, 1)
        XCTAssertEqual(MikaPose.surprise.eyeWide, 1)
        XCTAssertEqual(MikaPose.surprise.mouthRound, 1)
        XCTAssertEqual(MikaPose.sad.mouthCurve, -1)
        XCTAssertEqual(MikaPose.sad.pencil, 0)
        assertPoint(MikaPose.sad.rightArm.hand, 324, 316, "le bras droit rangé")
        XCTAssertEqual(MikaPose.sleep.eyeOpen, 0)
        XCTAssertEqual(MikaPose.sleep.zzz, 1)
        XCTAssertEqual(MikaPose.look.pupilX, 10)
        XCTAssertEqual(MikaPose.proud.eyeHappy, 1)
        assertPoint(MikaPose.proud.rightArm.hand, 326, 96, "le crayon levé")
    }

    /// Le dessin, pièce par pièce : la tête, les yeux, les joues, la bouche et le crayon
    /// tombent aux coordonnées de la maquette.
    func testThePiecesFallWhereTheMockupPutsThem() throws {
        let idle = MikaArt.scene(.idle)
        XCTAssertEqual(idle.filter { $0.part == .back }.count, 2)
        XCTAssertEqual(idle.filter { $0.part == .limb }.count, 3)
        XCTAssertEqual(idle.filter { $0.part == .pencil }.count, 4, "le corps, la gomme, le bois, la mine")
        XCTAssertEqual(idle.filter { $0.part == .lid }.count, 0, "au repos, les yeux sont ouverts")
        XCTAssertNil(idle.first { $0.part == .shadow }, "l'ombre au sol est une option")
        XCTAssertEqual(MikaArt.scene(.idle, shadow: true).first?.part, .shadow)

        assertRect(try XCTUnwrap(idle.first { $0.part == .head }).path.cgPath.boundingBoxOfPath, 74, 44, 252, 244, "la tête")
        let eyes = idle.filter { $0.part == .eye }.map(\.path.cgPath.boundingBoxOfPath)
        XCTAssertEqual(eyes.count, 2)
        assertRect(eyes[0], 130, 132, 56, 68, "l'œil gauche")
        assertRect(eyes[1], 214, 132, 56, 68, "l'œil droit")
        let pupils = idle.filter { $0.part == .pupil }.map(\.path.cgPath.boundingBoxOfPath)
        assertRect(pupils[0], 148, 153, 30, 38, "la pupille gauche, tournée vers le nez")
        assertRect(pupils[1], 222, 153, 30, 38, "la pupille droite")
        let cheeks = idle.filter { $0.part == .cheek }.map(\.path.cgPath.boundingBoxOfPath)
        assertRect(cheeks[0], 98, 201, 36, 22, "la joue gauche")
        assertRect(cheeks[1], 266, 201, 36, 22, "la joue droite")

        // Le sourire : de (184, 212) à (216, 212), creusé jusqu'à 220.
        let smile = MikaArt.mouthShape(for: .idle)
        assertRect(smile.path.cgPath.boundingBoxOfPath, 184, 212, 32, 8, "le sourire")
        XCTAssertEqual(smile.lineWidth, 7, accuracy: 0.001)
        XCTAssertEqual(smile.tongue, 0, accuracy: 0.001)
        // La bouche ouverte : 178…222, de 207 à 240, sans trait, la langue au fond.
        let open = MikaArt.mouthShape(for: .happy)
        assertRect(open.path.cgPath.boundingBoxOfPath, 178, 207, 44, 33, "la bouche ouverte")
        XCTAssertEqual(open.lineWidth, 0, accuracy: 0.001)
        XCTAssertEqual(open.tongue, 1, accuracy: 0.001)
        // La bouche ronde : une ellipse de 11 × 14 autour de (200, 220).
        assertRect(MikaArt.mouthShape(for: .surprise).path.cgPath.boundingBoxOfPath, 189, 206, 22, 28, "la bouche ronde", accuracy: 0.6)
        // La tristesse : les coins plus bas que le milieu.
        assertRect(MikaArt.mouthShape(for: .sad).path.cgPath.boundingBoxOfPath, 186, 217, 28, 7, "la bouche triste")

        // Les yeux rieurs : plus d'ellipse blanche, deux arcs d'encre de 44 de large.
        let happy = MikaArt.scene(.happy)
        XCTAssertEqual(happy.filter { $0.part == .eye }.count, 0)
        let arcs = happy.filter { $0.part == .lid }
        XCTAssertEqual(arcs.count, 2)
        assertRect(arcs[0].path.cgPath.boundingBoxOfPath, 136, 161, 44, 15, "l'arc rieur gauche")
        XCTAssertEqual(arcs[0].lineWidth, 9, accuracy: 0.001)
        // Le sommeil : deux arcs courbés vers le bas.
        let asleep = MikaArt.scene(.sleep).filter { $0.part == .lid }
        assertRect(asleep[0].path.cgPath.boundingBoxOfPath, 138, 172, 40, 6, "la paupière du sommeil")
        XCTAssertEqual(asleep[0].lineWidth, 8, accuracy: 0.001)
        // Le clin d'œil : l'œil gauche ouvert, le droit en arc.
        let wink = MikaArt.scene(.wink)
        XCTAssertEqual(wink.filter { $0.part == .eye }.count, 1)
        XCTAssertEqual(wink.filter { $0.part == .lid }.count, 1)

        // La mine du crayon, au repos : vers (367, 67), une fois le crayon penché de 14°.
        let lead = try XCTUnwrap(idle.last { $0.part == .pencil }).path.cgPath.boundingBoxOfPath
        XCTAssertEqual(lead.maxX, 368.3, accuracy: 1.5)
        XCTAssertEqual(lead.minY, 66.6, accuracy: 1.5)
        // Sans crayon : ni crayon ni poing.
        let sad = MikaArt.scene(.sad)
        XCTAssertEqual(sad.filter { $0.part == .pencil || $0.part == .fist || $0.part == .spark }.count, 0)
        XCTAssertEqual(MikaArt.scene(.face).filter { $0.part == .pencil }.count, 0, "l'avatar n'a pas de crayon")
    }

    /// Les couleurs : le corps est l'accent de l'app, plus clair sur le marine ; le reste ne
    /// change pas d'un thème à l'autre.
    func testColorsFollowTheTheme() {
        XCTAssertEqual(MikaPalette.marine.body, MikaTint(hex: 0x5C88FF))
        XCTAssertEqual(MikaPalette.marine.shade, MikaTint(hex: 0x3F6BE8))
        XCTAssertEqual(MikaPalette.light.body, MikaTint(hex: 0x3870FE))
        XCTAssertEqual(MikaPalette.light.shade, MikaTint(hex: 0x2A5BE0))
        XCTAssertEqual(MikaPalette.resolved(night: true), .marine)
        XCTAssertEqual(MikaPalette.resolved(night: false), .light)
        for palette in [MikaPalette.marine, .light] {
            XCTAssertEqual(palette.ink, MikaTint(hex: 0x14182B))
            XCTAssertEqual(palette.cheek, MikaTint(hex: 0xFF8FA8, opacity: 0.8))
            XCTAssertEqual(palette.pencil, MikaTint(hex: 0xF7B41F))
            XCTAssertEqual(palette.eraser, MikaTint(hex: 0xE3596C))
            XCTAssertEqual(palette.wood, MikaTint(hex: 0xF6DDB6))
            XCTAssertEqual(palette.spark, MikaTint(hex: 0xF7B41F))
            XCTAssertEqual(palette.shine, MikaTint(hex: 0xFFFFFF, opacity: 0.26))
        }
        let scene = MikaArt.scene(.idle, palette: .marine)
        XCTAssertEqual(scene.first { $0.part == .head }?.fill, MikaPalette.marine.body)
        XCTAssertEqual(scene.first { $0.part == .back }?.stroke, MikaPalette.marine.shade)
    }

    // MARK: - Le vecteur

    /// Une pose est un vecteur : c'est ce qui permet à SwiftUI de passer de l'une à l'autre.
    func testAPoseIsAVector() {
        let a = MikaPose.idle
        let b = MikaPose.celebrate
        XCTAssertEqual(MikaPose.zero + a, a)
        XCTAssertEqual((a - a).magnitudeSquared, 0)
        XCTAssertEqual(MikaPose.between(a, b, 0), a)
        assertClose(MikaPose.between(a, b, 1), b)
        var half = b - a
        half.scale(by: 0.5)
        assertClose(a + half, MikaPose.between(a, b, 0.5))
        XCTAssertGreaterThan((b - a).magnitudeSquared, 0)
    }

    /// **Les poses qui s'enchaînent sont interpolables** : entre deux temps d'un geste (et
    /// d'une humeur à n'importe quelle autre), la pose du milieu se dessine, et le bras tourne
    /// autour de l'épaule sans se raccourcir.
    func testSuccessivePosesInterpolate() {
        var pairs: [(MikaPose, MikaPose, String)] = []
        for mood in MikaMood.allCases {
            let chain = everyPose(of: mood)
            for (from, to) in zip(chain, chain.dropFirst()) {
                pairs.append((from, to, "\(mood)"))
            }
            for other in MikaMood.allCases where other != mood {
                pairs.append((mood.rest, other.beats[0].pose, "\(mood) → \(other)"))
            }
        }
        for (from, to, name) in pairs {
            for t in [0.25, 0.5, 0.75] {
                let middle = MikaPose.between(from, to, t)
                XCTAssertTrue(middle.values.allSatisfy(\.isFinite), name)
                for (arm, a, b) in [(middle.leftArm, from.leftArm, to.leftArm), (middle.rightArm, from.rightArm, to.rightArm)] {
                    let shortest = min(span(a), span(b))
                    XCTAssertGreaterThanOrEqual(span(arm), shortest - 0.5, "\(name) : le bras se raccourcit en route")
                }
                let pieces = MikaArt.scene(middle)
                XCTAssertGreaterThanOrEqual(pieces.count, 12, name)
                for piece in pieces {
                    let box = MikaArt.bounds(of: piece, pose: middle)
                    XCTAssertFalse(box.isNull || box.isInfinite, name)
                    XCTAssertTrue(box.minX > -200 && box.maxX < 600 && box.minY > -260 && box.maxY < 420, "\(name) : une pièce part au loin (\(piece.part))")
                }
            }
        }
    }

    /// Un œil se ferme en s'aplatissant : entre ouvert et rieur, le blanc rétrécit pendant que
    /// l'arc apparaît, sans jamais disparaître tous les deux.
    func testAnEyeClosesByFlattening() {
        var lastHeight = CGFloat.greatestFiniteMagnitude
        for step in 0...10 {
            let pose = MikaPose.between(.idle, .happy, Double(step) / 10)
            let pieces = MikaArt.scene(pose)
            let white = pieces.first { $0.part == .eye }?.path.cgPath.boundingBoxOfPath.height ?? 0
            let arc = pieces.first { $0.part == .lid }
            XCTAssertLessThanOrEqual(white, lastHeight + 0.001, "le blanc de l'œil regrandit en se fermant")
            XCTAssertTrue(white > 0 || arc != nil, "à \(step)/10, l'œil a disparu")
            lastHeight = white
        }
        XCTAssertEqual(lastHeight, 0)
    }

    // MARK: - Les gestes

    /// Seules l'écriture et la réflexion tournent en boucle, le temps d'une attente ; leur
    /// boucle part de la pose qui reste, et ne s'y arrête jamais d'elle-même.
    func testOnlyWaitingLoops() throws {
        XCTAssertEqual(Set(MikaMood.allCases.filter(\.loops)), [.think, .write])
        for mood in MikaMood.allCases where mood.loops {
            let loop = try XCTUnwrap(mood.loop)
            XCTAssertEqual(loop.from, mood.rest, "\(mood)")
            XCTAssertNotEqual(loop.to, loop.from, "\(mood)")
        }
        XCTAssertNotEqual(MikaMood.write.loop?.to.pencilAngle, MikaPose.write.pencilAngle, "le crayon oscille")
        XCTAssertNotEqual(MikaMood.think.loop?.to.dotsPulse, MikaPose.think.dotsPulse, "les trois points pulsent")
    }

    /// Les gestes : le coucou lève le bras, le balance deux fois et revient ; la fête lève
    /// les deux bras ; le clin d'œil revient au repos ; la tristesse reste triste.
    func testGesturesSayWhatTheyMean() {
        let wave = MikaMood.wave.beats
        XCTAssertEqual(wave.count, 6)
        XCTAssertEqual(MikaMood.wave.rest, .idle, "le bras revient")
        let hands = wave.dropLast().map { $0.pose.leftArm.hand }
        XCTAssertTrue(hands.allSatisfy { $0.y < 150 }, "le bras gauche est levé pendant tout le coucou")
        XCTAssertLessThan(hands[1].x, hands[2].x, "il balance")
        XCTAssertGreaterThan(hands[2].x, hands[3].x)
        XCTAssertLessThan(hands[3].x, hands[4].x)
        XCTAssertTrue(wave.allSatisfy { $0.pose.rightArm == MikaArm.rightPencil }, "seul le bras gauche salue")

        let party = MikaMood.celebrate
        XCTAssertTrue(party.beats.allSatisfy { $0.pose.leftArm.hand.y < 130 && $0.pose.rightArm.hand.y < 130 }, "les deux bras en l'air")
        XCTAssertTrue(party.beats.allSatisfy { $0.pose.eyeHappy == 1 && $0.pose.mouthOpen == 1 })
        XCTAssertTrue(party.beats.allSatisfy { $0.pose.confetti == 0 }, "en mouvement, les confettis sont la gerbe, pas l'image")
        XCTAssertEqual(party.pose.confetti, 1, "fixe, la fête se lit à ses confettis")
        XCTAssertEqual(MikaMood.confettiSeconds, 1.2, accuracy: 0.001)

        XCTAssertEqual(MikaMood.wink.rest, .idle)
        XCTAssertEqual(MikaMood.wink.beats[0].pose.eyeWink, 1)
        XCTAssertEqual(MikaMood.appear.rest, .idle)
        XCTAssertEqual(MikaMood.sad.rest, .sad)
        XCTAssertEqual(MikaMood.shake.rest, .sad)
        XCTAssertEqual(MikaMood.sleep.rest, .sleep)
        XCTAssertEqual(MikaMood.surprise.rest, .surprise)
        XCTAssertEqual(MikaMood.proud.rest, .proud)
    }

    /// Un geste est court : deux secondes au plus.
    func testGesturesAreShort() {
        for mood in MikaMood.allCases {
            XCTAssertGreaterThan(mood.duration, 0, "\(mood)")
            XCTAssertLessThanOrEqual(mood.duration, 2, "\(mood) : geste trop long")
        }
    }

    /// À l'appui : un écrasement de 3 % et un clin d'œil, puis il revient. Les yeux fermés ou
    /// la bouche triste ne font pas de clin d'œil.
    func testATapSquashesAndWinks() {
        let tap = MikaMood.tapBeats(from: .idle)
        XCTAssertEqual(tap[0].pose.squash, 0.03, accuracy: 0.0001)
        XCTAssertEqual(tap[0].pose.eyeWink, 1)
        XCTAssertEqual(tap.last?.pose, MikaPose.idle)
        XCTAssertTrue(tap.dropFirst().allSatisfy { $0.pose.squash == 0 })
        for rest in [MikaPose.sad, .sleep, .happy] {
            let quiet = MikaMood.tapBeats(from: rest)
            XCTAssertEqual(quiet[0].pose.squash, 0.03, accuracy: 0.0001)
            XCTAssertTrue(quiet.allSatisfy { $0.pose.eyeWink == 0 })
            XCTAssertEqual(quiet.last?.pose, rest)
        }
        let blink = MikaMood.blinkBeats(from: .look)
        XCTAssertEqual(blink.first?.pose.blink, 1)
        XCTAssertEqual(blink.last?.pose, MikaPose.look)
    }

    /// **Aucun geste ne déplace Mika** : ni saut, ni translation. Dans chaque pose de chaque
    /// geste (et à mi-chemin entre deux), un point posé au sol y reste, aucun point du corps ne
    /// monte, l'écrasement ne dépasse pas 3 % et le penché 3 degrés.
    func testNoGestureMovesMikaUpOrDown() {
        for mood in MikaMood.allCases {
            let chain = everyPose(of: mood)
            var poses = chain
            for (from, to) in zip(chain, chain.dropFirst()) {
                poses.append(MikaPose.between(from, to, 0.5))
            }
            for pose in poses {
                let transform = MikaArt.bodyTransform(for: pose)
                XCTAssertEqual(transform.b, 0, accuracy: 0.000001, "\(mood) : le corps tourne")
                for x in [0.0, 134, 200, 266, 400] {
                    let foot = CGPoint(x: x, y: MikaArt.ground).applying(transform)
                    XCTAssertEqual(foot.y, CGFloat(MikaArt.ground), accuracy: 0.0001, "\(mood) : le sol bouge")
                }
                for y in stride(from: 0.0, through: MikaArt.ground, by: 25) {
                    for x in [60.0, 200, 340] {
                        let moved = CGPoint(x: x, y: y).applying(transform)
                        XCTAssertGreaterThanOrEqual(moved.y, CGFloat(y) - 0.0001, "\(mood) : un point monte")
                    }
                }
                let top = CGPoint(x: 200, y: 44).applying(transform)
                XCTAssertLessThanOrEqual(top.y - 44, 10, "\(mood) : il s'écrase de plus de 3 %")
                XCTAssertLessThanOrEqual(abs(top.x - 200), 17, "\(mood) : il se penche trop")
                XCTAssertGreaterThanOrEqual(pose.squash, -0.0001, "\(mood)")
                XCTAssertLessThanOrEqual(pose.squash, 0.0301, "\(mood)")
                XCTAssertLessThanOrEqual(abs(pose.tilt), 3.01, "\(mood)")

                // Ses trois tentacules du bas ne quittent pas le sol.
                let feet = MikaArt.scene(pose).filter { $0.part == .back }.map { MikaArt.bounds(of: $0, pose: pose) }
                for foot in feet {
                    XCTAssertEqual(foot.maxY, 349, accuracy: 0.3, "\(mood) : un pied décolle")
                }
            }
        }
    }

    /// **Aucun Mika ne saute ni ne se déplace dans l'app** : à côté d'un `MikaMascot`, d'un
    /// `MikaPeek` ou d'un `MikaAsk`, pas de décalage qui dépend d'un état
    /// (`offset(y: hop ? -10 : 0)`), pas d'échelle qui le fait surgir de petit
    /// (`scaleEffect(shown ? 1 : 0.4)`, `popIn` qui grandit). Un décalage fixe, pour le placer,
    /// reste permis.
    func testNoMikaJumpsAnywhere() throws {
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Micabo", isDirectory: true)
        guard let files = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("les sources ne sont pas lisibles depuis ce simulateur")
        }
        let moving = try NSRegularExpression(pattern: #"\.offset\([^)]*\?|\.scaleEffect\([^)]*\?\s*[0-9.]+\s*:\s*0?\.[0-8]|\.popIn\((?![^)]*scales: false)"#)
        var offenders: [String] = []
        var read = 0
        for case let url as URL in files where url.pathExtension == "swift" {
            guard url.lastPathComponent != "MikaMascot.swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            read += 1
            let lines = text.components(separatedBy: "\n")
            for (number, line) in lines.enumerated() where ["MikaMascot(", "MikaPeek(", "MikaAsk(", "OnboardingMikaOnLine("].contains(where: line.contains) {
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

    /// Deux Mika à l'écran : celui qui écrit s'arrête quand l'autre fait coucou, et ne cligne
    /// pas tant que l'autre bouge.
    func testASecondMikaSettlesTheFirst() throws {
        let stage = MikaStage()
        let writer = MikaDirector(stage: stage)
        let greeter = MikaDirector(stage: stage)
        var written: [MikaCue] = []
        var greeted: [MikaCue] = []
        for (director, isWriter) in [(writer, true), (greeter, false)] {
            director.moves = true
            director.blinks = true
            director.apply = { cue in
                if isWriter { written.append(cue) } else { greeted.append(cue) }
            }
        }

        writer.appear(.write)
        writer.finished(try XCTUnwrap(written.last))
        XCTAssertEqual(writer.activity, .looping)
        XCTAssertEqual(written.last?.repeats, true, "l'écriture tourne tant qu'elle dure")
        XCTAssertEqual(stage.performer, writer.token)

        greeter.appear(.wave)
        XCTAssertEqual(stage.performer, greeter.token)
        XCTAssertFalse(writer.isBusy, "le premier s'est posé")
        XCTAssertEqual(written.last?.pose, MikaMood.write.rest)
        XCTAssertEqual(written.last?.repeats, false)

        // Tant que l'autre joue, celui-ci ne cligne pas.
        let before = written.count
        writer.blink()
        XCTAssertEqual(written.count, before)

        // Le coucou va au bout : la scène est libre, « onDone » aurait sonné.
        var finished = 0
        greeter.done = { finished += 1 }
        var guardrail = 0
        while greeter.isBusy, guardrail < 20 {
            greeter.finished(try XCTUnwrap(greeted.last))
            guardrail += 1
        }
        XCTAssertEqual(greeter.activity, .resting)
        XCTAssertEqual(greeted.count, MikaMood.wave.beats.count)
        XCTAssertEqual(greeted.last?.pose, MikaPose.idle)
        XCTAssertEqual(finished, 1)
        XCTAssertNil(stage.performer)

        // Au repos, les yeux ouverts, la scène libre : il cligne.
        greeter.blink()
        XCTAssertEqual(greeter.activity, .blinking)
        XCTAssertEqual(greeted.last?.pose.blink, 1)
        XCTAssertEqual(stage.performer, greeter.token)
    }

    /// **Rien ne tourne hors écran** : en quittant l'écran, tout geste, toute boucle et tout
    /// clignement s'arrêtent, Mika est posé d'un coup sur la fin de son geste, et plus rien ne
    /// repart — ni la fin tardive d'un temps, ni l'horloge du clignement, ni un appui.
    func testNothingRunsOffScreen() throws {
        for mood in MikaMood.allCases {
            let stage = MikaStage()
            let director = MikaDirector(stage: stage)
            var cues: [MikaCue] = []
            director.moves = true
            director.blinks = true
            director.apply = { cues.append($0) }

            director.appear(mood)
            XCTAssertTrue(director.isBusy, "\(mood) : le geste d'arrivée joue")
            if mood.loops {
                director.finished(try XCTUnwrap(cues.last))
                XCTAssertEqual(director.activity, .looping, "\(mood)")
            }
            let pending = try XCTUnwrap(cues.last)

            director.leave()
            XCTAssertEqual(director.activity, .offstage, "\(mood)")
            XCTAssertFalse(director.isBusy, "\(mood)")
            XCTAssertNil(stage.performer, "\(mood) : la scène n'est pas rendue")
            let last = try XCTUnwrap(cues.last)
            XCTAssertNil(last.curve, "\(mood) : posé d'un coup, sans animation")
            XCTAssertFalse(last.repeats, "\(mood) : la boucle continue hors écran")
            XCTAssertEqual(last.pose, mood.rest, "\(mood)")

            let count = cues.count
            director.finished(pending)
            director.blink()
            director.tap()
            director.settle()
            XCTAssertEqual(cues.count, count, "\(mood) : quelque chose a rejoué hors écran")
            XCTAssertEqual(director.activity, .offstage, "\(mood)")

            // De retour à l'écran : une attente reprend ; un geste coupé avant sa fin (personne
            // ne l'a vu) se rejoue ; un geste joué jusqu'au bout ne se rejoue pas.
            director.appear(mood)
            if mood.loops {
                XCTAssertEqual(director.activity, .looping, "\(mood)")
                XCTAssertEqual(cues.last?.repeats, true, "\(mood)")
            } else {
                XCTAssertEqual(director.activity, .gesturing, "\(mood) : le geste coupé ne se rejoue pas")
                var guardrail = 0
                while director.activity == .gesturing, guardrail < 20 {
                    director.finished(try XCTUnwrap(cues.last))
                    guardrail += 1
                }
                XCTAssertEqual(director.activity, .resting, "\(mood)")
                director.leave()
                let played = cues.count
                director.appear(mood)
                XCTAssertEqual(director.activity, .resting, "\(mood)")
                XCTAssertEqual(cues.count, played, "\(mood) : un geste déjà joué se rejoue au retour")
            }
        }
    }

    /// « Réduire les animations », un Mika figé, un Mika trop petit : ni geste, ni boucle, ni
    /// clignement.
    func testReducedMotionAndSmallMikasStayStill() throws {
        let still = MikaDirector(stage: MikaStage())
        var cues: [MikaCue] = []
        still.apply = { cues.append($0) }
        still.moves = false
        still.blinks = true
        still.appear(.write)
        still.blink()
        still.tap()
        XCTAssertEqual(still.activity, .still)
        XCTAssertTrue(cues.isEmpty)

        // Un petit Mika (moins de 64 points) joue son geste, mais ne cligne pas.
        let small = MikaDirector(stage: MikaStage())
        small.apply = { cues.append($0) }
        small.moves = true
        small.blinks = false
        small.appear(.idle)
        small.finished(try XCTUnwrap(cues.last))
        XCTAssertEqual(small.activity, .resting)
        let count = cues.count
        small.blink()
        XCTAssertEqual(cues.count, count)
        XCTAssertEqual(MikaMood.blinkingSize, 64)
        XCTAssertEqual(MikaMood.blinkEvery, 3...6)

        // Les yeux déjà fermés ne clignent pas.
        let happy = MikaDirector(stage: MikaStage())
        happy.apply = { cues.append($0) }
        happy.moves = true
        happy.blinks = true
        happy.appear(.happy)
        var guardrail = 0
        while happy.isBusy, guardrail < 20 {
            happy.finished(try XCTUnwrap(cues.last))
            guardrail += 1
        }
        XCTAssertEqual(happy.activity, .resting)
        let quiet = cues.count
        happy.blink()
        XCTAssertEqual(cues.count, quiet)

        // Le mouvement coupé en route : tout s'arrête, il reste à l'écran.
        happy.tap()
        XCTAssertEqual(happy.activity, .reacting)
        happy.halt()
        XCTAssertEqual(happy.activity, .still)
        XCTAssertNil(cues.last?.curve)
    }

    /// Un changement d'humeur part de la pose du moment, et la fête lance sa gerbe une fois.
    func testAMoodChangeStartsItsGesture() throws {
        let director = MikaDirector(stage: MikaStage())
        var cues: [MikaCue] = []
        director.moves = true
        director.apply = { cues.append($0) }
        director.appear(.think)
        director.change(to: .celebrate)
        XCTAssertEqual(director.activity, .gesturing)
        let first = try XCTUnwrap(cues.last)
        XCTAssertTrue(first.confetti, "la gerbe part avec le premier temps de la fête")
        XCTAssertEqual(first.pose, MikaMood.celebrate.beats[0].pose)
        director.finished(first)
        XCTAssertEqual(cues.last?.confetti, false, "une seule gerbe par fête")
        // La fin tardive d'un temps du geste d'avant ne compte plus.
        let stale = try XCTUnwrap(cues.first)
        let count = cues.count
        director.finished(stale)
        XCTAssertEqual(cues.count, count)
    }

    /// Sous XCTest, les vues de Mika ne bougent pas : les rendus restent des images.
    func testTestsUseStills() {
        XCTAssertTrue(MikaLibrary.isRunningTests)
    }

    // MARK: - Les cadrages

    /// **Le demi** : la vue garde ses proportions d'avant (312 × 260), et la coupe passe sous
    /// les joues et la bouche de chaque humeur, au-dessus du bas de la tête.
    func testThePeekCutsBelowTheFace() {
        XCTAssertEqual(MikaPeek.height(for: 312), 260, accuracy: 0.001)
        XCTAssertEqual(MikaPeek.height(for: MikaPeek.card), 92 * 260 / 312, accuracy: 0.001)
        XCTAssertEqual(MikaArt.peekCut, 248)
        XCTAssertLessThan(CGFloat(MikaArt.peekCut), MikaArt.head.cgPath.boundingBoxOfPath.maxY, "coupé par le bord, pas posé dessus")
        let face: [MikaPiece.Part] = [.eye, .pupil, .lid, .cheek, .mouth]
        for mood in MikaMood.allCases {
            for pose in everyPose(of: mood) {
                for piece in MikaArt.scene(pose) where face.contains(piece.part) {
                    let box = MikaArt.bounds(of: piece, pose: pose)
                    XCTAssertLessThan(Double(box.maxY), MikaArt.peekCut - 2, "\(mood) : le bord coupe le visage (\(piece.part))")
                }
            }
        }
        // En haut, la fenêtre laisse de l'air pour l'étincelle du crayon.
        XCTAssertLessThan(MikaPeek.window.minY, 24)
    }

    /// Sur un fond bleu, Mika prend un liseré blanc : il ne s'y pose jamais nu.
    func testABlueBackdropOutlinesMika() {
        XCTAssertTrue(MikaBackdrop.blue.outlines)
        XCTAssertTrue(MikaBackdrop.sticker.outlines)
        XCTAssertFalse(MikaBackdrop.surface.outlines)
        XCTAssertFalse(MikaBackdrop.disc.outlines, "le disque le détache déjà du fond")
        let scene = MikaArt.scene(.idle, sticker: MikaArt.stickerWidth)
        let outline = scene.prefix { $0.part == .sticker }
        XCTAssertEqual(outline.count, 6, "les cinq tentacules et la tête")
        XCTAssertTrue(outline.allSatisfy { $0.stroke == MikaTint(hex: 0xFFFFFF) })
        XCTAssertEqual(outline.first?.lineWidth, MikaArt.limbWidth + 18)
        XCTAssertEqual(MikaArt.scene(.idle).filter { $0.part == .sticker }.count, 0)
    }

    /// La gerbe de la fête : rien avant, rien après, vingt-deux pièces dans l'air entre les
    /// deux, qui ne suivent pas le corps.
    func testTheConfettiBurstStartsAndEndsEmpty() {
        XCTAssertTrue(MikaArt.burst(0, palette: .marine).isEmpty)
        XCTAssertTrue(MikaArt.burst(1, palette: .marine).isEmpty)
        let middle = MikaArt.burst(0.5, palette: .marine)
        XCTAssertEqual(middle.count, 22)
        XCTAssertTrue(middle.allSatisfy { !$0.isBody && $0.part == .confetti })
        let start = MikaArt.burst(0.05, palette: .marine).map(\.path.cgPath.boundingBoxOfPath)
        let later = middle.map(\.path.cgPath.boundingBoxOfPath)
        let spreadStart = (start.map(\.maxX).max() ?? 0) - (start.map(\.minX).min() ?? 0)
        let spreadLater = (later.map(\.maxX).max() ?? 0) - (later.map(\.minX).min() ?? 0)
        XCTAssertGreaterThan(spreadLater, spreadStart, "la gerbe s'ouvre")
    }

    // MARK: - Ce que l'app embarque

    /// **Plus aucune image d'expression, plus aucune vidéo** : Mika est dessiné.
    func testNoRasterMikaIsShipped() {
        for name in ["neutre", "sourire", "clin-doeil", "coucou", "surprise", "reflexion", "ecriture", "triste", "sommeil", "tete"] {
            XCTAssertNil(UIImage(named: "Mika-\(name)"), "Mika-\(name) est encore au catalogue")
        }
        let videos = (Bundle.main.urls(forResourcesWithExtension: "mov", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil) ?? [])
        XCTAssertTrue(videos.filter { $0.lastPathComponent.hasPrefix("mika") }.isEmpty, "\(videos)")
    }

    /// Mika se redessine à chaque image de ses gestes : sur un iPhone ProMotion, l'app demande
    /// la cadence de l'écran (sans cette clé, ses animations plafonnent à 60 images par seconde).
    func testTheAppAsksForTheScreenCadence() {
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CADisableMinimumFrameDurationOnPhone") as? Bool, true)
    }

    /// **L'écran de lancement et la première image de l'app sont les mêmes** : le marine dans
    /// les deux thèmes, la même image de Mika, 200 points, au centre.
    func testTheLaunchScreenAndTheFirstFrameMatch() throws {
        let launch = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UILaunchScreen") as? [String: Any])
        XCTAssertEqual(launch["UIColorName"] as? String, "LaunchBackground")
        XCTAssertEqual(launch["UIImageName"] as? String, LaunchCurtain.mika)
        XCTAssertEqual(launch["UIImageRespectsSafeAreaInsets"] as? Bool, false, "centré dans l'écran entier, comme le rideau")
        let image = try XCTUnwrap(UIImage(named: LaunchCurtain.mika), "l'image de lancement manque au catalogue")
        XCTAssertEqual(image.size.width, 200, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 200, accuracy: 0.5)

        let named = try XCTUnwrap(UIColor(named: "LaunchBackground"))
        let curtain = UIColor(MicaboBrand.launch)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for color in [named.resolvedColor(with: traits), curtain.resolvedColor(with: traits)] {
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                XCTAssertEqual(red, 0x0B / 255.0, accuracy: 0.004)
                XCTAssertEqual(green, 0x0F / 255.0, accuracy: 0.004)
                XCTAssertEqual(blue, 0x1C / 255.0, accuracy: 0.004)
                XCTAssertEqual(alpha, 1, accuracy: 0.004)
            }
        }
    }

    // MARK: - Le dessin, comparé à la maquette

    /// Le canevas dessine Mika, dans les couleurs du thème : le bleu du corps entre les yeux,
    /// l'encre d'une pupille, rien dans un coin.
    @MainActor
    func testTheCanvasDrawsMika() throws {
        for night in [true, false] {
            let figure = MikaFigure(pose: .idle, framing: .avatar, scale: 100.0 / 300.0, night: night)
            let renderer = ImageRenderer(content: figure)
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.cgImage, "le canevas ne rend rien")
            XCTAssertEqual(image.width, 100)
            XCTAssertEqual(image.height, 100)
            let pixels = try XCTUnwrap(MikaMockup.pixels(of: image))
            let body: UInt32 = night ? 0x5C88FF : 0x3870FE
            XCTAssertLessThan(MikaMockup.distance(pixels, 100, x: 50, y: 50, to: body), 10, "le corps, entre les yeux")
            XCTAssertLessThan(MikaMockup.distance(pixels, 100, x: 38, y: 53, to: 0x14182B), 10, "la pupille gauche")
            XCTAssertLessThan(MikaMockup.distance(pixels, 100, x: 30, y: 44, to: 0xFFFFFF), 10, "le blanc de l'œil")
            XCTAssertEqual(pixels[(2 * 100 + 2) * 4 + 3], 0, "un coin du canevas est vide")
        }
    }

    /// **Le dessin de l'app est celui de la maquette** : chaque expression, rendue par SwiftUI
    /// à la taille de la planche (`design/mika-v3/mika-expressions.png`, exportée du SVG par
    /// Chromium), lui ressemble pixel pour pixel — à l'anticrénelage près, et aux deux « z »
    /// du sommeil, qui sont un texte dans la maquette et un tracé dans l'app.
    @MainActor
    func testTheDrawingMatchesTheMockup() throws {
        guard let sheet = MikaMockup.sheet(), let reference = MikaMockup.pixels(of: sheet) else {
            throw XCTSkip("la maquette n'est pas lisible depuis ce simulateur")
        }
        XCTAssertEqual(sheet.width, 1200)
        XCTAssertEqual(sheet.height, 904)
        for night in [true, false] {
            for mood in MikaMockup.expressions {
                let different = try XCTUnwrap(MikaMockup.difference(mood, night: night, reference: reference, sheetWidth: sheet.width), "\(mood) ne se rend pas")
                XCTAssertLessThan(different, MikaMockup.tolerance, "\(mood)\(night ? "" : " (clair)") s'écarte de la maquette : \(different) pixels sur 40 000")
            }
        }
    }

    // MARK: - Outils

    /// Toutes les poses par lesquelles une humeur peut passer, dans l'ordre : la première
    /// image, le geste, l'attente, l'appui, le clignement.
    private func everyPose(of mood: MikaMood) -> [MikaPose] {
        var chain = [mood.opening] + mood.beats.map(\.pose)
        if let loop = mood.loop {
            chain += [loop.from, loop.to, loop.from]
        }
        chain += MikaMood.tapBeats(from: mood.rest).map(\.pose)
        chain += MikaMood.blinkBeats(from: mood.rest).map(\.pose)
        chain.append(mood.pose)
        return chain
    }

    /// La distance de l'épaule à la main.
    private func span(_ arm: MikaArm) -> Double {
        let points = arm.points
        return hypot(Double(points[4].x - points[0].x), Double(points[4].y - points[0].y))
    }

    private func assertPoint(_ point: CGPoint, _ x: CGFloat, _ y: CGFloat, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(point.x, x, accuracy: 0.001, what, file: file, line: line)
        XCTAssertEqual(point.y, y, accuracy: 0.001, what, file: file, line: line)
    }

    private func assertRect(
        _ rect: CGRect, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ what: String,
        accuracy: CGFloat = 0.3, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertEqual(rect.minX, x, accuracy: accuracy, "\(what) : x", file: file, line: line)
        XCTAssertEqual(rect.minY, y, accuracy: accuracy, "\(what) : y", file: file, line: line)
        XCTAssertEqual(rect.width, width, accuracy: accuracy, "\(what) : largeur", file: file, line: line)
        XCTAssertEqual(rect.height, height, accuracy: accuracy, "\(what) : hauteur", file: file, line: line)
    }

    private func assertClose(_ a: MikaPose, _ b: MikaPose, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.values.count, b.values.count, file: file, line: line)
        for (x, y) in zip(a.values, b.values) {
            XCTAssertEqual(x, y, accuracy: 0.000001, file: file, line: line)
        }
    }
}

/// **La maquette versionnée** (`design/mika-v3/mika-expressions.png` : douze expressions sur le
/// marine, puis les mêmes sur le thème clair, exportées du SVG) et sa comparaison avec le
/// dessin de l'app.
enum MikaMockup {
    /// Les douze expressions de la planche, dans l'ordre, six par rangée.
    static let expressions: [MikaMood] = [
        .idle, .happy, .wave, .wink, .celebrate, .think,
        .write, .surprise, .sad, .sleep, .look, .proud,
    ]
    /// Le côté d'un dessin sur la planche, en pixels.
    static let cell = 200
    /// La hauteur d'une rangée : le dessin et son nom dessous.
    static let row = 226
    /// Le nombre de pixels (sur 40 000) qu'une expression peut avoir de différents.
    static let tolerance = 200

    static var url: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("design/mika-v3/mika-expressions.png")
    }

    static func sheet() -> CGImage? {
        UIImage(contentsOfFile: url.path)?.cgImage
    }

    /// Le fond de page d'un thème.
    static func paper(night: Bool) -> UInt32 { night ? 0x0B0F1C : 0xEEF1F8 }

    /// Les pixels RGBA d'une image, en sRGB, la rangée du haut d'abord.
    static func pixels(of image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        return Array(UnsafeBufferPointer(start: bytes, count: width * height * 4))
    }

    /// L'écart d'un pixel à une couleur : la plus grande différence d'un canal.
    static func distance(_ pixels: [UInt8], _ width: Int, x: Int, y: Int, to hex: UInt32) -> Int {
        let index = (y * width + x) * 4
        let red = abs(Int(pixels[index]) - Int((hex >> 16) & 0xFF))
        let green = abs(Int(pixels[index + 1]) - Int((hex >> 8) & 0xFF))
        let blue = abs(Int(pixels[index + 2]) - Int(hex & 0xFF))
        return max(red, green, blue)
    }

    /// Le dessin SwiftUI d'une expression, à la taille de la planche, sur le fond du thème.
    @MainActor
    static func drawing(_ mood: MikaMood, night: Bool) -> CGImage? {
        let view = MikaMascot(mood: mood, size: CGFloat(cell), frozenAt: 0)
            .background(Color(hex: paper(night: night)))
            .environment(\.colorScheme, night ? .dark : .light)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        return renderer.cgImage
    }

    /// **Le nombre de pixels du dessin qui ne ressemblent à aucun de leurs voisins dans la
    /// maquette** (le pixel d'en face et les huit autour) : l'anticrénelage de deux moteurs
    /// de dessin diffère d'un demi-pixel, un œil déplacé de deux pixels se voit.
    @MainActor
    static func difference(_ mood: MikaMood, night: Bool, reference: [UInt8], sheetWidth: Int) -> Int? {
        guard let index = expressions.firstIndex(of: mood),
              let image = drawing(mood, night: night),
              image.width == cell, image.height == cell,
              let drawn = pixels(of: image) else { return nil }
        let originX = (index % 6) * cell
        let originY = ((night ? 0 : 2) + index / 6) * row
        var different = 0
        for y in 0..<cell {
            for x in 0..<cell {
                let mine = (y * cell + x) * 4
                var best = 255
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = min(cell - 1, max(0, x + dx))
                        let ny = min(cell - 1, max(0, y + dy))
                        let theirs = ((originY + ny) * sheetWidth + originX + nx) * 4
                        let red = abs(Int(drawn[mine]) - Int(reference[theirs]))
                        let green = abs(Int(drawn[mine + 1]) - Int(reference[theirs + 1]))
                        let blue = abs(Int(drawn[mine + 2]) - Int(reference[theirs + 2]))
                        best = min(best, max(red, green, blue))
                    }
                }
                if best > 48 { different += 1 }
            }
        }
        return different
    }
}
