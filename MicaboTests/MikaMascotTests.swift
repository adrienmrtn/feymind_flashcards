import XCTest
@testable import Micabo

/// La mascotte : la scène traduite du design se lit, et ses courbes se calculent comme en CSS.
final class MikaMascotTests: XCTestCase {
    func testTheSceneDecodesFromTheBundle() throws {
        let scene = try XCTUnwrap(MikaScene.shared, "mika.json manque ou ne se décode pas")
        XCTAssertEqual(scene.viewBox, [-10, -24, 220, 220])
        XCTAssertGreaterThan(scene.nodes.count, 3)
        XCTAssertEqual(scene.fade, 0.18, accuracy: 0.001)
    }

    /// Chaque humeur fait bouger le corps : un Mika figé dans une humeur serait un bug.
    func testEveryMoodAnimatesTheBody() throws {
        let scene = try XCTUnwrap(MikaScene.shared)
        func find(_ cls: String, in nodes: [MikaNode]) -> MikaNode? {
            for node in nodes {
                if node.c?.contains(cls) == true { return node }
                if let found = find(cls, in: node.kids ?? []) { return found }
            }
            return nil
        }
        let squash = try XCTUnwrap(find("squash", in: scene.nodes))
        for mood in MikaMood.allCases {
            let animation = try XCTUnwrap(squash.st?[mood.rawValue]?.anim, "\(mood) ne respire pas")
            XCTAssertNotNil(scene.keyframes[animation.name], "\(animation.name) sans images clés")
        }
    }

    /// Toute animation nommée a ses images clés.
    func testEveryAnimationHasItsKeyframes() throws {
        let scene = try XCTUnwrap(MikaScene.shared)
        var missing: [String] = []
        func walk(_ nodes: [MikaNode]) {
            for node in nodes {
                for style in (node.st ?? [:]).values {
                    if let name = style.anim?.name, scene.keyframes[name] == nil { missing.append(name) }
                }
                walk(node.kids ?? [])
            }
        }
        walk(scene.nodes)
        XCTAssertEqual(missing, [])
    }

    func testCubicBezierMatchesCSS() {
        let linear: [Double] = [0, 0, 1, 1]
        XCTAssertEqual(CubicBezier.value(linear, at: 0.3), 0.3, accuracy: 1e-6)
        let easeInOut: [Double] = [0.42, 0, 0.58, 1]
        XCTAssertEqual(CubicBezier.value(easeInOut, at: 0), 0, accuracy: 1e-4)
        XCTAssertEqual(CubicBezier.value(easeInOut, at: 0.5), 0.5, accuracy: 1e-3)
        XCTAssertEqual(CubicBezier.value(easeInOut, at: 1), 1, accuracy: 1e-4)
        XCTAssertLessThan(CubicBezier.value(easeInOut, at: 0.2), 0.2, "ease-in-out démarre lentement")
        // Une courbe qui dépasse 1 (le « pop » de la surprise) doit dépasser.
        let overshoot: [Double] = [0.3, 1.6, 0.5, 1]
        XCTAssertGreaterThan(CubicBezier.value(overshoot, at: 0.5), 1)
    }
}
