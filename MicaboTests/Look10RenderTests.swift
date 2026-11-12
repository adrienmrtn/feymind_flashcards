import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Lot 10 : la direction artistique V3.3, « marine, net, adulte ».** Le marine par défaut, une
/// pilule blanche pour l'action principale, le bleu clair pour le mot-clé, le jaune pour « PRO »
/// et l'offre, des surfaces à filet sans lèvre ni ombre, Sofia Sans Condensed pour les titres et
/// la police système pour le reste. Les valeurs sont celles des maquettes (`mock11/base.css`),
/// écrites en un seul endroit (`V3Palette`, `V3Metric`, `V3Font`).
@MainActor
final class Look10Tests: XCTestCase {
    private func hex(_ color: Color, night: Bool = true) -> String {
        let traits = UITraitCollection(userInterfaceStyle: night ? .dark : .light)
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X",
            Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded())
        )
    }

    /// Le marine : les jetons de `base.css`, au chiffre près.
    func testTheNavyTokensAreTheMockupValues() {
        XCTAssertEqual(hex(V3Color.bg), "0B0F1C")
        XCTAssertEqual(hex(V3Color.surface), "171C2C")
        XCTAssertEqual(hex(V3Color.soft), "20263A")
        XCTAssertEqual(hex(V3Color.line), "262D42")
        XCTAssertEqual(hex(V3Color.ink), "F5F6FB")
        XCTAssertEqual(hex(V3Color.ink2), "A9B1C6")
        XCTAssertEqual(hex(V3Color.ink3), "6E7791")
        XCTAssertEqual(hex(V3Color.accent), "5C88FF")
        XCTAssertEqual(hex(V3Color.accentBright), "7FA2FF")
        XCTAssertEqual(hex(V3Color.accentWash), "18224A")
        XCTAssertEqual(hex(V3Color.yellow), "F7B41F")
        XCTAssertEqual(hex(V3Color.yellowWash), "2B2412")
        XCTAssertEqual(hex(V3Color.green), "34D399")
        XCTAssertEqual(hex(V3Color.greenWash), "0F2E26")
        XCTAssertEqual(hex(V3Color.red), "F87171")
        XCTAssertEqual(hex(V3Color.redWash), "3A1820")
        XCTAssertEqual(hex(V3Color.pink), "FF8FA8")
        XCTAssertEqual(hex(V3Color.lilac), "A78BFA")
        XCTAssertEqual(hex(V3Color.orange), "FB923C")
    }

    /// Le clair est une option : un fond teinté — jamais de blanc pur en fond de page —, des
    /// surfaces blanches, et une encre jaune assombrie pour rester lisible en texte.
    func testTheLightThemeIsTintedNeverPureWhite() {
        XCTAssertEqual(hex(V3Color.bg, night: false), "EEF1F8")
        XCTAssertNotEqual(hex(V3Color.bg, night: false), "FFFFFF")
        XCTAssertEqual(hex(V3Color.surface, night: false), "FFFFFF")
        XCTAssertEqual(hex(V3Color.line, night: false), "DCE1EC")
        XCTAssertEqual(hex(V3Color.ink, night: false), "0F1324")
        XCTAssertEqual(hex(V3Color.ink2, night: false), "566078")
        XCTAssertEqual(hex(V3Color.ink3, night: false), "97A0B4")
        XCTAssertEqual(hex(V3Color.accent, night: false), "3870FE")
        XCTAssertEqual(hex(V3Color.accentWash, night: false), "E4ECFF")
        XCTAssertEqual(hex(V3Color.yellow, night: false), "F7B41F", "le jaune est un aplat : le même dans les deux thèmes")
        XCTAssertEqual(hex(V3Color.yellowWash, night: false), "FFF4D6")
        XCTAssertNotEqual(hex(V3Color.yellowInk, night: false), hex(V3Color.yellow, night: false), "du texte jaune sur son lavis clair doit s'assombrir")
    }

    /// Les sept teintes d'icône : une couleur par idée.
    func testTheSevenIconTints() {
        XCTAssertEqual(hex(V3Color.iconBlue), "60A5FA")
        XCTAssertEqual(hex(V3Color.iconPink), "F472B6")
        XCTAssertEqual(hex(V3Color.iconGreen), "34D399")
        XCTAssertEqual(hex(V3Color.iconYellow), "FBBF24")
        XCTAssertEqual(hex(V3Color.iconLilac), "A78BFA")
        XCTAssertEqual(hex(V3Color.iconOrange), "FB923C")
        XCTAssertEqual(hex(V3Color.iconRed), "F87171")
        XCTAssertEqual(hex(MicaboIcon.flame.tint), "FB923C", "la flamme est orange")
        XCTAssertEqual(hex(MicaboIcon.pdf.tint), "F87171", "le PDF est rouge")
        XCTAssertEqual(hex(MicaboIcon.cards.tint), "34D399", "les cartes sont vertes")
        XCTAssertEqual(hex(MicaboIcon.quiz.tint), "F472B6", "le quiz est rose")
        XCTAssertEqual(hex(MicaboIcon.notes.tint), "60A5FA", "les notes sont bleues")
    }

    /// Le bouton principal est une pilule blanche au texte marine sur le marine, une pilule
    /// encre au texte blanc sur le clair ; les anciens noms du bouton et du jaune restent des
    /// alias, et l'offre a son propre bouton, jaune.
    func testTheMainButtonIsAWhitePill() {
        XCTAssertEqual(hex(V3Color.cta), "FFFFFF")
        XCTAssertEqual(hex(V3Color.ctaLip), "BFC6D9")
        XCTAssertEqual(hex(V3Color.ctaInk), "0B0F1C")
        XCTAssertEqual(hex(V3Color.cta, night: false), "0F1324")
        XCTAssertEqual(hex(V3Color.ctaInk, night: false), "FFFFFF")
        XCTAssertEqual(V3ButtonKind.accent, .primary)
        XCTAssertEqual(V3ButtonKind.white, .primary)
        XCTAssertEqual(V3ButtonKind.ink, .primary)
        XCTAssertNotEqual(V3ButtonKind.offer, .primary)
        XCTAssertEqual(hex(V3Color.pencil), hex(V3Color.yellow))
        XCTAssertEqual(hex(V3Color.pencilWash), hex(V3Color.yellowWash))
        XCTAssertEqual(hex(V3Color.accentHi), hex(V3Color.accentBright))
    }

    /// **Une seule source** : les jetons d'avant le lot 10 (`MicaboColor`) valent ceux de la
    /// direction artistique, dans les deux apparences. Changer `V3Palette` change toute l'app.
    func testTheOldTokensAreTheNewOnes() {
        let pairs: [(Color, Color, String)] = [
            (MicaboColor.canvas, V3Color.bg, "canvas"),
            (MicaboColor.surface, V3Color.surface, "surface"),
            (MicaboColor.surfaceMuted, V3Color.soft, "surfaceMuted"),
            (MicaboColor.stroke, V3Color.line, "stroke"),
            (MicaboColor.edge, V3Color.line, "edge"),
            (MicaboColor.ink, V3Color.ink, "ink"),
            (MicaboColor.inkSecondary, V3Color.ink2, "inkSecondary"),
            (MicaboColor.inkTertiary, V3Color.ink3, "inkTertiary"),
            (MicaboColor.accent, V3Color.accent, "accent"),
            (MicaboColor.accentDeep, V3Color.accentDeep, "accentDeep"),
            (MicaboColor.accentWash, V3Color.accentWash, "accentWash"),
            (MicaboColor.correct, V3Color.green, "correct"),
            (MicaboColor.correctSoft, V3Color.greenWash, "correctSoft"),
            (MicaboColor.wrong, V3Color.red, "wrong"),
            (MicaboColor.wrongSoft, V3Color.redWash, "wrongSoft"),
            (MicaboColor.flame, V3Color.orange, "flame"),
            (MicaboColor.cautionVivid, V3Color.yellow, "cautionVivid"),
        ]
        for (old, new, name) in pairs {
            XCTAssertEqual(hex(old), hex(new), "\(name), marine")
            XCTAssertEqual(hex(old, night: false), hex(new, night: false), "\(name), clair")
        }
        XCTAssertEqual(MicaboRadius.card, V3Metric.radiusCard)
        XCTAssertEqual(MicaboRadius.lg, V3Metric.radiusInner)
        XCTAssertEqual(MicaboSurface.border, V3Metric.border)
        XCTAssertEqual(MicaboButtonMetrics.height, V3Metric.buttonHeight)
        XCTAssertEqual(MicaboButtonMetrics.radius, V3Metric.radiusButton)
    }

    /// Une surface « dans un ton » accepte le lavis comme le plein : le lavis reste tel quel, le
    /// plein est délayé ; et le filet est toujours un cran plus soutenu que le fond.
    func testAToneGivesAWashAndAnEdge() {
        XCTAssertEqual(hex(V3Color.wash(of: V3Color.greenWash)), "0F2E26")
        XCTAssertEqual(hex(V3Color.wash(of: V3Color.greenWash), night: false), "DDF7EA")
        XCTAssertNotEqual(hex(V3Color.wash(of: V3Color.green)), "34D399")
        for tone in [V3Color.greenWash, V3Color.green, V3Color.yellowWash, V3Color.red, V3Color.accentWash, V3Color.lilac] {
            XCTAssertNotEqual(hex(V3Color.edge(of: tone)), hex(V3Color.wash(of: tone)))
            XCTAssertNotEqual(hex(V3Color.edge(of: tone), night: false), hex(V3Color.wash(of: tone), night: false))
        }
    }

    /// Les mesures des maquettes : bouton de 56 pt en pilule, lèvre de 4 ; ligne de 58, rayon
    /// 16 ; carte de rayon 22 ; filet de 1,5 ; puce de 44 ; jauge de 8 ; marges de 20. La seule
    /// lèvre de l'app est celle des boutons pleins.
    func testTheMetricsAreTheMockupValues() {
        XCTAssertEqual(V3Metric.buttonHeight, 56)
        XCTAssertGreaterThanOrEqual(V3Metric.radiusButton, V3Metric.buttonHeight / 2, "une pilule")
        XCTAssertEqual(V3Metric.buttonLip, 4)
        XCTAssertEqual(V3Metric.lip, 0)
        XCTAssertEqual(V3Metric.border, 1.5)
        XCTAssertEqual(V3Metric.optionHeight, 58)
        XCTAssertEqual(V3Metric.radiusInner, 16)
        XCTAssertEqual(V3Metric.radiusCard, 22)
        XCTAssertEqual(V3Metric.radiusBubble, 20)
        XCTAssertEqual(V3Metric.chipHeight, 44)
        XCTAssertEqual(V3Metric.progressHeight, 8)
        XCTAssertEqual(V3Metric.screenMargin, 20)
    }

    /// **L'ancienne échelle se répartit entre les deux familles** : un titre (19 points et plus,
    /// en gras) est un titre ; le reste est du texte, au style système le plus proche — jamais
    /// plus petit qu'avant à l'œil, jamais en Black.
    func testTheOldScaleSplitsBetweenTheTwoFamilies() {
        XCTAssertTrue(V3LegacyScale.isTitle(size: 22, weight: .bold))
        XCTAssertTrue(V3LegacyScale.isTitle(size: 19, weight: .heavy))
        XCTAssertFalse(V3LegacyScale.isTitle(size: 17, weight: .black), "17 points : un libellé, pas un titre")
        XCTAssertFalse(V3LegacyScale.isTitle(size: 24, weight: .regular), "un grand texte léger n'est pas un titre")
        XCTAssertEqual(V3LegacyScale.titleWeight(.bold), .black)
        XCTAssertEqual(V3LegacyScale.titleWeight(.semibold), .heavy)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 11), .caption2)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 12), .caption)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 13), .footnote)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 14), .subheadline)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 15), .subheadline)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 16), .callout)
        XCTAssertEqual(V3LegacyScale.textStyle(for: 17), .body)
        XCTAssertEqual(V3LegacyScale.textWeight(.regular), .medium)
        XCTAssertEqual(V3LegacyScale.textWeight(.bold), .bold)
        XCTAssertEqual(V3LegacyScale.textWeight(.black), .heavy)
        XCTAssertEqual(V3LegacyScale.readingWeight(.regular), .regular, "un texte long garde son Regular")
    }
}

