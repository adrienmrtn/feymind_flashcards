import SwiftUI

// MARK: - Mika se présente, en six écrans

/// Les six écrans où Mika dit ce qu'il fait, dans l'ordre : sa mission, les documents qu'il
/// prend, les parcours qu'il en tire, des leçons qui donnent envie, la solution, la fin de la
/// pression.
enum MikaPage: String, CaseIterable, Identifiable {
    /// Avant le quiz des moyennes : l'histoire, la recherche, le point de départ.
    case founders
    case companion
    case start
    case mission
    case sources
    case paths
    case design
    case solution
    case tutor
    case relief

    var id: String { rawValue }

    /// La phrase de l'écran ; les mots entre `**` se peignent du dégradé de l'app.
    var titleKey: String { "ios.onb.mika.\(rawValue)" }

    /// **La part de la page que prend la scène.** L'écran de la recherche porte en plus la
    /// carte de Harvard sous sa phrase : sa scène se fait plus petite pour lui laisser la place.
    var sceneShare: CGFloat { self == .companion ? 0.4 : 0.6 }
}

/// **Une scène animée en haut, une phrase en dessous, le rond.** Dix écrans de la même
/// forme : l'illustration prend les trois cinquièmes de la page, la phrase se pose dessous,
/// centrée, dans la police des titres de l'app.
struct MikaStepView: View {
    let page: MikaPage

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    /// **Le rond n'arrive qu'une fois la scène jouée.** Présent dès l'arrivée, il se touchait
    /// par réflexe, et les écrans de Mika défilaient sans qu'on les ait vus.
    @State private var showsAction = false
    /// La hauteur de la phrase, et de la carte quand il y en a une : la scène prend ce qui
    /// reste, sans jamais passer dessous.
    @State private var textHeight: CGFloat = 0
    @Environment(\.onboardingStill) private var still

    /// Le temps que la scène joue son entrée avant que le rond ne se pose.
    static let actionDelay = 1.3

    var body: some View {
        let isShown = shown || still
        return VStack(spacing: 0) {
            GeometryReader { proxy in
                let room = proxy.size.height
                // La scène prend sa part de la page, mais jamais la place de la phrase : sous
                // un titre de quatre lignes, elle rapetisse ; plus bas que 240 points, c'est
                // la page qui défile.
                let sceneHeight = max(240, min(room * page.sceneShare, room - textHeight - 18))
                ScrollView {
                    VStack(spacing: 0) {
                        // Dix points d'air au-dessus : ce qui flotte en haut de la scène — Mika
                        // assis sur sa carte — n'est pas rogné par le bord de la page.
                        scene
                            .frame(width: proxy.size.width, height: sceneHeight)
                            .padding(.top, 10)
                            .accessibilityHidden(true)

                        VStack(spacing: 18) {
                            OnboardingAccentText(template: i18n.t(page.titleKey), size: 27, alignment: .center)
                                .padding(.horizontal, 26)

                            if page == .companion {
                                ResearchQuoteCard(compact: true)
                                    .padding(.horizontal, MicaboSpacing.screen)
                            }
                        }
                        .padding(.top, 6)
                        .padding(.bottom, MicaboSpacing.md)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
                        .opacity(isShown ? 1 : 0)
                        .offset(y: isShown ? 0 : 14)

                        Spacer(minLength: 0)
                    }
                    .frame(width: proxy.size.width)
                    .frame(minHeight: room, alignment: .top)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }

            OnboardingArrowBar {
                model.advance()
            }
            .opacity(showsAction || still ? 1 : 0)
            .allowsHitTesting(showsAction || still)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.6, bounce: 0.25).delay(0.2)) {
                shown = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.4 : Self.actionDelay)) {
                withAnimation(.easeOut(duration: 0.3)) { showsAction = true }
            }
        }
    }

    @ViewBuilder
    private var scene: some View {
        switch page {
        case .founders: MikaFoundersScene()
        case .companion: MikaCompanionScene()
        case .start: MikaStartScene()
        case .tutor: MikaTutorScene()
        case .mission: MikaMissionScene()
        case .sources: MikaSourcesScene()
        case .paths: MikaPathsScene()
        case .design: MikaDesignScene()
        case .solution: MikaSolutionScene()
        case .relief: MikaReliefScene()
        }
    }
}

// MARK: - Les briques des scènes

private struct OnboardingStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Les scènes à leur état final, sans attendre leurs animations** : pour les rendus,
    /// qui dessinent une seule image avant que rien n'ait bougé.
    var onboardingStill: Bool {
        get { self[OnboardingStillKey.self] }
        set { self[OnboardingStillKey.self] = newValue }
    }
}

/// Une tuile blanche de l'app, une icône 3D dedans : la brique de toutes les scènes.
private struct MikaTile: View {
    let icon: MicaboIcon
    var size: CGFloat = 66
    var label: String?

    var body: some View {
        VStack(spacing: 6) {
            MicaboIconView(icon: icon, size: size * 0.72)
                .frame(width: size, height: size)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                .micaboElevation(.card)
            if let label {
                Text(label)
                    .font(MicaboFont.ui(14, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

/// Un léger flottement, chacun à son rythme : ce qui flotte ensemble ne bat pas ensemble.
private struct Bobbing: ViewModifier {
    var amplitude: CGFloat = 6
    var period: Double = 2.2
    var delay: Double = 0

    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amplitude : amplitude)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true).delay(delay)) { up = true }
            }
    }
}

/// Une apparition en ressort, décalée par son rang.
private struct PopIn: ViewModifier {
    let shown: Bool
    var delay: Double = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .animation(.spring(duration: 0.55, bounce: 0.45).delay(delay), value: shown)
    }
}

private extension View {
    func bobbing(_ amplitude: CGFloat = 6, period: Double = 2.2, delay: Double = 0) -> some View {
        modifier(Bobbing(amplitude: amplitude, period: period, delay: delay))
    }

    func popIn(_ shown: Bool, delay: Double = 0) -> some View {
        modifier(PopIn(shown: shown, delay: delay))
    }
}

