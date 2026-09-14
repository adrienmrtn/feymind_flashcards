import SwiftUI

// MARK: - Tuile

/// Tuile pastel d'une rangée : un emoji ou un symbole posé sur un carré arrondi.
/// C'est l'élément qui donne sa couleur à un écran, le reste restant ivoire et blanc.
struct MicaboTile: View {
    enum Glyph {
        case emoji(String)
        case symbol(String)
    }

    let glyph: Glyph
    var background: Color = MicaboColor.surfaceMuted
    var tint: Color = MicaboColor.inkSecondary
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            switch glyph {
            case .emoji(let value):
                Text(value)
                    .font(.system(size: size * 0.45))
            case .symbol(let name):
                Image(systemName: name)
                    .font(.system(size: size * 0.40, weight: .medium))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .background(background, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
    }

    /// Tuile d'un cours : son emoji sur un pastel dérivé de sa teinte.
    static func course(_ course: Course, size: CGFloat = 44) -> MicaboTile {
        let tint = Color(hexString: course.accentHex)
        return MicaboTile(
            glyph: .emoji(CourseEmoji.resolve(for: course)),
            background: tint.lightened(by: 0.80),
            tint: tint.darkened(by: 0.25),
            size: size
        )
    }
}

// MARK: - Pastille d'état

enum MicaboBadgeTone {
    /// Ce qui attend l'utilisateur : cartes dues, sélection.
    case accent
    /// Une échéance, un examen : ocre.
    case warm
    /// Une information sans urgence.
    case neutral
    case positive

    var foreground: Color {
        switch self {
        case .accent: MicaboColor.accent
        case .warm: MicaboColor.caution
        case .neutral: MicaboColor.inkSecondary
        case .positive: MicaboColor.positive
        }
    }

    var background: Color {
        switch self {
        case .accent: MicaboColor.accentSoft
        case .warm: MicaboColor.cautionSoft
        case .neutral: MicaboColor.surfaceMuted
        case .positive: MicaboColor.positiveSoft
        }
    }
}

/// Petite pilule posée au bout d'une rangée : « 4 dues », « à jour », « bac blanc J-6 ».
struct MicaboBadge: View {
    let text: String
    var tone: MicaboBadgeTone = .neutral

    var body: some View {
        Text(text)
            .font(MicaboFont.ui(11, weight: .semibold))
            .foregroundStyle(tone.foreground)
            .padding(.vertical, 5)
            .padding(.horizontal, 9)
            .background(tone.background, in: Capsule())
            .lineLimit(1)
    }
}

// MARK: - Rangée

/// Ce qui se pose à droite d'une rangée.
enum MicaboRowAccessory {
    case none
    case chevron
    case value(String)
    case badge(String, MicaboBadgeTone)
    case toggle(Binding<Bool>)
    case symbol(String)
}

/// Rangée de liste : tuile pastel, intitulé, sous-titre, puis un accessoire.
/// Elle sert aussi bien aux cours qu'aux réglages, dans un bloc blanc comme à
/// même le fond ivoire.
struct MicaboRow: View {
    var tile: MicaboTile?
    var title: String
    var subtitle: String?
    var accessory: MicaboRowAccessory = .chevron
    var titleColor: Color = MicaboColor.ink
    var action: (() -> Void)?

    /// Un interrupteur se manipule seul : la rangée ne devient pas un bouton.
    private var isInteractiveRow: Bool {
        guard action != nil else { return false }
        if case .toggle = accessory { return false }
        return true
    }

