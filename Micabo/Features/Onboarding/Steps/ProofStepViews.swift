import SwiftUI

// MARK: - Les chiffres

/// **Les chiffres de preuve du parcours, tous au même endroit.**
///
/// Ils sont **provisoires** : ce sont des ordres de grandeur posés pour dessiner les écrans,
/// et ils doivent être remplacés par les vrais avant d'être montrés. Les avoir ici plutôt
/// que dans chaque écran, c'est ce qui permet de les remplacer d'un coup — et de savoir, en
/// relisant ce fichier, tout ce que le parcours affirme.
enum OnboardingProofFigures {
    /// La note App Store et le nombre d'avis.
    static let rating = 4.8
    static let reviews = 12_000
    /// Les élèves qui utilisent Micabo.
    static let students = 500_000
    /// Ce qu'il reste d'un cours une semaine après, en relisant et en se testant.
    /// Karpicke & Roediger, Science, 2008.
    static let retainedByRereading = 36
    static let retainedByTesting = 80
    /// Le multiplicateur de rétention et celui des rappels.
    static let retentionMultiplier = 2
    static let reminderMultiplier = 2
    /// La part des élèves qui atteignent leur objectif.
    static let reachTarget = 82
    /// Combien de fois une carte est revue d'ici l'échéance, en moyenne.
    static let reviewsPerCard = 4

    /// Un entier écrit dans la langue de l'élève : « 12 000 », « 12,000 », « 12.000 ».
    static func text(_ value: Int, locale: UiLocale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale.foundation
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func text(_ value: Double, locale: UiLocale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale.foundation
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - Le texte à chiffre coloré

/// **Une phrase noire, avec un passage en violet.** Le passage est marqué entre deux
/// astérisques doubles dans la chaîne traduite (`**14**`), pour que chaque langue décide
/// de sa place dans la phrase.
struct OnboardingAccentText: View {
    let template: String
    var size: CGFloat = 34
    var alignment: TextAlignment = .center
    var color: Color = OnboardingPalette.ink
    var accent: Color = OnboardingPalette.accent

    var body: some View {
        composed
            .font(OnboardingPalette.title(size))
            .tracking(-0.9)
            .lineSpacing(-2)
            .multilineTextAlignment(alignment)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var composed: Text {
        var result = Text("")
        var isAccent = false
        for (index, part) in template.components(separatedBy: "**").enumerated() {
            if index > 0 { isAccent.toggle() }
            result = result + Text(part).foregroundStyle(isAccent ? accent : color)
        }
        return result
    }
}

// MARK: - « Passer de 11 à 14 est réaliste. »

/// La première preuve, juste après la moyenne visée : l'écart qu'on vient de se fixer,
/// et une phrase qui dit qu'il se prend. C'est l'écran « losing 14.8 kg is a realistic
/// target » de Cal AI, avec le chiffre de l'élève dedans.
struct ProofRealisticStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var scale: DesiredGradeScale { DesiredGradeScale.for(model.country) }

    private var from: String {
        guard let score = model.currentScore, score >= TargetScore.min else {
            return "< \(scale.min)"
        }
        return scale.label(for: score)
    }

    private var to: String {
        scale.label(for: model.targetScore ?? TargetScore.max)
    }

    private var gap: Int {
        max(1, (model.targetScore ?? TargetScore.max) - (model.currentScore ?? TargetScore.min))
    }

    var body: some View {
        OnboardingProofPage(
            headline: i18n.t("ios.proof.realistic.title", ["from": from, "to": to]),
            caption: i18n.t("ios.proof.realistic.sub", ["pct": "\(OnboardingProofFigures.reachTarget)", "gap": "\(gap)"])
        ) {
            OnboardingGapBadge(from: from, to: to)
        } onContinue: {
            model.advance()
        }
    }
}

/// « 11 → 14 », en grand, sur un lavis violet.
private struct OnboardingGapBadge: View {
    let from: String
    let to: String

    var body: some View {
        HStack(spacing: 14) {
            Text(from)
                .foregroundStyle(OnboardingPalette.gray)
            Image(systemName: "arrow.right")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(OnboardingPalette.grayLight)
            Text(to)
                .foregroundStyle(OnboardingPalette.accent)
        }
        .font(MicaboFont.ui(44, weight: .bold))
        .tracking(-1.5)
        .monospacedDigit()
        .padding(.vertical, 22)
        .padding(.horizontal, 36)
        .background(OnboardingPalette.accentWash, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - « Relire ne suffit pas. »

/// Deux barres : ce qu'il reste d'un cours une semaine après, en le relisant et en se
/// testant dessus. Le rouge et le vert n'existent que là.
struct ProofRetentionStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingProofPage(
            headline: i18n.t("ios.proof.retention.title", ["pct": "\(OnboardingProofFigures.retainedByTesting)"]),
            caption: i18n.t("ios.journey.source")
        ) {
            OnboardingBarsChart(
                title: i18n.t("ios.proof.retention.caption"),
                bars: [
                    .init(label: i18n.t("ios.proof.retention.reread"), value: OnboardingProofFigures.retainedByRereading, tint: OnboardingPalette.chartBad),
                    .init(label: i18n.t("ios.proof.retention.testing"), value: OnboardingProofFigures.retainedByTesting, tint: OnboardingPalette.chartGood),
                ]
            )
        } onContinue: {
            model.advance()
        }
    }
}

// MARK: - « Avec Micabo, tu retiens 2× plus. »

/// La comparaison avant / après : deux colonnes, la seconde noire et deux fois plus
/// haute. C'est l'écran « lose twice as much with Cal AI » — le même dessin, le même
/// chiffre.
struct ProofTwiceStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingProofPage(
            headline: i18n.t("ios.proof.twice.title", ["n": "\(OnboardingProofFigures.retentionMultiplier)"])
        ) {
            OnboardingBarsChart(
                bars: [
                    .init(label: i18n.t("ios.proof.twice.without"), value: 1, tint: OnboardingPalette.cardStrong),
                    .init(label: i18n.t("ios.proof.twice.with"), value: OnboardingProofFigures.retentionMultiplier, tint: OnboardingPalette.accent),
                ],
                maxValue: OnboardingProofFigures.retentionMultiplier,
                showsValues: false
            )
        } onContinue: {
            model.advance()
        }
    }
}

// MARK: - « Rejoins 500 000 élèves. »

/// La note, et trois avis empilés. Une pile qui ne bouge pas toute seule : on lit celui du
/// dessus, et on appuie pour voir le suivant.
struct ProofStudentsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private struct Review: Identifiable {
        let id: Int
        let quote: String
        let name: String
        let level: String
    }

    private var reviews: [Review] {
        (1...3).map { index in
            Review(
                id: index,
                quote: i18n.t("ios.review\(index).quote"),
                name: i18n.t("ios.review\(index).name"),
                level: i18n.t("ios.review\(index).level")
            )
        }
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.proof.students.title", ["n": OnboardingProofFigures.text(OnboardingProofFigures.students, locale: i18n.locale)]),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    OnboardingStars(size: 15)
                    Text(i18n.t("ios.proof.students.rating", [
                        "rating": OnboardingProofFigures.text(OnboardingProofFigures.rating, locale: i18n.locale),
                        "n": OnboardingProofFigures.text(OnboardingProofFigures.reviews, locale: i18n.locale),
                    ]))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.gray)
                }

