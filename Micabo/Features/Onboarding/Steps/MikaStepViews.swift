import SwiftUI

// MARK: - Mika se présente, en sept écrans

/// Les écrans où Mika dit ce qu'il fait, dans l'ordre du parcours : sa mission, les documents
/// qu'il prend, les parcours qu'il en tire, l'XP et la série, le prof particulier dans la
/// poche, tout au même endroit, la montagne rangée. Trois au lot 7 ; les quatre autres sont
/// revenus au lot 9, à la première personne comme les trois premiers.
enum MikaPage: String, CaseIterable, Identifiable {
    case mission
    case sources
    case paths
    case design
    case tutor
    case solution
    case relief

    var id: String { rawValue }

    /// L'étape du parcours qui montre la page.
    var step: OnboardingStep {
        switch self {
        case .mission: .mikaMission
        case .sources: .mikaSources
        case .paths: .mikaPaths
        case .design: .mikaDesign
        case .tutor: .mikaTutor
        case .solution: .mikaSolution
        case .relief: .mikaRelief
        }
    }

    /// La phrase de l'écran ; les mots entre `**` se peignent du dégradé de l'app. Les pages du
    /// lot 7 gardent leurs phrases ; celles revenues au lot 9 ont les leurs.
    var titleKey: String {
        switch self {
        case .sources, .paths, .tutor: "ios.onb7.mika.\(rawValue)"
        case .mission, .design, .solution, .relief: "ios.onb9.mika.\(rawValue)"
        }
    }

    /// **La part de la page que prend la scène.**
    var sceneShare: CGFloat { 0.6 }
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
                // Les rendus de la CI ne dessinent pas l'intérieur d'un `ScrollView` : la page
                // y est posée telle quelle, pour qu'on y lise la phrase de Mika.
                if still {
                    column(width: proxy.size.width, room: room, sceneHeight: sceneHeight, isShown: isShown)
                } else {
                    ScrollView {
                        column(width: proxy.size.width, room: room, sceneHeight: sceneHeight, isShown: isShown)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
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
            withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion).delay(reduceMotion ? 0 : 0.2)) {
                shown = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.4 : Self.actionDelay)) {
                withAnimation(MicaboMotion.standard) { showsAction = true }
            }
        }
    }

    /// La scène, puis la phrase : la colonne de la page, qu'elle défile ou non.
    private func column(width: CGFloat, room: CGFloat, sceneHeight: CGFloat, isShown: Bool) -> some View {
        VStack(spacing: 0) {
            // Dix points d'air au-dessus : ce qui flotte en haut de la scène — Mika
            // assis sur sa carte — n'est pas rogné par le bord de la page.
            scene
                .frame(width: width, height: sceneHeight)
                .padding(.top, 10)
                .accessibilityHidden(true)

            OnboardingAccentText(template: i18n.t(page.titleKey), size: 27, alignment: .center)
                .padding(.horizontal, 26)
                .padding(.top, 6)
                .padding(.bottom, MicaboSpacing.md)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
                .opacity(isShown ? 1 : 0)
                .offset(y: isShown ? 0 : 14)

            Spacer(minLength: 0)
        }
        .frame(width: width)
        .frame(minHeight: room, alignment: .top)
    }

    @ViewBuilder
    private var scene: some View {
        MikaPageScene(page: page)
    }
}

/// **La scène d'une page de Mika, seule** : ce que `MikaStepView` pose au-dessus de sa phrase.
/// Les rendus la dessinent à part — la page entière défile, et `ImageRenderer` ne dessine pas
/// un `ScrollView`.
struct MikaPageScene: View {
    let page: MikaPage

