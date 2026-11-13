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
    /// Le titre d'une question ou d'une démonstration : l'élément dominant de l'écran.
    static let questionTitle: CGFloat = 36
    /// Le même titre sur un écran court.
    static let questionTitleCompact: CGFloat = 30
    /// Entre le titre et Mika.
    static let mikaGap: CGFloat = 12
    /// Entre Mika et les réponses (ou le morceau d'app).
    static let answersGap: CGFloat = 16
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
    static let heroWelcome: CGFloat = 220

    /// En dessous de cette hauteur de page (un iPhone SE, sous la barre du haut), l'écran est
    /// court : Mika et les morceaux d'app se resserrent.
    static let compactHeight: CGFloat = 640

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
/// l'appareil » (`OnboardingLot12RenderTests`) le vérifient avec les vraies marges.
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
            .environment(\.onbCompact, outer.size.height < OnbLayout.compactHeight)
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

// MARK: - Ce que dit Mika

/// **Une réplique de Mika** : sa phrase (son mot-clé entre `**`) et l'humeur qui va avec.
struct OnbSay: Equatable {
    var text: String
    var mood: MikaMood

    init(_ text: String, mood: MikaMood = .idle) {
        self.text = text
        self.mood = mood
    }
}

/// **Mika qui réagit, sous le titre** (lot 12) : un grand Mika (112 pt, 80 sur un petit
/// écran), perché du côté de fin, **qui dépasse derrière le bloc de réponses** — ses
/// tentacules passent sous la première carte —, et sa réplique dans une bulle secondaire qui
/// pointe vers lui. Le titre domine ; Mika a du poids sans manger la place des réponses.
///
/// La rangée a toujours la hauteur de Mika : une réplique qui change de longueur ne déplace
/// rien en dessous.
///
/// Quand la réplique change (l'élève vient de répondre), le texte fait un fondu, la bulle fait
/// un petit ressort, et Mika change d'humeur (son geste, une fois). Rien ne retarde la page.
struct OnbMikaRow: View {
    let say: OnbSay
    /// Vrai : sur un écran court, la réplique s'efface et laisse la place à ce qui est promis.
    var collapsible = false

    @Environment(\.onbCompact) private var compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var size: CGFloat { compact ? 80 : 112 }
    /// Ce que le bloc suivant recouvre de Mika : le bas de ses tentacules.
    private var overlap: CGFloat { (size * 0.17).rounded() }

    var body: some View {
        if !(compact && collapsible) {
            row
        }
    }

    private var row: some View {
        let phrase = OnbPhrase(say.text)
        let calm = reduceMotion
        return HStack(alignment: .bottom, spacing: 2) {
            Text(v3: phrase.text, highlight: phrase.highlight)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    V3Color.surface,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: V3Metric.radiusBubble,
                        bottomLeadingRadius: V3Metric.radiusBubble,
                        bottomTrailingRadius: V3Metric.radiusBubbleTail,
                        topTrailingRadius: V3Metric.radiusBubble,
                        style: .continuous
                    )
                )
                .keyframeAnimator(initialValue: CGFloat(1), trigger: say.text) { content, scale in
                    content.scaleEffect(calm ? 1 : scale, anchor: .bottomTrailing)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.035, duration: 0.12)
                        SpringKeyframe(1.0, duration: 0.25)
                    }
                }
                // La bulle se pose au niveau de la bouche de Mika, au-dessus du bloc suivant.
                .padding(.bottom, overlap + size * 0.18)
            MikaMascot(mood: say.mood, size: size)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
        .frame(minHeight: size)
        .padding(.bottom, -overlap)
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: say.text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(phrase.text))
    }
}

// MARK: - Une question

/// **Une question du parcours** (lot 12) : **le titre en grand, en haut**, la question
/// elle-même, son mot-clé en couleur ; dessous, Mika qui réagit dans sa bulle ; dessous, les
/// réponses, groupées. Le bouton, quand il y en a un, est au pied, toujours au même endroit.
///
/// Plus de question dans une petite bulle, plus de grand vide entre la question et les
/// réponses : l'œil va du titre à Mika, puis aux réponses.
struct OnbQuestion<Answers: View, Footer: View>: View {
    private let title: String
    private let say: OnbSay?
    private let answers: Answers
    private let footer: Footer

    init(
        _ title: String,
        say: OnbSay?,
        @ViewBuilder answers: () -> Answers,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.say = say
        self.answers = answers()
        self.footer = footer()
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)
            if let say {
                OnbMikaRow(say: say)
                    .padding(.top, OnbLayout.mikaGap)
            }
            answers
                .padding(.top, OnbLayout.answersGap)
        } footer: {
            footer
        }
    }
}

extension OnbQuestion where Footer == EmptyView {
    /// Une question à choix unique : pas de bouton, la réponse avance.
    init(_ title: String, say: OnbSay?, @ViewBuilder answers: () -> Answers) {
        self.init(title, say: say, answers: answers, footer: { EmptyView() })
    }
}

// MARK: - Une réponse qui se coche

