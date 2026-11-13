import SwiftUI

/// **Ce que le paywall et l'offre ont en commun** : leurs choix visuels (`PaywallStyle`), la
/// croix, la marque, la rangée « icône, titre, une ligne », le message posé sous le bouton et
/// les liens du bas.
///
/// Les avoir ici plutôt que recopiés dans chaque écran n'est pas une commodité : Micabo
/// ouvre le paywall à une douzaine d'endroits, l'offre le remplace quand on le referme, et
/// deux croix qui ne se ressemblent pas donnent l'impression de deux apps.

// MARK: - Les choix visuels

/// **Tout ce qui se règle à l'œil, en un seul endroit** : chaque valeur est un jeton V3
/// (`V3Font`, `V3Color`, `V3Metric`). Les écrans ne nomment ni police ni couleur ; changer la
/// direction artistique du paywall et de l'offre se fait ici — et, pour tout ce que le paywall
/// partage avec le reste de l'app (le bouton, la bulle de Mika, « PRO »), dans le composant V3.
enum PaywallStyle {
    // MARK: Les polices du paywall

    /// « Micabo [PRO] », en haut à gauche : la taille de la marque (`V3ProBadge`).
    static let brandSize: CGFloat = 24
    /// « Pour Lina », sous la marque.
    static let brandFor = V3Font.eyebrow
    /// Le titre de l'en-tête « essai » (`V3Title`), sur deux phrases : sa taille, et celle
    /// qu'il prend quand l'écran est court.
    static let titleSize: CGFloat = 32
    static let titleMediumSize: CGFloat = 28
    static let titleCompactSize: CGFloat = 25
    /// Les pastilles de ce que l'élève a déclaré (`PaywallFactsRow`).
    static let fact = V3Font.text(.footnote, weight: .semibold)
    static let factIcon = V3Font.text(.caption, weight: .bold)
    static let factHeight: CGFloat = 30
    /// Le tableau Gratuit / PRO (`PaywallFeatureTable`) : son en-tête, ses lignes, la ligne
    /// de la porte, ses valeurs et sa coche.
    static let tableHeader = V3Font.text(.caption, weight: .bold)
    static let tableRowTitle = V3Font.text(.subheadline, weight: .semibold)
    static let tableRowLead = V3Font.text(.subheadline, weight: .bold)
    static let tableValue = V3Font.text(.subheadline, weight: .bold)
    static let tableCheck: CGFloat = 20
    static let tableGlyph: CGFloat = 18
    static let tableGlyphColumn: CGFloat = 24
    /// La chronologie sur une rangée (`PaywallTimelineStrip`) : la date, sa ligne.
    static let stepTitle = V3Font.text(.footnote, weight: .bold)
    static let stepDetail = V3Font.text(.caption, weight: .medium)
    static let stepDetailTight = V3Font.text(.caption2, weight: .medium)
    static let stepDot: CGFloat = 26
    /// Une rangée de la chronologie ou d'un bénéfice : son titre, sa ligne.
    static let rowTitle = V3Font.option
    static let rowDetail = V3Font.support
    /// La même ligne, sur un écran serré (`PaywallDensity.tight`).
    static let rowDetailTight = V3Font.caption
    /// Une offre : son nom, sa ligne, son prix et l'unité du prix.
    static let planTitle = V3Font.option
    static let planDetail = V3Font.caption
    static let price = V3Font.title
    /// Le prix de l'offre qui n'est pas recommandée : un cran plus petit.
    static let priceSecondary = V3Font.heading(19, relativeTo: .headline)
    static let priceUnit = V3Font.caption
    /// La pastille de la remise, à côté du nom de l'offre.
    static let badge = V3Font.text(.caption, weight: .heavy)
    /// « Rien à payer aujourd'hui », au-dessus du bouton.
    static let assurance = V3Font.label
    /// La mention sous le bouton, le message d'un achat qui n'a pas abouti, les liens.
    static let legal = V3Font.text(.caption, weight: .medium)
    static let notice = V3Font.caption
    static let link = V3Font.text(.caption, weight: .semibold)

    // MARK: Les polices de l'offre et de la bienvenue

