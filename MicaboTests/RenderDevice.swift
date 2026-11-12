import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Un iPhone pour les rendus** : sa taille, ses marges de sécurité, son encoche.
///
/// `ImageRenderer` dessine une vue sans fenêtre, donc sans marge de sécurité : un titre posé
/// sous l'encoche ou un bouton collé à la barre d'accueil y paraissent justes. Ces profils
/// servent à `RenderGallery.renderDevice`, qui pose l'écran dans une vraie fenêtre avec ces
/// marges, puis dessine l'encoche (ou la barre d'état) et la barre d'accueil par-dessus.
struct RenderDevice {
    let suffix: String
    let size: CGSize
    let insets: UIEdgeInsets
    let cornerRadius: CGFloat
    let hasIsland: Bool
    let hasHomeIndicator: Bool

    /// iPhone 15 Pro : 393 × 852, Dynamic Island, 59 pt en haut, 34 pt en bas.
    static let iPhone15Pro = RenderDevice(
        suffix: "15pro", size: CGSize(width: 393, height: 852),
        insets: UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
        cornerRadius: 55, hasIsland: true, hasHomeIndicator: true
    )
    /// iPhone SE : 375 × 667, barre d'état de 20 pt, bouton d'accueil (aucune marge en bas).
    static let iPhoneSE = RenderDevice(
        suffix: "se", size: CGSize(width: 375, height: 667),
        insets: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0),
        cornerRadius: 0, hasIsland: false, hasHomeIndicator: false
    )
}

/// **Le contrôleur qui tient l'écran** : il pose la vue de l'écran dans un cadre de la taille du
/// profil, placé dans la fenêtre du simulateur là où celle-ci ne donne aucune marge (entre
/// l'encoche et la barre d'accueil), puis lui ajoute les marges du profil.
///
/// La marge d'une **fenêtre** vient de la scène, où qu'on la pose ; celle d'une **vue** est
/// géométrique : la part d'elle qui chevauche l'encoche ou la barre d'accueil. Un cadre posé
/// hors de ces zones n'a donc aucune marge, et `additionalSafeAreaInsets` (qui ne sait
/// qu'ajouter) donne exactement celles du profil. Un profil plus haut que cette zone (l'iPhone
/// 15 Pro sur un simulateur de 874 pt) garde au moins les marges du simulateur.
@MainActor
private final class DeviceFrameController: UIViewController {
    let hosting: UIViewController
    let target: UIEdgeInsets
    let size: CGSize
    let frameView = UIView()

    init(hosting: UIViewController, target: UIEdgeInsets, size: CGSize) {
        self.hosting = hosting
        self.target = target
        self.size = size
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        frameView.clipsToBounds = true
        view.addSubview(frameView)
        addChild(hosting)
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        frameView.addSubview(hosting.view)
        hosting.didMove(toParent: self)
    }

    /// Pose le cadre, puis ajoute à l'écran ce qui lui manque pour avoir les marges du profil.
    func settleInsets() {
        view.layoutIfNeeded()
        let unsafe = view.safeAreaInsets
        var origin = CGPoint.zero
        if unsafe.top + size.height <= view.bounds.height - unsafe.bottom {
            origin.y = unsafe.top
        }
        frameView.frame = CGRect(origin: origin, size: size)
        hosting.view.frame = frameView.bounds
        hosting.additionalSafeAreaInsets = .zero
        view.layoutIfNeeded()
        let inherited = hosting.view.safeAreaInsets
        hosting.additionalSafeAreaInsets = UIEdgeInsets(
            top: max(0, target.top - inherited.top),
            left: max(0, target.left - inherited.left),
            bottom: max(0, target.bottom - inherited.bottom),
            right: max(0, target.right - inherited.right)
        )
        hosting.view.setNeedsLayout()
        view.layoutIfNeeded()
    }
}

extension RenderGallery {
    /// **Le rendu « sur l'appareil »** : l'écran est posé dans une vraie fenêtre, à la taille du
    /// profil, avec ses marges de sécurité (les `ignoresSafeArea`, `safeAreaInset` et
    /// `.background` se comportent comme sur l'iPhone), puis l'encoche ou la barre d'état et la
    /// barre d'accueil sont dessinées par-dessus, avec un trait pointillé rose à la limite de
    /// chaque marge. Écrit `<nom>-<profil>.png` (clair) et `<nom>-<profil>-nuit.png` (marine).
    ///
    /// Profils : `.iPhone15Pro` (59/34) et `.iPhoneSE` (20/0). Le contenu d'une ScrollView est
    /// dessiné tel que l'écran le montre (le premier écran), les contrôles UIKit compris.
    static func renderDevice<V: View>(
        _ name: String,
        devices: [RenderDevice] = [.iPhone15Pro, .iPhoneSE],
        guides: Bool = true,
        _ view: V
    ) throws {
        guard let directory else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        FontLoader.registerFonts()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for device in devices {
            for (scheme, tail) in [(ColorScheme.light, ""), (.dark, "-nuit")] {
                let file = "\(name)-\(device.suffix)\(tail)"
                let image = snapshot(view, device: device, scheme: scheme, guides: guides, log: file)
                guard let data = image?.pngData() else {
                    XCTFail("rendu vide : \(file)")
                    continue
                }
                try data.write(to: directory.appendingPathComponent("\(file).png"))
            }
        }
    }

