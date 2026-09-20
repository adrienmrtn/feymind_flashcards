import SwiftUI

/// **Les formes de la nouvelle direction artistique.**
///
/// Ce fichier n'ajoute pas des variantes aux composants existants : il en pose d'autres, et
/// c'est le fond du changement. L'app d'avant était faite de **rangées** — une tuile de
/// quarante-quatre points à gauche, un titre, un chevron — et tout s'y rangeait pareil : un
/// cours, un réglage, un examen, un dossier. C'est efficace et c'est indifférencié : la liste
/// des matières d'un étudiant se lisait comme la liste de ses réglages.
///
/// La maquette tranche autrement. Ce qu'on possède — les decks — devient **grand, coloré et
/// carré** : une tuile de cent douze points, un emoji de quarante-quatre, un pastel par
/// matière, et le texte dessous plutôt qu'à côté. Ce qu'on consulte reste une rangée, mais
/// elle perd son cadre : des filets entre les lignes, pas des cartes empilées. Et ce qu'on
/// doit faire maintenant — la session du jour — prend une carte à lui seul, à motif, avec un
/// chiffre de quarante-six points.
///
/// **Trois règles gouvernent tout ce fichier**, et elles viennent des deux applications de
/// référence :
///
/// 1. **Le blanc est le fond, pas une surface.** Rien n'est posé sur du gris. Ce qui doit se
///    détacher le fait par un filet d'un point, jamais par une ombre — l'ombre était la
///    façon de l'ancienne app de dire « ceci est un objet », et elle le disait partout.
/// 2. **La couleur appartient au contenu.** Le violet est réservé à ce qui agit et à ce qui
///    progresse ; les pastels appartiennent aux matières. Une barre d'onglets, un en-tête ou
///    un fond de page n'ont pas de couleur.
/// 3. **La taille dit l'importance, pas le gras.** Vingt-et-un points pour le titre d'une
///    page, quarante-six pour le nombre de cartes du jour, onze pour une étiquette. L'écart
///    fait la hiérarchie ; tout mettre en gras revient à ne rien souligner.

// MARK: - Le titre d'une page

/// **Le titre d'un écran racine**, et ce qu'il n'a pas : pas de bouton de retour, pas de
/// pastille ronde, pas de bandeau.
///
/// `MicaboScreenHeader` reste pour les écrans poussés, où il faut un chevron de retour.
/// Celui-ci est pour les trois onglets : on y est arrivé par la barre du bas, il n'y a nulle
/// part d'où revenir, et un bouton rond posé au-dessus du titre ne ferait qu'occuper la
/// place que le titre mérite.
struct MicaboPageHeading<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(MicaboFont.ui(21, weight: .bold))
                    .tracking(-0.3)
                    .foregroundStyle(MicaboColor.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.ui(13.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
    }
}

extension MicaboPageHeading where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Les pastilles

/// **Le compte à rebours d'une épreuve.**
///
/// Noir quand elle presse, gris quand elle est loin. Le seuil n'est pas une couleur de plus :
/// deux pastilles noires côte à côte ne diraient plus laquelle arrive en premier, et c'est la
/// seule chose qu'on vient y lire.
struct MicaboCountdownPill: View {
    let days: Int
    /// En dessous, la pastille passe en noir.
    var urgentWithin: Int = 15

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var isUrgent: Bool { days <= urgentWithin }

    var body: some View {
        Text(days <= 0 ? i18n.t("app.exams.countdown.today") : "J-\(days)")
            .font(MicaboFont.ui(11.5, weight: .heavy))
            .foregroundStyle(isUrgent ? MicaboColor.onInk : MicaboColor.inkSecondary)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(isUrgent ? MicaboColor.ink : MicaboColor.surfaceMuted, in: Capsule())
            .fixedSize()
    }
}

/// La série de jours, en flamme. Elle vit sur son propre lavis orangé : c'est la seule chose
/// de l'écran qui ne se compte pas en cartes, et elle n'a rien à faire dans le violet.
struct MicaboStreakPill: View {
    let days: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MicaboColor.flame)

            Text("\(days)")
                .font(MicaboFont.ui(14, weight: .heavy))
                .foregroundStyle(MicaboColor.flameInk)
                .monospacedDigit()
        }
        .padding(.vertical, 7)
        .padding(.leading, 10)
        .padding(.trailing, 13)
        .background(MicaboColor.flameSoft, in: Capsule())
    }
}

