import SwiftData
import SwiftUI
import XCTest
@testable import Micabo

/// **Les trois écritures nouvelles du lot 13, sur un vrai iPhone** : l'hébreu (de droite à
/// gauche), le japonais et le coréen, que la police des titres n'écrit pas.
///
/// Six écrans représentatifs — la Home, le parcours d'accueil, le paywall, la leçon, le
/// calendrier, le choix de la langue — dans la fenêtre aux marges de l'iPhone 15 Pro
/// (`RenderGallery.renderDevice`), et une planche typographique qui écrit des titres, une bulle
/// de Mika et des boutons **dans l'écriture même**, quel que soit l'état des catalogues (copie
/// anglaise tant que les traducteurs n'ont pas fini) : c'est elle qui montre le repli de police
/// (pas de cases vides, pas de Regular au milieu d'un titre Black), l'interligne et les coupures.
@MainActor
final class Lot13LanguagesRenderTests: XCTestCase {
    private static var shared: PerfFixture?
    private var fixture: PerfFixture!
    private var savedDefaults: [String: Any]?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        executionTimeAllowance = 300
        if let domain = Bundle.main.bundleIdentifier {
            savedDefaults = UserDefaults.standard.persistentDomain(forName: domain)
        }
        UserDefaults.standard.set(true, forKey: SampleContentPurge.key)
        UserDefaults.standard.set(true, forKey: SubjectCasePass.key)
        UserDefaults.standard.set(true, forKey: CalendarDefaults.seededKey)
        UserDefaults.standard.set(true, forKey: StudyStreak.Key.adoptedReviews)
        FontLoader.registerFonts()
        if Self.shared == nil { Self.shared = try PerfFixture() }
        fixture = Self.shared
    }

    override func tearDownWithError() throws {
        if let domain = Bundle.main.bundleIdentifier, RenderGallery.directory != nil {
            UserDefaults.standard.setPersistentDomain(savedDefaults ?? [:], forName: domain)
        }
    }

    private static let locales: [UiLocale] = [.he, .ja, .ko]

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    /// L'écran dans l'environnement de l'app, dans le sens de lecture de la langue (ce que fait
    /// `MicaboApp`).
    private func render<V: View>(
        _ name: String,
        _ locale: UiLocale,
        devices: [RenderDevice] = [.iPhone15Pro],
        env given: PerfEnvironment? = nil,
        _ view: V
    ) throws {
        let env = given ?? PerfEnvironment()
        try RenderGallery.renderDevice(
            "l13-\(locale.rawValue)-\(name)",
            devices: devices,
            env.wrap(view, container: fixture.container)
                .environment(\.layoutDirection, locale.isRightToLeft ? .rightToLeft : .leftToRight)
                .environment(\.locale, locale.foundation)
        )
    }

    // MARK: - La planche typographique

    func testScriptSpecimen() throws {
        for locale in [UiLocale.fr] + Self.locales {
            use(locale)
            try render("specimen", locale, devices: [.iPhone15Pro, .iPhoneSE], ScriptSpecimen(sample: .sample(for: locale)))
        }
    }

    // MARK: - Les six écrans

    func testHomeAndCalendar() throws {
        for locale in Self.locales {
            use(locale)
            let env = PerfEnvironment()
            for (tab, name) in [(RootTab.today, "home"), (.calendar, "calendrier")] {
                let router = env.router
                router.selection = tab
                try render(name, locale, env: env, RootTabView(router: router))
            }
        }
    }

    func testLesson() throws {
        var descriptor = FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.createdAt, order: .reverse)])
        descriptor.fetchLimit = 1
        let course = try XCTUnwrap(try fixture.context.fetch(descriptor).first)
        for locale in Self.locales {
            use(locale)
            try render("lecon", locale, NavigationStack { LessonPathView(course: course) })
        }
    }

    func testLanguageSettings() throws {
        for locale in Self.locales {
            use(locale)
            try render("langues", locale, LanguagePickerPage(locale: locale))
            try render("reglages", locale, SettingsView())
        }
    }

    func testOnboarding() throws {
        defer { OnboardingPreferences.reset() }
        for locale in Self.locales {
            use(locale)
            OnboardingPreferences.reset()
            let model = OnboardingModel()
            model.displayName = ScriptSample.sample(for: locale).name
            for (step, name) in [(OnboardingStep.welcome, "accueil"), (.goal, "objectif")] {
                model.place(on: step)
                try render("onb-\(name)", locale, OnboardingLivePage(step: step, model: model))
            }
        }
    }

    func testPaywall() throws {
        let saved = PriceDisplay.forced(in: .standard)
        PriceDisplay.setOverride(.weekly)
        defer {
            PriceDisplay.setOverride(saved)
            PaywallStorePrices.clear()
        }
        let now = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)) ?? Date()
        let examDay = Calendar.current.date(from: DateComponents(year: 2027, month: 6, day: 15)) ?? Date()
        for locale in Self.locales {
            use(locale)
            let sample = ScriptSample.sample(for: locale)
            let context = PaywallContext(
                profile: PaywallProfile(firstName: sample.name, examName: sample.exam, examID: nil, examDate: examDay, subjects: ["Mathématiques", "Physique"]),
                now: now,
                reminderKept: true,
                topic: sample.topic
            )
            try render("paywall", locale, PaywallScreen(
                trigger: nil,
                name: sample.name,
                isPurchasing: false,
                onClose: {},
                onSubscribe: { _ in },
                onRestore: {},
                prices: .ready,
                notice: nil,
                context: context
            ).environment(\.mikaStill, true))
        }
    }
}

