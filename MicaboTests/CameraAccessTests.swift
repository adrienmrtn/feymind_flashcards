import AVFoundation
import XCTest
@testable import Micabo

/// Le refus de l'App Store du 17 septembre tient dans ce fichier.
///
/// Règle 5.1.1(iv) : l'app ne doit pas renvoyer vers les Réglages quelqu'un qui vient de
/// toucher « Refuser ». Elle ne le faisait nulle part dans son code — c'est le scanner de
/// VisionKit, présenté sans caméra, qui affichait sa boîte « Camera Unavailable » et son
/// bouton **Settings**. La parade est donc en amont : ne jamais l'ouvrir sans autorisation.
final class CameraAccessTests: XCTestCase {
    /// Refusée ou verrouillée par le contrôle parental, la caméra n'ouvre plus rien. C'est
    /// l'assertion qui empêche la boîte du relecteur de réapparaître.
    func testARefusedCameraNeverOpensTheScanner() {
        XCTAssertFalse(CameraAccess.allowsScanner(.denied))
        XCTAssertFalse(CameraAccess.allowsScanner(.restricted))
        XCTAssertTrue(CameraAccess.isRefused(.denied))
        XCTAssertTrue(CameraAccess.isRefused(.restricted))
    }

    /// Avant la question comme après un oui, le scanner reste la bonne tuile : un refus n'est
    /// pas l'état par défaut, et on ne punit pas ceux qui ont accepté.
    func testTheScannerStaysOfferedBeforeAndAfterAYes() {
        XCTAssertTrue(CameraAccess.allowsScanner(.notDetermined))
        XCTAssertTrue(CameraAccess.allowsScanner(.authorized))
        XCTAssertFalse(CameraAccess.isRefused(.notDetermined))
        XCTAssertFalse(CameraAccess.isRefused(.authorized))
    }

    /// La ligne de repli explique, et n'envoie nulle part. Un « Réglages » qui reviendrait
    /// dans une des cinq langues rejouerait le refus, même sans bouton.
    func testTheFallbackLineSendsNobodyToSettings() {
        let settings = ["Réglages", "Settings", "Einstellungen", "Ajustes", "Ayarlar"]
        for locale in UiLocale.allCases {
            let line = L10n.t("ios.scanCameraOff", locale: locale)
            XCTAssertNotEqual(line, "ios.scanCameraOff", locale.rawValue)
            XCTAssertFalse(line.isEmpty, locale.rawValue)
            for word in settings {
                XCTAssertFalse(
                    line.localizedCaseInsensitiveContains(word),
                    "\(locale.rawValue) renvoie vers « \(word) » : \(line)"
                )
            }
        }
    }
}
