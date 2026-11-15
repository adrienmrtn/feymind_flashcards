import SwiftUI

// Lot 14 : le parcours en chapitres. Ici, l'écran qui ouvre un chapitre (Mika parle seul, en
// grand), et les trois pages du chapitre « Comment je t'aide » qui ne sont pas des démos de
// fonction : d'où vient Mika, « je ne suis pas juste ChatGPT », ce que dit la recherche.

// MARK: - L'ouverture d'un chapitre

/// **L'écran qui ouvre un chapitre** : le nom du chapitre en surtitre (« 3/7 · Comment je
/// t'aide »), un grand Mika, une phrase forte, le bouton. Rien d'autre.
///
/// **L'arrivée est sobre** : en même temps que la page glisse, Mika passe de 92 % à sa taille
/// et la phrase apparaît en fondu, sous la courbe douce de l'app — sans délai, sans saut.
/// « Réduire les animations » et les rendus le montrent posé.
struct OnbChapterOpener: View {
    /// Le chapitre, de 0 à `OnboardingStep.chapterCount - 1`.
    let chapter: Int
    /// La phrase de Mika, son mot-clé entre `**`.
    let text: String
    var sub: String?
    var mood: MikaMood = .happy
    var cta: String
    var onContinue: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still
    @Environment(\.onbSettled) private var settled
    @Environment(\.onbCompact) private var compact

    @State private var arrived = false

    private var isSettled: Bool { arrived || still || settled || reduceMotion }

    /// « 3/7 · Comment je t'aide ».
    static func label(chapter: Int, locale: UiLocale) -> String {
        let name = L10n.t(OnboardingStep.chapterTitleKey(chapter), locale: locale)
        return "\(chapter + 1)/\(OnboardingStep.chapterCount) · \(name)"
    }

    var body: some View {
        OnbScreen {
            Spacer(minLength: 8)
                .layoutPriority(-1)

            OnbHeroMika(mood: mood, max: compact ? 150 : 210, min: 110)
                .scaleEffect(isSettled ? 1 : 0.92)
                .opacity(isSettled ? 1 : 0)

            VStack(spacing: 12) {
                Text(Self.label(chapter: chapter, locale: i18n.locale))
                    .font(V3Font.eyebrow)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(V3Color.accentBright)
                    .multilineTextAlignment(.center)
                OnbTitle(text, size: compact ? 30 : 34, alignment: .center)
                if let sub {
                    Text(sub)
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink2)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, compact ? 14 : 22)
            .opacity(isSettled ? 1 : 0)

            Spacer(minLength: 8)
                .layoutPriority(-1)
        } footer: {
            V3Button(cta, action: onContinue)
        }
        .onAppear {
            guard !isSettled else { return }
            withAnimation(MicaboMotion.gentle) { arrived = true }
        }
    }
}

/// **Les cinq ouvertures de chapitre qui ne sont que la phrase de Mika** (la première est la
/// présentation de Mika, `WelcomeStepView` ; la sixième est le chargement du plan).
struct ChapterOpenerStepView: View {
    let step: OnboardingStep

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// La phrase de Mika, et son humeur.
    static func phrase(for step: OnboardingStep) -> (key: String, mood: MikaMood) {
        switch step {
        case .studyIntro: ("ios.onb14.open.study", .look)
        case .helpIntro: ("ios.onb14.open.help", .happy)
        case .goalIntro: ("ios.onb14.open.goal", .proud)
        case .organizeIntro: ("ios.onb14.open.organize", .write)
        default: ("ios.onb14.open.story", .wink)
        }
    }

