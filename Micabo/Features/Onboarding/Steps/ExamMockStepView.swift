import SwiftUI

/// **Deuxième écran sur l'épreuve : l'examen blanc.**
///
/// C'est le seul moment où Micabo **mesure** au lieu d'estimer. Tout le reste juge carte par
/// carte - la bonne échelle pour apprendre, la mauvaise pour prévoir une note : réussir
/// quatre-vingts pour cent de ses cartes une par une, chacune sortie de son contexte, ne dit
/// pas qu'on saura répondre à vingt questions d'affilée sur tout le programme, en temps
/// imparti. C'est exactement l'écart que les étudiants découvrent le jour J.
///
/// L'écran le montre plutôt que de l'expliquer : une copie se remplit, les questions se
/// cochent, et un score tombe. Le chiffre annoncé est **la copie qu'on vient de voir passer**,
/// pas une statistique inventée.
struct ExamMockStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.examMockTitle") ?? "Un examen blanc,\nà J-7 et à J-2.",
            subtitle: i18n?.t("ios.examMockLead"),
            titleSize: 28
        ) {
            MockPaperDemo()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// La copie de démonstration : six questions qui se corrigent, et le score qui monte avec.
private struct MockPaperDemo: View {
    /// Ce que valent les six questions. Deux ratées : une copie parfaite ne dirait rien de ce
    /// que l'examen blanc sert à trouver.
    private let answers: [Bool] = [true, true, false, true, false, true]

    @State private var graded = 0
    @State private var showsScore = false
    @State private var didStart = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, locale: .fr, vars: vars)
    }

    /// Le score de la copie, calculé sur ce qui est corrigé. Il n'est écrit nulle part : il
    /// compte les bonnes réponses qu'on vient de voir se cocher.
    private var score: Int {
        let done = answers.prefix(graded)
        guard !done.isEmpty else { return 0 }
        return Int((Double(done.filter { $0 }.count) / Double(answers.count) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            questions
            footer
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .onAppear(perform: run)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MicaboColor.caution)

            Text(t("ios.examMockPaper"))
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)

            Spacer(minLength: MicaboSpacing.xs)

            Text(t("ios.examMockMinutes", ["n": "15"]))
                .font(MicaboFont.number(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .monospacedDigit()
        }
    }

    private var questions: some View {
        VStack(spacing: 7) {
            ForEach(answers.indices, id: \.self) { index in
                row(at: index)
            }
        }
    }

    private func row(at index: Int) -> some View {
        let isGraded = index < graded
        let isRight = answers[index]

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(isGraded ? (isRight ? MicaboColor.accentSoft : MicaboColor.negativeSoft) : MicaboColor.surfaceMuted)
                    .frame(width: 22, height: 22)

                Image(systemName: isRight ? "checkmark" : "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isRight ? MicaboColor.accent : MicaboColor.negative)
                    .opacity(isGraded ? 1 : 0)
                    .scaleEffect(isGraded ? 1 : 0.5)
            }

            // La question elle-même reste illisible : ce n'est pas ce qu'on regarde, et une
            // vraie question de biologie sur cet écran ferait lire au lieu de comprendre.
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(MicaboColor.surfaceMuted)
                .frame(height: 8)
                .frame(maxWidth: .infinity)
                .opacity(isGraded ? 1 : 0.55)

            Spacer(minLength: 0)
        }
        .frame(height: 26)
        .animation(.spring(response: 0.3, dampingFraction: 0.62), value: isGraded)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Text(t("ios.examMockScore"))
                .font(MicaboFont.hanken(12.5, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)

            Spacer(minLength: MicaboSpacing.xs)

            Text("\(score) %")
                .font(MicaboFont.number(20, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: score)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 12)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        .opacity(showsScore ? 1 : 0)
        .animation(.easeOut(duration: 0.35), value: showsScore)
    }

    /// Les questions se corrigent l'une après l'autre, puis le score se pose.
    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showsScore = true }

        for index in answers.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.24) {
                graded = index + 1
                if answers[index] {
                    Haptics.tick()
                } else {
                    Haptics.warning()
                }
            }
        }
    }
}