/// Des phrases écrites dans chaque écriture, pour juger la police sans attendre les catalogues.
struct ScriptSample {
    let title: String
    let keyword: String
    let long: String
    let mika: String
    let button: String
    let secondary: String
    let name: String
    let exam: String
    let topic: String

    static func sample(for locale: UiLocale) -> ScriptSample {
        switch locale {
        case .ja:
            ScriptSample(
                title: "今日の復習を始めよう", keyword: "復習",
                long: "試験までに覚えることを、毎日少しずつ一緒に整理しよう",
                mika: "こんにちは、Mikaだよ。今日はどの科目を勉強する？",
                button: "続ける", secondary: "あとで", name: "さくら", exam: "大学入学共通テスト", topic: "冷戦"
            )
        case .ko:
            ScriptSample(
                title: "오늘의 복습을 시작해요", keyword: "복습",
                long: "시험 전까지 외울 내용을 매일 조금씩 함께 정리해요",
                mika: "안녕, 나는 Mika야. 오늘은 어떤 과목을 공부할까?",
                button: "계속하기", secondary: "나중에", name: "지우", exam: "대학수학능력시험", topic: "냉전"
            )
        case .he:
            ScriptSample(
                title: "בוא נתחיל את החזרה של היום", keyword: "החזרה",
                long: "נארגן יחד, קצת בכל יום, את כל מה שצריך לזכור לפני המבחן",
                mika: "היי, אני Mika. איזה מקצוע לומדים היום?",
                button: "המשך", secondary: "אחר כך", name: "נועה", exam: "בגרות", topic: "המלחמה הקרה"
            )
        default:
            ScriptSample(
                title: "Commence ta révision du jour", keyword: "révision",
                long: "Range avec moi, un peu chaque jour, tout ce qu'il faut retenir avant l'examen",
                mika: "Salut, moi c'est Mika. On révise quelle matière aujourd'hui ?",
                button: "Continuer", secondary: "Plus tard", name: "Lina", exam: "Bac", topic: "La guerre froide"
            )
        }
    }
}

/// La planche : les jetons de titre de l'app, du plus grand au bouton, dans l'écriture voulue.
struct ScriptSpecimen: View {
    let sample: ScriptSample

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                V3Title(sample.title, highlight: sample.keyword, size: 40)
                V3Title(sample.long, size: 32)
                V3Title(sample.long, highlight: sample.keyword, size: 25)
                MikaAsk(sample.mika, highlight: "Mika")
                Text(sample.title)
                    .font(V3Font.cardTitle)
                    .foregroundStyle(V3Color.ink)
                Text(sample.long)
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                V3Button(sample.button) {}
                V3Button(sample.secondary, kind: .secondary) {}
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .environment(\.mikaStill, true)
        .background(V3Color.bg.ignoresSafeArea())
    }
}

/// Le choix de la langue tel que les réglages le montrent : les trente-deux drapeaux.
struct LanguagePickerPage: View {
    let locale: UiLocale

    var body: some View {
        ScrollView {
            LanguageSwitcher(variant: .card)
                .padding(.horizontal, 20)
                .padding(.top, 12)
        }
        .environment(UiLocaleStore(locale: locale))
        .background(V3Color.bg.ignoresSafeArea())
    }
}