/// Le halo doux derrière Mika, qui respire.
private struct MikaGlow: View {
    var size: CGFloat = 240
    var color: Color = MicaboColor.accent

    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// **La plus grande taille qui tienne sous le haut de la page**, centrée en `center` : au
    /// delà, le halo (et sa respiration, 6 %) dépasse les dix points d'air au-dessus de la
    /// scène et se fait rogner net par le bord de la page. Par le bas, il peut déborder : rien
    /// ne le coupe, il passe sous la phrase.
    static func room(_ center: CGPoint, in size: CGSize) -> CGFloat {
        2 * (center.y + 8) / 1.08
    }

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.22), color.opacity(0)], center: .center, startRadius: 4, endRadius: size / 2))
            .frame(width: size, height: size)
            .scaleEffect(breathe ? 1.06 : 0.94)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true }
            }
    }
}

/// Quelques éclats qui scintillent autour d'une scène.
private struct Sparkles: View {
    let points: [CGPoint]
    var color: Color = MicaboColor.cautionVivid

    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Image(systemName: "sparkle")
                    .font(.system(size: index.isMultiple(of: 2) ? 18 : 12, weight: .bold))
                    .foregroundStyle(color)
                    .scaleEffect(on ? 1 : 0.4)
                    .opacity(on ? 1 : 0.2)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(Double(index) * 0.27),
                        value: on
                    )
                    .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
            }
        }
        .onAppear { on = true }
    }
}

// MARK: - 1. La mission

/// **Mika au centre, et ce qu'il fabrique autour de lui** : des notes, un quiz, des cartes,
/// un trophée, une flamme — chacun arrive en ressort, puis flotte à son rythme.
private struct MikaMissionScene: View {
    @State private var shown = false
    @Environment(\.onboardingStill) private var still

    private static let orbit: [(MicaboIcon, CGFloat, CGFloat)] = [
        (.notes, 0.17, 0.26), (.quiz, 0.83, 0.22), (.cards, 0.12, 0.66),
        (.trophy, 0.88, 0.62), (.flame, 0.34, 0.9), (.lightbulb, 0.68, 0.92),
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                MikaGlow(size: min(min(proxy.size.width, proxy.size.height) * 0.9, MikaGlow.room(CGPoint(x: 0, y: proxy.size.height * 0.52), in: proxy.size)))
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.52)

                ForEach(Array(Self.orbit.enumerated()), id: \.offset) { index, item in
                    MikaTile(icon: item.0, size: 64)
                        .rotationEffect(.degrees(index.isMultiple(of: 2) ? -7 : 6))
                        .bobbing(7, period: 1.9 + Double(index) * 0.23, delay: Double(index) * 0.1)
                        .popIn(shown || still, delay: 0.25 + Double(index) * 0.09)
                        .position(x: proxy.size.width * item.1, y: proxy.size.height * item.2)
                }

                MikaMascot(mood: .happy, size: min(170, proxy.size.height * 0.5), reactsToTap: true)
                    .popIn(shown || still, delay: 0.05)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.52)

                Sparkles(points: [CGPoint(x: 0.3, y: 0.12), CGPoint(x: 0.72, y: 0.4), CGPoint(x: 0.24, y: 0.46), CGPoint(x: 0.6, y: 0.1)])
            }
        }
        .onAppear { shown = true }
    }
}

// MARK: - 2. Les documents

/// **Les documents arrivent, et Mika les avale** : cours, PDF, notes, YouTube, photos,
/// audio, en arc au-dessus de lui ; l'un après l'autre, chacun plonge vers lui, Mika fait
/// « miam », et la tuile ne revient pas.
private struct MikaSourcesScene: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @Environment(\.onboardingStill) private var still
    @State private var flying: Int?
    /// Les tuiles déjà avalées : **elles ne reviennent pas.** Mika les a prises, elles sont
    /// à lui.
    @State private var eaten: Set<Int> = []
    @State private var full = false
    @State private var munch = false
    @State private var mood: MikaMood = .think

    private struct Source {
        let icon: MicaboIcon
        let key: String
    }

    private static let sources: [Source] = [
        Source(icon: .book, key: "ios.onb.mika.source.course"),
        Source(icon: .pdf, key: "ios.onb.mika.source.pdf"),
        Source(icon: .notes, key: "ios.onb.mika.source.notes"),
        Source(icon: .link, key: "ios.onb.mika.source.youtube"),
        Source(icon: .photo, key: "ios.onb.mika.source.photo"),
        Source(icon: .audio, key: "ios.onb.mika.source.audio"),
    ]

    var body: some View {
        GeometryReader { proxy in
            let mika = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.74)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.7, MikaGlow.room(mika, in: proxy.size)))
                    .position(mika)

                ForEach(Array(Self.sources.enumerated()), id: \.offset) { index, source in
                    let home = position(index, in: proxy.size)
                    let isGone = !still && (flying == index || eaten.contains(index))
                    MikaTile(icon: source.icon, size: 60, label: i18n.t(source.key))
                        .bobbing(5, period: 2 + Double(index) * 0.17, delay: Double(index) * 0.12)
                        .scaleEffect(isGone ? 0.25 : 1)
                        .opacity(isGone ? 0 : 1)
                        .offset(x: isGone ? mika.x - home.x : 0, y: isGone ? mika.y - home.y : 0)
                        .popIn(shown || still, delay: 0.2 + Double(index) * 0.1)
                        .position(home)
                }

                MikaMascot(mood: mood, size: min(150, proxy.size.height * 0.42))
                    .scaleEffect(munch ? 1.08 : 1)
                    .popIn(shown || still)
                    .position(mika)

                if full {
                    Sparkles(points: [CGPoint(x: 0.3, y: 0.55), CGPoint(x: 0.7, y: 0.5), CGPoint(x: 0.36, y: 0.88), CGPoint(x: 0.66, y: 0.9)])
                        .transition(.opacity)
                }
            }
        }
        .onAppear { shown = true }
        .task { await feed() }
    }

    /// Les six tuiles en arc, de gauche à droite, au-dessus de Mika.
    private func position(_ index: Int, in size: CGSize) -> CGPoint {
        let count = Double(Self.sources.count - 1)
        let angle = Double.pi * (1.08 - 1.16 * Double(index) / count)
        let radiusX = size.width * 0.38
        let radiusY = size.height * 0.5
        return CGPoint(
            x: size.width / 2 + radiusX * cos(angle),
            y: size.height * 0.74 - radiusY * sin(angle) * 0.92
        )
    }

    /// Une à une, les tuiles plongent vers Mika, qui croque ; une fois toutes avalées, il
    /// est content, et la scène reste ainsi : rien ne revient.
    @MainActor
    private func feed() async {
        guard !reduceMotion, !still else {
            mood = .happy
            return
        }
        try? await Task.sleep(for: .seconds(1.3))
        for index in Self.sources.indices {
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.42)) { flying = index }
            try? await Task.sleep(for: .seconds(0.42))
            eaten.insert(index)
            flying = nil
            withAnimation(.spring(duration: 0.25, bounce: 0.6)) {
                munch = true
                mood = .happy
            }
            Haptics.tick()
            try? await Task.sleep(for: .seconds(0.22))
            withAnimation(.spring(duration: 0.3)) { munch = false }
            try? await Task.sleep(for: .seconds(0.28))
        }
        guard !Task.isCancelled else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.5)) {
            mood = .celebrate
            full = true
        }
        Haptics.success()
    }
}

