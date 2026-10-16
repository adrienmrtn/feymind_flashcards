import SwiftUI
import UIKit

/// **Les icônes 3D de Micabo**, et leur repli.
///
/// La refonte retire les emojis des textes : chaque leçon, chaque thème, chaque cercle, chaque
/// source d'import porte une icône 3D de la base (`Assets.xcassets/Icon3D-<id>`, en @2x et @3x).
/// Une icône a un identifiant stable — le nom de son fichier dans la base (`rawValue`) : c'est
/// lui que le modèle choisit pour une leçon ou un thème, lui qui est enregistré
/// (`Course.iconID`, `Chapter.iconID`), et lui qui nomme l'image.
///
/// Quelques usages n'ont pas d'icône dans la base — l'audio, les onglets, les réglages. Ils
/// se dessinent en SF Symbol (`symbol`), comme toute icône dont l'image manquerait.
///
/// La liste des icônes qu'un modèle peut choisir est `lessonCatalog` ; la même liste, avec le
/// même sens, vit côté serveur dans `supabase/functions/_shared/icons.ts`.
enum MicaboIcon: String, CaseIterable, Codable, Identifiable {
    // MARK: La base — sections

    case star = "etoile"
    case quill = "plume"
    case lightbulb = "ampoule"
    case book = "livre-ouvert"
    case flask = "fiole"
    case globe = "globe"
    case calculator = "calculatrice"
    case hourglass = "sablier"
    case puzzle = "puzzle"
    case trophy = "trophee"
    case flag = "drapeau"
    case brain = "cerveau"
    case rocket = "fusee"
    case magnifier = "loupe"
    case lock = "cadenas"
    case check = "coche"
    case palette = "palette"
    case diploma = "diplome"
    case atom = "atome"
    case scroll = "parchemin"
    case pin = "epingle"
    case alarm = "reveil"

    // MARK: La base — onglets du parcours, import, divers

    case notes = "fiche"
    case quiz = "quiz"
    case cards = "cartes"
    case mika = "mika"
    case photo = "photo"
    case pdf = "pdf"
    case link = "lien"
    case text = "texte"
    case folder = "dossier"
    case exam = "examen"
    case flame = "flamme"
    case crown = "couronne"

    // MARK: Hors base — dessinés en SF Symbol

    case audio
    case home
    case lessons
    case profile
    case mail
    case apps
    case document
    case language
    case theme
    case rate
    case friends
    case privacy

    var id: String { rawValue }

    /// **Les icônes qu'un modèle peut donner à une leçon ou à un thème**, et ce que chacune
    /// évoque. C'est cette table qui part dans le prompt.
    static let lessonCatalog: [(icon: MicaboIcon, meaning: String)] = [
        (.book, "par défaut, lecture, littérature, langues"),
        (.globe, "géographie, monde, pays, environnement"),
        (.flask, "chimie, expériences, biologie de laboratoire"),
        (.scroll, "histoire, textes anciens, droit, traités"),
        (.calculator, "mathématiques, calcul, statistiques, économie chiffrée"),
        (.atom, "physique, particules, énergie"),
        (.lightbulb, "idée clé, définition, principe, invention"),
        (.magnifier, "analyse, méthode, étude de cas, enquête"),
        (.puzzle, "mécanisme, liens entre notions, système"),
        (.brain, "psychologie, mémoire, philosophie, raisonnement"),
        (.alarm, "chronologie, dates, durées, rythmes"),
        (.hourglass, "évolution, époque, temps long"),
        (.quill, "écriture, rédaction, auteurs, poésie"),
        (.palette, "arts, couleurs, design, culture"),
        (.rocket, "progrès, espace, innovation, technologie"),
        (.flag, "nation, politique, guerre, conquête"),
        (.diploma, "méthodologie d'examen, programme, synthèse"),
        (.pin, "lieux, cartes, repères"),
        (.check, "règles, procédures, étapes à suivre"),
        (.lock, "sécurité, protection, notions difficiles"),
        (.star, "essentiel, à retenir"),
        (.trophy, "réussite, bilan, records"),
        (.crown, "pouvoir, monarchie, souverains"),
        (.flame, "énergie, combustion, révolutions, passions"),
        (.exam, "calendrier, événements datés")
    ]