    @ViewBuilder
    var body: some View {
        switch page {
        case .mission: MikaMissionScene()
        case .sources: MikaSourcesScene()
        case .paths: MikaPathsScene()
        case .design: MikaDesignScene()
        case .tutor: MikaTutorScene()
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

/// **Un objet qui se pose**, chacun à son rythme : il arrive d'un peu plus bas, une fois, puis
/// reste immobile. Il flottait sans fin ; une scène qui bouge en boucle sous une phrase qu'on
/// lit tire l'œil de la phrase, et ne dit rien de plus la dixième seconde que la première.
private struct Bobbing: ViewModifier {
    var amplitude: CGFloat = 6
    var period: Double = 2.2
    var delay: Double = 0

    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: settled || reduceMotion ? 0 : amplitude)
            .onAppear {
                withAnimation(MicaboMotion.resolved(MicaboMotion.gentle, reduceMotion: reduceMotion).delay(delay)) { settled = true }
            }
    }
}

/// Une apparition en ressort, décalée par son rang. Pour Mika (`scales` faux), un fondu sur
/// place : il ne surgit pas de petit.
private struct PopIn: ViewModifier {
    let shown: Bool
    var delay: Double = 0
    var scales = true

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || !scales ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .animation(MicaboMotion.standard.delay(delay), value: shown)
    }
}

private extension View {
    func bobbing(_ amplitude: CGFloat = 6, period: Double = 2.2, delay: Double = 0) -> some View {
        modifier(Bobbing(amplitude: amplitude, period: period, delay: delay))
    }

    func popIn(_ shown: Bool, delay: Double = 0, scales: Bool = true) -> some View {
        modifier(PopIn(shown: shown, delay: delay, scales: scales))
    }
}

/// Le halo doux derrière Mika, immobile : il respirait en boucle.
private struct MikaGlow: View {
    var size: CGFloat = 240
    var color: Color = MicaboColor.accent

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
    }
}

