import SwiftUI

/// Le document d'exemple de la démonstration : un chapitre de SVT d'une page.
///
/// Le cycle de l'eau est vu partout, du collège au supérieur, et se dessine en trois
/// temps : c'est reconnaissable d'un coup d'œil, contrairement à un chapitre dense.
/// Rien n'est enregistré, aucune permission n'est demandée, aucun appel réseau n'est
/// fait : les trois écrans se traversent en avion.
///
/// Les trois écrans montrent **le même document à trois états** : brut quand on le dépose,
/// fiché après lecture, décomposé en cartes ensuite. C'est ce fil qui fait comprendre
/// l'app : trois illustrations sans rapport ne montreraient que trois animations.
enum OnboardingDemo {
    static var locale: UiLocale { .resolved() }

    static var courseTitle: String { L10n.t("demo.courseTitle", locale: locale) }
    static var subject: String { L10n.t("demo.showcase.waterSubject", locale: locale) }
    static var chapter: String { L10n.t("demo.chapter", locale: locale) }
    static var fileName: String { L10n.t("demo.fileName", locale: locale) }

    /// Bleu d'eau : la figure et les accents de la démonstration.
    static let accent = Color(hex: 0x3E6C8C)

    // MARK: - Le document brut

    /// Ce que contient le PDF déposé : un mur de texte sans hiérarchie.
    ///
    /// C'est **volontairement mal écrit** et volontairement dense. Le premier écran doit
    /// montrer un cours tel qu'on le reçoit, pas un cours déjà mis en page : sinon l'écran
    /// suivant, qui le met en page, ne transforme rien.
    static var rawLines: [String] {
        [
            L10n.t("demo.raw1", locale: locale),
            L10n.t("demo.raw2", locale: locale),
            L10n.t("demo.raw3", locale: locale),
            L10n.t("demo.raw4", locale: locale),
            L10n.t("demo.raw5", locale: locale),
        ]
    }

    // MARK: - La fiche

    /// La fiche telle que Micabo l'écrirait : un plan, une définition, l'essentiel
    /// surligné, une figure. Les mêmes blocs que ceux de l'app, en miniature.
    static var sheetHeading: String { L10n.t("demo.sheetHeading", locale: locale) }
    static var sheetParagraph: String { L10n.t("demo.sheetParagraph", locale: locale) }
    static var sheetTerm: String { L10n.t("demo.defTerm", locale: locale) }
    static var sheetDefinition: String { L10n.t("demo.defText", locale: locale) }
    static var sheetHighlight: String { L10n.t("demo.sheetHighlight", locale: locale) }

    // MARK: - Les cartes

    /// Ce qu'une carte demande. Les trois formats de l'app, pour que la démonstration ne
    /// laisse pas croire que Micabo ne fait que du recto verso. Les libellés et les
    /// symboles vivent sur `Output`, qui est ce que l'écran affiche.
    enum CardKind {
        case basic
        case choice
        case gap
    }

    struct Card: Identifiable {
        let id: UUID
        let kind: CardKind
        let front: String
        let back: String
        /// Propositions du QCM, la bonne en premier dans l'ordre d'écriture.
        var choices: [String] = []
        var answerIndex = 0

        init(
            id: UUID = UUID(),
            kind: CardKind,
            front: String,
            back: String,
            choices: [String] = [],
            answerIndex: Int = 0
        ) {
            self.id = id
            self.kind = kind
            self.front = front
            self.back = back
            self.choices = choices
            self.answerIndex = answerIndex
        }
    }