    /// Une icône lue depuis le stockage ou rendue par le modèle ; un nom inconnu retombe sur
    /// le livre plutôt que sur rien.
    init(id: String?) {
        let key = id?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        self = MicaboIcon(rawValue: key) ?? .book
    }

    /// Le nom de l'image 3D dans `Assets.xcassets`.
    var assetName: String { "Icon3D-\(rawValue)" }

    /// L'image 3D, si elle est dans le catalogue.
    var image: UIImage? { UIImage(named: assetName) }

    /// Le dessin de repli, et celui des icônes hors base.
    var symbol: String {
        switch self {
        case .star: "star.fill"
        case .quill: "pencil.and.scribble"
        case .lightbulb: "lightbulb.fill"
        case .book: "book.fill"
        case .flask: "flask.fill"
        case .globe: "globe.europe.africa.fill"
        case .calculator: "function"
        case .hourglass: "hourglass"
        case .puzzle: "puzzlepiece.fill"
        case .trophy: "trophy.fill"
        case .flag: "flag.checkered"
        case .brain: "brain.head.profile"
        case .rocket: "paperplane.fill"
        case .magnifier: "magnifyingglass"
        case .lock: "lock.fill"
        case .check: "checkmark.circle.fill"
        case .palette: "paintpalette.fill"
        case .diploma: "graduationcap.fill"
        case .atom: "atom"
        case .scroll: "scroll.fill"
        case .pin: "mappin.circle.fill"
        case .alarm: "alarm.fill"
        case .notes: "doc.text.fill"
        case .quiz: "list.clipboard.fill"
        case .cards: "rectangle.on.rectangle.angled.fill"
        case .mika: "bubble.left.fill"
        case .photo: "camera.fill"
        case .pdf: "doc.richtext.fill"
        case .link: "link"
        case .text: "text.alignleft"
        case .folder: "folder.fill"
        case .exam: "calendar"
        case .flame: "flame.fill"
        case .crown: "crown.fill"
        case .audio: "mic.fill"
        case .home: "house.fill"
        case .lessons: "books.vertical.fill"
        case .profile: "person.crop.circle.fill"
        case .mail: "envelope.fill"
        case .apps: "square.grid.2x2.fill"
        case .document: "doc.plaintext.fill"
        case .language: "character.bubble.fill"
        case .theme: "circle.lefthalf.filled"
        case .rate: "star.bubble.fill"
        case .friends: "person.2.fill"
        case .privacy: "hand.raised.fill"
        }
    }

    /// La teinte d'un dessin de repli, prise dans la base : violet, jaune, rose, menthe, bleu.
    var tint: Color {
        switch self {
        case .star, .quill, .rocket, .diploma, .scroll, .mika, .theme, .apps:
            Color(hex: 0x7C5CF0)
        case .lightbulb, .trophy, .crown, .flame, .folder, .alarm, .rate, .hourglass:
            Color(hex: 0xF2A900)
        case .calculator, .brain, .flag, .pin, .photo, .exam, .audio, .privacy:
            Color(hex: 0xEC6A96)
        case .flask, .puzzle, .check, .text, .cards, .friends:
            Color(hex: 0x2FB37A)
        default:
            Color(hex: 0x4F8EF7)
        }
    }

    /// Vrai si l'icône a une image dans la base (et pas seulement un symbole).
    var isInBase: Bool {
        switch self {
        case .audio, .home, .lessons, .profile, .mail, .apps, .document, .language, .theme,
             .rate, .friends, .privacy:
            false
        default:
            true
        }
    }
}

/// **Une icône 3D à la taille demandée**, ou son repli dessiné.
struct MicaboIconView: View {
    let icon: MicaboIcon
    var size: CGFloat = 44
    /// À venir, sur le chemin : l'icône s'efface à 40 %.
    var dimmed = false

    var body: some View {
        Group {
            if let image = icon.image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: icon.symbol)
                    .font(.system(size: size * 0.6, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(icon.tint.gradient)
            }
        }
        .frame(width: size, height: size)
        .opacity(dimmed ? 0.4 : 1)
        .accessibilityHidden(true)
    }
}
