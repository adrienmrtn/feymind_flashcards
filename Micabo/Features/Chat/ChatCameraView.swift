import SwiftUI
import UIKit

/// **L'appareil photo du chat, en rafale** : on prend une page, puis la suivante, sans
/// quitter la visée ; les photos prises s'alignent en bas (un appui en retire une), et
/// « Terminé » les pose toutes dans la conversation. Six au plus, comme le chat.
///
/// Même appareil que le scanner (`SolverCamera`) : la lampe plutôt que l'éclair, la mise au
/// point au plus près.
struct ChatCameraView: View {
    /// Combien de photos la conversation peut encore recevoir.
    let room: Int
    let onDone: ([UIImage]) -> Void

    init(room: Int, onDone: @escaping ([UIImage]) -> Void) {
        self.room = room
        self.onDone = onDone
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera = SolverCamera()
    @State private var shots: [ChatShot] = []
    @State private var allowed = CameraAccess.allowsScanner(CameraAccess.status)
    @State private var capturing = false

    var body: some View {
        ChatCameraChrome(
            shots: shots,
            room: room,
            available: allowed && SolverCamera.isAvailable,
            torchAvailable: camera.hasTorch,
            torchOn: camera.torchOn,
            capturing: capturing,
            onClose: { dismiss() },
            onTorch: { camera.toggleTorch() },
            onShoot: shoot,
            onRemove: { id in shots.removeAll { $0.id == id } },
            onDone: finish
        ) {
            if allowed && SolverCamera.isAvailable {
                SolverCameraPreview(session: camera.session)
            } else {
                Color.black
            }
        }
        .onAppear(perform: start)
        .onDisappear { camera.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { start() } else { camera.stop() }
        }
    }

    private func start() {
        Task {
            let granted = await CameraAccess.request()
            allowed = granted
            if granted { camera.start() }
        }
    }

    private func shoot() {
        guard !capturing, shots.count < room else { return }
        capturing = true
        Task {
            if let image = await camera.capture() {
                shots.append(ChatShot(image: image))
                Haptics.light()
            }
            capturing = false
        }
    }

    private func finish() {
        let images = shots.map(\.image)
        camera.stop()
        dismiss()
        if !images.isEmpty { onDone(images) }
    }
}

struct ChatShot: Identifiable, Equatable {
    var id = UUID()
    var image: UIImage
}

/// La visée et ses commandes, sans caméra : les rendus la posent sur un fond.
struct ChatCameraChrome<Preview: View>: View {
    let shots: [ChatShot]
    let room: Int
    let available: Bool
    let torchAvailable: Bool
    let torchOn: Bool
    var capturing = false
    let onClose: () -> Void
    let onTorch: () -> Void
    let onShoot: () -> Void
    let onRemove: (UUID) -> Void
    let onDone: () -> Void
    @ViewBuilder let preview: () -> Preview

    private var isFull: Bool { shots.count >= room }

    var body: some View {
        ZStack {
            // La visée remplit l'écran sans en dicter la taille : les commandes restent dans
            // les marges, quelle que soit la photo.
            Color.black
                .overlay { preview() }
                .clipped()
                .ignoresSafeArea()
            if !available {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(V3Font.text(.largeTitle, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.8))
                    Text(L10n.t("ios.chat11.camera.unavailable", locale: .resolved()))
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 40)
            }
            VStack(spacing: 0) {
                top
                Spacer(minLength: 0)
                bottom
            }
        }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
    }

    private var top: some View {
        HStack(spacing: 12) {
            roundButton("xmark", label: L10n.t("ios.cal.close", locale: .resolved()), action: onClose)
            Spacer(minLength: 0)
            Text(L10n.t("ios.chat11.camera.hint", locale: .resolved()))
                .font(V3Font.label)
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.45), in: Capsule())
            Spacer(minLength: 0)
            if torchAvailable {
                roundButton(torchOn ? "flashlight.on.fill" : "flashlight.off.fill", label: L10n.t("ios.chat11.camera.torch", locale: .resolved()), action: onTorch)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 8)
    }

    private var bottom: some View {
        VStack(spacing: 16) {
            if !shots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shots) { shot in
                            Button { onRemove(shot.id) } label: {
                                Image(uiImage: shot.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(V3Font.text(.footnote, weight: .bold))
                                            .foregroundStyle(Color.white, Color.black.opacity(0.6))
                                            .padding(3)
                                    }
                            }
                            .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
                            .accessibilityLabel(Text(L10n.t("ios.chat11.photo.remove", locale: .resolved())))
                        }
                    }
                    .padding(.horizontal, V3Metric.screenMargin)
                }
                .frame(height: 60)
            }
            HStack {
                Text(L10n.t("ios.chat11.camera.count", locale: .resolved(), vars: ["count": "\(shots.count)", "max": "\(room)"]))
                    .font(V3Font.label)
                    .foregroundStyle(Color.white.opacity(0.85))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onShoot) {
                    ZStack {
                        Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 78, height: 78)
                        Circle().fill(Color.white.opacity(isFull || !available ? 0.35 : 1)).frame(width: 62, height: 62)
                    }
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                .disabled(isFull || !available || capturing)
                .accessibilityLabel(Text(L10n.t("ios.chat11.camera.shoot", locale: .resolved())))
                Button(action: onDone) {
                    Text(L10n.t("ios.chat11.camera.done", locale: .resolved()))
                        .font(V3Font.buttonSecondary)
                        .foregroundStyle(shots.isEmpty ? Color.white.opacity(0.5) : V3Color.ctaInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 44)
                        .background(shots.isEmpty ? Color.white.opacity(0.15) : Color.white, in: Capsule())
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                .disabled(shots.isEmpty)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .padding(.bottom, 12)
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(V3Font.text(.body, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.45), in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(label))
    }
}
