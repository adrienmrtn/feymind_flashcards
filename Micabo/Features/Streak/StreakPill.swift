import SwiftUI

/// **La série, en haut de Home** : la flamme 3D et le nombre de jours, dans une pastille.
///
/// Elle est en couleur quand aujourd'hui est fait, et grise tant qu'il ne l'est pas : la série
/// tient encore jusqu'à minuit, mais elle attend. C'est le seul rappel qu'on voit sans rien
/// ouvrir, et il dit exactement ce qu'il y a à faire — sans notification, sans badge rouge.
struct StreakPill: View {
    let action: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.scenePhase) private var scenePhase

    @State private var status = StudyStreak.status()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                MicaboIconView(icon: .flame, size: 26)
                    .saturation(status.studiedToday ? 1 : 0)
                    .opacity(status.studiedToday ? 1 : 0.5)
                Text("\(status.current)")
                    .font(MicaboFont.number(18))
                    .foregroundStyle(status.studiedToday ? MicaboColor.flameInk : MicaboColor.inkTertiary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(status.current)))
            }
            .padding(.leading, 8)
            .padding(.trailing, 13)
            .frame(height: 40)
            .background(status.studiedToday ? MicaboColor.flameSoft : MicaboColor.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    status.studiedToday ? MicaboColor.flame.opacity(0.35) : MicaboColor.stroke,
                    lineWidth: 1.5
                )
            )
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(i18n.t("ios.streak.pillA11y", ["count": "\(status.current)"])))
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refresh() }
        // Au retour dans l'app : minuit a pu passer, et la pastille doit se griser.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        let next = StudyStreak.status()
        guard next != status else { return }
        withAnimation(.spring(duration: 0.4)) { status = next }
    }
}
