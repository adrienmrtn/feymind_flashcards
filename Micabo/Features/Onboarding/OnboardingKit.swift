import SwiftUI

// Les briques communes aux écrans du parcours. Elles ne dessinent rien par elles-mêmes : les
// couleurs, les polices et les formes viennent du système visuel V3 (`V3Color`, `V3Font`,
// `V3Metric`, `V3Screen`, `MikaAsk`, `V3Title`, `V3OptionRow`, `V3Chip`, `V3Button`,
// `.v3Card`). Ici : le gabarit d'un écran (qui se dessine aussi dans un rendu), la mise en
// page d'une question, le grand Mika d'un moment, la place du clavier, et les mots (dates,
// heures).

// MARK: - Les mesures du parcours

/// Les espacements des écrans du parcours, lus dans les maquettes (px = pt).
enum OnbLayout {
    /// La marge horizontale d'une page composée hors du gabarit (les stories) : celle du
    /// gabarit.
    static let margin: CGFloat = 20
    /// Entre la bulle de Mika et les réponses, au moins.
    static let askGap: CGFloat = 28
    /// Entre deux lignes de réponse.
    static let rowGap: CGFloat = 10
    /// Entre deux cartes.
    static let cardGap: CGFloat = 12
    /// Au-dessus du titre d'une page à titre, sous la barre du haut.
    static let titleTop: CGFloat = 16
    /// Entre le titre d'une page et ce qu'elle montre.
    static let titleGap: CGFloat = 24

    /// Le titre d'une story ou d'un grand moment.
    static let display: CGFloat = 40
    /// Le titre d'une page.
    static let pageTitle: CGFloat = 32

    /// Le grand Mika d'un moment : sa plus grande et sa plus petite taille.
    static let heroMax: CGFloat = 190
    static let heroMin: CGFloat = 120
    /// Mika quand il se présente : le plus grand du parcours.
    static let heroWelcome: CGFloat = 240

    /// **Sous le bouton du pied**, au-dessus de la zone sûre du bas : 16 pt au-dessus de la
    /// barre d'accueil ; 24 pt du bord sur un iPhone à bouton d'accueil, qui n'a pas de marge.
    static func footerGap(safeBottom: CGFloat) -> CGFloat {
        safeBottom > 0 ? 16 : 24
    }
}

// MARK: - Le gabarit d'un écran

/// **L'écran d'une étape** : un contenu qui remplit la hauteur (et défile s'il dépasse), et un
/// pied fixe. La barre du haut n'est pas ici : elle est fixe, au-dessus des pages
/// (`OnboardingFlowView`).
///
/// Le contenu reçoit au moins la hauteur de l'écran (`.frame(minHeight:)` dans le
/// défilement) : les `Spacer` y poussent, les réponses descendent. Les rendus « sur
/// l'appareil » (`OnboardingDeviceRenderTests`) le vérifient avec les vraies marges.
///
/// **Le pied** est sous la colonne, dans la zone sûre : son bouton se pose au-dessus de la
/// barre d'accueil avec une marge normale (`OnbLayout.footerGap`), et à 24 pt du bord sur un
/// iPhone à bouton d'accueil, qui n'a pas de marge en bas.
struct OnbScreen<Content: View, Footer: View>: View {
    private let content: Content
    private let footer: Footer

    @Environment(\.onboardingStill) private var still

