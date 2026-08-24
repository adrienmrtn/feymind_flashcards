import Foundation
import XCTest
@testable import Micabo

/// L'analyse d'un lien, faite sur l'appareil avant tout appel.
final class YouTubeLinkTests: XCTestCase {
    func testEveryShapeOfYouTubeLinkIsRecognized() {
        let expected = "dQw4w9WgXcQ"
        let links = [
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtube.com/watch?v=dQw4w9WgXcQ",
            "http://m.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://www.youtube.com/shorts/dQw4w9WgXcQ",
            "https://www.youtube.com/embed/dQw4w9WgXcQ",
            "https://www.youtube.com/live/dQw4w9WgXcQ",
            "https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ",
            // Collé depuis l'application YouTube : la vidéo est noyée dans les paramètres.
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=42s&list=PLabc&feature=share",
            "youtube.com/watch?v=dQw4w9WgXcQ",
            "  https://youtu.be/dQw4w9WgXcQ?t=90  "
        ]

        for link in links {
            XCTAssertEqual(YouTubeLink.videoID(from: link), expected, "Lien refusé à tort : \(link)")
        }
    }

    func testWhatIsNotAYouTubeVideoIsRefused() {
        let links = [
            "",
            "   ",
            "bonjour",
            "https://vimeo.com/123456789",
            "https://www.dailymotion.com/video/x8abcde",
            "https://www.youtube.com",
            "https://www.youtube.com/watch",
            "https://www.youtube.com/@unechaine",
            "https://www.youtube.com/playlist?list=PLabcdefghij",
            // Onze caractères ne font pas un lien : l'utilisateur croirait avoir collé une URL.
            "dQw4w9WgXcQ",
            // Un identifiant tronqué reste un identifiant faux.
            "https://youtu.be/dQw4w9Wg",
            "https://notyoutube.com/watch?v=dQw4w9WgXcQ"
        ]

        for link in links {
            XCTAssertNil(YouTubeLink.videoID(from: link), "Lien accepté à tort : \(link)")
        }
    }

    /// Le domaine doit être exactement le bon : un sous-domaine qui finit par « youtube.com »
    /// n'appartient pas à YouTube.
    func testLookalikeHostsAreRefused() {
        XCTAssertNil(YouTubeLink.videoID(from: "https://youtube.com.evil.tld/watch?v=dQw4w9WgXcQ"))
        XCTAssertNil(YouTubeLink.videoID(from: "https://myyoutube.com/watch?v=dQw4w9WgXcQ"))
    }
}

/// Les cinq refus, et leurs phrases. Ce sont elles que l'utilisateur lit : ce test les
/// verrouille au mot près.
final class YouTubeImportErrorTests: XCTestCase {
    func testEachRefusalHasItsExactSentence() {
        XCTAssertEqual(
            YouTubeImportError.invalidLink.errorDescription,
            "Ce lien n'est pas une vidéo YouTube."
        )
        XCTAssertEqual(
            YouTubeImportError.unavailable.errorDescription,
            "Cette vidéo n'est pas accessible."
        )
        XCTAssertEqual(
            YouTubeImportError.noCaptions.errorDescription,
            "Cette vidéo n'a pas de sous-titres. Micabo ne peut pas la lire."
        )
        XCTAssertEqual(
            YouTubeImportError.transcriptTooShort.errorDescription,
            "Cette vidéo est trop courte pour générer des cartes."
        )
    }

    /// Un refus qui ne dit pas jusqu'où on peut aller laisse essayer au hasard : la limite
    /// est annoncée, avec ou sans la durée mesurée.
    func testTooLongAlwaysAnnouncesTheLimit() {
        let known = YouTubeImportError.tooLong(duration: 134 * 60, limit: 90 * 60)
        XCTAssertEqual(
            known.errorDescription,
            "Cette vidéo dure 2 h 14. Micabo lit les vidéos jusqu'à 1 h 30."
        )

        let unknown = YouTubeImportError.tooLong(duration: 0, limit: 90 * 60)
        XCTAssertEqual(
            unknown.errorDescription,
            "Cette vidéo est trop longue. Micabo lit les vidéos jusqu'à 1 h 30."
        )
    }

    /// Le code du serveur décide, pas la forme de son message : celui-ci peut être
    /// reformulé côté serveur sans changer un mot dans l'application.
    func testServerCodesMapToTheRightRefusal() {
        let cases: [(String, YouTubeImportError)] = [
            ("invalid_url", .invalidLink),
            ("unavailable", .unavailable),
            ("no_captions", .noCaptions),
            ("too_short", .transcriptTooShort)
        ]

        for (code, expected) in cases {
            let error = YouTubeImportError(
                .server(status: 422, message: "peu importe le message", code: code)
            )
            XCTAssertEqual(error, expected, "Code mal traduit : \(code)")
        }
    }

    func testUnknownCodeFallsBackOnTheServerMessage() {
        let error = YouTubeImportError(
            .server(status: 500, message: "Panne inattendue.", code: "quelque_chose_de_neuf")
        )
        XCTAssertEqual(error.errorDescription, "Panne inattendue.")
    }