// MARK: - 3. Les parcours

/// **Une leçon de l'app, qui se construit** : le téléphone montre le chemin, ses étapes
/// sortent une à une et le trait se remplit jusqu'à l'étape en cours. Mika regarde depuis le
/// bord.
private struct MikaPathsScene: View {
    @State private var shown = false
    @Environment(\.onboardingStill) private var still

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                OnboardingLessonPhone(fades: true, animated: true, widthRatio: 0.74)
                    .frame(width: proxy.size.width, height: proxy.size.height)

                MikaMascot(mood: .wave, size: min(110, proxy.size.height * 0.3))
                    .bobbing(4, period: 2.4)
                    .popIn(shown || still, delay: 0.9)
                    .padding(.leading, proxy.size.width * 0.04)
                    .padding(.bottom, proxy.size.height * 0.08)
            }
        }
        .onAppear { shown = true }
    }
}

// MARK: - 4. Des leçons qui donnent envie

/// **Une question de l'app, et la joie d'avoir juste** : la carte arrive, une réponse se
/// choisit, passe au vert, « +10 XP » s'envole, la série monte, et Mika, assis sur la carte,
/// saute de joie. La scène recommence.
private struct MikaDesignScene: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @Environment(\.onboardingStill) private var still
    @State private var picked = false
    @State private var streak = 2
    @State private var burst = false

    private static let choices = ["1961", "1989", "1991"]
    private static let answer = 1

    var body: some View {
        GeometryReader { proxy in
            let cardWidth = min(330, proxy.size.width - 56)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.9, MikaGlow.room(CGPoint(x: 0, y: proxy.size.height * 0.55), in: proxy.size)), color: MicaboColor.correct)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.55)

                card(width: cardWidth)
                    .overlay(alignment: .topTrailing) {
                        MikaMascot(mood: picked || still ? .celebrate : .idle, size: 92)
                            .offset(x: 6, y: -74)
                    }
                    .overlay(alignment: .topLeading) { streakBadge.offset(x: -10, y: -16) }
                    .overlay { confetti }
                    .popIn(shown || still, delay: 0.1)
                    .position(x: proxy.size.width / 2, y: proxy.size.height * 0.6)
            }
        }
        .onAppear { shown = true }
        .task { await play() }
    }

    private func card(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("lesson.question.kind.choice", locale: .resolved()))
                .font(MicaboFont.ui(12, weight: .heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(LessonTone.blue.ink)
            Text(i18n.t("ios.onb.mika.design.question"))
                .font(MicaboFont.ui(19, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(Self.choices.enumerated()), id: \.offset) { index, choice in
                choiceRow(choice, isAnswer: index == Self.answer)
            }
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }

    private func choiceRow(_ choice: String, isAnswer: Bool) -> some View {
        let lit = (picked || still) && isAnswer
        return HStack {
            Text(choice)
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(lit ? MicaboColor.onInk : MicaboColor.ink)
            Spacer()
            if lit {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(lit ? MicaboColor.correct : MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(lit ? Color.clear : MicaboColor.stroke, lineWidth: 1.5))
        .scaleEffect(lit ? 1.03 : 1)
    }

    private var streakBadge: some View {
        HStack(spacing: 4) {
            MicaboIconView(icon: .flame, size: 22)
            Text("\(streak)")
                .font(MicaboFont.number(17))
                .foregroundStyle(MicaboColor.flameInk)
                .contentTransition(.numericText(value: Double(streak)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(MicaboColor.flameSoft, in: Capsule())
        .overlay(Capsule().strokeBorder(MicaboColor.surface, lineWidth: 2))
        .scaleEffect(burst ? 1.15 : 1)
    }

    /// « +10 XP » qui s'envole, et une poignée de confettis.
    private var confetti: some View {
        ZStack {
            Text("+10 XP")
                .font(MicaboFont.ui(16, weight: .black))
                .foregroundStyle(MicaboColor.correctInk)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MicaboColor.correctSoft, in: Capsule())
                .offset(y: burst ? -120 : -40)
                .opacity(burst ? 0 : (picked ? 1 : 0))
            ForEach(0..<10, id: \.self) { index in
                let angle = CGFloat(index) / 10 * 2 * .pi
                Circle()
                    .fill(LessonTone.allCases[index % LessonTone.allCases.count].vivid)
                    .frame(width: 9, height: 9)
                    .offset(x: burst ? cos(angle) * 150 : 0, y: burst ? sin(angle) * 110 : 0)
                    .opacity(burst ? 0 : (picked ? 1 : 0))
            }
        }
        .allowsHitTesting(false)
    }

    @MainActor
    private func play() async {
        guard !reduceMotion else {
            picked = true
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.spring(duration: 0.35, bounce: 0.5)) { picked = true }
            Haptics.success()
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.easeOut(duration: 0.9)) { burst = true }
            withAnimation(.spring(duration: 0.4, bounce: 0.6)) { streak += 1 }
            try? await Task.sleep(for: .seconds(2.2))
            withAnimation(.easeInOut(duration: 0.3)) { picked = false }
            burst = false
            if streak > 8 { streak = 2 }
        }
    }
}

// MARK: - 5. La solution

/// **Tout ce qu'il faut, en un seul endroit** : un anneau qui se remplit autour de Mika, et
/// les quatre portes de l'app — notes, quiz, flashcards, examen — qui se cochent une à une.
private struct MikaSolutionScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @Environment(\.onboardingStill) private var still
    @State private var fill: CGFloat = 0
    @State private var checked = 0

    private static let items: [(MicaboIcon, String, CGFloat, CGFloat)] = [
        (.notes, "lesson.nav.notes", 0.16, 0.2),
        (.quiz, "lesson.nav.quiz", 0.84, 0.2),
        (.cards, "lesson.nav.flashcards", 0.16, 0.82),
        (.exam, "lesson.tab.exams", 0.84, 0.82),
    ]

    var body: some View {
        GeometryReader { proxy in
            let ring = min(proxy.size.width * 0.56, proxy.size.height * 0.72)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.52)
            ZStack {
                Circle()
                    .stroke(MicaboColor.track, lineWidth: 16)
                    .frame(width: ring, height: ring)
                    .position(center)
                Circle()
                    .trim(from: 0, to: still ? 1 : fill)
                    .stroke(
                        AngularGradient(colors: [MicaboColor.accent, MicaboColor.keyword, MicaboColor.accent], center: .center),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: ring, height: ring)
                    .position(center)

                MikaMascot(mood: checked >= Self.items.count || still ? .celebrate : .happy, size: ring * 0.62)
                    .popIn(shown || still)
                    .position(center)

                ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                    MikaTile(icon: item.0, size: 58, label: L10n.t(item.1, locale: .resolved()))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(MicaboColor.onInk, MicaboColor.correct)
                                .background(Circle().fill(MicaboColor.surface).padding(2))
                                .offset(x: 8, y: -8)
                                .scaleEffect(index < checked || still ? 1 : 0.2)
                                .opacity(index < checked || still ? 1 : 0)
                        }
                        .bobbing(4, period: 2.1 + Double(index) * 0.2)
                        .popIn(shown || still, delay: 0.2 + Double(index) * 0.1)
                        .position(x: proxy.size.width * item.2, y: proxy.size.height * item.3)
                }
            }
        }
        .onAppear { shown = true }
        .task { await run() }
    }

    @MainActor
    private func run() async {
        if reduceMotion {
            fill = 1
            checked = Self.items.count
            return
        }
        try? await Task.sleep(for: .seconds(0.6))
        for index in Self.items.indices {
            withAnimation(.easeInOut(duration: 0.55)) { fill = CGFloat(index + 1) / CGFloat(Self.items.count) }
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.spring(duration: 0.4, bounce: 0.55)) { checked = index + 1 }
            Haptics.tick()
            try? await Task.sleep(for: .seconds(0.15))
        }
        Haptics.success()
    }
}

