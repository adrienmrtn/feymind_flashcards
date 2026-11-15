import SwiftUI

// Lot 14 : « Avant de finir, on veut te montrer comment Micabo va t'aider. » Un cas concret,
// raconté en quatre écrans et une conclusion : réviser la Révolution française. Rien à jouer :
// chaque écran est un vrai morceau d'app, qui s'anime une fois à son arrivée (pas de délai,
// pas de cascade), et un bouton « Continuer ». Le même exemple pour tout le monde, dans toutes
// les langues : c'est un récit, pas une démo sur sa matière.

// MARK: - Le gabarit

/// **Une page du récit** : le titre, la phrase de Mika quand elle apporte quelque chose, le
/// morceau d'app, le bouton.
struct OnbStoryStage<Panel: View>: View {
    let title: String
    var say: OnbSay?
    @ViewBuilder let panel: () -> Panel

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)
            if let say {
                OnbMikaRow(say: say, collapsible: true)
                    .padding(.top, OnbLayout.mikaGap)
            }
            panel()
                .frame(maxWidth: .infinity)
                .padding(.top, say == nil ? OnbLayout.titleGap : OnbLayout.answersGap)
                .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}

/// **L'arrivée d'un morceau du récit** : posé tout de suite dans les rendus et avec « Réduire
/// les animations » ; sinon il se joue une fois, sous la courbe douce de l'app, dès que la page
/// est là.
private struct OnbStoryArrival: ViewModifier {
    @Binding var arrived: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still
    @Environment(\.onbSettled) private var settled

    func body(content: Content) -> some View {
        content.onAppear {
            guard !arrived else { return }
            if still || settled || reduceMotion {
                arrived = true
            } else {
                withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion)) {
                    arrived = true
                }
            }
        }
    }
}

private extension View {
    func onbStoryArrival(_ arrived: Binding<Bool>) -> some View {
        modifier(OnbStoryArrival(arrived: arrived))
    }
}

// MARK: - 1. La leçon se crée

/// **« Imagine : tu révises la Révolution française. »** Le compositeur de l'app : deux
/// supports joints, une question précise, « Créer la leçon ».
struct StoryCreateStepView: View {
    var previewArrived = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var arrived = false

    @Environment(\.onbSettled) private var settled

    private var shown: Bool { arrived || previewArrived || settled }

    var body: some View {
        OnbStoryStage(
            title: i18n.t("ios.onb14.story.create.title"),
            say: OnbSay(i18n.t("ios.onb14.story.create.say"), mood: .write)
        ) {
            OnbPanel(padding: 16) {
                HStack(spacing: 8) {
                    attachment(.pdf)
                    attachment(.photo)
                    Spacer(minLength: 0)
                }
                Text(i18n.t("ios.onb14.story.create.question"))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(V3Color.bg, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous)
                            .strokeBorder(V3Color.accent, lineWidth: V3Metric.border)
                    )
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                    Text(i18n.t("ios.onb14.story.create.cta"))
                        .font(V3Font.heading(19))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(V3Color.onAccent)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(V3Color.accent, in: Capsule())
                .scaleEffect(shown ? 1 : 0.96)
                .accessibilityHidden(true)
            }
            .onbStoryArrival($arrived)
        }
    }

    private func attachment(_ source: OnbSource) -> some View {
        HStack(spacing: 6) {
            MicaboIconView(icon: source.kind.icon, size: 18 * 1.35, tint: source.tone)
                .frame(width: 22, height: 22)
            Text(source.title(locale: i18n.locale))
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(V3Color.green)
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .background(V3Color.wash(of: source.tone), in: Capsule())
        .scaleEffect(shown ? 1 : 0.85)
        .opacity(shown ? 1 : 0)
    }
}

// MARK: - 2. Le parcours

/// **« Tu obtiens un parcours fait pour retenir. »** Le chemin de la leçon, en zigzag comme
/// dans l'app : deux thèmes, un quiz, des cartes, une révision quelques jours plus tard. Le
/// chemin se trace à l'arrivée. La phrase de Mika dit d'où vient cette forme : la recherche
/// en sciences cognitives (répétition espacée, test de récupération) — rien de plus.
struct StoryPathStepView: View {
    var previewArrived = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact
    @State private var arrived = false

    @Environment(\.onbSettled) private var settled

    private var shown: Bool { arrived || previewArrived || settled }

    struct Node: Identifiable {
        let id: Int
        let icon: MicaboIcon
        let tone: Color
        let text: String
    }

    private var nodes: [Node] {
        [
            Node(id: 0, icon: .scroll, tone: V3Color.iconBlue, text: i18n.t("ios.onb14.story.node.estates")),
            Node(id: 1, icon: .flag, tone: V3Color.iconPink, text: i18n.t("ios.onb14.story.node.bastille")),
            Node(id: 2, icon: .quiz, tone: V3Color.iconGreen, text: i18n.t("lesson.nav.quiz")),
            Node(id: 3, icon: .cards, tone: V3Color.iconLilac, text: i18n.t("lesson.nav.flashcards")),
            Node(id: 4, icon: .alarm, tone: V3Color.iconYellow, text: i18n.t("ios.onb14.story.node.review")),
        ]
    }

    private var step: CGFloat { compact ? 50 : 62 }

