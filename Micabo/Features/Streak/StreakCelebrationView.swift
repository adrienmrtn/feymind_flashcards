import SwiftUI

/// **La série qui grandit, une fois par jour** : Mika fait la fête à côté de la flamme, le
/// nombre passe de la veille à aujourd'hui, et le rond du jour s'allume dans la semaine.
///
/// Elle vient **après** l'étape, jamais à sa place : le chemin s'anime d'abord (le cercle se
/// remplit, les confettis d'un palier tombent), et la série n'arrive qu'une fois tout cela
/// posé. Après le Quiz final, elle attend que « Leçon terminée » ait eu son moment. Elle ne
/// bloque rien : « Continuer » rend la main là où on allait.
///
/// L'écran montre ce qui vient de se passer, pas seulement le résultat. Le nombre part de la
/// veille et le rond d'aujourd'hui est vide à l'ouverture ; les deux changent ensemble, une
/// fraction de seconde plus tard. C'est ce geste qui dit « tu viens de faire grandir ta
/// série », et un chiffre déjà écrit ne le dirait pas.
struct StreakCelebrationView: View {
    let onContinue: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var status: StudyStreak.Status
    @State private var week: [StudyStreak.Day]
    @State private var shownCount: Int
    @State private var lit = false
    @State private var played = false

    init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        let status = StudyStreak.status()
        _status = State(initialValue: status)
        _week = State(initialValue: StudyStreak.week())
        _shownCount = State(initialValue: max(0, status.current - 1))
    }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            // Un halo chaud qui descend du haut : la seule touche de couleur de l'écran avant
            // la flamme.
            RadialGradient(
                colors: [MicaboColor.flameSoft, MicaboColor.canvas.opacity(0)],
                center: .top,
                startRadius: 0,
                endRadius: 460
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            if lit {
                ConfettiView(colors: [MicaboColor.flame, MicaboColor.flameInk, MicaboColor.flameTrack, LessonTone.yellow.vivid])
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer(minLength: 12)
                HStack(alignment: .bottom, spacing: -8) {
                    MikaMascot(mood: .celebrate, size: 124, reactsToTap: true)
                    StreakFlame(lit: lit, size: 84)
                }
                Text("\(shownCount)")
                    .font(MicaboFont.number(84))
                    .foregroundStyle(StreakFlame.gradient)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shownCount)))
                    .padding(.top, -4)
                Text(i18n.t("ios.streak.unit", ["count": "\(shownCount)"]))
                    .font(MicaboFont.display(28))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, -8)
                Text(line)
                    .font(MicaboFont.ui(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
                StreakWeekCard(days: week, todayLit: lit)
                    .padding(.top, 26)
                Spacer(minLength: 20)
                Button(i18n.t("ios.streak.continue"), action: onContinue)
                    .buttonStyle(LessonPrimaryButtonStyle())
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, MicaboSpacing.screen)
        }
        .accessibilityElement(children: .contain)
        .onAppear(perform: play)
    }

    /// Le premier jour, un nouveau record, ou une série qui continue.
    private var line: String {
        if status.current <= 1 { return i18n.t("ios.streak.celebrate.first") }
        if status.current >= status.best { return i18n.t("ios.streak.celebrate.record") }
        return i18n.t("ios.streak.celebrate.line")
    }

    private func play() {
        guard !played else { return }
        played = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.spring(duration: 0.55, bounce: 0.45)) {
                lit = true
                shownCount = status.current
            }
            Haptics.success()
            Haptics.burst(count: 3, over: 0.45)
        }
    }
}