// MARK: - 6. La fin de la pression

/// **La montagne de choses à revoir, puis plus rien** : une pile de feuilles de travers, un
/// point rouge d'alerte ; elle s'effondre en une seule leçon bien rangée, cochée, et Mika s'y
/// pose, tranquille.
private struct MikaReliefScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown = false
    @Environment(\.onboardingStill) private var still
    @State private var tidy = false

    /// La pile : décalage, rotation, de bas en haut.
    private static let sheets: [(CGFloat, CGFloat, Double)] = [
        (-70, 70, -9), (40, 76, 7), (-20, 40, 4), (60, 28, -12), (-56, 4, 10), (12, -18, -5), (-6, -50, 8),
    ]

    var body: some View {
        GeometryReader { proxy in
            let base = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.62)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.85, MikaGlow.room(base, in: proxy.size)), color: tidy ? MicaboColor.correct : MicaboColor.wrong)
                    .position(base)
                    .animation(.easeInOut(duration: 0.8), value: tidy)

                ForEach(Array(Self.sheets.enumerated()), id: \.offset) { index, sheet in
                    paper(index: index)
                        .rotationEffect(.degrees(tidy ? 0 : sheet.2))
                        .offset(x: tidy ? 0 : sheet.0, y: tidy ? 0 : sheet.1)
                        .scaleEffect(tidy ? 0.6 : 1)
                        .opacity(tidy ? 0 : 1)
                        .popIn(shown || still, delay: 0.05 * Double(index))
                        .animation(.spring(duration: 0.6, bounce: 0.2).delay(tidy ? 0.03 * Double(Self.sheets.count - index) : 0), value: tidy)
                        .position(base)
                }

                alert
                    .opacity(tidy ? 0 : 1)
                    .scaleEffect(tidy ? 0.3 : 1)
                    .popIn(shown || still, delay: 0.45)
                    .position(x: base.x + 92, y: base.y - 96)
                    .animation(.spring(duration: 0.4), value: tidy)

                lesson
                    .scaleEffect(tidy ? 1 : 0.4)
                    .opacity(tidy ? 1 : 0)
                    .animation(.spring(duration: 0.55, bounce: 0.45).delay(0.25), value: tidy)
                    .position(base)

                MikaMascot(mood: tidy ? .happy : .surprise, size: 104)
                    .offset(y: tidy ? -96 : -150)
                    .opacity(shown || still ? 1 : 0)
                    .animation(.spring(duration: 0.6, bounce: 0.4).delay(tidy ? 0.4 : 0.3), value: tidy)
                    .animation(.easeOut(duration: 0.3).delay(0.3), value: shown)
                    .position(base)
            }
        }
        .onAppear { shown = true }
        .task { await settle() }
    }

    /// Une feuille de cours : des lignes grises, un surlignage, parfois une note rouge.
    private func paper(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(MicaboColor.ink.opacity(0.75)).frame(width: 70, height: 7)
            ForEach(0..<4, id: \.self) { line in
                Capsule()
                    .fill(line == 1 && index.isMultiple(of: 2) ? MicaboColor.cautionSoft : MicaboColor.track)
                    .frame(width: line == 3 ? 62 : 104, height: 5)
            }
        }
        .padding(14)
        .frame(width: 134, height: 96, alignment: .topLeading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.2))
        .overlay(alignment: .bottomTrailing) {
            if index % 3 == 1 {
                Text("?!")
                    .font(MicaboFont.ui(16, weight: .black))
                    .foregroundStyle(MicaboColor.wrongInk)
                    .padding(8)
            }
        }
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    private var alert: some View {
        Image(systemName: "exclamationmark")
            .font(.system(size: 22, weight: .black))
            .foregroundStyle(MicaboColor.onInk)
            .frame(width: 44, height: 44)
            .background(MicaboColor.wrong, in: Circle())
            .overlay(Circle().strokeBorder(MicaboColor.surface, lineWidth: 3))
            .bobbing(3, period: 0.9)
    }

    /// La leçon rangée : une icône, une barre pleine, une coche.
    private var lesson: some View {
        HStack(spacing: 14) {
            MicaboIconView(icon: .check, size: 54)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(MicaboColor.ink.opacity(0.8)).frame(width: 110, height: 9)
                Capsule().fill(MicaboColor.correct).frame(width: 140, height: 10)
                    .overlay(alignment: .leading) { Capsule().fill(.white.opacity(0.3)).frame(height: 3).padding(.horizontal, 5).offset(y: -1) }
            }
        }
        .padding(18)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.correct.opacity(0.5), lineWidth: 2))
        .micaboElevation(.card)
    }

    @MainActor
    private func settle() async {
        if reduceMotion {
            tidy = true
            return
        }
        try? await Task.sleep(for: .seconds(1.5))
        tidy = true
        Haptics.success()
    }
}

