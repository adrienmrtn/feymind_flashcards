import PDFKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - Ce qui sort de la caméra

/// Une page prise ou importée, et où en est sa lecture sur l'appareil.
struct ScanPage: Identifiable, Equatable {
    enum State: Equatable {
        case reading
        case read(String)
        /// Rien de lisible : la page reste dans la rangée, signalée, et ne part pas.
        case empty
    }

    var id = UUID()
    var image: UIImage
    var state: State = .reading

    var text: String {
        if case .read(let text) = state { return text }
        return ""
    }

    static func == (lhs: ScanPage, rhs: ScanPage) -> Bool {
        lhs.id == rhs.id && lhs.state == rhs.state
    }

    /// En dessous, une page ne dit rien.
    static let minimumCharacters = 12

    static func state(for text: String) -> State {
        let clean = TextSanitizer.normalizeExtractedText(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.count >= minimumCharacters ? .read(String(clean.prefix(MikaLimits.attachmentCharacters))) : .empty
    }
}

/// **Une capture prête** : le mode, la langue cible, les pages lues (ou le texte tapé).
struct ScanCapture: Identifiable {
    var id = UUID()
    var mode: ScanMode
    var target: UiLocale?
    var pages: [ScanPage]
    var typed: String = ""

    var firstText: String { pages.first(where: { !$0.text.isEmpty })?.text ?? typed }

    /// Six pages au plus : autant que de photos dans un message du chat (`ChatSession.maxPhotos`).
    static let maxPages = 6
}

/// Une capture passée de la caméra au chat dans une pile de navigation : comparée par son
/// identité (les photos ne se comparent pas).
final class ScanPayload: Hashable {
    let capture: ScanCapture
    init(_ capture: ScanCapture) { self.capture = capture }
    static func == (lhs: ScanPayload, rhs: ScanPayload) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

/// L'étape de la capture.
enum ScanStage: Equatable {
    /// La visée.
    case live
    /// La photo figée d'une question ou d'une équation : on ajuste le cadre.
    case still
    /// La lecture du cadre.
    case reading
    /// Rien ne s'est lu : de quoi reprendre.
    case unreadable
}

/// Ce que les commandes déclenchent.
struct ScanActions {
    var close: () -> Void = {}
    var shutter: () -> Void = {}
    var library: () -> Void = {}
    var files: () -> Void = {}
    var type: () -> Void = {}
    var torch: () -> Void = {}
    var mode: (ScanMode) -> Void = { _ in }
    var target: (UiLocale) -> Void = { _ in }
    var removePage: (UUID) -> Void = { _ in }
    var done: () -> Void = {}
    var retake: () -> Void = {}
    var confirm: () -> Void = {}
    var unlock: () -> Void = {}
}

/// Ce que l'écran montre, en une valeur : le branchement le remplit, les rendus aussi.
struct ScanChromeState {
    var mode: ScanMode = .solve
    var target: UiLocale = .en
    var stage: ScanStage = .live
    var cameraAvailable = true
    /// La caméra a été refusée (ou verrouillée) : on le dit, et la photothèque prend le relais.
    var cameraRefused = false
    var hasTorch = true
    var torchOn = false
    var pages: [ScanPage] = []
    var maxPages = ScanCapture.maxPages
    var offline = false
    var limitReached = false
    /// La caméra ouverte depuis une conversation : ses modes y répondent.
    var inChat = false

    var showsTorch: Bool { ScanTorch.isShown(hasTorch: hasTorch, cameraAvailable: cameraAvailable, live: stage == .live) }
    var isFull: Bool { pages.count >= maxPages }
    var isReading: Bool { pages.contains { $0.state == .reading } }
    var canFinish: Bool { !pages.isEmpty && !isReading }
}

// MARK: - L'écran, sans la caméra

/// **La caméra de Mika** (lot 12), dessinée sans appareil : le fond (la visée, la photo, ou
/// la page de démonstration des rendus), le cadre du mode, et les commandes. Plein écran,
/// noir, en thème marine quel que soit le réglage : la page est ce qu'on regarde.
///
/// De haut en bas : fermer, écrire, la lampe ; la phrase d'aide du mode ; le cadre ; les pages
/// déjà prises et « Envoyer » ; la langue cible (Traduire) ; **les pastilles des modes, juste
/// au-dessus du déclencheur** ; Photos, le déclencheur, Fichiers.
struct ScanCaptureChrome<Background: View>: View {
    let state: ScanChromeState
    @Binding var frame: CGRect
    var actions: ScanActions
    @ViewBuilder var background: Background