    /// « Réessayer » ne s'affiche que quand réessayer peut marcher. Une vidéo sans
    /// sous-titres n'en aura pas plus au second essai.
    func testRetryIsOnlyOfferedWhenItCanWork() {
        XCTAssertTrue(YouTubeImportError.network("délai dépassé").allowsRetry)
        XCTAssertTrue(YouTubeImportError.unavailable.allowsRetry)
        XCTAssertFalse(YouTubeImportError.noCaptions.allowsRetry)
        XCTAssertFalse(YouTubeImportError.transcriptTooShort.allowsRetry)
        XCTAssertFalse(YouTubeImportError.tooLong(duration: 0, limit: 90 * 60).allowsRetry)
        XCTAssertFalse(YouTubeImportError.invalidLink.allowsRetry)
    }
}

/// Ce que l'aperçu décide tout seul, sans rien télécharger.
final class YouTubeVideoTests: XCTestCase {
    private func video(
        duration: Int,
        limit: Int? = 90 * 60,
        captions: [YouTubeCaptionLanguage] = [
            YouTubeCaptionLanguage(code: "fr", name: "français", isAutomatic: false)
        ]
    ) -> YouTubeVideo {
        YouTubeVideo(
            id: "dQw4w9WgXcQ",
            title: "Le cycle de l'eau",
            author: "Chaîne SVT",
            durationSeconds: duration,
            thumbnailUrl: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
            limitSeconds: limit,
            captionLanguages: captions
        )
    }

    /// Le refus d'une vidéo trop longue se décide à l'aperçu, donc **avant** la
    /// transcription et avant toute génération.
    func testATooLongVideoIsBlockedFromThePreview() {
        let blocked = video(duration: 134 * 60).blockingReason
        XCTAssertEqual(blocked, .tooLong(duration: 134 * 60, limit: 90 * 60))
        XCTAssertNil(video(duration: 42 * 60).blockingReason)
    }

    func testAVideoWithoutCaptionsIsBlockedFromThePreview() {
        XCTAssertEqual(video(duration: 600, captions: []).blockingReason, .noCaptions)
    }

    /// La limite vient du serveur quand il l'envoie, de la constante locale sinon : un
    /// déploiement antérieur ne doit pas faire disparaître le garde.
    func testLimitFallsBackOnTheLocalConstant() {
        XCTAssertEqual(video(duration: 600, limit: nil).limit, YouTubeLimits.maximumDuration)
        XCTAssertEqual(video(duration: 600, limit: 3600).limit, 3600)
    }

    func testDurationIsWrittenAsAVideoDurationIsRead() {
        XCTAssertEqual(YouTubeDuration.label(for: 42), "1 min")
        XCTAssertEqual(YouTubeDuration.label(for: 12 * 60), "12 min")
        XCTAssertEqual(YouTubeDuration.label(for: 60 * 60), "1 h")
        XCTAssertEqual(YouTubeDuration.label(for: 107 * 60), "1 h 47")
        XCTAssertNil(YouTubeDuration.label(for: 0))
    }
}

/// Le choix de la piste : la langue de l'utilisateur d'abord, la piste par défaut ensuite,
/// et à langue égale l'écrit à la main plutôt que l'automatique.
final class YouTubeCaptionChoiceTests: XCTestCase {
    private let french = YouTubeCaptionLanguage(code: "fr", name: "français", isAutomatic: false)
    private let frenchAuto = YouTubeCaptionLanguage(code: "fr", name: "français (auto)", isAutomatic: true)
    private let english = YouTubeCaptionLanguage(code: "en", name: "English", isAutomatic: false)
    private let canadianFrench = YouTubeCaptionLanguage(code: "fr-CA", name: "français (Canada)", isAutomatic: false)

    private func video(_ captions: [YouTubeCaptionLanguage]) -> YouTubeVideo {
        YouTubeVideo(
            id: "dQw4w9WgXcQ",
            title: "T",
            author: "A",
            durationSeconds: 600,
            thumbnailUrl: "",
            limitSeconds: 90 * 60,
            captionLanguages: captions
        )
    }

    func testALanguageCodeMatchesItsRegionalVariants() {
        XCTAssertTrue(canadianFrench.matches("fr"))
        XCTAssertTrue(french.matches("fr-FR"))
        XCTAssertFalse(english.matches("fr"))
    }

    /// À langue égale, une piste écrite à la main passe devant une piste automatique : elle
    /// est ponctuée, et un texte ponctué donne de meilleures cartes.
    func testManualCaptionsWinOverAutomaticOnes() {
        let chosen = video([frenchAuto, english, french]).chosenCaption(languages: ["fr", "en"])
        XCTAssertEqual(chosen, french)
    }

    /// La langue passe avant tout : une piste automatique dans la bonne langue vaut mieux
    /// qu'une piste écrite à la main dans une autre.
    func testTheRightLanguageWinsOverTheBetterTrack() {
        let chosen = video([english, frenchAuto]).chosenCaption(languages: ["fr", "en"])
        XCTAssertEqual(chosen, frenchAuto)
    }