    /// Le titre d'un moment (`V3Title`) : « Bienvenue dans Micabo Pro ».
    static let momentSize: CGFloat = 40
    static let momentSub = V3Font.body
    /// « −40 % », en géant, et son interlettrage.
    static let percent = V3Font.display(132)
    static let percentTracking: CGFloat = -2
    /// « sur ton année Micabo Pro ».
    static let offerSub = V3Font.h2
    /// « Tout Pro : leçons, Mika, examens blancs, entraînements », sous la carte du prix.
    static let offerIncludes = V3Font.support
    /// Le tarif réduit, dans sa carte, et ce qui l'entoure.
    static let offerPrice = V3Font.display(34)
    static let offerPriceUnit = V3Font.support
    static let offerEquivalent = V3Font.figure
    /// Le même, sur un écran étroit : il reste à côté du prix au lieu de passer dessous.
    static let offerEquivalentNarrow = V3Font.label
    static let offerEquivalentLead = V3Font.caption
    /// Le décompte dans sa pastille, la pastille de la Home, « Offre de bienvenue ».
    static let pill = V3Font.label
    static let pillQuiet = V3Font.eyebrow

    // MARK: Les mesures

    /// La croix : son dessin, et la zone qu'on touche.
    static let closeSize: CGFloat = V3Metric.backSize
    static let touch: CGFloat = 44
    /// L'icône d'une rangée, et la colonne qui la porte.
    static let glyph: CGFloat = V3Metric.optionIcon
    static let glyphColumn: CGFloat = 34
    /// Les mêmes, à côté d'un titre seul (`PaywallDensity.minimal`, `bare`).
    static let glyphSmall: CGFloat = 22
    static let glyphColumnSmall: CGFloat = 28
    /// Une offre : sa hauteur (une ligne de réponse, plus la place de sa deuxième ligne), son
    /// rayon, l'espace entre deux.
    static let planHeight: CGFloat = V3Metric.optionHeight + 8
    /// L'offre qui n'est pas recommandée : plus basse, elle se lit en second.
    static let secondaryPlanHeight: CGFloat = V3Metric.optionHeight
    static let secondaryPlanTight: CGFloat = 50
    static let planRadius: CGFloat = V3Metric.radiusInner
    static let planSpacing: CGFloat = 10
    /// Le tableau : ses lignes, son en-tête, ses colonnes, ses rayons.
    static let tableRow: CGFloat = 32
    static let tableRowTight: CGFloat = 30
    static let tableHeaderHeight: CGFloat = 28
    static let freeColumn: CGFloat = 62
    static let proColumn: CGFloat = 52
    static let proColumnRadius: CGFloat = 14
    static let tableRadius: CGFloat = V3Metric.radiusCard
    /// **Sous les liens du bas** : au-dessus d'une barre d'accueil, la zone sûre fait déjà
    /// l'espace ; sans elle (iPhone SE), le pied garde sa marge à lui.
    static let bottomGapAboveHomeBar: CGFloat = 4
    static let bottomGapWithoutHomeBar: CGFloat = 14
    /// En dessous de cette hauteur utile, l'écran est court (iPhone SE : 647 points) et les
    /// formules prennent la hauteur d'une ligne de réponse.
    static let shortScreen: CGFloat = 700
    /// Les pastilles : le décompte de l'offre, la pastille de la Home.
    static let pillHeight: CGFloat = 34
    /// Ce qui est éteint le temps d'un achat : la croix.
    static let disabledOpacity: Double = 0.35
    /// Mika en fête : sur l'offre, et à la bienvenue.
    static let offerMika: CGFloat = 150
    /// Mika et sa réplique, en tête de l'offre et du paywall d'essai (lot 12).
    static let offerMikaLine: CGFloat = 76
    static let trialMika: CGFloat = 64
    static let welcomeMika: CGFloat = 200

    // MARK: Les couleurs

    /// Le mot-clé d'un titre ou d'une bulle, et ce que le tarif réduit fait par mois : le
    /// bleu clair.
    static let keyword = V3Color.accentBright
    /// Le jaune de l'offre et de « PRO » : le grand pourcentage, les pastilles. Le même dans
    /// les deux thèmes.
    static let yellow = V3Color.yellow
    /// Ce qui s'écrit sur ce jaune : un brun très sombre, le même dans les deux thèmes.
    static let onYellow = V3Color.onYellow
    /// « Rien à payer aujourd'hui » : le vert de ce qui est gratuit.
    static let free = V3Color.green
    /// Un message d'erreur, sous le bouton.
    static let error = V3Color.red

    // MARK: Les boutons

    /// Le bouton de l'offre : la pilule jaune, « Profiter de −40 % ».
    static let offerButton: V3ButtonKind = .offer
}

// MARK: - La croix