    var body: some View {
        OnbStoryStage(
            title: i18n.t("ios.onb14.story.path.title"),
            say: OnbSay(i18n.t("ios.onb14.story.path.say"), mood: .proud)
        ) {
            OnbPanel(padding: 16) {
                HStack(spacing: 10) {
                    OnbIcon(icon: .book, size: 24)
                    Text(i18n.t("ios.onb14.story.lesson"))
                        .font(V3Font.heading(21))
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                path
            }
            .onbStoryArrival($arrived)
        }
    }

    /// Les nœuds en zigzag, et le trait qui les relie.
    private var path: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let points = nodes.indices.map { index in
                CGPoint(x: index.isMultiple(of: 2) ? width * 0.24 : width * 0.62, y: CGFloat(index) * step + step / 2)
            }
            ZStack(alignment: .topLeading) {
                Path { line in
                    line.move(to: points[0])
                    for point in points.dropFirst() { line.addLine(to: point) }
                }
                .trim(from: 0, to: shown ? 1 : 0)
                .stroke(V3Color.accent.opacity(0.55), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 9]))

                ForEach(nodes) { node in
                    let point = points[node.id]
                    HStack(spacing: 10) {
                        MicaboIconView(icon: node.icon, size: 22 * 1.35, tint: node.tone)
                            .frame(width: 44, height: 44)
                            .background(V3Color.wash(of: node.tone), in: Circle())
                            .overlay(Circle().strokeBorder(node.tone.opacity(0.7), lineWidth: 2))
                        Text(node.text)
                            .font(V3Font.label)
                            .foregroundStyle(V3Color.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: width - point.x - 34, alignment: .leading)
                    }
                    .position(x: point.x + (width - point.x - 34) / 2 + 5, y: point.y)
                    .opacity(shown ? 1 : (node.id == 0 ? 1 : 0.25))
                }
            }
        }
        .frame(height: step * CGFloat(nodes.count))
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(OnbWords.list(nodes.map(\.text), locale: i18n.locale)))
    }
}

// MARK: - 3. Quiz et cartes

/// **« Tu suis ton parcours : tu connais ta leçon. »** Une question du quiz (la bonne réponse
/// se colore, l'XP tombe) et une carte de la leçon, retournée sur sa réponse.
struct StoryPracticeStepView: View {
    var previewArrived = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact
    @State private var arrived = false

    @Environment(\.onbSettled) private var settled

    private var shown: Bool { arrived || previewArrived || settled }

    var body: some View {
        OnbStoryStage(
            title: i18n.t("ios.onb14.story.practice.title"),
            say: OnbSay(i18n.t("ios.onb14.story.practice.say"), mood: .happy)
        ) {
            VStack(spacing: 12) {
                quiz
                card
            }
            .onbStoryArrival($arrived)
        }
    }

    private var quiz: some View {
        OnbPanel(padding: 14) {
            HStack(alignment: .top) {
                Text(i18n.t("ios.onb14.story.quiz.q"))
                    .font(V3Font.heading(20))
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                OnbXPPill(points: 10)
                    .scaleEffect(shown ? 1 : 0.6)
                    .opacity(shown ? 1 : 0)
            }
            HStack(spacing: 8) {
                ForEach(["1792", "1789", "1804"], id: \.self) { year in
                    let right = year == "1789"
                    HStack(spacing: 6) {
                        Text(verbatim: year)
                            .font(V3Font.heading(20))
                            .monospacedDigit()
                        if right, shown {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundStyle(right && shown ? V3Color.green : V3Color.ink2)
                    .frame(maxWidth: .infinity, minHeight: compact ? 42 : 48)
                    .background(right && shown ? V3Color.greenWash : V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous)
                            .strokeBorder(right && shown ? V3Color.green : .clear, lineWidth: 2)
                    )
                }
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// La carte, sa question au-dessus, sa réponse qui arrive en fondu.
    private var card: some View {
        OnbPanel(padding: 14) {
            Label(i18n.t("lesson.nav.flashcards"), systemImage: "rectangle.on.rectangle.angled")
                .font(V3Font.caption)
                .foregroundStyle(V3Color.lilac)
            Text(i18n.t("ios.onb14.story.card.q"))
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(i18n.t("ios.onb14.story.card.a"))
                .font(V3Font.heading(26))
                .foregroundStyle(V3Color.lilac)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 6)
        }
    }
}

// MARK: - 4. Plus loin

/// **« Et tu vas plus loin, de quoi impressionner tes profs. »** Une question que le cours ne
/// pose pas, et la réponse de Mika.
struct StoryAskStepView: View {
    var previewArrived = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var arrived = false

    @Environment(\.onbSettled) private var settled

    private var shown: Bool { arrived || previewArrived || settled }

    var body: some View {
        OnbStoryStage(title: i18n.t("ios.onb14.story.ask.title")) {
            OnbPanel(padding: 16) {
                Text(i18n.t("ios.onb14.story.ask.q"))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.onAccent)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(V3Color.accent, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                    .padding(.leading, 40)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(alignment: .top, spacing: 10) {
                    MikaAvatar(size: 32)
                    Text(i18n.t("ios.onb14.story.ask.a"))
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                }
                .padding(.trailing, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.94, anchor: .topLeading)
            }
            .onbStoryArrival($arrived)
        }
    }
}

// MARK: - La conclusion

/// **« Tu gagnes du temps, et apprendre devient un jeu. »** Mika conclut le récit : « J'espère
/// te faire aimer apprendre : j'ai été créé pour ça. »
struct StoryCloseStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    var body: some View {
        OnbScreen {
            Spacer(minLength: 8)
                .layoutPriority(-1)
            OnbHeroMika(mood: .celebrate, max: compact ? 150 : 210, min: 110)
            VStack(spacing: 12) {
                OnbTitle(i18n.t("ios.onb14.story.close.title"), size: compact ? 30 : 34, alignment: .center)
                Text(i18n.t("ios.onb14.story.close.sub"))
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, compact ? 14 : 22)
            Spacer(minLength: 8)
                .layoutPriority(-1)
        } footer: {
            V3Button(i18n.t("common.continue")) {
                model.advance()
            }
        }
    }
}
