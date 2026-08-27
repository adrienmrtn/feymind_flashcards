import Foundation
import UIKit

/// Le lien d'une vidéo YouTube.
///
/// L'analyse se fait **sur l'appareil**, avant tout appel : un lien mal collé, une adresse
/// Vimeo ou un morceau de texte se refusent sans réseau, et l'utilisateur a sa réponse au
/// moment où il lâche le champ. Les hôtes acceptés sont les mêmes que côté serveur, qui
/// revalide de son côté : la vérification client est un confort, pas une autorisation.
enum YouTubeLink {
    private static let allowedHosts: Set<String> = [
        "youtube.com",
        "m.youtube.com",
        "music.youtube.com",
        "youtube-nocookie.com",
        "youtu.be"
    ]

    /// Les chemins qui portent l'identifiant dans leur second segment.
    private static let pathPrefixes: Set<String> = ["shorts", "embed", "live", "v"]

    /// L'identifiant de la vidéo, ou `nil` si ce n'est pas un lien YouTube.
    ///
    /// Un identifiant collé seul est refusé : onze caractères alphanumériques peuvent être
    /// n'importe quoi, et l'utilisateur croirait avoir collé un lien.
    static func videoID(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.lowercased().hasPrefix("http") ? trimmed : "https://" + trimmed
        guard let components = URLComponents(string: normalized), let rawHost = components.host else {
            return nil
        }

        let lowered = rawHost.lowercased()
        let host = lowered.hasPrefix("www.") ? String(lowered.dropFirst(4)) : lowered
        guard allowedHosts.contains(host) else { return nil }

        let segments = components.path.split(separator: "/").map(String.init)
        let query = components.queryItems?.first { $0.name == "v" }?.value

        if host == "youtu.be" {
            return valid(segments.first)
        }
        if segments.first == "watch" {
            return valid(query)
        }
        if segments.count >= 2, pathPrefixes.contains(segments[0]) {
            return valid(segments[1])
        }
        return valid(query)
    }

    static func isValid(_ raw: String) -> Bool {
        videoID(from: raw) != nil
    }

    private static func valid(_ candidate: String?) -> String? {
        guard let candidate, candidate.count == 11 else { return nil }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        return candidate.unicodeScalars.allSatisfy(allowed.contains) ? candidate : nil
    }
}

/// Ce que Micabo accepte de lire dans une vidéo.
enum YouTubeLimits {
    /// Au delà, la transcription dépasse ce qu'un seul appel de génération peut lire.
    /// La même valeur est appliquée côté serveur : celle-ci sert à refuser sans appeler.
    static let maximumDuration: TimeInterval = 90 * 60
}

// MARK: - Modèles

struct YouTubeCaptionLanguage: Codable, Hashable {
    var code: String
    var name: String
    var isAutomatic: Bool
}

/// L'aperçu d'une vidéo, montré avant confirmation.
struct YouTubeVideo: Codable, Equatable, Identifiable {
    var id: String
    var title: String
    var author: String
    /// 0 quand la durée est inconnue, ce qui est le cas d'un direct.
    var durationSeconds: Int
    var thumbnailUrl: String
    /// Limite annoncée par le serveur. Absente d'un déploiement antérieur, auquel cas la
    /// constante locale fait foi.
    var limitSeconds: Int?
    var captionLanguages: [YouTubeCaptionLanguage]

    var duration: TimeInterval {
        TimeInterval(durationSeconds)
    }

    var limit: TimeInterval {
        limitSeconds.map { TimeInterval($0) } ?? YouTubeLimits.maximumDuration
    }

    var thumbnailURL: URL? {
        URL(string: thumbnailUrl)
    }

    /// « 12 min », « 1 h 47 ». Une durée de vidéo ne se lit pas en secondes.
    var durationLabel: String? {
        YouTubeDuration.label(for: duration)
    }