    var body: some View {
        if isInteractiveRow, let action {
            Button(action: action) { content }
                .buttonStyle(MicaboRowButtonStyle())
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: 13) {
            if let tile {
                tile
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(MicaboFont.rowTitle)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let subtitle {
                    Text(subtitle)
                        .font(MicaboFont.rowSubtitle)
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: MicaboSpacing.xs)

            accessoryView
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary.opacity(0.8))
        case .value(let text):
            Text(text)
                .font(MicaboFont.ui(14, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
        case .badge(let text, let tone):
            MicaboBadge(text: text, tone: tone)
        case .toggle(let binding):
            // L'interrupteur système ne vibre pas de lui-même : on le fait par la liaison,
            // pour qu'un réglage qu'on bascule réponde comme une rangée qu'on touche.
            Toggle("", isOn: binding.buzzing())
                .labelsHidden()
                .tint(MicaboColor.accent)
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
    }
}

/// Appui d'une rangée : un voile ivoire, sans changement de forme. Une rangée ne s'enfonce
/// pas — elle est trop large pour que la mise à l'échelle se lise — mais elle vibre comme
/// tout le reste, sinon les listes seraient les seuls écrans muets de l'app.
struct MicaboRowButtonStyle: ButtonStyle {
    var feedback: Haptics.Press = .light

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? MicaboColor.surfaceMuted.opacity(0.7) : Color.clear)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .micaboPressFeedback(isPressed: configuration.isPressed, feedback: feedback)
            .hoverEffect(.highlight)
    }
}

// MARK: - Regroupements

/// Une suite de rangées, dans l'une des deux mises en page de l'app.
///
/// **Une liste d'objets est faite de cartes.** Un cours, un paquet, ce qu'il y a au
/// programme : chacun est une chose distincte, qu'on ouvre, qu'on range, qu'on supprime.
/// Un bloc unique coupé par des filets les présente comme les lignes d'un même formulaire,
/// et c'est faux — d'où la carte par rangée, avec son ombre et son air autour.
///
/// **Une liste de réglages reste un bloc.** Douze lignes qui appartiennent au même sujet,
/// et dont aucune ne s'ouvre : là, le filet dit la bonne chose, et douze cartes
/// indépendantes se liraient comme douze décisions. C'est `.grouped`, et les Réglages, les
/// feuilles et les listes de choix le gardent.
struct MicaboRowGroup: View {
    enum Layout {
        /// Une carte par rangée, posées avec de l'air entre elles.
        case cards
        /// Un seul bloc blanc, filets entre les rangées.
        case grouped
    }

    let rows: [MicaboRow]
    /// Entaille du filet : par défaut il démarre après la tuile. Sans effet en `.cards`.
    var dividerInset: CGFloat = 72
    var radius: CGFloat = MicaboRadius.group
    var layout: Layout = .cards

    /// L'air entre deux cartes. Assez pour qu'on voie deux objets, assez peu pour qu'on
    /// voie une liste : au-delà, les cours cessent d'avoir l'air de tenir ensemble.
    private static let cardSpacing: CGFloat = 9

    var body: some View {
        switch layout {
        case .cards:
            VStack(spacing: Self.cardSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    row.micaboGroup(radius: MicaboRadius.lg)
                }
            }
        case .grouped:
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    row
                    if index < rows.count - 1 {
                        MicaboHairline(inset: dividerInset)
                    }
                }
            }
            .micaboGroup(radius: radius)
        }
    }
}

/// Intitulé de section, en capitales grises au-dessus d'un bloc.
struct MicaboSectionCaption: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(MicaboFont.eyebrow)
            .tracking(MicaboTracking.caps)
            .foregroundStyle(MicaboColor.inkTertiary)
            .padding(.leading, MicaboSpacing.xxs)
    }
}

/// Note explicative sous un bloc de réglages.
struct MicaboSectionFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MicaboFont.ui(12, weight: .regular))
            .foregroundStyle(MicaboColor.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, MicaboSpacing.xxs)
    }
}

/// Section complète : intitulé, bloc de rangées, note facultative.
///
/// C'est **la** mise en page groupée de l'app : un réglage n'est pas un objet, et douze
/// réglages en douze cartes se liraient comme douze décisions à prendre.
struct MicaboSettingsSection: View {
    let caption: String
    let rows: [MicaboRow]
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: caption)
            MicaboRowGroup(rows: rows, layout: .grouped)
            if let footnote {
                MicaboSectionFootnote(text: footnote)
                    .padding(.top, 2)
            }
        }
    }
}
