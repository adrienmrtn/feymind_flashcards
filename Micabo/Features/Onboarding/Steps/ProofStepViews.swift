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
    static let students = 100_000
    /// Les élèves qui ont fait exactement le chemin qu'on vient de se fixer, et en combien
    /// de mois. Le compteur monte jusqu'au premier ; la courbe s'arrête au second.
    static let pathAchievers = 697
    static let pathMonths = 3
    /// Ce qu'il reste d'un cours une semaine après, en relisant et en se testant.
    /// Karpicke & Roediger, Science, 2008.
    static let retainedByRereading = 36
    static let retainedByTesting = 80
    /// Le multiplicateur de rétention et celui des rappels.
    static let retentionMultiplier = 2
    static let reminderMultiplier = 2

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

// MARK: - « Passer de 11 à 14, c'est réaliste. »

/// **La première preuve, en deux temps.** D'abord la phrase seule, qui se lit mot à mot
/// et se termine par un surligneur sur « réaliste ». Puis, sur un appui, le chiffre : les
/// élèves qui ont fait exactement ce chemin, qui monte comme un tableau d'aéroport et
/// freine en arrivant. Le bouton n'existe pas avant que le chiffre soit posé : on ne passe
/// pas devant une preuve qui n'a pas fini de se donner.
struct ProofRealisticStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

    private enum Phase {
        /// La phrase se lit.
        case reading
        /// La phrase est lue et surlignée : un appui fait venir le chiffre.
        case armed
        /// Le chiffre monte.
        case counting
        /// Le chiffre est posé : le bouton est là.
        case done
    }

    @State private var phase: Phase = .reading
    @State private var shown = 0

    private static let target = OnboardingProofFigures.pathAchievers
    /// Le temps que met le compteur : long, parce que c'est lui qu'on regarde.
    private static let countDuration = 3.2

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(showsBack: false)

            VStack(spacing: 0) {
                Spacer(minLength: MicaboSpacing.lg)

                OnboardingReadingText(
                    template: i18n.t("ios.proof.realistic.title", ["from": from, "to": to]),
                    size: 32,
                    wordDelay: 0.2,
                    onHighlighted: { if phase == .reading { phase = .armed } }
                )
                .padding(.horizontal, MicaboSpacing.screen)

                if phase == .counting || phase == .done {
                    counter
                        .padding(.top, MicaboSpacing.xl)
                        .transition(.opacity)
                }

                Spacer(minLength: MicaboSpacing.lg)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeOut(duration: 0.4), value: phase)

            ZStack {
                Text(i18n.t("ios.proof.tap"))
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(OnboardingPalette.grayLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .opacity(phase == .armed ? 1 : 0)

                MicaboBottomBar(background: OnboardingPalette.white) {
                    OnboardingContinueButton {
                        model.advance()
                    }
                }
                .opacity(phase == .done ? 1 : 0)
                .allowsHitTesting(phase == .done)
            }
            .animation(.easeOut(duration: 0.4), value: phase)
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .contentShape(Rectangle())
        .onTapGesture {
            guard phase == .armed else { return }
            Haptics.light()
            phase = .counting
            Task { await count() }
        }
    }

    /// « Plus de », le chiffre qui roule, et ce qu'il compte.
    private var counter: some View {
        VStack(spacing: 10) {
            Text(i18n.t("ios.proof.path.more"))
                .font(MicaboFont.ui(15, weight: .semibold))
                .foregroundStyle(OnboardingPalette.gray)

            OnboardingDigitRoller(
                value: shown,
                digits: String(Self.target).count,
                size: 88,
                tint: phase == .done ? OnboardingPalette.accent : OnboardingPalette.ink
            )
            .animation(.easeOut(duration: 0.3), value: phase)

            Text(i18n.t("ios.proof.path.sub", ["months": "\(OnboardingProofFigures.pathMonths)"]))
                .font(MicaboFont.ui(17, weight: .medium))
                .foregroundStyle(OnboardingPalette.ink)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, MicaboSpacing.xl)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// **Le compteur monte vite, puis freine.** Une courbe en cube : à mi-temps il est aux
    /// sept huitièmes, et il passe le dernier tiers du temps sur les vingt derniers
    /// chiffres — ce sont ceux qu'on lit. Un coup à chaque centaine, un coup net au bout.
    @MainActor
    private func count() async {
        if reduceMotion {
            shown = Self.target
            phase = .done
            return
        }
        let frames = Int(Self.countDuration * 30)
        var lastHundred = 0
        for frame in 1...frames {
            guard !Task.isCancelled else { return }
            let t = Double(frame) / Double(frames)
            let eased = 1 - pow(1 - t, 3)
            shown = Int((Double(Self.target) * eased).rounded())
            let hundred = shown / 100
            if hundred > lastHundred {
                lastHundred = hundred
                Haptics.tick()
            }
            try? await Task.sleep(for: .milliseconds(33))
        }
        shown = Self.target
        Haptics.success()
        phase = .done
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
            headline: i18n.t("ios.proof.retention.title"),
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

// MARK: - « C'est pour ça qu'on a créé Micabo. »

/// Une phrase, après « relire, c'est oublier », et rien d'autre. Elle se lit mot à mot,
/// « Micabo » se surligne à la fin, et c'est seulement là que le bouton arrive : la
/// réponse au constat d'avant, donnée le temps qu'il faut pour la lire.
struct ProofWhyStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isReady = false

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(showsBack: false)

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                OnboardingReadingText(
                    template: i18n.t("ios.proof.why.title"),
                    size: 38,
                    wordDelay: 0.24,
                    startDelay: 0.6,
                    onHighlighted: { isReady = true }
                )
                .padding(.horizontal, MicaboSpacing.screen)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            MicaboBottomBar(background: OnboardingPalette.white) {
                OnboardingContinueButton {
                    model.advance()
                }
            }
            .opacity(isReady ? 1 : 0)
            .allowsHitTesting(isReady)
            .animation(.easeOut(duration: 0.4), value: isReady)
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

// MARK: - Les avis, en carrousel

/// **Trois avis qui défilent d'eux-mêmes**, juste après le merci. On peut les faire glisser
/// au doigt ; sinon, le suivant vient toutes les trois secondes et demie. Les points
/// dessous disent où l'on en est.
struct ReviewsStepView: View {
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

    @State private var page = 0

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.reviews.title"),
            scrolls: false,
            expandsContent: true,
            centered: true
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 10) {
                    OnboardingStars(size: 15)
                    Text(i18n.t("ios.proof.students.rating", [
                        "rating": OnboardingProofFigures.text(OnboardingProofFigures.rating, locale: i18n.locale),
                        "n": OnboardingProofFigures.text(OnboardingProofFigures.reviews, locale: i18n.locale),
                    ]))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.gray)
                }

                OnboardingReviewCarousel(page: $page, count: reviews.count) { index in
                    OnboardingReviewCard(quote: reviews[index].quote, name: reviews[index].name, level: reviews[index].level)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            OnboardingContinueButton {
                model.advance()
            }
        }
    }
}

