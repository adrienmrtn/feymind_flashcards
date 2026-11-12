import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Lot 10 : le système visuel V3, « franc, joueur, lumineux ».** Une page blanche, une encre
/// bleu-noir, des titres en Black, et tout ce qui se touche posé sur une lèvre : bord de 2 pt,
/// lèvre de 4 pt (5 pour le bouton principal). Les valeurs sont celles des maquettes.
@MainActor
final class Look10Tests: XCTestCase {
    private func hex(_ color: Color, night: Bool = false) -> String {
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

    /// Le jour : les jetons de `base.css`, au chiffre près.
    func testTheDayTokensAreTheMockupValues() {
        XCTAssertEqual(hex(V3Color.bg), "FFFFFF")
        XCTAssertEqual(hex(V3Color.surface), "FFFFFF")
        XCTAssertEqual(hex(V3Color.soft), "F5F7FB")
        XCTAssertEqual(hex(V3Color.line), "E3E8F2")
        XCTAssertEqual(hex(V3Color.lip), "CDD5E3")
        XCTAssertEqual(hex(V3Color.ink), "12162A")
        XCTAssertEqual(hex(V3Color.ink2), "5A6378")
        XCTAssertEqual(hex(V3Color.ink3), "9AA3B5")
        XCTAssertEqual(hex(V3Color.accent), "3870FE")
        XCTAssertEqual(hex(V3Color.accentDeep), "1F47B8")
        XCTAssertEqual(hex(V3Color.accentWash), "EEF3FF")
        XCTAssertEqual(hex(V3Color.accentWash2), "DCE6FF")
        XCTAssertEqual(hex(V3Color.yellow), "F7B41F")
        XCTAssertEqual(hex(V3Color.yellowWash), "FFF4D6")
        XCTAssertEqual(hex(V3Color.pink), "E3596C")
        XCTAssertEqual(hex(V3Color.pinkWash), "FFE7EC")
        XCTAssertEqual(hex(V3Color.green), "1FB573")
        XCTAssertEqual(hex(V3Color.greenWash), "DDF7EA")
        XCTAssertEqual(hex(V3Color.lilac), "8B6CF0")
        XCTAssertEqual(hex(V3Color.lilacWash), "EEE9FF")
    }

    /// La nuit garde le marine de Micabo : fond, surface, filet, texte, accent.
    func testTheNightKeepsTheNavy() {
        XCTAssertEqual(hex(V3Color.bg, night: true), "0B0F1C")
        XCTAssertEqual(hex(V3Color.surface, night: true), "161B2B")
        XCTAssertEqual(hex(V3Color.line, night: true), "252B3E")
        XCTAssertEqual(hex(V3Color.ink, night: true), "F4F6FC")
        XCTAssertEqual(hex(V3Color.accent, night: true), "5C88FF")
    }

    /// Les fonds pleins des stories ne changent pas avec l'apparence.
    func testTheStoryBackgroundsAreTheSameDayAndNight() {
        for (color, value) in [
            (V3Color.storyBlue, "3870FE"), (V3Color.storyYellow, "FFC531"),
            (V3Color.storyCoral, "FF6B81"), (V3Color.storyNavy, "12162A"),
        ] {
            XCTAssertEqual(hex(color), value)
            XCTAssertEqual(hex(color, night: true), value)
        }
    }

    /// Une surface « dans un ton » accepte le lavis comme le plein : le lavis reste tel quel, le
    /// plein est délayé ; et le bord est toujours un cran plus soutenu que le fond.
    func testAToneGivesAWashAndAnEdge() {
        XCTAssertEqual(hex(V3Color.wash(of: V3Color.greenWash)), "DDF7EA")
        XCTAssertEqual(hex(V3Color.wash(of: V3Color.greenWash), night: true), "0F3326")
        XCTAssertNotEqual(hex(V3Color.wash(of: V3Color.green)), "1FB573")
        for tone in [V3Color.greenWash, V3Color.green, V3Color.yellowWash, V3Color.pink, V3Color.accentWash, V3Color.lilac] {
            XCTAssertNotEqual(hex(V3Color.edge(of: tone)), hex(V3Color.wash(of: tone)))
            XCTAssertNotEqual(hex(V3Color.edge(of: tone), night: true), hex(V3Color.wash(of: tone), night: true))
        }
    }

    /// Les mesures des maquettes : bouton de 58 pt à lèvre de 5, ligne de 64, pastille de 40,
    /// rayons 18 / 22 / 24, jauge de 10, marges de 20.
    func testTheMetricsAreTheMockupValues() {
        XCTAssertEqual(V3Metric.buttonHeight, 58)
        XCTAssertEqual(V3Metric.buttonLip, 5)
        XCTAssertEqual(V3Metric.lip, 4)
        XCTAssertEqual(V3Metric.border, 2)
        XCTAssertEqual(V3Metric.optionHeight, 64)
        XCTAssertEqual(V3Metric.badge, 40)
        XCTAssertEqual(V3Metric.radiusButton, 18)
        XCTAssertEqual(V3Metric.radiusBubble, 22)
        XCTAssertEqual(V3Metric.radiusCard, 24)
        XCTAssertEqual(V3Metric.progressHeight, 10)
        XCTAssertEqual(V3Metric.screenMargin, 20)
    }
}

/// La planche des composants V3 : jour, nuit, arabe, allemand en très grand texte sur 375 pt.
@MainActor
final class Look10RenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    /// Les phrases de la planche : un spécimen, pas des écrans — elles ne vivent qu'ici.
    private struct Words {
        var question: String
        var reaction: String
        var options: [String]
        var support: String
        var chips: [String]
        var cardTitle: String
        var cardBody: String
        var praise: String
        var praiseSub: String
        var primary: String
        var later: String
        var start: String
        var account: String
        var pageTitle: String
        var pageSub: String