/// **La croix** : 36 points, dessinée à même la page.
///
/// Elle est **toujours là, et elle ne se fait pas attendre**. Un paywall dont la sortie
/// apparaît au bout de cinq secondes fait fermer l'app au lieu de la faire refuser : on perd
/// l'utilisateur au lieu de perdre l'abonnement. Elle réagit au premier appui ; pendant un
/// achat seulement, elle s'éteint — on ne quitte pas un paiement en cours.
struct PaywallCloseButton: View {
    /// La couleur de la croix.
    var tint: Color = V3Color.ink
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: PaywallStyle.closeSize / 2, weight: .bold))
                .foregroundStyle(tint)
                // Éteinte pendant un achat : elle se voit éteinte.
                .opacity(isEnabled ? 1 : PaywallStyle.disabledOpacity)
                .frame(width: PaywallStyle.closeSize, height: PaywallStyle.closeSize)
                // La zone touchable fait 44 points.
                .frame(width: PaywallStyle.touch, height: PaywallStyle.touch)
                .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true))
        .accessibilityLabel(L10n.t("app.a11y.close", locale: .resolved()))
    }
}

/// Ce dont la croix dépasse de son dessin : de quoi l'aligner sur la marge de l'écran.
private let closeOverhang = (PaywallStyle.closeSize - PaywallStyle.touch) / 2

// MARK: - La marque

/// **Une pastille du jaune de l'offre**, avec son encre brune : la remise d'une offre, la
/// pastille de la Home. C'est le jaune et l'encre de « PRO » (`V3ProBadge`), les mêmes dans
/// les deux thèmes : une étiquette, pas une surface de l'app.
struct PaywallYellowPill<Label: View>: View {
    var horizontal: CGFloat = 9
    var vertical: CGFloat = 2
    @ViewBuilder var label: () -> Label

    var body: some View {
        label()
            .foregroundStyle(PaywallStyle.onYellow)
            .lineLimit(1)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(PaywallStyle.yellow, in: Capsule())
    }
}

/// **« Micabo [PRO] · Pour Lina »**, en haut à gauche du paywall : ce qu'on vend, et à qui.
/// La marque est celle de l'app (`V3ProBadge`) : « PRO » en capitales droites, dans sa
/// pastille jaune.
struct PaywallBrand: View {
    /// Le prénom de l'élève ; sans lui, la marque seule.
    var name: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            V3ProBadge("Micabo", size: PaywallStyle.brandSize)
                .lineLimit(1)
                .fixedSize()
            if let name {
                Text(L10n.t("ios.pay10.brand.for", locale: .resolved(), vars: ["name": name]))
                    .font(PaywallStyle.brandFor)
                    .foregroundStyle(V3Color.ink2)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// **La barre du haut du paywall** : la marque à gauche, la croix à droite. La croix s'éteint
/// pendant un achat.
struct PaywallTopBar: View {
    var name: String?
    var isBusy: Bool
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PaywallBrand(name: name)
            Spacer(minLength: 0)
            PaywallCloseButton(action: onClose)
                .disabled(isBusy)
                .padding(.trailing, closeOverhang)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(minHeight: V3Metric.topBarHeight)
    }
}

/// **La barre du haut de l'offre** : la croix à gauche, le décompte à droite. Le décompte
/// est la seule chose de l'écran qui se redessine à chaque seconde ; arrivé à zéro, il le dit
/// (`onExpired`).
struct DiscountTopBar: View {
    /// Le temps qu'il reste sur la fenêtre.
    var clock: DiscountClock
    var isBusy: Bool
    var onClose: () -> Void
    var onExpired: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PaywallCloseButton(action: onClose)
                .disabled(isBusy)
                .padding(.leading, closeOverhang)
            Spacer(minLength: 0)
            DiscountTicking(clock: clock) { left in
                DiscountCountdownPill(remaining: left)
                    .onChange(of: left <= 0) { _, isOver in
                        if isOver { onExpired() }
                    }
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(minHeight: V3Metric.topBarHeight)
    }
}

// MARK: - Un texte et son mot-clé

/// **Un texte et son mot-clé** : les phrases du catalogue marquent d'un `**…**` le groupe de
/// mots à écrire en bleu clair. Ici on les sépare : le texte tel qu'il se lit, et le groupe à
/// mettre en avant — un seul par phrase. Ce sont les deux entrées des composants qui les
/// dessinent (`V3Title`, `MikaAsk`).
struct PaywallEmphasis: Equatable {
    /// Le texte, sans ses marques.
    let text: String
    /// Le groupe de mots à mettre en avant, `nil` s'il n'y en a pas.
    let highlight: String?

    init(text: String, highlight: String?) {
        self.text = text
        self.highlight = highlight
    }