    init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
        self.content = content()
        self.footer = footer()
    }

    private var hasFooter: Bool { Footer.self != EmptyView.self }

    /// Le contenu, dans les marges de l'écran.
    private var column: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var body: some View {
        GeometryReader { outer in
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    if still {
                        // Un rendu ne dessine pas l'intérieur d'un `ScrollView` : la même
                        // colonne, coupée en bas si elle dépasse (le début d'un défilement).
                        ViewThatFits(in: .vertical) {
                            column
                            column
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                        .clipped()
                    } else {
                        ScrollView {
                            column
                                .frame(minHeight: proxy.size.height, alignment: .top)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollDismissesKeyboard(.interactively)
                        .scrollIndicators(.hidden)
                    }
                }

                if hasFooter {
                    VStack(spacing: 10) {
                        footer
                    }
                    .padding(.horizontal, V3Metric.screenMargin)
                    .padding(.top, 8)
                    .padding(.bottom, OnbLayout.footerGap(safeBottom: outer.safeAreaInsets.bottom))
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
    }
}

extension OnbScreen where Footer == EmptyView {
    /// Un écran sans pied : un choix unique, qui avance à l'appui.
    init(@ViewBuilder content: () -> Content) {
        self.init(content: content, footer: { EmptyView() })
    }
}

// MARK: - Une question

/// **Une question du parcours** : Mika et sa bulle en haut (`MikaAsk`), les réponses ancrées
/// en bas, du vide entre les deux ; et, quand il y en a un, le bouton au pied. La barre du
/// haut n'est pas ici : elle est fixe, au-dessus des pages (`OnboardingFlowView`).
///
/// Quand l'élève répond, l'écran change le texte de la bulle (un fondu, dans `MikaAsk`) et
/// l'humeur de Mika : c'est la réaction, et elle ne retarde rien.
///
/// `anchored` faux : les réponses suivent la bulle (une longue liste, des puces, une page qui
/// prend le clavier).
struct OnbQuestion<Answers: View, Footer: View>: View {
    private let ask: String
    private let mood: MikaMood
    private let anchored: Bool
    private let answers: Answers
    private let footer: Footer

    init(
        _ ask: String,
        mood: MikaMood = .idle,
        anchored: Bool = true,
        @ViewBuilder answers: () -> Answers,
        @ViewBuilder footer: () -> Footer
    ) {
        self.ask = ask
        self.mood = mood
        self.anchored = anchored
        self.answers = answers()
        self.footer = footer()
    }

    var body: some View {
        OnbScreen {
            OnbBubble(ask, mood: mood)
            if anchored {
                Spacer(minLength: OnbLayout.askGap)
            } else {
                Color.clear
                    .frame(height: OnbLayout.askGap)
            }
            answers
        } footer: {
            footer
        }
    }
}

extension OnbQuestion where Footer == EmptyView {
    /// Une question à choix unique : pas de bouton, la réponse avance.
    init(
        _ ask: String,
        mood: MikaMood = .idle,
        anchored: Bool = true,
        @ViewBuilder answers: () -> Answers
    ) {
        self.init(ask, mood: mood, anchored: anchored, answers: answers, footer: { EmptyView() })
    }
}

// MARK: - Les phrases et leur mot-clé

/// **Une phrase du catalogue et son mot-clé.** Les phrases marquent leur mot-clé entre deux
/// astérisques doubles (« Ton **objectif n°1** cette année ? »), pour que chaque langue décide
/// de sa place. La bulle de Mika reçoit la phrase nue et le passage à faire ressortir.
struct OnbPhrase: Equatable {
    /// La phrase, sans ses marques.
    let text: String
    /// Le premier passage marqué.
    let highlight: String?

    init(_ template: String) {
        let parts = template.components(separatedBy: "**")
        text = parts.joined()
        highlight = parts.count >= 3 ? parts[1].nilIfBlank : nil
    }

    /// La phrase sans ses marques : pour le lecteur d'écran, et là où rien ne se peint.
    static func plain(_ template: String) -> String {
        template.replacingOccurrences(of: "**", with: "")
    }

    /// **La phrase, son passage marqué dans une autre couleur** : pour un texte courant (la
    /// ligne de l'étude), que les composants de titre ne dessinent pas.
    static func marked(_ template: String, keyword: Color) -> Text {
        var result = Text(verbatim: "")
        let parts = template.components(separatedBy: "**")
        for (index, part) in parts.enumerated() where !part.isEmpty {
            // Une marque restée ouverte ne colore rien.
            let isKeyword = index % 2 == 1 && index < parts.count - 1
            result = result + (isKeyword ? Text(verbatim: part).foregroundStyle(keyword) : Text(verbatim: part))
        }
        return result
    }
}

/// **Mika et sa bulle** (`MikaAsk`), pour une phrase du catalogue : son mot-clé prend la
/// couleur que le système visuel donne aux mots-clés.
struct OnbBubble: View {
    private let phrase: OnbPhrase
    private let mood: MikaMood

    init(_ template: String, mood: MikaMood = .idle) {
        self.phrase = OnbPhrase(template)
        self.mood = mood
    }

    var body: some View {
        MikaAsk(phrase.text, highlight: phrase.highlight, mood: mood)
    }
}

/// **Le titre d'une page ou d'un moment** (`V3Title`), pour une phrase du catalogue. Le
/// mot-clé est en bleu clair ; `keyword` lui donne une autre couleur quand il a un autre sens
/// (le vert d'un objectif, le jaune du plan et de l'examen).
struct OnbTitle: View {
    private let template: String
    private let size: CGFloat
    private let alignment: TextAlignment
    private let keyword: Color

    init(
        _ template: String,
        size: CGFloat = OnbLayout.pageTitle,
        alignment: TextAlignment = .leading,
        keyword: Color = V3Color.accentBright
    ) {
        self.template = template
        self.size = size
        self.alignment = alignment
        self.keyword = keyword
    }

    var body: some View {
        V3Title(template, size: size, alignment: alignment, highlightColor: keyword)
    }
}

// MARK: - Le grand Mika d'un moment

/// **Le grand Mika d'un « moment »**, centré : il prend la hauteur libre de la page, entre
/// `min` et `max`. Sur un grand téléphone il fait sa pleine taille ; sur un petit, ou en très
/// grand texte, c'est lui qui cède la place, jamais le titre ni le bouton.
struct OnbHeroMika: View {
    var mood: MikaMood
    var max: CGFloat = OnbLayout.heroMax
    var min: CGFloat = OnbLayout.heroMin

    var body: some View {
        GeometryReader { proxy in
            MikaMascot(mood: mood, size: Swift.min(proxy.size.width, proxy.size.height))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minHeight: min, maxHeight: max)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - Une icône deux tons

/// **Une icône de la famille, dessinée à `size` points.** `MicaboIconView` dessine son
/// symbole aux deux tiers de sa case : on lui donne une case plus grande, comme le fait la
/// ligne de réponse (`V3OptionRow`).
struct OnbIcon: View {
    let icon: MicaboIcon
    var size: CGFloat = 34

    var body: some View {
        MicaboIconView(icon: icon, size: size * 1.35)
            .frame(width: size + 2, height: size + 2)
    }
}

// MARK: - Une ligne qui rassure

/// **« Rien à payer aujourd'hui »** : une coche et une phrase, en vert, au-dessus du bouton.
struct OnbReassurance: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "checkmark")
                .font(V3Font.label)
                .accessibilityHidden(true)
            Text(text)
                .font(V3Font.label)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(V3Color.green)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - La place du clavier

/// **La place du clavier, au bas d'une page qui en prend un** (le prénom, la recherche d'un
/// pays, le sujet de la première leçon).
///
/// Le parcours ignore le clavier (`OnboardingFlowView`) : aucun pied de page ne monte ni ne
/// redescend avec lui pendant qu'une page glisse. Les pages qui tapent du texte se terminent
/// par cet espace : il prend la hauteur du clavier, pour que la fin de la page passe
/// au-dessus de lui.
///
/// `isActive` faux (la page n'est plus l'étape du parcours) : l'espace se fige. La page part
/// telle qu'elle était, et le clavier descend sous celle qui arrive.
struct OnbKeyboardRoom: View {
    var isActive = true
    /// Ce que la page garde déjà sous son contenu (un pied fixe) : retiré de la hauteur.
    var trim: CGFloat = 0

    @State private var height: CGFloat = 0

    var body: some View {
        Color.clear
            .frame(height: height)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                move(to: Swift.max(0, Self.overlap(for: note) - trim))
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                move(to: 0)
            }
            .accessibilityHidden(true)
    }

    private func move(to target: CGFloat) {
        guard isActive, target != height else { return }
        // La courbe courte de l'app, à peu près la durée du clavier : la page monte avec lui.
        withAnimation(MicaboMotion.quick) { height = target }
    }

    /// Ce que le clavier couvre de l'écran.
    private static func overlap(for note: Notification) -> CGFloat {
        guard let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let window = MicaboScreen.keyWindow else { return 0 }
        return Swift.max(0, window.bounds.maxY - end.minY)
    }
}

// MARK: - Les mots

/// Les dates, les heures et les listes du parcours, écrites dans la langue de l'app.
enum OnbWords {
    /// « 15 juin 2027 » : le jour d'un examen.
    static func date(_ date: Date, locale: UiLocale) -> String {
        formatted(date, template: "d MMMM yyyy", locale: locale)
    }

    /// « 15 juin » : le même jour, dans une phrase.
    static func day(_ date: Date, locale: UiLocale) -> String {
        formatted(date, template: "d MMMM", locale: locale)
    }

    /// « 18 h », « 6 PM », « 18 Uhr » : l'heure du rappel.
    static func hour(_ hour: Int, locale: UiLocale) -> String {
        let moment = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        // « 18 h » ne se coupe pas en fin de ligne d'un titre : l'espace est insécable.
        return formatted(moment, template: "j", locale: locale).replacingOccurrences(of: " ", with: "\u{00A0}")
    }

    private static func formatted(_ date: Date, template: String, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// « 3 jours », « 3 Tage » : une durée, écrite par le système (il connaît les pluriels de
    /// chaque langue).
    static func duration(days: Int, locale: UiLocale) -> String {
        SchoolExams.remainingText(days: days, locale: locale)
    }

    /// « 12/20 → 16/20 » : d'où l'on part, où l'on va.
    ///
    /// **Une plage de notes s'écrit de gauche à droite, dans toutes les langues**, comme une
    /// équation : iOS pose de toute façon des chiffres et une flèche de gauche à droite (les
    /// rendus en arabe montraient « 60% ← 80% », qui se lit de 80 vers 60). La plage est donc
    /// un bloc enchâssé de gauche à droite (U+202A … U+202C), flèche vers la droite : en
    /// arabe aussi, « 60% → 80% ».
    static func range(from: String, to: String, locale: UiLocale) -> String {
        locale.isRightToLeft ? "\u{202A}\(from) → \(to)\u{202C}" : "\(from) → \(to)"
    }

    /// « Maths, Philo et Physique-Chimie » : une liste, avec la virgule et le « et » de la
    /// langue.
    static func list(_ items: [String], locale: UiLocale) -> String {
        let formatter = ListFormatter()
        formatter.locale = locale.foundation
        return formatter.string(from: items) ?? items.joined(separator: ", ")
    }
}

// MARK: - Les rendus

private struct OnboardingStillKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Un écran posé dans son état final**, pour les rendus de la CI : ni horloge, ni champ
    /// du système. Le paywall le lit aussi.
    var onboardingStill: Bool {
        get { self[OnboardingStillKey.self] }
        set { self[OnboardingStillKey.self] = newValue }
    }
}
