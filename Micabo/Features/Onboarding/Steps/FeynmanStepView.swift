import SwiftUI

/// **La méthode Feynman : expliquer à voix haute ce qu'on croit savoir.**
///
/// C'est la seule vérification que personne ne peut tricher. Un QCM se devine, un texte à trou
/// se retrouve, une carte qu'on retourne se reconnaît - « ah oui, je savais ». Une explication
/// dite à voix haute, sans notes, s'arrête net à l'endroit exact où la compréhension s'arrête,
/// et c'est cet endroit-là qu'on cherche.
///
/// L'écran le montre en trois temps : la question, l'explication qui bute, et le mot qui
/// manquait. Aucun paragraphe : on regarde quelqu'un se faire prendre en défaut, ce qui vaut
/// mieux que de lire qu'on pourrait l'être.
struct FeynmanStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.feynmanTitle") ?? "Explique-le à voix haute.\nTu sauras si tu sais.",
            subtitle: i18n?.t("ios.feynmanLead"),
            titleSize: 28
        ) {
            FeynmanDemo()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// L'explication qui bute : les mots se posent, puis l'hésitation, puis ce qui manquait.
private struct FeynmanDemo: View {
    /// L'explication, mot à mot. Elle s'arrête sur « parce que » : c'est toujours là que ça
    /// casse, au moment de dire *pourquoi* plutôt que *quoi*.
    private let words = ["L'eau", "s'évapore", "des", "océans", "parce", "que…"]

    @State private var spoken = 0
    @State private var hesitates = false
    @State private var showsGap = false
    @State private var didStart = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private func t(_ key: String) -> String {
        i18n?.t(key) ?? L10n.t(key, locale: .fr)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            question
            speech
            gap
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .onAppear(perform: run)
    }

    private var question: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)

            Text(t("ios.feynmanQuestion"))
                .font(MicaboFont.hanken(13.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Les mots arrivent un par un, comme on parle.
    private var speech: some View {
        HStack(spacing: 5) {
            ForEach(words.indices, id: \.self) { index in
                Text(words[index])
                    .font(MicaboFont.hanken(15, weight: .regular))
                    .foregroundStyle(MicaboColor.inkReading)
                    .opacity(index < spoken ? 1 : 0)
                    .offset(y: index < spoken ? 0 : 4)
                    .animation(.easeOut(duration: 0.22), value: spoken)
            }

            // Le curseur qui clignote pendant l'hésitation : c'est le silence, rendu visible.
            RoundedRectangle(cornerRadius: 1, style: .continuous)
                .fill(MicaboColor.negative)
                .frame(width: 2, height: 17)
                .opacity(hesitates ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: hesitates)

            Spacer(minLength: 0)
        }
        .frame(minHeight: 24, alignment: .leading)
    }

    private var gap: some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)

            Text(t("ios.feynmanGap"))
                .font(MicaboFont.hanken(12.5, weight: .medium))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        .opacity(showsGap ? 1 : 0)
        .offset(y: showsGap ? 0 : 6)
        .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.45), value: showsGap)
    }

    private func run() {
        guard !didStart else { return }
        didStart = true

        for index in words.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(index) * 0.26) {
                spoken = index + 1
            }
        }

        let end = 0.4 + Double(words.count) * 0.26
        DispatchQueue.main.asyncAfter(deadline: .now() + end) {
            hesitates = true
            Haptics.warning()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + end + 1.1) {
            hesitates = false
            showsGap = true
            Haptics.success()
        }
    }
}
