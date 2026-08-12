import SwiftUI

/// Écran 13 : projection sur un an au rythme choisi. Le nombre se déroule à l'écran.
struct ProjectionStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var displayed = 0.0
    @State private var didStart = false

    private var target: Double {
        Double(model.projectedCardsPerYear)
    }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Ta projection",
            title: "À ce rythme, dans un an…",
            subtitle: "\(model.dailyMinutes) minutes par jour, tous les jours. Voilà ce que ça représente.",
            titleSize: 28
        ) {
            VStack(spacing: 16) {
                headline
                breakdown
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
        .onAppear(perform: runCounter)
    }

    private var headline: some View {
        VStack(spacing: 6) {
            CountingText(
                value: displayed,
                font: MicaboFont.hanken(60, weight: .bold),
                color: MicaboColor.ink
            )
            .tracking(-2)

            Text("cartes mémorisées")
                .font(MicaboFont.hanken(15, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private var breakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            row(
                icon: "calendar",
                text: "\(model.dailyMinutes) minutes par jour, 365 jours"
            )
            row(
                icon: "rectangle.on.rectangle",
                text: "environ \(Int(LearningProjection.cardsPerMinute)) cartes parcourues par minute"
            )
            row(
                icon: "arrow.triangle.2.circlepath",
                text: "\(Int(LearningProjection.repetitionsPerCard)) passages en moyenne pour ancrer une carte"
            )

            Text("Une estimation, pas une promesse : le calcul est posé ici pour que tu puisses le refaire.")
                .font(MicaboFont.hanken(11, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
    }

    private func row(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .frame(width: 18)

            Text(text)
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(Color(hex: 0x4A463F))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func runCounter() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeOut(duration: 1.6)) {
                displayed = target
            }
            Haptics.burst(count: 18, over: 1.5, intensity: 0.3)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
                Haptics.success()
            }
        }
    }
}
