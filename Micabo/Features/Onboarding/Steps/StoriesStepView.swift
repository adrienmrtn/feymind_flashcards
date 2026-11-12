import SwiftData
import SwiftUI

// MARK: - Les quatre stories

/// **Les quatre stories du premier écran** : ce que fait l'app, montré dans un aperçu du
/// produit. C'est le « story mapping » des fonctionnalités : la Home n'a plus à l'expliquer.
enum OnboardingStory: Int, CaseIterable, Identifiable {
    /// Un cours devient une leçon.
    case lesson
    /// Des quiz et des cartes.
    case quiz
    /// Un exercice pris en photo.
    case scan
    /// Le plan de révision, jusqu'à l'examen : le calendrier, la série, la concentration.
    case plan

    var id: Int { rawValue }

    /// Le rang de la page dans les statistiques : de 1 à 4.
    var index: Int { rawValue + 1 }

    var titleKey: String {
        switch self {
        case .lesson: "ios.onb10.story1"
        case .quiz: "ios.onb10.story2"
        case .scan: "ios.onb10.story3"
        case .plan: "ios.onb10.story4"
        }
    }

    /// La couleur du mot-clé : une idée, une couleur.
    var keyword: Color {
        switch self {
        case .lesson: V3Color.accentBright
        case .quiz: V3Color.green
        case .scan: V3Color.pink
        case .plan: V3Color.yellow
        }
    }

    var next: OnboardingStory? {
        OnboardingStory(rawValue: rawValue + 1)
    }
}

/// **Le premier écran : quatre stories**, qu'on passe avec « Continuer » ou en glissant. À la
/// quatrième, le bouton dit « Commencer » et entre dans le parcours.
///
/// Chaque page a un titre et un aperçu du produit, dessiné ici (pas d'image : les textes sont
/// ceux de la langue de l'élève, et l'examen de la dernière page est celui de son pays).
///
/// C'est aussi le seul écran qui porte une sortie : « J'ai déjà un compte ». C'est **la seule
/// façon de sauter le parcours** sur une installation neuve (`LaunchGate`) : une connexion
/// qui aboutit depuis ici ouvre l'app sur les cours du compte. En haut, le choix de la langue.
struct StoriesStepView: View {
    /// Pour les rendus : la page à montrer.
    var previewPage: OnboardingStory?

    @Environment(OnboardingModel.self) private var model
    @Environment(AuthController.self) private var auth
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(CloudSync.self) private var sync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    /// La page à l'écran. Le défilement l'écrit, « Continuer » aussi.
    @State private var current: OnboardingStory? = .lesson
    /// Les pages déjà comptées dans les statistiques : une fois chacune.
    @State private var seen: Set<OnboardingStory> = []

    @State private var showsLogin = false
    /// Vrai une fois « J'ai déjà un compte » touché : une connexion qui aboutit ensuite ouvre
    /// l'app au lieu de continuer le parcours.
    @State private var wantsExistingAccount = false
    @State private var isCheckingAccount = false

    private var story: OnboardingStory {
        previewPage ?? current ?? .lesson
    }

