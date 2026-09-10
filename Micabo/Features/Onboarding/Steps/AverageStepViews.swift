import SwiftUI

/// **Les deux moyennes, et la promesse qui les relie.**
///
/// Trois écrans qui arrivent juste avant la construction du parcours, parce que c'est elle
/// qui s'en sert : l'écart entre ce qu'on a et ce qu'on vise règle l'intensité du plan -
/// deux passages par carte, ou quatre.
///
/// Ce sont aussi les deux seuls chiffres qu'un étudiant connaît vraiment sur lui-même. Tout
/// le reste du parcours demande des catégories - un pays, un palier, des matières - et
/// celles-ci se choisissent sans y penser. Une moyenne, on la sait.

/// La moyenne d'aujourd'hui.
///
/// La question ne juge pas, et la phrase le dit : on demande à quelqu'un d'écrire son plus
/// mauvais chiffre à une app qu'il vient d'installer. Le premier cran du curseur est **en
/// dessous** du barème, parce qu'une échelle qui commence à la moyenne annonce à celui qui ne
/// l'a pas qu'il n'était pas prévu.
struct CurrentAverageStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var scale: DesiredGradeScale {
        DesiredGradeScale.for(model.country)
    }

    /// Le barème du pays, précédé du cran « moins que ça ».
    private var choices: [GradeTick] {
        let below = GradeTick(
            score: DesiredGradeScale.belowScore,
            label: i18n?.t("ios.averageBelow", ["grade": scale.choices.first?.label ?? ""])
                ?? "Moins de \(scale.choices.first?.label ?? "")"
        )
        return [below] + scale.choices
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.averageTitle") ?? "Quelle est ta moyenne\nen ce moment ?",
            subtitle: i18n?.t("ios.averageLead"),
            titleSize: 28,
            animatesTitle: true,
            expandsContent: true
        ) {
            GradeSlider(
                choices: choices,
                score: Binding(
                    get: { model.currentScore },
                    set: { newValue in
                        model.currentScore = newValue
                        // Un objectif hérité d'une moyenne plus basse n'a plus cours : le
                        // laisser afficherait un but déjà atteint sur l'écran suivant.
                        if let target = model.targetScore, let newValue, target <= newValue {
                            model.targetScore = nil
                        }
                    }
                ),
                label: i18n?.t("ios.averageTitle") ?? "Ta moyenne"
            )
        } footer: {
            OnboardingContinueButton(isEnabled: model.currentScore != nil) {
                model.advance()
            }
        }
    }
}

/// La moyenne visée.
///
/// Elle ne peut qu'être au-dessus de l'actuelle. Les notes plus basses ne sont pas grisées,
/// elles ne sont pas là : un cran qui refuse d'être atteint est une question à laquelle on
/// n'a pas compris la réponse.
struct TargetAverageStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var choices: [GradeTick] {
        DesiredGradeScale.for(model.country).targets(above: model.currentScore)
    }

    /// Celui qui a déjà le haut du barème n'a rien à choisir : il le lit, et il continue.
    private var isAtTop: Bool { choices.isEmpty }

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.targetTitle") ?? "Et tu vises\ncombien ?",
            subtitle: isAtTop ? i18n?.t("ios.targetAtTop") : i18n?.t("ios.targetLead"),
            titleSize: 28,
            animatesTitle: true,
            expandsContent: true
        ) {
            if !isAtTop {
                GradeSlider(
                    choices: choices,
                    score: Binding(
                        get: { model.targetScore },
                        set: { model.targetScore = $0 }
                    ),
                    // Deux crans au-dessus du départ : un objectif qui s'ouvre sur la valeur
                    // juste au-dessus de la sienne ne ressemble pas à un objectif.
                    fallbackIndex: 1,
                    label: i18n?.t("ios.targetTitle") ?? "Ta moyenne visée"
                )
            }
        } footer: {
            OnboardingContinueButton(isEnabled: isAtTop || model.targetScore != nil) {
                model.advance()
            }
        }
    }
}