    /// La piste que Micabo lira, choisie selon la même règle que le serveur : la langue de
    /// l'utilisateur d'abord, écrite à la main plutôt qu'automatique, puis la première
    /// disponible. Les langues sont un paramètre et non une lecture directe des réglages,
    /// pour que la règle soit vérifiable sans dépendre de la langue du téléphone.
    func chosenCaption(
        languages: [String] = YouTubeImportService.preferredLanguages
    ) -> YouTubeCaptionLanguage? {
        for language in languages {
            if let manual = captionLanguages.first(where: { !$0.isAutomatic && $0.matches(language) }) {
                return manual
            }
            if let automatic = captionLanguages.first(where: { $0.isAutomatic && $0.matches(language) }) {
                return automatic
            }
        }
        return captionLanguages.first
    }

    /// Ce qui empêche de lire cette vidéo, s'il y a quelque chose.
    ///
    /// C'est ici, et pas dans une alerte lancée depuis le réseau, que les deux refus qui se
    /// voient à l'aperçu sont décidés : l'écran peut ainsi montrer la vidéo **et** dire
    /// pourquoi elle ne passe pas, avec sa durée réelle. Surtout, une vidéo trop longue est
    /// écartée sans qu'aucun appel de transcription ni de génération ne soit lancé.
    var blockingReason: YouTubeImportError? {
        if captionLanguages.isEmpty { return .noCaptions }
        if duration > limit { return .tooLong(duration: duration, limit: limit) }
        return nil
    }
}

extension YouTubeCaptionLanguage {
    /// Compare deux codes sur leur langue seule : « fr » vaut pour « fr-CA ».
    func matches(_ language: String) -> Bool {
        code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            == language.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
    }
}

struct YouTubeTranscript: Codable, Equatable {
    var text: String
    var languageCode: String
    var languageName: String
    var isAutomatic: Bool
}

/// Mise en forme d'une durée, la même à l'aperçu et dans les messages d'erreur.
enum YouTubeDuration {
    static func label(for duration: TimeInterval) -> String? {
        let total = Int(duration.rounded())
        guard total > 0 else { return nil }

        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours) h \(String(format: "%02d", minutes))" : "\(hours) h"
        }
        return "\(max(1, minutes)) min"
    }
}

// MARK: - Erreurs

/// Les refus de l'import vidéo, avec leur phrase.
///
/// Chaque cas correspond à un `code` renvoyé par l'Edge Function, et non à la forme de son
/// message : le serveur peut reformuler ses journaux sans que l'application change de
/// texte. Les phrases sont ici, en un seul endroit, parce que ce sont elles que
/// l'utilisateur lit.
enum YouTubeImportError: LocalizedError, Equatable {
    case invalidLink
    case unavailable
    case noCaptions
    case transcriptTooShort
    case tooLong(duration: TimeInterval, limit: TimeInterval)
    case notConfigured
    case network(String)
    case server(String)

    /// Traduit un refus du serveur. Un code inconnu retombe sur le message du serveur
    /// plutôt que sur une phrase inventée.
    init(_ error: SupabaseFunctionError) {
        switch error {
        case .notConfigured:
            self = .notConfigured
            return
        case .network(let detail):
            self = .network(detail)
            return
        case .invalidResponse:
            self = .server("La réponse n'a pas pu être lue. Réessaie.")
            return
        case .server(let status, let message, let code):
            switch code {
            case "invalid_url":
                self = .invalidLink
            case "unavailable":
                self = .unavailable
            case "no_captions":
                self = .noCaptions
            case "too_short":
                self = .transcriptTooShort
            case "too_long":
                self = .tooLong(duration: 0, limit: YouTubeLimits.maximumDuration)
            default:
                self = .server(YouTubeImportError.transportMessage(status: status, message: message))
            }
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidLink:
            "Ce lien n'est pas une vidéo YouTube."
        case .unavailable:
            "Cette vidéo n'est pas accessible."
        case .noCaptions:
            "Cette vidéo n'a pas de sous-titres. Micabo ne peut pas la lire."
        case .transcriptTooShort:
            "Cette vidéo est trop courte pour générer des cartes."
        case .tooLong(let duration, let limit):
            Self.tooLongMessage(duration: duration, limit: limit)
        case .notConfigured:
            "L'accès à l'IA n'est pas configuré. Renseigne l'URL Supabase dans Profil, Réglages."
        case .network(let detail):
            "Connexion impossible. \(detail)"
        case .server(let message):
            message
        }
    }

