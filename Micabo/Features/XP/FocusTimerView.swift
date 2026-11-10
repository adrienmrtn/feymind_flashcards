import SwiftUI
import UIKit

/// Le temps de concentration mené au bout, toutes séances confondues : il s'ajoute aux heures
/// de révision de Home (`HomeStats`).
enum FocusLog {
    static let key = "micabo.focus.seconds"

    static var totalSeconds: Double {
        UserDefaults.standard.double(forKey: key)
    }

    static func add(_ seconds: Double) {
        UserDefaults.standard.set(totalSeconds + max(0, seconds), forKey: key)
    }
}

/// **Le minuteur** (`docs/refonte-knowunity.md` § 5) : Mika au centre d'un anneau qui se vide,
/// 25:00, Pause / Reprendre, Arrêter (avec confirmation). Au bout, la fête, `focusSession`
/// (40 XP), et le temps compte dans les heures de révision.
///
/// **Le temps se calcule depuis l'heure de fin**, jamais en comptant des secondes : l'app
/// peut passer en arrière-plan, l'écran peut se verrouiller, la séance continue de courir et
/// se termine à la bonne minute. L'écran reste allumé tant que la séance est ouverte.
struct FocusTimerView: View {
    static let duration = TimeInterval(XPRules.focusMinutes * 60)

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// L'heure où la séance se termine, tant qu'elle court ; nil en pause.
    @State private var endDate: Date?
    @State private var remainingWhenPaused = FocusTimerView.duration
    @State private var finished = false
    @State private var award: XPAward?
    @State private var confirmsStop = false
    @State private var started = false

    private var isPaused: Bool { endDate == nil && !finished }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            if finished {
                finishedView
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    session(remaining: remaining(at: context.date))
                }
            }
        }
        .animation(.spring(duration: 0.5), value: finished)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            guard !started else { return }
            started = true
            resume()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        // Au retour dans l'app : la séance a pu se terminer pendant l'absence.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { finishIfDue() }
        }
        .confirmationDialog(
            L10n.t("ios.kx.timer.stopQ", locale: .resolved()),
            isPresented: $confirmsStop,
            titleVisibility: .visible
        ) {
            Button(L10n.t("ios.kx.timer.stop", locale: .resolved()), role: .destructive) { dismiss() }
            Button(L10n.t("ios.kx.timer.keepGoing", locale: .resolved()), role: .cancel) {}
        } message: {
            Text(L10n.t("ios.kx.timer.stopMsg", locale: .resolved()))
        }
    }

    // MARK: La séance

    private func session(remaining: TimeInterval) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(L10n.t("ios.kx.tools.timer.title", locale: .resolved()))
                    .font(MicaboFont.ui(20, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 12)

            Spacer(minLength: 16)

            ZStack {
                Circle()
                    .stroke(MicaboColor.track, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: max(0, min(1, remaining / Self.duration)))
                    .stroke(
                        LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)
                MikaMascot(mood: isPaused ? .sleep : .idle, size: 150)
            }
            .frame(width: 264, height: 264)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(L10n.t("ios.kx.timer.remainingA11y", locale: .resolved(), vars: ["time": Self.format(remaining)])))

            Text(Self.format(remaining))
                .font(MicaboFont.number(64))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: true))
                .padding(.top, 26)
                .accessibilityHidden(true)
            Text(isPaused
                ? L10n.t("ios.kx.timer.paused", locale: .resolved())
                : L10n.t("ios.kx.timer.focus", locale: .resolved()))
                .font(MicaboFont.ui(17, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 32)

            Spacer(minLength: 16)

            VStack(spacing: 12) {
                Button {
                    if isPaused { resume() } else { pause() }
                } label: {
                    Label(
                        isPaused ? L10n.t("ios.kx.timer.resume", locale: .resolved()) : L10n.t("ios.kx.timer.pause", locale: .resolved()),
                        systemImage: isPaused ? "play.fill" : "pause.fill"
                    )
                }
                .buttonStyle(LessonPrimaryButtonStyle())
                Button {
                    confirmsStop = true
                } label: {
                    Label(L10n.t("ios.kx.timer.stop", locale: .resolved()), systemImage: "stop.fill")
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 16)
        }
        .onChange(of: remaining <= 0) { _, done in
            if done { finish() }
        }
    }

    private func remaining(at date: Date) -> TimeInterval {
        guard let endDate else { return remainingWhenPaused }
        return max(0, endDate.timeIntervalSince(date))
    }

    private func pause() {
        guard let endDate else { return }
        remainingWhenPaused = max(0, endDate.timeIntervalSinceNow)
        self.endDate = nil
        Haptics.light()
    }

    private func resume() {
        endDate = Date().addingTimeInterval(remainingWhenPaused)
    }

    private func finishIfDue() {
        guard let endDate, endDate <= Date() else { return }
        finish()
    }

    private func finish() {
        guard !finished else { return }
        endDate = nil
        remainingWhenPaused = 0
        FocusLog.add(Self.duration)
        // La fête du jour se montre ici, dans l'écran de fin : pas de seconde fête par-dessus.
        award = XPStore.shared.award(.focusSession, celebrates: false)
        finished = true
        UIApplication.shared.isIdleTimerDisabled = false
        Haptics.success()
        Haptics.burst(count: 3, over: 0.45)
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: La fin

    private var finishedView: some View {
        ZStack {
            ConfettiView(colors: [MicaboColor.accent, MicaboColor.keyword, LessonTone.mint.vivid, LessonTone.yellow.vivid])
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 16) {
                    if award?.reachedGoal == true {
                        XPGoalCard(showsButton: false)
                            .padding(.top, 24)
                    } else {
                        MicaboSpeechBubble(text: L10n.t("ios.kx.timer.mika", locale: .resolved()), tail: .bottom)
                            .padding(.top, 40)
                            .padding(.horizontal, 12)
                        MikaMascot(mood: .celebrate, size: 150, reactsToTap: true)
                    }
                    Text(L10n.t("ios.kx.timer.done", locale: .resolved()))
                        .font(MicaboFont.display(30))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.t("ios.kx.timer.doneBody", locale: .resolved(), vars: ["n": "\(XPRules.focusMinutes)"]))
                        .font(MicaboFont.ui(17, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                    if let added = award?.added, added > 0 {
                        XPBadge(points: added)
                            .scaleEffect(1.25)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, MicaboSpacing.screen)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button(L10n.t("ios.kx.continue", locale: .resolved())) { dismiss() }
                    .buttonStyle(LessonPrimaryButtonStyle())
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, 12)
                    .background(MicaboColor.canvas)
            }
        }
    }
}
