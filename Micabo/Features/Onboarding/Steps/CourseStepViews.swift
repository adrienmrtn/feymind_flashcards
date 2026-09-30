import SwiftData
import SwiftUI

// MARK: - Les supports

/// **Les cases de dépôt, celles de la création d'un deck.** Le parcours ne redessine pas
/// l'import : c'est le même écran, avec le rond fléché à la place de la pilule, et le même
/// objet `DeckSetup` que `DeckBuilder` lira à l'écran suivant.
///
/// **La branche du parcours se prend ici**, sans question avant : déposer et avancer mène
/// à la construction ; « je n'ai rien pour l'instant », en gris à gauche du rond, mène au
/// choix d'un cours de démonstration. Une question « tu as tes supports ? » posée sur un
/// écran à part demandait de répondre avant d'avoir vu ce qu'on pouvait déposer.
struct OnboardingMaterialsStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        DeckMaterialsStepView(
            setup: model.deckSetup,
            usesArrow: true,
            onNothing: {
                model.hasMaterials = false
                model.advance()
            }
        ) {
            model.hasMaterials = true
            model.advance()
        }
    }
}

// MARK: - Le cours de démonstration

/// **« Choisis un cours à générer. »** Quatre cours, quatre matières, une carte chacun :
/// l'emoji sur son pastel, le titre, la matière, le nombre de chapitres et de cartes. On en
/// choisit un, et il se « génère » à l'écran suivant.
struct DemoCourseStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var courses: [OnboardingDemoCourse] {
        OnboardingDemoCatalog.courses(locale: i18n.locale)
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb.demo.title"),
            subtitle: i18n.t("ios.onb.demo.sub"),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 10) {
                ForEach(Array(courses.enumerated()), id: \.element.id) { rank, course in
                    DemoCourseRow(
                        course: course,
                        rank: rank,
                        isSelected: model.demoCourse?.id == course.id
                    ) {
                        model.demoCourse = course
                    }
                }
            }
        } footer: {
            OnboardingArrowButton(isEnabled: model.demoCourse != nil) {
                model.advance()
            }
        }
    }
}

/// Une carte de cours à choisir : d'encre quand elle est choisie, comme une réponse.
private struct DemoCourseRow: View {
    let course: OnboardingDemoCourse
    let rank: Int
    let isSelected: Bool
    var action: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(course.emoji)
                    .font(.system(size: 26))
                    .frame(width: 52, height: 52)
                    .background(
                        isSelected ? OnboardingPalette.white.opacity(0.14) : MicaboColor.pastel(at: rank),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.title)
                        .font(MicaboFont.ui(16.5, weight: .semibold))
                        .foregroundStyle(isSelected ? OnboardingPalette.white : OnboardingPalette.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(
                        SubjectDisplay.subject(course.subject, locale: i18n.locale)
                            + " · " + i18n.t("ios.deck.chapterCount", ["count": "\(course.chapters.count)"])
                            + " · " + MicaboCopy.cards(course.cardCount, locale: i18n.locale)
                    )
                    .font(OnboardingPalette.subtitle)
                    .foregroundStyle(isSelected ? OnboardingPalette.white.opacity(0.7) : OnboardingPalette.gray)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                }

