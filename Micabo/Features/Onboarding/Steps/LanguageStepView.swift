import SwiftUI

/// Écran 3 : choix de la langue. Seul le français est disponible pour l'instant,
/// les autres restent visibles mais grisées.
struct LanguageStepView: View {
    @Environment(OnboardingModel.self) private var model

    private struct Language: Identifiable {
        let id: String
        let flag: String
        let name: String
        let isAvailable: Bool
    }

    private let languages: [Language] = [
        Language(id: "fr", flag: "🇫🇷", name: "Français", isAvailable: true),
        Language(id: "en", flag: "🇬🇧", name: "English", isAvailable: false),
        Language(id: "es", flag: "🇪🇸", name: "Español", isAvailable: false),
        Language(id: "de", flag: "🇩🇪", name: "Deutsch", isAvailable: false),
        Language(id: "it", flag: "🇮🇹", name: "Italiano", isAvailable: false)
    ]

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Langue",
            title: "Dans quelle langue veux-tu utiliser Micabo ?",
            subtitle: "Les autres langues arrivent bientôt. Tu pourras changer d'avis à tout moment."
        ) {
            VStack(spacing: 10) {
                ForEach(languages) { language in
                    LanguageRow(
                        flag: language.flag,
                        name: language.name,
                        isAvailable: language.isAvailable
                    )
                }
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

private struct LanguageRow: View {
    let flag: String
    let name: String
    let isAvailable: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(flag)
                .font(.system(size: 24))
                .frame(width: 42, height: 42)
                .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
                .saturation(isAvailable ? 1 : 0)

            Text(name)
                .font(MicaboFont.hanken(16, weight: .semibold))
                .foregroundStyle(isAvailable ? MicaboColor.ink : MicaboColor.inkTertiary)

            Spacer(minLength: MicaboSpacing.xs)

            if isAvailable {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(MicaboColor.ink)
            } else {
                Text("Bientôt")
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(MicaboColor.surfaceMuted, in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isAvailable ? MicaboColor.surface : MicaboColor.surface.opacity(0.5),
            in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(isAvailable ? MicaboColor.ink : MicaboColor.stroke, lineWidth: isAvailable ? 1.6 : 1)
        }
        .opacity(isAvailable ? 1 : 0.55)
    }
}
