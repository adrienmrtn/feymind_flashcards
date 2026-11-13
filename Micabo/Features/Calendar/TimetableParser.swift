import Foundation

/// Un cours lu dans un emploi du temps : le jour (1 = lundi), les heures, la matière, la salle.
struct TimetableEntry: Equatable, Identifiable {
    var id = UUID()
    var weekday: Int
    var startMinute: Int
    var endMinute: Int
    var title: String
    var room: String

    static func == (lhs: TimetableEntry, rhs: TimetableEntry) -> Bool {
        lhs.weekday == rhs.weekday && lhs.startMinute == rhs.startMinute && lhs.endMinute == rhs.endMinute
            && lhs.title == rhs.title && lhs.room == rhs.room
    }

    /// Vrai quand la ligne peut s'enregistrer telle quelle.
    var isValid: Bool {
        (1...7).contains(weekday) && startMinute < endMinute && endMinute <= CalendarTime.dayMinutes
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// **Lire la réponse de Mika** à une photo d'emploi du temps.
///
/// On lui demande un tableau JSON et rien d'autre ; il arrive qu'il l'entoure d'une phrase ou
/// d'un bloc de code. On prend donc **le premier tableau bien formé** de la réponse, on le
/// décode avec indulgence (un jour écrit « 1 » ou 1, une heure écrite « 8h30 »), et on ne
/// garde que les lignes qui tiennent debout : un jour de 1 à 7, un début avant la fin, un
/// titre. Les doublons s'effacent, le reste se trie par jour puis par heure.
enum TimetableParser {
    static let maxEntries = 80
    static let maxTitle = 60

    /// La demande envoyée à Mika avec le texte de la photo. En anglais : elle ne s'affiche
    /// pas, et c'est la langue que le modèle suit le plus fidèlement pour un format strict.
    static let instruction = """
    The attachment is the OCR of ONE photo of my weekly school timetable. Each line is "x y | text": \
    x and y are the position of the text in the photo, in percent (x from the left, y from the top). \
    Texts in the same column share an x (often one column per day); texts on the same row share a y \
    (often a time). Rebuild every class of the week. Reply with ONLY a JSON array, no other words, \
    no markdown: [{"day":1,"start":"08:00","end":"09:00","title":"Maths","room":"B12"}]. \
    day: 1 = Monday … 7 = Sunday. start and end: 24-hour HH:mm. title: the subject, as written. \
    room: the room if visible, else "". Skip breaks and lunch. If it is not a timetable, reply [].
    """

    /// Les cours d'une réponse. Vide si rien de lisible.
    static func entries(from reply: String) -> [TimetableEntry] {
        for json in arrays(in: reply) {
            let found = entries(fromArray: json)
            if !found.isEmpty { return found }
        }
        return []
    }

    private static func entries(fromArray json: String) -> [TimetableEntry] {
        guard let data = json.data(using: .utf8),
              let objects = try? JSONSerialization.jsonObject(with: data) as? [Any]
        else { return [] }

        var result: [TimetableEntry] = []
        for case let object as [String: Any] in objects.prefix(maxEntries * 2) {
            guard let entry = entry(from: object), entry.isValid, !result.contains(entry) else { continue }
            result.append(entry)
            if result.count == maxEntries { break }
        }
        return result.sorted { lhs, rhs in
            if lhs.weekday != rhs.weekday { return lhs.weekday < rhs.weekday }
            if lhs.startMinute != rhs.startMinute { return lhs.startMinute < rhs.startMinute }
            return lhs.title < rhs.title
        }
    }

    private static func entry(from object: [String: Any]) -> TimetableEntry? {
        guard let day = integer(object["day"]),
              let start = (object["start"] as? String).flatMap(CalendarTime.parse),
              let end = (object["end"] as? String).flatMap(CalendarTime.parse)
        else { return nil }
        // « MATHÉMATIQUES » reprend sa casse, « SVT » reste un sigle.
        let title = TextSanitizer.subject((object["title"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let room = TextSanitizer.clean((object["room"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return TimetableEntry(
            weekday: day,
            startMinute: start,
            endMinute: end,
            title: String(title.prefix(maxTitle)),
            room: String(room.prefix(maxTitle))
        )
    }

    private static func integer(_ value: Any?) -> Int? {
        switch value {
        case let number as Int: return number
        case let number as Double where number.rounded() == number: return Int(number)
        case let text as String: return Int(text.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    /// Le premier tableau JSON bien formé du texte.
    static func firstArray(in text: String) -> String? {
        arrays(in: text).first
    }

    /// Les tableaux JSON bien formés du texte, dans l'ordre : les crochets se comptent, ceux des
    /// chaînes ne comptent pas. Un tableau qui ne se décode pas est sauté, et l'on cherche le
    /// suivant ; un tableau trouvé est sauté en entier.
    static func arrays(in text: String) -> [String] {
        let characters = Array(text)
        var found: [String] = []
        var index = 0
        while index < characters.count && found.count < 8 {
            guard characters[index] == "[" else {
                index += 1
                continue
            }
            if let end = matchingBracket(in: characters, from: index) {
                let candidate = String(characters[index...end])
                if let data = candidate.data(using: .utf8),
                   (try? JSONSerialization.jsonObject(with: data)) is [Any] {
                    found.append(candidate)
                    index = end + 1
                    continue
                }
            }
            index += 1
        }
        return found
    }

    private static func matchingBracket(in characters: [Character], from start: Int) -> Int? {
        var depth = 0
        var inString = false
        var escaped = false
        for index in start..<characters.count {
            let character = characters[index]
            if inString {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }
            switch character {
            case "\"": inString = true
            case "[": depth += 1
            case "]":
                depth -= 1
                if depth == 0 { return index }
            default: break
            }
        }
        return nil
    }

    /// Le jour de la semaine courante qui porte ce rang (1 = lundi) : la première occurrence
    /// d'un cours lu, à partir de laquelle il se répète.
    static func firstDay(for weekday: Int, from now: Date, calendar: Calendar = MicaboCalendar.shared) -> Date {
        let week = MicaboCalendar.week(of: now, calendar: calendar)
        let index = max(1, min(7, weekday)) - 1
        return week.indices.contains(index) ? week[index] : calendar.startOfDay(for: now)
    }
}