                Spacer(minLength: MicaboSpacing.xs)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? OnboardingPalette.ink : OnboardingPalette.card,
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(OnboardingMotion.select, value: isSelected)
        .onboardingAppear(index: 3 + rank, stagger: OnboardingMotion.rowStagger)
        .accessibilityLabel(course.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - La construction du cours

/// **Mika écrit le cours**, pour de vrai ou pour de faux, sur le même écran.
///
/// Avec des supports, c'est `DeckBuilder` qui travaille : la fiche, le plan, les cartes,
/// enregistrés dès qu'ils existent. La jauge suit son propre temps — vite au début, de
/// moins en moins, sans jamais atteindre le bout tant que le cours n'est pas là — et
/// finit le chemin en une seconde quand il arrive. Sans supports, le cours de
/// démonstration entre dans la bibliothèque au bout du même chargement joué que le profil.
///
/// **La fin enchaîne d'elle-même**, comme le profil : un coup net, le blob rapetisse, et le
/// cours s'ouvre.
struct CourseBuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var shown: Double = 0
    @State private var elapsed: Double = 0
    @State private var built: Course?
    @State private var failure: String?
    @State private var didStart = false
    @State private var isDone = false
    @State private var didAdvance = false

    /// Le plafond de la jauge tant que le cours n'est pas construit.
    private static let ceiling: Double = 0.92
    /// La durée du chargement joué, pour le cours de démonstration.
    static let demoDuration = 6.5
    private static let holdAtEnd = 0.7
    private static let thresholds: [Double] = [0.22, 0.5, 0.74, 1.0]
    private static let stages: [DeckBuilder.Stage] = [.reading, .writingSheet, .splitting, .writingCards]

    private var stepLabel: String {
        let index = Self.thresholds.firstIndex { shown < $0 - 0.001 } ?? Self.stages.count - 1
        return i18n.t(Self.stages[min(index, Self.stages.count - 1)].captionKey)
    }

    private var subtitle: String {
        if let demo = model.demoCourse, model.isDemoCourse {
            return demo.title
        }
        return i18n.t("ios.mika.course.materials")
    }

    var body: some View {
        Group {
            if let failure {
                failureBody(failure)
            } else {
                MikaLoadingView(
                    progress: shown,
                    title: i18n.t("ios.mika.course.title"),
                    subtitle: subtitle,
                    stepLabel: stepLabel,
                    isDone: isDone
                )
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .task {
            guard !didStart else { return }
            didStart = true
            // La jauge ne bouge qu'une fois la page posée : des chiffres qui roulent sur une
            // page encore en train de glisser se lisent comme un tremblement.
            try? await Task.sleep(for: .seconds(OnboardingMotion.slideDuration + 0.05))
            guard !Task.isCancelled else { return }
            if model.isDemoCourse {
                await playDemo()
            } else {
                await buildReal()
            }
        }
    }

    // MARK: Pour de vrai

    @MainActor
    private func buildReal() async {
        let creeping = Task { @MainActor in await creep() }
        do {
            let outcome = try await DeckBuilder.build(model.deckSetup, using: aiService, in: modelContext)
            creeping.cancel()
            built = outcome.course
            await finish(with: outcome.course)
        } catch {
            creeping.cancel()
            failure = error.localizedDescription
        }
    }

    /// **L'asymptote.** Toutes les trois dixièmes de seconde, la jauge avance de deux pour
    /// cent de ce qui la sépare du plafond, sans jamais l'atteindre.
    @MainActor
    private func creep() async {
        while !Task.isCancelled, built == nil, failure == nil {
            let step = (Self.ceiling - shown) * 0.02
            withAnimation(.linear(duration: 0.3)) { shown += max(0.0006, step) }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    // MARK: Pour de faux

    /// Le même temps joué que le profil, puis le cours entre dans la bibliothèque.
    @MainActor
    private func playDemo() async {
        guard let demo = model.demoCourse else {
            failure = i18n.t("ios.deckBuild.failed")
            return
        }
        let frame = 1.0 / 30.0
        while elapsed < Self.demoDuration, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int(frame * 1000)))
            elapsed = min(Self.demoDuration, elapsed + frame)
            shown = MikaProgressCurve.value(at: elapsed / Self.demoDuration)
        }
        guard !Task.isCancelled else { return }
        do {
            let language = ContentLanguage(rawValue: i18n.locale.rawValue) ?? .en
            let course = try OnboardingDemoCatalog.install(demo, language: language, in: modelContext)
            built = course
            await finish(with: course)
        } catch {
            failure = error.localizedDescription
        }
    }

    // MARK: La fin

    /// Ce qui reste de la jauge se remplit par paliers, puis un coup net, puis la page
    /// suivante.
    @MainActor
    private func finish(with course: Course) async {
        for target in Self.thresholds where target > shown {
            withAnimation(.easeOut(duration: 0.25)) { shown = target }
            try? await Task.sleep(for: .milliseconds(240))
        }
        shown = 1
        isDone = true
        Haptics.success()
        try? await Task.sleep(for: .milliseconds(Int(Self.holdAtEnd * 1000)))
        guard !didAdvance else { return }
        didAdvance = true
        model.builtCourse = course
        model.advance()
    }

    // MARK: Quand ça rate

    private func failureBody(_ message: String) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: MicaboSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(MicaboColor.ratingAgain)

                Text(i18n.t("ios.deckBuild.failed"))
                    .font(MicaboFont.ui(22, weight: .bold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(MicaboFont.ui(14, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: 0)

            MicaboBottomBar(background: OnboardingPalette.white) {
                VStack(spacing: 10) {
                    OnboardingContinueButton(title: i18n.t("ios.retry")) {
                        failure = nil
                        shown = 0
                        elapsed = 0
                        didStart = false
                        Task { @MainActor in
                            guard !didStart else { return }
                            didStart = true
                            if model.isDemoCourse { await playDemo() } else { await buildReal() }
                        }
                    }

                    if !model.isDemoCourse {
                        Button(i18n.t("ios.deckBuild.back")) {
                            model.jump(to: .materials)
                        }
                        .buttonStyle(MicaboSecondaryButtonStyle())
                    }

                    Button(i18n.t("ios.onb.course.skip")) {
                        model.courseUnavailable = true
                        model.advance()
                    }
                    .buttonStyle(MicaboQuietButtonStyle())
                }
            }
        }
    }
}

/// **La courbe du chargement joué**, partagée par le profil et le cours de démonstration :
/// vite au début, trois ralentissements, et le bout.
enum MikaProgressCurve {
    private static let curve: [(at: Double, reached: Double)] = [
        (0.00, 0.00), (0.10, 0.11), (0.20, 0.15), (0.38, 0.44), (0.46, 0.48),
        (0.66, 0.73), (0.74, 0.77), (0.90, 0.94), (1.00, 1.00),
    ]

    static func value(at time: Double) -> Double {
        let time = min(1, max(0, time))
        var previous = curve[0]
        for point in curve.dropFirst() {
            if time <= point.at {
                let span = point.at - previous.at
                let ratio = span > 0 ? (time - previous.at) / span : 1
                return previous.reached + (point.reached - previous.reached) * ratio
            }
            previous = point
        }
        return 1
    }
}

// MARK: - Le cours qu'on parcourt

/// **Le cours fiché, ouvert en entier**, avec le rond fléché qui flotte en bas à droite.
///
/// C'est le vrai plan du deck — le bandeau, le titre, les chapitres —, sans les actions
/// de révision, sans le cadenas Pro, sans le menu : on lit, on ouvre un chapitre, on
/// revient. Le cours est déjà dans la bibliothèque ; c'est le même objet que l'app montrera
/// à la sortie du parcours.
///
/// **Le rond fait visiter.** Il n'avance pas d'un coup : il ouvre le premier chapitre, puis
/// le deuxième, puis les suivants, et ne passe à la suite qu'une fois le dernier ouvert.
/// Un élève qui touche un chapitre de lui-même compte comme y étant passé : le rond reprend
/// au premier chapitre qu'il n'a pas vu. C'est ce qui garantit qu'on a lu une fiche avant
/// de s'entraîner dessus — sans forcer personne à défiler jusqu'en bas.
struct CourseReviewStepView: View {
    @Environment(OnboardingModel.self) private var model

    /// La pile : vide sur le plan, le chapitre ouvert sinon.
    @State private var path: [Chapter] = []
    /// Le rang du prochain chapitre que le rond ouvre.
    @State private var nextChapter = 0

    var body: some View {
        ZStack {
            if let course = model.builtCourse {
                NavigationStack(path: $path) {
                    OnboardingCoursePlanView(course: course) { chapter in
                        open(chapter, in: course)
                    }
                    .navigationDestination(for: Chapter.self) { chapter in
                        OnboardingChapterView(chapter: chapter, demo: demoChapter(for: chapter))
                    }
                }
            } else {
                OnboardingPalette.white.ignoresSafeArea()
            }
        }
        .overlay(alignment: .bottomTrailing) {
            OnboardingArrowButton {
                advance()
            }
            .padding(.trailing, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.sm)
        }
        .environment(\.onboardingSurface, .canvas)
    }

    /// Un chapitre touché sur le plan : il s'ouvre, et le rond reprendra après lui.
    private func open(_ chapter: Chapter, in course: Course) {
        if let index = course.orderedChapters.firstIndex(where: { $0.id == chapter.id }) {
            nextChapter = max(nextChapter, index + 1)
        }
        path = [chapter]
    }

    /// Le rond : le prochain chapitre non vu, ou la suite quand tous le sont. Depuis un
    /// chapitre ouvert, le suivant le remplace dans la pile : on ne repasse pas par le plan.
    private func advance() {
        let chapters = model.builtCourse?.orderedChapters ?? []
        guard nextChapter < chapters.count else {
            model.advance()
            return
        }
        let chapter = chapters[nextChapter]
        nextChapter += 1
        path = [chapter]
    }

    /// Le chapitre de démonstration qui correspond, quand le cours est le cours joué :
    /// c'est lui qui porte les schémas et les graphes.
    private func demoChapter(for chapter: Chapter) -> DemoChapter? {
        guard model.isDemoCourse, let demo = model.demoCourse else { return nil }
        return demo.chapters.indices.contains(chapter.position) ? demo.chapters[chapter.position] : nil
    }
}

/// Le plan : bandeau, titre, matière, chapitres. Toucher un chapitre le signale au parent,
/// qui l'ouvre.
private struct OnboardingCoursePlanView: View {
    let course: Course
    var onOpen: (Chapter) -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var safeTop: CGFloat { MicaboScreen.safeTop }
    private var pastel: Color { MicaboColor.pastel(for: course.id) }

    var body: some View {
        MicaboCollapsingScreen(expandedHeight: safeTop + MicaboHeaderBand.deck) { scroll in
            OnboardingCourseBanner(
                emoji: course.emoji,
                pastel: pastel,
                title: course.title,
                band: MicaboHeaderBand.deck,
                safeTop: safeTop,
                offset: scroll.offset,
                showsBack: false,
                onBack: {}
            )
        } content: {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                identity
                plan
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 22)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
        }
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(course.title)
                .font(MicaboFont.ui(25, weight: .bold))
                .tracking(-0.5)
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 9) {
                if let subject = course.subject?.nilIfBlank {
                    Text(SubjectDisplay.subject(subject, locale: i18n.locale).uppercased())
                        .font(MicaboFont.ui(11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(MicaboColor.inkSecondary)
                    dot
                }

                Text(i18n.t("ios.deck.chapterCount", ["count": "\(course.orderedChapters.count)"]))
                    .font(MicaboFont.ui(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)

                dot

                Text(MicaboCopy.cards(course.cards.count, locale: i18n.locale))
                    .font(MicaboFont.ui(13, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)

                Spacer(minLength: 0)
            }

            if !course.summary.isEmpty {
                Text(course.summary)
                    .font(MicaboFont.reading(15))
                    .foregroundStyle(MicaboColor.inkReading)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    private var dot: some View {
        Circle()
            .fill(MicaboColor.inkTertiary)
            .frame(width: 3, height: 3)
    }

    private var plan: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(i18n.t("ios.deck.chapters"))
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .padding(.bottom, 2)

            VStack(spacing: 0) {
                ForEach(Array(course.orderedChapters.enumerated()), id: \.element.id) { index, chapter in
                    MicaboChapterRow(
                        number: index + 1,
                        title: chapter.title.nilIfBlank ?? i18n.t("ios.deck.untitledChapter", ["number": "\(index + 1)"]),
                        meta: chapter.cardCount > 0
                            ? i18n.t("ios.deck.notStarted") + " · " + i18n.t("ios.deck.cardCount", ["count": "\(chapter.cardCount)"])
                            : i18n.t("ios.deck.notStarted"),
                        state: index == 0 ? .inProgress : .untouched
                    ) {
                        onOpen(chapter)
                    }
                    if index < course.orderedChapters.count - 1 {
                        MicaboHairline(onCanvas: true)
                    }
                }
            }
        }
    }

}

/// Un chapitre ouvert : la fiche riche pour le cours de démonstration, la fiche telle
/// qu'elle est enregistrée pour le cours de l'élève. On lit, on ne corrige pas.
private struct OnboardingChapterView: View {
    let chapter: Chapter
    let demo: DemoChapter?

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private static let margin: CGFloat = 22
    private var safeTop: CGFloat { MicaboScreen.safeTop }

    private var tint: Color { Color(hexString: chapter.course?.accentHex ?? "") }
    private var pastel: Color { MicaboColor.pastel(for: chapter.course?.id ?? chapter.id) }

    private var number: Int {
        (chapter.course?.orderedChapters.firstIndex { $0.id == chapter.id } ?? chapter.position) + 1
    }

    /// Les blocs enregistrés, sans le titre de partie que la page écrit déjà en tête.
    private var blocks: [SheetBlock] {
        var all = chapter.decodedSheet()?.blocks ?? []
        if case .heading(_, let text)? = all.first,
           SheetMarkup.plain(text).caseInsensitiveCompare(chapter.title.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame {
            all.removeFirst()
        }
        return all
    }

    var body: some View {
        MicaboCollapsingScreen(expandedHeight: safeTop + MicaboHeaderBand.chapter) { scroll in
            OnboardingCourseBanner(
                emoji: chapter.course?.emoji ?? "📘",
                pastel: pastel,
                title: chapter.title,
                band: MicaboHeaderBand.chapter,
                safeTop: safeTop,
                offset: scroll.offset,
                readingProgress: scroll.progress,
                showsBack: true,
                onBack: { dismiss() }
            )
        } content: {
            VStack(alignment: .leading, spacing: 0) {
                MicaboFactLine(facts: facts)

                Text(chapter.title)
                    .font(MicaboFont.ui(25, weight: .bold))
                    .tracking(-0.5)
                    .lineSpacing(2)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 9)

                Group {
                    if let demo {
                        DemoSheetView(blocks: demo.blocks, tint: tint)
                    } else {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                                SheetBlockView(block: block, tint: tint)
                                    .padding(.top, index == 0 ? 0 : SheetBlockView.spacing(before: block))
                            }
                        }
                    }
                }
                .padding(.top, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Self.margin)
            .padding(.top, 20)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
        }
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .enablesSwipeBack()
    }

    private var facts: [MicaboFactLine.Fact] {
        var out: [MicaboFactLine.Fact] = [
            .init(text: i18n.t("ios.chapterShort", ["number": "\(number)"]), isLead: true),
        ]
        if chapter.cardCount > 0 {
            out.append(.init(text: MicaboCopy.cards(chapter.cardCount, locale: i18n.locale)))
        }
        let minutes = CourseSheet(blocks: blocks).readingMinutes
        out.append(.init(text: i18n.t("ios.chapter.readingTime", ["minutes": "\(minutes)"])))
        return out
    }
}

// MARK: - Le bandeau

/// **Le bandeau d'un cours ou d'un chapitre, réduit à ce que le parcours en montre** : le
/// pastel, l'emoji qui voyage en se repliant, le titre qui arrive, et un retour quand il y
/// a où revenir. Pas de menu, pas de taille de texte : on ne fait que lire.
struct OnboardingCourseBanner: View {
    let emoji: String
    let pastel: Color
    let title: String
    let band: CGFloat
    let safeTop: CGFloat
    let offset: CGFloat
    var readingProgress: Double? = nil
    var showsBack: Bool
    var onBack: () -> Void

    private var travel: CGFloat { band - MicaboHeaderBand.collapsed }
    private var collapse: CGFloat { min(1, max(0, offset / travel)) }
    private var stretch: CGFloat { max(0, -offset) }
    private var height: CGFloat { safeTop + band - travel * collapse + stretch }

    private static var button: CGFloat { 38 }
    private static var emojiSlot: CGFloat { 22 }
    private static var gap: CGFloat { 8 }

    var body: some View {
        let sidePadding: CGFloat = 18 - 4 * collapse
        let circleAlpha: Double = 0.88 * Double(1 - collapse)
        let titleAlpha: Double = Double(max(0, (collapse - 0.4) / 0.6))
        let titleRise: CGFloat = 6 * (1 - collapse)
        let emojiScale: CGFloat = 1 - 0.673 * collapse + stretch / 600
        let restY: CGFloat = safeTop + (band + stretch) / 2
        let barY: CGFloat = safeTop + Self.button / 2
        let emojiY: CGFloat = restY + (barY - restY) * collapse
        let barX: CGFloat = sidePadding + Self.button + Self.gap + Self.emojiSlot / 2
        let shadowAlpha: Double = 0.10 * Double(collapse)

        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let restX: CGFloat = proxy.size.width / 2
                let emojiX: CGFloat = restX + (barX - restX) * collapse

                Text(emoji)
                    .font(.system(size: 52))
                    .scaleEffect(emojiScale)
                    .position(x: emojiX, y: emojiY)
            }
            .allowsHitTesting(false)

            HStack(spacing: Self.gap) {
                if showsBack {
                    MicaboBannerButton(circleAlpha: circleAlpha, action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .accessibilityLabel(L10n.t("app.common.back", locale: .resolved()))
                } else {
                    Color.clear.frame(width: Self.button, height: Self.button)
                }

                Color.clear
                    .frame(width: Self.emojiSlot, height: Self.button)

                Text(title)
                    .font(MicaboFont.ui(16, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(titleAlpha)
                    .offset(y: titleRise)
                    .accessibilityHidden(titleAlpha < 0.5)

                Color.clear.frame(width: Self.button, height: Self.button)
            }
            .padding(.horizontal, sidePadding)
            .padding(.top, safeTop)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            Rectangle()
                .fill(pastel)
                .shadow(color: MicaboColor.ink.opacity(shadowAlpha), radius: 14, x: 0, y: 2)
        }
        .overlay(alignment: .bottom) {
            if let readingProgress {
                GeometryReader { proxy in
                    let fill: CGFloat = CGFloat(max(0, min(1, readingProgress))) * proxy.size.width
                    ZStack(alignment: .leading) {
                        Rectangle().fill(MicaboColor.ink.opacity(0.10))
                        Rectangle().fill(MicaboColor.accent).frame(width: fill)
                    }
                }
                .frame(height: 3)
                .opacity(Double(collapse))
            }
        }
    }
}