    /// Le titre de l'alerte. Il nomme le refus, le message l'explique : « Vidéo trop
    /// longue » au-dessus de « Cette vidéo dure 2 h 14 » se lit d'un coup d'œil.
    var failureTitle: String {
        switch self {
        case .invalidLink: "Lien invalide"
        case .unavailable: "Vidéo inaccessible"
        case .noCaptions: "Pas de sous-titres"
        case .transcriptTooShort: "Vidéo trop courte"
        case .tooLong: "Vidéo trop longue"
        case .notConfigured, .network, .server: "Lecture impossible"
        }
    }

    /// Vrai quand réessayer a une chance de marcher. Une vidéo sans sous-titres n'en aura
    /// pas plus au second essai : proposer « Réessayer » serait une fausse promesse.
    var allowsRetry: Bool {
        switch self {
        case .network, .server, .unavailable: true
        case .invalidLink, .noCaptions, .transcriptTooShort, .tooLong, .notConfigured: false
        }
    }

    /// La limite est **toujours** annoncée : un refus qui ne dit pas jusqu'où on peut aller
    /// laisse l'utilisateur essayer au hasard.
    private static func tooLongMessage(duration: TimeInterval, limit: TimeInterval) -> String {
        let ceiling = YouTubeDuration.label(for: limit) ?? "1 h 30"
        guard let measured = YouTubeDuration.label(for: duration) else {
            return "Cette vidéo est trop longue. Micabo lit les vidéos jusqu'à \(ceiling)."
        }
        return "Cette vidéo dure \(measured). Micabo lit les vidéos jusqu'à \(ceiling)."
    }

    private static func transportMessage(status: Int, message: String) -> String {
        if status == 404 {
            return "Fonction Supabase introuvable. Déploie youtube-transcript depuis supabase/functions."
        }
        if status == 401 || status == 403 {
            return "Clé Supabase refusée (\(status)). Vérifie la clé publique dans Réglages."
        }
        return message.nilIfBlank ?? "Le serveur a répondu \(status)."
    }
}

// MARK: - Service

/// Lit une vidéo YouTube en deux temps : l'aperçu, puis la transcription.
///
/// Le découpage n'est pas décoratif. L'aperçu répond aux questions qu'on se pose avant de
/// lancer quoi que ce soit — est-ce bien cette vidéo, a-t-elle des sous-titres, n'est-elle
/// pas trop longue — et il permet de **refuser une vidéo de trois heures avant de dépenser
/// un seul appel de génération**. La transcription ne part qu'après confirmation.
struct YouTubeImportService {
    var functions = SupabaseFunctions.shared

    private static let function = "youtube-transcript"

