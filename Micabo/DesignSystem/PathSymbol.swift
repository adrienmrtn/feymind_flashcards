import SwiftUI
import UIKit

/// **Les pictogrammes du chemin** : un symbole au trait par thème, jamais deux fois le même
/// dans une leçon. La grande icône 3D reste celle de la leçon ; les ronds du chemin portent un
/// pictogramme, comme une carte de progression.
///
/// Le modèle choisit dans `catalog`, qui est la même table que
/// `supabase/functions/_shared/symbols.ts`, dans le même ordre (`symbols.test.ts` le vérifie).
/// Un symbole que le téléphone ne connaît pas (iOS trop ancien) est remplacé à l'affichage par
/// un symbole sûr : un rond n'est jamais vide.
enum PathSymbol {
    static let catalog: [String] = [
        "lightbulb",
        "book",
        "books.vertical",
        "text.book.closed",
        "character.book.closed",
        "quote.bubble",
        "bubble.left.and.bubble.right",
        "pencil",
        "highlighter",
        "checklist",
        "list.number",
        "magnifyingglass",
        "puzzlepiece",
        "target",
        "arrow.triangle.branch",
        "arrow.triangle.2.circlepath",
        "link",
        "scalemass",
        "brain.head.profile",
        "eye",
        "hourglass",
        "clock",
        "calendar",
        "scroll",
        "crown",
        "flag",
        "shield",
        "building.columns",
        "person.3",
        "person.2.wave.2",
        "megaphone",
        "hand.raised",
        "newspaper",
        "doc.text",
        "signature",
        "globe.europe.africa",
        "map",
        "mappin.and.ellipse",
        "mountain.2",
        "water.waves",
        "leaf",
        "tree",
        "cloud.sun",
        "wind",
        "flame",
        "bolt",
        "drop",
        "thermometer.medium",
        "sun.max",
        "moon.stars",
        "sparkles",
        "atom",
        "testtube.2",
        "microbe",
        "allergens",
        "heart",
        "lungs",
        "brain",
        "stethoscope",
        "pills",
        "cross.case",
        "waveform.path.ecg",
        "pawprint",
        "fish",
        "ladybug",
        "function",
        "sum",
        "percent",
        "divide",
        "x.squareroot",
        "plus.forwardslash.minus",
        "number",
        "infinity",
        "ruler",
        "triangle",
        "cube",
        "chart.bar",
        "chart.pie",
        "chart.line.uptrend.xyaxis",
        "chart.line.downtrend.xyaxis",
        "dollarsign.circle",
        "eurosign.circle",
        "banknote",
        "creditcard",
        "cart",
        "storefront",
        "briefcase",
        "building.2",
        "shippingbox",
        "arrow.left.arrow.right",
        "hammer",
        "wrench.and.screwdriver",
        "gearshape.2",
        "cpu",
        "desktopcomputer",
        "network",
        "antenna.radiowaves.left.and.right",
        "lock",
        "key",
        "airplane",
        "car",
        "train.side.front.car",
        "ferry",
        "music.note",
        "paintpalette",
        "theatermasks",
        "camera",
        "film",
        "figure.run",
        "fork.knife",
        "house",
        "graduationcap",
        "binoculars",
        "location",
        "paperplane",
        "bell"
    ]

    static let fallback = "lightbulb"

    /// Un symbole par thème, tous différents : un absent, inconnu ou déjà pris reçoit le premier
    /// libre du catalogue. Les leçons d'avant les pictogrammes passent par ici aussi.
    static func unique(_ symbols: [String]) -> [String] {
        var used = Set<String>()
        return symbols.map { raw in
            let id = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if catalog.contains(id), !used.contains(id) {
                used.insert(id)
                return id
            }
            let free = catalog.first { !used.contains($0) } ?? fallback
            used.insert(free)
            return free
        }
    }

    /// Le pictogramme qui va avec une icône 3D : pour une leçon d'avant les pictogrammes.
    static func forIcon(_ id: String) -> String {
        switch id {
        case "globe": "globe.europe.africa"
        case "fiole": "testtube.2"
        case "parchemin": "scroll"
        case "calculatrice": "function"
        case "atome": "atom"
        case "ampoule": "lightbulb"
        case "loupe": "magnifyingglass"
        case "puzzle": "puzzlepiece"
        case "cerveau": "brain.head.profile"
        case "reveil": "clock"
        case "sablier": "hourglass"
        case "plume": "pencil"
        case "palette": "paintpalette"
        case "fusee": "sparkles"
        case "drapeau": "flag"
        case "diplome": "graduationcap"
        case "epingle": "mappin.and.ellipse"
        case "coche": "checklist"
        case "cadenas": "lock"
        case "etoile": "highlighter"
        case "trophee": "chart.bar"
        case "couronne": "crown"
        case "flamme": "flame"
        case "examen": "calendar"
        default: "book"
        }
    }

    /// Le nom à donner à `Image(systemName:)` : le symbole s'il existe sur ce téléphone.
    static func resolved(_ id: String) -> String {
        UIImage(systemName: id) != nil ? id : fallback
    }
}