                ForEach(Array(reviews.enumerated()), id: \.element.id) { index, review in
                    OnboardingReviewCard(quote: review.quote, name: review.name, level: review.level)
                        .onboardingAppear(index: 4 + index, stagger: 0.08)
                }
            }
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Un avis : l'initiale dans un rond, le prénom, le niveau, cinq étoiles, la phrase.
struct OnboardingReviewCard: View {
    let quote: String
    let name: String
    let level: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(String(name.prefix(1)).uppercased())
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(OnboardingPalette.white)
                    .frame(width: 38, height: 38)
                    .background(OnboardingPalette.ink, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                    Text(level)
                        .font(OnboardingPalette.subtitle)
                        .foregroundStyle(OnboardingPalette.gray)
                }

                Spacer(minLength: 0)

                OnboardingStars(size: 12, spacing: 2)
            }

            Text(quote)
                .font(MicaboFont.ui(15, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - « D'ici le jour J, 340 cartes, revues 4 fois. »

/// **Ce que le plan fait, en volume.** Le nombre de cartes qu'on aura vues d'ici
/// l'échéance, et combien de fois chacune. C'est le premier écran qui montre le plan
/// en chiffres, et ce sont ceux de l'élève : son rythme, son échéance.
struct ProofPlanStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var totalCards: Int {
        model.cardsPerDay * model.daysToExam
    }

    var body: some View {
        OnboardingProofPage(
            headline: i18n.t("ios.proof.plan.title", [
                "cards": OnboardingProofFigures.text(totalCards, locale: i18n.locale),
                "times": "\(OnboardingProofFigures.reviewsPerCard)",
            ]),
            caption: i18n.t("ios.proof.plan.sub", ["n": "\(model.cardsPerDay)", "days": "\(model.daysToExam)"])
        ) {
            OnboardingDaysGrid(days: model.daysToExam)
        } onContinue: {
            model.advance()
        }
    }
}

/// **Les jours jusqu'à l'échéance, un point par jour**, qui s'allument l'un après
/// l'autre. Au-delà de quatre-vingt-dix, un point vaut plusieurs jours : la grille dit
/// « c'est long » sans devenir un mur.
struct OnboardingDaysGrid: View {
    let days: Int

    @State private var lit = 0

    private static let columns = 10
    private static let maxDots = 90

    private var dots: Int { max(1, min(Self.maxDots, days)) }

    var body: some View {
        let rows = Int((Double(dots) / Double(Self.columns)).rounded(.up))
        VStack(spacing: 10) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        let index = row * Self.columns + column
                        Circle()
                            .fill(index < lit ? OnboardingPalette.accent : OnboardingPalette.card)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(1, contentMode: .fit)
                            .opacity(index < dots ? 1 : 0)
                    }
                }
            }
        }
        .padding(20)
        .background(OnboardingPalette.card.opacity(0.5), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement()
        .accessibilityLabel("\(days)")
        .task {
            try? await Task.sleep(for: .milliseconds(300))
            for index in 1...dots {
                guard !Task.isCancelled else { return }
                lit = index
                if index % 5 == 0 { Haptics.tick() }
                try? await Task.sleep(for: .milliseconds(max(8, 900 / dots)))
            }
        }
    }
}

