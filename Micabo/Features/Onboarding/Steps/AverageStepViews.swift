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
            label: i18n.t("ios.averageBelow", ["grade": scale.choices.first?.label ?? ""])
        )
        return [below] + scale.choices
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.averageTitle"),
            subtitle: i18n.t("ios.averageSub"),
            // **Sans défilement, sinon la roue n'a pas de hauteur.** `expandsContent` ne
            // donne la hauteur restante au contenu que hors d'un `ScrollView` ; dedans, un
            // `GeometryReader` se voit proposer dix points, et la roue s'écrasait en une
            // bande de vingt points avec un chiffre coupé. C'est ce que montrait la capture.
            scrolls: true
        ) {
            VStack(spacing: 0) {
                GradeWheel(
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
                    label: i18n.t("ios.averageTitle")
                )
            }
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
            title: i18n.t("ios.targetTitle"),
            // Rien quand il reste quelque chose à choisir : `ios.targetLead` expliquait
            // comment répondre à une question qui n'en a pas besoin. La ligne du haut du
            // barème, elle, n'explique pas — elle remplace la roue.
            subtitle: isAtTop ? i18n.t("ios.targetAtTop") : i18n.t("ios.targetSub"),
            scrolls: true
        ) {
            if !isAtTop {
                VStack(spacing: 22) {
                    GradeWheel(
                        choices: choices,
                        score: Binding(
                            get: { model.targetScore },
                            set: { model.targetScore = $0 }
                        ),
                        // Le milieu de ce qui reste à viser : la roue s'ouvre avec des notes
                        // des deux côtés, et un objectif qui n'est ni le cran juste
                        // au-dessus du sien ni le haut du barème.
                        fallbackIndex: (choices.count - 1) / 2,
                        label: i18n.t("ios.targetTitle")
                    )

                    if let current = model.currentScore, let target = model.targetScore {
                        GradeGapCard(
                            current: current,
                            target: target,
                            scale: DesiredGradeScale.for(model.country)
                        )
                        .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.18), value: model.targetScore)
            }
        } footer: {
            OnboardingContinueButton(isEnabled: isAtTop || model.targetScore != nil) {
                model.advance()
            }
        }
    }
}

// MARK: - La grille

/// **Les notes en grille, trois par ligne.** La colonne qui défilait était partagée avec
/// le parcours de deck et ne répondait pas comme une question : on ne voyait pas où
/// appuyer, et la note choisie se lisait en violet pâle au milieu de neuf notes grises.
/// Une grille de cartes se lit comme toutes les autres questions du quiz : gris, et noir
/// quand c'est choisi.
private struct GradeWheel: View {
    let choices: [GradeTick]
    @Binding var score: Int?
    /// Conservé pour les appels existants ; la grille n'a pas de cran de départ.
    var fallbackIndex: Int?
    let label: String

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(choices.enumerated()), id: \.element.id) { rank, tick in
                Button {
                    score = tick.score
                } label: {
                    Text(tick.label)
                        .font(MicaboFont.ui(20, weight: .bold))
                        .foregroundStyle(score == tick.score ? OnboardingPalette.white : OnboardingPalette.ink)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            score == tick.score ? OnboardingPalette.ink : OnboardingPalette.card,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .animation(OnboardingMotion.select, value: score)
                .onboardingAppear(index: 3 + rank, stagger: OnboardingMotion.rowStagger)
            }
        }
        .accessibilityLabel(label)
    }
}

// MARK: - L'écart

/// **Ce qui sépare la note d'aujourd'hui de celle qu'on vise.**
///
/// La carte de la maquette, sous la roue : combien de points il y a à prendre, à quel point
/// c'est ambitieux, et d'où l'on part. Ce n'est pas un sous-titre qui explique l'écran —
/// c'est un fait sur l'étudiant, produit par les deux réponses qu'il vient de donner, et il
/// n'a rien à lire tant qu'il n'a pas répondu.
struct GradeGapCard: View {
    let current: Int
    let target: Int
    let scale: DesiredGradeScale

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var points: Int { Swift.max(0, target - current) }

    /// Trois paliers, et rien de plus fin : au-delà de quatre points d'écart, personne ne
    /// distingue « très ambitieux » de « ambitieux », et prétendre le contraire donnerait une
    /// étiquette qui n'engage rien.
    private var reachKey: String {
        switch points {
        case ...2: "ios.target.reach.near"
        case ...4: "ios.target.reach.fair"
        default: "ios.target.reach.bold"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(OnboardingPalette.white)
                .frame(width: 42, height: 42)
                .background(OnboardingPalette.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(i18n.t("ios.target.gap", ["count": "\(points)"]))
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(OnboardingPalette.ink)

                    Text(i18n.t(reachKey))
                        .font(MicaboFont.ui(11, weight: .bold))
                        .foregroundStyle(OnboardingPalette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(OnboardingPalette.accentWash, in: Capsule())
                }

                Text(i18n.t("ios.target.todayAt", ["grade": scale.label(for: current)]))
                    .font(OnboardingPalette.subtitle)
                    .foregroundStyle(OnboardingPalette.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