/// Quelques éclats autour d'une scène : ils s'allument une fois, l'un après l'autre, puis
/// restent. Ils clignotaient sans fin.
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
                        reduceMotion ? nil : MicaboMotion.standard.delay(0.3 + Double(index) * 0.12),
                        value: on
                    )
                    .position(x: proxy.size.width * point.x, y: proxy.size.height * point.y)
            }
        }
        .onAppear { on = true }
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

                // Mika en demi, qui dépasse de sa ligne au bas de la scène.
                let side = min(130, proxy.size.height * 0.42)
                // Il croque : un petit écrasement de 3 % sur place, jamais un saut.
                OnboardingMikaOnLine(mood: mood, size: side)
                    .scaleEffect(x: munch ? 1.03 : 1, y: munch ? 0.97 : 1, anchor: .bottom)
                    .popIn(shown || still, scales: false)
                    .position(x: mika.x, y: proxy.size.height - OnboardingMikaOnLine.height(for: side) / 2)

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
            withAnimation(MicaboMotion.standard) { flying = index }
            try? await Task.sleep(for: .seconds(0.42))
            eaten.insert(index)
            flying = nil
            withAnimation(MicaboMotion.quick) {
                munch = true
                mood = .happy
            }
            Haptics.tick()
            try? await Task.sleep(for: .seconds(0.22))
            withAnimation(MicaboMotion.quick) { munch = false }
            try? await Task.sleep(for: .seconds(0.28))
        }
        guard !Task.isCancelled else { return }
        // La seule courbe à rebond de l'app, pour la réussite de la scène.
        withAnimation(MicaboMotion.celebrate) {
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

                // Mika, en demi, fait coucou depuis le bord bas de la scène, sur sa ligne.
                OnboardingMikaOnLine(mood: .wave, size: min(MikaPeek.hero, proxy.size.height * 0.32))
                    .popIn(shown || still, delay: 0.9, scales: false)
                    .padding(.leading, proxy.size.width * 0.02)
            }
        }
        .onAppear { shown = true }
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

                // **Les pastilles s'appuient sur un bord, elles ne s'y centrent plus.** Centrées
                // à 17 % et 83 % de la largeur, une étiquette un peu longue (« Todas as tuas
                // disciplinas », et déjà « Toutes tes matières ») sortait de l'écran. Ancrées
                // à la marge, elles restent où elles étaient quand elles sont courtes, et
                // grandissent vers le téléphone quand la langue est longue.
                let badgeWidth = proxy.size.width * Self.badgeShare
                badge(icon: .alarm, text: i18n.t("ios.onb.tutor.anytime"))
                    .rotationEffect(.degrees(-6))
                    .bobbing(5, period: 2.2, delay: 0.2)
                    .popIn(stage >= 1, delay: 0.2)
                    .frame(width: badgeWidth, alignment: .leading)
                    .position(x: Self.badgeInset + badgeWidth / 2, y: proxy.size.height * 0.24)

                badge(icon: .book, text: i18n.t("ios.onb.tutor.subjects"))
                    .rotationEffect(.degrees(5))
                    .bobbing(5, period: 2.5, delay: 0.4)
                    .popIn(stage >= 3, delay: 0.2)
                    .frame(width: badgeWidth, alignment: .trailing)
                    .position(x: proxy.size.width - Self.badgeInset - badgeWidth / 2, y: proxy.size.height * 0.78)
            }
        }
        .task { await run() }
    }

    private func phone(width: CGFloat, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MikaAvatar(size: 30)
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
        .animation(MicaboMotion.standard, value: stage)
    }

    /// La part de la largeur qu'une pastille peut prendre, et sa marge au bord de l'écran.
    private static let badgeShare: CGFloat = 0.55
    private static let badgeInset: CGFloat = 12

    private func badge(icon: MicaboIcon, text: String) -> some View {
        HStack(spacing: 6) {
            MicaboIconView(icon: icon, size: 28)
            Text(text)
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
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

// MARK: - La mission (lot 9)

/// **Ce que Mika fabrique pour toi** : des fiches, un quiz, des cartes, un trophée, une série,
/// une idée — chacune se pose autour de lui, une fois, puis ne bouge plus. Mika, en demi sur
/// sa ligne, écrit.
private struct MikaMissionScene: View {
    @State private var shown = false
    @Environment(\.onboardingStill) private var still

    /// L'icône, sa place (en fraction de la largeur, puis de la hauteur au-dessus de Mika), et
    /// son inclinaison.
    private static let orbit: [(MicaboIcon, CGFloat, CGFloat, Double)] = [
        (.cards, 0.30, 0.02, 5), (.trophy, 0.70, 0.0, -6),
        (.notes, 0.15, 0.48, -7), (.quiz, 0.85, 0.44, 6),
        (.flame, 0.13, 0.98, 7), (.lightbulb, 0.87, 0.94, -5),
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(MikaPeek.hero, proxy.size.height * 0.4)
            let peek = OnboardingMikaOnLine.height(for: side)
            let mika = CGPoint(x: proxy.size.width / 2, y: proxy.size.height - peek / 2)
            // La place des tuiles : du haut de la scène au sommet de Mika.
            let top: CGFloat = 40
            let usable = max(60, proxy.size.height - peek - top - 10)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.8, MikaGlow.room(mika, in: proxy.size)))
                    .position(mika)

                ForEach(Array(Self.orbit.enumerated()), id: \.offset) { index, item in
                    MikaTile(icon: item.0, size: 62)
                        .rotationEffect(.degrees(item.3))
                        .bobbing(6, delay: Double(index) * 0.06)
                        .popIn(shown || still, delay: 0.2 + Double(index) * 0.07)
                        .position(x: proxy.size.width * item.1, y: top + usable * item.2)
                }

                OnboardingMikaOnLine(mood: .write, size: side)
                    .popIn(shown || still, scales: false)
                    .position(mika)

                Sparkles(points: [CGPoint(x: 0.5, y: 0.08), CGPoint(x: 0.24, y: 0.3), CGPoint(x: 0.78, y: 0.26), CGPoint(x: 0.5, y: 0.42)])
            }
        }
        .onAppear { shown = true }
    }
}

// MARK: - L'XP et la série (lot 9)