// MARK: - « Ta courbe jusqu'au jour J. »

/// La progression prévue, de la moyenne d'aujourd'hui à celle qu'on vise, jusqu'à
/// l'échéance qu'on vient de donner. Le tracé est le même quelles que soient les notes :
/// c'est une forme, pas une prédiction.
struct ProofCurveStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var scale: DesiredGradeScale { DesiredGradeScale.for(model.country) }

    private var from: String {
        guard let score = model.currentScore, score >= TargetScore.min else {
            return "< \(scale.min)"
        }
        return scale.label(for: score)
    }

    private var to: String {
        scale.label(for: model.targetScore ?? TargetScore.max)
    }

    var body: some View {
        OnboardingProofPage(
            headline: i18n.t("ios.proof.curve.title"),
            caption: i18n.t("ios.proof.curve.sub", ["days": "\(model.daysToExam)", "from": from, "to": to])
        ) {
            OnboardingCurveChart(
                from: from,
                to: to,
                startLabel: i18n.t("ios.proof.curve.today"),
                endLabel: i18n.t("ios.proof.curve.exam", ["days": "\(model.daysToExam)"])
            )
        } onContinue: {
            model.advance()
        }
    }
}

// MARK: - La page de preuve

/// **Une phrase, une image, un bouton.** Toutes les preuves ont cette forme : le titre
/// centré avec son chiffre en violet, la figure au milieu de ce qui reste, la légende grise
/// dessous.
struct OnboardingProofPage<Figure: View>: View {
    let headline: String
    var caption: String?
    @ViewBuilder var figure: () -> Figure
    var onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model: OnboardingModel?

    var body: some View {
        VStack(spacing: 0) {
            chrome

            VStack(spacing: 0) {
                Spacer(minLength: MicaboSpacing.lg)

                OnboardingAccentText(template: headline)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onboardingAppear(index: 1)

                Spacer(minLength: MicaboSpacing.xl)

                figure()
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onboardingAppear(index: 3)

                if let caption {
                    Text(caption)
                        .font(MicaboFont.ui(14, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, MicaboSpacing.xl)
                        .padding(.top, MicaboSpacing.lg)
                        .onboardingAppear(index: 4)
                }

                Spacer(minLength: MicaboSpacing.lg)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MicaboBottomBar(background: OnboardingPalette.white) {
                OnboardingContinueButton(action: onContinue)
                    .onboardingAppear(index: 5)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }

    /// La même barre que les questions : le retour éteint, la jauge.
    @ViewBuilder
    private var chrome: some View {
        if let model {
            HStack(alignment: .center, spacing: 14) {
                Color.clear.frame(width: 40, height: 40)

                MicaboProgressBar(
                    progress: model.step.progress,
                    tint: OnboardingPalette.ink,
                    track: OnboardingPalette.cardStrong
                )
                .frame(height: 3)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
        }
    }
}

// MARK: - Les figures

/// Deux ou trois barres verticales, leur valeur écrite dedans, leur libellé dessous.
struct OnboardingBarsChart: View {
    struct Bar: Identifiable {
        var id: String { label }
        let label: String
        let value: Int
        let tint: Color
        var valueText: String?
        var valueInk: Color = OnboardingPalette.white
    }

    var title: String?
    let bars: [Bar]
    var maxValue: Int = 100
    /// La valeur écrite dans la barre. Sans elle, la hauteur dit tout.
    var showsValues: Bool = true

    @State private var isDrawn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(title)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.gray)
            }

            HStack(alignment: .bottom, spacing: 18) {
                ForEach(bars) { bar in
                    VStack(spacing: 10) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(bar.tint)
                                .frame(height: isDrawn ? height(for: bar) : 12)

                            if showsValues {
                                Text(bar.valueText ?? "\(bar.value) %")
                                    .font(MicaboFont.ui(22, weight: .bold))
                                    .foregroundStyle(bar.valueInk)
                                    .monospacedDigit()
                                    .padding(.bottom, 14)
                                    .opacity(isDrawn ? 1 : 0)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        Text(bar.label)
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(OnboardingPalette.ink)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(height: 220, alignment: .bottom)
        }
        .padding(20)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.25)) { isDrawn = true }
        }
        .accessibilityElement(children: .combine)
    }

    private func height(for bar: Bar) -> CGFloat {
        let fraction = CGFloat(bar.value) / CGFloat(max(1, maxValue))
        return max(56, 180 * fraction)
    }
}

/// Un anneau qui se remplit en violet, le chiffre au milieu.
struct OnboardingRing: View {
    let fraction: Double
    let label: String

