import PhotosUI
import SwiftUI
import UIKit

/// Raccourci d'écriture : une phrase de « Corriger un texte » dans la langue de l'app.
func writingText(_ key: String, _ vars: [String: String] = [:]) -> String {
    L10n.t(key, locale: .resolved(), vars: vars)
}

/// Ce que les boutons de la relecture déclenchent.
struct WritingCoachActions {
    var check: () -> Void = {}
    var paste: () -> Void = {}
    var photo: () -> Void = {}
    var unlock: () -> Void = {}
    var copy: () -> Void = {}
    var edit: () -> Void = {}
    var restart: () -> Void = {}
}

// MARK: - Le contenu

/// **« Corriger un texte »** (lot 7) : l'élève colle, tape ou photographie un texte — une
/// rédaction, une lettre en anglais, un paragraphe d'histoire — et Mika le relit à son niveau :
/// un avis d'ensemble, chaque correction avec sa règle, un conseil, et le texte corrigé, qu'on
/// copie. Sans défilement ni barre : `WritingCoachView` les ajoute, et les rendus dessinent
/// ceci tel quel.
struct WritingCoachContent: View {
    @Bindable var session: WritingSession
    var isPro: Bool
    var focused: FocusState<Bool>.Binding
    var actions: WritingCoachActions
    /// Les rendus de la CI ne dessinent pas un `TextEditor` (un contrôle UIKit) : ils posent le
    /// texte à sa place, dans le même cadre.
    var editorStandIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch session.phase {
            case .editing, .failed:
                lead
                editor
                if case .failed(let failure) = session.phase {
                    message(failure)
                }
            case .checking:
                checking
            case .locked:
                editor
                locked
            case .reviewed:
                reviewed
            }
            if let notice = session.notice {
                message(notice)
            }
        }
    }

    // MARK: La saisie

    private var lead: some View {
        SolverMikaCard(mood: .write) {
            VStack(alignment: .leading, spacing: 10) {
                Text(writingText("ios.ku7.writing.lead"))
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !isPro, session.quota.hasFreeQuestion {
                    Label(solveText("review.free"), systemImage: "gift.fill")
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .foregroundStyle(MicaboColor.accentInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MicaboColor.accentWash, in: Capsule())
                }
            }
        }
    }

    /// Le texte, et sous un filet, son nombre de mots et de quoi le remplir : une seule carte.
    private var editor: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if session.text.isEmpty {
                    Text(writingText("ios.ku7.writing.placeholder"))
                        .font(MicaboFont.ui(17, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                if editorStandIn {
                    Text(session.text)
                        .font(MicaboFont.ui(17, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                } else {
                    TextEditor(text: $session.text)
                        .font(MicaboFont.ui(17, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)
                        .scrollContentBackground(.hidden)
                        .focused(focused)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .frame(minHeight: 200)
                        .disabled(session.phase == .checking || session.reading)
                }
            }
            Divider().overlay(MicaboColor.stroke)
            // Le compte et les deux pastilles sur une ligne ; sur deux quand la langue ou la taille
            // du texte ne les laisse pas tenir, plutôt qu'un « Einfüg… ».
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    status
                    Spacer(minLength: 8)
                    tools
                }
                VStack(alignment: .leading, spacing: 8) {
                    status
                    tools
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            if let failure = session.readFailure {
                Divider().overlay(MicaboColor.stroke)
                Text(failure)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.wrongInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .solverCard(radius: 20)
    }

    @ViewBuilder
    private var status: some View {
        if session.reading {
            HStack(spacing: 8) {
                ProgressView().tint(MicaboColor.accent)
                Text(writingText("ios.ku7.writing.reading"))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize()
            }
        } else {
            Text(writingText("ios.ku7.writing.words", ["count": "\(session.wordCount)"]))
                .font(MicaboFont.ui(14, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .monospacedDigit()
                .fixedSize()
        }
    }

    private var tools: some View {
        HStack(spacing: 8) {
            toolButton(solveText("type.paste"), systemImage: "doc.on.clipboard", action: actions.paste)
            toolButton(writingText("ios.ku7.writing.photo"), systemImage: "camera", action: actions.photo)
        }
    }

    private func toolButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(MicaboColor.accentInk)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(MicaboColor.accentWash, in: Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .disabled(session.reading || session.phase == .checking)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.ui(14, weight: .semibold))
            .foregroundStyle(MicaboColor.wrongInk)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: La relecture en cours

    private var checking: some View {
        VStack(spacing: 12) {
            SolverMikaCard(mood: .think) {
                HStack(spacing: 10) {
                    ProgressView().tint(MicaboColor.accent)
                    Text(writingText("ios.ku7.writing.checking"))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 14) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(MicaboColor.surfaceSunken).frame(width: 170, height: 10)
                        Capsule().fill(MicaboColor.surfaceMuted).frame(height: 8)
                        Capsule().fill(MicaboColor.surfaceMuted).frame(width: 210, height: 8)
                    }
                    if index < 2 { Divider().overlay(MicaboColor.stroke) }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .solverCard()
            .accessibilityHidden(true)
        }
    }

    // MARK: La porte

    private var locked: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(MicaboBrand.blue, in: Circle())
            Text(writingText("ios.ku7.writing.locked.title"))
                .font(MicaboFont.ui(19, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(writingText("ios.ku7.writing.locked.body"))
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .solverCard()
    }

    // MARK: La relecture

    @ViewBuilder
    private var reviewed: some View {
        if let review = session.review {
            if let plain = review.plain {
                SolverMikaNote {
                    SolverRichText(source: plain, size: 16)
                }
            } else {
                SolverMikaNote {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(writingText("ios.ku7.writing.summary"))
                            .font(MicaboFont.ui(13, weight: .heavy))
                            .foregroundStyle(MicaboColor.accentInk)
                        Text(review.summary ?? writingText("ios.ku7.writing.noFixes"))
                            .font(MicaboFont.ui(16, weight: .semibold))
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !review.fixes.isEmpty {
                    fixes(review.fixes)
                }
                if let tip = review.tip {
                    tipCard(tip)
                }
            }
            if !session.reviewedText.isEmpty, review.plain == nil {
                correctedCard
            }
            HStack(spacing: 8) {
                Button(action: actions.edit) {
                    Label(writingText("ios.ku7.writing.edit"), systemImage: "pencil")
                }
                Spacer(minLength: 8)
                Button(action: actions.restart) {
                    Label(writingText("ios.ku7.writing.again"), systemImage: "arrow.counterclockwise")
                }
            }
            .font(MicaboFont.ui(14, weight: .bold))
            .foregroundStyle(MicaboColor.accentInk)
            .buttonStyle(MicaboPressableButtonStyle())
            .padding(.top, 4)
        }
    }

    /// Les corrections dans une seule carte, séparées par un filet : le passage barré, sa
    /// correction, et la règle.
    private func fixes(_ fixes: [WritingFix]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            StudySectionTitle(title: writingText("ios.ku7.writing.fixes", ["count": "\(fixes.count)"]))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(fixes) { fix in
                    fixRow(fix)
                    if fix.id != fixes.last?.id {
                        Divider().overlay(MicaboColor.stroke).padding(.leading, 16)
                    }
                }
            }
            .solverCard()
        }
    }

    private func fixRow(_ fix: WritingFix) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(fix.original)
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(MicaboColor.wrongInk)
                .strikethrough(true, color: MicaboColor.wrongInk.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MicaboColor.correctInk)
                    .flipsForRightToLeftLayoutDirection(true)
                Text(fix.corrected)
                    .font(MicaboFont.ui(16, weight: .heavy))
                    .foregroundStyle(MicaboColor.correctInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !fix.why.isEmpty {
                SheetInlineText(
                    markup: fix.why,
                    style: SheetTextStyle(size: 14.5, weight: .regular, color: MicaboColor.inkSecondary, lineSpacing: 3)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func tipCard(_ tip: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MicaboColor.accentInk)
                .frame(width: 34, height: 34)
                .background(MicaboColor.accentWash, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(writingText("ios.ku7.writing.tip"))
                    .font(MicaboFont.ui(13, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkSecondary)
                SheetInlineText(
                    markup: tip,
                    style: SheetTextStyle(size: 15.5, weight: .medium, color: MicaboColor.ink, lineSpacing: 3)
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solverCard()
    }

    /// Le texte de l'élève, corrections appliquées et surlignées en vert.
    private var correctedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Pas de capitales espacées ici : l'interlettrage casse la liaison des lettres arabes.
            Text(writingText("ios.ku7.writing.corrected"))
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
            Text(Self.highlighted(session.segments))
                .font(MicaboFont.ui(16, weight: .regular))
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .solverCard()
    }

    static func highlighted(_ segments: [WritingSegment]) -> AttributedString {
        var out = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.text)
            if segment.isFixed {
                piece.foregroundColor = MicaboColor.correctInk
                piece.backgroundColor = MicaboColor.correctSoft
                piece.font = MicaboFont.ui(16, weight: .bold)
            }
            out += piece
        }
        return out
    }
}

// MARK: - Le bouton du bas

/// **Le seul bouton plein de l'écran**, selon où on en est : relire, débloquer, ou copier le
/// texte corrigé.
struct WritingCoachBar: View {
    let session: WritingSession
    var copied = false
    var actions: WritingCoachActions

    var body: some View {
        switch session.phase {
        case .editing, .failed:
            button(writingText("ios.ku7.writing.check"), icon: "checkmark.seal", action: actions.check)
                .disabled(!session.canCheck)
        case .locked:
            button(writingText("ios.ku7.writing.locked.cta"), icon: "lock.open.fill", action: actions.unlock)
        case .reviewed:
            if session.review?.plain == nil {
                button(
                    writingText(copied ? "ios.ku7.writing.copied" : "ios.ku7.writing.copy"),
                    icon: copied ? "checkmark" : "doc.on.doc",
                    action: actions.copy
                )
            } else {
                button(writingText("ios.ku7.writing.again"), icon: "arrow.counterclockwise", action: actions.restart)
            }
        case .checking:
            EmptyView()
        }
    }

    private func button(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(MicaboPrimaryButtonStyle())
    }
}

// MARK: - L'écran

/// **« Corriger un texte »**, en plein écran depuis le raccourci de Home : un parcours, avec
/// sa croix. La porte est celle de Mika (`WritingSession`).
struct WritingCoachView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.aiService) private var aiService
    @Environment(ProAccess.self) private var pro: ProAccess?
    @State private var session = WritingSession()
    @FocusState private var focused: Bool
    @State private var choosingPhoto = false
    @State private var showsPhotoPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showsScanner = false
    @State private var copied = false

    private var isPro: Bool { pro?.isPro ?? false }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MicaboScreenHeader(title: writingText("ios.ku7.writing.title"), back: .close { dismiss() })
                WritingCoachContent(session: session, isPro: isPro, focused: $focused, actions: actions)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: session.phase)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            if session.phase != .checking {
                MicaboBottomBar {
                    WritingCoachBar(session: session, copied: copied, actions: actions)
                }
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .micaboPaywall($session.paywall, onSubscribed: {
            Task { await session.unlocked(service: aiService) }
        })
        .onChange(of: isPro) { _, nowPro in
            guard nowPro, session.phase == .locked else { return }
            Task { await session.unlocked(service: aiService) }
        }
        .confirmationDialog(writingText("ios.ku7.writing.photo"), isPresented: $choosingPhoto, titleVisibility: .hidden) {
            Button(L10n.t("lesson.import.scan", locale: .resolved())) {
                Task {
                    if await CameraAccess.request() {
                        showsScanner = true
                    } else {
                        showsPhotoPicker = true
                    }
                }
            }
            Button(L10n.t("lesson.import.library", locale: .resolved())) { showsPhotoPicker = true }
        }
        .photosPicker(isPresented: $showsPhotoPicker, selection: $photoItems, maxSelectionCount: OnDeviceOCR.pageLimit, matching: .images)
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            photoItems = []
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                await session.read(images)
            }
        }
        .fullScreenCover(isPresented: $showsScanner) {
            DocumentCameraView { images in
                showsScanner = false
                Task { await session.read(images) }
            } onCancel: {
                showsScanner = false
            }
            .ignoresSafeArea()
        }
        .onAppear { Analytics.track(.writingOpened) }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var actions: WritingCoachActions {
        WritingCoachActions(
            check: {
                focused = false
                Task { await session.check(isPro: isPro, service: aiService) }
            },
            paste: {
                session.paste(UIPasteboard.general.string)
                Haptics.light()
            },
            photo: {
                focused = false
                // Une caméra refusée n'ouvre pas le scanner (VisionKit afficherait son impasse) :
                // la photothèque directement, comme les imports de leçon.
                if DocumentCameraView.isSupported, CameraAccess.allowsScanner(CameraAccess.status) {
                    choosingPhoto = true
                } else {
                    showsPhotoPicker = true
                }
            },
            unlock: { session.paywall = .mika },
            copy: {
                UIPasteboard.general.string = session.correctedText
                Haptics.success()
                Analytics.track(.writingCopied)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { copied = false }
            },
            edit: { session.edit() },
            restart: {
                copied = false
                session.restart()
            }
        )
    }
}
