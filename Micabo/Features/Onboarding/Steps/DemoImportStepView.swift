import SwiftUI

/// Écran 8a : premier temps de la démonstration. L'utilisateur importe lui-même
/// un faux cours en appuyant sur le document ; la fin de l'analyse enchaîne sur l'écran suivant.
struct DemoImportStepView: View {
    @Environment(OnboardingModel.self) private var model

    private enum Phase {
        case idle
        case scanning
        case done
    }

    @State private var phase: Phase = .idle
    @State private var sweepProgress: Double = 0
    @State private var hintPulse = false
    @State private var floatUp = false
    @State private var showClickHint = false

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 1 sur 3",
            title: "Dépose ton cours.",
            subtitle: "Un PDF d'amphi, des notes prises à la volée, une photo de tableau. Micabo lit tout, y compris les schémas.",
            titleSize: 28
        ) {
            Button(action: startScan) {
                ZStack(alignment: .bottomTrailing) {
                    DemoDocumentPage(
                        isScanning: phase != .idle,
                        isAnalyzed: phase == .done,
                        sweepProgress: sweepProgress
                    )

                    if phase == .idle, showClickHint {
                        clickHint
                            .transition(.scale(scale: 0.7).combined(with: .opacity))
                            .padding(14)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(phase != .idle)
            .offset(y: phase == .idle && floatUp ? -7 : 0)
            .scaleEffect(phase == .idle ? (floatUp ? 1.015 : 0.99) : 0.97)
            .shadow(
                color: Color.black.opacity(phase == .idle && floatUp ? 0.14 : 0.06),
                radius: phase == .idle && floatUp ? 22 : 12,
                x: 0,
                y: phase == .idle && floatUp ? 14 : 8
            )
            .animation(.easeOut(duration: 0.35), value: phase)
        } footer: {
            statusLabel
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                hintPulse = true
            }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                floatUp = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                guard phase == .idle else { return }
                withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                    showClickHint = true
                }
                Haptics.tick()
            }
        }
    }

    private var clickHint: some View {
        HStack(spacing: 6) {
            Text("👆")
                .font(.system(size: 18))
            Text("Clique ici")
                .font(MicaboFont.hanken(13, weight: .bold))
                .foregroundStyle(MicaboColor.onInk)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(MicaboColor.ink, in: Capsule())
        .shadow(color: Color.black.opacity(0.16), radius: 10, x: 0, y: 4)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch phase {
        case .idle:
            HStack(spacing: 7) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 12, weight: .medium))
                Text("Appuie sur le document pour l'importer")
                    .font(MicaboFont.hanken(13, weight: .semibold))
            }
            .foregroundStyle(MicaboColor.ink)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(MicaboColor.surfaceMuted, in: Capsule())
            .scaleEffect(hintPulse ? 1.03 : 0.99)

        case .scanning:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .tint(MicaboColor.accent)
                Text("Lecture des 12 pages…")
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            .transition(.opacity)

        case .done:
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MicaboColor.positive)
                Text("Cours importé")
                    .font(MicaboFont.hanken(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
            }
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(MicaboColor.positiveSoft, in: Capsule())
            .transition(.opacity)
        }
    }

    private func startScan() {
        guard phase == .idle else { return }
        Haptics.medium()

        withAnimation(.easeOut(duration: 0.3)) {
            phase = .scanning
        }

        withAnimation(.easeInOut(duration: 1.25)) {
            sweepProgress = 1
        }

        Haptics.burst(count: 8, over: 1.2, intensity: 0.28)

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
            withAnimation(.easeOut(duration: 0.28)) {
                phase = .done
            }
            Haptics.success()

            // L'écran s'enchaîne de lui-même : la fin de l'import vaut validation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
                flow.advance()
            }
        }
    }
}
