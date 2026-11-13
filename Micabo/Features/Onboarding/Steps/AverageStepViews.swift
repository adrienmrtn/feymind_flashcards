import SwiftUI

// Les deux moyennes, et la projection qui les relie. Ce sont les deux seuls chiffres qu'un
// élève connaît vraiment sur lui-même ; ils se disent dans SON barème (`StudentGradeScale`) :
// sur 20, en Notenpunkte, en GPA, en lettres.

// MARK: - La moyenne d'aujourd'hui

/// **« Ta moyenne en ce moment, à peu près ? »**
///
/// La question ne juge pas : la première valeur de la molette est **en dessous** du barème,
/// parce qu'une échelle qui commence à la moyenne annonce à celui qui ne l'a pas qu'il n'était
/// pas prévu. Elle est facultative : « Passer », en haut à droite, saute aussi la moyenne
/// visée.
struct CurrentAverageStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Le barème de l'élève, précédé du cran « moins que ça ».
    private var choices: [GradeTick] {
        let scale = model.gradeScale.scale
        let below = GradeTick(
            score: DesiredGradeScale.belowScore,
            label: i18n.t("ios.averageBelow", ["grade": scale.choices.first?.label ?? ""])
        )
        return [below] + scale.choices
    }

    var body: some View {
        OnbQuestion(
            i18n.t("ios.onb12.q.current"),
            say: OnbSay(i18n.t("ios.onb12.say.current"), mood: .wink)
        ) {
            VStack(spacing: 18) {
                OnbGradeWheel(
                    choices: choices,
                    score: Binding(
                        get: { model.currentScore },
                        set: { newValue in
                            model.currentScore = newValue
                            // Un objectif plus bas que la nouvelle moyenne n'a plus cours.
                            if let target = model.targetScore, let newValue, target < newValue {
                                model.targetScore = nil
                            }
                        }
                    ),
                    label: OnbPhrase.plain(i18n.t("ios.onb12.q.current")),
                    caption: model.gradeScale.caption(locale: i18n.locale)
                )
            }
            .frame(maxWidth: .infinity)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: model.currentScore != nil) {
                model.answerCurrentAverage()
                model.advance()
            }
        }
    }
}

// MARK: - La moyenne visée

/// **« Et tu vises combien ? »**
///
/// On peut viser sa note d'aujourd'hui (« tenir ») ou n'importe laquelle au-dessus ; les
/// notes plus basses ne sont pas là. Sous la molette, **la carte change en direct** : l'écart
/// dans le barème de l'élève, et ce que Mika en pense.
struct TargetAverageStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var choices: [GradeTick] {
        model.targetChoices
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb10.q.target"), say: say) {
            VStack(spacing: 18) {
                OnbGradeWheel(
                    choices: choices,
                    score: Binding(
                        get: { model.targetScore },
                        set: { model.targetScore = $0 }
                    ),
                    // Le milieu de ce qui reste à viser : ni « tenir », ni le haut du barème.
                    fallbackIndex: (choices.count - 1) / 2,
                    label: OnbPhrase.plain(i18n.t("ios.onb10.q.target")),
                    caption: model.gradeScale.caption(locale: i18n.locale)
                )

            }
            .frame(maxWidth: .infinity)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: model.targetScore != nil) {
                model.advance()
            }
        }
    }

    /// **Mika réagit à l'écart, en direct** : l'écart dans le barème de l'élève, et ce qu'il
    /// vaut (« +4 points : ambitieux, et faisable »). Il change à chaque cran de la molette.
    private var say: OnbSay {
        guard let gap = model.gradeGap(locale: i18n.locale) else {
            return OnbSay(i18n.t("ios.onb12.say.target"), mood: .happy)
        }
        return OnbSay(gap.title(locale: i18n.locale), mood: .happy)
    }
}

// MARK: - La molette d'une note

/// **La note choisie en très grand, sa voisine du dessus et celle du dessous.** On fait
/// glisser le doigt de haut en bas, la note change cran par cran avec un petit coup ; un appui
/// sur une voisine la choisit.
///
/// Une note « sur quelque chose » (« 16/20 ») s'écrit en deux tailles : le nombre, puis son
/// barème en petit. Les autres (« 3.7 », « B+ », « 12 ») s'écrivent d'un bloc.
struct OnbGradeWheel: View {
    let choices: [GradeTick]
    @Binding var score: Int?
    /// Le cran de départ, quand rien n'a encore été choisi. Le milieu, sauf avis contraire.
    var fallbackIndex: Int?
    /// Ce que le lecteur d'écran annonce.
    let label: String
    /// Un mot sous la molette, quand le chiffre seul ne suffit pas (l'unité, ou que la
    /// meilleure note est la plus petite).
    var caption: String?

    /// Le cran sous le doigt quand le glissement a commencé.
    @State private var dragStart: Int?

    /// Ce qu'il faut glisser pour changer d'un cran.
    private static let stepHeight: CGFloat = 34

    private var start: Int {
        min(max(0, fallbackIndex ?? (choices.count - 1) / 2), max(0, choices.count - 1))
    }

