import SwiftUI

// Le parcours en chapitres (lot 14, réécrit au lot 15). Ici, l'écran qui ouvre un chapitre, et
// les trois pages du chapitre « Comment Mika t'aide » qui ne sont pas des démos de fonction :
// d'où vient Mika, « pas un simple ChatGPT », ce que dit la recherche.
//
// **La voix (lot 15)** : le titre, c'est l'app qui parle à l'élève — jamais « je » ; elle parle
// de Mika à la troisième personne. La bulle, c'est Mika, et lui seul, à la première personne.
// **La grille** : le titre en haut à gauche, une seule chose au centre optique, le bouton en bas.

// MARK: - L'ouverture d'un chapitre

/// **L'écran qui ouvre un chapitre** (lot 15) : la même grille que tous les écrans du
/// parcours — le titre en haut à gauche, le bouton en bas — et, au centre, Mika en grand qui
/// parle dans sa bulle. Plus de surtitre (« 3/7 · … ») : le chapitre se lit à la jauge.
///
/// **L'arrivée est sobre** : en même temps que la page glisse, Mika passe de 92 % à sa taille
/// et la bulle apparaît en fondu, sous la courbe douce de l'app — sans délai, sans saut.
/// « Réduire les animations » et les rendus le montrent posé.
struct OnbChapterOpener: View {
    /// Le titre, son mot-clé entre `**`.
    let title: String
    /// Ce que dit Mika.
    let say: String
    var mood: MikaMood = .happy
    var cta: String
    var onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still
    @Environment(\.onbSettled) private var settled
    @Environment(\.onbCompact) private var compact

    @State private var arrived = false

    private var isSettled: Bool { arrived || still || settled || reduceMotion }

    private var mikaSize: CGFloat { compact ? 150 : 210 }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbCentered {
                VStack(spacing: 4) {
                    OnbSpeech(text: say)
                        .opacity(isSettled ? 1 : 0)
                    MikaMascot(mood: mood, size: mikaSize)
                        .frame(width: mikaSize, height: mikaSize)
                        .scaleEffect(isSettled ? 1 : 0.92)
                        .opacity(isSettled ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
            }
        } footer: {
            V3Button(cta, action: onContinue)
        }
        .onAppear {
            guard !isSettled else { return }
            withAnimation(MicaboMotion.gentle) { arrived = true }
        }
    }
}

/// **Les ouvertures de chapitre où Mika parle** (la première est sa présentation,
/// `WelcomeStepView` ; celle du chapitre 6 est le chargement du plan).
struct ChapterOpenerStepView: View {
    let step: OnboardingStep

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Le titre, la phrase de Mika, et son humeur.
    static func phrase(for step: OnboardingStep) -> (title: String, say: String, mood: MikaMood) {
        switch step {
        case .studyIntro: ("ios.onb15.open.study.title", "ios.onb15.open.study.say", .look)
        case .helpIntro: ("ios.onb15.open.help.title", "ios.onb15.open.help.say", .happy)
        case .goalIntro: ("ios.onb15.open.goal.title", "ios.onb15.open.goal.say", .proud)
        case .organizeIntro: ("ios.onb15.open.organize.title", "ios.onb15.open.organize.say", .write)
        default: ("ios.onb15.open.story.title", "ios.onb15.open.story.say", .wink)
        }
    }

    var body: some View {
        let phrase = Self.phrase(for: step)
        OnbChapterOpener(
            title: i18n.t(phrase.title),
            say: i18n.t(phrase.say),
            mood: phrase.mood,
            cta: i18n.t(step == .helpIntro || step == .storyIntro ? "ios.onb12.recap.cta" : "common.continue")
        ) {
            model.advance()
        }
    }
}

// MARK: - Les sources d'une leçon

/// **Les cinq façons d'apporter un cours** (lot 14 : « dire aussi PDF, micro, photo, YouTube,
/// texte »), celles du compositeur de leçon de l'app (`LessonComposer.Kind`).
enum OnbSource: CaseIterable, Identifiable {
    case pdf
    case lecture
    case photo
    case youtube
    case text

    var id: Self { self }

    var kind: LessonComposer.Kind {
        switch self {
        case .pdf: .pdf
        case .lecture: .lecture
        case .photo: .photo
        case .youtube: .youtube
        case .text: .text
        }
    }

    var tone: Color {
        switch self {
        case .pdf: V3Color.iconOrange
        case .lecture: V3Color.iconPink
        case .photo: V3Color.iconBlue
        case .youtube: V3Color.iconYellow
        case .text: V3Color.iconGreen
        }
    }

    func title(locale: UiLocale) -> String {
        L10n.t(kind.titleKey, locale: locale)
    }
}