    var body: some View {
        // Les marges se lisent hors de `ignoresSafeArea` (la leçon du scanner) : dedans, la
        // zone sûre est nulle, et la croix montait sous l'encoche.
        GeometryReader { outer in
            chrome(insets: outer.safeAreaInsets)
        }
        .environment(\.colorScheme, .dark)
    }

    private func chrome(insets: EdgeInsets) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let top = max(insets.top, 20) + 4
            let bottom = max(insets.bottom, 12) + 8
            ZStack {
                background
                    .frame(width: size.width, height: size.height)
                    .clipped()

                if !state.cameraRefused || state.stage != .live {
                    framingOverlay(size: size, top: top, bottom: bottom)
                }

                VStack(spacing: 0) {
                    LinearGradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: top + 130)
                    Spacer(minLength: 0)
                    LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                        .frame(height: bottom + 320)
                }
                .allowsHitTesting(false)

                VStack(spacing: 10) {
                    topBar
                    notices
                    Spacer(minLength: 0)
                    if state.cameraRefused && state.stage == .live {
                        ScanRefusedCard(onLibrary: actions.library, onFiles: actions.files)
                            .padding(.horizontal, V3Metric.screenMargin)
                        Spacer(minLength: 0)
                    }
                    bottomArea
                }
                .padding(.top, top)
                .padding(.bottom, bottom)
            }
            .frame(width: size.width, height: size.height)
        }
        .background(Color.black)
        .ignoresSafeArea()
    }

    // MARK: Le cadre

    @ViewBuilder
    private func framingOverlay(size: CGSize, top: CGFloat, bottom: CGFloat) -> some View {
        switch state.mode.framing {
        case .question, .line:
            SolverCropOverlay(
                // Avant que l'écran ait posé son cadre (sa première passe), celui du mode.
                frame: Binding(
                    get: { frame == .zero ? Self.defaultFrame(for: state.mode, in: size) : frame },
                    set: { frame = $0 }
                ),
                bounds: size,
                editable: state.stage == .live || state.stage == .still,
                scanning: state.stage == .reading
            )
        case .page:
            if state.stage == .live {
                ScanPageGuide(rect: Self.pageRect(in: size, top: top, bottom: bottom))
            }
        }
    }

    /// Le contour d'une page, sous la phrase d'aide et au-dessus des pastilles et du
    /// déclencheur (les vignettes des pages prises peuvent mordre sur son bas).
    static func pageRect(in size: CGSize, top: CGFloat, bottom: CGFloat) -> CGRect {
        let available = max(160, size.height - (top + 104) - (bottom + 236))
        let width = min(size.width - 40, available / 1.3)
        let height = min(available, width * 1.42)
        return CGRect(x: (size.width - width) / 2, y: top + 104, width: width, height: height)
    }

    /// Le cadre de départ du mode : la question du scanner, ou la bande d'une équation.
    static func defaultFrame(for mode: ScanMode, in size: CGSize) -> CGRect {
        mode.framing == .line ? lineFrame(in: size) : SolverCrop.initialFrame(in: size)
    }

    /// Le cadre de départ d'une équation : une bande large et basse.
    static func lineFrame(in size: CGSize) -> CGRect {
        let width = size.width * 0.88
        let height: CGFloat = 112
        return CGRect(x: (size.width - width) / 2, y: size.height * 0.36, width: width, height: height)
    }

    // MARK: Le haut

    private var topBar: some View {
        HStack(spacing: 10) {
            round("xmark", label: L10n.t("ios.cal.close", locale: .resolved()), action: actions.close)
            Spacer(minLength: 0)
            if state.stage == .live {
                round("keyboard", label: L10n.t("ios.scan12.type", locale: .resolved()), action: actions.type)
            }
            if state.showsTorch {
                round(
                    state.torchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                    label: L10n.t(state.torchOn ? "ios.scan12.torch.off" : "ios.scan12.torch.on", locale: .resolved()),
                    active: state.torchOn,
                    action: actions.torch
                )
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
    }

    private func round(_ symbol: String, label: String, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(V3Font.text(.body, weight: .bold))
                .foregroundStyle(active ? Color(hex: 0x2A1E00) : Color.white)
                .frame(width: 44, height: 44)
                .background(active ? AnyShapeStyle(V3Color.yellow) : AnyShapeStyle(Color.black.opacity(0.45)), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(active ? 0 : 0.16), lineWidth: 1))
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// La phrase d'aide, puis ce qui empêche : hors ligne, la question offerte passée.
    private var notices: some View {
        VStack(spacing: 8) {
            if state.stage != .unreadable, !(state.cameraRefused && state.stage == .live) {
                HStack(spacing: 8) {
                    if state.stage == .reading {
                        ProgressView().tint(.white).controlSize(.small)
                    } else {
                        Image(systemName: state.mode.symbol)
                            .font(V3Font.text(.subheadline, weight: .bold))
                            .foregroundStyle(state.mode.tone)
                    }
                    Text(hint)
                        .font(V3Font.label)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.55), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                .padding(.horizontal, V3Metric.screenMargin)
                .accessibilityElement(children: .combine)
            }
            if state.offline {
                banner(symbol: "wifi.slash", text: L10n.t("ios.scan12.offline", locale: .resolved()), tone: Color.black.opacity(0.72), ink: .white)
            }
            if state.limitReached {
                Button(action: actions.unlock) {
                    HStack(spacing: 8) {
                        Text(L10n.t("ios.scan12.limit", locale: .resolved()))
                            .font(V3Font.label)
                            .foregroundStyle(Color(hex: 0x2A1E00))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: "PRO")
                            .font(V3Font.heading(15))
                            .foregroundStyle(V3Color.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: 0x2A1E00), in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(V3Color.yellow, in: Capsule())
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
                .padding(.horizontal, V3Metric.screenMargin)
            }
        }
    }

    private var hint: String {
        switch state.stage {
        case .still: L10n.t("ios.scan12.adjust", locale: .resolved())
        case .reading: L10n.t("ios.scan12.reading", locale: .resolved())
        default: state.mode.hint()
        }
    }

    private func banner(symbol: String, text: String, tone: Color, ink: Color) -> some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
        }
        .font(V3Font.caption)
        .foregroundStyle(ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tone, in: Capsule())
        .padding(.horizontal, V3Metric.screenMargin)
    }

    // MARK: Le bas

    @ViewBuilder
    private var bottomArea: some View {
        switch state.stage {
        case .live:
            VStack(spacing: 14) {
                if state.mode.takesSeveralPages, !state.pages.isEmpty {
                    ScanPagesRow(pages: state.pages, maxPages: state.maxPages, canFinish: state.canFinish, onRemove: actions.removePage, onDone: actions.done)
                }
                if state.mode == .translate {
                    ScanTargetPicker(target: state.target, onPick: actions.target)
                }
                ScanModePicker(selected: state.mode, onPick: actions.mode)
                if !state.cameraRefused {
                    controls
                }
            }
        case .still, .reading:
            ScanButtonPair(
                primary: V3Button(L10n.t("ios.scan12.read", locale: .resolved()), systemImage: "text.viewfinder", isLoading: state.stage == .reading, action: actions.confirm),
                secondary: V3Button(L10n.t("ios.scan12.retake", locale: .resolved()), systemImage: "arrow.counterclockwise", kind: .secondary, action: actions.retake)
            )
            .disabled(state.stage == .reading)
            .padding(.horizontal, V3Metric.screenMargin)
        case .unreadable:
            ScanUnreadableCard(onRetake: actions.retake, onType: actions.type)
                .padding(.horizontal, V3Metric.screenMargin)
        }
    }

    private var controls: some View {
        HStack(alignment: .center, spacing: 0) {
            side("photo.on.rectangle.angled", L10n.t("ios.scan12.photos", locale: .resolved()), action: actions.library)
            Spacer(minLength: 8)
            Button(action: actions.shutter) {
                ZStack {
                    Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 80, height: 80)
                    Circle().fill(Color.white.opacity(shutterEnabled ? 1 : 0.3)).frame(width: 64, height: 64)
                    Image(systemName: state.mode.symbol)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(V3Color.bg.opacity(shutterEnabled ? 1 : 0.5))
                }
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .disabled(!shutterEnabled)
            .accessibilityLabel(Text(L10n.t("ios.scan12.shutter", locale: .resolved(), vars: ["mode": state.mode.title()])))
            Spacer(minLength: 8)
            side("doc.fill", L10n.t("ios.scan12.files", locale: .resolved()), action: actions.files)
        }
        .padding(.horizontal, V3Metric.screenMargin)
    }

    private var shutterEnabled: Bool {
        state.cameraAvailable && !state.cameraRefused && !(state.mode.takesSeveralPages && state.isFull)
    }

    private func side(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(V3Font.text(.title3, weight: .semibold))
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                Text(title)
                    .font(V3Font.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(Color.white)
            .frame(width: 88)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .disabled(state.mode.takesSeveralPages && state.isFull)
    }
}

/// Le contour d'une page : l'extérieur assombri, quatre coins blancs. Il ne se règle pas : la
/// page entière part, Vision y trouve les lignes.
struct ScanPageGuide: View {
    let rect: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { path in
                path.addRect(CGRect(x: -2000, y: -2000, width: 6000, height: 6000))
                path.addRoundedRect(in: rect, cornerSize: CGSize(width: 18, height: 18))
            }
            .fill(Color.black.opacity(0.38), style: FillStyle(eoFill: true))
            SolverFrameCorners()
                .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityHidden(true)
    }
}

