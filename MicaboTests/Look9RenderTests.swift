import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Lot 9 : un système visuel du niveau des meilleures apps d'étude.** Une nuit marine au lieu
/// du graphite, des surfaces posées sur une lèvre au lieu d'une ombre floue, des boutons qui
/// s'enfoncent, et une seule famille d'icônes — plates, en deux tons, dans la couleur de la
/// matière.
@MainActor
final class Look9Tests: XCTestCase {
    /// Chaque icône se dessine : un nom de symbole inconnu donnerait une case vide, sans erreur.
    func testEveryIconSymbolExists() {
        for icon in MicaboIcon.allCases {
            XCTAssertNotNil(UIImage(systemName: icon.symbol), "\(icon) : « \(icon.symbol) » n'existe pas")
            if let outline = icon.outline {
                XCTAssertNotNil(UIImage(systemName: outline), "\(icon) : « \(outline) » n'existe pas")
            }
        }
    }

    /// Une icône de matière a la couleur des leçons de cette matière : la tuile pâle et le
    /// dessin qu'elle porte sont du même ton.
    func testSubjectIconsTakeTheSubjectTone() {
        for icon in [MicaboIcon.calculator, .atom, .flask, .scroll, .globe, .brain, .palette, .quill, .book, .rocket, .diploma] {
            XCTAssertEqual(icon.tone, LessonTone.forSubject(icon), "\(icon)")
        }
    }

    /// La nuit est marine, pas graphite : le bleu y domine le rouge, de loin.
    func testTheNightIsNavy() {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(MicaboPalette.night.canvas).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertGreaterThan(blue - red, 0.05)
        XCTAssertEqual(MicaboPalette.night.toneGlyph.count, LessonTone.allCases.count)
        XCTAssertEqual(MicaboPalette.day.toneGlyph.count, LessonTone.allCases.count)
    }
}

@MainActor
final class Look9RenderTests: XCTestCase {
    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
    }

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        L10n.t(key, locale: .resolved(), vars: vars)
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

    /// Toutes les icônes, chacune sur la tuile pâle de son ton.
    private func iconGrid(size: CGFloat) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(MicaboIcon.allCases) { icon in
                MicaboIconView(icon: icon, size: size)
                    .frame(width: size * 1.45, height: size * 1.45)
                    .background(icon.tone.pale, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    /// Les briques de l'app sur le fond : ce qui donne son air à chaque écran.
    private func components() -> some View {
        VStack(alignment: .leading, spacing: 18) {
            MicaboPageHeading(title: t("lesson.tab.lessons"), subtitle: t("lesson.lessons.count", ["count": "6"]))
            iconGrid(size: 30)
            MicaboSectionHeader(title: t("lesson.tab.lessons"), actionTitle: t("ios.profile.seeAll")) {}
            HStack(spacing: 12) {
                MicaboIconView(icon: .calculator, size: 34)
                    .frame(width: 52, height: 52)
                    .background(LessonTone.blue.pale, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 6) {
                    Text("La guerre froide")
                        .font(MicaboFont.cardTitle)
                        .foregroundStyle(MicaboColor.ink)
                    Text("Bac d'histoire · J-12")
                        .font(MicaboFont.caption)
                        .foregroundStyle(MicaboColor.inkSecondary)
                    MicaboProgressBar(progress: 0.43)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboCard()
            HStack(spacing: 8) {
                MicaboSelectChip(title: t("lesson.theme.day"), isSelected: true) {}
                MicaboSelectChip(title: t("lesson.theme.night"), isSelected: false) {}
                MicaboSelectChip(title: t("lesson.theme.system"), isSelected: false) {}
            }
            Button(t("ios.cal.startSession")) {}
                .buttonStyle(MicaboPrimaryButtonStyle())
            Button(t("lesson.theme.night")) {}
                .buttonStyle(MicaboSecondaryButtonStyle())
            ProfileGroup(title: t("lesson.profile.settings")) {
                ProfileRow(icon: .language, title: t("lesson.profile.language"), value: "Français") {}.label
                ProfileRow(icon: .theme, title: t("lesson.profile.theme"), value: t(MicaboAppearance.defaultAppearance.titleKey)) {}.label
                ProfileRow(icon: .rate, title: t("lesson.profile.rate"), showsDivider: false) {}.label
            }
            MicaboEmptyState(systemImage: "tray", title: t("lesson.lessons.emptyTitle"), message: t("lesson.lessons.emptyBody"))
                .micaboCard()
        }
        .padding(20)
        .environment(\.homeStill, true)
        .environment(\.mikaStill, true)
    }

    func testComponentsDayAndNight() throws {
        try inLanguage(.fr) {
            try RenderGallery.render("look9-components", night: true, components())
            try RenderGallery.render("look9-icons-large", night: true, iconGrid(size: 44).padding(20))
        }
        try inLanguage(.de) {
            try RenderGallery.render("look9-components-de-xxxl", width: 375, components().environment(\.dynamicTypeSize, .xxxLarge))
        }
        try inLanguage(.ar) {
            try RenderGallery.render("look9-components-ar", night: true, components().environment(\.layoutDirection, .rightToLeft))
        }
    }
}