/// **Une ligne de réponse qui réagit** : la ligne de l'app (`V3OptionRow`), plus un petit
/// ressort quand elle devient choisie. Le retour haptique est celui de la ligne.
struct OnbOption: View {
    let title: String
    var subtitle: String?
    var icon: MicaboIcon?
    var emoji: String?
    let isSelected: Bool
    var multiple = false
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Lus avant la fermeture de l'animation, qui n'est pas isolée au fil principal.
        let calm = reduceMotion
        let selected = isSelected
        V3OptionRow(title, subtitle: subtitle, icon: icon, emoji: emoji, isSelected: isSelected, multiple: multiple, action: action)
            .keyframeAnimator(initialValue: CGFloat(1), trigger: isSelected) { content, scale in
                content.scaleEffect(calm || !selected ? 1 : scale)
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(1.03, duration: 0.1)
                    SpringKeyframe(1.0, duration: 0.22)
                }
            }
    }
}

/// **Un choix unique qui avance** : la réponse s'écrit sous le ressort court de l'app (la
/// coche apparaît, la ligne se gonfle), et la page part **à la fin de ce ressort** — pas après
/// une minuterie. « Réduire les animations » : un fondu bref, puis la page.
enum OnbPick {
    static func choose(on step: OnboardingStep, model: OnboardingModel, _ apply: () -> Void) {
        guard model.step == step else { return }
        let curve = MicaboMotion.resolved(MicaboMotion.quick, reduceMotion: UIAccessibility.isReduceMotionEnabled)
        withAnimation(curve, completionCriteria: .logicallyComplete) {
            apply()
        } completion: {
            guard model.step == step else { return }
            model.advance()
        }
    }
}

// MARK: - Une démonstration jouable

/// **Une démonstration du parcours** (lot 12) : un morceau d'app à jouer, grand, dans la DA.
///
/// En haut, le blocage qu'elle soigne (une étiquette) et la promesse (le titre) ; Mika
/// dessous, qui dit quoi faire puis réagit ; puis le morceau d'app, qui prend la place qui
/// reste. Le bouton du pied **joue la démonstration** tant qu'elle ne l'a pas été (« Retourner
/// la carte », « Prendre la photo »…), puis devient « Continuer ». Toucher le morceau d'app
/// joue aussi.
struct OnbDemoStage<Panel: View>: View {
    let title: String
    let say: OnbSay
    /// Le libellé du bouton tant que la démonstration n'est pas jouée ; `nil` : « Continuer ».
    var playLabel: String?
    let isPlayed: Bool
    var onPlay: () -> Void = {}
    @ViewBuilder let panel: () -> Panel

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)
            OnbMikaRow(say: say)
                .padding(.top, OnbLayout.mikaGap)
            panel()
                .frame(maxWidth: .infinity)
                .padding(.top, OnbLayout.answersGap)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        } footer: {
            if isPlayed || playLabel == nil {
                V3Button(i18n.t("common.continue")) {
                    model.advance()
                }
            } else if let playLabel {
                V3Button(playLabel, kind: .primary) {
                    onPlay()
                }
            }
        }
    }
}

/// **Le cadre d'un morceau d'app** : une grande surface, rayon des cartes, sans ombre.
struct OnbPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .v3Card()
    }
}

// MARK: - Les temps forts

/// **Une fête** : des confettis qui tombent une fois, par-dessus la page, quand `isOn` passe
/// à vrai. « Réduire les animations » les retire (`ConfettiView`), et les rendus aussi.
struct OnbConfetti: View {
    let isOn: Bool

    @Environment(\.onboardingStill) private var still

    var body: some View {
        if isOn, !still {
            ConfettiView(colors: [V3Color.accent, V3Color.yellow, V3Color.green, V3Color.pink, V3Color.lilac])
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// **Un gain d'XP**, en pastille jaune : « +10 XP ». Il apparaît d'un ressort.
struct OnbXPPill: View {
    let points: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .black))
            Text(verbatim: "+\(points) XP")
                .font(V3Font.heading(18))
                .monospacedDigit()
        }
        .foregroundStyle(V3Color.onYellow)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(V3Color.yellow, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - La petite taille

private struct OnbCompactKey: EnvironmentKey {
    static let defaultValue = false
}

/// **Mesure la hauteur de la page** et dit aux écrans du parcours s'ils sont courts
/// (`onbCompact`) : posé sur la page entière, il vaut aussi pour les vues de l'étape, pas
/// seulement pour ce que `OnbScreen` contient.
struct OnbCompactReader: ViewModifier {
    /// La page a la barre du haut : elle lui laisse sa hauteur.
    let chrome: Bool

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            content
                .environment(\.onbCompact, proxy.size.height - (chrome ? OnboardingTopBar.height : 0) < OnbLayout.compactHeight)
        }
    }
}

private struct OnbSettledKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **Les arrivées déjà jouées** : la courbe tracée, le point posé. Pour les rendus sur
    /// appareil, qui gardent le défilement de l'iPhone mais photographient l'état final.
    var onbSettled: Bool {
        get { self[OnbSettledKey.self] }
        set { self[OnbSettledKey.self] = newValue }
    }

    /// **Un écran court** (iPhone SE, très grand texte) : Mika et les morceaux d'app se
    /// resserrent, le titre et le bouton gardent leur taille.
    var onbCompact: Bool {
        get { self[OnbCompactKey.self] }
        set { self[OnbCompactKey.self] = newValue }
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

    @Environment(\.onbCompact) private var compact

    var body: some View {
        // Un titre de question passe à 30 pt sur un écran court : il reste l'élément dominant,
        // et les réponses remontent.
        let shown = compact && size >= OnbLayout.questionTitle ? OnbLayout.questionTitleCompact : size
        V3Title(template, size: shown, alignment: alignment, highlightColor: keyword)
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