// MARK: - Avant les moyennes : l'histoire

/// **Deux étudiants, une montagne de cours, puis l'idée.** Les deux étudiants arrivent, une
/// bulle « ? » au-dessus de chacun ; entre eux, leurs documents s'entassent de travers. Puis
/// l'ampoule s'allume, les bulles deviennent des « ! », la pile se range — et Micabo naît
/// au milieu, dans ses éclats.
private struct MikaFoundersScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    /// 0 : rien ; 1 : les étudiants, perdus ; 2 : l'idée ; 3 : Micabo.
    @State private var phase = 0

    private static let pile: [(MicaboIcon, CGFloat, CGFloat, Double)] = [
        (.book, -34, 14, -14), (.pdf, 30, 8, 12), (.notes, -4, -18, -4),
    ]

    private var stage: Int { still ? 3 : phase }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let center = CGPoint(x: w / 2, y: h * 0.6)
            ZStack {
                MikaGlow(size: min(min(w, h) * 0.95, MikaGlow.room(center, in: proxy.size)), color: stage >= 2 ? MicaboColor.cautionVivid : MicaboColor.accent)
                    .position(center)
                    .animation(.easeInOut(duration: 0.8), value: stage)

                ForEach(0..<2, id: \.self) { side in
                    let x = side == 0 ? w * 0.18 : w * 0.82
                    student(side)
                        .bobbing(4, period: 2.1 + Double(side) * 0.3)
                        .popIn(stage >= 1, delay: Double(side) * 0.15)
                        .position(x: x, y: h * 0.66)

                    bubble(stage >= 2 ? "!" : "?", lit: stage >= 2)
                        .popIn(stage >= 1, delay: 0.35 + Double(side) * 0.15)
                        .position(x: x + (side == 0 ? 18 : -18), y: h * 0.66 - 70)
                        .animation(.spring(duration: 0.4, bounce: 0.5), value: stage)
                }

                ForEach(Array(Self.pile.enumerated()), id: \.offset) { index, item in
                    MikaTile(icon: item.0, size: 54)
                        .rotationEffect(.degrees(stage >= 3 ? 0 : item.3))
                        .offset(x: stage >= 3 ? 0 : item.1, y: stage >= 3 ? 0 : item.2)
                        .scaleEffect(stage >= 3 ? 0.4 : 1)
                        .opacity(stage >= 3 ? 0 : 1)
                        .popIn(stage >= 1, delay: 0.2 + Double(index) * 0.1)
                        .animation(.spring(duration: 0.55, bounce: 0.25), value: stage)
                        .position(x: center.x, y: center.y + 18)
                }

                MicaboIconView(icon: .lightbulb, size: 62)
                    .shadow(color: MicaboColor.cautionVivid.opacity(0.45), radius: stage >= 2 ? 22 : 0)
                    .bobbing(5, period: 1.8)
                    .popIn(stage >= 2)
                    .position(x: center.x, y: h * 0.2)

                MicaboBrandMark(size: 70)
                    .shadow(color: MicaboColor.accent.opacity(0.3), radius: 18, y: 8)
                    .popIn(stage >= 3)
                    .position(x: center.x, y: center.y + 12)

                if stage >= 3 {
                    Sparkles(points: [CGPoint(x: 0.36, y: 0.46), CGPoint(x: 0.64, y: 0.44), CGPoint(x: 0.4, y: 0.8), CGPoint(x: 0.62, y: 0.78)])
                        .transition(.opacity)
                }
            }
        }
        .task { await run() }
    }

    private func student(_ side: Int) -> some View {
        Text(side == 0 ? "🧑‍🎓" : "👩‍🎓")
            .font(.system(size: 44))
            .frame(width: 84, height: 84)
            .background(MicaboColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            .micaboElevation(.card)
    }

    private func bubble(_ mark: String, lit: Bool) -> some View {
        Text(mark)
            .font(MicaboFont.display(22))
            .foregroundStyle(lit ? MicaboColor.onInk : MicaboColor.inkSecondary)
            .frame(width: 40, height: 40)
            .background(lit ? MicaboColor.accent : MicaboColor.surface, in: Circle())
            .overlay(Circle().strokeBorder(lit ? Color.clear : MicaboColor.stroke, lineWidth: 1.5))
            .micaboElevation(.card)
    }

    @MainActor
    private func run() async {
        guard !reduceMotion else {
            phase = 3
            return
        }
        try? await Task.sleep(for: .seconds(0.25))
        phase = 1
        try? await Task.sleep(for: .seconds(1.3))
        guard !Task.isCancelled else { return }
        phase = 2
        Haptics.light()
        try? await Task.sleep(for: .seconds(0.9))
        guard !Task.isCancelled else { return }
        phase = 3
        Haptics.success()
    }
}