    private static func snapshot<V: View>(_ view: V, device: RenderDevice, scheme: ColorScheme, guides: Bool, log: String) -> UIImage? {
        let frame = CGRect(origin: .zero, size: device.size)
        let window: UIWindow
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: frame)
        }
        window.frame = window.windowScene?.screen.bounds ?? frame
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 2)
        window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light

        let hosting = UIHostingController(rootView: AnyView(view.environment(\.colorScheme, scheme)))
        hosting.view.backgroundColor = UIColor(V3Color.bg).resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
        let root = DeviceFrameController(hosting: hosting, target: device.insets, size: device.size)
        window.rootViewController = root
        window.isHidden = false
        root.settleInsets()
        // Laisse SwiftUI poser l'écran (tâches d'apparition, premières mises en page).
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        root.settleInsets()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let measured = hosting.view.safeAreaInsets
        appendLog("\(log) : marges vues par l'écran haut \(Int(measured.top)) bas \(Int(measured.bottom)) (attendu \(Int(device.insets.top))/\(Int(device.insets.bottom)))")
        let captured = root.frameView

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: frame, format: format).image { context in
            let cg = context.cgContext
            UIColor.black.setFill()
            cg.fill(frame)
            if device.cornerRadius > 0 {
                UIBezierPath(roundedRect: frame, cornerRadius: device.cornerRadius).addClip()
            }
            if !captured.drawHierarchy(in: frame, afterScreenUpdates: true) {
                captured.layer.render(in: cg)
            }
            drawChrome(device: device, dark: scheme == .dark, guides: guides, in: cg)
            // Une marge qui n'est pas celle du profil se voit sur l'image, en rouge.
            if abs(measured.top - device.insets.top) > 4 || abs(measured.bottom - device.insets.bottom) > 4 {
                let warning = NSAttributedString(
                    string: " marges vues \(Int(measured.top))/\(Int(measured.bottom)) ≠ \(Int(device.insets.top))/\(Int(device.insets.bottom)) ",
                    attributes: [.font: UIFont.boldSystemFont(ofSize: 12), .foregroundColor: UIColor.white, .backgroundColor: UIColor.red]
                )
                warning.draw(at: CGPoint(x: 8, y: device.size.height / 2))
            }
        }
        window.rootViewController = nil
        window.isHidden = true
        return image
    }

    /// L'encoche (ou la barre d'état), la barre d'accueil et les limites des marges.
    private static func drawChrome(device: RenderDevice, dark: Bool, guides: Bool, in cg: CGContext) {
        let width = device.size.width
        let ink = dark ? UIColor.white : UIColor.black
        if guides {
            cg.saveGState()
            cg.setStrokeColor(UIColor(red: 1, green: 0.2, blue: 0.6, alpha: 0.85).cgColor)
            cg.setLineWidth(1)
            cg.setLineDash(phase: 0, lengths: [4, 3])
            for y in [device.insets.top, device.size.height - device.insets.bottom] where y > 0 && y < device.size.height {
                cg.move(to: CGPoint(x: 0, y: y))
                cg.addLine(to: CGPoint(x: width, y: y))
            }
            cg.strokePath()
            cg.restoreGState()
        }
        // L'heure et la batterie.
        let statusY: CGFloat = device.hasIsland ? 17 : 2
        let time = NSAttributedString(string: "9:41", attributes: [
            .font: UIFont.systemFont(ofSize: device.hasIsland ? 17 : 13, weight: .semibold),
            .foregroundColor: ink,
        ])
        time.draw(at: CGPoint(x: device.hasIsland ? 52 : 8, y: statusY))
        let battery = CGRect(x: width - (device.hasIsland ? 60 : 36), y: statusY + (device.hasIsland ? 4 : 3), width: 26, height: 12)
        ink.setStroke()
        let shell = UIBezierPath(roundedRect: battery, cornerRadius: 3.5)
        shell.lineWidth = 1
        shell.stroke()
        ink.setFill()
        UIBezierPath(roundedRect: battery.insetBy(dx: 2, dy: 2), cornerRadius: 2).fill()
        if device.hasIsland {
            UIColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(x: (width - 126) / 2, y: 11, width: 126, height: 37), cornerRadius: 18.5).fill()
        }
        if device.hasHomeIndicator {
            ink.setFill()
            UIBezierPath(roundedRect: CGRect(x: (width - 134) / 2, y: device.size.height - 8 - 5, width: 134, height: 5), cornerRadius: 2.5).fill()
        }
    }

    private static func appendLog(_ line: String) {
        guard let directory else { return }
        let url = directory.appendingPathComponent("safe-areas.txt")
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}

/// **Une page d'onglet posée comme dans l'app** : le fond qui passe sous les marges, la pile de
/// navigation, et la barre d'onglets ancrée en bas comme `RootTabView` la pose. La page
/// réserve elle-même la place de la barre (`tabBarClearance`), comme dans l'app.
struct RenderTabRoot<Content: View>: View {
    @State private var router: TabRouter
    let content: Content

    init(selection: RootTab = .today, @ViewBuilder content: () -> Content) {
        let router = TabRouter()
        router.selection = selection
        _router = State(initialValue: router)
        self.content = content()
    }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            NavigationStack { content }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MicaboTabBar()
        }
        .environment(router)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }
}