    /// L'examen de la dernière page : celui que tout le monde connaît dans le pays détecté
    /// (il suit la langue choisie en haut de l'écran) ; ailleurs, un contrôle.
    private var examName: String {
        let region = model.country == .other ? model.regionCode : SchoolingCountry.guessed().regionCode
        return Self.flagshipExam(region: region) ?? i18n.t("ios.onb5.exam.testName")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            pages
            dots
                .padding(.top, 6)
            footer
        }
        .background(V3Color.bg.ignoresSafeArea())
        .sheet(isPresented: $showsLogin) {
            loginSheet
        }
        .onChange(of: auth.completedSignIns) { _, _ in
            guard wantsExistingAccount else { return }
            Task { await resolveLogin() }
        }
        .onChange(of: current, initial: true) { _, page in
            note(page)
        }
    }

    // MARK: Le haut

    /// Le choix de la langue, en haut à droite : la langue de l'app (`UiLocaleStore`), dans
    /// une puce du système visuel. Un rendu ne dessine pas un menu du système : il montre la
    /// puce seule.
    private var header: some View {
        HStack {
            Spacer(minLength: 0)
            if still || previewPage != nil {
                languageChip
            } else {
                Menu {
                    ForEach(UiLocale.allCases) { code in
                        Button {
                            i18n?.pick(code)
                        } label: {
                            if code == i18n.locale {
                                Label(code.nativeName, systemImage: "checkmark")
                            } else {
                                Text(verbatim: "\(code.flag)  \(code.nativeName)")
                            }
                        }
                    }
                } label: {
                    languageChip
                }
                .accessibilityLabel(Text(i18n.t("ios.appLanguage")))
                .accessibilityValue(Text(verbatim: i18n.locale.nativeName))
            }
        }
        .padding(.horizontal, OnbLayout.margin)
        .frame(minHeight: 44)
    }

    /// La langue choisie : son drapeau, son nom, un chevron.
    private var languageChip: some View {
        HStack(spacing: 7) {
            Text(verbatim: i18n.locale.flag)
                .font(V3Font.label)
                .accessibilityHidden(true)
            Text(verbatim: i18n.locale.nativeName)
                .font(V3Font.label)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(V3Font.caption)
        }
        .foregroundStyle(V3Color.ink2)
        .padding(.horizontal, 14)
        .frame(minHeight: V3Metric.chipHeight - 8)
        .modifier(V3SurfaceStyle(radius: (V3Metric.chipHeight - 8) / 2))
    }

    // MARK: Les pages

    /// Les quatre pages, côte à côte : on glisse de l'une à l'autre, page par page. Les rendus
    /// n'en posent qu'une.
    @ViewBuilder
    private var pages: some View {
        if still || previewPage != nil {
            StoryPage(story: story, exam: examName)
        } else {
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(OnboardingStory.allCases) { story in
                        StoryPage(story: story, exam: examName)
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(story)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
        }
    }

    /// Les quatre points : celui de la page à l'écran est plein.
    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(OnboardingStory.allCases) { page in
                Circle()
                    .fill(page == story ? V3Color.ink : V3Color.ink3)
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement()
        .accessibilityValue(Text(verbatim: "\(story.index)/\(OnboardingStory.allCases.count)"))
    }

    // MARK: Le pied

    private var footer: some View {
        VStack(spacing: 10) {
            V3Button(i18n.t(story.next == nil ? "ios.onb10.story.start" : "common.continue")) {
                advance()
            }
            V3Button(i18n.t("common.alreadyAccount"), kind: .secondary, isEnabled: !auth.isWorking && !isCheckingAccount) {
                wantsExistingAccount = true
                showsLogin = true
            }
        }
        .padding(.horizontal, OnbLayout.margin)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    /// « Continuer » : la page suivante ; à la dernière, le parcours.
    private func advance() {
        guard let next = story.next else {
            model.adoptDetectedCountry()
            model.advance()
            return
        }
        withAnimation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion)) {
            current = next
        }
    }

    /// Compte la page dans les statistiques, une fois.
    private func note(_ page: OnboardingStory?) {
        guard !still, previewPage == nil, let page, seen.insert(page).inserted else { return }
        Analytics.track(.onboardingStoryViewed, ["index": .number(Double(page.index))])
    }

    // MARK: « J'ai déjà un compte »

    private var loginSheet: some View {
        SignInScreen(
            placement: .sheet,
            onDismiss: { showsLogin = false },
            onCreateAccount: {
                wantsExistingAccount = false
                showsLogin = false
                model.adoptDetectedCountry()
                model.advance()
            },
            isResolving: isCheckingAccount
        )
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(V3Color.bg)
        .interactiveDismissDisabled(auth.isWorking || isCheckingAccount)
    }

    /// **« J'ai déjà un compte », et la connexion a abouti** : le profil du compte remplace
    /// le parcours, le parcours est marqué fini sur cette installation, et l'app s'ouvre sur
    /// les cours du compte, synchronisés.
    ///
    /// La connexion se guette par `completedSignIns` et non par `isSignedIn` : une session
    /// restée dans le trousseau depuis l'installation précédente est déjà ouverte, et se
    /// reconnecter au même compte ne ferait pas changer `isSignedIn`.
    @MainActor
    private func resolveLogin() async {
        guard !isCheckingAccount else { return }
        let route = LaunchGate.route(
            installMarked: LaunchGate.isInstallMarked(),
            onboardingDoneLocally: OnboardingPreferences.isCompleted,
            hasSession: auth.isSignedIn,
            tappedHaveAccount: wantsExistingAccount
        )
        guard route == .home else { return }
        isCheckingAccount = true
        _ = await sync.recognizeExistingAccount()
        OnboardingPreferences.markCompleted()
        isCheckingAccount = false
        wantsExistingAccount = false
        showsLogin = false
        await sync.sync(context: modelContext)
    }

    // MARK: L'examen du pays

    /// **L'examen que tout le monde connaît dans un pays** : celui de la dernière année de
    /// son lycée (le Bac, l'Abitur, la PAU, le SAT…), tel qu'il se nomme là-bas. Rien quand
    /// le pays n'est pas décrit : on ne lui invente pas d'examen.
    static func flagshipExam(region: String?) -> String? {
        let tracks = SchoolSystem.tracks(region: region)
        let ordered = tracks.filter { $0.tier == .upperSecondary } + tracks.filter { $0.tier != .upperSecondary }
        for track in ordered {
            let ids = track.years.last?.exams.nilIfEmpty ?? track.exams
            if let exam = ids.lazy.compactMap({ SchoolExams.catalog[$0] }).first {
                return exam.title
            }
        }
        return nil
    }
}

