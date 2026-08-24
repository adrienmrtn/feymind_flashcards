import SwiftUI

/// Écran 13 : rythme quotidien. Le curseur va de 5 minutes à 2 heures, par paliers de
/// 5 minutes jusqu'à la demi-heure puis de 15 minutes au-delà — il glisse donc sur les
/// paliers de `DailyLoad`, pas sur les minutes.
///
/// La valeur n'est pas décorative : elle fixe le plafond de cartes neuves par jour,
/// affiché juste en dessous et recalculé à chaque cran.
struct DailyTimeStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var stepIndex = Double(DailyLoad.stepIndex(for: 15))
    @State private var isReady = false

    private var minutes: Int {
        DailyLoad.minutes(atStepIndex: Int(stepIndex.rounded()))
    }

    private var pace: DailyLoad.Pace {
        DailyLoad.pace(forDailyMinutes: minutes)
    }

    private var newCardsPerDay: Int {
        DailyLoad.newCardsPerDay(dailyMinutes: minutes)
    }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ton rythme",
            title: "Combien de temps par jour ?",
            subtitle: "Dix minutes chaque jour valent mieux qu'une heure le dimanche.",
            titleSize: 28
        ) {
            VStack(spacing: 14) {
                dial
                loadNote
            }
        } footer: {
            OnboardingContinueButton {
                commit()
                model.advance()
            }
        }
        .onAppear {
            stepIndex = Double(DailyLoad.stepIndex(for: model.dailyMinutes))
            isReady = true
        }
    }

    private var dial: some View {
        VStack(spacing: 20) {
            readout

            VStack(spacing: 10) {
                Slider(
                    value: $stepIndex,
                    in: 0...Double(DailyLoad.steps.count - 1),
                    step: 1
                )
                .tint(MicaboColor.progress)
                .onChange(of: stepIndex) { oldValue, newValue in
                    guard isReady, oldValue != newValue else { return }
                    Haptics.selection()
                    commit()
                }

                HStack {
                    Text("\(DailyLoad.minimumMinutes) min")
                    Spacer()
                    Text("2 h")
                }
                .font(MicaboFont.hanken(11, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
            }

            paceLabel
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .micaboGroup()
    }

    private var readout: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(readoutValue)
                .font(MicaboFont.hanken(64, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-2)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(minutes)))
                .animation(OnboardingMotion.shift, value: minutes)

            Text(readoutUnit)
                .font(MicaboFont.hanken(15, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Au-delà de l'heure, on parle en heures : « 90 min » se lit moins bien que « 1 h 30 ».
    private var readoutValue: String {
        guard minutes >= 60 else { return "\(minutes)" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)" : "\(hours) h \(rest)"
    }

    private var readoutUnit: String {
        guard minutes >= 60 else { return "min / jour" }
        return minutes % 60 == 0 ? "h / jour" : "/ jour"
    }

    private var paceLabel: some View {
        HStack(spacing: 7) {
            Image(systemName: pace.systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text("C'est \(pace.label)")
                .font(MicaboFont.hanken(12, weight: .semibold))
        }
        .foregroundStyle(MicaboColor.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .background(MicaboColor.accentSoft, in: Capsule())
        .contentTransition(.opacity)
        .animation(.easeOut(duration: 0.2), value: pace.label)
    }

    /// Ce que le curseur décide vraiment.
    private var loadNote: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 20)

            Text("On introduit au maximum \(MicaboCopy.cards(newCardsPerDay)) neuves par jour, pour que ta charge quotidienne reste sous \(DailyLoad.label(forMinutes: minutes)).")
                .font(MicaboFont.hanken(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText(value: Double(newCardsPerDay)))
                .animation(.easeOut(duration: 0.25), value: newCardsPerDay)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.accentSoft.opacity(0.6), in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
    }

    private func commit() {
        model.dailyMinutes = minutes
    }
}