    /// Les langues de l'utilisateur, par ordre de préférence, réduites à leur code de
    /// langue : c'est ce que portent les pistes de sous-titres.
    static var preferredLanguages: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for identifier in Locale.preferredLanguages.prefix(6) {
            let code = Locale(identifier: identifier).language.languageCode?.identifier
                ?? String(identifier.prefix(2))
            guard !code.isEmpty, seen.insert(code).inserted else { continue }
            result.append(code)
        }
        return result.isEmpty ? ["fr"] : result
    }

    /// L'aperçu de la vidéo : titre, chaîne, durée, vignette, langues disponibles.
    ///
    /// L'aperçu ne refuse ni l'absence de sous-titres ni une durée hors limite : il les
    /// rapporte, et c'est `YouTubeVideo.blockingReason` qui les nomme. L'écran montre alors
    /// la vidéo et la raison, ce qui vaut mieux qu'une alerte sur un écran vide.
    ///
    /// L'appareil d'abord : YouTube bloque les IP de datacenter, pas celle du
    /// téléphone. Le serveur ne sert que de repli.
    func preview(link: String) async throws -> YouTubeVideo {
        guard let id = YouTubeLink.videoID(from: link) else { throw YouTubeImportError.invalidLink }

        if let local = try? await YouTubeOnDevice.preview(videoID: id) {
            return local
        }

        return try await call(payload: [
            "url": link,
            "languages": Self.preferredLanguages,
            "metadataOnly": true
        ], key: "video")
    }

    /// La transcription, après confirmation. Elle n'est demandée que sur un aperçu sans
    /// `blockingReason` : le serveur revérifie de son côté, il est seul à voir le texte.
    func transcript(link: String) async throws -> YouTubeTranscript {
        guard let id = YouTubeLink.videoID(from: link) else { throw YouTubeImportError.invalidLink }

        if let local = try? await YouTubeOnDevice.transcript(
            videoID: id,
            languages: Self.preferredLanguages
        ) {
            return local
        }

        return try await call(payload: [
            "url": link,
            "languages": Self.preferredLanguages
        ], key: "transcript")
    }

    /// La vignette, ramenée en JPEG pour servir de couverture au cours. Un échec n'est pas
    /// une erreur : le cours retombe sur sa tuile d'emoji, comme n'importe quel import.
    func cover(for video: YouTubeVideo) async -> Data? {
        guard let url = video.thumbnailURL else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            return ImagePrep.jpeg(image, maxDimension: 900, quality: 0.7)
        } catch {
            return nil
        }
    }

    private func call<T: Decodable>(payload: [String: Any], key: String) async throws -> T {
        do {
            let envelope = try await functions.post(Self.function, payload: payload)
            return try functions.decode(T.self, from: envelope, key: key)
        } catch let error as SupabaseFunctionError {
            throw YouTubeImportError(error)
        }
    }
}

// MARK: - Vers le pipeline d'import

extension YouTubeImportService {
    /// La vidéo transcrite, sous la forme que le reste de l'import connaît déjà.
    ///
    /// Une fois ici, une vidéo n'est plus une vidéo : c'est un document dont le texte a été
    /// obtenu autrement. Elle repart donc dans le pipeline d'un PDF, sans branche à elle,
    /// et c'est pour ça que la fiche puis les cartes marchent sans une ligne de plus.
    static func document(
        video: YouTubeVideo,
        transcript: YouTubeTranscript,
        cover: Data?
    ) -> ImportedDocument {
        ImportedDocument(
            text: transcript.text,
            pageImages: [],
            coverImage: cover,
            pageCount: 1,
            fileName: video.title.nilIfBlank ?? "Vidéo YouTube",
            source: .youtube,
            extractionNote: note(video: video, transcript: transcript)
        )
    }

    private static func note(video: YouTubeVideo, transcript: YouTubeTranscript) -> String {
        var parts: [String] = []
        let language = transcript.languageName.nilIfBlank ?? transcript.languageCode
        parts.append(transcript.isAutomatic
            ? "Sous-titres automatiques (\(language))"
            : "Sous-titres \(language)")
        if let duration = video.durationLabel { parts.append(duration) }
        parts.append("\(transcript.text.count) caractères lus")
        return parts.joined(separator: " · ")
    }
}

// MARK: - Lecture sur l'appareil

/// Le client Innertube iOS, exécuté **sur le téléphone**.
///
/// Même requête que l'Edge Function, mais l'IP n'est pas celle d'un
/// datacenter : YouTube rend les pistes, et `timedtext` suit.
enum YouTubeOnDevice {
    private static let playerURL = URL(
        string: "https://www.youtube.com/youtubei/v1/player?key=AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8&prettyPrint=false"
    )!
    private static let userAgent =
        "com.google.ios.youtube/20.10.38 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)"
    private static let minimumCharacters = 400

    static func preview(videoID: String) async throws -> YouTubeVideo {
        let player = try await fetchPlayer(videoID: videoID, language: YouTubeImportService.preferredLanguages.first ?? "fr")
        return try video(from: player, videoID: videoID)
    }