/// **Ce que dit la recherche, en deux barres** : un cours en classe, puis le même cours avec
/// un tuteur IA, deux fois plus haut. Mika arrive sur la seconde, et s'en réjouit. Les
/// chiffres exacts sont dans la carte, sous la phrase.
private struct MikaCompanionScene: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var grown = false

    private var isGrown: Bool { grown || still }

    var body: some View {
        GeometryReader { proxy in
            // La place de Mika au-dessus de la grande barre est prise sur la hauteur : rien ne
            // dépasse du haut de la scène.
            let chart = max(90, min(proxy.size.height - 120, 200))
            let barWidth = min(96, proxy.size.width * 0.24)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.8, MikaGlow.room(CGPoint(x: 0, y: proxy.size.height * 0.45), in: proxy.size)))
                    .position(x: proxy.size.width * 0.62, y: proxy.size.height * 0.45)

                HStack(alignment: .bottom, spacing: proxy.size.width * 0.12) {
                    bar(label: i18n.t("ios.onb.companion.class"), height: chart * 0.42, width: barWidth, colors: [MicaboColor.inkTertiary.opacity(0.55), MicaboColor.inkTertiary.opacity(0.75)], delay: 0)
                    bar(label: i18n.t("ios.onb.companion.ai"), height: chart * 0.88, width: barWidth, colors: OnboardingPalette.mikaGradient, delay: 0.25)
                        .overlay(alignment: .top) {
                            MikaMascot(mood: isGrown ? .celebrate : .think, size: 76)
                                .offset(y: -66)
                                .popIn(isGrown, delay: 0.9)
                        }
                }
                .position(x: proxy.size.width / 2, y: proxy.size.height - (chart * 0.88 + 42) / 2 - 4)
            }
        }
        .onAppear {
            guard !reduceMotion else {
                grown = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                grown = true
                Haptics.soft()
            }
        }
    }

    private func bar(label: String, height: CGFloat, width: CGFloat, colors: [Color], delay: Double) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top))
                .frame(width: width, height: isGrown ? height : 14)
                .overlay(alignment: .top) {
                    Capsule().fill(.white.opacity(0.3)).frame(height: 4).padding(.horizontal, 10).padding(.top, 6)
                }
                .animation(.spring(duration: 1.1, bounce: 0.2).delay(delay), value: isGrown)
            Text(label)
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(width: width + 40, height: 34, alignment: .top)
        }
        .frame(height: height + 42, alignment: .bottom)
    }
}

/// **D'où tu pars, et jusqu'où on va.** Un chemin pointillé se trace du bas à gauche vers le
/// haut à droite ; l'épingle « Tu es ici » tombe au départ, deux étapes s'allument en route,
/// et le trophée attend au bout, sur son halo. Mika regarde vers le haut.
private struct MikaStartScene: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var drawn: CGFloat = 0
    @State private var shown = false

    private static let start = CGPoint(x: 0.2, y: 0.8)
    private static let end = CGPoint(x: 0.8, y: 0.26)
    private static let stops: [(CGFloat, CGFloat)] = [(0.42, 0.62), (0.6, 0.42)]

    private var progress: CGFloat { still ? 1 : drawn }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let a = CGPoint(x: size.width * Self.start.x, y: size.height * Self.start.y)
            let b = CGPoint(x: size.width * Self.end.x, y: size.height * Self.end.y)
            ZStack {
                MikaGlow(size: min(size.width * 0.6, MikaGlow.room(b, in: size)), color: MicaboColor.cautionVivid)
                    .position(b)

                StartTrail(from: a, to: b)
                    .stroke(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10]))
                StartTrail(from: a, to: b)
                    .trim(from: 0, to: progress)
                    .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 10]))

                ForEach(Array(Self.stops.enumerated()), id: \.offset) { index, stop in
                    let lit = progress >= stop.0 + 0.05
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(lit ? MicaboColor.onInk : MicaboColor.inkTertiary)
                        .frame(width: 34, height: 34)
                        .background(lit ? MicaboColor.correct : MicaboColor.surface, in: Circle())
                        .overlay(Circle().strokeBorder(lit ? Color.clear : MicaboColor.stroke, lineWidth: 1.5))
                        .scaleEffect(lit ? 1.08 : 1)
                        .animation(.spring(duration: 0.35, bounce: 0.55), value: lit)
                        .position(StartTrail.point(at: stop.0, from: a, to: b))
                        .popIn(shown || still, delay: 0.15 + Double(index) * 0.1)
                }

                VStack(spacing: 6) {
                    MicaboIconView(icon: .trophy, size: 64)
                        .bobbing(5, period: 2)
                    label(i18n.t("ios.onb.start.goal"), tint: MicaboColor.caution, fill: MicaboColor.cautionSoft)
                }
                .popIn(shown || still, delay: 0.3)
                .position(x: b.x, y: b.y + 8)

                VStack(spacing: 4) {
                    label(i18n.t("ios.onb.start.here"), tint: MicaboColor.onInk, fill: MicaboColor.accent)
                    MicaboIconView(icon: .pin, size: 46)
                }
                .offset(y: shown || still ? 0 : -60)
                .opacity(shown || still ? 1 : 0)
                .animation(.spring(duration: 0.55, bounce: 0.5).delay(0.1), value: shown)
                .position(x: a.x, y: a.y - 30)

                MikaMascot(mood: .wave, size: min(92, size.height * 0.3))
                    .popIn(shown || still, delay: 0.5)
                    .position(x: size.width * 0.16, y: size.height * 0.36)
            }
        }
        .onAppear {
            shown = true
            guard !reduceMotion else {
                drawn = 1
                return
            }
            withAnimation(.easeInOut(duration: 1.6).delay(0.5)) { drawn = 1 }
        }
    }

    private func label(_ text: String, tint: Color, fill: Color) -> some View {
        Text(text)
            .font(MicaboFont.ui(12.5, weight: .heavy))
            .foregroundStyle(tint)
            .lineLimit(1)
            .fixedSize()
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(fill, in: Capsule())
    }
}

/// Le chemin de la scène du départ : une courbe en S douce, du départ vers le but.
private struct StartTrail: Shape {
    let from: CGPoint
    let to: CGPoint