/// **Les pastilles des modes**, sur une ligne qui défile ; celle du mode choisi est blanche.
struct ScanModePicker: View {
    let selected: ScanMode
    let onPick: (ScanMode) -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        Group {
            if still {
                // Les rendus ne dessinent pas ce qui défile : la même rangée, coupée au bord.
                Color.clear
                    .frame(height: 40)
                    .overlay(alignment: .leading) {
                        row.fixedSize().padding(.leading, V3Metric.screenMargin)
                    }
                    .clipped()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        row.padding(.horizontal, V3Metric.screenMargin)
                    }
                    .onAppear { proxy.scrollTo(selected, anchor: .center) }
                    .onChange(of: selected) { _, mode in
                        withAnimation(MicaboMotion.standard) { proxy.scrollTo(mode, anchor: .center) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(L10n.t("ios.scan12.modes", locale: .resolved())))
    }

    private var row: some View {
        HStack(spacing: 8) {
            ForEach(ScanMode.ordered) { mode in
                let isOn = mode == selected
                Button { onPick(mode) } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.symbol)
                            .font(V3Font.text(.footnote, weight: .bold))
                            .foregroundStyle(isOn ? V3Color.bg : mode.tone)
                        Text(mode.title())
                            .font(V3Font.label)
                            .foregroundStyle(isOn ? V3Color.bg : Color.white)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(isOn ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.black.opacity(0.5)), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(isOn ? 0 : 0.18), lineWidth: 1))
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .selection))
                .id(mode)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

