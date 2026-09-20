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
            titleSize: 26,
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
                label: i18n.t("ios.averageTitle")
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
            title: i18n.t("ios.targetTitle"),
            subtitle: isAtTop ? i18n.t("ios.targetAtTop") : i18n.t("ios.targetLead"),
            titleSize: 26,
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
                    label: i18n.t("ios.targetTitle")
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

    /// L'échéance annoncée : la fin de l'année scolaire, pas une date choisie.
    ///
    /// Personne n'a demandé à cet étudiant pour quand il visait sa moyenne, et lui faire
    /// choisir un mois ici serait une douzième question pour un graphe. Juin est la réponse
    /// pour à peu près tout le monde dans les quatre pays décrits, et c'est le seul repère
    /// que la courbe a besoin de nommer.
    private var deadlineLabel: String {
        let calendar = MicaboCalendar.shared
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        // Après juin, l'année scolaire visée est la suivante.
        var components = DateComponents()
        components.year = month >= 7 ? year + 1 : year
        components.month = 6
        components.day = 1
        guard let june = calendar.date(from: components) else { return "" }
        return june.formatted(.dateTime.month(.wide)).localizedCapitalized
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.togetherTitle"),
            titleSize: 26
        ) {
            VStack(spacing: 14) {
                GradeJourney(
                    from: label(for: model.currentScore) ?? i18n.t("ios.averageBelowShort"),
                    to: label(for: model.targetScore) ?? scale.max,
                    deadline: deadlineLabel
                )

                GradeEvidence()
            }
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.journey.commit")) {
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
            .font(MicaboFont.ui(12, weight: .medium))
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
/// **La progression prévue, et la zone de maintien.**
///
/// Ce qui vivait ici était une barre horizontale avec un point qui la remonte : « de 11 à
/// 16 », en une ligne. C'est juste et c'est plat — une barre qui se remplit ne dit pas qu'un
/// progrès est **lent d'abord, rapide ensuite**, ni qu'il y a un après.
///
/// La courbe le dit. Elle part à plat, monte, et s'arrête à la date visée ; au-delà, un
/// trait vert horizontal sur fond vert pâle, qui est la seule promesse honnête qu'on puisse
/// faire après l'objectif : **maintenir**. Une courbe qui continuerait de monter après juin
/// promettrait vingt sur vingt, et personne n'y croit.
///
/// **Le tracé est le même quelles que soient les notes.** C'est une forme, pas une
/// prédiction : on ne sait pas de combien quelqu'un progressera, et faire varier la courbure
/// selon l'écart entre les deux notes laisserait croire qu'on a calculé quelque chose.
private struct GradeJourney: View {
    let from: String
    let to: String
    let deadline: String

    @State private var drawn: CGFloat = 0
    @State private var arrived = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.t("ios.journey.title", locale: .resolved()))
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)

            chart
                .frame(height: 168)

            HStack {
                Text(L10n.t("ios.journey.today", locale: .resolved()))
                Spacer(minLength: 0)
                Text(deadline)
            }
            .font(MicaboFont.ui(12.5, weight: .semibold))
            .foregroundStyle(MicaboColor.inkSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .task {
            withAnimation(.timingCurve(0.25, 0.9, 0.25, 1, duration: 1.15).delay(0.25)) {
                drawn = 1
            }
            try? await Task.sleep(for: .milliseconds(1_320))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.6)) { arrived = true }
            Haptics.success()
        }
    }

    /// Les proportions du tracé, en fractions de la boîte. Elles sont écrites une fois ici
    /// plutôt que dispersées dans les calculs : le point d'arrivée de la courbe, le début de
    /// la zone de maintien et la position de la pastille doivent tomber au même endroit, et
    /// trois nombres recopiés finissent toujours par diverger d'un point.
    private enum Layout {
        /// L'abscisse où la courbe atteint l'objectif, et où commence le maintien.
        static let goalX: CGFloat = 0.62
        /// L'ordonnée de départ et celle de l'objectif.
        static let startY: CGFloat = 0.86
        static let goalY: CGFloat = 0.21
        static let leftInset: CGFloat = 0.06
    }

    private var chart: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let start = CGPoint(x: w * Layout.leftInset, y: h * Layout.startY)
            let goal = CGPoint(x: w * Layout.goalX, y: h * Layout.goalY)

            ZStack(alignment: .topLeading) {
                grid(width: w, height: h)

                // La zone de maintien, posée avant les traits : c'est un fond, pas un objet.
                Rectangle()
                    .fill(MicaboColor.positiveWash)
                    .frame(width: w - goal.x, height: h * 0.72)
                    .offset(x: goal.x, y: h * 0.14)
                    .opacity(arrived ? 1 : 0)

                // La montée, tracée au fil de l'animation.
                curve(from: start, to: goal)
                    .trim(from: 0, to: drawn)
                    .stroke(MicaboColor.accentPale, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

                // Le maintien, qui n'apparaît qu'une fois l'objectif atteint.
                Path { path in
                    path.move(to: goal)
                    path.addLine(to: CGPoint(x: w, y: goal.y))
                }
                .trim(from: 0, to: arrived ? 1 : 0)
                .stroke(MicaboColor.positive, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

                dot(at: start, stroke: MicaboColor.ink, size: 13)
                dot(at: goal, stroke: MicaboColor.positive, size: 14)
                    .opacity(arrived ? 1 : 0)
                    .scaleEffect(arrived ? 1 : 0.7)

                labels(width: w, height: h, start: start, goal: goal)
            }
            .animation(.easeOut(duration: 0.35), value: arrived)
        }
    }

    /// Trois filets pointillés. Ils ne portent pas d'échelle : ils donnent une assise à la
    /// courbe, et une échelle chiffrée sur une forme qui n'est pas une prédiction serait un
    /// mensonge de précision.
    private func grid(width: CGFloat, height: CGFloat) -> some View {
        Path { path in
            for fraction in [0.2, 0.42, 0.64] {
                path.move(to: CGPoint(x: width * Layout.leftInset, y: height * fraction))
                path.addLine(to: CGPoint(x: width * 0.98, y: height * fraction))
            }
        }
        .stroke(MicaboColor.stroke, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
    }

    private func curve(from start: CGPoint, to goal: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            path.addCurve(
                to: goal,
                // Plate au départ, redressée à l'arrivée : c'est la forme d'un progrès qui
                // met du temps à se voir.
                control1: CGPoint(x: start.x + (goal.x - start.x) * 0.35, y: start.y),
                control2: CGPoint(x: start.x + (goal.x - start.x) * 0.64, y: goal.y + 12)
            )
        }
    }

    private func dot(at point: CGPoint, stroke: Color, size: CGFloat) -> some View {
        Circle()
            .fill(MicaboColor.canvas)
            .overlay(Circle().strokeBorder(stroke, lineWidth: 3))
            .frame(width: size, height: size)
            .position(point)
    }

    @ViewBuilder
    private func labels(width: CGFloat, height: CGFloat, start: CGPoint, goal: CGPoint) -> some View {
        Text(from)
            .font(MicaboFont.ui(17, weight: .heavy))
            .foregroundStyle(MicaboColor.ink)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .position(x: width * 0.03, y: start.y - 22)

        Text(to)
            .font(MicaboFont.ui(13, weight: .heavy))
            .foregroundStyle(MicaboColor.onInk)
            .monospacedDigit()
            .padding(.vertical, 3)
            .padding(.horizontal, 11)
            .background(MicaboColor.positive, in: Capsule())
            .position(x: goal.x, y: goal.y - 22)
            .opacity(arrived ? 1 : 0)

        Text(L10n.t("ios.journey.hold", locale: .resolved()))
            .font(MicaboFont.ui(11, weight: .bold))
            .foregroundStyle(MicaboColor.positiveInk)
            .position(x: goal.x + (width - goal.x) * 0.42, y: goal.y + 26)
            .opacity(arrived ? 1 : 0)
    }
}

/// **La preuve, sous le graphe.**
///
/// Une phrase, un chiffre en gras, et sa source nommée. C'est le seul endroit du parcours qui
/// cite une étude, et elle est citée parce qu'elle justifie la seule chose que l'app demande
/// vraiment : se tester plutôt que relire. Sans référence, ce serait un argument de brochure.
private struct GradeEvidence: View {
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(MicaboColor.positiveWash)
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MicaboColor.positiveInk)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text.micaboMarkup(L10n.t("ios.journey.evidence", locale: .resolved()))
                    .font(MicaboFont.ui(14.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.t("ios.journey.source", locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}