    static func transcript(videoID: String, languages: [String]) async throws -> YouTubeTranscript {
        let player = try await fetchPlayer(videoID: videoID, language: languages.first ?? "fr")
        let tracks = captionTracks(from: player)
        guard !tracks.isEmpty else { throw YouTubeImportError.noCaptions }

        let ordered = orderedTracks(tracks, languages: languages)
        var longest: YouTubeTranscript?

        for track in ordered {
            guard let text = await captionText(from: track.baseURL), !text.isEmpty else { continue }
            let result = YouTubeTranscript(
                text: text,
                languageCode: track.code,
                languageName: track.name,
                isAutomatic: track.isAutomatic
            )
            if text.count >= minimumCharacters { return result }
            if longest == nil || text.count > (longest?.text.count ?? 0) {
                longest = result
            }
        }

        if let longest { return longest }
        throw YouTubeImportError.noCaptions
    }

    private static func fetchPlayer(videoID: String, language: String) async throws -> [String: Any] {
        var request = URLRequest(url: playerURL)
        request.httpMethod = "POST"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("5", forHTTPHeaderField: "X-YouTube-Client-Name")
        request.setValue("20.10.38", forHTTPHeaderField: "X-YouTube-Client-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "videoId": videoID,
            "contentCheckOk": true,
            "racyCheckOk": true,
            "context": [
                "client": [
                    "clientName": "IOS",
                    "clientVersion": "20.10.38",
                    "deviceMake": "Apple",
                    "deviceModel": "iPhone16,2",
                    "osName": "iPhone",
                    "osVersion": "18.3.2.22D82",
                    "hl": language,
                    "gl": "FR"
                ]
            ]
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw YouTubeImportError.unavailable
        }
        guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw YouTubeImportError.unavailable
        }
        let status = ((parsed["playabilityStatus"] as? [String: Any])?["status"] as? String) ?? "OK"
        guard status == "OK", parsed["videoDetails"] is [String: Any] else {
            throw YouTubeImportError.unavailable
        }
        return parsed
    }

    private static func video(from player: [String: Any], videoID: String) throws -> YouTubeVideo {
        guard let details = player["videoDetails"] as? [String: Any] else {
            throw YouTubeImportError.unavailable
        }
        let tracks = captionTracks(from: player)
        let seconds = Int(details["lengthSeconds"] as? String ?? "") ?? 0
        return YouTubeVideo(
            id: videoID,
            title: (details["title"] as? String).flatMap { $0.nilIfBlank } ?? "Vidéo YouTube",
            author: details["author"] as? String ?? "",
            durationSeconds: seconds,
            thumbnailUrl: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg",
            limitSeconds: Int(YouTubeLimits.maximumDuration),
            captionLanguages: tracks.map {
                YouTubeCaptionLanguage(code: $0.code, name: $0.name, isAutomatic: $0.isAutomatic)
            }
        )
    }

    private struct Track {
        var code: String
        var name: String
        var isAutomatic: Bool
        var isDefault: Bool
        var baseURL: String
    }

    private static func captionTracks(from player: [String: Any]) -> [Track] {
        let renderer = ((player["captions"] as? [String: Any])?
            ["playerCaptionsTracklistRenderer"] as? [String: Any])
        let raw = renderer?["captionTracks"] as? [[String: Any]] ?? []
        let defaultIndex = renderer?["defaultCaptionTrackIndex"] as? Int ?? 0

        return raw.enumerated().compactMap { index, track in
            guard let baseURL = track["baseUrl"] as? String, !baseURL.isEmpty,
                  let code = track["languageCode"] as? String, !code.isEmpty else { return nil }
            let name = ((track["name"] as? [String: Any])?["simpleText"] as? String) ?? code
            return Track(
                code: code,
                name: name,
                isAutomatic: (track["kind"] as? String) == "asr",
                isDefault: index == defaultIndex,
                baseURL: baseURL
            )
        }
    }

    private static func orderedTracks(_ tracks: [Track], languages: [String]) -> [Track] {
        var seen = Set<String>()
        var result: [Track] = []
        for language in languages {
            if let manual = tracks.first(where: { !$0.isAutomatic && sameLanguage($0.code, language) }) {
                if seen.insert(manual.baseURL).inserted { result.append(manual) }
            }
            if let automatic = tracks.first(where: { $0.isAutomatic && sameLanguage($0.code, language) }) {
                if seen.insert(automatic.baseURL).inserted { result.append(automatic) }
            }
        }
        for track in tracks where seen.insert(track.baseURL).inserted {
            result.append(track)
        }
        return result
    }

    private static func sameLanguage(_ a: String, _ b: String) -> Bool {
        a.split(whereSeparator: { $0 == "-" || $0 == "_" }).first?.lowercased()
            == b.split(whereSeparator: { $0 == "-" || $0 == "_" }).first?.lowercased()
    }

    private static func captionText(from baseURL: String) async -> String? {
        if let json = await fetch(baseURL, format: "json3"),
           let text = YouTubeCaptionText.fromJSON3(json), !text.isEmpty {
            return text
        }
        if let xml = await fetch(baseURL, format: nil),
           let text = YouTubeCaptionText.fromXML(xml), !text.isEmpty {
            return text
        }
        if let vtt = await fetch(baseURL, format: "vtt"),
           let text = YouTubeCaptionText.fromVTT(vtt), !text.isEmpty {
            return text
        }
        return nil
    }

    private static func fetch(_ baseURL: String, format: String?) async -> String? {
        guard var components = URLComponents(string: baseURL) else { return nil }
        var items = components.queryItems ?? []
        items.removeAll { $0.name == "fmt" }
        if let format {
            items.append(URLQueryItem(name: "fmt", value: format))
        }
        components.queryItems = items
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}