/// « Vers : anglais », la langue de la traduction : un menu des langues que Mika sait viser.
struct ScanTargetPicker: View {
    let target: UiLocale
    let onPick: (UiLocale) -> Void

    var body: some View {
        Menu {
            ForEach(ScanTranslation.targets, id: \.self) { locale in
                Button {
                    onPick(locale)
                } label: {
                    if locale == target {
                        Label(ScanTranslation.name(of: locale), systemImage: "checkmark")
                    } else {
                        Text(ScanTranslation.name(of: locale))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundStyle(V3Color.iconLilac)
                Text(L10n.t("ios.scan12.target", locale: .resolved(), vars: ["language": ScanTranslation.name(of: target)]))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(V3Font.text(.caption2, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .font(V3Font.label)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Color.white.opacity(0.14), in: Capsule())
        }
        .accessibilityLabel(Text(L10n.t("ios.scan12.target", locale: .resolved(), vars: ["language": ScanTranslation.name(of: target)])))
    }
}

/// Les pages déjà prises, en vignettes retirables, le compte, et « Envoyer ».
struct ScanPagesRow: View {
    let pages: [ScanPage]
    let maxPages: Int
    let canFinish: Bool
    let onRemove: (UUID) -> Void
    let onDone: () -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                thumbnails
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onDone) {
                    HStack(spacing: 6) {
                        Text(L10n.t("ios.scan12.send", locale: .resolved()))
                        Image(systemName: "arrow.up")
                            .font(V3Font.text(.footnote, weight: .heavy))
                    }
                    .font(V3Font.heading(18, weight: .heavy))
                    .foregroundStyle(V3Color.bg)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .background(Color.white.opacity(canFinish ? 1 : 0.45), in: Capsule())
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                .disabled(!canFinish)
                .fixedSize()
            }
            .padding(.horizontal, V3Metric.screenMargin)
            if let empty = pages.firstIndex(where: { $0.state == .empty }) {
                Text(L10n.t("ios.scan12.pageEmpty", locale: .resolved(), vars: ["n": "\(empty + 1)"]))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.yellow)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, V3Metric.screenMargin)
            }
        }
    }

    @ViewBuilder
    private var thumbnails: some View {
        let row = HStack(spacing: 8) {
            ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                thumbnail(page, number: index + 1)
            }
            Text(verbatim: "\(pages.count)/\(maxPages)")
                .font(V3Font.label)
                .foregroundStyle(Color.white.opacity(0.8))
                .monospacedDigit()
                .fixedSize()
        }
        .padding(.top, 6)
        .padding(.trailing, 6)
        if still {
            row
        } else {
            ScrollView(.horizontal, showsIndicators: false) { row }
        }
    }

    private func thumbnail(_ page: ScanPage, number: Int) -> some View {
        Image(uiImage: page.image)
            .resizable()
            .scaledToFill()
            .frame(width: 44, height: 58)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                switch page.state {
                case .reading:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.5))
                        ProgressView().tint(.white).controlSize(.small)
                    }
                case .empty:
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.35))
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(V3Color.yellow, lineWidth: 2)
                        Image(systemName: "eye.slash.fill").font(V3Font.text(.footnote, weight: .bold)).foregroundStyle(V3Color.yellow)
                    }
                case .read:
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button { onRemove(page.id) } label: {
                    Image(systemName: "xmark")
                        .font(V3Font.text(.caption2, weight: .heavy))
                        .foregroundStyle(Color.white)
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.75), in: Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
                .offset(x: 7, y: -7)
                .accessibilityLabel(Text(L10n.t("ios.scan12.removePage", locale: .resolved(), vars: ["n": "\(number)"])))
            }
    }
}