    /// Lit une phrase marquée : « Je réponds à **toutes tes questions** avec Pro. »
    init(marked: String) {
        let parts = marked.components(separatedBy: "**")
        text = parts.joined()
        highlight = parts.count >= 3 && !parts[1].isEmpty ? parts[1] : nil
    }
}

/// **Mika dit l'accroche, dans sa bulle** (`MikaAsk`) : c'est lui qui parle derrière chaque
/// porte de l'app. Le mot-clé de la phrase est en bleu clair.
struct PaywallMikaLine: View {
    let line: PaywallEmphasis
    var mood: MikaMood = .idle

    var body: some View {
        MikaAsk(line.text, highlight: line.highlight, mood: mood)
    }
}

/// **Mika et sa réplique, en tête de l'offre** (lot 12) : il parle d'abord, le grand
/// pourcentage vient ensuite. La bulle est celle du parcours d'accueil : une surface, le
/// petit coin du côté de Mika, le texte en corps gras secondaire.
struct DiscountMikaLine: View {
    let line: PaywallEmphasis
    var mood: MikaMood = .wink
    var size: CGFloat = PaywallStyle.offerMikaLine

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            MikaMascot(mood: mood, size: size)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
            Text(v3: line.text, highlight: line.highlight)
                .font(size < 70 ? V3Font.support : V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, size < 70 ? 8 : 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    V3Color.surface,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: V3Metric.radiusBubbleTail,
                        bottomLeadingRadius: V3Metric.radiusBubble,
                        bottomTrailingRadius: V3Metric.radiusBubble,
                        topTrailingRadius: V3Metric.radiusBubble,
                        style: .continuous
                    )
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(line.text))
    }
}

// MARK: - Une rangée

/// **Une icône du paywall, en deux tons** : le plein du symbole au quart de sa couleur, son
/// contour par-dessus. C'est le dessin des icônes de l'app (`MicaboIconView`), pour les
/// quelques symboles qu'elle n'a pas (le cadenas ouvert, la cloche), dans ses teintes
/// (`V3Color.iconBlue` et les autres : une couleur par idée).
struct PaywallGlyph: View {
    /// Le nom du symbole du système, sans « .fill » : le contour. Son plein se déduit.
    var symbol: String
    var tone: Color
    var size: CGFloat = PaywallStyle.glyph
    /// Le côté de la colonne qui porte l'icône.
    var column: CGFloat = PaywallStyle.glyphColumn

    var body: some View {
        ZStack {
            Image(systemName: symbol + ".fill")
                .foregroundStyle(tone.opacity(0.24))
            Image(systemName: symbol)
                .foregroundStyle(tone)
        }
        .font(.system(size: size, weight: .semibold))
        .frame(width: column, height: column)
        .accessibilityHidden(true)
    }
}

/// **Une rangée du paywall** : une icône deux tons, un titre, une ligne. C'est une étape de
/// la chronologie de l'essai, ou un bénéfice de Pro.
struct PaywallInfoRow: View {
    /// Le symbole du système, sans « .fill ».
    var symbol: String
    /// La teinte de l'icône : une couleur par idée.
    var tone: Color
    var title: String
    /// La ligne sous le titre ; `nil` quand l'écran n'a de place que pour le titre.
    var detail: String?
    /// La police de la ligne : une légende quand l'écran est serré.
    var detailFont: Font = PaywallStyle.rowDetail
    /// L'icône et sa colonne : plus petites à côté d'un titre seul.
    var glyph: CGFloat = PaywallStyle.glyph
    var glyphColumn: CGFloat = PaywallStyle.glyphColumn

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PaywallGlyph(symbol: symbol, tone: tone, size: glyph, column: glyphColumn)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(PaywallStyle.rowTitle)
                    .foregroundStyle(V3Color.ink)
                if let detail {
                    Text(detail)
                        .font(detailFont)
                        .foregroundStyle(V3Color.ink2)
                }
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Le message sous le bouton

/// **Ce que la boutique a répondu, quand ce n'est pas un achat** : une panne ou un refus
/// (`error`), ou un achat qui attend une validation (`info`). Le message se pose sous le
/// bouton, sans alerte : un bouton qui ne répond rien passe pour cassé, une alerte par-dessus
/// un prix fait sursauter.
enum PaywallNotice: Equatable {
    case error(String)
    case info(String)

    var text: String {
        switch self {
        case .error(let text), .info(let text): text
        }
    }

    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

/// Le message, sous le bouton.
struct PaywallNoticeLine: View {
    let notice: PaywallNotice