/// « On va t'aider à y arriver. »
///
/// L'écran qui suit les deux moyennes ne demande rien. Il vient de faire écrire un chiffre bas
/// et un chiffre haut ; entre les deux il y a un écart, et l'écart tout seul décourage. Ce que
/// cet écran ajoute, c'est le chemin : d'où l'on part, où l'on va, et par où l'on passe.
struct TogetherStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var scale: DesiredGradeScale {
        DesiredGradeScale.for(model.country)
    }

    private func label(for score: Int?) -> String? {
        guard let score, score >= TargetScore.min else { return nil }
        return scale.label(for: score)
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n?.t("ios.togetherTitle") ?? "On va t'aider\nà y arriver.",
            titleSize: 28
        ) {
            GradeJourney(
                from: label(for: model.currentScore) ?? (i18n?.t("ios.averageBelowShort") ?? "Aujourd'hui"),
                to: label(for: model.targetScore) ?? scale.max
            )
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

// MARK: - Le curseur

/// **Le curseur de moyenne.**
///
/// Un curseur, et pas douze boutons : ces douze valeurs sont une seule chose qui monte, et un
/// curseur le dit d'un trait. On voit tout de suite où l'on est sur l'échelle, et déplacer le
/// pouce d'un cran est plus rapide que viser un bouton.
///
/// La valeur est **écrite dès l'arrivée**. Un curseur qui montre 15/20 sans que 15/20 soit la
/// réponse enregistrée est un piège : le bouton Continuer refuserait d'avancer sans dire
/// pourquoi. Ce qu'on voit est ce qui compte.
private struct GradeSlider: View {
    let choices: [GradeTick]
    @Binding var score: Int?
    /// Le cran de départ, quand rien n'a encore été choisi. Le milieu, sauf avis contraire.
    var fallbackIndex: Int?
    let label: String

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var start: Int {
        Swift.min(Swift.max(0, fallbackIndex ?? (choices.count - 1) / 2), Swift.max(0, choices.count - 1))
    }

    private var index: Int {
        guard let score, let found = choices.firstIndex(where: { $0.score == score }) else {
            return start
        }
        return found
    }

    var body: some View {
        VStack(spacing: MicaboSpacing.lg) {
            Text(choices.indices.contains(index) ? choices[index].label : "")
                .font(MicaboFont.number(48, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.18), value: index)

            slider

            HStack {
                Text(choices.first?.label ?? "")
                Spacer(minLength: MicaboSpacing.sm)
                Text(choices.last?.label ?? "")
            }
            .font(MicaboFont.hanken(12, weight: .medium))
            .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(MicaboSpacing.lg)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .onAppear {
            // La réponse existe dès l'affichage : voir plus haut.
            if score == nil, choices.indices.contains(start) { score = choices[start].score }
        }
    }

    /// Le `Slider` du système, sur des crans entiers. Le clavier, l'accessibilité et le
    /// glisser au doigt sont les siens : une reconstruction maison en perd toujours la moitié.
    private var slider: some View {
        Slider(
            value: Binding(
                get: { Double(index) },
                set: { newValue in
                    let rank = Int(newValue.rounded())
                    guard choices.indices.contains(rank) else { return }
                    if choices[rank].score != score { Haptics.selection() }
                    score = choices[rank].score
                }
            ),
            in: 0...Double(Swift.max(1, choices.count - 1)),
            step: 1
        )
        .tint(MicaboColor.accent)
        .accessibilityLabel(label)
        .accessibilityValue(choices.indices.contains(index) ? choices[index].label : "")
    }
}

// MARK: - Le chemin

/// **D'où l'on part, où l'on va, et le chemin parcouru sous les yeux.**
///
/// La première version remplissait un trait de gauche à droite et s'arrêtait là : une barre de
/// chargement, sur un écran qui ne charge rien. Ici quelque chose **voyage** - un point part du
/// chiffre d'aujourd'hui, remonte le trait, et l'objectif s'allume à son arrivée. C'est la
/// seule page du parcours qui promet quelque chose ; elle doit se regarder jusqu'au bout.
private struct GradeJourney: View {
    let from: String
    let to: String

    @State private var drawn = false
    @State private var arrived = false

    var body: some View {
        HStack(spacing: MicaboSpacing.sm) {
            marker(value: from, tint: MicaboColor.inkTertiary, background: MicaboColor.surfaceMuted)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MicaboColor.surfaceMuted)
                        .frame(height: 5)

                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: drawn ? proxy.size.width : 0, height: 5)

                    // Le point qui remonte le trait. Il est en tête du remplissage, pas
                    // dessus : c'est lui qui tire, le trait est sa trace.
                    Circle()
                        .fill(MicaboColor.accent)
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle()
                                .stroke(MicaboColor.accent.opacity(0.28), lineWidth: arrived ? 0 : 7)
                                .scaleEffect(arrived ? 1 : 1.4)
                        )
                        .offset(x: (drawn ? proxy.size.width : 0) - 5.5)
                        .opacity(arrived ? 0 : 1)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)

            marker(value: to, tint: MicaboColor.onInk, background: MicaboColor.accent)
                // L'objectif s'allume quand le point arrive : un petit sursaut, et c'est fini.
                .scaleEffect(arrived ? 1 : 0.88)
                .opacity(arrived ? 1 : 0.45)
        }
        .padding(MicaboSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous))
        .animation(.timingCurve(0.25, 0.9, 0.25, 1, duration: 1.05).delay(0.3), value: drawn)
        .animation(.spring(response: 0.42, dampingFraction: 0.6), value: arrived)
        .task {
            drawn = true
            try? await Task.sleep(for: .milliseconds(1_280))
            arrived = true
            Haptics.success()
        }
    }

    private func marker(value: String, tint: Color, background: Color) -> some View {
        Text(value)
            .font(MicaboFont.number(17, weight: .bold))
            .foregroundStyle(tint)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.vertical, 10)
            .padding(.horizontal, 13)
            .background(background, in: Capsule())
    }
}
