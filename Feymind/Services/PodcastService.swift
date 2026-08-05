import Foundation

struct PodcastGenerationRequest {
    var courseTitle: String
    var courseContext: String
    var hostVoiceId: String
    var guestVoiceId: String
    /// Durée cible courte pour limiter le coût TTS.
    var targetMinutes: Int
}