/// **Chaque bonne réponse rapporte, et la série grandit** : une carte de l'app — la flamme et
/// son nombre de jours, la semaine qui se coche jour après jour, la barre d'XP qui se remplit
/// avec « +10 XP ». Le jaune est celui de l'app pour la série et l'XP, et rien d'autre ne
/// l'est. Mika dépasse du haut de la carte. Pas de deuxième question : la vraie, sur sa
/// matière, vient juste avant (`SampleCardStepView`).
private struct MikaDesignScene: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var shown = false
    /// Les jours cochés de la semaine, de 0 à 7.
    @State private var days = 0

    private static let week = 7
    private var lit: Int { still ? Self.week : days }

    var body: some View {
        GeometryReader { proxy in
            let width = min(330, proxy.size.width - 56)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.62)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.9, MikaGlow.room(center, in: proxy.size)), color: MicaboColor.cautionVivid)
                    .position(center)

                card(width: width)
                    // Mika passe la tête par-dessus la carte : le bord haut de la carte coupe son
                    // buste (la règle de mise en scène).
                    .background(alignment: .topTrailing) {
                        MikaPeek(mood: .wink, width: MikaPeek.card, reactsToTap: true, animates: !still)
                            .offset(x: -18, y: -MikaPeek.height(for: MikaPeek.card) + 2)
                            .accessibilityHidden(true)
                    }
                    // Un fondu sur place : Mika est sur la carte, il ne surgit pas de petit.
                    .popIn(shown || still, delay: 0.1, scales: false)
                    .position(center)
            }
        }
        .onAppear { shown = true }
        .task { await fill() }
    }

    private func card(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                MicaboIconView(icon: .flame, size: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text(max(1, lit).formatted(.number.locale(i18n.locale.foundation)))
                        .font(MicaboFont.number(34))
                        .foregroundStyle(MicaboColor.flameInk)
                        .contentTransition(.numericText(value: Double(lit)))
                    Text(i18n.t("ios.streak.title"))
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 8)
                Text("+10 XP")
                    .font(MicaboFont.ui(15, weight: .black))
                    .foregroundStyle(MicaboColor.flameInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MicaboColor.flameSoft, in: Capsule())
                    .environment(\.layoutDirection, .leftToRight)
            }

            HStack(spacing: 0) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { index, symbol in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(index < lit ? MicaboColor.cautionVivid : MicaboColor.track)
                            if index < lit {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .black))
                                    .foregroundStyle(MicaboColor.flameInk)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 30, height: 30)
                        Text(symbol)
                            .font(MicaboFont.ui(12, weight: .bold))
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Capsule()
                .fill(MicaboColor.track)
                .frame(height: 12)
                .overlay(alignment: .leading) {
                    GeometryReader { bar in
                        Capsule()
                            .fill(MicaboColor.cautionVivid)
                            .frame(width: bar.size.width * (0.18 + 0.8 * CGFloat(lit) / CGFloat(Self.week)))
                    }
                }
        }
        .padding(18)
        .frame(width: width, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
        .animation(MicaboMotion.standard, value: lit)
    }

    /// Les jours de la semaine, dans la langue de l'élève et à partir du premier jour de son
    /// pays : « L M M J V S D », « M D M D F S S », « ن ث ر خ ج س ح ».
    private var weekdays: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = i18n.locale.foundation
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[first...] + symbols[..<first])
    }

    /// La semaine se coche jour après jour, une fois, puis reste pleine.
    @MainActor
    private func fill() async {
        guard !still else { return }
        guard !reduceMotion else {
            days = Self.week
            return
        }
        try? await Task.sleep(for: .seconds(0.7))
        for day in 1...Self.week {
            guard !Task.isCancelled else { return }
            days = day
            Haptics.tick()
            try? await Task.sleep(for: .seconds(0.16))
        }
        Haptics.success()
    }
}

// MARK: - Tout au même endroit (lot 9)

