import SwiftData
import SwiftUI

// MARK: - Les supports

/// **Les cases de dépôt, celles de la création d'un deck.** Le parcours ne redessine pas
/// l'import : c'est le même écran, avec le rond fléché à la place de la pilule, et le même
/// objet `DeckSetup`, dont `LessonBuilder` fera la leçon à l'écran suivant.
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

/// **Mika écrit la leçon**, pour de vrai ou pour de faux, sur le même écran.
///
/// Avec des supports, c'est `LessonBuilder` qui travaille, comme depuis Home : le plan, puis
/// les thèmes, quatre à la fois. L'écran rend la main dès que le premier thème est écrit ; les
/// autres s'écrivent pendant la suite du parcours. La jauge suit son propre temps — vite au
/// début, de moins en moins — et ne descend jamais sous l'étape que la génération a atteinte.
/// Sans supports, le cours de démonstration entre dans la bibliothèque, déjà en leçon, au
/// bout du même chargement joué que le profil.
///
/// **La fin enchaîne d'elle-même**, comme le profil : un coup net, le blob rapetisse, et le
/// cours s'ouvre.
struct CourseBuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(\.modelContext) private var modelContext
    @Environment(LessonBuilder.self) private var lessons
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var shown: Double = 0
    /// L'étape réelle de la génération, quand c'est une vraie leçon.
    @State private var stage: LessonBuilder.Stage?
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
    private static let stages = LessonBuilder.Stage.allCases

    private var stepLabel: String {
        if let stage {
            return i18n.t(GenerationSteps.key(for: stage, hasSupports: true))
        }
        let index = Self.thresholds.firstIndex { shown < $0 - 0.001 } ?? Self.stages.count - 1
        return i18n.t(GenerationSteps.key(for: Self.stages[min(index, Self.stages.count - 1)], hasSupports: true))
    }

    /// Le plancher de la jauge à chaque étape réelle : elle ne recule jamais derrière le travail.
    private static func floor(for stage: LessonBuilder.Stage) -> Double {
        switch stage {
        case .reading: 0.04
        case .cutting: thresholds[0]
        case .writing: thresholds[1]
        case .questions: thresholds[2]
        }
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
            let course = try await lessons.create(.onboarding(from: model.deckSetup), in: modelContext) { reached in
                stage = reached
                let floor = Self.floor(for: reached)
                if shown < floor {
                    withAnimation(.easeOut(duration: 0.3)) { shown = floor }
                }
            }
            creeping.cancel()
            built = course
            await finish(with: course)
        } catch {
            creeping.cancel()
            failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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
            let course = try OnboardingDemoCatalog.installLesson(demo, language: language, in: modelContext)
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
                        stage = nil
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

// MARK: - La leçon qu'on regarde

/// **La leçon écrite, en chemin**, avec le rond fléché qui flotte en bas à droite.
///
/// C'est le vrai parcours de la leçon — l'icône, le titre, les cercles et les paliers — tel que
/// l'app l'ouvrira : on le regarde, on n'y joue pas encore. **Le rond fait lire** : il ouvre les
/// notes du premier thème, puis passe à l'entraînement. C'est ce qui garantit qu'on a lu une
/// page de la leçon avant de s'entraîner dessus, sans forcer personne à tout lire.
struct CourseReviewStepView: View {
    @Environment(OnboardingModel.self) private var model

    @State private var reading: Chapter?
    @State private var didRead = false

    var body: some View {
        ZStack {
            if let course = model.builtCourse {
                OnboardingLessonPreview(course: course)
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
        .sheet(item: $reading) { chapter in
            OnboardingThemeReader(chapter: chapter, demo: demoChapter(for: chapter)) {
                reading = nil
                model.advance()
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .environment(\.onboardingSurface, .canvas)
    }

    /// Le rond : les notes du premier thème la première fois, la suite ensuite.
    private func advance() {
        guard !didRead, let first = model.builtCourse?.orderedChapters.first else {
            model.advance()
            return
        }
        didRead = true
        reading = first
    }

    /// Le chapitre de démonstration qui correspond, quand le cours est le cours joué :
    /// c'est lui qui porte les schémas et les graphes.
    private func demoChapter(for chapter: Chapter) -> DemoChapter? {
        guard model.isDemoCourse, let demo = model.demoCourse else { return nil }
        return demo.chapters.indices.contains(chapter.position) ? demo.chapters[chapter.position] : nil
    }
}
