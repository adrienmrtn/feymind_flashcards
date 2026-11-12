import SwiftUI
import UIKit
import XCTest
@testable import Micabo

/// **Les planches du nouveau Mika** (lot 10) : le personnage plat, dessiné dans le code, sur
/// le marine de l'app d'abord, puis sur le fond teinté du thème clair.
///
/// - `mika10-maquette-*` : la planche de la maquette (`design/mika-v3/mika-expressions.png`)
///   au-dessus du même tableau dessiné par SwiftUI, avec l'écart en pixels sous chaque dessin ;
/// - `mika10-entier-*`, `mika10-demi-*` : chaque humeur en entier et en demi ;
/// - `mika10-tailles-*` : en entier à 36, 84, 150, 240 et 300 points, en demi, en avatar ;
/// - `mika10-metamorphoses`, `mika10-gestes`, `mika10-confettis` : ce qui bouge, image par image ;
/// - `mika10-fonds` : sur un fond bleu (liseré, disque), en arabe ; `mika10-lancement` ;
/// - `mika10-quiz-*`, `mika10-moments`, `mika10-attentes` : Mika à sa place dans l'app.
///
/// Sous XCTest, Mika est posé sur l'expression de son humeur : rien ne bouge.
@MainActor
final class MikaRenderTests: XCTestCase {
    private var savedLocale: String?

    override func setUpWithError() throws {
        guard RenderGallery.directory != nil else { throw XCTSkip("MICABO_RENDER_DIR absent : pas de rendu") }
        savedLocale = UserDefaults.standard.string(forKey: UiLocale.storageKey)
    }

    override func tearDown() {
        if let savedLocale {
            UserDefaults.standard.set(savedLocale, forKey: UiLocale.storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: UiLocale.storageKey)
        }
        super.tearDown()
    }

    // MARK: - Les deux thèmes

    private static func page(_ night: Bool) -> Color { Color(hex: night ? 0x0B0F1C : 0xEEF1F8) }
    private static func surface(_ night: Bool) -> Color { Color(hex: night ? 0x171C2C : 0xFFFFFF) }
    private static func rule(_ night: Bool) -> Color { Color(hex: night ? 0x262D42 : 0xDCE1EC) }
    private static func ink(_ night: Bool) -> Color { Color(hex: night ? 0xF5F6FB : 0x0F1324) }
    private static func name(_ night: Bool) -> String { night ? "marine" : "clair" }

    /// Une planche dans un thème : le fond de page, la couleur du texte, et le thème passé
    /// aux Mika qu'elle porte.
    private func themed<Content: View>(_ night: Bool, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .background(Self.page(night))
            .foregroundStyle(Self.ink(night))
            .environment(\.colorScheme, night ? .dark : .light)
    }

    private func label(_ text: String, size: CGFloat = 11) -> some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// Les humeurs, cinq par rangée.
    private static let rows: [[MikaMood]] = stride(from: 0, to: MikaMood.allCases.count, by: 5).map { start in
        Array(MikaMood.allCases[start..<min(start + 5, MikaMood.allCases.count)])
    }

    // MARK: - À côté de la maquette