/// **Les quatre portes d'une leçon, cochées l'une après l'autre** : fiches, quiz, flashcards,
/// examens blancs. Mika, en demi sur sa ligne, regarde le tout.
private struct MikaSolutionScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var shown = false
    @State private var checked = 0

    private static let items: [(MicaboIcon, String)] = [
        (.notes, "lesson.nav.notes"),
        (.quiz, "lesson.nav.quiz"),
        (.cards, "lesson.nav.flashcards"),
        (.exam, "lesson.tab.exams"),
    ]

    private var done: Int { still ? Self.items.count : checked }

    var body: some View {
        GeometryReader { proxy in
            let side = min(MikaPeek.hero, proxy.size.height * 0.36)
            let peek = OnboardingMikaOnLine.height(for: side)
            let mika = CGPoint(x: proxy.size.width / 2, y: proxy.size.height - peek / 2)
            let gridHeight = max(120, proxy.size.height - peek - 24)
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.85, MikaGlow.room(CGPoint(x: 0, y: gridHeight / 2), in: proxy.size)))
                    .position(x: proxy.size.width / 2, y: gridHeight / 2)

                VStack(spacing: 22) {
                    HStack(spacing: 44) {
                        tile(0)
                        tile(1)
                    }
                    HStack(spacing: 44) {
                        tile(2)
                        tile(3)
                    }
                }
                .position(x: proxy.size.width / 2, y: gridHeight / 2 + 6)

                OnboardingMikaOnLine(mood: .look, size: side)
                    .popIn(shown || still, delay: 0.1, scales: false)
                    .position(mika)
            }
        }
        .onAppear { shown = true }
        .task { await run() }
    }

    private func tile(_ index: Int) -> some View {
        let item = Self.items[index]
        let isChecked = index < done
        return MikaTile(icon: item.0, size: 64, label: L10n.t(item.1, locale: .resolved()))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk, MicaboColor.correct)
                    .background(Circle().fill(MicaboColor.surface).padding(2))
                    .offset(x: 10, y: -10)
                    .scaleEffect(isChecked ? 1 : 0.3)
                    .opacity(isChecked ? 1 : 0)
                    .animation(MicaboMotion.standard, value: isChecked)
            }
            .bobbing(4, delay: Double(index) * 0.08)
            .popIn(shown || still, delay: 0.15 + Double(index) * 0.08)
    }

    @MainActor
    private func run() async {
        guard !still else { return }
        guard !reduceMotion else {
            checked = Self.items.count
            return
        }
        try? await Task.sleep(for: .seconds(0.8))
        for index in Self.items.indices {
            guard !Task.isCancelled else { return }
            checked = index + 1
            Haptics.tick()
            try? await Task.sleep(for: .seconds(0.3))
        }
        Haptics.success()
    }
}

// MARK: - La montagne rangée (lot 9)

