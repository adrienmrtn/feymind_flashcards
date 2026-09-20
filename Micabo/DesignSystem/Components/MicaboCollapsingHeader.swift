import Observation
import SwiftUI

// MARK: - Ce que le défilement rapporte

/// **La géométrie d'un défilement vertical, telle que le bandeau en a besoin.**
///
/// Trois nombres, et rien qui dépende du montage de l'écran : où l'on en est, combien il y
/// a à parcourir, et combien on en voit. La progression de lecture s'en déduit.
struct MicaboScrollGeometry: Equatable {
    /// Zéro au repos, positif quand on est descendu, négatif quand on tire au-delà du haut.
    var offset: CGFloat = 0
    /// La hauteur de tout ce qui défile, marges de zone sûre comprises.
    var contentHeight: CGFloat = 0
    /// La hauteur de la fenêtre qui le montre.
    var viewportHeight: CGFloat = 0

    /// La part du chemin parcourue, entre zéro et un : zéro quand rien n'a bougé, un quand
    /// le pouce ne peut plus descendre.
    var progress: Double {
        let span = contentHeight - viewportHeight
        guard span > 1 else { return 1 }
        return Double(min(1, max(0, offset / span)))
    }
}

/// **Le défilement se lit avec l'API faite pour ça, plus avec une sonde.**
///
/// Trois montages de bandeau ont échoué de la même façon : le bandeau ne bougeait pas au
/// défilement. Ils lisaient tous l'offset par une `PreferenceKey` posée sur un
/// `GeometryReader` en fond du contenu — le montage classique d'iOS 14, qui rapporte une
/// position à chaque passe de mise en page. Or depuis iOS 18, le `ScrollView` défile sans
/// refaire la mise en page de son contenu quand rien n'en dépend : la préférence est
/// émise une fois, à l'ouverture, et plus jamais. Le bandeau restait donc exactement où il
/// était, quel que soit le montage autour.
///
/// `onScrollGeometryChange` est l'API qu'Apple a introduite pour cet usage précis — un
/// bandeau qui suit le doigt — et elle est appelée avant chaque image rendue. Le repli
/// iOS 17 garde l'ancienne sonde : là, elle marche.
private struct MicaboScrollGeometryModifier: ViewModifier {
    let space: String
    let onChange: (MicaboScrollGeometry) -> Void

    @State private var legacy = MicaboScrollGeometry()

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: MicaboScrollGeometry.self) { geometry in
                MicaboScrollGeometry(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    contentHeight: geometry.contentSize.height
                        + geometry.contentInsets.top
                        + geometry.contentInsets.bottom,
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, geometry in
                onChange(geometry)
            }
        } else {
            GeometryReader { page in
                content
                    .coordinateSpace(name: space)
                    .onPreferenceChange(MicaboScrollOffsetKey.self) { top in
                        legacy.offset = -top
                        legacy.viewportHeight = page.size.height
                        onChange(legacy)
                    }
                    .onPreferenceChange(MicaboContentHeightKey.self) { height in
                        legacy.contentHeight = height
                        legacy.viewportHeight = page.size.height
                        onChange(legacy)
                    }
            }
        }
    }
}

/// La position du contenu dans le repère du `ScrollView` — le repli d'iOS 17.
struct MicaboScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// La hauteur de ce qui défile, pour que la barre de lecture ait un dénominateur — le repli
/// d'iOS 17.
struct MicaboContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Rapporte la géométrie du `ScrollView` modifié, à chaque image.
    func micaboScrollGeometry(space: String, onChange: @escaping (MicaboScrollGeometry) -> Void) -> some View {
        modifier(MicaboScrollGeometryModifier(space: space, onChange: onChange))
    }

    /// Les sondes du repli iOS 17, à poser sur le contenu du `ScrollView`. Sur iOS 18 elles
    /// émettent des préférences que personne ne lit, et ne coûtent rien.
    func micaboScrollProbes(space: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: MicaboScrollOffsetKey.self, value: proxy.frame(in: .named(space)).minY)
                    .preference(key: MicaboContentHeightKey.self, value: proxy.size.height)
            }
        )
    }
}

// MARK: - L'écran

/// L'état du défilement, tenu à part de l'écran qui le contient.
///
/// Il est `@Observable` et non `@State` pour une raison de coût : l'offset change à chaque
/// image pendant qu'on fait défiler, et un `@State` sur l'écran ferait réévaluer tout son
/// corps — le plan, les chapitres, la fiche — soixante fois par seconde. Ici seul le
/// bandeau lit la géométrie, donc seul le bandeau se redessine.
@Observable
private final class MicaboScrollState {
    var geometry = MicaboScrollGeometry()
}