    var body: some View {
        let phrase = Self.phrase(for: step)
        OnbChapterOpener(
            chapter: step.chapter,
            text: i18n.t(phrase.key),
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

/// **« J'ai été créé par des élèves qui avaient besoin de ranger leur pile de cours au même
/// endroit. »** (lot 14, mots de l'utilisateur.) La pile est là, en vrac : un PDF, un cours
/// enregistré, des photos, une vidéo, du texte. « Ranger » les réunit dans Micabo.
struct OriginStepView: View {
    /// Pour les rendus : la pile déjà rangée.
    var previewTidy = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onbCompact) private var compact

    @State private var tidy = false

    private var isTidy: Bool { tidy || previewTidy }

    /// La place d'une feuille dans la pile en vrac : un décalage et un angle, à la main.
    private static let scatter: [(x: CGFloat, y: CGFloat, angle: Double)] = [
        (-34, -104, -8), (30, -52, 6), (-26, 0, 4), (36, 52, -6), (-14, 104, -3),
    ]

    private var rowHeight: CGFloat { compact ? 44 : 50 }

    var body: some View {
        OnbScreen {
            OnbTitle(i18n.t("ios.onb14.origin.title"), size: compact ? 26 : 30)
                .padding(.top, OnbLayout.titleTop)

            pile
                .frame(maxWidth: .infinity)
                .padding(.top, compact ? 18 : 30)
                .contentShape(Rectangle())
                .onTapGesture { arrange() }
        } footer: {
            V3Button(i18n.t(isTidy ? "common.continue" : "ios.onb14.origin.play")) {
                if isTidy { model.advance() } else { arrange() }
            }
        }
    }

    /// La pile : en vrac, chaque feuille de travers ; rangée, une colonne dans une carte Micabo.
    private var pile: some View {
        let count = CGFloat(OnbSource.allCases.count)
        let stackHeight = count * rowHeight + (count - 1) * 8
        return ZStack(alignment: .top) {
            // La carte de Micabo apparaît derrière la colonne rangée.
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    MikaAvatar(size: 26)
                    Text(verbatim: "Micabo")
                        .font(V3Font.heading(20))
                        .foregroundStyle(V3Color.ink)
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                Spacer(minLength: 0)
            }
            .frame(width: 286, height: stackHeight + 72, alignment: .topLeading)
            .v3Card(selected: true)
            .opacity(isTidy ? 1 : 0)
            .scaleEffect(isTidy ? 1 : 0.94)

            ForEach(Array(OnbSource.allCases.enumerated()), id: \.offset) { index, source in
                sheet(source)
                    .rotationEffect(.degrees(isTidy ? 0 : Self.scatter[index].angle))
                    .offset(
                        x: isTidy ? 0 : Self.scatter[index].x,
                        y: isTidy
                            ? 54 + CGFloat(index) * (rowHeight + 8)
                            : (stackHeight + 72) / 2 - rowHeight / 2 + Self.scatter[index].y
                    )
            }
        }
        .frame(height: stackHeight + 72)
        .environment(\.layoutDirection, i18n.locale.isRightToLeft ? .rightToLeft : .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(OnbWords.list(OnbSource.allCases.map { $0.title(locale: i18n.locale) }, locale: i18n.locale)))
    }

    private func sheet(_ source: OnbSource) -> some View {
        HStack(spacing: 10) {
            MicaboIconView(icon: source.kind.icon, size: 24 * 1.35, tint: source.tone)
                .frame(width: 30, height: 30)
            Text(source.title(locale: i18n.locale))
                .font(V3Font.option)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(width: 254, height: rowHeight)
        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous)
                .strokeBorder(V3Color.line, lineWidth: V3Metric.border)
        )
    }

    private func arrange() {
        guard !isTidy else { return }
        Haptics.success()
        withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion)) {
            tidy = true
        }
    }
}

// MARK: - « Je ne suis pas juste ChatGPT »

/// **« Je ne suis pas juste ChatGPT. »** (lot 14, mots de l'utilisateur.) Trois lignes, tirées
/// de ses réponses et vraies : conçu pour les élèves de sa classe (le programme et le niveau de
/// son pays), des leçons construites et interactives, ses habitudes de travail (son temps, sa
/// méthode, ses blocages). Aucun chiffre.
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
            L10n.t("ios.onb14.chat.trained", locale: locale, vars: ["class": $0])
        } ?? L10n.t("ios.onb14.chat.trainedAny", locale: locale)
        return [
            Line(icon: .diploma, tone: V3Color.iconBlue, text: trained),
            Line(icon: .book, tone: V3Color.iconGreen, text: L10n.t("ios.onb14.chat.lessons", locale: locale)),
            Line(icon: .brain, tone: V3Color.iconLilac, text: L10n.t("ios.onb14.chat.habits", locale: locale)),
        ]
    }

    var body: some View {
        OnbScreen {
            OnbTitle(i18n.t("ios.onb14.chat.title"), size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)

            OnbHeroMika(mood: .proud, max: compact ? 96 : 140, min: 80)
                .padding(.top, compact ? 8 : 18)

            VStack(alignment: .leading, spacing: compact ? 16 : 22) {
                ForEach(Self.lines(for: model, locale: i18n.locale)) { line in
                    HStack(alignment: .center, spacing: 14) {
                        MicaboIconView(icon: line.icon, size: 26 * 1.35, tint: line.tone)
                            .frame(width: 44, height: 44)
                            .background(V3Color.wash(of: line.tone), in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                        Text(v3: OnbPhrase(line.text).text, highlight: OnbPhrase(line.text).highlight)
                            .font(V3Font.bodyStrong)
                            .foregroundStyle(V3Color.ink)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.top, compact ? 14 : 26)
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}

// MARK: - Ce que dit la recherche

/// **Ce que dit la recherche** (lot 14) : la seule étude du parcours, citée telle quelle —
/// Kestin et al., « AI tutoring outperforms in-class active learning », Scientific Reports,
/// 2025 (Harvard). **Une citation typographique, sans logo** : le blason d'une université est
/// une marque, il laisserait croire à un partenariat (App Store 5.2). La source est écrite en
/// clair, au corps de lecture.
struct ResearchStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    var body: some View {
        OnbScreen {
            Spacer(minLength: 8)
                .layoutPriority(-1)

            VStack(spacing: compact ? 12 : 18) {
                Text(i18n.t("ios.research.eyebrow"))
                    .font(V3Font.eyebrow)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(V3Color.accentBright)
                    .multilineTextAlignment(.center)

                Text(i18n.t("ios.research.badge"))
                    .font(V3Font.display(compact ? 80 : 104))
                    .foregroundStyle(V3Color.accentBright)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityHidden(true)

                OnbTitle(i18n.t("ios.research.quote"), size: compact ? 23 : 26, alignment: .center)

                Rectangle()
                    .fill(V3Color.line)
                    .frame(width: 44, height: 2)
                    .padding(.top, 4)

                Text(i18n.t("ios.research.source"))
                    .font(V3Font.support)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 8)
                .layoutPriority(-1)
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}
