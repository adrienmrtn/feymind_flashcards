import SwiftUI

/// Rythme quotidien. Le curseur va de 5 minutes à 2 heures, par paliers de
/// 5 minutes jusqu'à la demi-heure puis de 15 minutes au-delà — il glisse donc sur les
/// paliers de `DailyLoad`, pas sur les minutes.
///
/// La valeur n'est pas décorative : elle fixe le plafond de cartes neuves par jour,
/// affiché juste en dessous et recalculé à chaque cran. Le sous-titre le dit avant qu'on
/// touche le curseur : une question qui annonce ce qu'elle sert à décider se répond mieux
/// qu'une question posée sèchement.
///
/// **Le curseur est posé à même le fond, sans bloc autour.** Il vivait dans une carte
/// blanche, avec la conséquence dans un second encadré juste dessous : deux cadres empilés
/// sur un écran qui ne porte qu'une seule commande, et un grand nombre enfermé dans une
/// boîte se lit comme la valeur d'un formulaire, pas comme une décision qu'on prend. Le
/// chiffre, la piste et la phrase qui en découle se lisent mieux à l'air libre, et l'écran
/// ressemble alors aux autres questions du parcours, qui n'encadrent pas leurs réponses.
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
            title: "Combien de temps veux-tu réviser par jour ?",
            subtitle: "Ça nous aide à créer un parcours parfaitement personnalisé à tes besoins.",
            titleSize: 27
        ) {
            VStack(spacing: 18) {
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
                // Le menthe vif du logo tenait sur le blanc du bloc ; sur le crème, un filet
                // de quatre points dans cette teinte ne se distingue plus de sa piste. C'est
                // la règle de la palette, et elle vaut ici comme partout : sur fond clair,
                // c'est l'accent sombre qui porte une progression.
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
        .frame(maxWidth: .infinity)
    }

    private var readout: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(readoutValue)
                .font(MicaboFont.number(64))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-1.5)
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

    /// Ce que le curseur décide vraiment. Une phrase, un pictogramme, et pas de cadre : la
    /// conséquence se lit sous le curseur, elle n'est pas un encart à côté de lui.
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func commit() {
        model.dailyMinutes = minutes
    }
}