    /// Les quatre formes que prend une fiche quand Micabo la découpe, dans l'ordre où
    /// le troisième écran les fait sortir.
    ///
    /// Le schéma est là parce que c'est le format qu'on oublie toujours d'annoncer : une
    /// démonstration qui ne montre que des cartes laisse croire que Micabo ne fait que des
    /// cartes.
    enum Output: Int, CaseIterable, Identifiable {
        case schema
        case flashcard
        case quiz
        case gap

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .schema: L10n.t("demo.card4Kind", locale: .resolved())
            case .flashcard: L10n.t("demo.card1Kind", locale: .resolved())
            case .quiz: L10n.t("demo.card2Kind", locale: .resolved())
            case .gap: L10n.t("demo.card3Kind", locale: .resolved())
            }
        }

        var systemImage: String {
            switch self {
            case .schema: "arrow.triangle.branch"
            case .flashcard: "rectangle.on.rectangle.angled"
            case .quiz: "list.bullet"
            case .gap: "ellipsis.rectangle"
            }
        }
    }

    /// Phrase du texte à trou, coupée là où le mot manque.
    static var gapBefore: String {
        let front = L10n.t("demo.card3Front", locale: locale)
        if let range = front.range(of: "…") ?? front.range(of: "...") {
            return String(front[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return front
    }

    static var gapAnswer: String { L10n.t("demo.card3Back", locale: locale) }
    static var gapAfter: String { "." }

    /// Une ligne au recto, une ligne au verso : la démonstration se lit d'un coup d'œil.
    static var cards: [Card] {
        [
            Card(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                kind: .basic,
                front: L10n.t("demo.card1Front", locale: locale),
                back: L10n.t("demo.card1Back", locale: locale)
            ),
            Card(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                kind: .choice,
                front: L10n.t("demo.card2Front", locale: locale),
                back: L10n.t("demo.card2Back", locale: locale),
                choices: [
                    L10n.t("demo.card2c1", locale: locale),
                    L10n.t("demo.card2c2", locale: locale),
                    L10n.t("demo.card2c3", locale: locale),
                ],
                answerIndex: 0
            ),
            Card(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                kind: .gap,
                front: L10n.t("demo.card3Front", locale: locale),
                back: L10n.t("demo.card3Back", locale: locale)
            ),
        ]
    }
}

// MARK: - Le document brut

/// La page telle qu'on la dépose : dense, sans hiérarchie, illisible en vignette.
///
/// Le texte est rendu en vraies lignes et non en traits gris. Un faux document en barres
/// grises ressemble à une maquette, et on ne croit pas une transformation dont on n'a pas
/// vu le point de départ.
struct DemoRawPage: View {
    /// Position du balayage de lecture, de 0 (au-dessus) à 1 (en dessous). Négatif : rien.
    var sweepProgress: Double = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            fileBar
            page
        }
        .background(MicaboColor.surface)
        .overlay(alignment: .top) { sweep }
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    private var fileBar: some View {
        HStack(spacing: 6) {
            Text("PDF")
                .font(MicaboFont.hanken(8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(MicaboColor.onInk)
                .padding(.vertical, 2)
                .padding(.horizontal, 5)
                .background(Color(hex: 0xB5573C), in: RoundedRectangle(cornerRadius: 3, style: .continuous))

            Text(OnboardingDemo.fileName)
                .font(MicaboFont.hanken(9, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(MicaboColor.surfaceMuted)
    }

    /// Le titre est perdu au milieu du texte, à la même taille que le reste : c'est
    /// exactement ce qui rend un polycopié pénible à réviser.
    private var page: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(OnboardingDemo.rawLines.enumerated()), id: \.offset) { index, line in
                Text(line)
                    .font(MicaboFont.hanken(6.5, weight: index == 0 ? .semibold : .regular))
                    .foregroundStyle(MicaboColor.inkReading)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var sweep: some View {
        if sweepProgress >= 0 {
            GeometryReader { proxy in
                LinearGradient(
                    colors: [
                        MicaboColor.progress.opacity(0),
                        MicaboColor.progress.opacity(0.3),
                        MicaboColor.progress.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 44)
                .offset(y: sweepProgress * (proxy.size.height + 44) - 44)
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - La fiche

/// Le même cours, fiché. Les blocs apparaissent un à un quand `revealed` monte, ce qui
/// permet à l'écran de transformation d'écrire la fiche sous les yeux plutôt que de la
/// faire surgir d'un coup.
struct DemoSheetPage: View {
    /// Nombre de blocs découverts, de 0 à `blockCount`.
    var revealed: Int = Self.blockCount

    static let blockCount = 5

    /// Largeur de la fiche partout où elle apparaît. Les deux écrans de démonstration la
    /// posent au même endroit à la même taille : c'est ce qui fait lire une transformation
    /// plutôt que deux illustrations.
    static let width: CGFloat = 244

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            block(0) { titleBlock }
            block(1) { paragraph }
            block(2) { definition }
            block(3) { highlight }
            block(4) { DemoWaterCycleFigure() }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        // La fiche fait exactement sa hauteur, ni plus ni moins. Sans cette ligne, elle
        // s'étire ou se comprime selon la place que lui laisse l'écran qui l'accueille, et
        // c'est toujours la figure qui paie : elle se tasse jusqu'à disparaître, ce qui
        // laisse un trou blanc là où il devrait y avoir un schéma.
        .fixedSize(horizontal: false, vertical: true)
        .background(MicaboColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
    }

    @ViewBuilder
    private func block<Content: View>(_ index: Int, @ViewBuilder content: () -> Content) -> some View {
        content()
            .opacity(index < revealed ? 1 : 0)
            .offset(y: index < revealed ? 0 : 6)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Capsule()
                .fill(OnboardingDemo.accent)
                .frame(width: 18, height: 2.5)

            Text(OnboardingDemo.sheetHeading)
                .font(MicaboFont.hanken(13, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
        }
    }

    private var paragraph: some View {
        Text(OnboardingDemo.sheetParagraph)
            .font(MicaboFont.hanken(7.5, weight: .regular))
            .foregroundStyle(MicaboColor.inkReading)
            .lineSpacing(2.5)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Le filet de la définition est **posé en surimpression** du texte, et non à côté de
    /// lui dans une rangée. Un `Capsule` en `maxHeight: .infinity` rendait le bloc gourmand
    /// en hauteur : la fiche entière s'étirait alors pour remplir l'écran qui l'accueille,
    /// en poussant la figure hors de vue. En surimpression, le filet prend exactement la
    /// hauteur du texte et ne pèse rien sur la mise en page.
    private var definition: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(OnboardingDemo.sheetTerm)
                .font(MicaboFont.hanken(8, weight: .semibold))
                .foregroundStyle(OnboardingDemo.accent)

            Text(OnboardingDemo.sheetDefinition)
                .font(MicaboFont.hanken(7, weight: .regular))
                .foregroundStyle(MicaboColor.inkReading)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(OnboardingDemo.accent.opacity(0.5))
                .frame(width: 2)
        }
    }

    /// La marque de la fiche, en miniature.
    ///
    /// C'était un fond jaune, comme le surligneur de l'app ; c'est maintenant du texte en
    /// couleur, comme lui. Une démonstration qui promettrait une marque que la fiche ne fait
    /// plus serait une promesse à tenir deux fois.
    private var highlight: some View {
        Text(OnboardingDemo.sheetHighlight)
            // Un demi-point au-dessus du paragraphe, et le demi-gras : à cette échelle, la
            // couleur seule ne suffisait pas à distinguer cette ligne de celle du dessus.
            .font(MicaboFont.hanken(8, weight: .semibold))
            .foregroundStyle(MicaboColor.sheetEmphasis)
    }
}

/// Figure de la fiche : les trois temps du cycle, avec la boucle du retour à la mer.
///
/// Elle a été **grossie et cernée d'un filet**. Dans sa version précédente, elle était
/// composée en corps 6,5 sur un fond bleu à 5 % : à côté du texte de la fiche, ça ne se
/// lisait pas comme un schéma mais comme un blanc dans la page. Un schéma qu'on ne voit
/// pas ne prouve rien, et c'est précisément la promesse que cet écran doit tenir.
///
/// La hauteur est fixée par le contenu (`fixedSize`) et jamais négociée : c'est ce qui
/// l'empêche de se tasser à zéro quand la fiche est posée dans un cadre trop court.
struct DemoWaterCycleFigure: View {
    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 4) {
                stage(symbol: "sun.max.fill", label: L10n.t("demo.evap", locale: .resolved()), tint: MicaboColor.caution)
                arrow
                stage(symbol: "cloud.fill", label: L10n.t("demo.cond", locale: .resolved()), tint: MicaboColor.inkSecondary)
                arrow
                stage(symbol: "cloud.rain.fill", label: L10n.t("demo.precip", locale: .resolved()), tint: OnboardingDemo.accent)
            }

            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 8, weight: .bold))

                Text(L10n.t("demo.rivers", locale: .resolved()))
                    .font(MicaboFont.hanken(8, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(OnboardingDemo.accent)
            .padding(.vertical, 3.5)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(OnboardingDemo.accent.opacity(0.14), in: Capsule())
        }
        .padding(9)
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            OnboardingDemo.accent.opacity(0.09),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(OnboardingDemo.accent.opacity(0.28), lineWidth: 1)
        }
    }

    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(OnboardingDemo.accent.opacity(0.55))
    }

    private func stage(symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(height: 17)

            Text(label)
                .font(MicaboFont.hanken(8, weight: .semibold))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
    }
}

