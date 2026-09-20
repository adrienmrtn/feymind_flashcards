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
            // **Sans défilement, sinon la roue n'a pas de hauteur.** `expandsContent` ne
            // donne la hauteur restante au contenu que hors d'un `ScrollView` ; dedans, un
            // `GeometryReader` se voit proposer dix points, et la roue s'écrasait en une
            // bande de vingt points avec un chiffre coupé. C'est ce que montrait la capture.
            scrolls: false,
            animatesTitle: true,
            expandsContent: true
        ) {
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
            subtitle: isAtTop ? i18n.t("ios.targetAtTop") : nil,
            titleSize: 26,
            scrolls: false,
            animatesTitle: true,
            expandsContent: true
        ) {
            if !isAtTop {
                VStack(spacing: 22) {
                    GradeWheel(
                        choices: choices,
                        score: Binding(
                            get: { model.targetScore },
                            set: { model.targetScore = $0 }
                        ),
                        // Deux crans au-dessus du départ : un objectif qui s'ouvre sur la
                        // valeur juste au-dessus de la sienne ne ressemble pas à un objectif.
                        fallbackIndex: 1,
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
            GradeJourney(
                from: label(for: model.currentScore) ?? i18n.t("ios.averageBelowShort"),
                to: label(for: model.targetScore) ?? scale.max,
                deadline: deadlineLabel
            )
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.journey.commit")) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        MicaboOutlineCard {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                        .fill(MicaboColor.flameSoft)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(MicaboColor.flame)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(i18n.t("ios.target.gap", ["count": "\(points)"]))
                            .font(MicaboFont.ui(15, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)

                        Text(i18n.t(reachKey))
                            .font(MicaboFont.ui(11, weight: .heavy))
                            .foregroundStyle(MicaboColor.flameInk)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(MicaboColor.flameTrack, in: Capsule())
                    }

                    Text(i18n.t("ios.target.todayAt", ["grade": scale.label(for: current)]))
                        .font(MicaboFont.ui(13, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
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
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous)
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

