import Foundation

/// Valeur JSON de forme quelconque, utilisée pour lire les réponses de l'IA
/// sans dépendre de leur structure exacte.
enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    /// Toutes les chaînes de l'arbre, dans un ordre de lecture plausible.
    func textLines() -> [String] {
        switch self {
        case .string(let value):
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        case .array(let values):
            return values.flatMap { $0.textLines() }
        case .object(let fields):
            return Self.readingOrder(of: fields).flatMap { fields[$0]?.textLines() ?? [] }
        case .number, .bool, .null:
            return []
        }
    }

    /// Les clés d'un objet JSON n'ont pas d'ordre : on remonte d'abord les champs porteurs de sens.
    private static func readingOrder(of fields: [String: JSONValue]) -> [String] {
        let preferred = [
            "title", "term", "label", "expression", "text", "date",
            "detail", "caption", "author", "headers", "rows", "items",
            "steps", "columns", "events", "bars", "root", "children"
        ]
        let ignored: Set<String> = ["type", "kind", "variant", "level", "ordered", "unit", "value"]

        let known = preferred.filter { fields[$0] != nil }
        let others = fields.keys
            .filter { !preferred.contains($0) && !ignored.contains($0) }
            .sorted()
        return known + others
    }
}
