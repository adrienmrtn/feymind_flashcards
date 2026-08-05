import Foundation
import SwiftData

/// Voix MiniMax disponibles pour le podcast, en français.
struct PodcastVoice: Identifiable, Hashable, Codable {
    var id: String
    var label: String
    var gender: Gender
    var vibe: String

    enum Gender: String, Codable {
        case female
        case male
    }

    /// Catalogue court, pensé pour un duo de podcast.
    static let catalog: [PodcastVoice] = [
        PodcastVoice(id: "French_CasualMan", label: "Léo", gender: .male, vibe: "Décontracté"),
        PodcastVoice(id: "French_Male_Speech_New", label: "Marc", gender: .male, vibe: "Posé"),
        PodcastVoice(id: "French_MaleNarrator", label: "Paul", gender: .male, vibe: "Narrateur"),
        PodcastVoice(id: "French_MovieLeadFemale", label: "Camille", gender: .female, vibe: "Dynamique"),
        PodcastVoice(id: "French_Female_News Anchor", label: "Claire", gender: .female, vibe: "Claire"),
        PodcastVoice(id: "French_FemaleAnchor", label: "Nina", gender: .female, vibe: "Pro"),
        PodcastVoice(id: "French_Female_Speech_New", label: "Jade", gender: .female, vibe: "Convaincante"),
        PodcastVoice(id: "French_Female Journalist", label: "Inès", gender: .female, vibe: "Journaliste")
    ]

    static let defaultHost = catalog.first { $0.id == "French_CasualMan" } ?? catalog[0]
    static let defaultGuest = catalog.first { $0.id == "French_MovieLeadFemale" } ?? catalog[1]

    static func voice(id: String) -> PodcastVoice {
        catalog.first { $0.id == id } ?? defaultHost
    }
}

struct PodcastSegment: Codable, Hashable, Identifiable {
    var id: UUID
    var speaker: String
    var text: String
    var audioURL: String
    var durationMs: Int
    /// Chemin local relatif, une fois le segment téléchargé.
    var localFileName: String?

    init(
        id: UUID = UUID(),
        speaker: String,
        text: String,
        audioURL: String,
        durationMs: Int = 0,
        localFileName: String? = nil
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.audioURL = audioURL
        self.durationMs = durationMs
        self.localFileName = localFileName
    }
}

struct GeneratedPodcast: Codable {
    var title: String
    var hostVoiceId: String
    var guestVoiceId: String
    var segments: [PodcastSegment]
    var estimatedCostCents: Int?
}

@Model
final class CoursePodcast {
    var id: UUID = UUID()
    var title: String = ""
    var hostVoiceId: String = PodcastVoice.defaultHost.id
    var guestVoiceId: String = PodcastVoice.defaultGuest.id
    var createdAt: Date = Date()
    var durationMs: Int = 0
    var segmentsData: Data = Data()
    var course: Course?

    init(
        title: String,
        hostVoiceId: String,
        guestVoiceId: String,
        segments: [PodcastSegment],
        course: Course? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.hostVoiceId = hostVoiceId
        self.guestVoiceId = guestVoiceId
        self.createdAt = Date()
        self.durationMs = segments.reduce(0) { $0 + $1.durationMs }
        self.segmentsData = (try? JSONEncoder().encode(segments)) ?? Data()
        self.course = course
    }

    var segments: [PodcastSegment] {
        get { (try? JSONDecoder().decode([PodcastSegment].self, from: segmentsData)) ?? [] }
        set {
            segmentsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            durationMs = newValue.reduce(0) { $0 + $1.durationMs }
        }
    }

    var hostVoice: PodcastVoice { PodcastVoice.voice(id: hostVoiceId) }
    var guestVoice: PodcastVoice { PodcastVoice.voice(id: guestVoiceId) }

    var durationLabel: String {
        let totalSeconds = max(1, durationMs / 1000)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