        static let fr = Words(
            question: "Ton objectif n°1 cette année ?",
            reaction: "Bac dans 7 mois : on a le temps de bien faire",
            options: ["Avoir de meilleures notes", "Entrer dans la formation de mes rêves", "Vraiment comprendre mes cours", "Réviser plus vite"],
            support: "Je règle ton plan dessus",
            chips: ["Scanner un exo", "Quiz", "Importer"],
            cardTitle: "Flashcards au bon moment",
            cardBody: "Je te les ressors juste avant que tu oublies.",
            praise: "+4 points : ambitieux, et faisable",
            praiseSub: "12/20 → 16/20 d'ici le 15 juin",
            primary: "Continuer",
            later: "Plus tard",
            start: "Commencer",
            account: "J'ai déjà un compte",
            pageTitle: "Voilà comment je t'aide",
            pageSub: "Je révise avec toi, tous les jours."
        )

        static let de = Words(
            question: "Was ist dein wichtigstes Ziel in diesem Schuljahr?",
            reaction: "Abitur in 7 Monaten: Wir haben genug Zeit, es richtig zu machen",
            options: ["Bessere Noten schreiben", "Meinen Wunschstudienplatz bekommen", "Den Unterrichtsstoff wirklich verstehen", "Schneller wiederholen"],
            support: "Danach richte ich deinen Lernplan aus",
            chips: ["Aufgabe scannen", "Quiz", "Importieren"],
            cardTitle: "Karteikarten im richtigen Moment",
            cardBody: "Ich zeige sie dir wieder, kurz bevor du sie vergisst.",
            praise: "+4 Punkte: ehrgeizig und machbar",
            praiseSub: "Von 3,0 auf 2,0 bis zum 15. Juni",
            primary: "Weiter",
            later: "Später",
            start: "Loslegen",
            account: "Ich habe schon ein Konto",
            pageTitle: "So unterstütze ich dich beim Lernen",
            pageSub: "Ich wiederhole jeden Tag mit dir."
        )

        static let ar = Words(
            question: "ما هدفك الأول هذا العام؟",
            reaction: "البكالوريا بعد ٧ أشهر: لدينا الوقت لنُحسن العمل",
            options: ["الحصول على درجات أفضل", "الالتحاق بالتخصص الذي أحلم به", "فهم دروسي فعلاً", "المراجعة بسرعة أكبر"],
            support: "سأضبط خطتك على هذا الهدف",
            chips: ["صوّر تمريناً", "اختبار", "استيراد"],
            cardTitle: "بطاقات في الوقت المناسب",
            cardBody: "أعيدها إليك قبل أن تنساها بقليل.",
            praise: "+٤ نقاط: طموح وممكن",
            praiseSub: "من ١٢ إلى ١٦ من ٢٠ قبل ١٥ يونيو",
            primary: "متابعة",
            later: "لاحقاً",
            start: "ابدأ",
            account: "لدي حساب بالفعل",
            pageTitle: "هكذا أساعدك",
            pageSub: "أراجع معك كل يوم."
        )
    }