/// **Rien ne s'est lu** : ce qu'on peut faire, sans reproche.
struct ScanUnreadableCard: View {
    let onRetake: () -> Void
    let onType: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                MikaMascot(mood: .sad, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.t("ios.scan12.unreadable.title", locale: .resolved()))
                        .font(V3Font.cardTitle)
                        .foregroundStyle(V3Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("ios.scan12.unreadable.body", locale: .resolved()))
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            ScanButtonPair(
                primary: V3Button(L10n.t("ios.scan12.retake", locale: .resolved()), systemImage: "camera.fill", action: onRetake),
                secondary: V3Button(L10n.t("ios.scan12.type", locale: .resolved()), systemImage: "keyboard", kind: .secondary, action: onType)
            )
        }
        .padding(18)
        .v3Card(radius: V3Metric.radiusCard)
    }
}

/// Deux boutons empilés, le principal en haut : côte à côte, « Reprendre » se coupait en deux
/// lignes sur un iPhone SE (rendu `scan12-camera-illisible-se`).
struct ScanButtonPair: View {
    let primary: V3Button
    let secondary: V3Button

    var body: some View {
        VStack(spacing: 10) {
            primary
            secondary
        }
    }
}

/// **La caméra est refusée** : on le dit simplement, et on passe à la photothèque et aux
/// fichiers. Aucun renvoi vers les Réglages : c'est ce que l'App Store a refusé le 17 septembre
/// (règle 5.1.1(iv), `CameraAccessTests`).
struct ScanRefusedCard: View {
    let onLibrary: () -> Void
    let onFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "camera.fill")
                .font(V3Font.text(.title2, weight: .semibold))
                .foregroundStyle(V3Color.iconPink)
                .frame(width: 48, height: 48)
                .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusBadge, style: .continuous))
                .accessibilityHidden(true)
            Text(L10n.t("ios.scan12.refused.title", locale: .resolved()))
                .font(V3Font.cardTitle)
                .foregroundStyle(V3Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.t("ios.scan12.refused.body", locale: .resolved()))
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink2)
                .fixedSize(horizontal: false, vertical: true)
            ScanButtonPair(
                primary: V3Button(L10n.t("ios.scan12.photos", locale: .resolved()), systemImage: "photo.on.rectangle.angled", action: onLibrary),
                secondary: V3Button(L10n.t("ios.scan12.files", locale: .resolved()), systemImage: "doc.fill", kind: .secondary, action: onFiles)
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(radius: V3Metric.radiusCard)
    }
}

