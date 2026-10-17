import SwiftUI

/// **Les notes d'un thème**, mises en page comme le brief les décrit (`docs/refonte-parcours.md`
/// § 6) : « En une phrase » dans la couleur de la leçon, des blocs courts, les blocs spéciaux
/// quand le contenu le demande, « À retenir » dans la couleur de la leçon.
///
/// Trois couleurs et pas plus : la couleur de la leçon pour les encadrés et les puces, le
/// violet pour les mots-clés, le vert et le rouge pour les réponses. Seule exception, les
/// encadrés qui enseignent (`NoteCallout`) : leur teinte dit leur genre (piège, règle…).
struct ThemeNotesView: View {
    let notes: ThemeNotes
    let tone: LessonTone

    var body: some View {
        VStack(alignment: .leading, spacing: NoteRhythm.between) {
            ToneBox(label: L10n.t("lesson.notes.oneLiner", locale: .resolved()), tone: tone) {
                KeywordText(notes.oneLiner, size: 18, weight: .bold)
                    .font(MicaboFont.ui(18, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
            }

            if !notes.blocks.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(notes.blocks.enumerated()), id: \.offset) { index, block in
                        NoteBlockView(block: block, tone: tone)
                            .padding(.top, NoteRhythm.spacing(before: block, after: index > 0 ? notes.blocks[index - 1] : nil))
                    }
                }
            }

            if !notes.takeaways.isEmpty {
                ToneBox(label: L10n.t("lesson.notes.takeaways", locale: .resolved()), tone: tone) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(notes.takeaways.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(tone.ink)
                                KeywordText(line)
                                    .font(MicaboFont.notes)
                                    .foregroundStyle(MicaboColor.ink)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// **Le rythme vertical des notes**, le même sur la page d'un thème et dans le cercle Notes :
/// un pas régulier entre deux blocs, plus d'air au-dessus d'un sous-titre, et le sous-titre
/// collé au bloc qu'il ouvre — sinon il flotte entre deux parties sans dire laquelle.
enum NoteRhythm {
    /// Entre deux blocs.
    static let between: CGFloat = 18
    /// Au-dessus d'un sous-titre : il ouvre une partie.
    static let beforeSubtitle: CGFloat = 28
    /// Sous un sous-titre : il tient au bloc qu'il ouvre.
    static let afterSubtitle: CGFloat = 10

    /// L'espace au-dessus de `block`, selon le bloc qui le précède ; rien pour le premier.
    static func spacing(before block: NoteBlock, after previous: NoteBlock?) -> CGFloat {
        guard let previous else { return 0 }
        if case .subtitle = previous { return afterSubtitle }
        if case .subtitle = block { return beforeSubtitle }
        return between
    }
}

/// Un encadré dans la couleur de la leçon, avec son petit titre en capitales.
struct ToneBox<Content: View>: View {
    let label: String
    let tone: LessonTone
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(tone.ink)
            content
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Un bloc des notes.
struct NoteBlockView: View {
    let block: NoteBlock
    let tone: LessonTone

    @State private var definitionOpen = false

    var body: some View {
        switch block {
        case .subtitle(let text):
            HStack(spacing: 10) {
                Capsule().fill(tone.vivid).frame(width: 4, height: 20)
                KeywordText(text, size: 20, weight: .bold)
                    .font(MicaboFont.subtitle)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .paragraph(let text):
            KeywordText(text)
                .font(MicaboFont.notes)
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

        case .list(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(tone.vivid)
                            .frame(width: 7, height: 7)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        KeywordText(item)
                            .font(MicaboFont.notes)
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .definition(let term, let text):
            definition(term: term, text: text)

        case .dates(let items):
            DatesTimeline(items: items, tone: tone)

        case .formula(let latex, let caption):
            VStack(spacing: 8) {
                MathFormula(latex: latex, fontSize: 20, color: MicaboColor.ink)
                    .frame(maxWidth: .infinity)
                if let caption {
                    KeywordText(caption, size: 15, weight: .medium)
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))

        case .example(let text):
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("lesson.notes.example", locale: .resolved()))
                    .font(MicaboFont.small)
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkSecondary)
                KeywordText(text)
                    .font(MicaboFont.notes)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

        case .steps(let items):
            NoteSteps(items: items, tone: tone)

        case .table(let columns, let rows):
            NoteTable(columns: columns, rows: rows, tone: tone)

        case .quote(let text, let author):
            NoteQuote(text: text, author: author, tone: tone)

        case .callout(let kind, let title, let text):
            NoteCallout(kind: kind, title: title, text: text, tone: tone)
        }
    }

    /// Une définition : le terme en violet, replié ; un appui l'ouvre.
    private func definition(term: String, text: String) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { definitionOpen.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.t("lesson.notes.definition", locale: .resolved()))
                        .font(MicaboFont.small)
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(MicaboColor.inkSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MicaboColor.keyword)
                        .rotationEffect(.degrees(definitionOpen ? 180 : 0))
                }
                KeywordText(term, size: 19, weight: .heavy, tintsKeywords: false)
                    .font(MicaboFont.ui(19, weight: .heavy))
                    .foregroundStyle(MicaboColor.keyword)
                    .multilineTextAlignment(.leading)
                if definitionOpen {
                    KeywordText(text)
                        .font(MicaboFont.notes)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(MicaboColor.keyword.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}

/// Les dates clés, sur une frise qu'on fait glisser.
struct DatesTimeline: View {
    let items: [NoteBlock.DateItem]
    let tone: LessonTone

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            Circle().fill(tone.vivid).frame(width: 14, height: 14)
                            Rectangle()
                                .fill(index == items.count - 1 ? Color.clear : tone.vivid.opacity(0.5))
                                .frame(height: 3)
                        }
                        KeywordText(item.date, size: 17, weight: .heavy, tintsKeywords: false)
                            .font(MicaboFont.ui(17, weight: .heavy))
                            .foregroundStyle(tone.ink)
                        KeywordText(item.text, size: 15, weight: .medium)
                            .font(MicaboFont.ui(15, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 130, alignment: .leading)
                    }
                    .frame(width: 150, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

/// Des étapes numérotées : une pastille par étape dans la couleur de la leçon, reliées par
/// un filet qui dit « puis ».
struct NoteSteps: View {
    let items: [String]
    let tone: LessonTone

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isLast = index == items.count - 1
                HStack(alignment: .top, spacing: 14) {
                    Text("\(index + 1)")
                        .font(MicaboFont.number(15))
                        .foregroundStyle(MicaboColor.onInk)
                        .frame(width: 30, height: 30)
                        .background(tone.vivid, in: Circle())
                    KeywordText(item)
                        .font(MicaboFont.notes)
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .padding(.bottom, isLast ? 0 : 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                // Le filet part sous la pastille et rejoint la suivante : posé en fond, il
                // prend la hauteur de l'étape, quelle que soit la longueur de son texte.
                .background(alignment: .topLeading) {
                    if !isLast {
                        Rectangle()
                            .fill(tone.vivid.opacity(0.35))
                            .frame(width: 2)
                            .padding(.top, 30)
                            .padding(.leading, 14)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
    }
}

/// **Un petit tableau** : l'en-tête en gras sur la teinte de la leçon, une ligne sur deux
/// teintée, des cellules qui reviennent à la ligne. Quand les colonnes ne tiennent pas à
/// leur largeur minimale, le tableau glisse en travers plutôt que d'écraser ses cellules.
struct NoteTable: View {
    let columns: [String]
    let rows: [[String]]
    let tone: LessonTone

    @State private var width: CGFloat = 0

    /// En dessous, une cellule ne tient plus qu'un mot par ligne.
    private static let minColumnWidth: CGFloat = 88
    /// La largeur d'une colonne quand le tableau défile.
    private static let scrollingColumnWidth: CGFloat = 150

    private var fits: Bool {
        width == 0 || CGFloat(columns.count) * Self.minColumnWidth <= width
    }

    var body: some View {
        Group {
            if fits {
                table(columnWidth: nil)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    table(columnWidth: Self.scrollingColumnWidth)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, value in width = value }
            }
        }
    }

    private func table(columnWidth: CGFloat?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            row(columns, isHeader: true, tint: tone.pale, columnWidth: columnWidth)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, cells in
                row(
                    cells,
                    isHeader: false,
                    tint: index % 2 == 1 ? MicaboColor.surfaceMuted : MicaboColor.surface,
                    columnWidth: columnWidth
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
    }

    private func row(_ cells: [String], isHeader: Bool, tint: Color, columnWidth: CGFloat?) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(columns.indices, id: \.self) { column in
                KeywordText(
                    cells.indices.contains(column) ? cells[column] : "",
                    size: 15,
                    weight: isHeader ? .heavy : .medium,
                    tintsKeywords: !isHeader
                )
                .font(MicaboFont.ui(15, weight: isHeader ? .heavy : .medium))
                .foregroundStyle(isHeader ? tone.ink : MicaboColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(width: columnWidth, alignment: .leading)
                .frame(maxWidth: columnWidth == nil ? .infinity : nil, alignment: .leading)
            }
        }
        .background(tint)
    }
}

/// Une citation : un filet dans la couleur de la leçon, le texte en italique, et qui l'a dite.
struct NoteQuote: View {
    let text: String
    let author: String?
    let tone: LessonTone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            KeywordText(text, size: 18, weight: .medium, italic: true)
                .font(MicaboFont.ui(18, weight: .medium).italic())
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let author {
                Text("— " + KeywordText.plain(author))
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, 18)
        .background(alignment: .leading) {
            Capsule().fill(tone.vivid).frame(width: 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

/// **Un encadré qui enseigne** : pourquoi ça compte, le piège classique, une astuce, une règle à
/// retenir. Chaque genre a sa teinte et son pictogramme, pour qu'on reconnaisse un piège avant
/// de l'avoir lu : le bleu de l'information, le rouge de l'erreur, la couleur de la leçon pour
/// l'astuce, le jaune de l'attention pour la règle. Le nom du genre est toujours écrit ; le titre
/// du serveur, facultatif, vient dessous.
struct NoteCallout: View {
    let kind: CalloutKind
    let title: String?
    let text: String
    let tone: LessonTone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: Self.symbol(for: kind))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ink)
                    .accessibilityHidden(true)
                Text(L10n.t(kind.titleKey, locale: .resolved()))
                    .font(MicaboFont.small)
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(ink)
            }
            if let title {
                KeywordText(title, size: 18, weight: .bold, tintsKeywords: false)
                    .font(MicaboFont.ui(18, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            KeywordText(text)
                .font(MicaboFont.notes)
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(wash, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ink.opacity(0.25), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
    }

    /// La couleur du pictogramme, du nom du genre et du filet.
    private var ink: Color {
        switch kind {
        case .why: MicaboColor.info
        case .mistake: MicaboColor.negative
        case .tip: tone.ink
        case .remember: MicaboColor.caution
        }
    }

    /// Le fond de l'encadré, la même teinte en pâle.
    private var wash: Color {
        switch kind {
        case .why: MicaboColor.infoSoft
        case .mistake: MicaboColor.negativeSoft
        case .tip: tone.pale
        case .remember: MicaboColor.cautionSoft
        }
    }

    static func symbol(for kind: CalloutKind) -> String {
        switch kind {
        case .why: "lightbulb.fill"
        case .mistake: "exclamationmark.triangle.fill"
        case .tip: "sparkles"
        case .remember: "pin.fill"
        }
    }
}

/// **Un texte des notes** : les mots-clés (`**mot**`) en gras violet, les formules en ligne
/// (`$…$`) transposées par `FormulaRenderer` — exposants, indices, fractions, lettres
/// grecques — en italique, sans leurs dollars.
///
/// C'est aussi le rendu de tout texte écrit par le modèle (question, proposition, « pourquoi »,
/// carte) : un `Text` nu y montrerait `$x^2$` tel quel.
///
/// Les mots-clés et les formules portent une police explicite, et un `AttributedString` ne
/// sait pas hériter d'une taille : `size` et `weight` disent donc celles du texte autour, pour
/// qu'un mot-clé d'une question à 22 points ne retombe pas à 17. Le reste du texte prend la
/// police posée par `.font(_:)`. `tintsKeywords` à faux garde le gras sans le violet, là où
/// la couleur du texte dit déjà autre chose (une réponse juste, une pastille choisie).
struct KeywordText: View {
    let source: String
    var size: CGFloat
    var weight: Font.Weight
    var tintsKeywords: Bool
    var isItalic: Bool

    init(
        _ source: String,
        size: CGFloat = 17,
        weight: Font.Weight = .regular,
        tintsKeywords: Bool = true,
        italic: Bool = false
    ) {
        self.source = source
        self.size = size
        self.weight = weight
        self.tintsKeywords = tintsKeywords
        self.isItalic = italic
    }

    var body: some View {
        Text(Self.attributed(source, size: size, weight: weight, tintsKeywords: tintsKeywords, italic: isItalic))
    }

    static func attributed(
        _ source: String,
        size: CGFloat = 17,
        weight: Font.Weight = .regular,
        tintsKeywords: Bool = true,
        italic: Bool = false
    ) -> AttributedString {
        var result = AttributedString()
        for (index, part) in source.components(separatedBy: "**").enumerated() where !part.isEmpty {
            let isKeyword = index % 2 == 1
            for segment in FormulaRenderer.segments(of: part) where !segment.text.isEmpty {
                var chunk = AttributedString(segment.text)
                if isKeyword || segment.isMath {
                    let font = MicaboFont.ui(size, weight: isKeyword ? keywordWeight(weight) : formulaWeight(weight))
                    chunk.font = segment.isMath || italic ? font.italic() : font
                }
                if isKeyword, tintsKeywords {
                    chunk.foregroundColor = MicaboColor.keyword
                }
                result += chunk
            }
        }
        return result
    }

    /// Le même texte à plat : mots-clés sans leurs astérisques, formules transposées. Pour
    /// les endroits où l'on ne compose qu'une chaîne (un libellé, une phrase traduite).
    static func plain(_ source: String) -> String {
        FormulaRenderer.stripped(source.replacingOccurrences(of: "**", with: ""))
    }

    /// Un mot-clé est en gras ; dans un texte déjà très gras, il garde la graisse du texte.
    private static func keywordWeight(_ weight: Font.Weight) -> Font.Weight {
        weight == .heavy || weight == .black ? weight : .bold
    }

    /// Une formule, un cran au-dessus du texte maigre : l'italique fin se lit mal.
    private static func formulaWeight(_ weight: Font.Weight) -> Font.Weight {
        weight == .regular ? .medium : weight
    }
}
