import SwiftData
import XCTest
@testable import Micabo

/// **Les supports et les modes de révision** (`docs/supports.md`) : ce qui se lit sur
/// l'appareil (diapos, page web, paquet collé), ce qui se construit depuis la leçon (écoute,
/// carte mentale, fiche PDF, deck), et la porte du gratuit.
@MainActor
final class SupportsTests: XCTestCase {
    // MARK: - Les diapositives

    /// Un ZIP minimal, entrées stockées sans compression : ce que `ZipArchive` sait lire.
    static func zip(_ files: [(String, String)]) -> Data {
        var archive = Data()
        var central = Data()
        func u16(_ value: Int) -> Data { withUnsafeBytes(of: UInt16(value).littleEndian) { Data($0) } }
        func u32(_ value: UInt32) -> Data { withUnsafeBytes(of: value.littleEndian) { Data($0) } }
        for (name, text) in files {
            let body = Data(text.utf8)
            let nameData = Data(name.utf8)
            let crc = crc32(body)
            let offset = UInt32(archive.count)
            archive += u32(0x0403_4b50) + u16(20) + u16(0) + u16(0) + u16(0) + u16(0)
            archive += u32(crc) + u32(UInt32(body.count)) + u32(UInt32(body.count))
            archive += u16(nameData.count) + u16(0) + nameData + body
            central += u32(0x0201_4b50) + u16(20) + u16(20) + u16(0) + u16(0) + u16(0) + u16(0)
            central += u32(crc) + u32(UInt32(body.count)) + u32(UInt32(body.count))
            central += u16(nameData.count) + u16(0) + u16(0) + u16(0) + u16(0) + u32(0) + u32(offset) + nameData
        }
        let centralOffset = UInt32(archive.count)
        archive += central
        archive += u32(0x0605_4b50) + u16(0) + u16(0) + u16(files.count) + u16(files.count)
        archive += u32(UInt32(central.count)) + u32(centralOffset) + u16(0)
        return archive
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xEDB8_8320 : crc >> 1
            }
        }
        return ~crc
    }

    static func slideXML(_ paragraphs: [String]) -> String {
        let body = paragraphs.map { "<a:p><a:r><a:t>\($0)</a:t></a:r></a:p>" }.joined()
        return #"<?xml version="1.0" encoding="UTF-8"?><p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody>"#
            + body + "</p:txBody></p:sp></p:spTree></p:cSld></p:sld>"
    }

    static var samplePresentation: Data {
        zip([
            ("[Content_Types].xml", "<Types/>"),
            ("ppt/slides/slide10.xml", slideXML(["Conclusion", "La chlorophylle capte la lumière"])),
            ("ppt/slides/slide1.xml", slideXML(["La photosynthèse", "Un cours de SVT"])),
            ("ppt/slides/_rels/slide1.xml.rels", "<Relationships/>"),
            ("ppt/slides/slide2.xml", slideXML(["Les deux phases", "Phase claire &amp; phase sombre"])),
            ("ppt/notesSlides/notesSlide2.xml", slideXML(["La phase claire a lieu dans les thylakoïdes.", "2"])),
        ])
    }

    func testSlidesAreReadInSlideshowOrderWithTheirNotes() throws {
        let slides = try SlidesImportService.slides(in: Self.samplePresentation)
        XCTAssertEqual(slides.map(\.number), [1, 2, 10], "l'ordre des numéros, pas celui de l'archive")
        XCTAssertEqual(slides[0].text, "La photosynthèse\nUn cours de SVT")
        XCTAssertEqual(slides[1].text, "Les deux phases\nPhase claire & phase sombre")
        XCTAssertEqual(slides[1].notes, "La phase claire a lieu dans les thylakoïdes.", "le numéro seul des notes est retiré")
        XCTAssertEqual(slides[2].notes, "")

        let document = try SlidesImportService.extract(data: Self.samplePresentation, fileName: "SVT")
        XCTAssertEqual(document.pageCount, 3)
        XCTAssertEqual(document.fileName, "SVT")
        XCTAssertEqual(document.source, .pdf)
        XCTAssertTrue(document.text.hasPrefix("— 1 —\nLa photosynthèse"))
        XCTAssertTrue(document.text.contains("thylakoïdes"))
        let first = try XCTUnwrap(document.text.range(of: "photosynthèse"))
        let last = try XCTUnwrap(document.text.range(of: "Conclusion"))
        XCTAssertLessThan(first.lowerBound, last.lowerBound)
    }

    func testSomethingElseThanSlidesSaysWhy() {
        XCTAssertThrowsError(try SlidesImportService.extract(data: Data("pas un zip".utf8), fileName: "x")) { error in
            XCTAssertEqual(error as? SlidesImportService.ImportError, .unreadable)
        }
        let empty = Self.zip([("ppt/slides/slide1.xml", Self.slideXML([""]))])
        XCTAssertThrowsError(try SlidesImportService.extract(data: empty, fileName: "x")) { error in
            XCTAssertEqual(error as? SlidesImportService.ImportError, .empty)
        }
        XCTAssertThrowsError(try SlidesImportService.extract(from: URL(fileURLWithPath: "/tmp/cours.key"))) { error in
            XCTAssertEqual(error as? SlidesImportService.ImportError, .keynote)
        }
        XCTAssertFalse(L10n.t("ios.sup.slides.keynote", locale: .de).isEmpty)
    }

    // MARK: - Le paquet collé

    func testQuizletExportWithTabs() {
        let result = FlashcardPaste.parse("Mitose\tDivision d'une cellule en deux\nMéiose\tDivision qui donne quatre cellules\n\nADN\tMolécule qui porte\nl'information génétique\n")
        XCTAssertEqual(result.cards.count, 3)
        XCTAssertEqual(result.cards[0], FlashcardPaste.Card(front: "Mitose", back: "Division d'une cellule en deux"))
        XCTAssertEqual(result.cards[2].back, "Molécule qui porte\nl'information génétique", "une définition sur deux lignes reste une carte")
        XCTAssertEqual(result.skipped, 0)
    }

    func testOtherSeparatorsAndLeftovers() {
        let dashes = FlashcardPaste.parse("1789 - Prise de la Bastille\n1815 - Waterloo\nTitre sans définition")
        XCTAssertEqual(dashes.cards.map(\.front), ["1789", "1815"])
        XCTAssertEqual(dashes.cards[1].back, "Waterloo\nTitre sans définition")

        let colon = FlashcardPaste.parse("rouge: red\nbleu: blue\nvert:")
        XCTAssertEqual(colon.cards.count, 2)
        XCTAssertEqual(colon.skipped, 1)

        let csv = FlashcardPaste.parse("\"chat\",\"cat\"\n\"chien\",\"dog\"")
        XCTAssertEqual(csv.cards, [FlashcardPaste.Card(front: "chat", back: "cat"), FlashcardPaste.Card(front: "chien", back: "dog")])

        XCTAssertTrue(FlashcardPaste.parse("rien à lire ici").cards.isEmpty)
        XCTAssertEqual(FlashcardPaste.separator(for: ["a\tb, c", "d\te"]), "\t", "la tabulation gagne")
    }

    // MARK: - La réponse dite

    func testSpokenAnswersAreComparedTolerantly() {
        XCTAssertEqual(SpokenAnswer.judge(heard: "c'est la photo synthèse", expected: "La photosynthèse").verdict, .right)
        XCTAssertEqual(SpokenAnswer.judge(heard: "la chlorophylle capte la lumiere", expected: "La chlorophylle capte la lumière du soleil").verdict, .right)
        XCTAssertEqual(SpokenAnswer.judge(heard: "en 1989", expected: "1989").verdict, .right)
        XCTAssertEqual(SpokenAnswer.judge(heard: "en 1991", expected: "1989").verdict, .missed)
        XCTAssertEqual(SpokenAnswer.judge(heard: "des mitochondries", expected: "La mitochondrie").verdict, .right, "un pluriel")
        XCTAssertEqual(SpokenAnswer.judge(heard: "Truman", expected: "Truman").verdict, .right)
        XCTAssertEqual(SpokenAnswer.judge(heard: "trumen", expected: "Truman").verdict, .right, "une faute de reconnaissance")

        let partial = SpokenAnswer.judge(heard: "les États-Unis et l'URSS s'opposent", expected: "Les États-Unis et l'URSS s'opposent sans guerre directe")
        XCTAssertEqual(partial.verdict, .close)
        XCTAssertTrue(partial.matched.contains("urss"))
        XCTAssertTrue(partial.missing.contains("guerre"))
        XCTAssertEqual(SpokenAnswer.judge(heard: "les États-Unis", expected: "Les États-Unis et l'URSS s'opposent sans guerre directe").verdict, .missed, "deux mots sur sept")

        XCTAssertEqual(SpokenAnswer.judge(heard: "aucune idée", expected: "La guerre froide").verdict, .missed)
        XCTAssertEqual(SpokenAnswer.judge(heard: "", expected: "La guerre froide").verdict, .missed)
    }

    func testKeywordsLeaveOutLittleWords() {
        XCTAssertEqual(SpokenAnswer.keywords("La prise de la Bastille"), ["prise", "bastille"])
        XCTAssertEqual(SpokenAnswer.keywords("Die Teilung der Zelle"), ["teilung", "zelle"])
        XCTAssertEqual(SpokenAnswer.keywords("le"), ["le"], "une réponse faite de petits mots les garde")
        XCTAssertEqual(SpokenAnswer.distance("chat", "chats", limit: 2), 1)
        XCTAssertGreaterThan(SpokenAnswer.distance("photosynthese", "respiration", limit: 2), 2)
    }

    // MARK: - La carte mentale

    static let notes = ThemeNotes(
        oneLiner: "Deux blocs s'opposent.",
        blocks: [
            .subtitle("Deux visions du monde"),
            .list(["Le **capitalisme** américain", "Le communisme soviétique"]),
            .paragraph("Un long paragraphe qui ne fait pas une notion."),
            .definition(term: "Rideau de fer", text: "La frontière qui coupe l'Europe."),
            .dates([NoteBlock.DateItem(date: "1961", text: "Construction du mur")]),
            .formula(latex: "E = mc^2", caption: nil),
        ],
        takeaways: ["La guerre froide dure de 1947 à 1991."]
    )

    static let digest = LessonDigest(
        title: "La guerre froide",
        subject: "Histoire",
        takeaways: ["Deux blocs, jamais de guerre directe."],
        themes: [
            LessonDigest.Theme(title: "Deux blocs face à face", notes: notes, cards: []),
            LessonDigest.Theme(title: "Le vocabulaire", notes: nil, cards: [(front: "OTAN", back: "Alliance de l'Ouest"), (front: "Pacte de Varsovie", back: "Alliance de l'Est")]),
        ]
    )

    func testMindMapTreeFromNotesAndCards() {
        let root = MindMap.build(Self.digest)
        XCTAssertEqual(root.title, "La guerre froide")
        XCTAssertEqual(root.level, .root)
        XCTAssertEqual(root.children.map(\.title), ["Deux blocs face à face", "Le vocabulaire"])

        let first = root.children[0]
        XCTAssertEqual(first.children.map(\.title), ["Deux visions du monde", "Rideau de fer", "1961"])
        XCTAssertEqual(first.children[0].children.map(\.title), ["Le capitalisme américain", "Le communisme soviétique"], "la liste se range sous son sous-titre, sans balisage")
        XCTAssertEqual(first.children[1].children.map(\.title), ["La frontière qui coupe l'Europe."])
        XCTAssertEqual(root.children[1].children.map(\.title), ["OTAN", "Pacte de Varsovie"], "sans notes, les cartes font les notions")

        var ids: Set<String> = []
        func collect(_ node: MindMapNode) {
            XCTAssertFalse(ids.contains(node.id), node.id)
            ids.insert(node.id)
            node.children.forEach(collect)
        }
        collect(root)
        XCTAssertEqual(ids.count, root.count)
    }

    func testMindMapLimitsAndClips() {
        let long = String(repeating: "mot ", count: 60)
        let notes = ThemeNotes(oneLiner: "", blocks: (0..<20).map { .subtitle("Notion \($0) \(long)") }, takeaways: [])
        let root = MindMap.build(LessonDigest(title: "T", themes: [LessonDigest.Theme(title: "A", notes: notes, cards: [])]))
        XCTAssertEqual(root.children[0].children.count, MindMap.maximumNotions)
        XCTAssertLessThanOrEqual(root.children[0].children[0].title.count, MindMap.maximumLength)
        XCTAssertTrue(root.children[0].children[0].title.hasSuffix("…"))

        let onlyTakeaways = ThemeNotes(oneLiner: "Une phrase.", blocks: [.paragraph("Rien d'autre.")], takeaways: ["À retenir"])
        let fallback = MindMap.build(LessonDigest(title: "T", themes: [LessonDigest.Theme(title: "A", notes: onlyTakeaways, cards: [])]))
        XCTAssertEqual(fallback.children[0].children.map(\.title), ["À retenir"])
    }

    // MARK: - L'écoute

    func testListeningScriptReadsTheNotesChapterByChapter() {
        let script = ListeningScript(digest: Self.digest, locale: .fr)
        XCTAssertEqual(script.chapters.count, 3, "deux thèmes, puis l'essentiel de la leçon")
        XCTAssertEqual(script.chapters[0].lines.first, "Deux blocs face à face")
        XCTAssertTrue(script.chapters[0].lines.contains("Le capitalisme américain"), "sans les étoiles du gras")
        XCTAssertTrue(script.chapters[0].lines.contains("Rideau de fer. La frontière qui coupe l'Europe."))
        XCTAssertFalse(script.chapters[0].lines.contains { $0.contains("mc^2") }, "une formule sans légende ne se lit pas")
        XCTAssertTrue(script.chapters[0].lines.contains("À retenir"))
        XCTAssertEqual(script.chapters[1].lines, ["Le vocabulaire", "OTAN. Alliance de l'Ouest", "Pacte de Varsovie. Alliance de l'Est"])
        XCTAssertEqual(script.chapters[2].title, L10n.t("ios.sup.listen.takeaways", locale: .fr))
        XCTAssertGreaterThanOrEqual(script.minutes(), 1)
        XCTAssertEqual(ListeningScript.sentences("Une phrase. Une autre ! Et la fin ?").count, 3)
        XCTAssertEqual(ListenPlayerCard.rateLabel(1), "1×")
    }

    func testSpeakerRatesStayInTheSynthesizerRange() {
        XCTAssertLessThan(LessonSpeaker.utteranceRate(for: 1), LessonSpeaker.utteranceRate(for: 1.5))
        XCTAssertLessThanOrEqual(LessonSpeaker.utteranceRate(for: 1.5), 0.75)
    }

    // MARK: - Le deck sans génération

    func testADeckIsSplitIntoPartsWithQuizzesDrawnFromItsCards() {
        let cards = (1...30).map { DeckLessonBuilder.Card(front: "Mot \($0)", back: "Sens \($0)") }
        let parts = DeckLessonBuilder.parts(of: cards, locale: .fr)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.map(\.cards.count), [10, 10, 10])
        XCTAssertEqual(parts[0].title, "Partie 1")
        XCTAssertEqual(parts[0].notes.blocks.count, 10)
        XCTAssertEqual(parts[0].notes.oneLiner, "10 cartes à connaître.")
        for part in parts {
            XCTAssertEqual(part.questions.count, DeckLessonBuilder.questionsPerPart)
            for question in part.questions {
                XCTAssertEqual(question.choices.count, 4)
                XCTAssertEqual(Set(question.choices).count, 4, "quatre propositions différentes")
                let card = part.cards.first { $0.front == question.prompt || $0.back == question.prompt }
                let expected = card.map { $0.front == question.prompt ? $0.back : $0.front }
                XCTAssertEqual(question.choices[question.answer], expected)
            }
        }

        let small = DeckLessonBuilder.parts(of: Array(cards.prefix(3)), locale: .fr)
        XCTAssertEqual(small.count, 1)
        XCTAssertEqual(small[0].title, "Toutes les cartes")
        XCTAssertTrue(small[0].questions.isEmpty, "sans trois autres réponses, pas de QCM")
    }

    func testAnImportedDeckBecomesALessonWithoutTheModel() throws {
        let container = try ModelContainer(
            for: Course.self, CourseFolder.self, Chapter.self, Flashcard.self, ReviewLog.self, Exam.self, OffDay.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let cards = (1...14).map { DeckLessonBuilder.Card(front: "Verbe \($0)", back: "Verb \($0)") }
        let course = try DeckLessonBuilder.make(title: "Vocabulaire", cards: cards, in: context)
        XCTAssertEqual(course.source, .deck)
        XCTAssertTrue(course.isLesson)
        XCTAssertEqual(course.cards.count, 14)
        XCTAssertEqual(course.orderedChapters.count, 2)
        XCTAssertTrue(course.orderedChapters.allSatisfy { $0.notes != nil && ($0.quiz?.questions.isEmpty == false) })
        XCTAssertFalse(LessonAllowance.hasUsedFreeLesson(courses: [course]), "un paquet ne consomme pas la leçon offerte")
        let session = LessonSession(course: course)
        XCTAssertGreaterThan(session.totalCount, 2)
    }

    // MARK: - La page web

    func testAWebPageLosesItsDecorAndKeepsItsArticle() {
        let html = """
        <html><head><title>Accueil | Site</title>
        <meta property="og:title" content="La photosynth&egrave;se expliqu&#233;e">
        <style>body { color: red }</style><script>var x = "<p>non</p>";</script></head>
        <body><nav><a href="/">Menu</a><a>Contact</a></nav>
        <header>Bandeau</header>
        <article><h1>La photosynthèse</h1>
        <p>La plante capte la lumi&egrave;re&nbsp;et fabrique sa mati&#xE8;re. \(String(repeating: "Le texte continue longuement. ", count: 20))</p>
        <ul><li>Phase claire</li><li>Phase sombre</li></ul></article>
        <footer>© 2026</footer></body></html>
        """
        let page = WebPageText.extract(html: html)
        XCTAssertEqual(page.title, "La photosynthèse expliquée")
        XCTAssertTrue(page.text.hasPrefix("La photosynthèse"))
        XCTAssertTrue(page.text.contains("La plante capte la lumière et fabrique sa matière."))
        XCTAssertTrue(page.text.contains("• Phase claire"))
        for noise in ["Menu", "Contact", "Bandeau", "© 2026", "color: red", "var x", "<"] {
            XCTAssertFalse(page.text.contains(noise), noise)
        }
    }

    func testWebLinksAreRecognized() {
        XCTAssertEqual(WebPageImportService.url(from: "fr.wikipedia.org/wiki/Photosynthèse")?.host, "fr.wikipedia.org")
        XCTAssertEqual(WebPageImportService.url(from: "Regarde ça : https://www.example.com/cours")?.host, "www.example.com")
        XCTAssertNil(WebPageImportService.url(from: "pas un lien"))
        XCTAssertNil(WebPageImportService.url(from: "ftp://example.com"))
        XCTAssertNil(WebPageImportService.url(from: ""))
        XCTAssertEqual(WebPageText.decodeEntities("&laquo;&#160;oui&#xA0;&raquo; &amp; &unknown;"), "«\u{00A0}oui\u{00A0}» & &unknown;")
    }

    // MARK: - La barre et la porte

    func testNewSourcesTravelByTheRoutesTheServerKnows() {
        let composer = LessonComposer()
        let expected: [(LessonComposer.Kind, LessonSourceKind)] = [(.web, .text), (.slides, .pdf), (.handwriting, .photo), (.lecture, .audio)]
        for (kind, source) in expected {
            let id = composer.begin(kind, title: kind.rawValue)!
            composer.finish(id, with: ImportedDocument(text: String(repeating: "Un texte de cours. ", count: 20), pageImages: [], coverImage: nil, pageCount: 1, fileName: "x", source: .text, extractionNote: nil))
            XCTAssertEqual(LessonComposer.sourceKind(of: composer.supports.last!), source, kind.rawValue)
        }
        for kind in LessonComposer.Kind.allCases {
            XCTAssertFalse(LessonAllowance.locksImport(kind, isPro: false, freeLessonLeft: true), "aucune couronne sur un support")
            for locale in UiLocale.allCases {
                XCTAssertNotEqual(L10n.t(kind.titleKey, locale: locale), kind.titleKey, "\(locale) \(kind)")
                XCTAssertNotEqual(L10n.t(kind.subtitleKey, locale: locale), kind.subtitleKey, "\(locale) \(kind)")
            }
        }
        XCTAssertEqual(Set(HomeSourcesSheet.grid.flatMap { $0 }).count, 9)
        XCTAssertFalse(HomeSourcesSheet.grid.flatMap { $0 }.contains(.flashcards), "les flashcards sont à part")
    }

    func testListenAndMindMapAreFreeVoiceHasOneFreeSessionExportIsPro() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "supports-tests"))
        defaults.removePersistentDomain(forName: "supports-tests")
        defer { defaults.removePersistentDomain(forName: "supports-tests") }

        XCTAssertNil(RevisionModeAllowance.gate(.listen, isPro: false, defaults: defaults))
        XCTAssertNil(RevisionModeAllowance.gate(.mindMap, isPro: false, defaults: defaults))
        XCTAssertNil(RevisionModeAllowance.gate(.voice, isPro: false, defaults: defaults), "la première séance est offerte")
        XCTAssertEqual(RevisionModeAllowance.gate(.export, isPro: false, defaults: defaults), .exportSheet)
        RevisionModeAllowance.noteVoiceSession(defaults: defaults)
        XCTAssertEqual(RevisionModeAllowance.gate(.voice, isPro: false, defaults: defaults), .voiceRecall)
        for mode in RevisionMode.allCases {
            XCTAssertNil(RevisionModeAllowance.gate(mode, isPro: true, defaults: defaults))
            XCTAssertFalse(RevisionModeAllowance.showsProBadge(mode, isPro: true))
        }
        XCTAssertFalse(PaywallTrigger.voiceRecall.headline.isEmpty)
        XCTAssertNotEqual(PaywallTrigger.exportSheet.headline, "ios.sup.paywall.export")
    }

    // MARK: - La fiche en PDF

    func testTheSheetExportsAsAPDF() throws {
        let data = SheetExporter.render(Self.digest, locale: .fr)
        XCTAssertTrue(data.starts(with: Array("%PDF".utf8)))
        XCTAssertGreaterThan(data.count, 1_000)
        XCTAssertEqual(SheetExporter.fileName(for: "Chapitre 3 : la cellule / SVT"), "Chapitre 3 la cellule SVT")
        let url = try SheetExporter.export(Self.digest, locale: .ar)
        XCTAssertEqual(url.pathExtension, "pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }
}