    private static func controls(from: CGPoint, to: CGPoint) -> (CGPoint, CGPoint) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return (CGPoint(x: from.x + dx * 0.9, y: from.y + dy * 0.1), CGPoint(x: from.x + dx * 0.1, y: from.y + dy * 0.9))
    }

    /// Le point de la courbe à une fraction donnée de sa longueur, à peu près.
    static func point(at t: CGFloat, from: CGPoint, to: CGPoint) -> CGPoint {
        let (c1, c2) = controls(from: from, to: to)
        let u = 1 - t
        let x = u * u * u * from.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * to.x
        let y = u * u * u * from.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * to.y
        return CGPoint(x: x, y: y)
    }

    func path(in rect: CGRect) -> Path {
        let (c1, c2) = Self.controls(from: from, to: to)
        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: c1, control2: c2)
        return path
    }
}

// MARK: - Le prof particulier

/// **Mika, dans la poche, à toute heure.** Un téléphone flotte ; dedans, une question arrive
/// — « Tu peux m'expliquer la photosynthèse ? » —, Mika tape, puis répond. Autour, deux
/// pastilles : 24 h/24, toutes tes matières.
private struct MikaTutorScene: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    /// 0 : le téléphone ; 1 : la question ; 2 : Mika tape ; 3 : sa réponse.
    @State private var phase = 0
    @State private var dot = 0

    private var stage: Int { still ? 3 : phase }

    var body: some View {
        GeometryReader { proxy in
            let phoneWidth = min(230, proxy.size.width * 0.58)
            let phoneHeight = min(proxy.size.height * 0.94, phoneWidth * 1.6)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.85, MikaGlow.room(CGPoint(x: 0, y: proxy.size.height / 2), in: proxy.size)))
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                phone(width: phoneWidth, height: phoneHeight)
                    .bobbing(4, period: 2.6)
                    .popIn(stage >= 0)
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)

                badge(icon: .alarm, text: i18n.t("ios.onb.tutor.anytime"))
                    .rotationEffect(.degrees(-6))
                    .bobbing(5, period: 2.2, delay: 0.2)
                    .popIn(stage >= 1, delay: 0.2)
                    .position(x: proxy.size.width * 0.17, y: proxy.size.height * 0.24)

                badge(icon: .book, text: i18n.t("ios.onb.tutor.subjects"))
                    .rotationEffect(.degrees(5))
                    .bobbing(5, period: 2.5, delay: 0.4)
                    .popIn(stage >= 3, delay: 0.2)
                    .position(x: proxy.size.width * 0.83, y: proxy.size.height * 0.78)
            }
        }
        .task { await run() }
    }

    private func phone(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MikaMascot(mood: stage >= 3 ? .happy : .idle, size: 30)
                Text("Mika")
                    .font(MicaboFont.ui(14, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                Circle().fill(MicaboColor.correct).frame(width: 7, height: 7)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 4)

            if stage >= 1 {
                Text(i18n.t("ios.onb.tutor.ask"))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(MicaboColor.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.leading, 24)
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }

            if stage == 2 {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(MicaboColor.inkTertiary)
                            .frame(width: 7, height: 7)
                            .opacity(dot == index ? 1 : 0.35)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .transition(.opacity)
            }

            if stage >= 3 {
                Text(i18n.t("ios.onb.tutor.answer"))
                    .font(MicaboFont.ui(13, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
                    .padding(.trailing, 18)
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 26)
        .padding(.bottom, 14)
        .frame(width: width, height: height, alignment: .top)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).strokeBorder(Color(hex: 0x15161A), lineWidth: 7))
        .overlay(alignment: .top) {
            Capsule().fill(Color(hex: 0x15161A)).frame(width: 64, height: 16).padding(.top, 9)
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 22, y: 14)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: stage)
    }

    private func badge(icon: MicaboIcon, text: String) -> some View {
        HStack(spacing: 6) {
            MicaboIconView(icon: icon, size: 28)
            Text(text)
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.vertical, 8)
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .background(MicaboColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }

    @MainActor
    private func run() async {
        guard !reduceMotion else {
            phase = 3
            return
        }
        try? await Task.sleep(for: .seconds(0.5))
        phase = 1
        Haptics.tick()
        try? await Task.sleep(for: .seconds(0.7))
        guard !Task.isCancelled else { return }
        phase = 2
        for step in 0..<6 {
            try? await Task.sleep(for: .seconds(0.18))
            dot = step % 3
        }
        guard !Task.isCancelled else { return }
        phase = 3
        Haptics.light()
    }
}

// MARK: - Une leçon de l'app, dans un téléphone

/// **Une leçon telle que l'app la montre** : l'en-tête (icône 3D, titre, « 40 % », la barre),
/// le chemin de la leçon avec ses ronds, sa bulle « Commencer » et ses titres d'étape, puis la
/// barre Notes · Quiz · Flashcards. Dessinée avec les composants du chemin (`PathNode`,
/// `PathTrail`, `PathStepTitle`, `LessonNavbar`), à la taille d'un vrai écran, puis réduite à
/// celle du téléphone : c'est l'app, pas une capture.
///
/// `animated` fait sortir les étapes une à une et remplit le trait, pour l'écran « parcours ».
struct OnboardingLessonPhone: View {
    var fades = false
    var animated = false
    var widthRatio: CGFloat = 0.8

    /// La largeur d'écran sur laquelle la leçon se compose, avant d'être réduite.
    static let screenWidth: CGFloat = 390
    static let screenHeight: CGFloat = 844
    /// La bordure du téléphone, en points d'écran.
    private static let bezel: CGFloat = 12
    private static let frame = Color(hex: 0x15161A)

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * widthRatio
            let outerWidth = Self.screenWidth + 2 * Self.bezel
            let scale = width / outerWidth
            phone
                .frame(width: outerWidth, height: Self.screenHeight + 2 * Self.bezel)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: outerWidth * scale, height: (Self.screenHeight + 2 * Self.bezel) * scale, alignment: .topLeading)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
        }
        .padding(.top, MicaboSpacing.sm)
        .mask {
            if fades {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.62),
                        .init(color: .clear, location: 0.98),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Rectangle()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var phone: some View {
        ZStack(alignment: .top) {
            // Le cadre d'un téléphone est noir, de jour comme de nuit.
            RoundedRectangle(cornerRadius: 62, style: .continuous)
                .fill(Self.frame)
            OnboardingLessonScreen(animated: animated)
                .frame(width: Self.screenWidth, height: Self.screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: 52, style: .continuous))
                .padding(Self.bezel)
            Capsule()
                .fill(Self.frame)
                .frame(width: 120, height: 34)
                .padding(.top, Self.bezel + 12)
        }
        .shadow(color: .black.opacity(0.18), radius: 30, y: 16)
    }
}

