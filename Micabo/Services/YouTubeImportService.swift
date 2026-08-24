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
    func preview(link: String) async throws -> YouTubeVideo {
        guard YouTubeLink.isValid(link) else { throw YouTubeImportError.invalidLink }

        return try await call(payload: [
            "url": link,
            "languages": Self.preferredLanguages,
            "metadataOnly": true
        ], key: "video")
    }

    /// La transcription, après confirmation. Elle n'est demandée que sur un aperçu sans
    /// `blockingReason` : le serveur revérifie de son côté, il est seul à voir le texte.
    func transcript(link: String) async throws -> YouTubeTranscript {
        guard YouTubeLink.isValid(link) else { throw YouTubeImportError.invalidLink }

        return try await call(payload: [
            "url": link,
            "languages": Self.preferredLanguages
        ], key: "transcript")
    }

    /// La vignette, ramenée en JPEG pour servir de couverture au cours. Un échec n'est pas
    /// une erreur : le cours retombe sur sa tuile d'emoji, comme n'importe quel import.
    func cover(for video: YouTubeVideo) async -> Data? {
        guard let url = video.thumbnailURL else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return nil }
        return ImagePrep.jpeg(image, maxDimension: 900, quality: 0.7)
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
