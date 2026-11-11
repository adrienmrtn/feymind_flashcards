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

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
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