    private var index: Int {
        guard let score, let found = choices.firstIndex(where: { $0.score == score }) else { return start }
        return found
    }

    var body: some View {
        VStack(spacing: 10) {
            neighbour(index - 1)
            selected
            neighbour(index + 1)

            if let caption {
                Text(caption)
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .highPriorityGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let origin = dragStart ?? index
                    dragStart = origin
                    // Glisser vers le haut fait monter la liste : la note suivante arrive.
                    move(to: origin - Int((value.translation.height / Self.stepHeight).rounded()))
                }
                .onEnded { _ in dragStart = nil }
        )
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue(choices.indices.contains(index) ? choices[index].label : "")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(to: index + 1)
            case .decrement: move(to: index - 1)
            @unknown default: break
            }
        }
        .onAppear {
            // La réponse existe dès l'affichage : une note montrée sans être enregistrée
            // laisserait le bouton éteint sans dire pourquoi.
            if score == nil, choices.indices.contains(start) { score = choices[start].score }
        }
    }

    /// La note choisie.
    private var selected: some View {
        let parts = Self.parts(of: choices.indices.contains(index) ? choices[index].label : "")
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(parts.value)
                .font(V3Font.display(72))
                .foregroundStyle(V3Color.ink)
            if let scale = parts.scale {
                Text(scale)
                    .font(V3Font.display(30))
                    .foregroundStyle(V3Color.accent)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.35)
        .contentTransition(.numericText())
        .animation(MicaboMotion.quick, value: index)
        .padding(.horizontal, 30)
        .padding(.vertical, 4)
        .frame(minWidth: 180)
        .v3Card(selected: true)
    }

    /// Une voisine : la note d'avant ou celle d'après. Sa place reste tenue au bout du barème.
    private func neighbour(_ position: Int) -> some View {
        let exists = choices.indices.contains(position)
        return Button {
            move(to: position)
        } label: {
            Text(exists ? Self.parts(of: choices[position].label).value : " ")
                .font(V3Font.display(30))
                .foregroundStyle(V3Color.ink3)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .none))
        .disabled(!exists)
        .accessibilityHidden(true)
    }

    private func move(to target: Int) {
        let clamped = min(max(0, target), max(0, choices.count - 1))
        guard clamped != index, choices.indices.contains(clamped) else { return }
        score = choices[clamped].score
        Haptics.selection()
    }

    /// « 16/20 » en « 16 » et « /20 » ; une note sans barre reste entière.
    static func parts(of label: String) -> (value: String, scale: String?) {
        guard let slash = label.firstIndex(of: "/"),
              label[..<slash].allSatisfy({ $0.isNumber || $0 == "," || $0 == "." }),
              !label[..<slash].isEmpty
        else { return (label, nil) }
        return (String(label[..<slash]), String(label[slash...]))
    }
}

// MARK: - La projection, et l'engagement

/// **« On vise 16/20 pour le 15 juin »** : la projection, puis l'engagement.
///
/// La courbe part d'aujourd'hui, de sa moyenne, et monte jusqu'au jour de l'examen, à la note
/// qu'il vise. C'est un objectif dessiné, pas une prédiction : elle met côte à côte ce qu'il a
/// dit avoir et ce qu'il a dit viser, à la date qu'il a donnée. Sans examen, l'horizon est de
/// trois mois ; moyenne passée, la courbe se dessine sans chiffres.
struct StartingPointStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Sans examen daté : l'horizon de la projection, en jours.
    static let openHorizonDays = 91

    private var target: String? {
        model.targetLabel(locale: i18n.locale)
    }

    private var horizon: String {
        OnbWords.duration(days: Self.openHorizonDays, locale: i18n.locale)
    }

    private var title: String {
        Self.title(for: model, locale: i18n.locale)
    }

    /// Le titre, d'après ce que l'élève a répondu : sa note visée et le jour de son examen ;
    /// sans examen, trois mois ; sans note, son examen ; sans rien, une phrase.
    static func title(for model: OnboardingModel, locale: UiLocale) -> String {
        let exam = model.datedExam
        if let target = model.targetLabel(locale: locale) {
            if let exam {
                return L10n.t("ios.onb10.start.title", locale: locale, vars: [
                    "target": target,
                    "date": OnbWords.day(exam.date, locale: locale),
                ])
            }
            return L10n.t("ios.onb10.start.titleOpen", locale: locale, vars: [
                "target": target,
                "time": OnbWords.duration(days: openHorizonDays, locale: locale),
            ])
        }
        if let exam {
            return L10n.t("ios.onb10.start.titleExam", locale: locale, vars: ["exam": exam.choice.title(locale: locale)])
        }
        return L10n.t("ios.onb10.start.titleBare", locale: locale)
    }

    var body: some View {
        OnbScreen {
            // La note visée est en vert : c'est l'objectif.
            OnbTitle(title, size: OnbLayout.display, keyword: V3Color.green)
                .padding(.top, OnbLayout.titleTop)

            OnbMikaRow(say: OnbSay(i18n.t("ios.onb10.start.line"), mood: .proud))
                .padding(.top, OnbLayout.mikaGap)

            projection
                .padding(.top, OnbLayout.answersGap)
        } footer: {
            V3Button(i18n.t("ios.onb12.start.cta")) {
                model.advance()
            }
        }
    }

    /// La carte : son intitulé, la courbe, puis d'où l'on part et quand on arrive.
    private var projection: some View {
        VStack(spacing: 8) {
            OnbProjectionChart(target: target)
                .frame(height: 170)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    if let current = model.currentLabel(locale: i18n.locale) {
                        Text(current)
                            .font(V3Font.bodyStrong)
                            .foregroundStyle(V3Color.ink)
                    }
                    Text(i18n.t("ios.onb5.trial.today"))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink3)
                }
                Spacer(minLength: 8)
                Text(model.datedExam.map { OnbWords.date($0.date, locale: i18n.locale) }
                    ?? i18n.t("ios.onb10.start.in", ["time": horizon]))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink3)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .v3Card()
        .accessibilityElement(children: .combine)
    }
}