/// **La page de démonstration** des rendus et du simulateur, qui n'a pas de caméra : une feuille
/// de cours posée sur un bureau.
struct ScanDemoDesk: View {
    var lines: [String]

    var body: some View {
        SolverDemoDesk(lines: lines)
    }
}

/// **Des fichiers en pages** : une image telle quelle ; un PDF, page par page, avec son texte
/// quand il en porte un (sinon la page se lit comme une photo).
enum ScanFileLoader {
    struct Loaded {
        var image: UIImage
        var text: String?
    }

    static func load(_ urls: [URL], limit: Int) -> [Loaded] {
        var out: [Loaded] = []
        for url in urls where out.count < limit {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if url.pathExtension.lowercased() == "pdf", let document = PDFDocument(url: url) {
                for index in 0..<document.pageCount where out.count < limit {
                    guard let page = document.page(at: index) else { continue }
                    let bounds = page.bounds(for: .mediaBox)
                    let scale = 1600 / max(bounds.width, bounds.height, 1)
                    let image = page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
                    out.append(Loaded(image: image, text: page.string))
                }
            } else if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                out.append(Loaded(image: SolverImage.normalized(image), text: nil))
            }
        }
        return out
    }
}

// MARK: - L'écran, branché

/// Où la caméra a été ouverte.
enum ScanContext: Equatable {
    /// Depuis la Home ou la feuille Outils : « Résoudre » garde le scanner pas à pas.
    case standalone
    /// Depuis une conversation : tout revient dans cette conversation.
    case chat
}

/// **La caméra de Mika, branchée** : l'appareil, la lampe, le zoom et la mise au point (la
/// visée qu'on pince et qu'on touche), la photothèque, les fichiers, la saisie, et la lecture
/// des pages sur l'appareil.
///
/// La session de la caméra démarre à l'apparition et s'arrête à la disparition, au passage en
/// arrière-plan, et dès qu'une photo est figée ; la lampe s'éteint avec elle.
struct ScanCaptureView: View {
    var context: ScanContext = .standalone
    var initialMode: ScanMode?
    /// « Résoudre » depuis la caméra seule : l'énoncé lu part au scanner pas à pas.
    var onSolve: ((_ statement: String, _ source: SolverSource, _ thumbnail: Data?) -> Void)?
    let onCapture: (ScanCapture) -> Void
    let onClose: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(ProAccess.self) private var pro: ProAccess?

