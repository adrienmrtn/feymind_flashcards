import SwiftUI
import UIKit

/// **Les icônes de Micabo : plates, en deux tons** (lot 9).
///
/// Chaque leçon, chaque thème, chaque cercle, chaque source d'import porte une icône. Elle a un
/// identifiant stable (`rawValue`) : c'est lui que le modèle choisit pour une leçon ou un thème,
/// lui qui est enregistré (`Course.iconID`, `Chapter.iconID`).
///
/// **Elles se dessinent en SF Symbols, en deux tons** : le contour plein de la couleur, et
/// l'intérieur de la même couleur à un quart. Les icônes 3D de la base
/// (`Assets.xcassets/Icon3D-<id>`) faisaient « autocollant » à côté des pictogrammes du
/// système, se brouillaient sous vingt-huit points et ne changeaient pas de couleur avec la
/// matière ; une famille plate se lit net à toutes les tailles, de la puce de seize points au
/// trophée de cent, et prend le ton de la leçon. Les images restent dans le catalogue — le site
/// et les anciennes versions les nomment —, l'app ne les dessine plus.
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

    /// Le dessin plein : l'intérieur de l'icône, et son repli quand il n'y a pas de contour.
    var symbol: String {
        switch self {
        case .star: "star.fill"
        case .quill: "pencil.and.outline"
        case .lightbulb: "lightbulb.fill"
        case .book: "book.closed.fill"
        case .flask: "flask.fill"
        case .globe: "globe.europe.africa.fill"
        case .calculator: "plusminus.circle.fill"
        case .hourglass: "hourglass"
        case .puzzle: "puzzlepiece.fill"
        case .trophy: "trophy.fill"
        case .flag: "flag.fill"
        case .brain: "brain.head.profile"
        case .rocket: "paperplane.fill"
        case .magnifier: "magnifyingglass.circle.fill"
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
        case .link: "link.circle.fill"
        case .text: "text.alignleft"
        case .folder: "folder.fill"
        case .exam: "calendar.circle.fill"
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

    /// Le contour posé sur le plein, quand le symbole a les deux dessins. Sans contour,
    /// l'icône est un trait d'une seule teinte (`symbol`).
    var outline: String? {
        switch self {
        case .star: "star"
        case .lightbulb: "lightbulb"
        case .book: "book.closed"
        case .flask: "flask"
        case .globe: "globe.europe.africa"
        case .calculator: "plusminus.circle"
        case .puzzle: "puzzlepiece"
        case .trophy: "trophy"
        case .flag: "flag"
        case .rocket: "paperplane"
        case .magnifier: "magnifyingglass.circle"
        case .lock: "lock"
        case .check: "checkmark.circle"
        case .palette: "paintpalette"
        case .diploma: "graduationcap"
        case .scroll: "scroll"
        case .pin: "mappin.circle"
        case .alarm: "alarm"
        case .notes: "doc.text"
        case .quiz: "list.clipboard"
        case .cards: "rectangle.on.rectangle.angled"
        case .mika: "bubble.left"
        case .photo: "camera"
        case .pdf: "doc.richtext"
        case .link: "link.circle"
        case .folder: "folder"
        case .exam: "calendar.circle"
        case .flame: "flame"
        case .crown: "crown"
        case .audio: "mic"
        case .home: "house"
        case .lessons: "books.vertical"
        case .profile: "person.crop.circle"
        case .mail: "envelope"
        case .apps: "square.grid.2x2"
        case .document: "doc.plaintext"
        case .language: "character.bubble"
        case .rate: "star.bubble"
        case .friends: "person.2"
        case .privacy: "hand.raised"
        case .quill, .hourglass, .brain, .atom, .text, .theme: nil
        }
    }

    /// **Le ton d'une icône** : celui de la matière qu'elle représente (`LessonTone.forSubject`),
    /// pour qu'une icône de maths soit bleue partout où elle paraît ; pour les autres, le ton
    /// de ce qu'elles disent — le jaune du crayon pour ce qui récompense (série, trophée,
    /// couronne), le rose pour ce qui capte (photo, micro), la menthe pour ce qui est juste.
    var tone: LessonTone {
        switch self {
        case .calculator, .rocket, .atom, .brain, .flask, .globe, .scroll, .diploma, .quill, .book, .palette:
            LessonTone.forSubject(self)
        case .lightbulb, .trophy, .crown, .flame, .folder, .alarm, .rate, .hourglass, .star:
            .yellow
        case .flag, .pin, .photo, .audio, .privacy:
            .pink
        case .puzzle, .check, .text, .cards, .friends:
            .mint
        case .mika, .theme, .apps, .exam:
            .lilac
        default:
            .blue
        }
    }

    /// La teinte du dessin : le trait du ton de l'icône.
    var tint: Color { tone.glyph }

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

/// **Une icône à la taille demandée** : plate, en deux tons, dans le ton de l'icône ou dans
/// celui qu'on lui donne (`tone`) — celui de la leçon, pour que le dessin et la tuile pâle
/// qui le porte soient de la même couleur.
struct MicaboIconView: View {
    let icon: MicaboIcon
    var size: CGFloat = 44
    /// À venir, sur le chemin : l'icône s'efface à 40 %.
    var dimmed = false
    /// Le ton du dessin ; par défaut, celui de l'icône (`MicaboIcon.tone`).
    var tone: LessonTone?

    var body: some View {
        let color = (tone ?? icon.tone).glyph
        // Le trait s'épaissit sur les petites tailles : un contour régulier à seize points
        // disparaît, un contour gras à cent en devient un pictogramme d'avertissement.
        let weight: Font.Weight = size < 30 ? .bold : (size < 64 ? .semibold : .medium)
        let font = Font.system(size: size * 0.62, weight: weight)
        ZStack {
            if let outline = icon.outline {
                Image(systemName: icon.symbol)
                    .font(font)
                    .foregroundStyle(color.opacity(0.24))
                Image(systemName: outline)
                    .font(font)
                    .foregroundStyle(color)
            } else {
                Image(systemName: icon.symbol)
                    .font(font)
                    .foregroundStyle(color)
            }
        }
        .frame(width: size, height: size)
        .opacity(dimmed ? 0.4 : 1)
        .accessibilityHidden(true)
    }
}
