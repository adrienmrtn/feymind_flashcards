import PhotosUI
import SwiftUI
import UIKit

// MARK: - Ce que l'écran de capture montre

/// L'état de la capture. La visée d'abord ; puis la photo figée, où l'élève ajuste le cadre ;
/// la lecture ; et, si rien ne se lit, le message pour reprendre.
enum SolverCaptureStage: Equatable {
    case live
    case still
    case reading
    case unreadable
}

/// Ce que les boutons de l'écran de capture déclenchent.
struct SolverCaptureActions {
    var close: () -> Void = {}
    var shutter: () -> Void = {}
    var library: () -> Void = {}
    var type: () -> Void = {}
    var torch: () -> Void = {}
    var history: () -> Void = {}
    var tutor: () -> Void = {}
    var retake: () -> Void = {}
    var confirm: () -> Void = {}
}

/// **L'écran de capture, sans la caméra** : le fond (la visée, la photo, ou la scène de
/// démonstration des rendus), le cadre réglable, et les commandes. Plein écran et noir, comme
/// l'appareil photo du téléphone : la page est ce qu'on regarde.
struct SolverCaptureChrome<Background: View>: View {
    let stage: SolverCaptureStage
    @Binding var frame: CGRect
    var cameraAvailable: Bool
    var torchAvailable: Bool
    var torchOn: Bool
    var historyCount: Int
    var actions: SolverCaptureActions
    @ViewBuilder var background: Background

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                background
                    .frame(width: size.width, height: size.height)
                    .clipped()

                SolverCropOverlay(frame: $frame, bounds: size, editable: stage == .live || stage == .still, scanning: stage == .reading)