    @State private var camera = SolverCamera()
    @State private var connectivity = HomeConnectivity()
    @State private var mode: ScanMode = ScanModeMemory().mode
    @State private var target: UiLocale = ScanModeMemory().target()
    @State private var stage: ScanStage = .live
    @State private var frame: CGRect = .zero
    @State private var container: CGSize = .zero
    @State private var still: UIImage?
    @State private var stillFit: SolverCrop.Fit = .fill
    @State private var stillSource: SolverSource = .camera
    @State private var pages: [ScanPage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsPicker = false
    @State private var showsFiles = false
    @State private var typing = false
    @State private var reader: Task<Void, Never>?
    @State private var cameraAllowed = CameraAccess.allowsScanner(CameraAccess.status)
    @State private var paywall: PaywallTrigger?
    @State private var started = false

    private let memory = ScanModeMemory()
    private var cameraAvailable: Bool { SolverCamera.isAvailable && cameraAllowed }
    private var isPro: Bool { pro?.isPro ?? false }

    private var chromeState: ScanChromeState {
        ScanChromeState(
            mode: mode,
            target: target,
            stage: stage,
            cameraAvailable: cameraAvailable,
            cameraRefused: CameraAccess.isRefused(CameraAccess.status) && SolverCamera.isAvailable,
            hasTorch: camera.hasTorch,
            torchOn: camera.torchOn,
            pages: pages,
            offline: !connectivity.isOnline,
            limitReached: MikaQuota().gate(isPro: isPro) == .paywall,
            inChat: context == .chat
        )
    }

    var body: some View {
        ScanCaptureChrome(state: chromeState, frame: $frame, actions: actions) {
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
        .photosPicker(
            isPresented: $showsPicker,
            selection: $pickerItems,
            maxSelectionCount: mode.takesSeveralPages ? max(1, ScanCapture.maxPages - pages.count) : 1,
            selectionBehavior: .ordered,
            matching: .images
        )
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            pickerItems = []
            load(items)
        }
        .fileImporter(isPresented: $showsFiles, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: mode.takesSeveralPages) { result in
            if case .success(let urls) = result { importFiles(urls) }
        }
        .sheet(isPresented: $typing) {
            SolverTypeSheet { text in
                typing = false
                typed(text)
            }
        }
        .micaboPaywall($paywall)
        .onAppear {
            if !started {
                started = true
                if let initialMode { choose(initialMode) }
                Analytics.track(.scanOpened, ["mode": .text(mode.analyticsName), "context": .text(context == .chat ? "chat" : "standalone")])
            }
            connectivity.start()
            startCamera()
        }
        .onDisappear {
            reader?.cancel()
            camera.stop()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, stage == .live { startCamera() } else if phase != .active { camera.stop() }
        }
    }

    private var actions: ScanActions {
        ScanActions(
            close: close,
            shutter: shoot,
            library: { showsPicker = true },
            files: { showsFiles = true },
            type: { typing = true },
            torch: camera.toggleTorch,
            mode: choose,
            target: { locale in
                target = locale
                memory.remember(target: locale)
            },
            removePage: { id in pages.removeAll { $0.id == id } },
            done: finishPages,
            retake: retake,
            confirm: confirm,
            unlock: { paywall = .mika }
        )
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
            ScanCameraPreview(camera: camera)
        } else {
            SolverNoCamera()
        }
    }

    // MARK: Les gestes

    private func choose(_ next: ScanMode) {
        guard next != mode else { return }
        let framingChanged = next.framing != mode.framing
        mode = next
        memory.mode = next
        if framingChanged {
            // Une question ou une équation ne garde pas les pages d'un autre mode.
            if !next.takesSeveralPages { pages = [] }
            resetFrame()
        }
        Analytics.track(.scanModeChosen, ["mode": .text(next.analyticsName)])
    }

    private func place(in size: CGSize) {
        guard size.width > 0, size != container else { return }
        container = size
        resetFrame()
    }

    private func resetFrame() {
        guard container.width > 0 else { return }
        frame = mode.framing == .line ? ScanCaptureChrome<EmptyView>.lineFrame(in: container) : SolverCrop.initialFrame(in: container)
    }

    private func startCamera() {
        guard SolverCamera.isAvailable else { return }
        Task {
            // La question système une fois ; sur un non, la photothèque et les fichiers restent.
            let allowed = await CameraAccess.request()
            cameraAllowed = allowed
            if allowed, still == nil, stage == .live { camera.start() }
        }
    }

    private func close() {
        reader?.cancel()
        camera.stop()
        onClose()
    }

    private func shoot() {
        guard cameraAvailable else { return }
        Haptics.medium()
        Task {
            guard let image = await camera.capture() else { return }
            if mode.takesSeveralPages {
                guard pages.count < ScanCapture.maxPages else { return }
                addPages([image])
            } else {
                camera.stop()
                still = image
                stillFit = .fill
                stillSource = .camera
                stage = .still
            }
        }
    }

    /// Des pages arrivent : chacune se lit tout de suite, sur l'appareil.
    private func addPages(_ images: [UIImage], texts: [String?] = []) {
        for (index, image) in images.enumerated() where pages.count < ScanCapture.maxPages {
            let known = index < texts.count ? texts[index] : nil
            var page = ScanPage(image: image)
            if let known, known.count >= ScanPage.minimumCharacters { page.state = ScanPage.state(for: known) }
            pages.append(page)
            guard page.state == .reading else { continue }
            let id = page.id
            Task {
                let text = await OnDeviceOCR.recognize(in: SolverImage.normalized(image, maxDimension: 2400))
                guard let at = pages.firstIndex(where: { $0.id == id }) else { return }
                pages[at].state = ScanPage.state(for: text)
                if pages[at].state == .empty { Haptics.warning() }
            }
        }
        Haptics.light()
    }