/// Une pastille de filtre. Encre pleine quand elle est active, filet quand elle ne l'est pas.
struct MicaboFilterChip: View {
    let title: String
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.ui(12.5, weight: isSelected ? .bold : .semibold))
                .foregroundStyle(isSelected ? MicaboColor.onInk : MicaboColor.inkSecondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background {
                    if isSelected {
                        Capsule().fill(MicaboColor.ink)
                    } else {
                        Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }
}

// MARK: - La progression

/// **Une barre de progression fine, et son pourcentage à côté.**
///
/// Cinq points de haut : c'est une indication, pas une jauge de téléchargement. Le
/// pourcentage est en violet et en gras parce que c'est lui qu'on lit — la barre ne fait que
/// le rendre comparable d'une tuile à l'autre sans avoir à lire deux nombres.
struct MicaboSlimProgress: View {
    let percent: Int
    var showsLabel: Bool = true
    var height: CGFloat = 5

    var body: some View {
        HStack(spacing: 7) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.track)
                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: max(0, min(1, Double(percent) / 100)) * proxy.size.width)
                }
            }
            .frame(height: height)

            if showsLabel {
                Text("\(percent) %")
                    .font(MicaboFont.ui(11.5, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .monospacedDigit()
                    .fixedSize()
            }
        }
    }
}

// MARK: - La grande tuile d'un deck

/// **Un deck dans la grille.**
///
/// C'est la forme qui remplace la rangée, et le changement n'est pas décoratif. Une rangée
/// range ; une tuile **montre**. Un étudiant qui ouvre l'app voit quatre carrés colorés et
/// reconnaît ses matières à l'emoji avant d'avoir lu un mot — ce qu'une liste de six lignes
/// grises ne permet jamais.
///
/// Le texte est **sous** la tuile et non dedans : posé par-dessus le pastel il faudrait le
/// rendre lisible sur six couleurs différentes, ce qui finit toujours par un voile noir qui
/// éteint la couleur qu'on venait de choisir.
struct MicaboDeckTile: View {
    let emoji: String
    let pastel: Color
    let title: String
    let meta: String
    var percent: Int?
    var countdownDays: Int?
    var action: () -> Void