    /// La planche de la maquette au-dessus, le même tableau dessiné par l'app en dessous : le
    /// personnage doit être le même (proportions, yeux, joues, crayon). Sous chaque dessin,
    /// le nombre de pixels (sur 40 000) qui s'écartent de la maquette.
    func testNextToTheMockup() throws {
        let sheet = MikaMockup.sheet()
        let reference = sheet.flatMap { MikaMockup.pixels(of: $0) }
        for night in [true, false] {
            var measured: [MikaMood: String] = [:]
            if let sheet, let reference {
                for mood in MikaMockup.expressions {
                    if let gap = MikaMockup.difference(mood, night: night, reference: reference, sheetWidth: sheet.width) {
                        measured[mood] = "\(gap) px"
                    }
                }
            }
            let gaps = measured
            try RenderGallery.render(
                "mika10-maquette-\(Self.name(night))", width: 600,
                VStack(spacing: 0) {
                    if let sheet {
                        // La moitié de la planche qui porte ce thème : le marine en haut.
                        Image(uiImage: UIImage(cgImage: sheet))
                            .resizable()
                            .frame(width: 600, height: 452)
                            .offset(y: night ? 0 : -226)
                            .frame(width: 600, height: 226, alignment: .top)
                            .clipped()
                    } else {
                        Text("la maquette n'est pas lisible depuis ce simulateur")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 600, height: 40)
                    }
                    themed(night) {
                        VStack(spacing: 0) {
                            ForEach(0..<2, id: \.self) { row in
                                HStack(spacing: 0) {
                                    ForEach(Array(MikaMockup.expressions[(row * 6)..<(row * 6 + 6)]), id: \.self) { mood in
                                        VStack(spacing: 0) {
                                            MikaMascot(mood: mood, size: 100, frozenAt: 0)
                                            self.label("\(mood.rawValue) · \(gaps[mood] ?? "?")", size: 7)
                                                .frame(width: 100, height: 13)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            )
        }
    }

    // MARK: - Les humeurs

    /// Chaque humeur en entier, sur le marine puis sur le clair.
    func testEveryMoodWhole() throws {
        for night in [true, false] {
            try RenderGallery.render(
                "mika10-entier-\(Self.name(night))", width: 590,
                themed(night) {
                    VStack(spacing: 10) {
                        ForEach(Self.rows, id: \.self) { row in
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(row) { mood in
                                    VStack(spacing: 2) {
                                        MikaMascot(mood: mood, size: 110, frozenAt: 0)
                                        self.label(mood.rawValue)
                                    }
                                    .frame(width: 114)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
            )
        }
    }

    /// Chaque humeur en demi : du haut de la tête jusque sous les joues et la bouche, coupée
    /// net par le bord de la carte où elle se pose.
    func testEveryMoodPeeking() throws {
        for night in [true, false] {
            try RenderGallery.render(
                "mika10-demi-\(Self.name(night))", width: 590,
                themed(night) {
                    VStack(spacing: 6) {
                        ForEach(Self.rows, id: \.self) { row in
                            HStack(alignment: .top, spacing: 0) {
                                ForEach(row) { mood in
                                    VStack(spacing: 4) {
                                        self.peekOnCard(mood, width: 92, night: night)
                                        self.label(mood.rawValue)
                                    }
                                    .frame(width: 114)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(10)
                }
            )
        }
    }

    /// Un demi-Mika sur le bord haut d'une carte, de l'air au-dessus pour ce qui déborde.
    private func peekOnCard(_ mood: MikaMood, width: CGFloat, night: Bool) -> some View {
        VStack(spacing: 0) {
            MikaPeek(mood: mood, width: width)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Self.surface(night))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Self.rule(night), lineWidth: 1.5))
                .frame(width: width * 1.18, height: 24)
        }
        .padding(.top, width * 0.3)
    }

    // MARK: - Les tailles

    /// En entier à 36, 84, 150, 240 et 300 points ; en demi à 64, 92 et 124 ; en avatar à 28,
    /// 36, 44 et 60. Le dessin est vectoriel : net à toutes les tailles.
    func testSizes() throws {
        for night in [true, false] {
            try RenderGallery.render(
                "mika10-tailles-\(Self.name(night))", width: 600,
                themed(night) {
                    VStack(spacing: 14) {
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach([36, 84, 150, 240] as [CGFloat], id: \.self) { size in
                                VStack(spacing: 2) {
                                    MikaMascot(mood: .idle, size: size, frozenAt: 0)
                                    self.label("\(Int(size))")
                                }
                            }
                        }
                        HStack(alignment: .bottom, spacing: 8) {
                            VStack(spacing: 2) {
                                MikaMascot(mood: .wave, size: 300, frozenAt: 0)
                                self.label("300")
                            }
                            VStack(spacing: 2) {
                                MikaMascot(mood: .celebrate, size: 240, frozenAt: 0, shadow: true)
                                self.label("240, avec son ombre")
                            }
                        }
                        HStack(alignment: .bottom, spacing: 10) {
                            ForEach([64, 92, 124] as [CGFloat], id: \.self) { width in
                                VStack(spacing: 4) {
                                    self.peekOnCard(.happy, width: width, night: night)
                                    self.label("demi \(Int(width))")
                                }
                            }
                            ForEach([28, 36, 44, 60] as [CGFloat], id: \.self) { size in
                                VStack(spacing: 4) {
                                    MikaAvatar(size: size)
                                    self.label("\(Int(size))")
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            )
        }
    }

    // MARK: - Ce qui bouge

    /// Une pose à l'écran, dans un carré de `side`.
    private func figure(_ pose: MikaPose, side: CGFloat, night: Bool = true) -> some View {
        MikaFigure(pose: pose, framing: .full, scale: side / MikaFraming.full.window.width, night: night)
            .frame(width: side, height: side, alignment: .bottom)
    }

    /// **Les métamorphoses** : la pose que SwiftUI calcule entre deux humeurs, de 0 à 1. L'œil
    /// s'aplatit pendant que l'arc apparaît, le bras tourne autour de l'épaule, la bouche
    /// s'ouvre : ce n'est pas un fondu entre deux images.
    func testMorphs() throws {
        let pairs: [(String, MikaPose, MikaPose)] = [
            ("repos → joie", .idle, .happy),
            ("repos → clin d'œil", .idle, .wink),
            ("repos → clignement", .idle, MikaPose.idle.with { $0.blink = 1 }),
            ("repos → coucou", .idle, .wave),
            ("repos → fête", .idle, MikaPose.celebrate.with { $0.confetti = 0 }),
            ("repos → surprise", .idle, .surprise),
            ("repos → triste", .idle, .sad),
            ("repos → sommeil", .idle, .sleep),
            ("réflexion → écriture", .think, .write),
            ("triste → fête", .sad, MikaPose.celebrate.with { $0.confetti = 0 }),
        ]
        let steps: [Double] = [0, 0.2, 0.4, 0.6, 0.8, 1]
        try RenderGallery.render(
            "mika10-metamorphoses", width: 640,
            themed(true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(pairs.indices, id: \.self) { index in
                        let pair = pairs[index]
                        HStack(spacing: 0) {
                            self.label(pair.0, size: 10)
                                .frame(width: 88, alignment: .leading)
                            ForEach(steps, id: \.self) { step in
                                self.figure(MikaPose.between(pair.1, pair.2, step), side: 90)
                            }
                        }
                    }
                }
                .padding(6)
            }
        )
    }

    /// **Les gestes**, temps par temps : le coucou (le bras se lève, balance deux fois,
    /// revient), la fête, le clin d'œil, le « non », la joie, l'arrivée, l'appui, le clignement,
    /// et les deux bouts des deux attentes.
    func testGestures() throws {
        var listed: [(String, [MikaPose])] = []
        for mood in [MikaMood.wave, .celebrate, .wink, .shake, .happy, .appear] {
            listed.append((mood.rawValue, [mood.opening] + mood.beats.map(\.pose)))
        }
        listed.append(("appui", [MikaPose.idle] + MikaMood.tapBeats(from: .idle).map(\.pose)))
        listed.append(("clignement", [MikaPose.idle] + MikaMood.blinkBeats(from: .idle).map(\.pose)))
        for mood in [MikaMood.write, .think] {
            if let loop = mood.loop {
                listed.append(("\(mood.rawValue) (attente)", [loop.from, MikaPose.between(loop.from, loop.to, 0.5), loop.to]))
            }
        }
        let gestures = listed
        try RenderGallery.render(
            "mika10-gestes", width: 640,
            themed(true) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(gestures.indices, id: \.self) { index in
                        let gesture = gestures[index]
                        HStack(spacing: 0) {
                            self.label(gesture.0, size: 10)
                                .frame(width: 74, alignment: .leading)
                            ForEach(gesture.1.indices, id: \.self) { step in
                                self.figure(gesture.1[step], side: 78)
                            }
                        }
                    }
                }
                .padding(6)
            }
        )
    }

    /// La gerbe de confettis de la fête, de son départ à sa fin (1,2 seconde).
    func testConfettiBurst() throws {
        let moments: [Double] = [0.04, 0.12, 0.25, 0.4, 0.6, 0.8, 0.95]
        try RenderGallery.render(
            "mika10-confettis", width: 640,
            themed(true) {
                HStack(spacing: 0) {
                    ForEach(moments, id: \.self) { moment in
                        VStack(spacing: 2) {
                            MikaBurstPreview(progress: moment, width: 90)
                            self.label(String(format: "%.2f", moment), size: 9)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        )
    }

    // MARK: - Les fonds, le lancement

    /// **Jamais directement sur un fond bleu** : le liseré blanc (`backdrop: .blue`), le disque
    /// (`.mikaBackdrop(.disc)`), le nid ; un demi-Mika sur le bleu ; et Mika en arabe, son
    /// crayon toujours dans la main droite.
    func testBackdrops() throws {
        let accent = Color(hex: 0x3D73FF)
        for night in [true, false] {
            try RenderGallery.render(
                "mika10-fonds-\(Self.name(night))", width: 600,
                themed(night) {
                    VStack(spacing: 0) {
                        HStack(alignment: .bottom, spacing: 14) {
                            VStack(spacing: 4) {
                                MikaMascot(mood: .wave, size: 130, frozenAt: 0, backdrop: .blue)
                                self.label("backdrop: .blue").foregroundStyle(Color.white)
                            }
                            VStack(spacing: 4) {
                                MikaMascot(mood: .wave, size: 130, frozenAt: 0).mikaBackdrop(.disc)
                                self.label(".mikaBackdrop(.disc)").foregroundStyle(Color.white)
                            }
                            VStack(spacing: 4) {
                                MikaMascot(mood: .celebrate, size: 130, frozenAt: 0).mikaBackdrop(.disc)
                                self.label("la fête dans son disque").foregroundStyle(Color.white)
                            }
                            VStack(spacing: 0) {
                                MikaPeek(mood: .wave, width: 110, backdrop: .blue)
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Self.surface(night))
                                    .frame(width: 130, height: 26)
                            }
                        }
                        .padding(.top, 34)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity)
                        .background(accent)

                        HStack(alignment: .bottom, spacing: 18) {
                            VStack(spacing: 4) {
                                MikaMascot(mood: .happy, size: 96, frozenAt: 0, frame: .circle)
                                self.label("le nid")
                            }
                            VStack(spacing: 4) {
                                MikaMascot(mood: .idle, size: 110, frozenAt: 0)
                                    .environment(\.layoutDirection, .rightToLeft)
                                self.label("en arabe : le crayon reste à droite")
                            }
                            VStack(spacing: 4) {
                                HStack(spacing: 8) {
                                    MikaAvatar(size: 40)
                                    MikaAvatar(size: 32)
                                }
                                .padding(10)
                                .background(Self.surface(night), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                self.label("l'avatar sur une surface")
                            }
                        }
                        .padding(14)
                    }
                }
            )
        }
    }

    /// L'écran de lancement, recopié par la première image de l'app : le marine, Mika au
    /// centre de l'écran.
    func testLaunch() throws {
        try RenderGallery.render(
            "mika10-lancement", width: 300, height: 650,
            LaunchCurtain()
                .frame(width: 300, height: 650)
        )
    }

    // MARK: - À sa place dans l'app

    private func use(_ locale: UiLocale) {
        UserDefaults.standard.set(locale.rawValue, forKey: UiLocale.storageKey)
    }

    private func t(_ key: String) -> String { L10n.t(key, locale: .resolved()) }

    private static let question = QuizQuestion(
        id: "mika10",
        prompt: "Quelle particule porte une charge positive ?",
        choices: ["L'électron", "Le proton", "Le neutron", "Le noyau"],
        answer: 1,
        why: "Le proton porte une charge positive, égale et opposée à celle de l'électron."
    )

    /// Le retour d'une réponse : le panneau en bas d'un écran de quiz, Mika au-dessus de son bord.
    private func quiz(right: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            AnswerPanel(question: Self.question, right: right, isLast: false) {}
        }
        .frame(height: 400)
        .environment(\.mikaStill, true)
    }

    /// Un écran vide, où Mika tient la page.
    private func moments() -> some View {
        MicaboEmptyState(
            systemImage: "books.vertical",
            title: t("lesson.lessons.emptyTitle"),
            message: t("lesson.lessons.emptyBody"),
            actionTitle: t("lesson.lessons.new"),
            mika: .wave
        ) {}
        .padding(20)
        .environment(\.mikaStill, true)
        .environment(\.homeStill, true)
    }

    /// L'attente d'une génération, puis son échec : la même taille, la même place.
    private func waits() -> some View {
        HStack(alignment: .bottom, spacing: 24) {
            MikaMascot(mood: .write, size: 150)
            MikaMascot(mood: .think, size: 150)
            MikaMascot(mood: .sad, size: 150)
        }
        .padding(20)
        .environment(\.mikaStill, true)
    }

    func testMikaInPlace() throws {
        use(.fr)
        try RenderGallery.render("mika10-quiz-juste", night: true, quiz(right: true))
        try RenderGallery.render("mika10-quiz-faux", night: true, quiz(right: false))
        try RenderGallery.render("mika10-moments", night: true, moments())
        try RenderGallery.render("mika10-attentes", width: 520, night: true, waits())

        use(.de)
        try RenderGallery.render("mika10-quiz-faux-de", width: 375, night: true, quiz(right: false))

        use(.ar)
        try RenderGallery.render("mika10-quiz-juste-ar", night: true, quiz(right: true).environment(\.layoutDirection, .rightToLeft))
        try RenderGallery.render("mika10-moments-ar", night: true, moments().environment(\.layoutDirection, .rightToLeft))
    }
}

/// La gerbe de confettis d'une fête à un instant donné, autour de Mika les bras levés.
private struct MikaBurstPreview: View {
    let progress: Double
    let width: CGFloat

    var body: some View {
        let framing = MikaFraming.full.burst
        let scale = width / (framing.window.width + framing.bleedSide * 2)
        let size = framing.canvasSize(scale: scale)
        let toView = framing.toView(scale: scale)
        let pose = MikaMood.celebrate.beats[0].pose
        let moment = progress
        Canvas { context, _ in
            MikaArt.paint(MikaArt.scene(pose, palette: .marine), pose: pose, in: &context, toView: toView)
            MikaArt.paint(MikaArt.burst(moment, palette: .marine), pose: pose, in: &context, toView: toView)
        }
        .frame(width: size.width, height: size.height)
    }
}
