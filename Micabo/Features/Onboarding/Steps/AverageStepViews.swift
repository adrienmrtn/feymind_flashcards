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
            scrolls: false,
            expandsContent: true
        ) {
            // La roue a sa hauteur à elle ; les ressorts la posent au milieu de ce qui reste.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
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
                Spacer(minLength: 0)
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
            scrolls: false,
            expandsContent: true
        ) {
            if !isAtTop {
                VStack(spacing: 22) {
                    Spacer(minLength: 0)

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

                    Spacer(minLength: 0)
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

// MARK: - La roue

/// **La roue des notes de l'accueil**, qui est celle du parcours de deck.
///
/// C'était un `Slider` du système : un rail, une pastille, la valeur écrite au-dessus en
/// quarante-huit points, et les deux bornes du barème en petit dessous. Ça marchait, et ça ne
/// ressemblait à rien de ce que la maquette décrit — elle ne montre pas un rail mais **une
/// colonne de notes**, celle qu'on a choisie au centre en gros violet sur un lavis, et les
/// voisines qui s'effacent de chaque côté.
///
/// La différence n'est pas décorative. Un curseur cache l'échelle : on lit sa valeur et deux
/// bornes, on ne voit jamais ce qu'il y a juste à côté. La colonne montre les notes voisines
/// en même temps que la sienne, ce qui est exactement la question posée — non pas « où suis-je
/// sur une échelle », mais « laquelle de ces notes est la mienne ».
///
/// **C'est `VerticalGradePicker`, pas un second exemplaire.** Le parcours de création d'un
/// deck pose déjà la question de la note visée, et il la pose avec cette colonne-là : en
/// écrire une deuxième ici aurait donné deux façons de choisir une note dans la même app,
/// qui auraient cessé de se ressembler au premier réglage. Il ne reste donc de propre à
/// l'accueil que ce qui lui est vraiment propre : une réponse qui peut être vide, et qu'on
/// écrit dès l'arrivée — une roue qui montre 15 sans que 15 soit enregistré ferait refuser
/// le bouton Continuer sans dire pourquoi.
private struct GradeWheel: View {
    let choices: [GradeTick]
    @Binding var score: Int?
    /// Le cran de départ, quand rien n'a encore été choisi. Le milieu, sauf avis contraire.
    var fallbackIndex: Int?
    let label: String

    private var start: Int {
        Swift.min(Swift.max(0, fallbackIndex ?? (choices.count - 1) / 2), Swift.max(0, choices.count - 1))
    }

    private var fallbackScore: Int {
        choices.indices.contains(start) ? choices[start].score : TargetScore.default
    }

    var body: some View {
        VerticalGradePicker(
            ticks: choices,
            score: Binding(
                get: { score ?? fallbackScore },
                set: { score = $0 }
            )
        )
        .accessibilityLabel(label)
        .onAppear {
            // La réponse existe dès l'affichage : voir plus haut.
            if score == nil { score = fallbackScore }
        }
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