// MARK: - Une page

/// **Une story** : son titre, centré, et son aperçu du produit dans un cadre « haut de
/// téléphone » que le bas de la page coupe.
struct StoryPage: View {
    let story: OnboardingStory
    /// L'examen affiché sur la dernière page.
    let exam: String

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(spacing: 0) {
            OnbTitle(i18n.t(story.titleKey), size: OnbLayout.display, alignment: .center, keyword: story.keyword)
                .padding(.top, 14)
                .layoutPriority(1)

            StoryPhoneFrame {
                switch story {
                case .lesson: StoryLessonPreview()
                case .quiz: StoryQuizPreview()
                case .scan: StoryScanPreview()
                case .plan: StoryPlanPreview(exam: exam)
                }
            }
            .padding(.top, 26)
            // Un aperçu du produit est une illustration (VoiceOver ne le lit pas) : il garde
            // ses proportions en très grand texte, où le titre seul grossit.
            .dynamicTypeSize(.large)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, OnbLayout.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// **Le cadre « haut de téléphone »** : une surface qui se fond dans la page, des coins
/// arrondis en haut, un filet ; le bas se dissout, et coupe ce qui dépasse.
private struct StoryPhoneFrame<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// Le rayon des coins du haut : celui d'un téléphone.
    private static var radius: CGFloat { 34 }

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: Self.radius, topTrailingRadius: Self.radius, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            content
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
        // L'aperçu garde sa hauteur naturelle : sur un petit écran, le cadre le coupe par le
        // bas au lieu de le tasser.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            LinearGradient(colors: [V3Color.surface, V3Color.bg], startPoint: .top, endPoint: .bottom),
            in: shape
        )
        .overlay {
            shape.strokeBorder(V3Color.line, lineWidth: 2)
        }
        .clipShape(shape)
        .mask {
            LinearGradient(
                stops: [.init(color: .black, location: 0.72), .init(color: .clear, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Les aperçus

/// Une tuile d'aperçu : la surface haute de l'app, posée dans le cadre.
private struct StoryTile: ViewModifier {
    var radius: CGFloat = V3Metric.radiusInner

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(V3Color.soft, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// Une pastille dans un ton : son lavis, son texte.
private struct StoryTag: View {
    let text: String
    let tone: Color

    var body: some View {
        Text(text)
            .font(V3Font.caption)
            .fontWeight(.bold)
            .foregroundStyle(tone)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(V3Color.wash(of: tone), in: Capsule())
    }
}

/// **Page 1** : « Photo de mon cours », puis la leçon qui en sort, avec sa jauge et ses trois
/// modes.
private struct StoryLessonPreview: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(V3Color.accentBright)
            Text(i18n.t("ios.onb10.story.photo"))
                .foregroundStyle(V3Color.ink)
        }
        .font(V3Font.label)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .trailing)

        VStack(alignment: .leading, spacing: 0) {
            Text(i18n.t("ios.onb.sample.title"))
                .font(V3Font.display(22))
                .foregroundStyle(V3Color.ink)
            V3ProgressBar(value: 0.4)
                .padding(.top, 10)
                .padding(.bottom, 14)
            HStack(spacing: 8) {
                StoryTag(text: i18n.t("lesson.nav.notes"), tone: V3Color.accentBright)
                StoryTag(text: i18n.t("lesson.nav.quiz"), tone: V3Color.green)
                StoryTag(text: i18n.t("lesson.nav.flashcards"), tone: V3Color.lilac)
            }
        }
        .padding(16)
        .modifier(StoryTile())
    }
}

/// **Page 2** : une question, trois réponses, la bonne en vert.
private struct StoryQuizPreview: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        Text(i18n.t("ios.onb.mika.design.question"))
            .font(V3Font.display(22))
            .foregroundStyle(V3Color.ink)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 8) {
            answer("1961", isRight: false)
            answer("1989", isRight: true)
            answer("1991", isRight: false)
        }
    }