    @State private var isDrawn = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(OnboardingPalette.card, lineWidth: 18)

            Circle()
                .trim(from: 0, to: isDrawn ? fraction : 0.005)
                .stroke(OnboardingPalette.accent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text(label)
                .font(MicaboFont.ui(52, weight: .bold))
                .foregroundStyle(OnboardingPalette.ink)
                .tracking(-2)
                .monospacedDigit()
        }
        .frame(width: 220, height: 220)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9).delay(0.25)) { isDrawn = true }
        }
        .accessibilityElement()
        .accessibilityLabel(label)
    }
}

/// La courbe de progression : plate au départ, redressée à l'arrivée, sur fond gris.
struct OnboardingCurveChart: View {
    let from: String
    let to: String
    let startLabel: String
    let endLabel: String

    @State private var drawn: CGFloat = 0

    private enum Layout {
        static let startX: CGFloat = 0.08
        static let startY: CGFloat = 0.82
        static let goalX: CGFloat = 0.9
        static let goalY: CGFloat = 0.2
    }

    var body: some View {
        VStack(spacing: 14) {
            chart
                .frame(height: 200)

            HStack {
                Text(startLabel)
                Spacer(minLength: 0)
                Text(endLabel)
            }
            .font(MicaboFont.ui(13, weight: .semibold))
            .foregroundStyle(OnboardingPalette.gray)
        }
        .padding(20)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) { drawn = 1 }
        }
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let start = CGPoint(x: w * Layout.startX, y: h * Layout.startY)
            let goal = CGPoint(x: w * Layout.goalX, y: h * Layout.goalY)

            ZStack(alignment: .topLeading) {
                Path { path in
                    for fraction in [0.2, 0.5, 0.8] {
                        path.move(to: CGPoint(x: 0, y: h * fraction))
                        path.addLine(to: CGPoint(x: w, y: h * fraction))
                    }
                }
                .stroke(OnboardingPalette.cardStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                // Le lavis sous la courbe.
                area(from: start, to: goal, floor: h)
                    .fill(OnboardingPalette.accent.opacity(0.1))
                    .opacity(Double(drawn))

                curve(from: start, to: goal)
                    .trim(from: 0, to: drawn)
                    .stroke(OnboardingPalette.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                dot(at: start, fill: OnboardingPalette.ink)
                dot(at: goal, fill: OnboardingPalette.accent)
                    .opacity(drawn >= 1 ? 1 : 0)

                Text(from)
                    .font(MicaboFont.ui(17, weight: .bold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .monospacedDigit()
                    .position(x: start.x, y: start.y - 24)

                Text(to)
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(OnboardingPalette.white)
                    .monospacedDigit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(OnboardingPalette.accent, in: Capsule())
                    .position(x: goal.x, y: goal.y - 26)
                    .opacity(drawn >= 1 ? 1 : 0)
            }
            .animation(.easeOut(duration: 0.3), value: drawn >= 1)
        }
    }

    private func curve(from start: CGPoint, to goal: CGPoint) -> Path {
        Path { path in
            path.move(to: start)
            path.addCurve(
                to: goal,
                control1: CGPoint(x: start.x + (goal.x - start.x) * 0.4, y: start.y),
                control2: CGPoint(x: start.x + (goal.x - start.x) * 0.6, y: goal.y)
            )
        }
    }

    private func area(from start: CGPoint, to goal: CGPoint, floor: CGFloat) -> Path {
        var path = curve(from: start, to: goal)
        path.addLine(to: CGPoint(x: goal.x, y: floor))
        path.addLine(to: CGPoint(x: start.x, y: floor))
        path.closeSubpath()
        return path
    }

    private func dot(at point: CGPoint, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 3))
            .frame(width: 16, height: 16)
            .position(point)
    }
}
