import Lottie
import UIKit
import XCTest
@testable import Micabo

/// La mascotte : chaque humeur a son animation dans l'app, et son image fixe dans les deux
/// versions de l'étincelle.
final class MikaMascotTests: XCTestCase {
    /// Les treize animations du kit sont dans le paquet, et Lottie les décode.
    func testEveryMoodHasItsAnimation() throws {
        for mood in MikaMood.allCases {
            let url = try XCTUnwrap(
                Bundle.main.url(forResource: mood.animationName, withExtension: "json"),
                "\(mood.animationName).json manque"
            )
            let animation = try LottieAnimation.from(data: Data(contentsOf: url))
            XCTAssertEqual(animation.size.width, 1024, accuracy: 0.5, "\(mood) n'est pas en 1024")
            XCTAssertEqual(animation.duration, mood.duration, accuracy: 0.05, "\(mood) : durée")
        }
    }

    /// Chaque animation a l'étincelle que `MikaMascot` recolore sur un fond clair : un calque
    /// de forme nommé « sparkle ». Sans lui, l'étincelle resterait blanche sur le blanc.
    func testEveryAnimationHasASparkleLayer() throws {
        for mood in MikaMood.allCases {
            let url = try XCTUnwrap(Bundle.main.url(forResource: mood.animationName, withExtension: "json"))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
            let layers = try XCTUnwrap(json["layers"] as? [[String: Any]])
            let sparkles = layers.filter { $0["nm"] as? String == "sparkle" }
            XCTAssertFalse(sparkles.isEmpty, "\(mood) sans étincelle")
            XCTAssertTrue(sparkles.allSatisfy { $0["ty"] as? Int == 4 }, "\(mood) : l'étincelle n'est pas une forme")
        }
    }

    /// Les images fixes : dix expressions, deux étincelles, toutes dans le catalogue.
    func testEveryStillExistsInBothSparkles() {
        for still in MikaStill.allCases {
            for sparkle in [MikaSparkle.white, .blue] {
                let name = still.imageName(sparkle: sparkle)
                XCTAssertNotNil(UIImage(named: name), "\(name) manque au catalogue")
            }
        }
        for mood in MikaMood.allCases {
            XCTAssertNotNil(UIImage(named: mood.still.imageName(sparkle: .blue)), "\(mood) sans image fixe")
        }
    }

    /// Les boucles du kit : repos, réflexion, écriture, tristesse, sommeil. Le reste se joue
    /// une fois et revient au repos.
    func testLoopingMoodsFollowTheKit() {
        let loops = Set(MikaMood.allCases.filter(\.loops))
        XCTAssertEqual(loops, [.idle, .think, .write, .sad, .sleep])
    }

    /// Sous XCTest, Mika ne lance pas Lottie : les rendus restent des images.
    func testTestsUseStills() {
        XCTAssertTrue(MikaLibrary.isRunningTests)
    }
}
