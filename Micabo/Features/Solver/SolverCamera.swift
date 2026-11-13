import AVFoundation
import SwiftUI
import UIKit

/// **L'appareil photo du scanner**, plein écran, sans le scanner de documents de VisionKit :
/// une seule question se cadre à la main, et le scanner d'Apple cherche une page entière.
///
/// La session tourne sur sa propre file ; l'écran ne fait que lire `isRunning` et demander une
/// photo. Le flash est la **lampe** (`torch`) : sur une feuille, une lumière continue qu'on voit
/// avant d'appuyer vaut mieux qu'un éclair qui laisse un reflet.
@Observable
final class SolverCamera: NSObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "app.micabo.solver.camera")
    @ObservationIgnored private var device: AVCaptureDevice?
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var pending: CheckedContinuation<UIImage?, Never>?

    private(set) var isRunning = false
    private(set) var torchOn = false
    private(set) var hasTorch = false

    /// Faux sur le simulateur, ou sans caméra arrière.
    static var isAvailable: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    func start() {
        queue.async { [weak self] in
            guard let self else { return }
            if !self.configured { self.configure() }
            guard self.configured, !self.session.isRunning else { return }
            self.session.startRunning()
            let running = self.session.isRunning
            DispatchQueue.main.async { self.isRunning = running }
        }
    }

    /// Arrête la visée — et **éteint la lampe d'abord** : une lampe allumée ne doit pas
    /// survivre à la fermeture de la caméra, ni au passage en arrière-plan.
    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            if let device = self.device, device.hasTorch, device.torchMode != .off, (try? device.lockForConfiguration()) != nil {
                device.torchMode = .off
                device.unlockForConfiguration()
            }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
                self.torchOn = false
            }
        }
    }

    private func configure() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        // La mise au point au plus près : une feuille se tient à vingt centimètres.
        if (try? camera.lockForConfiguration()) != nil {
            if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
            if camera.isAutoFocusRangeRestrictionSupported { camera.autoFocusRangeRestriction = .near }
            camera.unlockForConfiguration()
        }
        device = camera
        configured = true
        // Après une mise au point touchée, l'autofocus continu reprend dès que la scène bouge.
        NotificationCenter.default.addObserver(forName: AVCaptureDevice.subjectAreaDidChangeNotification, object: camera, queue: nil) { [weak self] _ in
            self?.queue.async {
                guard let device = self?.device, device.isFocusModeSupported(.continuousAutoFocus), (try? device.lockForConfiguration()) != nil else { return }
                device.focusMode = .continuousAutoFocus
                if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
                device.isSubjectAreaChangeMonitoringEnabled = false
                device.unlockForConfiguration()
            }
        }
        let torch = camera.hasTorch
        DispatchQueue.main.async { self.hasTorch = torch }
    }

    func toggleTorch() {
        let wanted = !torchOn
        queue.async { [weak self] in
            guard let self, let device = self.device, device.hasTorch, (try? device.lockForConfiguration()) != nil else { return }
            device.torchMode = wanted ? .on : .off
            device.unlockForConfiguration()
            DispatchQueue.main.async { self.torchOn = wanted }
        }
    }

    /// Le grossissement au début d'un pincement : le geste multiplie celui-là.
    @ObservationIgnored private var pinchBase: CGFloat = 1
    /// Au-delà, l'image devient floue sur une feuille : on s'arrête.
    static let maxZoom: CGFloat = 6

    /// Le zoom d'un pincement (lot 12) : `scale` est celui du geste depuis son début.
    func pinch(_ scale: CGFloat, began: Bool) {
        queue.async { [weak self] in
            guard let self, let device = self.device else { return }
            if began { self.pinchBase = device.videoZoomFactor }
            let ceiling = min(device.activeFormat.videoMaxZoomFactor, Self.maxZoom)
            let wanted = max(1, min(self.pinchBase * scale, ceiling))
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = wanted
            device.unlockForConfiguration()
        }
    }

    /// La mise au point et l'exposition sur le point touché (`point` en coordonnées de
    /// capteur, de 0 à 1), puis l'autofocus continu reprend la main.
    func focus(at point: CGPoint) {
        queue.async { [weak self] in
            guard let self, let device = self.device, (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        }
    }

    /// Une photo, redressée ; `nil` si l'appareil n'a rien rendu.
    func capture() async -> UIImage? {
        guard pending == nil else { return nil }
        return await withCheckedContinuation { continuation in
            pending = continuation
            queue.async { [weak self] in
                guard let self else { return }
                guard self.session.isRunning else {
                    self.finish(nil)
                    return
                }
                // Le téléphone se tient droit : la photo aussi, quel que soit le capteur.
                if let connection = self.output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                let settings = AVCapturePhotoSettings()
                self.output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        finish(image.map { SolverImage.normalized($0) })
    }

    private func finish(_ image: UIImage?) {
        DispatchQueue.main.async {
            self.pending?.resume(returning: image)
            self.pending = nil
        }
    }
}

/// L'aperçu de la caméra, rempli (`resizeAspectFill`) : c'est ce que `SolverCrop` suppose
/// pour ramener le cadre dans la photo.
struct SolverCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// **La visée qu'on pince et qu'on touche** (lot 12) : le pincement zoome, l'appui fait la
/// mise au point à cet endroit ; un carré bleu s'y pose et s'efface de lui-même (une animation
/// du calque, pas une minuterie).
struct ScanCameraPreview: UIViewRepresentable {
    let camera: SolverCamera

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        weak var camera: SolverCamera?
        private let marker = CAShapeLayer()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .black
            previewLayer.videoGravity = .resizeAspectFill
            marker.strokeColor = UIColor(red: 0.36, green: 0.53, blue: 1, alpha: 1).cgColor
            marker.fillColor = UIColor.clear.cgColor
            marker.lineWidth = 2
            marker.opacity = 0
            layer.addSublayer(marker)
            addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:))))
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
            isAccessibilityElement = false
        }

        required init?(coder: NSCoder) { nil }

        @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
            guard gesture.state == .began || gesture.state == .changed else { return }
            camera?.pinch(gesture.scale, began: gesture.state == .began)
        }

        @objc private func tapped(_ gesture: UITapGestureRecognizer) {
            let point = gesture.location(in: self)
            camera?.focus(at: previewLayer.captureDevicePointConverted(fromLayerPoint: point))
            let side: CGFloat = 72
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            marker.path = UIBezierPath(roundedRect: CGRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side), cornerRadius: 14).cgPath
            CATransaction.commit()
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 1, 0]
            fade.keyTimes = [0, 0.6, 1]
            fade.duration = UIAccessibility.isReduceMotionEnabled ? 0.6 : 1.1
            marker.add(fade, forKey: "focus")
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = camera.session
        view.camera = camera
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.camera = camera
    }
}
