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
    static let courseTitle = "Le cycle de l'eau"
    static let subject = "SVT"
    static let chapter = "Chapitre 4 · L'eau sur Terre"
    static let fileName = "Le cycle de l'eau.pdf"

    /// Bleu d'eau : la figure et les accents de la démonstration.
    static let accent = Color(hex: 0x3E6C8C)

    // MARK: - Le document brut

    /// Ce que contient le PDF déposé : un mur de texte sans hiérarchie.
    ///
    /// C'est **volontairement mal écrit** et volontairement dense. Le premier écran doit
    /// montrer un cours tel qu'on le reçoit, pas un cours déjà mis en page : sinon l'écran
    /// suivant, qui le met en page, ne transforme rien.
    static let rawLines: [String] = [
        "Le cycle de l'eau désigne l'ensemble des mouvements de l'eau entre les océans, l'atmosphère et les continents.",
        "Sous l'effet du rayonnement solaire l'eau de surface passe à l'état de vapeur, ce phénomène est appelé évaporation et concerne surtout les océans qui couvrent 71 % de la surface terrestre.",
        "La vapeur d'eau s'élève et rencontre des couches plus froides, elle se condense alors autour de noyaux de condensation pour former des gouttelettes qui constituent les nuages.",
        "Lorsque les gouttelettes deviennent trop lourdes elles retombent sous forme de précipitations, pluie ou neige selon la température rencontrée pendant la chute.",
        "Une partie de cette eau ruisselle et rejoint les cours d'eau puis les océans, une autre s'infiltre dans le sol et alimente les nappes phréatiques."
    ]

    // MARK: - La fiche

    /// La fiche telle que Micabo l'écrirait : un plan, une définition, l'essentiel
    /// surligné, une figure. Les mêmes blocs que ceux de l'app, en miniature.
    static let sheetHeading = "Trois temps, une boucle"
    static let sheetParagraph = "L'eau change d'état sans jamais quitter la planète : ce qui s'évapore des océans retombe sur les continents, puis y retourne."
    static let sheetTerm = "Condensation"
    static let sheetDefinition = "Passage de la vapeur à l'état liquide, autour de noyaux de condensation."
    static let sheetHighlight = "71 % de l'évaporation vient des océans."

    // MARK: - Les cartes

    /// Ce qu'une carte demande. Les trois formats de l'app, pour que la démonstration ne
    /// laisse pas croire que Micabo ne fait que du recto verso.
    enum CardKind {
        case basic
        case choice
        case gap

        var label: String {
            switch self {
            case .basic: "Recto verso"
            case .choice: "QCM"
            case .gap: "Texte à trou"
            }
        }

        var systemImage: String {
            switch self {
            case .basic: "rectangle.on.rectangle.angled"
            case .choice: "list.bullet"
            case .gap: "ellipsis.rectangle"
            }
        }
    }

    struct Card: Identifiable {
        let id = UUID()
        let kind: CardKind
        let front: String
        let back: String
        /// Propositions du QCM, la bonne en premier dans l'ordre d'écriture.
        var choices: [String] = []
        var answerIndex = 0
    }

    /// Une ligne au recto, une ligne au verso : la démonstration se lit d'un coup d'œil.
    static let cards: [Card] = [
        Card(
            kind: .basic,
            front: "Que fait le soleil à l'eau des océans ?",
            back: "Il la fait s'évaporer."
        ),
        Card(
            kind: .choice,
            front: "Où la vapeur se condense-t-elle ?",
            back: "En altitude, où l'air est plus froid.",
            choices: ["En altitude", "Au ras du sol", "Sous la mer"],
            answerIndex: 0
        ),
        Card(
            kind: .gap,
            front: "Les gouttelettes trop lourdes retombent en …",
            back: "précipitations"
        )
    ]
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
                    .foregroundStyle(Color(hex: 0x55504A))
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

    /// Le surligneur de l'app, en miniature : c'est la marque qu'on reconnaît d'une fiche.
    private var highlight: some View {
        Text(OnboardingDemo.sheetHighlight)
            .font(MicaboFont.hanken(7.5, weight: .medium))
            .foregroundStyle(MicaboColor.ink)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)
            .background(MicaboColor.marker, in: RoundedRectangle(cornerRadius: 3, style: .continuous))
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
                stage(symbol: "sun.max.fill", label: "Évaporation", tint: MicaboColor.caution)
                arrow
                stage(symbol: "cloud.fill", label: "Condensation", tint: MicaboColor.inkSecondary)
                arrow
                stage(symbol: "cloud.rain.fill", label: "Précipitations", tint: OnboardingDemo.accent)
            }

            HStack(spacing: 5) {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 8, weight: .bold))

                Text("Les rivières ramènent l'eau à la mer")
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

// MARK: - Les cartes

/// Carte telle qu'elle sort de la fiche : son format, sa question, et de quoi voir que les
/// trois formats ne se ressemblent pas.
struct DemoMiniCard: View {
    let card: OnboardingDemo.Card
    var isCompact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 9) {
            HStack(spacing: 5) {
                Image(systemName: card.kind.systemImage)
                    .font(.system(size: isCompact ? 8 : 9, weight: .semibold))
                Text(card.kind.label.uppercased())
                    .font(MicaboFont.hanken(isCompact ? 7.5 : 8, weight: .bold))
                    .tracking(1)
            }
            .foregroundStyle(OnboardingDemo.accent)

            Text(card.front)
                .font(MicaboFont.hanken(isCompact ? 11 : 14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if card.kind == .choice, !isCompact {
                choices
            }
        }
        .padding(isCompact ? 11 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }

    private var choices: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(card.choices.enumerated()), id: \.offset) { _, choice in
                Text(choice)
                    .font(MicaboFont.hanken(10, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MicaboColor.surfaceMuted, in: Capsule())
            }
        }
    }
}