                // Un voile en haut et en bas : les commandes restent lisibles sur une feuille blanche.
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: proxy.safeAreaInsets.top + 120)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
                        .frame(height: proxy.safeAreaInsets.bottom + 300)
                }
                .allowsHitTesting(false)

                instruction
                    .position(x: size.width / 2, y: max(frame.minY - 30, proxy.safeAreaInsets.top + 70))

                VStack(spacing: 0) {
                    topBar
                        .environment(\.colorScheme, .dark)
                        .padding(.top, proxy.safeAreaInsets.top + 8)
                    Spacer(minLength: 0)
                    bottom
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 16) + 8)
                }
                .padding(.horizontal, MicaboSpacing.screen)
            }
            .frame(width: size.width, height: size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // MARK: Le haut

    private var topBar: some View {
        HStack(spacing: 12) {
            glassButton("xmark", label: L10n.t("lesson.circle.close", locale: .resolved()), action: actions.close)
            Spacer(minLength: 0)
            if stage == .live, torchAvailable {
                glassButton(torchOn ? "bolt.fill" : "bolt.slash.fill", label: solveText(torchOn ? "capture.flashOff" : "capture.flashOn"), active: torchOn, action: actions.torch)
            }
        }
    }

    private func glassButton(_ symbol: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(active ? MicaboBrand.ink : .white)
                .frame(width: 44, height: 44)
                .background(active ? AnyShapeStyle(MicaboBrand.pencil) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel(Text(label))
    }

    private var instruction: some View {
        let key: String = switch stage {
        case .live: "capture.hint"
        case .still: "capture.adjust"
        case .reading: "capture.reading"
        case .unreadable: "capture.hint"
        }
        return HStack(spacing: 8) {
            if stage == .reading {
                ProgressView().tint(.white).controlSize(.small)
            }
            Text(solveText(key))
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.55), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 320)
        .opacity(stage == .unreadable ? 0 : 1)
        .allowsHitTesting(false)
    }

    // MARK: Le bas

    @ViewBuilder
    private var bottom: some View {
        switch stage {
        case .live:
            liveControls.environment(\.colorScheme, .dark)
        case .still, .reading:
            stillControls.environment(\.colorScheme, .dark)
        case .unreadable:
            SolverUnreadableCard(onRetake: actions.retake, onType: actions.type)
        }
    }

    private var liveControls: some View {
        VStack(spacing: 22) {
            HStack(spacing: 10) {
                pill(icon: "clock.arrow.circlepath", text: solveText("capture.history"), badge: historyCount, action: actions.history)
                pill(icon: "bubble.left.and.bubble.right.fill", text: solveText("capture.askMika"), badge: 0, action: actions.tutor)
            }
            HStack(alignment: .center) {
                sideButton(icon: "photo.on.rectangle", text: solveText("capture.library"), action: actions.library)
                Spacer(minLength: 0)
                Button(action: actions.shutter) {
                    ZStack {
                        Circle().strokeBorder(Color.white, lineWidth: 5).frame(width: 82, height: 82)
                        Circle().fill(cameraAvailable ? MicaboBrand.blue : Color.white.opacity(0.25)).frame(width: 64, height: 64)
                        Image(systemName: "viewfinder")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                .disabled(!cameraAvailable)
                .accessibilityLabel(Text(solveText("capture.shutter")))
                Spacer(minLength: 0)
                sideButton(icon: "character.cursor.ibeam", text: solveText("capture.type"), action: actions.type)
            }
        }
    }

    private var stillControls: some View {
        HStack(spacing: 12) {
            Button(action: actions.retake) {
                Label(solveText("capture.retake"), systemImage: "arrow.counterclockwise")
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(MicaboPressableButtonStyle())
            Button(action: actions.confirm) {
                Label(solveText("capture.confirm"), systemImage: "text.viewfinder")
                    .font(MicaboFont.ui(17, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(MicaboBrand.blue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
        }
        .disabled(stage == .reading)
        .opacity(stage == .reading ? 0.5 : 1)
    }

    private func pill(icon: String, text: String, badge: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                Text(text)
                    .font(MicaboFont.ui(14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if badge > 0 {
                    Text("\(badge)")
                        .font(MicaboFont.ui(12, weight: .heavy))
                        .foregroundStyle(MicaboBrand.ink)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(MicaboBrand.pencil, in: Capsule())
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    private func sideButton(icon: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(text)
                    .font(MicaboFont.ui(13, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .frame(width: 92)
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}

// MARK: - Le cadre

/// **Le cadre de recadrage** : l'extérieur assombri, quatre coins blancs, et des poignées aux
/// coins pour l'agrandir ; on le déplace en le faisant glisser. Une seule question dedans.
struct SolverCropOverlay: View {
    @Binding var frame: CGRect
    let bounds: CGSize
    var editable: Bool
    var scanning: Bool = false

    @State private var start: CGRect?
    @State private var sweep = false

    private enum Handle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight, move
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(CGRect(origin: .zero, size: bounds))
                path.addRoundedRect(in: frame, cornerSize: CGSize(width: 20, height: 20))
            }
            .fill(Color.black.opacity(0.52), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)

            SolverFrameCorners()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: frame.width, height: frame.height)
                .offset(x: frame.minX, y: frame.minY)
                .allowsHitTesting(false)

            if scanning {
                LinearGradient(colors: [MicaboBrand.blue.opacity(0), MicaboBrand.blue.opacity(0.55), MicaboBrand.blue.opacity(0)], startPoint: .top, endPoint: .bottom)
                    .frame(width: frame.width - 16, height: 40)
                    .offset(x: frame.minX + 8, y: frame.minY + (sweep ? frame.height - 48 : 8))
                    // La lecture de la photo est une attente : seule boucle permise, et aucune
                    // avec « Réduire les animations ».
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: sweep) // attente
                    .onAppear { sweep = !LearnMotion.reduceMotion }
                    .onDisappear { sweep = false }
                    .allowsHitTesting(false)
            }

            if editable {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: max(frame.width - 60, 1), height: max(frame.height - 60, 1))
                    .offset(x: frame.minX + 30, y: frame.minY + 30)
                    .gesture(drag(.move))
                    .accessibilityHidden(true)
                ForEach([Handle.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { handle in
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 56, height: 56)
                        .contentShape(Circle())
                        .position(point(of: handle))
                        .gesture(drag(handle))
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
        // Des coordonnées d'écran : le cadre ne se retourne pas en arabe.
        .environment(\.layoutDirection, .leftToRight)
    }

    private func point(of handle: Handle) -> CGPoint {
        switch handle {
        case .topLeft: CGPoint(x: frame.minX, y: frame.minY)
        case .topRight: CGPoint(x: frame.maxX, y: frame.minY)
        case .bottomLeft: CGPoint(x: frame.minX, y: frame.maxY)
        case .bottomRight: CGPoint(x: frame.maxX, y: frame.maxY)
        case .move: CGPoint(x: frame.midX, y: frame.midY)
        }
    }

    private func drag(_ handle: Handle) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let origin = start ?? frame
                if start == nil { start = frame }
                let dx = value.translation.width
                let dy = value.translation.height
                var next = origin
                switch handle {
                case .move:
                    next = origin.offsetBy(dx: dx, dy: dy)
                case .topLeft:
                    next = CGRect(x: origin.minX + dx, y: origin.minY + dy, width: origin.width - dx, height: origin.height - dy)
                case .topRight:
                    next = CGRect(x: origin.minX, y: origin.minY + dy, width: origin.width + dx, height: origin.height - dy)
                case .bottomLeft:
                    next = CGRect(x: origin.minX + dx, y: origin.minY, width: origin.width - dx, height: origin.height + dy)
                case .bottomRight:
                    next = CGRect(x: origin.minX, y: origin.minY, width: origin.width + dx, height: origin.height + dy)
                }
                if next.width < 80 || next.height < 60, handle != .move { return }
                frame = SolverCrop.clamped(next, in: bounds, minimum: 60)
            }
            .onEnded { _ in
                start = nil
                Haptics.selection()
            }
    }
}

/// Les quatre coins du cadre, en équerres arrondies.
struct SolverFrameCorners: Shape {
    var length: CGFloat = 28
    var radius: CGFloat = 20

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = min(length, rect.width / 3, rect.height / 3)
        let r = min(radius, l)
        // Haut gauche
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // Haut droit
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // Bas droit
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // Bas gauche
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return path
    }
}

/// **Une photo illisible** : ce que Mika en dit, et de quoi reprendre. Mika en buste, collé au
/// bord bas de la carte, sur la surface claire.
struct SolverUnreadableCard: View {
    var onRetake: () -> Void
    var onType: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            SolverMikaCard(mood: .sad) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(solveText("unreadable.title"))
                        .font(MicaboFont.ui(18, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(solveText("unreadable.body"))
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 12) {
                Button(action: onType) {
                    Label(solveText("capture.type"), systemImage: "character.cursor.ibeam")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
                Button(action: onRetake) {
                    Label(solveText("capture.retake"), systemImage: "camera.fill")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }
        }
    }
}

/// **La scène de démonstration** des rendus et du simulateur : une feuille d'exercices posée
/// sur un bureau, parce que la CI n'a pas de caméra. Elle n'est jamais vue sur un téléphone
/// qui a un appareil photo.
struct SolverDemoDesk: View {
    var lines: [String] = [
        "Exercice 3",
        "Résoudre l'équation suivante :",
        "2x² − 8x + 6 = 0",
        "Exercice 4",
        "Calculer la dérivée de f(x) = x³ − 3x",
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x3A3027), Color(hex: 0x1E1813)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text(line)
                        .font(.system(size: index % 3 == 0 ? 20 : 19, weight: index % 3 == 0 ? .bold : .regular, design: .serif))
                        .foregroundStyle(Color(hex: 0x1F2430))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        // Un blanc entre deux exercices : le cadre n'en prend qu'un.
                        .padding(.top, index == 3 ? 44 : 0)
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 124)
            .frame(width: 360, height: 640, alignment: .topLeading)
            .background(
                LinearGradient(colors: [Color(hex: 0xFBFAF6), Color(hex: 0xEDEAE1)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay(alignment: .leading) {
                VStack(spacing: 26) {
                    ForEach(0..<14, id: \.self) { _ in
                        Rectangle().fill(Color(hex: 0x9DB7E8).opacity(0.35)).frame(height: 1)
                    }
                }
                .padding(.top, 74)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.45), radius: 22, y: 12)
            .rotationEffect(.degrees(-3))
            .offset(y: 30)
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

/// La visée quand l'appareil n'a pas de caméra (le simulateur), ou qu'elle est refusée.
struct SolverNoCamera: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x1B1E24), Color(hex: 0x0B0C10)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 10) {
                Image(systemName: "camera.metering.unknown")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
                Text(solveText("capture.noCamera"))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 48)
            }
        }
    }
}

// MARK: - L'écran, avec la caméra

/// **L'écran de capture, branché** : la caméra, la photothèque, la saisie, et la lecture de
/// l'énoncé sur l'appareil. Rend un énoncé lu à `onRead`, qui ouvre la solution.
struct SolverCaptureView: View {
    var historyCount: Int
    var onClose: () -> Void
    var onHistory: () -> Void
    var onTutor: () -> Void
    var onRead: (_ statement: String, _ source: SolverSource, _ thumbnail: Data?) -> Void

    @State private var camera = SolverCamera()
    @State private var stage: SolverCaptureStage = .live
    @State private var frame: CGRect = .zero
    @State private var container: CGSize = .zero
    @State private var still: UIImage?
    @State private var stillFit: SolverCrop.Fit = .fill
    @State private var stillSource: SolverSource = .camera
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var typing = false
    @State private var reader: Task<Void, Never>?
    @State private var cameraAllowed = CameraAccess.allowsScanner(CameraAccess.status)
    @Environment(\.scenePhase) private var scenePhase

    private var cameraAvailable: Bool { SolverCamera.isAvailable && cameraAllowed }

    var body: some View {
        SolverCaptureChrome(
            stage: stage,
            frame: $frame,
            cameraAvailable: cameraAvailable,
            torchAvailable: camera.hasTorch,
            torchOn: camera.torchOn,
            historyCount: historyCount,
            actions: SolverCaptureActions(
                close: onClose,
                shutter: shoot,
                library: { showPicker = true },
                type: { typing = true },
                torch: camera.toggleTorch,
                history: onHistory,
                tutor: onTutor,
                retake: retake,
                confirm: confirm
            )
        ) {
            backdrop
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { place(in: proxy.size) }
                    .onChange(of: proxy.size) { _, size in place(in: size) }
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            load(item)
        }
        .sheet(isPresented: $typing) {
            SolverTypeSheet { text in
                typing = false
                Analytics.track(.solverCaptured, ["source": .text(SolverSource.typed.rawValue), "subject": .text(SolverSubjectGuess.guess(text).rawValue)])
                onRead(text, .typed, nil)
            }
        }
        .onAppear(perform: startCamera)
        .onDisappear {
            reader?.cancel()
            camera.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, stage == .live { startCamera() } else if phase != .active { camera.stop() }
        }
    }

    @ViewBuilder
    private var backdrop: some View {
        if let still {
            Color.black.overlay {
                Image(uiImage: still)
                    .resizable()
                    .aspectRatio(contentMode: stillFit == .fill ? .fill : .fit)
            }
        } else if cameraAvailable {
            SolverCameraPreview(session: camera.session)
        } else {
            SolverNoCamera()
        }
    }

    private func place(in size: CGSize) {
        guard size.width > 0, size != container else { return }
        container = size
        frame = SolverCrop.initialFrame(in: size)
    }

    private func startCamera() {
        guard SolverCamera.isAvailable else { return }
        Task {
            // La question système une fois, puis la visée sur un oui ; sur un non, la
            // photothèque et la saisie restent.
            let allowed = await CameraAccess.request()
            cameraAllowed = allowed
            if allowed, still == nil { camera.start() }
        }
    }

    private func shoot() {
        guard cameraAvailable else { return }
        Haptics.medium()
        Task {
            guard let image = await camera.capture() else { return }
            camera.stop()
            still = image
            stillFit = .fill
            stillSource = .camera
            stage = .still
        }
    }

    private func load(_ item: PhotosPickerItem) {
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                stage = .unreadable
                return
            }
            camera.stop()
            still = SolverImage.normalized(image)
            stillFit = .fit
            stillSource = .library
            frame = libraryFrame(for: still!.size)
            stage = .still
        }
    }

    /// Une photo de la photothèque est déjà cadrée : le cadre prend toute l'image, et l'élève
    /// le resserre s'il y a plusieurs questions.
    private func libraryFrame(for image: CGSize) -> CGRect {
        let shown = SolverCrop.displayedRect(image: image, in: container, fit: .fit)
        let inset = shown.insetBy(dx: 12, dy: 12)
        let usable = CGRect(x: 16, y: 120, width: container.width - 32, height: max(container.height - 360, 120))
        let target = inset.intersection(usable)
        return SolverCrop.clamped(target.isNull ? SolverCrop.initialFrame(in: container) : target, in: container)
    }

    private func retake() {
        reader?.cancel()
        still = nil
        stage = .live
        frame = SolverCrop.initialFrame(in: container)
        startCamera()
    }

    private func confirm() {
        guard let still, stage == .still else { return }
        let fit = stillFit
        let source = stillSource
        let rect = SolverCrop.imageRect(for: frame, image: still.size, in: container, fit: fit)
        let page = rect.map { SolverImage.cropped(still, to: $0) } ?? still
        stage = .reading
        reader?.cancel()
        reader = Task {
            let preferred = [UiLocale.resolved().bcp47]
            let text = await OnDeviceOCR.recognizeExercise(in: page, preferred: preferred)
            guard !Task.isCancelled, stage == .reading else { return }
            let clean = TextSanitizer.normalizeExtractedText(text).trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count >= SolverFlow.minimumCharacters else {
                Haptics.warning()
                Analytics.track(.solverUnreadable, ["source": .text(source.rawValue)])
                stage = .unreadable
                return
            }
            Analytics.track(.solverCaptured, ["source": .text(source.rawValue), "subject": .text(SolverSubjectGuess.guess(clean).rawValue)])
            onRead(clean, source, SolverImage.thumbnail(page))
            // De retour sur la capture, la visée repart à zéro.
            self.still = nil
            stage = .live
            frame = SolverCrop.initialFrame(in: container)
        }
    }
}

// MARK: - Écrire l'énoncé

/// **Taper ou coller l'énoncé**, pour une consigne qu'on a sous les yeux ailleurs que sur papier.
struct SolverTypeSheet: View {
    var onDone: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(solveText("type.title"))
                    .font(MicaboFont.pageTitle)
                    .foregroundStyle(MicaboColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                MicaboCircleButton(systemImage: "xmark", size: 34, accessibilityTitle: L10n.t("lesson.circle.close", locale: .resolved())) { dismiss() }
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(solveText("type.placeholder"))
                        .font(MicaboFont.ui(17, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(MicaboFont.ui(17, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .scrollContentBackground(.hidden)
                    .focused($focused)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
            }
            .frame(minHeight: 160)
            .solverCard(radius: 18)

            HStack(spacing: 12) {
                Button {
                    if let pasted = UIPasteboard.general.string { text = pasted }
                } label: {
                    Label(solveText("type.paste"), systemImage: "doc.on.clipboard")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
                Button {
                    onDone(text.trimmingCharacters(in: .whitespacesAndNewlines))
                } label: {
                    Text(solveText("type.continue"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3)
                .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 ? 0.5 : 1)
            }
            Spacer(minLength: 0)
        }
        .padding(MicaboSpacing.screen)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }
}