/// **Un écran dont le bandeau se replie en place au défilement.**
///
/// Le bandeau n'est pas dans le contenu : il est posé par-dessus, fixe, et c'est **sa
/// hauteur** qui suit le doigt. Le contenu commence sous lui — il lui laisse sa hauteur
/// dépliée en tête de défilement — et remonte dessous ensuite, coupé par la barre, comme
/// sur `DeckScroll` et `ChapitreScroll`. Tiré vers le bas au-delà du haut, le bandeau
/// s'étire au lieu de laisser un vide : c'est le geste du grand titre natif.
struct MicaboCollapsingScreen<Header: View, Content: View>: View {
    /// La hauteur du bandeau déplié, zone sûre comprise : la place que le contenu lui laisse.
    let expandedHeight: CGFloat
    @ViewBuilder let header: (MicaboScrollGeometry) -> Header
    @ViewBuilder let content: () -> Content

    @State private var scroll = MicaboScrollState()

    private static var space: String { "micabo.collapsing" }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Color.clear.frame(height: expandedHeight)
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboScrollProbes(space: Self.space)
        }
        .scrollIndicators(.hidden)
        .micaboScrollGeometry(space: Self.space) { geometry in
            scroll.geometry = geometry
        }
        .overlay(alignment: .top) {
            MicaboCollapsingHeaderHost(scroll: scroll, header: header)
        }
        // **Après la superposition, pas avant.** Posé avant, il n'étendrait que le
        // défilement : le bandeau resterait aligné sur le haut de la zone sûre, avec une
        // bande blanche au-dessus de lui. Posé ici, il étend l'ensemble — défilement **et**
        // bandeau — jusqu'au bord de l'écran.
        .ignoresSafeArea(edges: .top)
    }
}

/// Le seul endroit qui lit la géométrie : c'est lui, et lui seul, qui se redessine.
private struct MicaboCollapsingHeaderHost<Header: View>: View {
    let scroll: MicaboScrollState
    let header: (MicaboScrollGeometry) -> Header

    var body: some View {
        header(scroll.geometry)
    }
}

// MARK: - Le bandeau

/// Les hauteurs des bandeaux, **sous** la barre d'état.
///
/// La maquette mesure cent quarante-huit points du tout premier pixel, dont une
/// cinquantaine de barre d'état : c'est la part sous la barre qui est constante, pas la
/// hauteur totale — elle change d'un téléphone à l'autre.
enum MicaboHeaderBand {
    /// Le bandeau d'un deck.
    static let deck: CGFloat = 98
    /// Celui d'un chapitre, plus court : une page de lecture doit commencer plus haut.
    static let chapter: CGFloat = 84
    /// La barre repliée : trente-huit de bouton et dix de marge basse.
    static let collapsed: CGFloat = 48
}

/// **Le bandeau pleine largeur d'un deck ou d'un chapitre, et sa réduction en place.**
///
/// Déplié, c'est une bande dans le pastel de la matière, son emoji au centre, deux boutons
/// ronds translucides posés dessus. Replié, c'est une barre de la même couleur, l'emoji
/// remonté à gauche du titre. **Entre les deux, tout voyage** : la bande rétrécit, l'emoji
/// glisse vers sa place et rapetisse, les pastilles blanches des boutons s'effacent, le
/// titre apparaît. C'est un seul objet qui se replie, pas deux qui se relaient — et c'est
/// ce qui fait que le mouvement se lit comme un geste plutôt que comme un changement
/// d'écran.
///
/// **La couleur ne change pas entre les deux états.** C'est aussi pour ça que la barre
/// repliée n'est pas blanche : une bande blanche par-dessus un contenu blanc n'a plus de
/// bord, et le titre se mettrait à flotter au-dessus du texte qui défile dessous.
struct MicaboCollapsingHeader<Trailing: View>: View {
    let emoji: String
    let pastel: Color
    let title: String
    /// Ce que le bandeau occupe sous la barre d'état, déplié. Voir `MicaboHeaderBand`.
    let band: CGFloat
    /// Le creux du haut de l'écran — barre d'état et île dynamique.
    let safeTop: CGFloat
    /// Le défilement, tel que `MicaboScrollGeometry.offset` le rapporte.
    let offset: CGFloat
    /// La progression de lecture, quand la page en a une : un filet violet sous la barre.
    var readingProgress: Double? = nil
    var onBack: () -> Void
    var onTrailing: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    /// La distance de défilement qui mène du bandeau déplié à la barre.
    private var travel: CGFloat { band - MicaboHeaderBand.collapsed }
    /// Entre 0 (déplié) et 1 (replié).
    private var collapse: CGFloat { min(1, max(0, offset / travel)) }
    /// De combien le bandeau s'étire quand on tire au-delà du haut.
    private var stretch: CGFloat { max(0, -offset) }
    private var height: CGFloat { safeTop + band - travel * collapse + stretch }

    /// Les boutons font trente-huit ; l'emoji replié occupe vingt-deux entre le chevron et
    /// le titre.
    private static var button: CGFloat { 38 }
    private static var emojiSlot: CGFloat { 22 }
    private static var gap: CGFloat { 8 }

