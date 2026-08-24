import SwiftUI

/// Choix de la langue. Seul le français est disponible.
///
/// Il y avait ici cinq rangées à drapeau dont quatre étaient grisées. Quatre choix qu'on ne
/// peut pas faire ne sont pas des choix : ils occupent l'écran, ils invitent à appuyer, et
/// ils ne répondent rien. Reste une rangée cochée et une ligne qui annonce la suite.
struct LanguageStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Langue",
            title: "Micabo parle\nfrançais.",
            titleSize: 32,
            scrolls: false
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 13) {
                    Text("🇫🇷")
                        .font(.system(size: 22))

                    Text("Français")
                        .font(MicaboFont.hanken(16, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)

                    Spacer(minLength: MicaboSpacing.xs)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 19))
                        .foregroundStyle(MicaboColor.ink)
                }
                .padding(.vertical, 15)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                        .strokeBorder(MicaboColor.ink, lineWidth: 1.5)
                }

                Text("English, Español, Deutsch et Italiano arrivent bientôt.")
                    .font(MicaboFont.hanken(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}
