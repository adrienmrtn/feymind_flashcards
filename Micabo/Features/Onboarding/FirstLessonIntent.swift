import Foundation

/// **La première leçon, choisie pendant le parcours d'accueil.**
///
/// L'élève dit par quel cours il veut commencer avant d'arriver dans l'app : un sujet qu'il
/// écrit, ou un cours qu'il a sous la main. Le parcours l'écrit ici ; la Home le lit à sa
/// première apparition, lance la création de la leçon (ou ouvre l'import), et l'efface.
///
/// Le sujet reste sur l'appareil : il ne part ni dans les statistiques ni ailleurs.
enum FirstLessonIntent: Equatable {
    /// Un sujet écrit par l'élève (« La guerre froide »).
    case topic(String)
    /// Il a un cours à importer : la feuille des sources s'ouvrira à l'arrivée.
    case importSource

    private static let kindKey = "micabo.onboarding.firstLesson.kind"
    private static let topicKey = "micabo.onboarding.firstLesson.topic"

    /// Ce qui attend d'être lancé. `nil` : rien de choisi, ou déjà consommé.
    static var pending: FirstLessonIntent? {
        get {
            let defaults = UserDefaults.standard
            switch defaults.string(forKey: kindKey) {
            case "topic":
                let topic = (defaults.string(forKey: topicKey) ?? "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return topic.isEmpty ? nil : .topic(topic)
            case "import":
                return .importSource
            default:
                return nil
            }
        }
        set {
            let defaults = UserDefaults.standard
            switch newValue {
            case .topic(let topic):
                defaults.set("topic", forKey: kindKey)
                defaults.set(topic, forKey: topicKey)
            case .importSource:
                defaults.set("import", forKey: kindKey)
                defaults.removeObject(forKey: topicKey)
            case nil:
                defaults.removeObject(forKey: kindKey)
                defaults.removeObject(forKey: topicKey)
            }
        }
    }
}