    /// Les briques V3, de haut en bas, comme elles s'empilent sur un écran.
    private func board(_ words: Words) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            V3TopBar(progress: 0.32, onBack: {})
                .padding(.horizontal, -V3Metric.screenMargin)
            MikaAsk(words.question, mood: .idle)
            VStack(spacing: 10) {
                V3OptionRow(words.options[0], tone: V3Color.greenWash, emoji: "📈", isSelected: false) {}
                V3OptionRow(words.options[1], tone: V3Color.accentWash2, emoji: "🎓", isSelected: true) {}
                V3OptionRow(words.options[2], subtitle: words.support, icon: .lightbulb, isSelected: false) {}
                V3OptionRow(words.options[3], isSelected: true, multiple: true) {}
                V3OptionRow(words.options[0], isSelected: false, multiple: true) {}
            }
            MicaboFlowLayout(spacing: 10, lineSpacing: 8) {
                V3Chip(words.chips[0], emoji: "📷") {}
                V3Chip(words.chips[1], systemImage: "checklist", isSelected: true) {}
                V3Chip(words.chips[2], systemImage: "square.and.arrow.down") {}
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(words.cardTitle)
                    .font(V3Font.title)
                    .tracking(V3Tracking.title)
                    .foregroundStyle(V3Color.ink)
                Text(words.cardBody)
                    .font(V3Font.support)
                    .foregroundStyle(V3Color.ink2)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
            HStack(spacing: 12) {
                Text("🎯").font(.system(size: 26))
                VStack(alignment: .leading, spacing: 2) {
                    Text(words.praise)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.greenInk)
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
                Text(words.chips[1])
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.accentInk)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .v3Card(selected: true)
                Text(words.chips[2])
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.yellowInk)
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .v3Card(tone: V3Color.yellow)
            }
            V3ProgressBar(value: 0.64)
            VStack(spacing: 8) {
                V3Button(words.primary) {}
                V3Button(words.primary, systemImage: "play.fill", isEnabled: false) {}
                V3Button(words.primary, isLoading: true) {}
                V3Button(words.later, kind: .ghost) {}
            }
            stories(words)
            scale(words)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.vertical, 16)
        .background(V3Color.bg)
        .environment(\.mikaStill, true)
    }

    /// Les boutons posés sur les fonds pleins des stories.
    private func stories(_ words: Words) -> some View {
        VStack(spacing: 10) {
            VStack(spacing: 8) {
                V3Button(words.start, kind: .white) {}
                V3Button(words.account, kind: .ghost) {}
                    .v3Tint(.white)
            }
            .padding(16)
            .background(V3Color.storyBlue, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            VStack(spacing: 8) {
                V3Button(words.start, kind: .ink) {}
                V3Button(words.account, kind: .ghost) {}
                    .v3Tint(V3Color.storyNavy)
            }
            .padding(16)
            .background(V3Color.storyYellow, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    /// L'échelle typographique.
    private func scale(_ words: Words) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(words.pageTitle).font(V3Font.display()).tracking(V3Tracking.display)
            Text(words.pageTitle).font(V3Font.h1).tracking(V3Tracking.h1)
            Text(words.pageTitle).font(V3Font.h2).tracking(V3Tracking.h2)
            Text(words.cardTitle).font(V3Font.title).tracking(V3Tracking.title)
            Text(words.pageSub).font(V3Font.bodyStrong)
            Text(words.pageSub).font(V3Font.body).foregroundStyle(V3Color.ink2)
            Text(words.later).font(V3Font.label).foregroundStyle(V3Color.accent)
            Text(words.praiseSub).font(V3Font.caption).foregroundStyle(V3Color.ink3)
        }
        .foregroundStyle(V3Color.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Le gabarit : barre du haut, Mika qui demande, les réponses, et le bouton au pied.
    private func screen(_ words: Words) -> some View {
        V3Screen(progress: 0.46, onBack: {}) {
            MikaAsk(words.reaction, mood: .happy)
            VStack(spacing: 10) {
                V3OptionRow(words.options[0], tone: V3Color.accentWash2, emoji: "🎓", isSelected: true) {}
                V3OptionRow(words.options[2], tone: V3Color.yellowWash, emoji: "✏️", isSelected: false) {}
                V3OptionRow(words.options[3], tone: V3Color.greenWash, emoji: "🌱", isSelected: false) {}
            }
            .padding(.top, 26)
        } footer: {
            V3Button(words.primary) {}
            V3Button(words.later, kind: .ghost) {}
        }
        .environment(\.mikaStill, true)
    }

    func testTheV3ComponentsBoard() throws {
        try RenderGallery.render("look10-v3-components", night: true, board(.fr))
        try RenderGallery.render(
            "look10-v3-components-ar",
            board(.ar).environment(\.layoutDirection, .rightToLeft)
        )
        try RenderGallery.render(
            "look10-v3-components-de-xxxl",
            width: 375,
            board(.de).environment(\.dynamicTypeSize, .xxxLarge)
        )
    }

    func testTheV3ScreenTemplate() throws {
        try RenderGallery.render("look10-v3-screen", height: 852, night: true, screen(.fr))
        try RenderGallery.render(
            "look10-v3-screen-ar",
            height: 852,
            screen(.ar).environment(\.layoutDirection, .rightToLeft)
        )
        try RenderGallery.render(
            "look10-v3-screen-de-xxxl",
            width: 375,
            height: 812,
            screen(.de).environment(\.dynamicTypeSize, .xxxLarge)
        )
    }
}