    var body: some View {
        // Toutes les valeurs sont nommées et typées avant la chaîne de modificateurs : un
        // calcul posé dans un `offset` au milieu de dix maillons est une inconnue de plus
        // pour l'inférence, et c'est ce qui a fait renoncer le compilateur ailleurs.
        let sidePadding: CGFloat = 18 - 4 * collapse
        let circleAlpha: Double = 0.88 * Double(1 - collapse)
        // Le titre n'arrive que dans la seconde moitié du geste : plus tôt, il passerait
        // sous l'emoji qui n'a pas fini de glisser.
        let titleAlpha: Double = Double(max(0, (collapse - 0.4) / 0.6))
        let titleRise: CGFloat = 6 * (1 - collapse)
        // L'emoji : cinquante-deux au centre de la bande, dix-sept dans la barre.
        let emojiScale: CGFloat = 1 - 0.673 * collapse + stretch / 600
        let restY: CGFloat = (safeTop + band + stretch) / 2
        let barY: CGFloat = safeTop + Self.button / 2
        let emojiY: CGFloat = restY + (barY - restY) * collapse
        let barX: CGFloat = sidePadding + Self.button + Self.gap + Self.emojiSlot / 2
        let shadowAlpha: Double = 0.10 * Double(collapse)

        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let restX: CGFloat = proxy.size.width / 2
                let emojiX: CGFloat = restX + (barX - restX) * collapse

                Text(emoji)
                    .font(.system(size: 52))
                    .scaleEffect(emojiScale)
                    .position(x: emojiX, y: emojiY)
            }
            .allowsHitTesting(false)

            HStack(spacing: Self.gap) {
                MicaboBannerButton(circleAlpha: circleAlpha, action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                }
                .accessibilityLabel(L10n.t("app.common.back", locale: .resolved()))

                Color.clear
                    .frame(width: Self.emojiSlot, height: Self.button)

                Text(title)
                    .font(MicaboFont.ui(16, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(titleAlpha)
                    .offset(y: titleRise)
                    .accessibilityHidden(titleAlpha < 0.5)

                MicaboBannerButton(circleAlpha: circleAlpha, action: onTrailing) {
                    trailing()
                }
            }
            .padding(.horizontal, sidePadding)
            .padding(.top, safeTop)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .background {
            Rectangle()
                .fill(pastel)
                .shadow(color: MicaboColor.ink.opacity(shadowAlpha), radius: 14, x: 0, y: 2)
        }
        .overlay(alignment: .bottom) {
            if let readingProgress {
                readingBar(readingProgress)
                    .opacity(Double(collapse))
            }
        }
    }

    /// Le filet de lecture : trois points, l'encre très diluée en piste, le violet en
    /// remplissage. La seule information qu'on cherche en levant les yeux au milieu d'une
    /// page.
    private func readingBar(_ progress: Double) -> some View {
        GeometryReader { proxy in
            let fill: CGFloat = CGFloat(max(0, min(1, progress))) * proxy.size.width

            ZStack(alignment: .leading) {
                Rectangle().fill(MicaboColor.ink.opacity(0.10))
                Rectangle()
                    .fill(MicaboColor.accent)
                    .frame(width: fill)
            }
        }
        .frame(height: 3)
    }
}

/// Un bouton de bandeau : en pastille blanche translucide sur le bandeau déplié, à plat
/// sur la barre repliée — et la pastille s'efface entre les deux. Le contenu est libre :
/// un chevron, trois points, ou « Aa ».
struct MicaboBannerButton<Label: View>: View {
    /// L'opacité de la pastille blanche : 0,88 dépliée, zéro repliée.
    var circleAlpha: Double
    var action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 38, height: 38)
                .background {
                    Circle().fill(Color.white.opacity(circleAlpha))
                }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

/// **Le creux du haut de l'écran, lu sur la fenêtre.**
///
/// Un bandeau qui monte jusqu'au bord de l'écran doit savoir où s'arrête la barre d'état,
/// sinon son bouton de retour se pose sur l'heure. La valeur change d'un téléphone à
/// l'autre — île dynamique, encoche, rien du tout — et une constante en dur se trompe sur
/// deux appareils sur trois.
///
/// **Ça n'est pas mesuré par un `GeometryReader`, et c'est la correction.** Un
/// `GeometryReader` qui respecte la zone sûre la mesure bien, mais il commence en dessous
/// d'elle : tout ce qu'on pose en superposition à l'intérieur s'aligne alors sur son haut à
/// lui, pas sur celui de l'écran. Le bandeau se posait donc cinquante points trop bas.
///
/// La fenêtre, elle, connaît ce creux sans qu'on ait à réserver de place pour le demander.
/// Il ne change pas pendant la vie de l'app : c'est une propriété de l'appareil, pas de la
/// mise en page.
enum MicaboScreen {
    static var safeTop: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        // Quarante-sept : le creux d'un iPhone à encoche. Ce n'est qu'un dernier recours —
        // il n'y a pas de fenêtre avant que la scène ne soit attachée.
        return window?.safeAreaInsets.top ?? 47
    }
}