/// La planche des composants de la direction artistique : marine, clair, arabe, allemand en très
/// grand texte sur 375 pt.
@MainActor
final class Look10RenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    /// Les phrases de la planche : un spécimen, pas des écrans — elles ne vivent qu'ici.
    private struct Words {
        var question: String
        var keyword: String
        var reaction: String
        var reactionKeyword: String
        var options: [String]
        var support: String
        var chips: [String]
        var cardTitle: String
        var cardBody: String
        var praise: String
        var praiseSub: String
        var primary: String
        var secondary: String
        var later: String
        var offer: String
        var upgrade: String
        var pageTitle: String
        var pageKeyword: String
        var pageSub: String
        var week: [String]

        static let fr = Words(
            question: "Ton objectif n°1 cette année ?",
            keyword: "objectif n°1",
            reaction: "Bonsoir Léa ! 30 min sur la guerre froide, on y va ?",
            reactionKeyword: "la guerre froide",
            options: ["Avoir de meilleures notes", "Entrer dans la formation de mes rêves", "Vraiment comprendre mes cours", "Réviser plus vite"],
            support: "Je règle ton plan dessus",
            chips: ["Focus 25 min", "Scanner un exo", "Quiz éclair"],
            cardTitle: "Flashcards au bon moment",
            cardBody: "Je te les ressors juste avant que tu oublies.",
            praise: "+4 points : ambitieux, et faisable",
            praiseSub: "12/20 → 16/20 d'ici le 15 juin",
            primary: "Continuer",
            secondary: "J'ai déjà un compte",
            later: "Plus tard",
            offer: "Profiter de −30 %",
            upgrade: "Passer en",
            pageTitle: "Ton cours devient une leçon. En 30 secondes.",
            pageKeyword: "leçon",
            pageSub: "Je révise avec toi, tous les jours.",
            week: ["L", "M", "M", "J", "V", "S", "D"]
        )

        static let de = Words(
            question: "Was ist dein wichtigstes Ziel in diesem Schuljahr?",
            keyword: "wichtigstes Ziel",
            reaction: "Guten Abend, Lea! 30 Minuten Kalter Krieg, legen wir los?",
            reactionKeyword: "Kalter Krieg",
            options: ["Bessere Noten schreiben", "Meinen Wunschstudienplatz bekommen", "Den Unterrichtsstoff wirklich verstehen", "Schneller wiederholen"],
            support: "Danach richte ich deinen Lernplan aus",
            chips: ["Fokus 25 Min.", "Aufgabe scannen", "Blitzquiz"],
            cardTitle: "Karteikarten im richtigen Moment",
            cardBody: "Ich zeige sie dir wieder, kurz bevor du sie vergisst.",
            praise: "+4 Punkte: ehrgeizig und machbar",
            praiseSub: "Von 3,0 auf 2,0 bis zum 15. Juni",
            primary: "Weiter",
            secondary: "Ich habe schon ein Konto",
            later: "Später",
            offer: "−30 % sichern",
            upgrade: "Jetzt zu",
            pageTitle: "Aus deinen Unterlagen wird eine Lektion. In 30 Sekunden.",
            pageKeyword: "Lektion",
            pageSub: "Ich wiederhole jeden Tag mit dir.",
            week: ["M", "D", "M", "D", "F", "S", "S"]
        )

        static let ar = Words(
            question: "ما هدفك الأول هذا العام؟",
            keyword: "هدفك الأول",
            reaction: "مساء الخير يا ليا! ٣٠ دقيقة عن الحرب الباردة، هل نبدأ؟",
            reactionKeyword: "الحرب الباردة",
            options: ["الحصول على درجات أفضل", "الالتحاق بالتخصص الذي أحلم به", "فهم دروسي فعلاً", "المراجعة بسرعة أكبر"],
            support: "سأضبط خطتك على هذا الهدف",
            chips: ["تركيز ٢٥ دقيقة", "صوّر تمريناً", "اختبار سريع"],
            cardTitle: "بطاقات في الوقت المناسب",
            cardBody: "أعيدها إليك قبل أن تنساها بقليل.",
            praise: "+٤ نقاط: طموح وممكن",
            praiseSub: "من ١٢ إلى ١٦ من ٢٠ قبل ١٥ يونيو",
            primary: "متابعة",
            secondary: "لدي حساب بالفعل",
            later: "لاحقاً",
            offer: "استفد من خصم ٣٠٪",
            upgrade: "انتقل إلى",
            pageTitle: "درسك يصبح درساً تفاعلياً. في ٣٠ ثانية.",
            pageKeyword: "درساً تفاعلياً",
            pageSub: "أراجع معك كل يوم.",
            week: ["ن", "ث", "ر", "خ", "ج", "س", "ح"]
        )
    }

    private func week(_ words: Words) -> [V3WeekDay] {
        [
            V3WeekDay(letter: words.week[0], number: 9, isDone: true),
            V3WeekDay(letter: words.week[1], number: 10, isDone: true),
            V3WeekDay(letter: words.week[2], number: 11, isDone: true, hasEvent: true),
            V3WeekDay(letter: words.week[3], number: 12, isToday: true, hasEvent: true),
            V3WeekDay(letter: words.week[4], number: 13),
            V3WeekDay(letter: words.week[5], number: 14, hasEvent: true),
            V3WeekDay(letter: words.week[6], number: 15),
        ]
    }

    /// Les briques de la direction, de haut en bas, comme elles s'empilent sur un écran.
    private func board(_ words: Words) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            V3TopBar(progress: 0.32, onBack: {})
                .padding(.horizontal, -V3Metric.screenMargin)
            MikaAsk(words.question, highlight: words.keyword)
            VStack(spacing: 10) {
                V3OptionRow(words.options[0], icon: .trophy, tone: V3Color.iconGreen, isSelected: false) {}
                V3OptionRow(words.options[1], icon: .diploma, tone: V3Color.iconLilac, isSelected: true) {}
                V3OptionRow(words.options[2], subtitle: words.support, icon: .lightbulb, isSelected: false) {}
                V3OptionRow(words.options[3], icon: .flame, isSelected: true, multiple: true) {}
                V3OptionRow(words.options[0], icon: .rocket, isSelected: false, multiple: true) {}
            }
            MicaboFlowLayout(spacing: 8, lineSpacing: 8) {
                V3Chip(words.chips[0], icon: .alarm) {}
                V3Chip(words.chips[1], icon: .photo) {}
                V3Chip(words.chips[2], systemImage: "bolt.fill", tone: V3Color.iconYellow) {}
                V3Chip(words.chips[1], isSelected: true) {}
            }
            VStack(alignment: .leading, spacing: 14) {
                Text(words.cardTitle)
                    .font(V3Font.title)
                    .tracking(V3Tracking.title)
                    .foregroundStyle(V3Color.ink)
                V3WeekStrip(days: week(words))
                Text(words.cardBody)
                    .font(V3Font.support)
                    .foregroundStyle(V3Color.ink2)
                V3Button(words.primary, systemImage: "play.fill") {}
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
            HStack(spacing: 12) {
                MicaboIconView(icon: .check, size: 36, tint: V3Color.iconGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text(words.praise)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.ink)
                    Text(words.praiseSub)
                        .font(V3Font.support)
                        .foregroundStyle(V3Color.greenInk)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card(tone: V3Color.greenWash)
            HStack(spacing: 12) {
                Text(words.chips[2])
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .v3Card(selected: true)
                Text(words.chips[0])
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.yellowInk)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .v3Card(tone: V3Color.yellow)
            }
            HStack(spacing: 16) {
                V3ProBadge(words.upgrade)
                Spacer(minLength: 0)
                V3ProBadge(size: 11)
            }
            V3ProgressBar(value: 0.64)
            VStack(spacing: 10) {
                V3Button(words.primary) {}
                V3Button(words.primary, isEnabled: false) {}
                V3Button(words.primary, isLoading: true) {}
                V3Button(words.offer, kind: .offer) {}
                V3Button(words.secondary, kind: .secondary) {}
                V3Button(words.later, kind: .ghost) {}
            }
            scale(words)
            icons
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.vertical, 16)
        .background(V3Color.bg)
        .environment(\.mikaStill, true)
    }

    /// L'échelle typographique : les titres en Sofia Sans Condensed, le texte en police système.
    private func scale(_ words: Words) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V3Title(words.pageTitle, highlight: words.pageKeyword, size: 40)
            V3Title(words.pageTitle, highlight: words.pageKeyword, size: 32, highlightColor: V3Color.green)
            Text(words.cardTitle).font(V3Font.h2).tracking(V3Tracking.h2)
            Text(words.cardTitle).font(V3Font.title).tracking(V3Tracking.title)
            Text(words.pageSub).font(V3Font.bodyStrong)
            Text(words.pageSub).font(V3Font.body).foregroundStyle(V3Color.ink2)
            Text(words.later).font(V3Font.label).foregroundStyle(V3Color.accentBright)
            Text(words.praiseSub).font(V3Font.caption).foregroundStyle(V3Color.ink3)
        }
        .foregroundStyle(V3Color.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Toutes les icônes de la famille, en deux tons, chacune dans la teinte de son idée.
    private var icons: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 10) {
            ForEach(MicaboIcon.allCases) { icon in
                MicaboIconView(icon: icon, size: 36)
            }
        }
    }

    /// Le gabarit : barre du haut, Mika qui demande, du vide, les réponses ancrées en bas.
    private func screen(_ words: Words) -> some View {
        V3Screen(progress: 0.32, onBack: {}) {
            MikaAsk(words.question, highlight: words.keyword)
            Spacer(minLength: 24)
            VStack(spacing: 10) {
                V3OptionRow(words.options[0], icon: .trophy, tone: V3Color.iconGreen, isSelected: false) {}
                V3OptionRow(words.options[1], icon: .diploma, tone: V3Color.iconLilac, isSelected: true) {}
                V3OptionRow(words.options[2], icon: .lightbulb, isSelected: false) {}
                V3OptionRow(words.options[3], icon: .flame, isSelected: false) {}
            }
        } footer: {
            V3Button(words.primary) {}
            V3Button(words.later, kind: .ghost) {}
        }
        .environment(\.mikaStill, true)
    }

    /// Les composants d'avant le lot 10, tels qu'ils sortent de la même source : en-tête, rangées,
    /// boutons, état vide, barre d'onglets.
    private func legacy() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MicaboPageHeading(title: L10n.t("lesson.tab.lessons", locale: .resolved()), subtitle: L10n.t("lesson.lessons.count", locale: .resolved(), vars: ["count": "6"]))
            MicaboSectionHeading(title: L10n.t("lesson.profile.settings", locale: .resolved()))
            MicaboSettingsSection(
                caption: L10n.t("lesson.profile.settings", locale: .resolved()),
                rows: [
                    MicaboRow(tile: MicaboTile(glyph: .symbol("globe"), background: MicaboColor.accentWash, tint: MicaboColor.accent), title: L10n.t("lesson.profile.language", locale: .resolved()), accessory: .value("Français"), action: {}),
                    MicaboRow(tile: MicaboTile(glyph: .symbol("moon.fill"), background: MicaboColor.accentWash, tint: MicaboColor.accent), title: L10n.t("lesson.profile.theme", locale: .resolved()), accessory: .value(L10n.t(MicaboAppearance.defaultAppearance.titleKey, locale: .resolved())), action: {}),
                ]
            )
            HStack(spacing: 8) {
                MicaboSelectChip(title: L10n.t("lesson.theme.day", locale: .resolved()), isSelected: false) {}
                MicaboSelectChip(title: L10n.t("lesson.theme.night", locale: .resolved()), isSelected: true) {}
                MicaboSelectChip(title: L10n.t("lesson.theme.system", locale: .resolved()), isSelected: false) {}
            }
            MicaboProgressBar(progress: 0.43)
            Button(L10n.t("ios.cal.startSession", locale: .resolved())) {}
                .buttonStyle(MicaboPrimaryButtonStyle())
            Button(L10n.t("lesson.theme.night", locale: .resolved())) {}
                .buttonStyle(MicaboSecondaryButtonStyle())
            MicaboEmptyState(systemImage: "tray", title: L10n.t("lesson.lessons.emptyTitle", locale: .resolved()), message: L10n.t("lesson.lessons.emptyBody", locale: .resolved()))
                .micaboCard()
            MicaboTabBar()
                .environment(TabRouter())
                .padding(.horizontal, -20)
        }
        .padding(20)
        .background(MicaboColor.canvas)
        .environment(\.mikaStill, true)
    }

    private func inLanguage(_ locale: UiLocale, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: UiLocale.storageKey)
        defer {
            if let previous { defaults.set(previous, forKey: UiLocale.storageKey) } else { defaults.removeObject(forKey: UiLocale.storageKey) }
        }
        defaults.set(locale.rawValue, forKey: UiLocale.storageKey)
        try body()
    }

    /// `RenderGallery` dessine le clair, puis le marine sous `-nuit` : ici le marine est le
    /// thème de référence, le clair l'option.
    func testTheComponentsBoard() throws {
        try RenderGallery.render("look10-v3-components", night: true, board(.fr))
        try RenderGallery.render(
            "look10-v3-components-ar",
            board(.ar).environment(\.layoutDirection, .rightToLeft).environment(\.colorScheme, .dark)
        )
        try RenderGallery.render(
            "look10-v3-components-de-xxxl",
            width: 375,
            board(.de).environment(\.dynamicTypeSize, .xxxLarge).environment(\.colorScheme, .dark)
        )
    }

    func testTheScreenTemplate() throws {
        try RenderGallery.render("look10-v3-screen", height: 852, night: true, screen(.fr))
        try RenderGallery.render(
            "look10-v3-screen-ar",
            height: 852,
            screen(.ar).environment(\.layoutDirection, .rightToLeft).environment(\.colorScheme, .dark)
        )
        try RenderGallery.render(
            "look10-v3-screen-de-xxxl",
            width: 375,
            height: 812,
            screen(.de).environment(\.dynamicTypeSize, .xxxLarge).environment(\.colorScheme, .dark)
        )
    }

    func testTheOlderComponentsFollow() throws {
        try inLanguage(.fr) {
            try RenderGallery.render("look10-legacy", night: true, legacy())
        }
        try inLanguage(.de) {
            try RenderGallery.render(
                "look10-legacy-de-xxxl",
                width: 375,
                legacy().environment(\.dynamicTypeSize, .xxxLarge).environment(\.colorScheme, .dark)
            )
        }
        try inLanguage(.ar) {
            try RenderGallery.render(
                "look10-legacy-ar",
                legacy().environment(\.layoutDirection, .rightToLeft).environment(\.colorScheme, .dark)
            )
        }
    }
}