/// L'écran de la leçon, à la taille d'un iPhone.
private struct OnboardingLessonScreen: View {
    let animated: Bool

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var revealedState = 0

    private var revealed: Int { still ? circles.count : revealedState }

    private let tone = LessonTone.blue

    private var circles: [(PathCircle, PathCircle.State)] {
        let t = { (key: String) in i18n.t(key) }
        return [
            (PathCircle(kind: .intro, number: 1, title: L10n.t("lesson.circle.intro", locale: .resolved()), icon: .notes, symbol: "play.fill"), .done),
            (PathCircle(kind: .notes(theme: 0), number: 2, title: t("ios.onb.sample.step1"), icon: .notes, symbol: "flag.fill"), .done),
            (PathCircle(kind: .notes(theme: 1), number: 3, title: t("ios.onb.sample.step2"), icon: .notes, symbol: "bolt.fill"), .current),
            (PathCircle(kind: .quiz(group: 0, themes: [0, 1]), number: 4, title: L10n.t("lesson.circle.checkpoint", locale: .resolved()), icon: .quiz, symbol: "rosette", subtitle: t("ios.onb.sample.group")), .upcoming),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            header
                .padding(.top, 8)
            path
                .padding(.top, 26)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
            LessonNavbar(dueCount: 3) { _ in }
                .padding(.bottom, 26)
        }
        .background(MicaboColor.canvas)
        .onAppear {
            guard animated else {
                revealedState = circles.count
                return
            }
            for index in circles.indices {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5 + Double(index) * 0.32) {
                    withAnimation(.spring(duration: 0.5, bounce: 0.45)) { revealedState = index + 1 }
                }
            }
        }
    }

    private var statusBar: some View {
        HStack {
            Text("9:41")
                .font(MicaboFont.ui(17, weight: .bold))
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: "cellularbars")
                Image(systemName: "wifi")
                Image(systemName: "battery.100")
            }
            .font(.system(size: 15, weight: .semibold))
        }
        .foregroundStyle(MicaboColor.ink)
        .padding(.horizontal, 34)
        .frame(height: 54)
    }

    private var header: some View {
        VStack(spacing: 12) {
            MicaboIconView(icon: .globe, size: 104)
                .shadow(color: tone.vivid.opacity(0.25), radius: 20, x: 0, y: 12)
            Text(i18n.t("ios.onb.sample.title"))
                .font(MicaboFont.display(28))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            VStack(spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text("40 %")
                        .font(MicaboFont.number(24))
                        .foregroundStyle(tone.ink)
                    Spacer(minLength: 8)
                    Text(L10n.t("lesson.path.stepsDone", locale: .resolved(), vars: ["done": "2", "total": "7"]))
                        .font(MicaboFont.ui(16, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                Capsule().fill(MicaboColor.track)
                    .frame(height: 13)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(tone.vivid)
                                .frame(width: proxy.size.width * (revealed >= 3 ? 0.4 : 0.08))
                        }
                    }
            }
            .padding(.horizontal, 30)
        }
    }

    private var path: some View {
        let width = OnboardingLessonPhone.screenWidth
        let layout = PathGeometry(count: circles.count, width: width)
        let reached = circles.firstIndex { $0.1 == .current } ?? 0
        let fraction = layout.fraction(upTo: min(reached, max(0, revealed - 1)))
        return VStack(spacing: 0) {
            ForEach(Array(circles.enumerated()), id: \.offset) { index, entry in
                row(entry.0, state: entry.1, index: index, layout: layout)
                    .frame(width: width, height: PathMapView.rowHeight)
            }
        }
        .frame(width: width)
        .background(alignment: .topLeading) {
            let shape = PathTrail(points: layout.centers)
            ZStack {
                shape.stroke(MicaboColor.track, style: StrokeStyle(lineWidth: PathMapView.trailWidth, lineCap: .round, lineJoin: .round))
                shape
                    .trim(from: 0, to: revealed > 0 ? fraction : 0)
                    .stroke(tone.vivid, style: StrokeStyle(lineWidth: PathMapView.trailWidth, lineCap: .round, lineJoin: .round))
                    .animation(.easeInOut(duration: 0.6), value: revealed)
            }
            .frame(width: layout.width, height: layout.height)
        }
    }

    private func row(_ circle: PathCircle, state: PathCircle.State, index: Int, layout: PathGeometry) -> some View {
        let center = layout.centers[index]
        let titleOnRight = layout.titleOnRight(index)
        let reach = PathMapView.nodeSize / 2 + PathMapView.ringGap + PathMapView.ringWidth + PathMapView.titleGap
        let titleWidth = max(96, titleOnRight ? layout.width - 18 - (center.x + reach) : center.x - reach - 18)
        let titleX = titleOnRight ? center.x + reach + titleWidth / 2 : center.x - reach - titleWidth / 2
        let y = PathMapView.rowHeight / 2
        let shown = index < revealed
        return ZStack {
            PathNode(circle: circle, state: state, readiness: .ready, tone: tone, ring: state == .current ? 0.35 : 0) {}
                .scaleEffect(shown ? 1 : 0.3)
                .opacity(shown ? 1 : 0)
                .position(x: center.x, y: y)
            PathStepTitle(circle: circle, state: state, readiness: .ready, tone: tone, alignLeading: titleOnRight) {}
                .frame(width: titleWidth, alignment: titleOnRight ? .leading : .trailing)
                .opacity(shown ? 1 : 0)
                .offset(x: shown ? 0 : (titleOnRight ? -12 : 12))
                .position(x: titleX, y: y)
        }
    }
}