    private func finishPages() {
        let readable = pages.filter { !$0.text.isEmpty }
        guard !readable.isEmpty else {
            Haptics.warning()
            Analytics.track(.scanUnreadable, ["mode": .text(mode.analyticsName)])
            stage = .unreadable
            camera.stop()
            return
        }
        deliver(ScanCapture(mode: mode, target: mode == .translate ? target : nil, pages: readable))
        pages = []
    }

    private func deliver(_ capture: ScanCapture) {
        Analytics.track(.scanCaptured, [
            "mode": .text(capture.mode.analyticsName),
            "pages": .number(Double(capture.pages.count)),
            "typed": .flag(!capture.typed.isEmpty),
        ])
        onCapture(capture)
    }

    private func load(_ items: [PhotosPickerItem]) {
        Task {
            var images: [UIImage] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    images.append(SolverImage.normalized(image))
                }
            }
            guard !images.isEmpty else {
                stage = .unreadable
                return
            }
            receive(images, source: .library)
        }
    }

    /// Des images venues de la photothèque ou des fichiers : des pages, ou la photo à cadrer.
    private func receive(_ images: [UIImage], texts: [String?] = [], source: SolverSource) {
        if mode.takesSeveralPages {
            addPages(images, texts: texts)
        } else if let first = images.first {
            camera.stop()
            still = first
            stillFit = .fit
            stillSource = source
            frame = libraryFrame(for: first.size)
            stage = .still
        }
    }

    /// Des fichiers : des images, ou les pages d'un PDF (son texte quand il en a, sinon l'image
    /// de la page, lue comme une photo).
    private func importFiles(_ urls: [URL]) {
        let loaded = ScanFileLoader.load(urls, limit: ScanCapture.maxPages)
        guard !loaded.isEmpty else {
            stage = .unreadable
            return
        }
        receive(loaded.map(\.image), texts: loaded.map(\.text), source: .library)
    }

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
        resetFrame()
        startCamera()
    }

    /// La question ou l'équation cadrée est lue ; « Résoudre » seul part au scanner pas à pas.
    private func confirm() {
        guard let still, stage == .still else { return }
        let rect = SolverCrop.imageRect(for: frame, image: still.size, in: container, fit: stillFit)
        let cropped = rect.map { SolverImage.cropped(still, to: $0) } ?? still
        let source = stillSource
        let current = mode
        stage = .reading
        reader?.cancel()
        reader = Task {
            let text = await OnDeviceOCR.recognizeExercise(in: cropped, preferred: [UiLocale.resolved().bcp47])
            guard !Task.isCancelled, stage == .reading else { return }
            let state = ScanPage.state(for: text)
            guard case .read(let clean) = state, clean.count >= SolverFlow.minimumCharacters else {
                Haptics.warning()
                Analytics.track(.scanUnreadable, ["mode": .text(current.analyticsName)])
                stage = .unreadable
                return
            }
            if current == .solve, context == .standalone, let onSolve {
                Analytics.track(.solverCaptured, ["source": .text(source.rawValue), "subject": .text(SolverSubjectGuess.guess(clean).rawValue)])
                onSolve(clean, source, SolverImage.thumbnail(cropped))
            } else {
                deliver(ScanCapture(mode: current, pages: [ScanPage(image: cropped, state: state)]))
            }
            self.still = nil
            stage = .live
            resetFrame()
        }
    }

    /// Le texte tapé à la place d'une photo.
    private func typed(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 3 else { return }
        if mode == .solve, context == .standalone, let onSolve {
            Analytics.track(.solverCaptured, ["source": .text(SolverSource.typed.rawValue), "subject": .text(SolverSubjectGuess.guess(clean).rawValue)])
            onSolve(clean, .typed, nil)
        } else {
            deliver(ScanCapture(mode: mode, target: mode == .translate ? target : nil, pages: [], typed: clean))
        }
        stage = .live
    }
}