/// **Le bandeau des sources** : cinq tuiles d'icône, leur nom dessous. Dans les stories, la
/// démo de la leçon et le récit final.
struct OnbSourceStrip: View {
    var tile: CGFloat = 46
    /// La source mise en avant (la photo, dans la démo de la leçon).
    var highlighted: OnbSource?

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(OnbSource.allCases) { source in
                VStack(spacing: 6) {
                    MicaboIconView(icon: source.kind.icon, size: tile * 0.62 * 1.35, tint: source.tone)
                        .frame(width: tile, height: tile)
                        .background(V3Color.wash(of: source.tone), in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                        .overlay {
                            if source == highlighted {
                                RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous)
                                    .strokeBorder(source.tone, lineWidth: 2)
                            }
                        }
                    Text(source.title(locale: i18n.locale))
                        .font(V3Font.caption)
                        .foregroundStyle(source == highlighted ? V3Color.ink : V3Color.ink2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - D'où vient Mika

/// **« Mika a été créé pour ranger ta pile de cours. »** (lot 15, mots du fondateur.) Mika au
/// milieu, et autour de lui la pile en vrac : un PDF, une fiche, un document, un enregistrement,
/// une photo de cahier. « Ranger la pile » : tout s'envole dans **une seule carte**, « Tes
/// cours », rangée par matière — les siennes.
struct OriginStepView: View {
    /// Pour les rendus : la pile déjà rangée.
    var previewTidy = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onbCompact) private var compact

    @State private var tidy = false

    private var isTidy: Bool { tidy || previewTidy }

    /// La pile en vrac : une icône, sa teinte, sa place autour de Mika et son angle, à la main.
    private static let pile: [(icon: MicaboIcon, tone: Color, x: CGFloat, y: CGFloat, angle: Double)] = [
        (.pdf, V3Color.iconPink, -0.36, -0.30, -14),
        (.notes, V3Color.iconLilac, 0.02, -0.42, 7),
        (.document, V3Color.iconYellow, 0.36, -0.28, 11),
        (.audio, V3Color.iconGreen, -0.38, 0.22, -7),
        (.photo, V3Color.iconBlue, 0.38, 0.26, 12),
    ]

    /// Les matières de la carte rangée : les siennes, la plus dure d'abord, quatre au plus.
    private var subjects: [String] {
        var ordered = model.subjects.sorted()
        if let hardest = model.hardestSubject, let index = ordered.firstIndex(of: hardest) {
            ordered.remove(at: index)
            ordered.insert(hardest, at: 0)
        }
        return Array(ordered.prefix(4))
    }

    var body: some View {
        OnbScreen {
            OnbTitle(i18n.t("ios.onb15.origin.title"), size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbCentered {
                ZStack {
                    if isTidy {
                        tidied
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        scattered
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { arrange() }
            }
        } footer: {
            V3Button(i18n.t(isTidy ? "common.continue" : "ios.onb14.origin.play")) {
                if isTidy { model.advance() } else { arrange() }
            }
        }
    }

    /// La pile en vrac, autour de Mika.
    private var scattered: some View {
        let side: CGFloat = compact ? 250 : 320
        let tile: CGFloat = compact ? 58 : 72
        return ZStack {
            MikaMascot(mood: .surprise, size: compact ? 120 : 160)
                .accessibilityHidden(true)
            ForEach(Array(Self.pile.enumerated()), id: \.offset) { _, item in
                MicaboIconView(icon: item.icon, size: tile * 0.56 * 1.35, tint: item.tone)
                    .frame(width: tile, height: tile)
                    .background(V3Color.wash(of: item.tone), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(V3Color.line, lineWidth: V3Metric.border)
                    )
                    .rotationEffect(.degrees(item.angle))
                    .offset(x: item.x * side, y: item.y * side)
            }
        }
        .frame(width: side, height: side * 0.95)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(OnbWords.list(OnbSource.allCases.map { $0.title(locale: i18n.locale) }, locale: i18n.locale)))
    }

    /// La pile rangée : Mika, et la carte « Tes cours », une ligne par matière.
    private var tidied: some View {
        VStack(spacing: 0) {
            MikaMascot(mood: .happy, size: compact ? 96 : 130)
                .accessibilityHidden(true)
                .zIndex(1)
            VStack(alignment: .leading, spacing: 12) {
                Text(i18n.t("ios.onb15.origin.yours"))
                    .font(V3Font.heading(26))
                    .foregroundStyle(V3Color.ink)
                HStack(spacing: 8) {
                    ForEach(Array(Self.pile.enumerated()), id: \.offset) { _, item in
                        MicaboIconView(icon: item.icon, size: 22 * 1.35, tint: item.tone)
                            .frame(width: 40, height: 40)
                            .background(V3Color.wash(of: item.tone), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .accessibilityHidden(true)
                ForEach(subjects, id: \.self) { subject in
                    HStack(spacing: 12) {
                        OnbIcon(icon: MicaboIcon.subjectIcon(subject) ?? .book, size: 26)
                        Text(SubjectDisplay.subject(subject, locale: i18n.locale))
                            .font(OnbType.label)
                            .foregroundStyle(V3Color.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card(selected: true)
            .padding(.top, -14)
        }
        .accessibilityElement(children: .combine)
    }

    private func arrange() {
        guard !isTidy else { return }
        Haptics.success()
        withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion)) {
            tidy = true
        }
    }
}

// MARK: - « Pas un simple ChatGPT »

/// **« Mika n'est pas un simple ChatGPT. »** (lot 15 : Mika à la troisième personne.) Trois
/// lignes, tirées de ses réponses et vraies : fait pour les élèves de sa classe, des leçons
/// plutôt que des pavés de texte, sa façon de réviser (son temps, sa méthode, ses blocages).
/// Aucun chiffre. Au centre optique de la page.
struct NotJustChatStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    struct Line: Identifiable {
        var id: String { text }
        let icon: MicaboIcon
        let tone: Color
        let text: String
    }

    /// Les trois lignes : sa classe quand on la connaît.
    static func lines(for model: OnboardingModel, locale: UiLocale) -> [Line] {
        let trained = model.classLabel.map {
            L10n.t("ios.onb15.chat.trained", locale: locale, vars: ["class": $0])
        } ?? L10n.t("ios.onb15.chat.trainedAny", locale: locale)
        return [
            Line(icon: .diploma, tone: V3Color.iconBlue, text: trained),
            Line(icon: .book, tone: V3Color.iconGreen, text: L10n.t("ios.onb15.chat.lessons", locale: locale)),
            Line(icon: .brain, tone: V3Color.iconLilac, text: L10n.t("ios.onb15.chat.habits", locale: locale)),
        ]
    }

    var body: some View {
        OnbScreen {
            OnbTitle(i18n.t("ios.onb15.chat.title"), size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbCentered {
                VStack(alignment: .leading, spacing: compact ? 20 : 28) {
                    ForEach(Self.lines(for: model, locale: i18n.locale)) { line in
                        HStack(alignment: .center, spacing: 16) {
                            MicaboIconView(icon: line.icon, size: 28 * 1.35, tint: line.tone)
                                .frame(width: 56, height: 56)
                                .background(V3Color.wash(of: line.tone), in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                            Text(v3: OnbPhrase(line.text).text, highlight: OnbPhrase(line.text).highlight)
                                .font(OnbType.body)
                                .lineSpacing(OnbType.bodySpacing)
                                .foregroundStyle(V3Color.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}

// MARK: - Ce que dit la recherche

/// **Ce que dit la recherche** (lot 14, réécrit au lot 15) : la seule étude du parcours —
/// Kestin et al., « AI tutoring outperforms in-class active learning », Scientific Reports,
/// 2025 : des étudiants (physique, Harvard) avec un tuteur IA conçu pour l'enseignement ont eu
/// un gain d'apprentissage médian plus de deux fois supérieur à celui d'un cours en classe actif,
/// en moins de temps.
///
/// **Un visuel, sans logo** : deux barres (le cours en classe, le tuteur IA, « ×2 »), « Et en
/// moins de temps. », puis la source écrite en clair. Le blason d'une université est une marque,
/// il laisserait croire à un partenariat (App Store 5.2).
struct ResearchStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    var body: some View {
        OnbScreen {
            OnbTitle(i18n.t("ios.onb15.research.title"), size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbCentered {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: compact ? 14 : 20) {
                        bar(i18n.t("ios.onb15.research.class"), share: 0.42, badge: "×1", strong: false)
                        bar(i18n.t("ios.onb15.research.ai"), share: 0.84, badge: i18n.t("ios.research.badge"), strong: true)
                        Text(i18n.t("ios.onb15.research.faster"))
                            .font(OnbType.body)
                            .foregroundStyle(V3Color.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .v3Card()

                    Text(i18n.t("ios.onb15.research.source"))
                        .font(OnbType.mention)
                        .foregroundStyle(V3Color.ink2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                }
            }
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }

    /// Une barre : son nom, sa longueur, son chiffre.
    private func bar(_ label: String, share: CGFloat, badge: String, strong: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(OnbType.label)
                .foregroundStyle(V3Color.ink)
            HStack(spacing: 12) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(strong ? V3Color.accent : V3Color.ink3)
                        .frame(width: proxy.size.width * share)
                }
                .frame(height: 30)
                Text(verbatim: badge)
                    .font(V3Font.display(strong ? 44 : 28))
                    .foregroundStyle(strong ? V3Color.accentBright : V3Color.ink2)
                    .fixedSize()
                    .frame(width: 64, alignment: .leading)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
        .accessibilityElement(children: .combine)
    }
}