/// Le carrousel : une page par avis, qui avance seule et se laisse glisser.
struct OnboardingReviewCarousel<Page: View>: View {
    @Binding var page: Int
    let count: Int
    @ViewBuilder var content: (Int) -> Page

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 14) {
            TabView(selection: $page) {
                ForEach(0..<count, id: \.self) { index in
                    content(index)
                        .padding(.horizontal, 2)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 210)
            .animation(.easeInOut(duration: 0.45), value: page)

            HStack(spacing: 6) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? OnboardingPalette.ink : OnboardingPalette.cardStrong)
                        .frame(width: index == page ? 18 : 6, height: 6)
                        .animation(OnboardingMotion.select, value: page)
                }
            }
        }
        .task {
            guard !reduceMotion, count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(3_500))
                guard !Task.isCancelled else { return }
                page = (page + 1) % count
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
                .font(MicaboFont.ui(16, weight: .regular))
                .foregroundStyle(OnboardingPalette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - « Avec dix minutes par jour, voici ta progression. »

/// La progression prévue, de la moyenne d'aujourd'hui à celle qu'on vise, avec le temps
/// qu'on vient de promettre — et de signer. Le tracé est le même quelles que soient les
/// notes : c'est une forme, pas une prédiction.
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
            headline: i18n.t("ios.proof.curve.title", ["n": "\(model.minutesPerDay)"]),
            caption: i18n.t("ios.proof.curve.sub", ["months": "\(OnboardingProofFigures.pathMonths)", "from": from, "to": to]),
            tapToContinue: true
        ) {
            OnboardingCurveChart(
                from: from,
                to: to,
                startLabel: i18n.t("ios.proof.curve.today"),
                endLabel: i18n.t("ios.proof.curve.later", ["months": "\(OnboardingProofFigures.pathMonths)"])
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
    /// **Pas de bouton : on touche l'écran.** Réservé aux deux pages dont la figure se
    /// dessine sous les yeux. Le bouton noir en bas appelait l'appui avant la fin du
    /// tracé ; ici rien n'appelle rien pendant deux secondes, puis une ligne grise dit
    /// qu'on peut toucher, et tout l'écran répond.
    var tapToContinue: Bool = false
    @ViewBuilder var figure: () -> Figure
    var onContinue: () -> Void

    @Environment(OnboardingModel.self) private var model: OnboardingModel?
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Vrai deux secondes après l'arrivée : avant, un appui ne fait rien.
    @State private var isArmed = false
    @State private var didContinue = false

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

            if tapToContinue {
                Text(i18n.t("ios.proof.tap"))
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(OnboardingPalette.grayLight)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .opacity(isArmed ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: isArmed)
            } else {
                MicaboBottomBar(background: OnboardingPalette.white) {
                    OnboardingContinueButton(action: onContinue)
                        .onboardingAppear(index: 5)
                }
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .contentShape(Rectangle())
        .onTapGesture {
            guard tapToContinue, isArmed, !didContinue else { return }
            didContinue = true
            Haptics.light()
            onContinue()
        }
        .task {
            guard tapToContinue else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            isArmed = true
        }
    }

    private var chrome: some View {
        OnboardingChrome(showsBack: false)
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
    @State private var arrived = false

    private enum Layout {
        static let startX: CGFloat = 0.08
        static let startY: CGFloat = 0.82
        static let goalX: CGFloat = 0.88
        static let goalY: CGFloat = 0.26
    }

    /// Le tracé met deux secondes et demie, sur une courbe qui part doucement, accélère,
    /// et se pose : c'est la forme du progrès que la page raconte, et c'est assez long pour
    /// qu'on la regarde. Le point d'arrivée s'allume à la fin, avec un coup net.
    private static let drawDuration = 2.5

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
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.timingCurve(0.45, 0, 0.15, 1, duration: Self.drawDuration)) { drawn = 1 }
            // Quelques coups légers pendant la montée, puis un coup net à l'arrivée.
            for _ in 0..<4 {
                try? await Task.sleep(for: .milliseconds(Int(Self.drawDuration * 1000 / 5)))
                guard !Task.isCancelled else { return }
                Haptics.tick()
            }
            try? await Task.sleep(for: .milliseconds(Int(Self.drawDuration * 1000 / 5)))
            guard !Task.isCancelled else { return }
            withAnimation(OnboardingMotion.select) { arrived = true }
            Haptics.success()
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

                // Le point qui voyage : il suit la courbe pendant qu'elle se trace. La
                // position passe par un modificateur animable, image par image : posée
                // directement, elle allait en ligne droite du départ à l'arrivée.
                Circle()
                    .fill(OnboardingPalette.accent)
                    .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 3))
                    .frame(width: 16, height: 16)
                    .modifier(OnboardingCurveFollower(fraction: drawn, path: curve(from: start, to: goal)))
                    .opacity(arrived ? 0 : 1)

                // L'échelle est posée sur le rond **avant** sa position : posée après, elle
                // grossissait tout le cadre autour de son centre, et poussait le point
                // hors de la carte.
                Circle()
                    .fill(OnboardingPalette.accent)
                    .overlay(Circle().strokeBorder(OnboardingPalette.white, lineWidth: 3))
                    .frame(width: 16, height: 16)
                    .scaleEffect(arrived ? 1.25 : 0.6)
                    .opacity(arrived ? 1 : 0)
                    .position(goal)

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
                    .opacity(arrived ? 1 : 0)
            }
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

/// **Pose une vue sur un point d'une courbe, et suit la courbe quand la fraction s'anime.**
///
/// `position` s'anime en ligne droite entre deux points ; pour qu'un point voyage le long
/// d'une courbe, il faut recalculer sa position à chaque image, et c'est ce qu'un
/// modificateur animable fait : SwiftUI interpole `animatableData`, et le corps en tire
/// le point courant du tracé tronqué.
private struct OnboardingCurveFollower: ViewModifier, Animatable {
    var fraction: CGFloat
    let path: Path

    var animatableData: CGFloat {
        get { fraction }
        set { fraction = newValue }
    }

    func body(content: Content) -> some View {
        let clamped = Swift.min(Swift.max(0.001, fraction), 1)
        let point = path.trimmedPath(from: 0, to: clamped).currentPoint ?? path.currentPoint ?? .zero
        return content.position(point)
    }
}
