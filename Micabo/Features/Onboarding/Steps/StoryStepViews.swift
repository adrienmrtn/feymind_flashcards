import SwiftUI

// Lot 14, réécrit au lot 15 : « Voyons une leçon, du début à la fin. » Un exemple annoncé comme
// tel — la Révolution française —, raconté en quatre écrans et une conclusion, puis « Et toi,
// ta première leçon ? ». Chaque écran : un titre (la voix de l'app, jamais « je »), un vrai
// morceau d'app en grand au centre optique, le bouton. Pas de bulle : le morceau d'app parle.
// Le même exemple pour tout le monde, dans toutes les langues : c'est un récit, pas une démo sur
// sa matière. Faits vérifiés : la Bastille tombe en 1789, la monarchie en août 1792, Louis XVI
// fuit vers l'est en juin 1791 et il est arrêté à Varennes.

// MARK: - Le gabarit

/// **Une page du récit** : le titre, la phrase de Mika quand elle apporte quelque chose, le
/// morceau d'app, le bouton.
struct OnbStoryStage<Panel: View>: View {
    let title: String
    var say: OnbSay?
    /// Le libellé du bouton ; « Continuer » par défaut.
    var cta: String?
    var ctaSymbol: String?
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
            OnbCentered {
                panel()
                    .frame(maxWidth: .infinity)
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
            }
        } footer: {
            V3Button(cta ?? i18n.t("common.continue"), systemImage: ctaSymbol) {
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

/// **« Tu poses ta question, Mika crée la leçon. »** La barre de création de l'app, en grand :
/// deux supports joints, une question précise. Le bouton du pied crée la leçon ; l'écran
/// suivant montre ce qui en sort.
struct StoryCreateStepView: View {
    var previewArrived = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var arrived = false

    @Environment(\.onbSettled) private var settled

    private var shown: Bool { arrived || previewArrived || settled }

    var body: some View {
        OnbStoryStage(
            title: i18n.t("ios.onb15.story.create.title"),
            cta: i18n.t("ios.onb14.story.create.cta"),
            ctaSymbol: "sparkles"
        ) {
            OnbPanel(padding: 18) {
                HStack(spacing: 8) {
                    attachment(.pdf)
                    attachment(.photo)
                    Spacer(minLength: 0)
                }
                Text(i18n.t("ios.onb14.story.create.question"))
                    .font(OnbType.body)
                    .lineSpacing(OnbType.bodySpacing)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                    .background(V3Color.bg, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous)
                            .strokeBorder(V3Color.accent, lineWidth: 2)
                    )
            }
            .onbStoryArrival($arrived)
        }
    }

    private func attachment(_ source: OnbSource) -> some View {
        HStack(spacing: 8) {
            MicaboIconView(icon: source.kind.icon, size: 20 * 1.35, tint: source.tone)
                .frame(width: 26, height: 26)
            Text(source.title(locale: i18n.locale))
                .font(.system(.subheadline, design: .default, weight: .semibold))
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
                .fixedSize()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(V3Color.green)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
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

    private var step: CGFloat { compact ? 56 : 72 }

    var body: some View {
        OnbStoryStage(title: i18n.t("ios.onb15.story.path.title")) {
            OnbPanel(padding: 18) {
                HStack(spacing: 10) {
                    OnbIcon(icon: .book, size: 26)
                    Text(i18n.t("ios.onb14.story.lesson"))
                        .font(V3Font.heading(24))
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
                CGPoint(x: index.isMultiple(of: 2) ? width * 0.12 : width * 0.52, y: CGFloat(index) * step + step / 2)
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
                        MicaboIconView(icon: node.icon, size: 26 * 1.35, tint: node.tone)
                            .frame(width: 54, height: 54)
                            .background(V3Color.wash(of: node.tone), in: Circle())
                            .overlay(Circle().strokeBorder(node.tone.opacity(0.7), lineWidth: 2.5))
                        Text(node.text)
                            .font(OnbType.label)
                            .foregroundStyle(node.id == 4 ? V3Color.yellow : V3Color.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: width - point.x - 40, alignment: .leading)
                    }
                    .position(x: point.x + (width - point.x - 40) / 2 + 8, y: point.y)
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

// MARK: - 3. Le quiz

/// **« Tu t'entraînes, et tu retiens. »** Une seule question du quiz de la leçon, en grand : la
/// bonne réponse se colore, l'XP tombe. (La carte retournée est partie au lot 15 : une chose
/// par écran.)
struct StoryPracticeStepView: View {
    var previewArrived = false

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact
    @State private var arrived = false

    @Environment(\.onbSettled) private var settled

    private var shown: Bool { arrived || previewArrived || settled }

    var body: some View {
        OnbStoryStage(title: i18n.t("ios.onb15.story.practice.title")) {
            OnbPanel(padding: 20) {
                HStack(alignment: .center) {
                    Text(verbatim: "\(i18n.t("lesson.nav.quiz")) · \(i18n.t("ios.onb14.story.lesson"))")
                        .font(OnbType.mention)
                        .foregroundStyle(V3Color.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    OnbXPPill(points: 10)
                        .scaleEffect(shown ? 1 : 0.6)
                        .opacity(shown ? 1 : 0)
                }
                Text(i18n.t("ios.onb14.story.quiz.q"))
                    .font(V3Font.heading(30))
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 10) {
                    ForEach(["1792", "1789", "1804"], id: \.self) { year in
                        let right = year == "1789"
                        HStack(spacing: 8) {
                            Text(verbatim: year)
                                .font(V3Font.heading(28))
                                .monospacedDigit()
                            if right, shown {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                            }
                        }
                        .foregroundStyle(right && shown ? V3Color.green : V3Color.ink)
                        .frame(maxWidth: .infinity, minHeight: compact ? 50 : 60)
                        .background(right && shown ? V3Color.greenWash : V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous)
                                .strokeBorder(right && shown ? V3Color.green : .clear, lineWidth: 2)
                        )
                    }
                }
                .environment(\.layoutDirection, .leftToRight)
            }
            .onbStoryArrival($arrived)
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
        OnbStoryStage(title: i18n.t("ios.onb15.story.ask.title")) {
            VStack(spacing: 14) {
                Text(i18n.t("ios.onb14.story.ask.q"))
                    .font(OnbType.body)
                    .lineSpacing(OnbType.bodySpacing)
                    .foregroundStyle(V3Color.onAccent)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background(V3Color.accent, in: RoundedRectangle(cornerRadius: V3Metric.radiusBubble, style: .continuous))
                    .padding(.leading, 44)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                HStack(alignment: .bottom, spacing: 10) {
                    MikaAvatar(size: 40)
                    Text(i18n.t("ios.onb15.story.ask.a"))
                        .font(OnbType.body)
                        .lineSpacing(OnbType.bodySpacing)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(V3Color.surface, in: RoundedRectangle(cornerRadius: V3Metric.radiusBubble, style: .continuous))
                }
                .padding(.trailing, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(shown ? 1 : 0)
                .scaleEffect(shown ? 1 : 0.94, anchor: .topLeading)
            }
            .onbStoryArrival($arrived)
        }
    }
}

// MARK: - La conclusion

/// **« Mika a été créé pour te faire aimer apprendre. »** (lot 15, mots du fondateur) Mika
/// conclut le récit, en grand, dans sa bulle : « Tu gagnes du temps, et apprendre devient un
/// jeu. » Puis : « Et toi, ta première leçon ? »
struct StoryCloseStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnbChapterOpener(
            title: i18n.t("ios.onb15.story.close.title"),
            say: i18n.t("ios.onb14.story.close.title"),
            mood: .celebrate,
            cta: i18n.t("common.continue")
        ) {
            model.advance()
        }
    }
}
