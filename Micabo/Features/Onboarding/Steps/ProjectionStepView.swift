import SwiftUI

/// Écran 13 : projection sur un an au rythme choisi. Le nombre se déroule à l'écran.
///
/// Composition volontairement différente de l'écran du curseur qui la précède : pas de
/// panneau blanc, le chiffre est posé à même le crème, et une frise de douze mois montre
/// l'accumulation.
struct ProjectionStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var displayed = 0.0
    @State private var grownMonths = 0
    @State private var didStart = false

    private var target: Double {
        Double(model.projectedCardsPerYear)
    }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ta projection",
            title: "À ce rythme, dans un an…",
            subtitle: "\(DailyLoad.label(forMinutes: model.dailyMinutes)) par jour, tous les jours.",
            titleSize: 28
        ) {
            VStack(alignment: .leading, spacing: 22) {
                headline
                monthStrip
                breakdown
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .onAppear(perform: run)
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 2) {
            CountingText(
                value: displayed,
                font: MicaboFont.hanken(64, weight: .bold),
                color: MicaboColor.ink
            )
            .tracking(-2.5)

            Text("cartes mémorisées")
                .font(MicaboFont.hanken(16, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
    }

    /// Douze mois qui montent : la projection devient une image, pas seulement un nombre.
    private var monthStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(0..<12, id: \.self) { index in
                    Capsule()
                        .fill(index < grownMonths ? MicaboColor.accent : MicaboColor.surfaceSunken)
                        .frame(height: barHeight(for: index))
                        .frame(maxWidth: .infinity)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.04), value: grownMonths)
                }
            }
            .frame(height: 84, alignment: .bottom)

            HStack {
                Text("1er mois")
                Spacer()
                Text("12e mois")
            }
            .font(MicaboFont.hanken(10, weight: .medium))
            .foregroundStyle(MicaboColor.inkTertiary)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let ratio = CGFloat(index + 1) / 12
        return 14 + ratio * 70
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            row(icon: "calendar", text: "\(DailyLoad.label(forMinutes: model.dailyMinutes)) par jour, 365 jours")
            MicaboHairline(inset: 28, onCanvas: true)
            row(icon: "rectangle.on.rectangle", text: "environ \(Int(LearningProjection.cardsPerMinute)) cartes parcourues par minute")
            MicaboHairline(inset: 28, onCanvas: true)
            row(icon: "arrow.triangle.2.circlepath", text: "\(Int(LearningProjection.repetitionsPerCard)) passages en moyenne pour ancrer une carte")

            Text("Une estimation, pas une promesse : le calcul est posé ici pour que tu puisses le refaire.")
                .font(MicaboFont.hanken(11, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 18)

            Text(text)
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 1.6)) {
                displayed = target
            }
            grownMonths = 12
            Haptics.burst(count: 18, over: 1.5, intensity: 0.3)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                Haptics.success()
            }
        }
    }
}