/// Les trois formats de sous-titres, pour les tests autant que pour le réseau.
enum YouTubeCaptionText {
    static func fromJSON3(_ raw: String) -> String? {
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{"),
              let data = raw.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let events = parsed["events"] as? [[String: Any]] else { return nil }

        var lines: [String] = []
        for event in events {
            if event["aAppend"] as? Int == 1 { continue }
            let segments = event["segs"] as? [[String: Any]] ?? []
            let line = segments
                .compactMap { $0["utf8"] as? String }
                .joined()
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { lines.append(line) }
        }
        return clean(lines)
    }

    static func fromXML(_ xml: String) -> String? {
        guard xml.range(of: "<(?:timedtext|transcript|text)\\b", options: .regularExpression) != nil else {
            return nil
        }
        let regex = try? NSRegularExpression(pattern: "<(?:text|p)\\b[^>]*>([\\s\\S]*?)</(?:text|p)>")
        let full = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        let lines = regex?.matches(in: xml, range: full).compactMap { match -> String? in
            guard let range = Range(match.range(at: 1), in: xml) else { return nil }
            let stripped = xml[range].replacingOccurrences(
                of: "<[^>]+>",
                with: " ",
                options: .regularExpression
            )
            let line = decode(stripped).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return line.isEmpty ? nil : line
        } ?? []
        return clean(lines)
    }

    static func fromVTT(_ vtt: String) -> String? {
        var body = vtt
        if let prefix = body.range(of: "^\\u{FEFF}?WEBVTT[^\\n]*", options: .regularExpression) {
            body.removeSubrange(prefix)
        }
        let lines = body.components(separatedBy: "\n\n").compactMap { block -> String? in
            let spoken = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { line in
                    !line.isEmpty
                        && !line.contains("-->")
                        && line.range(of: "^\\d+$", options: .regularExpression) == nil
                        && line.range(of: "^kind:", options: [.regularExpression, .caseInsensitive]) == nil
                        && line.range(of: "^language:", options: [.regularExpression, .caseInsensitive]) == nil
                }
                .joined(separator: " ")
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return spoken.isEmpty ? nil : spoken
        }
        return clean(lines)
    }

    private static func clean(_ lines: [String]) -> String {
        var kept: [String] = []
        for raw in lines {
            let line = decode(raw)
                .replacingOccurrences(of: "\\[[^\\]\\n]{1,25}\\]", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if kept.last == line { continue }
            kept.append(line)
        }
        return kept.joined(separator: " ")
            .replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decode(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