    /// Cent douze points : la hauteur qui laisse un emoji de quarante-quatre respirer sans
    /// que deux rangées de tuiles ne débordent d'un écran de téléphone.
    static let tileHeight: CGFloat = 112

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: MicaboRadius.deck, style: .continuous)
                        .fill(pastel)

                    Text(emoji)
                        .font(.system(size: 44))
                }
                .frame(height: Self.tileHeight)
                .overlay(alignment: .topTrailing) {
                    if let countdownDays {
                        MicaboCountdownPill(days: countdownDays)
                            .scaleEffect(0.92, anchor: .topTrailing)
                            .padding(9)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(MicaboFont.ui(14.5, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(meta)
                        .font(MicaboFont.ui(11.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)

                    if let percent {
                        MicaboSlimProgress(percent: percent)
                            .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

/// La tuile qui n'en est pas une : celle par laquelle on en crée. Trait pointillé et signe
/// plus, pour qu'elle se lise comme un emplacement libre et non comme un deck de plus.
struct MicaboAddDeckTile: View {
    let title: String
    let meta: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: MicaboRadius.deck, style: .continuous)
                    .strokeBorder(
                        MicaboColor.strokeStrong,
                        style: StrokeStyle(lineWidth: 2, dash: [7, 6])
                    )
                    .frame(height: MicaboDeckTile.tileHeight)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(MicaboFont.ui(14.5, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Text(meta)
                        .font(MicaboFont.ui(11.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

/// La grille des decks : deux colonnes, et l'écart vertical plus large que l'horizontal.
///
/// Vingt-deux points en hauteur contre quinze en largeur, et ce n'est pas une coquetterie :
/// le bloc de texte d'une tuile descend sous elle, donc l'air vertical doit séparer *un bloc
/// entier* du suivant, là où l'air horizontal ne sépare que deux carrés.
enum MicaboDeckGrid {
    static let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    static let rowSpacing: CGFloat = 22
}

// MARK: - La carte du jour

/// **La séance du jour**, et c'est la seule carte de l'app qui porte un motif.
///
/// Elle a droit à ce traitement parce qu'elle est la seule chose de l'écran d'accueil sur
/// laquelle on doit appuyer. Tout le reste — les examens, la reprise — se consulte. Un aplat
/// violet saturé aurait fait le même travail et fatiguerait : le dégradé pastel et les
/// hachures donnent la même présence sans crier.
///
/// Le nombre est à quarante-six points. C'est démesuré pour un nombre à deux chiffres, et
/// c'est le but : il doit se lire depuis la poche, avant même que l'écran soit à hauteur
/// d'yeux.
struct MicaboTodayCard<Footer: View>: View {
    let total: Int
    let learning: Int
    let newCards: Int
    let unitLabel: String
    let durationLabel: String?
    let learningLabel: String
    let newLabel: String
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .bottom, spacing: 10) {
                Text("\(total)")
                    .font(MicaboFont.number(46, weight: .heavy))
                    .tracking(-1.8)
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(unitLabel)
                    .font(MicaboFont.ui(16, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .padding(.bottom, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let durationLabel {
                    Text(durationLabel)
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .padding(.bottom, 7)
                }
            }

            splitBar
            legend
            footer.padding(.top, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 20)
        .background {
            ZStack {
                LinearGradient(
                    colors: [MicaboColor.dayWashStart, MicaboColor.dayWashMid, MicaboColor.dayWashEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                MicaboHatchPattern()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.deck, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.deck, style: .continuous)
                .strokeBorder(MicaboColor.dayWashStroke, lineWidth: 1)
        }
    }

    /// **Une barre en deux morceaux, pas deux barres.** Les cartes en cours et les neuves
    /// composent la même session : les séparer en deux jauges ferait croire à deux travaux.
    private var splitBar: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let sum = max(1, learning + newCards)
            let gap: CGFloat = learning > 0 && newCards > 0 ? 4 : 0
            let usable = max(0, width - gap)

            HStack(spacing: gap) {
                if learning > 0 {
                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: usable * CGFloat(learning) / CGFloat(sum))
                }
                if newCards > 0 {
                    Capsule()
                        .fill(MicaboColor.accentPale)
                        .frame(width: usable * CGFloat(newCards) / CGFloat(sum))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 7)
    }

    private var legend: some View {
        HStack(spacing: 18) {
            dot(MicaboColor.accent, learningLabel, MicaboColor.ink)
            dot(MicaboColor.accentPale, newLabel, MicaboColor.inkSecondary)
            Spacer(minLength: 0)
        }
    }

    private func dot(_ color: Color, _ label: String, _ ink: Color) -> some View {
        HStack(spacing: 7) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(MicaboFont.ui(13, weight: .semibold))
                .foregroundStyle(ink)
        }
    }
}

/// Les hachures du fond de la carte du jour : des diagonales qui se croisent en haut à
/// droite, et trois traits horizontaux dessous. Dessinées, pas posées en image : une image
/// fixe se pixelliserait sur la largeur variable d'un téléphone.
private struct MicaboHatchPattern: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            Path { path in
                // Les diagonales descendantes, serrées vers le coin haut-droit.
                for i in 0..<7 {
                    let start = w * 0.32 + CGFloat(i) * w * 0.086
                    path.move(to: CGPoint(x: start, y: -h * 0.15))
                    path.addLine(to: CGPoint(x: w, y: h * (0.42 - CGFloat(i) * 0.06)))
                }
                // Les montantes, moins nombreuses : elles ne font que croiser.
                for i in 0..<4 {
                    path.move(to: CGPoint(x: w, y: -h * 0.15 + CGFloat(i) * h * 0.12))
                    path.addLine(to: CGPoint(x: w * 0.55 + CGFloat(i) * w * 0.08, y: h * 0.42 + CGFloat(i) * h * 0.12))
                }
                // Trois horizontales qui reculent, pour asseoir le motif.
                for (index, y) in [0.48, 0.66, 0.84].enumerated() {
                    path.move(to: CGPoint(x: w * (0.34 + CGFloat(index) * 0.085), y: h * y))
                    path.addLine(to: CGPoint(x: w, y: h * y))
                }
            }
            .stroke(MicaboColor.accent.opacity(0.13), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Les rangées sans cadre

/// **Une rangée qui n'est pas une carte.**
///
/// `MicaboRow` posait chaque ligne sur une surface blanche dans un groupe arrondi. Ici les
/// lignes sont séparées par un filet et rien d'autre : sur un fond déjà blanc, encarter du
/// blanc ne sépare rien et ajoute deux rayons et une ombre pour le prouver.
///
/// La tuile passe de quarante-quatre à quarante-deux points et son rayon à quatorze : elle
/// accompagne le texte au lieu de le précéder.
struct MicaboFlatRow<Trailing: View>: View {
    let emoji: String
    let pastel: Color
    let title: String
    var subtitle: String?
    var tileSize: CGFloat = 42
    @ViewBuilder var trailing: Trailing
    var action: (() -> Void)?

    init(
        emoji: String,
        pastel: Color,
        title: String,
        subtitle: String? = nil,
        tileSize: CGFloat = 42,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.emoji = emoji
        self.pastel = pastel
        self.title = title
        self.subtitle = subtitle
        self.tileSize = tileSize
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        if let action {
            Button(action: action) { content }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous)
                    .fill(pastel)
                Text(emoji)
                    .font(.system(size: tileSize * 0.48))
            }
            .frame(width: tileSize, height: tileSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.ui(12.5, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }
}

extension MicaboFlatRow where Trailing == EmptyView {
    init(
        emoji: String,
        pastel: Color,
        title: String,
        subtitle: String? = nil,
        tileSize: CGFloat = 42,
        action: (() -> Void)? = nil
    ) {
        self.init(
            emoji: emoji,
            pastel: pastel,
            title: title,
            subtitle: subtitle,
            tileSize: tileSize,
            action: action,
            trailing: { EmptyView() }
        )
    }
}

/// Le chevron de fin de rangée, à la taille de la maquette. Il est ici plutôt que dans
/// chaque écran pour qu'il ne se mette pas à varier d'un point d'un écran à l'autre.
struct MicaboRowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(MicaboColor.inkTertiary)
    }
}

/// **Une rangée de chapitre.**
///
/// La pastille ronde de trente-quatre points dit l'état avant que le sous-titre ne le
/// chiffre : coche verte pour ce qui est su, numéro violet pour ce qui est entamé, numéro
/// gris pour ce qui attend. C'est ce qui permet de lire un plan de neuf chapitres d'un coup
/// d'œil sans lire un seul pourcentage.
struct MicaboChapterRow: View {
    let number: Int
    let title: String
    let meta: String
    let state: ChapterState
    var action: () -> Void

    private var circleFill: Color {
        switch state {
        case .learned: MicaboColor.positiveSoft
        case .inProgress: MicaboColor.accentSoft
        case .untouched: MicaboColor.surfaceMuted
        }
    }

    private var circleInk: Color {
        switch state {
        case .learned: MicaboColor.positive
        case .inProgress: MicaboColor.accent
        case .untouched: MicaboColor.inkTertiary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill(circleFill)

                    if state == .learned {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(circleInk)
                    } else {
                        Text("\(number)")
                            .font(MicaboFont.ui(13, weight: .heavy))
                            .foregroundStyle(circleInk)
                            .monospacedDigit()
                    }
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(MicaboFont.ui(14.5, weight: .semibold))
                        // Un chapitre jamais ouvert s'écrit un ton plus bas : il est à lire,
                        // pas à relire, et la liste doit dire lequel vient ensuite.
                        .foregroundStyle(state == .untouched ? MicaboColor.inkSecondary : MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(meta)
                        .font(MicaboFont.ui(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                MicaboRowChevron()
            }
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

// MARK: - L'encadré chiffré

/// **Un encadré à filet**, la seule façon dont quelque chose se détache sur cette page.
///
/// Pas d'ombre, pas de fond gris : un point de trait et dix-huit de rayon. C'est ce qui
/// permet d'en poser trois de suite sans que la page ne devienne une pile de cartes.
struct MicaboOutlineCard<Content: View>: View {
    var padding: EdgeInsets = EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, lineWidth: 1)
            }
    }
}

// MARK: - Le bandeau d'un deck

/// **Le bandeau pleine largeur d'un deck**, et sa réduction au défilement.
///
/// Déplié, c'est une bande de cent quarante-huit points dans le pastel de la matière, avec
/// son emoji à cinquante-deux et deux boutons ronds translucides posés dessus. Replié, c'est
/// une barre de quatre-vingt-quatre qui garde la même couleur et remonte le titre dedans.
///
/// **La couleur ne change pas entre les deux états**, et c'est ce qui fait que la réduction
/// se lit comme un mouvement plutôt que comme un autre écran. C'est aussi pour ça que la
/// barre repliée n'est pas blanche : une bande blanche par-dessus un contenu blanc n'a plus
/// de bord, et le titre se mettrait à flotter au-dessus du texte qui défile dessous.
struct MicaboDeckBanner: View {
    let emoji: String
    let pastel: Color
    let title: String
    /// Entre 0 (déplié) et 1 (replié).
    let collapse: Double
    var onBack: () -> Void
    var onMenu: () -> Void

    static let expandedHeight: CGFloat = 148
    static let collapsedHeight: CGFloat = 84

    var body: some View {
        ZStack(alignment: .top) {
            pastel.ignoresSafeArea(edges: .top)

            expandedContent
                .opacity(1 - min(1, collapse * 1.6))

            collapsedContent
                .opacity(max(0, (collapse - 0.45) / 0.55))
        }
        .frame(height: Self.expandedHeight - (Self.expandedHeight - Self.collapsedHeight) * collapse)
        .clipped()
        .shadow(color: MicaboColor.ink.opacity(0.10 * collapse), radius: 14, x: 0, y: 2)
    }

    private var expandedContent: some View {
        ZStack {
            Text(emoji)
                .font(.system(size: 52))

            HStack {
                circleButton("chevron.left", action: onBack)
                Spacer(minLength: 0)
                circleButton("ellipsis", action: onMenu)
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collapsedContent: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))

            Text(emoji)
                .font(.system(size: 17))

            Text(title)
                .font(MicaboFont.ui(16, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onMenu) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 12)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.88), in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

/// Ce que le défilement rapporte pour piloter la réduction du bandeau.
struct MicaboScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    /// Pose une sonde de défilement qui alimente `MicaboScrollOffsetKey`.
    func micaboScrollProbe(space: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MicaboScrollOffsetKey.self,
                    value: proxy.frame(in: .named(space)).minY
                )
            }
        )
    }
}

// MARK: - Le bouton de la maquette

/// **Le bouton d'action, sans ombre.**
///
/// `MicaboPrimaryButtonStyle` en porte deux, et c'était juste tant que le fond de l'app
/// était crème : une ombre y faisait décoller le bouton. Sur du blanc elle salit, et la
/// maquette n'en a aucune — cinquante-six points de haut, quatorze de rayon, seize et demi
/// de texte, et l'aplat violet suffit.
struct MicaboActionButtonStyle: ButtonStyle {
    var tint: Color = MicaboColor.accent
    var foreground: Color = MicaboColor.onInk
    var height: CGFloat = 56
    var feedback: Haptics.Press = .medium

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MicaboFont.ui(16.5, weight: .bold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(tint, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
            .micaboPressEffect(isPressed: configuration.isPressed, feedback: feedback)
    }
}

// MARK: - L'intitulé d'un rayon

/// **Le titre d'une section, et son lien.**
///
/// Dix-huit points en gras, une ligne grise en dessous quand elle apporte quelque chose, et
/// « Tout voir › » en violet à droite. C'est le seul violet de la page qui ne soit pas une
/// progression : un lien qui mène ailleurs, et il n'y en a qu'un par rayon.
struct MicaboSectionHeading<Trailing: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MicaboFont.ui(18, weight: .bold))
                    .tracking(-0.2)
                    .foregroundStyle(MicaboColor.ink)

                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.ui(13, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing.padding(.top, 3)
        }
    }
}

extension MicaboSectionHeading where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// « Tout voir › » : le lien de fin de rayon, toujours écrit pareil.
struct MicaboSeeAllLink: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(title) ›")
                .font(MicaboFont.ui(13.5, weight: .bold))
                .foregroundStyle(MicaboColor.accent)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .light))
    }
}

// MARK: - Les chiffres du profil

/// Un chiffre et son intitulé, dans un encadré à filet. Trois de front, à largeur égale.
struct MicaboStatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(MicaboFont.ui(20, weight: .heavy))
                .tracking(-0.5)
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MicaboFont.ui(11, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
        .padding(.horizontal, 11)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }
}

/// **La série, en carte chaude.**
///
/// C'est la seule carte de l'app qui ne soit ni blanche ni violette, et elle le mérite : une
/// série n'est pas un compte de cartes, c'est une habitude, et elle se mesure au record
/// personnel plutôt qu'à un objectif qu'on aurait fixé pour l'étudiant.
///
/// Les segments montrent la distance jusqu'au record, pas le nombre de jours : six barres
/// pour dix-huit jours, parce que dix-huit barres de deux points ne se comptent pas.
struct MicaboStreakCard: View {
    let days: Int
    let best: Int
    let title: String
    let note: String

    private static let segments = 6

    private var filled: Int {
        guard best > 0 else { return Self.segments }
        return max(1, min(Self.segments, Int((Double(days) / Double(best) * Double(Self.segments)).rounded())))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MicaboColor.flame)

                Text(title)
                    .font(MicaboFont.ui(16, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
            }

            Text(note)
                .font(MicaboFont.ui(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.warmProse)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                ForEach(0..<Self.segments, id: \.self) { index in
                    Capsule()
                        .fill(index < filled ? MicaboColor.flame : MicaboColor.flameTrack)
                        .frame(height: 7)
                }
            }
            .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .background {
            LinearGradient(
                colors: [MicaboColor.warmWashStart, MicaboColor.warmWashEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous)
                .strokeBorder(MicaboColor.warmWashStroke, lineWidth: 1)
        }
    }
}

/// **Une rangée de maîtrise** : la barre est sous le titre, pas à côté.
///
/// C'est la différence avec `MicaboFlatRow` : ici le sujet de la ligne n'est pas le deck,
/// c'est sa progression. La barre prend donc toute la largeur du bloc de texte, et le
/// pourcentage se lit à droite comme un résultat.
struct MicaboMasteryRow: View {
    let emoji: String
    let pastel: Color
    let title: String
    let percent: Int
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous).fill(pastel)
                    Text(emoji).font(.system(size: 19))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(MicaboFont.ui(14.5, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)

                    MicaboSlimProgress(percent: percent, showsLabel: false, height: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(percent) %")
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .monospacedDigit()
                    .fixedSize()
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

/// **Les barres des derniers jours.**
///
/// Toutes dans le violet pâle sauf la dernière, qui est aujourd'hui. C'est la seule
/// information que ce graphe porte vraiment — est-ce que j'ai travaillé aujourd'hui, et
/// comment ça se compare — et une échelle chiffrée à côté ne l'aurait pas rendue plus
/// lisible, juste plus chargée.
struct MicaboActivityBars: View {
    /// Une valeur par jour, du plus ancien au plus récent.
    let values: [Int]
    var height: CGFloat = 58

    private var peak: Int { max(1, values.max() ?? 1) }

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let isToday = index == values.count - 1
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isToday ? MicaboColor.accent : MicaboColor.accentSoft)
                    // Un plancher de quatre points : un jour sans rien reste une barre, sinon
                    // le graphe a des trous qu'on lit comme des jours manquants.
                    .frame(height: max(4, height * CGFloat(value) / CGFloat(peak)))
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

// MARK: - La ligne de faits

/// **Trois faits séparés par des points.**
///
/// Pas par des barres verticales : trois faits séparés par des barres se lisent comme un
/// tableau, et ce n'en est pas un. Le premier peut porter le violet — c'est un rang, pas un
/// nombre — et les autres restent gris.
struct MicaboFactLine: View {
    struct Fact: Identifiable {
        let text: String
        var isLead: Bool = false
        var id: String { text }
    }

    let facts: [Fact]

    var body: some View {
        HStack(spacing: 9) {
            ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                if fact.isLead {
                    Text(fact.text.uppercased())
                        .font(MicaboFont.ui(11, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(MicaboColor.accent)
                } else {
                    Text(fact.text)
                        .font(MicaboFont.ui(12.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }

                if index < facts.count - 1 {
                    Circle()
                        .fill(MicaboColor.inkTertiary)
                        .frame(width: 3, height: 3)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Le bandeau d'un chapitre

/// **Le bandeau d'un chapitre**, cousin de celui du deck et différent sur trois points.
///
/// Il est plus court — cent trente-quatre contre cent quarante-huit — parce qu'un chapitre
/// est une page de lecture et non une page d'accueil : le texte doit commencer plus haut. Le
/// bouton de droite n'ouvre pas un menu mais la **taille du texte**, qui est la seule chose
/// qu'on règle en lisant. Et sa barre repliée porte **la progression de lecture**, un filet
/// de trois points qui dit où l'on en est dans le chapitre — la seule information qu'on
/// cherche en levant les yeux au milieu d'une page.
struct MicaboChapterBanner: View {
    let emoji: String
    let pastel: Color
    let title: String
    let collapse: Double
    /// Entre 0 et 1. Ne s'affiche que sur la barre repliée.
    let readingProgress: Double
    var onBack: () -> Void
    var onTextSize: () -> Void

    static let expandedHeight: CGFloat = 134
    static let collapsedHeight: CGFloat = 84

    var body: some View {
        ZStack(alignment: .top) {
            pastel.ignoresSafeArea(edges: .top)

            expandedContent
                .opacity(1 - min(1, collapse * 1.6))

            collapsedContent
                .opacity(max(0, (collapse - 0.45) / 0.55))
        }
        .frame(height: Self.expandedHeight - (Self.expandedHeight - Self.collapsedHeight) * collapse)
        .clipped()
        .overlay(alignment: .bottom) {
            if collapse > 0.45 {
                readingBar.opacity(max(0, (collapse - 0.45) / 0.55))
            }
        }
        .shadow(color: MicaboColor.ink.opacity(0.10 * collapse), radius: 14, x: 0, y: 2)
    }

    private var readingBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(MicaboColor.ink.opacity(0.10))
                Rectangle()
                    .fill(MicaboColor.accent)
                    .frame(width: max(0, min(1, readingProgress)) * proxy.size.width)
            }
        }
        .frame(height: 3)
    }

    private var expandedContent: some View {
        ZStack {
            Text(emoji).font(.system(size: 46))

            HStack {
                circleButton { onBack() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer(minLength: 0)

                circleButton { onTextSize() } label: {
                    Text("Aa").font(MicaboFont.ui(15, weight: .bold))
                }
            }
            .padding(.horizontal, 18)
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collapsedContent: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))

            Text(emoji).font(.system(size: 17))

            Text(title)
                .font(MicaboFont.ui(16, weight: .bold))
                .tracking(-0.2)
                .foregroundStyle(MicaboColor.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onTextSize) {
                Text("Aa")
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
        }
        .padding(.horizontal, 14)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 14)
    }

    private func circleButton<Label: View>(
        _ action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 38, height: 38)
                .background(Color.white.opacity(0.88), in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

// MARK: - L'en-tête d'une session

/// **L'en-tête d'une session : sortir, savoir où l'on en est, annuler.**
///
/// Les deux boutons sont des pastilles grises de trente-deux points et le compteur est au
/// centre. C'est un en-tête de lecteur, pas d'écran : pendant une session on ne navigue pas,
/// on avance, et la seule chose qui bouge est la jauge en dessous.
struct MicaboSessionHeader: View {
    let counter: String
    let progress: Double
    var canUndo: Bool
    var onClose: () -> Void
    var onUndo: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                pill("xmark", action: onClose)
                    .accessibilityLabel(i18n.t("app.a11y.close"))

                Text(counter)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                pill("arrow.counterclockwise", action: onUndo)
                    .opacity(canUndo ? 1 : 0)
                    .disabled(!canUndo)
                    .accessibilityLabel(i18n.t("app.session.undoAria"))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.track)
                    Capsule()
                        .fill(MicaboColor.accent)
                        .frame(width: max(0, min(1, progress)) * proxy.size.width)
                        .animation(.easeOut(duration: 0.25), value: progress)
                }
            }
            .frame(height: 4)
        }
    }

    private func pill(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 32, height: 32)
                .background(MicaboColor.surfaceMuted, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
    }
}

// MARK: - Le gras dans une phrase traduite

extension Text {
    /// **Une phrase traduite dont un fragment est en gras.**
    ///
    /// `Text(uneChaîne)` ne lit pas le Markdown : seul un littéral le fait, et nos phrases
    /// viennent d'un catalogue à l'exécution. Couper la phrase en deux clés aurait été
    /// l'autre solution, et c'est la mauvaise — le fragment en gras n'est pas au même
    /// endroit d'une langue à l'autre, et « 80 % retenus » n'est pas un morceau de phrase
    /// traduisible tout seul.
    ///
    /// L'analyse échoue, on rend la phrase telle quelle, astérisques comprises : un texte
    /// légèrement sali vaut mieux qu'un écran vide.
    static func micaboMarkup(_ value: String) -> Text {
        guard let attributed = try? AttributedString(
            markdown: value,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return Text(value)
        }
        return Text(attributed)
    }
}
