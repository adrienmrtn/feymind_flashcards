import SwiftUI

/// **Troisième écran sur l'épreuve : ce qui résiste.**
///
/// Le blanc a donné un score ; reste à savoir quoi en faire. C'est là que Micabo dit quelque
/// chose qu'aucun étudiant ne sait de lui-même : **quelles cartes exactement** lui coûtent
/// ses points. Une carte ratée quatre fois sur six n'est pas une carte comme les autres, et
/// la répétition espacée seule ne la traite pas différemment - elle ne regarde que le dernier
/// intervalle, jamais le taux d'échec.
///
/// L'écran montre donc trois cartes qui remontent en tête de file. C'est le geste que fait
/// l'app la veille d'une épreuve, et il vaut mieux le voir que le lire.
struct ExamWeakStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.examWeakTitle") ?? "Et ce qui résiste\npasse devant.",
            subtitle: i18n?.t("ios.examWeakLead"),
            titleSize: 28
        ) {
            WeakCardsDemo()
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Trois cartes fragiles qui remontent en tête de file, l'une après l'autre.
private struct WeakCardsDemo: View {
    /// Ce qu'on voit sur chaque ligne : le nombre d'échecs, et le nombre de passages. Ce
    /// sont les deux seuls chiffres qui disent « celle-ci te coûte des points ».
    private let cards: [(again: Int, reviews: Int)] = [(4, 6), (3, 5), (3, 7)]

    @State private var risen = 0
    @State private var didStart = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, locale: .fr, vars: vars)
    }

    var body: some View {
        VStack(spacing: 9) {
            ForEach(cards.indices, id: \.self) { index in
                row(at: index)
            }
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .onAppear(perform: run)
    }

    private func row(at index: Int) -> some View {
        let isUp = index < risen

        return HStack(spacing: 10) {
            Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MicaboColor.negative)
                .opacity(isUp ? 1 : 0)

            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(MicaboColor.surfaceMuted)
                    .frame(height: 8)
                    .frame(maxWidth: isUp ? .infinity : 140, alignment: .leading)

                Text(t("ios.examWeakLine", ["again": "\(cards[index].again)", "reviews": "\(cards[index].reviews)"]))
                    .font(MicaboFont.hanken(11.5, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: MicaboSpacing.xs)

            Text(t("ios.examWeakBadge"))
                .font(MicaboFont.hanken(10.5, weight: .bold))
                .foregroundStyle(MicaboColor.negative)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(MicaboColor.negativeSoft, in: Capsule())
                .opacity(isUp ? 1 : 0)
                .scaleEffect(isUp ? 1 : 0.85)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 11)
        .background(
            isUp ? MicaboColor.negativeSoft.opacity(0.35) : MicaboColor.surfaceMuted.opacity(0.5),
            in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
        )
        // La carte remonte : un décalage court, pas un ressort. Trois lignes qui rebondissent
        // ensemble donneraient une liste qui tremble.
        .offset(y: isUp ? 0 : 8)
        .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.4), value: isUp)
    }

    private func run() {
        guard !didStart else { return }
        didStart = true

        for index in cards.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45 + Double(index) * 0.22) {
                risen = index + 1
                Haptics.tick()
            }
        }
    }
}
