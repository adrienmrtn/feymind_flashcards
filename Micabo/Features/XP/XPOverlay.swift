import SwiftUI
import UIKit

/// **Ce qu'un gain d'XP montre, par-dessus tout** (`docs/refonte-knowunity.md` § 2) : un petit
/// « +10 XP » qui monte et s'efface, une haptique légère, et, une fois par jour, la fête de
/// l'objectif du jour avec Mika.
///
/// Les gains arrivent depuis des feuilles et des plein-écrans (un quiz, une série de cartes,
/// Mika) : une surcouche posée sur `RootView` serait dessous. Le gain s'affiche donc dans une
/// petite fenêtre à part, au-dessus de l'app, **visible seulement le temps du gain** et qui
/// laisse passer les touchers tant que la fête n'est pas ouverte.
@MainActor
final class XPOverlayController {
    static let shared = XPOverlayController()

    private var window: XPOverlayWindow?
    private let model = XPOverlayModel()
    private var hideTask: Task<Void, Never>?

    /// Branche le magasin d'XP sur la fenêtre. Une fois, au lancement de l'app.
    func install() {
        XPStore.shared.onAward = { [weak self] award in
            self?.show(award)
        }
    }

    private func show(_ award: XPAward) {
        guard award.added > 0, let window = ensureWindow() else { return }
        window.overrideUserInterfaceStyle = Self.interfaceStyle
        window.isHidden = false
        withAnimation(.spring(duration: 0.4, bounce: 0.35)) {
            model.toast = XPOverlayModel.Toast(points: award.added)
        }
        Haptics.light()
        UIAccessibility.post(
            notification: .announcement,
            argument: L10n.t("ios.kx.xp.gain", locale: .resolved(), vars: ["n": "\(award.added)"])
        )

        hideTask?.cancel()
        let celebrates = award.reachedGoal
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            self?.endToast(thenCelebrate: celebrates)
        }
    }

    private func endToast(thenCelebrate celebrates: Bool) {
        withAnimation(.easeOut(duration: 0.35)) { model.toast = nil }
        if celebrates {
            celebrate()
        } else if !model.celebrating {
            hideTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(0.4))
                guard !Task.isCancelled, let self, self.model.toast == nil, !self.model.celebrating else { return }
                self.window?.isHidden = true
            }
        }
    }

    private func celebrate() {
        guard let window = ensureWindow() else { return }
        window.overrideUserInterfaceStyle = Self.interfaceStyle
        window.isHidden = false
        window.acceptsTouches = true
        window.rootViewController?.view.accessibilityViewIsModal = true
        withAnimation(.easeInOut(duration: 0.3)) { model.celebrating = true }
    }

    private func endCelebration() {
        withAnimation(.easeInOut(duration: 0.3)) { model.celebrating = false }
        window?.acceptsTouches = false
        window?.rootViewController?.view.accessibilityViewIsModal = false
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(0.35))
            guard !Task.isCancelled, let self, !self.model.celebrating, self.model.toast == nil else { return }
            self.window?.isHidden = true
        }
    }

    private func ensureWindow() -> XPOverlayWindow? {
        if let window { return window }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return nil }
        let window = XPOverlayWindow(windowScene: scene)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        window.backgroundColor = .clear
        let host = UIHostingController(rootView: XPOverlayRoot(model: model) { [weak self] in
            self?.endCelebration()
        })
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.isHidden = true
        self.window = window
        return window
    }

    /// Le thème choisi dans le Profil : la fenêtre n'hérite pas de celui de l'app.
    private static var interfaceStyle: UIUserInterfaceStyle {
        let scheme = AppearanceStore.shared.appearance.colorScheme
        if scheme == .dark { return .dark }
        if scheme == .light { return .light }
        return .unspecified
    }
}

/// La fenêtre du gain : elle ne garde les touchers que pendant la fête.
final class XPOverlayWindow: UIWindow {
    var acceptsTouches = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard acceptsTouches else { return nil }
        return super.hitTest(point, with: event)
    }
}

@Observable
final class XPOverlayModel {
    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let points: Int
    }

    var toast: Toast?
    var celebrating = false
}

/// Le contenu de la fenêtre : le gain en haut, la fête par-dessus tout.
struct XPOverlayRoot: View {
    let model: XPOverlayModel
    let onFinishCelebration: () -> Void

    var body: some View {
        let locale = UiLocale.resolved()
        ZStack(alignment: .top) {
            if model.celebrating {
                XPGoalCelebration(onContinue: onFinishCelebration)
                    .transition(.opacity)
            }
            if let toast = model.toast {
                XPToast(points: toast.points)
                    .id(toast.id)
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(y: 24)),
                        removal: .opacity.combined(with: .offset(y: -36))
                    ))
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.locale, locale.foundation)
        .environment(\.layoutDirection, locale.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

/// « ⚡ +10 XP », dans le dégradé de l'app.
struct XPToast: View {
    let points: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 15, weight: .black))
            Text(L10n.t("ios.kx.xp.gain", locale: .resolved(), vars: ["n": "\(points)"]))
                .font(MicaboFont.number(18))
                .monospacedDigit()
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            LinearGradient(colors: MicaboColor.brandGradient, startPoint: .leading, endPoint: .trailing),
            in: Capsule()
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
        .shadow(color: MicaboColor.accent.opacity(0.35), radius: 12, y: 6)
    }
}

/// **L'objectif du jour est atteint** : Mika fait la fête, une fois par jour.
struct XPGoalCelebration: View {
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            if appeared {
                ConfettiView(colors: [MicaboColor.accent, MicaboColor.accentDeep, MicaboBrand.pencil, LessonTone.mint.vivid, MicaboBrand.eraser])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            XPGoalCard(onContinue: onContinue)
                .padding(.horizontal, MicaboSpacing.screen)
                .scaleEffect(appeared ? 1 : 0.86)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.4)) { appeared = true }
            Haptics.success()
            Haptics.burst(count: 3, over: 0.45)
        }
    }
}

/// La carte de la fête : Mika qui parle, l'anneau plein, et « Continuer ». Elle sert aussi à
/// la fin du minuteur quand la séance fait atteindre l'objectif.
struct XPGoalCard: View {
    var showsButton = true
    var onContinue: () -> Void = {}

    /// **La fête de l'objectif**, un moment qui compte : Mika en entier saute de joie, une
    /// fois, puis reste debout sur la carte.
    private var mika: some View {
        MikaMascot(mood: .celebrate, size: 120, reactsToTap: true)
    }

    var body: some View {
        VStack(spacing: 14) {
            MicaboSpeechBubble(text: L10n.t("ios.kx.goal.mika", locale: .resolved()), tail: .bottom)
                .padding(.horizontal, 8)
            mika
            Text(L10n.t("ios.kx.goal.title", locale: .resolved()))
                .font(MicaboFont.display(26))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(L10n.t("ios.kx.goal.body", locale: .resolved(), vars: ["goal": "\(XPRules.dailyGoal)"]))
                .font(MicaboFont.ui(16, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if showsButton {
                Button(L10n.t("ios.kx.continue", locale: .resolved()), action: onContinue)
                    .buttonStyle(MicaboBrandButtonStyle())
                    .padding(.top, 6)
            }
        }
        .padding(22)
        .frame(maxWidth: 420)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.sheet, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MicaboRadius.sheet, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        )
    }
}