    /// La seconde langue de l'utilisateur sert quand la première est absente.
    func testTheSecondLanguageIsTried() {
        let chosen = video([english]).chosenCaption(languages: ["fr", "en"])
        XCTAssertEqual(chosen, english)
    }

    /// Aucune piste dans une langue de l'utilisateur : on prend celle qui est là, comme le
    /// serveur prend la piste par défaut, plutôt que de refuser une vidéo lisible.
    func testTheDefaultTrackIsUsedWhenNoLanguageMatches() {
        let german = YouTubeCaptionLanguage(code: "de", name: "Deutsch", isAutomatic: false)
        let chosen = video([german, english]).chosenCaption(languages: ["fr"])
        XCTAssertEqual(chosen, german)
    }

    func testNoCaptionsGivesNoChoice() {
        XCTAssertNil(video([]).chosenCaption(languages: ["fr"]))
    }

    /// Les langues envoyées au serveur viennent des réglages du téléphone, réduites à leur
    /// code de langue, sans doublon, et jamais vides.
    func testPreferredLanguagesAreLanguageCodes() {
        let languages = YouTubeImportService.preferredLanguages

        XCTAssertFalse(languages.isEmpty)
        XCTAssertEqual(Set(languages).count, languages.count, "Aucun doublon")
        for code in languages {
            XCTAssertFalse(code.contains("-"), "« \(code) » doit être un code de langue, pas une locale")
        }
    }
}

/// La transcription rejoint le pipeline des autres imports : une fois ici, une vidéo n'est
/// plus une vidéo.
final class YouTubeDocumentTests: XCTestCase {
    private let video = YouTubeVideo(
        id: "dQw4w9WgXcQ",
        title: "Le cycle de l'eau",
        author: "Chaîne SVT",
        durationSeconds: 12 * 60,
        thumbnailUrl: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        limitSeconds: 90 * 60,
        captionLanguages: [YouTubeCaptionLanguage(code: "fr", name: "français", isAutomatic: false)]
    )

    func testTheDocumentCarriesTheTranscriptAndTheVideoSource() {
        let transcript = YouTubeTranscript(
            text: String(repeating: "L'eau s'évapore, se condense, retombe. ", count: 20),
            languageCode: "fr",
            languageName: "français",
            isAutomatic: false
        )

        let document = YouTubeImportService.document(video: video, transcript: transcript, cover: nil)

        XCTAssertEqual(document.source, .youtube)
        XCTAssertEqual(document.fileName, "Le cycle de l'eau")
        XCTAssertEqual(document.text, transcript.text)
        XCTAssertTrue(document.hasUsableText)
        // Une transcription n'a pas de pages : rien ne doit partir au modèle de vision.
        XCTAssertTrue(document.pageImages.isEmpty)
    }

    /// Des sous-titres automatiques sont annoncés comme tels : ils ne sont pas ponctués, et
    /// l'utilisateur doit savoir d'où vient un texte irrégulier.
    func testAutomaticCaptionsAreAnnouncedInTheNote() {
        let automatic = YouTubeTranscript(
            text: "alors aujourd'hui on va parler du cycle de l'eau",
            languageCode: "fr",
            languageName: "français",
            isAutomatic: true
        )

        let note = YouTubeImportService
            .document(video: video, transcript: automatic, cover: nil)
            .extractionNote ?? ""

        XCTAssertTrue(note.contains("automatiques"), note)
        XCTAssertTrue(note.contains("12 min"), note)
    }

    /// Le titre de la vidéo tient lieu de nom de fichier ; sans titre, il reste un nom.
    func testAnUntitledVideoStillHasAName() {
        var untitled = video
        untitled.title = "   "

        let document = YouTubeImportService.document(
            video: untitled,
            transcript: YouTubeTranscript(text: "texte", languageCode: "fr", languageName: "français", isAutomatic: false),
            cover: nil
        )

        XCTAssertEqual(document.fileName, "Vidéo YouTube")
    }
}

/// La source vidéo dans le reste de l'app.
final class YouTubeSourceTests: XCTestCase {
    func testYouTubeIsASourceLikeTheOthers() {
        XCTAssertEqual(ImportKind.youtube.courseSource, .youtube)
        XCTAssertEqual(CourseSource.youtube.label, "YouTube")
        // Le brut est stocké en base : le renommer perdrait la source des cours déjà là.
        XCTAssertEqual(CourseSource.youtube.rawValue, "youtube")
    }

    /// Une source inconnue d'une version antérieure retombe sur le texte au lieu de
    /// casser la lecture du cours.
    func testAnUnknownStoredSourceFallsBack() {
        XCTAssertNil(CourseSource(rawValue: "tiktok"))
    }

    /// La transcription est trop courte : la phrase est celle de l'import vidéo, pas le
    /// message générique des documents.
    func testTooShortTranscriptUsesTheVideoSentence() {
        let failure = ImportReadiness.failure(
            text: "trois mots",
            hasImages: false,
            canEnableVision: false,
            kind: .youtube
        )

        XCTAssertEqual(failure?.message, "Cette vidéo est trop courte pour générer des cartes.")
    }
}
