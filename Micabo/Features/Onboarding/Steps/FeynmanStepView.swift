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
    @State private var isSpeaking = false
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
        .task { await run() }
    }

    private var question: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .padding(.top, 2)

            Text(t("ios.feynmanQuestion"))
                .font(MicaboFont.hanken(13.5, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 6)

            VoiceBars(isSpeaking: isSpeaking)
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
                    .offset(y: index < spoken ? 0 : 5)
                    .blur(radius: index < spoken ? 0 : 1.5)
                    .animation(.spring(response: 0.34, dampingFraction: 0.72), value: spoken)
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

    /// **On ne parle pas au métronome.**
    ///
    /// Les mots tombaient tous les 260 millisecondes, ce qui s'entend à l'œil : c'est une
    /// machine qui débite, pas quelqu'un qui explique. Un mot long tient plus longtemps, et la
    /// phrase **ralentit** sur les deux derniers - juste avant l'endroit où elle va casser.
    /// C'est ce ralentissement qui rend l'hésitation crédible quand elle arrive.
    private func run() async {
        guard !didStart else { return }
        didStart = true

        try? await Task.sleep(for: .milliseconds(380))
        isSpeaking = true

        for index in words.indices {
            spoken = index + 1
            let held = 120 + words[index].count * 28
            let braking = index >= words.count - 2 ? 170 : 0
            try? await Task.sleep(for: .milliseconds(held + braking))
        }

        // Le silence : la voix s'arrête, les barres retombent à plat, le curseur clignote.
        isSpeaking = false
        hesitates = true
        Haptics.warning()

        try? await Task.sleep(for: .milliseconds(1_250))
        hesitates = false
        showsGap = true
        Haptics.success()
    }
}

/// **Le niveau du micro**, six barres qui vivent tant qu'on parle.
///
/// Elles retombent à plat dans l'hésitation, et c'est tout leur intérêt : un silence ne se lit
/// pas sur du texte qui a simplement cessé d'avancer. Là, on le voit.
private struct VoiceBars: View {
    let isSpeaking: Bool

    @State private var lively = false

    private let heights: [CGFloat] = [7, 14, 19, 10, 16, 8]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(isSpeaking ? MicaboColor.accent : MicaboColor.strokeStrong)
                    .frame(width: 3, height: isSpeaking && lively ? heights[index] : 3)
                    .animation(
                        .easeInOut(duration: 0.3 + Double(index) * 0.07).repeatForever(autoreverses: true),
                        value: lively
                    )
            }
        }
        .frame(height: 20)
        .animation(.easeOut(duration: 0.3), value: isSpeaking)
        .onAppear { lively = true }
        .accessibilityHidden(true)
    }
}