/// **La courbe de la projection** : elle part doucement, puis monte (une progression, pas une
/// droite), d'aujourd'hui à la date. Au bout, la note visée dans une pastille. Elle se
/// retourne en arabe.
struct OnbProjectionChart: View {
    /// La note visée, écrite au bout de la courbe ; sans elle, la courbe est sans chiffres.
    let target: String?

    @Environment(\.onboardingStill) private var frozen
    @Environment(\.onbSettled) private var settled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// **La courbe se trace à l'arrivée** (lot 12) : de 0 à 1, une fois, d'aujourd'hui vers
    /// l'objectif. Dans un rendu ou avec « Réduire les animations », elle est là d'emblée.
    @State private var drawn: CGFloat = 0
    /// La courbe est arrivée : le point et la note visée se posent, d'un ressort.
    @State private var arrived = false

    private var still: Bool { frozen || settled }
    private var progress: CGFloat { still || reduceMotion ? 1 : drawn }
    private var landed: Bool { still || reduceMotion || arrived }

    var body: some View {
        chart
            .onAppear {
                guard !still, !reduceMotion, drawn == 0 else { return }
                withAnimation(MicaboMotion.fill(seconds: 1.1), completionCriteria: .logicallyComplete) {
                    drawn = 1
                } completion: {
                    Haptics.soft()
                    withAnimation(MicaboMotion.celebrate) { arrived = true }
                }
            }
    }

    private var chart: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let start = CGPoint(x: 12, y: size.height - 28)
            let end = CGPoint(x: size.width - 16, y: 34)
            ZStack(alignment: .topLeading) {
                // Deux repères en pointillés : la carte a une échelle, même sans l'écrire.
                Path { path in
                    for fraction in [0.26, 0.6] {
                        path.move(to: CGPoint(x: 8, y: size.height * fraction))
                        path.addLine(to: CGPoint(x: size.width - 8, y: size.height * fraction))
                    }
                }
                .stroke(V3Color.line, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                OnbProjectionCurve(start: start, end: end, floor: size.height - 6)
                    .fill(LinearGradient(
                        colors: [V3Color.green.opacity(0.25), V3Color.green.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .opacity(Double(progress))

                OnbProjectionCurve(start: start, end: end, floor: nil)
                    .trim(from: 0, to: progress)
                    .stroke(V3Color.green, style: StrokeStyle(lineWidth: 5, lineCap: .round))

                Circle()
                    .fill(V3Color.surface)
                    .overlay(Circle().strokeBorder(V3Color.ink, lineWidth: 4))
                    .frame(width: 18, height: 18)
                    .position(start)

                Circle()
                    .fill(V3Color.green)
                    .overlay(Circle().strokeBorder(V3Color.surface, lineWidth: 3))
                    .frame(width: 18, height: 18)
                    .scaleEffect(landed ? 1 : 0.2)
                    .opacity(landed ? 1 : 0)
                    .position(end)
            }
            .flipsForRightToLeftLayoutDirection(true)
        }
        .overlay(alignment: .topTrailing) {
            // La note visée, dans une pastille verte, au bout de la courbe : elle se pose quand
            // la courbe arrive.
            if let target, landed {
                Text(target)
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.bg)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(V3Color.green, in: Capsule())
            }
        }
        .accessibilityHidden(true)
    }
}

/// La courbe elle-même ; avec un plancher, l'aire sous elle.
private struct OnbProjectionCurve: Shape {
    let start: CGPoint
    let end: CGPoint
    let floor: CGFloat?

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: start)
            let span = end.x - start.x
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x + span * 0.34, y: start.y - 2),
                control2: CGPoint(x: start.x + span * 0.55, y: end.y + 10)
            )
            if let floor {
                path.addLine(to: CGPoint(x: end.x, y: floor))
                path.addLine(to: CGPoint(x: start.x, y: floor))
                path.closeSubpath()
            }
        }
    }
}