/// **La pile de choses à revoir, puis une leçon rangée** : des feuilles de travers
/// s'empilent, puis se replient en une seule carte de leçon, cochée et à jour. Mika, en demi sur
/// sa ligne au bord, regarde la pile se ranger. Pas de rouge : rien n'est en retard ici, c'est
/// juste en désordre.
private struct MikaReliefScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var shown = false
    @State private var tidyState = false

    private var tidy: Bool { still || tidyState }

    /// La pile : décalage, rotation, de bas en haut.
    private static let sheets: [(CGFloat, CGFloat, Double)] = [
        (-64, 54, -9), (40, 60, 7), (-20, 30, 4), (56, 18, -12), (-50, 0, 10), (12, -20, -5), (-6, -46, 8),
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(MikaPeek.hero, proxy.size.height * 0.34)
            let peek = OnboardingMikaOnLine.height(for: side)
            let base = CGPoint(x: proxy.size.width / 2, y: max(110, (proxy.size.height - peek) * 0.5))
            ZStack {
                MikaGlow(size: min(proxy.size.width * 0.85, MikaGlow.room(base, in: proxy.size)), color: tidy ? MicaboColor.correct : MicaboColor.accent)
                    .position(base)

                ForEach(Array(Self.sheets.enumerated()), id: \.offset) { index, sheet in
                    paper(index: index)
                        .rotationEffect(.degrees(tidy ? 0 : sheet.2))
                        .offset(x: tidy ? 0 : sheet.0, y: tidy ? 0 : sheet.1)
                        .scaleEffect(tidy ? 0.6 : 1)
                        .opacity(tidy ? 0 : 1)
                        .popIn(shown || still, delay: 0.04 * Double(index))
                        .position(base)
                }

                lesson
                    .scaleEffect(tidy ? 1 : 0.5)
                    .opacity(tidy ? 1 : 0)
                    .position(base)

                OnboardingMikaOnLine(mood: tidy ? .wink : .look, size: side)
                    .popIn(shown || still, delay: 0.2, scales: false)
                    .position(x: proxy.size.width / 2, y: proxy.size.height - peek / 2)
            }
            .animation(MicaboMotion.gentle, value: tidy)
        }
        .onAppear { shown = true }
        .task { await settle() }
    }

    /// Une feuille de cours : des lignes grises, parfois un surlignage.
    private func paper(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Capsule().fill(MicaboColor.ink.opacity(0.7)).frame(width: 70, height: 7)
            ForEach(0..<4, id: \.self) { line in
                Capsule()
                    .fill(line == 1 && index.isMultiple(of: 2) ? MicaboColor.accentSoft : MicaboColor.track)
                    .frame(width: line == 3 ? 62 : 104, height: 5)
            }
        }
        .padding(14)
        .frame(width: 134, height: 96, alignment: .topLeading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.2))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    /// La leçon rangée : une icône, une barre pleine, une coche.
    private var lesson: some View {
        HStack(spacing: 14) {
            MicaboIconView(icon: .check, size: 54)
            VStack(alignment: .leading, spacing: 8) {
                Capsule().fill(MicaboColor.ink.opacity(0.8)).frame(width: 110, height: 9)
                Capsule().fill(MicaboColor.correct).frame(width: 140, height: 10)
            }
        }
        .padding(18)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }

    @MainActor
    private func settle() async {
        guard !still else { return }
        guard !reduceMotion else {
            tidyState = true
            return
        }
        try? await Task.sleep(for: .seconds(1.4))
        guard !Task.isCancelled else { return }
        tidyState = true
        Haptics.success()
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
                    withAnimation(MicaboMotion.standard) { revealedState = index + 1 }
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
                    Text(L10n.percent(40, locale: .resolved()))
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
                    .animation(MicaboMotion.standard, value: revealed)
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


// MARK: - Mika sur sa ligne

/// **Mika sur une ligne** : en demi, il dépasse d'un trait du filet de l'app qui coupe son
/// corps, comme sur les questions du parcours (`OnboardingMikaPrompt`) ; ou, pour un moment
/// qui compte (`whole` : le plan révélé, la préparation du plan), en entier, debout sur le
/// papier. Jamais dans une pastille bleue.
struct OnboardingMikaOnLine: View {
    var mood: MikaMood = .idle
    /// La largeur de Mika en demi, le côté de son carré en entier.
    var size: CGFloat = 120
    var whole = false
    var animates = true

    @Environment(\.onboardingStill) private var still

    /// La hauteur de la vue.
    static func height(for size: CGFloat, whole: Bool = false) -> CGFloat {
        whole ? size : MikaPeek.height(for: size) + 2
    }

    var body: some View {
        Group {
            if whole {
                MikaMascot(mood: mood, size: size, reactsToTap: true, frozenAt: still ? 0 : nil, backdrop: .surface, animates: animates)
            } else {
                VStack(spacing: 0) {
                    MikaPeek(mood: mood, width: size, reactsToTap: true, animates: animates && !still)
                    Capsule()
                        .fill(MicaboColor.stroke)
                        .frame(width: size * 1.4, height: 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
