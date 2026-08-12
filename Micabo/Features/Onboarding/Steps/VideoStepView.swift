import SwiftUI

/// Écran 9 : emplacement réservé à la vidéo de présentation.
/// Le bouton n'apparaît qu'au bout de trois secondes, le temps de la regarder.
struct VideoStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let unlockDelay = 3.0

    @State private var isUnlocked = false
    @State private var watchProgress = 0.0

    var body: some View {
        OnboardingScaffold(
            eyebrow: "En 40 secondes",
            title: "Voici comment ça marche.",
            subtitle: "Un cours, une pile de cartes, et cinq minutes par jour qui font le reste.",
            titleSize: 28
        ) {
            VStack(spacing: 14) {
                VideoPlaceholder(progress: watchProgress)

                Text(isUnlocked ? "C'est à toi." : "Encore un instant…")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .contentTransition(.opacity)
            }
        } footer: {
            Group {
                if isUnlocked {
                    OnboardingContinueButton(title: "Générer mes flashcards") {
                        model.advance()
                    }
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                } else {
                    Color.clear.frame(height: 52)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.74), value: isUnlocked)
        }
        .onAppear(perform: startCountdown)
    }

    private func startCountdown() {
        withAnimation(.linear(duration: unlockDelay)) {
            watchProgress = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + unlockDelay) {
            isUnlocked = true
            Haptics.success()
        }
    }
}

/// Cadre 16:9 avec un léger reflet qui balaie l'image, en attendant la vraie vidéo.
private struct VideoPlaceholder: View {
    let progress: Double

    @State private var shimmer = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                .fill(MicaboColor.ink)

            LinearGradient(
                colors: [.clear, Color.white.opacity(0.07), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(18))
            .offset(x: shimmer ? 240 : -240)
            .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))

            VStack(spacing: 12) {
                Image(systemName: "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 54, height: 54)
                    .background(MicaboColor.onInk, in: Circle())

                Text("Vidéo à venir")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.onInkMuted)
            }
        }
        .aspectRatio(16.0 / 10.0, contentMode: .fit)
        .overlay(alignment: .bottom) {
            MicaboProgressBar(
                progress: progress,
                tint: MicaboColor.onInk,
                track: Color.white.opacity(0.16)
            )
            .frame(height: 3)
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}
