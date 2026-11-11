import ImageIO
import UIKit
import XCTest
@testable import Micabo

/// La mascotte, en entier : chaque humeur a son animation WebP dans l'app, chaque pose son
/// image fixe, et les voyages de Mika ont leurs fichiers.
final class MikaMascotTests: XCTestCase {
    /// Les treize animations sont dans le paquet, ImageIO les ouvre, et leur durée est celle
    /// du kit (24 images par seconde).
    func testEveryMoodHasItsAnimation() throws {
        for mood in MikaMood.allCases {
            let url = try XCTUnwrap(MikaLibrary.url(for: mood.animationName), "mika-\(mood.animationName).webp manque")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let count = CGImageSourceGetCount(source)
            XCTAssertGreaterThan(count, 1, "\(mood) n'est pas animé")
            XCTAssertEqual(Double(count) / 24, mood.duration, accuracy: 0.1, "\(mood) : durée")
            let first = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(first.width, 512, "\(mood) n'est pas en 512")
        }
    }

    /// Les voyages : entrer, sortir, traverser, sur le cadre large du kit.
    func testJourneysHaveTheirAnimation() throws {
        for kind in [MikaJourney.Kind.enter, .exit, .walkAcross] {
            let url = try XCTUnwrap(MikaLibrary.url(for: kind.rawValue), "mika-\(kind.rawValue).webp manque")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let first = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(Double(first.width) / Double(first.height), Double(MikaJourney.aspect), accuracy: 0.01)
        }
    }

    /// Les poses fixes : toutes dans le catalogue, et chaque humeur a la sienne.
    func testEveryStillExists() {
        for still in MikaStill.allCases {
            XCTAssertNotNil(UIImage(named: still.imageName), "\(still.imageName) manque au catalogue")
        }
        for mood in MikaMood.allCases {
            XCTAssertNotNil(UIImage(named: mood.still.imageName), "\(mood) sans image fixe")
        }
    }

    /// Les boucles : repos, réflexion, écriture, tristesse, sommeil. Le reste se joue une fois
    /// et revient au repos.
    func testLoopingMoodsFollowTheKit() {
        let loops = Set(MikaMood.allCases.filter(\.loops))
        XCTAssertEqual(loops, [.idle, .think, .write, .sad, .sleep])
    }

    /// Sous XCTest, Mika n'anime rien : les rendus restent des images.
    func testTestsUseStills() {
        XCTAssertTrue(MikaLibrary.isRunningTests)
    }
}
