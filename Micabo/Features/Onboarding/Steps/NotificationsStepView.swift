import SwiftUI

/// Écran 15 : rappels quotidiens. L'autorisation système n'est pas encore demandée,
/// on n'enregistre pour l'instant que l'intention de l'utilisateur.
struct NotificationsStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var bellRings = false
    @State private var bannerVisible = false

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Dernière chose",
            title: "On te rappelle\nau bon moment.",
            subtitle: "Un rappel par jour, quand tes cartes arrivent à échéance.",
            titleSize: 28
        ) {
            VStack(spacing: 22) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .symbolEffect(.bounce, value: bellRings)
                    .frame(width: 88, height: 88)
                    .background(MicaboColor.surfaceMuted, in: Circle())

                NotificationBanner()
                    .opacity(bannerVisible ? 1 : 0)
                    .offset(y: bannerVisible ? 0 : -18)
                    .scaleEffect(bannerVisible ? 1 : 0.96)
            }
            .frame(maxWidth: .infinity)
        } footer: {
            VStack(spacing: 2) {
                OnboardingContinueButton(title: "Activer les notifications") {
                    model.notificationsOptIn = true
                    Haptics.success()
                    model.advance()
                }

                Button("Plus tard") {
                    Haptics.light()
                    model.notificationsOptIn = false
                    model.advance()
                }
                .buttonStyle(MicaboQuietButtonStyle())
            }
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            bellRings.toggle()
            Haptics.tick()
        }
        withAnimation(OnboardingMotion.shift.delay(0.7)) {
            bannerVisible = true
        }
    }
}

/// Aperçu d'un rappel, dans l'esprit d'une bannière système.
private struct NotificationBanner: View {
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MicaboColor.onInk)
                .frame(width: 34, height: 34)
                .background(MicaboColor.ink, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("MICABO")
                        .font(MicaboFont.hanken(10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(MicaboColor.inkTertiary)
                    Spacer()
                    Text("maintenant")
                        .font(MicaboFont.hanken(10, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Text("12 cartes t'attendent")
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)

                Text("6 minutes suffisent pour boucler ta journée.")
                    .font(MicaboFont.hanken(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
    }
}