    private func answer(_ text: String, isRight: Bool) -> some View {
        HStack(spacing: 10) {
            Text(verbatim: text)
                .font(V3Font.option)
                .monospacedDigit()
                .foregroundStyle(V3Color.ink)
            Spacer(minLength: 0)
            if isRight {
                Image(systemName: "checkmark.circle.fill")
                    .font(V3Font.option)
                    .foregroundStyle(V3Color.green)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 48)
        .modifier(V3SurfaceStyle(
            radius: V3Metric.radiusTile,
            fill: isRight ? V3Color.wash(of: V3Color.green) : V3Color.soft,
            border: isRight ? V3Color.green : V3Color.line
        ))
    }
}

/// **Page 3** : un énoncé dans un cadre de visée, puis ses étapes, jusqu'au résultat.
private struct StoryScanPreview: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        // Une équation s'écrit de gauche à droite, dans toutes les langues.
        Text(verbatim: "2x² − 8x + 6 = 0")
            .font(V3Font.display(26))
            .foregroundStyle(V3Color.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .environment(\.layoutDirection, .leftToRight)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .padding(.horizontal, 20)
            .overlay {
                StoryViewfinder()
                    .stroke(V3Color.pink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .padding(8)
            }
            .modifier(StoryTile())

        VStack(alignment: .leading, spacing: 12) {
            step("1", i18n.t("ios.onb10.story.step1"))
            step("2", i18n.t("ios.onb10.story.step2"))
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(V3Font.title)
                    .foregroundStyle(V3Color.green)
                    .frame(width: 26)
                Text(i18n.t("ios.onb10.story.result"))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.green)
            }
        }
        .padding(16)
        .modifier(StoryTile())
    }

    private func step(_ number: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: number)
                .font(V3Font.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .foregroundStyle(V3Color.onAccent)
                .frame(width: 26, height: 26)
                .background(V3Color.accent, in: Circle())
            Text(text)
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Les quatre coins d'un cadre de visée.
private struct StoryViewfinder: Shape {
    var arm: CGFloat = 18
    var radius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners: [(corner: CGPoint, horizontal: CGFloat, vertical: CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, horizontal, vertical) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + vertical * arm))
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + vertical * radius))
            path.addQuadCurve(to: CGPoint(x: corner.x + horizontal * radius, y: corner.y), control: corner)
            path.addLine(to: CGPoint(x: corner.x + horizontal * arm, y: corner.y))
        }
        return path
    }
}

/// **Page 4** : le système de Micabo. Le prochain examen et son compte à rebours (le
/// calendrier), la semaine à flammes (la série), une séance de concentration.
private struct StoryPlanPreview: View {
    let exam: String

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Les jours avant l'examen de l'aperçu.
    static let daysLeft = 12
    /// Les jours tenus de la semaine de l'aperçu : quatre sur sept.
    static let daysDone = 4
    /// La durée d'une séance de concentration, en minutes.
    static let focusMinutes = 25

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(i18n.t("ios.cal.nextExam"))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                Text(exam)
                    .font(V3Font.display(22))
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(OnbWords.duration(days: Self.daysLeft, locale: i18n.locale))
                .font(V3Font.label)
                .foregroundStyle(V3Color.yellowInk)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(V3Color.yellowWash, in: Capsule())
        }
        .padding(16)
        .modifier(StoryTile())

        V3WeekStrip(days: Self.week(locale: i18n.locale))
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .modifier(StoryTile())

        HStack(spacing: 8) {
            Image(systemName: "timer")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(V3Color.accentBright)
            Text(i18n.t("ios.onb10.story.focus", [
                "time": i18n.t("ios.quiz.time.short", ["n": "\(Self.focusMinutes)"]),
            ]))
            .foregroundStyle(V3Color.ink)
        }
        .font(V3Font.label)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(V3Color.soft, in: Capsule())
    }

    /// **La semaine de l'aperçu**, du lundi au dimanche comme le Calendrier, avec les initiales
    /// de la langue de l'élève : quatre jours tenus, aujourd'hui, et l'examen au bout.
    static func week(locale: UiLocale) -> [V3WeekDay] {
        let letters = MicaboCalendar.weekdayInitials(locale: locale)
        return (0..<7).map { offset in
            V3WeekDay(
                letter: offset < letters.count ? letters[offset] : "",
                number: 9 + offset,
                isDone: offset < daysDone,
                isToday: offset == daysDone,
                hasEvent: offset == 6
            )
        }
    }
}
