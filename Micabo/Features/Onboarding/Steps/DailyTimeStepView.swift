import SwiftUI

/// Écran 12 : rythme quotidien. Curseur de 5 minutes à 1 heure, par paliers de 5.
struct DailyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var minutes = 15.0
    @State private var isReady = false

    private let range = 5.0...60.0
    private let step = 5.0

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton rythme",
            title: "Combien de temps par jour ?",
            subtitle: "Mieux vaut dix minutes tous les jours qu'une heure le dimanche. Tu pourras changer d'avis quand tu veux.",
            titleSize: 28
        ) {
            VStack(spacing: 22) {
                readout

                VStack(spacing: 10) {
                    Slider(value: $minutes, in: range, step: step)
                        .tint(MicaboColor.progress)
                        .onChange(of: minutes) { oldValue, newValue in
                            guard isReady, oldValue != newValue else { return }
                            Haptics.selection()
                            model.dailyMinutes = Int(newValue)
                        }

                    HStack {
                        Text("5 min")
                        Spacer()
                        Text("1 h")
                    }
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                }

                paceLabel
            }
            .padding(18)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1)
            }
        } footer: {
            OnboardingContinueButton {
                model.dailyMinutes = Int(minutes)
                model.advance()
            }
        }
        .onAppear {
            minutes = Double(model.dailyMinutes)
            isReady = true
        }
    }

    private var readout: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text("\(Int(minutes))")
                .font(MicaboFont.hanken(64, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-2)
                .monospacedDigit()
                .contentTransition(.numericText(value: minutes))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: minutes)

            Text("min / jour")
                .font(MicaboFont.hanken(15, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var paceLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: paceIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(paceText)
                .font(MicaboFont.hanken(12, weight: .semibold))
        }
        .foregroundStyle(MicaboColor.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .background(MicaboColor.infoSoft, in: Capsule())
        .contentTransition(.opacity)
    }

    private var paceIcon: String {
        switch Int(minutes) {
        case ..<15: "leaf"
        case 15..<35: "figure.walk"
        default: "flame"
        }
    }

    private var paceText: String {
        switch Int(minutes) {
        case ..<15: "Tranquille, mais régulier"
        case 15..<35: "Le rythme de croisière"
        default: "Objectif concours"
        }
    }
}