    var body: some View {
        Text(notice.text)
            .font(PaywallStyle.notice)
            .foregroundStyle(notice.isError ? PaywallStyle.error : V3Color.ink2)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Les liens

/// **Les liens du bas** : la restauration, puis les conditions et la confidentialité
/// qu'Apple exige sur un écran d'abonnement.
struct PaywallLegalLinks: View {
    var isBusy = false
    var onRestore: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        // **Sur une ligne quand elle tient, sinon l'une sous l'autre** : en allemand et en
        // très grand texte, un lien coupé ne se lit plus, et des conditions qu'on ne peut pas
        // lire ne sont pas des conditions visibles.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                restore
                separator
                terms
                separator
                privacy
            }
            .fixedSize()
            VStack(spacing: 0) {
                restore
                terms
                privacy
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var restore: some View {
        entry(L10n.t("ios.paywallRestore", locale: .resolved()), action: onRestore)
            .disabled(isBusy)
    }

    private var terms: some View {
        entry(L10n.t("ios.pay10.terms", locale: .resolved())) { open(PaywallLinks.terms) }
    }

    private var privacy: some View {
        entry(L10n.t("ios.pay10.privacy", locale: .resolved())) { open(PaywallLinks.privacy) }
    }

    private var separator: some View {
        Text(verbatim: "·")
            .font(PaywallStyle.link)
            .foregroundStyle(V3Color.ink3)
            .accessibilityHidden(true)
    }

    private func entry(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(PaywallStyle.link)
                .foregroundStyle(V3Color.ink2)
                .lineLimit(1)
                .frame(minHeight: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true))
    }

    private func open(_ address: String) {
        guard let url = URL(string: address) else { return }
        openURL(url)
    }
}

// MARK: - Les prix du pays, ou l'attente

/// Où en sont les prix d'un écran qui vend.
enum PaywallPriceState: Equatable {
    /// La boutique n'a pas encore répondu : les offres sont des silhouettes.
    case loading
    /// Elle n'a pas répondu, ou sans ces produits : la phrase dit pourquoi.
    case failed(String)
    case ready
}

/// **Les prix du pays, ou rien.**
///
/// Quand la boutique n'avait pas encore répondu - un premier lancement sur un réseau lent,
/// un App Store qui tarde -, le paywall montrait les prix écrits en dur : ceux de la France,
/// en euros, à tout le monde. Un prix faux à côté d'un bouton d'achat. Le paywall attend
/// maintenant la réponse (`PaywallFlowView.loadPrices`), la redemande en espaçant
/// (`retryDelays`), puis propose « Réessayer » avec la cause. Pendant l'attente, l'écran est
/// là, la croix aussi : seules les offres sont des silhouettes.
enum PaywallPriceLoading {
    /// Les pauses avant chaque demande des prix : la première part tout de suite, les
    /// suivantes s'espacent. Sept secondes en tout, puis « Réessayer ».
    static let retryDelays: [Duration] = [.zero, .seconds(1), .seconds(2), .seconds(4)]

    /// Vrai quand un écran peut montrer ses prix : la boutique a répondu pour chacun de ses
    /// produits, ou il n'y a pas de boutique branchée (aperçus, constructions sans clé), et
    /// rien ne viendra.
    static func hasPrices(for productIDs: [String]) -> Bool {
        !PaywallPurchases.isReady || productIDs.allSatisfy { PaywallStorePrices.price(for: $0) != nil }
    }

    /// Où en sont les prix de ces produits, sachant ce que la dernière demande a rendu.
    static func state(for productIDs: [String], failure: String?) -> PaywallPriceState {
        if hasPrices(for: productIDs) { return .ready }
        if let failure { return .failed(failure) }
        return .loading
    }
}

// MARK: - Le gabarit d'un prix

/// **Un prix dans sa phrase, coupé autour de lui** : « 29,99 € par an » s'écrit avec la somme
/// en grand et le reste en petit, et la somme ne se range pas au même endroit dans toutes les
/// langues. Le gabarit traduit dit où elle va ; ce qui la précède et ce qui la suit gardent
/// leur place.
enum PaywallPriceTemplate {
    private static let marker = "\u{fffc}"

    /// Ce que le gabarit `key` écrit avant et après `{price}`.
    static func split(_ key: String, locale: UiLocale = .resolved()) -> (before: String, after: String) {
        let probed = L10n.t(key, locale: locale, vars: ["price": marker])
        let parts = probed.components(separatedBy: marker)
        guard parts.count == 2 else { return ("", "") }
        return (parts[0], parts[1])
    }
}
