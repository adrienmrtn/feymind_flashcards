import SwiftUI

// Les écrans revenus au lot 9 (« l'onboarding, tu as enlevé trop de trucs ») qui ne sont pas
// des pages de Mika : l'objectif n°1, le point de départ, l'annonce de la démonstration, ce
// que ça change concrètement, l'essai offert. Les pages de Mika revenues (mission, XP et
// série, tout au même endroit, la montagne rangée) sont dans `MikaStepViews`.

// MARK: - L'objectif n°1

/// **« Et ton objectif n°1 cette année ? »** Une réponse, parmi celles de son niveau
/// (`LearningGoal.offered(for:)`).
///
/// Partie au lot 7 parce qu'elle redemandait l'examen (« réviser pour un examen » trois écrans
/// après « quel est ton prochain gros examen ? ») et proposait « monter en compétences pour le
/// travail » à un collégien. Elle revient sans l'examen — `learningGoals` l'ajoute de lui-même
/// — et avec des réponses qui tiennent à chaque niveau : de meilleures notes, la formation de
/// ses rêves au lycée, valider son année à l'université, son concours en santé.
struct GoalStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var offered: [LearningGoal] {
        LearningGoal.offered(for: model.stage?.tier)
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb9.q.goal"),
            reaction: model.mainGoal == nil ? nil : i18n.t("ios.onb9.react.goal")
        ) {
            OnboardingAnswerList(offered) { rank, goal in
                OnboardingChoiceRow(
                    title: goal.title(locale: i18n.locale),
                    emoji: goal.emoji,
                    isSelected: model.mainGoal == goal,
                    rank: rank
                ) {
                    model.goals = [goal]
                }
            }
        } footer: {
            OnboardingArrowButton(isEnabled: model.mainGoal != nil) { model.advance() }
        }
    }
}

// MARK: - Le point de départ

/// **« On part de là où tu en es. Direction : Bac 🎯 »** — le pont vers les deux moyennes.
///
/// Un chemin pointillé se trace du bas à gauche, où l'épingle « Tu es ici » est posée, vers le
/// trophée en haut à droite, qui porte le nom de son examen. Mika, en demi sur sa ligne,
/// regarde vers le haut. Sans examen daté, la phrase dit « jusqu'où je peux t'emmener » et le
/// trophée « Ton objectif ».
struct StartingPointStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onboardingStill) private var still

    @State private var shown = false
    @State private var drawn: CGFloat = 0

    /// Le nom de l'examen à viser, quand il y en a un daté.
    private var examName: String? {
        guard let exam = model.examChoice, exam.hasDate else { return nil }
        return exam.title(locale: i18n.locale)
    }

    private var title: String {
        if let examName {
            return i18n.t("ios.onb9.start.exam", ["exam": examName])
        }
        return i18n.t("ios.onb9.start.open")
    }

    private var progress: CGFloat { still ? 1 : drawn }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(spacing: MicaboSpacing.lg) {
                    scene
                        .frame(height: 300)
                        .accessibilityHidden(true)

                    OnboardingAccentText(template: title, size: 27, alignment: .center)
                        .padding(.horizontal, 26)
                        .opacity(shown || still ? 1 : 0)
                        .offset(y: shown || still ? 0 : OnboardingMotion.rise)
                }
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar { model.advance() }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(MicaboMotion.resolved(MicaboMotion.gentle, reduceMotion: reduceMotion).delay(reduceMotion ? 0 : 0.15)) {
                shown = true
            }
            guard !reduceMotion else {
                drawn = 1
                return
            }
            // Le trait se dessine en même temps que la page se pose : une fois, sans boucle.
            withAnimation(MicaboMotion.gentle.delay(OnboardingMotion.slideDuration)) { drawn = 1 }
        }
    }

    private var scene: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let start = CGPoint(x: size.width * 0.22, y: size.height * 0.62)
            let end = CGPoint(x: size.width * 0.78, y: size.height * 0.2)
            let side = min(MikaPeek.line, size.height * 0.32)
            ZStack {
                StartingTrail(from: start, to: end)
                    .stroke(MicaboColor.strokeStrong, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 10]))
                StartingTrail(from: start, to: end)
                    .trim(from: 0, to: progress)
                    .stroke(MicaboColor.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [2, 10]))

                VStack(spacing: 6) {
                    MicaboIconView(icon: .trophy, size: 64)
                    label(examName ?? i18n.t("ios.onb.start.goal"), ink: MicaboColor.flameInk, fill: MicaboColor.flameSoft)
                }
                .scaleEffect(shown || still ? 1 : 0.6)
                .opacity(shown || still ? 1 : 0)
                .position(x: end.x, y: end.y + 8)

                VStack(spacing: 4) {
                    label(i18n.t("ios.onb.start.here"), ink: MicaboColor.onInk, fill: MicaboColor.accent)
                    MicaboIconView(icon: .pin, size: 46)
                }
                .opacity(shown || still ? 1 : 0)
                .position(x: start.x, y: start.y - 30)

                OnboardingMikaOnLine(mood: .look, size: side)
                    .position(x: size.width / 2, y: size.height - OnboardingMikaOnLine.height(for: side) / 2)
            }
        }
    }

    private func label(_ text: String, ink: Color, fill: Color) -> some View {
        Text(text)
            .font(MicaboFont.ui(13, weight: .heavy))
            .foregroundStyle(ink)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(fill, in: Capsule())
            .fixedSize()
    }
}

/// Le chemin du point de départ : une courbe en S douce, du départ vers le but.
private struct StartingTrail: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        let dx = to.x - from.x
        let dy = to.y - from.y
        var path = Path()
        path.move(to: from)
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x + dx * 0.9, y: from.y + dy * 0.1),
            control2: CGPoint(x: from.x + dx * 0.1, y: from.y + dy * 0.9)
        )
        return path
    }
}

// MARK: - Une phrase de Mika, seule

/// **Une page pour une phrase de Mika** : la phrase en grand, qui se lit mot à mot dans le
/// tiers haut, et Mika en demi qui dépasse de sa ligne en bas de la page. Le rond n'arrive
/// qu'une fois le dernier mot posé. Elle sert deux fois : avant la démonstration
/// (`featuresIntro`) et avant l'essai (`freeTrialIntro`).
struct OnboardingMikaSpeechPage: View {
    let text: String
    var mood: MikaMood = .wave
    /// Une icône 3D posée près de Mika : la couronne de l'essai.
    var icon: MicaboIcon?

    @Environment(OnboardingModel.self) private var model
    @Environment(\.onboardingStill) private var still

    @State private var isReady = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: MicaboSpacing.lg)

                OnboardingReadingText(
                    template: text,
                    size: 32,
                    wordDelay: 0.16,
                    startDelay: OnboardingMotion.slideDuration + 0.1,
                    highlightsOnFinish: true,
                    onFinish: {
                        withAnimation(MicaboMotion.standard) { isReady = true }
                    }
                )
                .padding(.horizontal, MicaboSpacing.screen)

                Spacer(minLength: MicaboSpacing.lg)

                OnboardingMikaOnLine(mood: mood, size: MikaPeek.hero)
                    // La couronne de l'essai se pose sur sa tête, un peu de travers.
                    .overlay(alignment: .top) {
                        if let icon {
                            MicaboIconView(icon: icon, size: 50)
                                .rotationEffect(.degrees(-12))
                                .offset(x: -8, y: -30)
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OnboardingArrowBar { model.advance() }
                .opacity(isReady || still ? 1 : 0)
                .allowsHitTesting(isReady || still)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }
}

/// **« Maintenant, je te montre comment je vais t'aider. »** Le profil vient de se préparer ;
/// Mika annonce les écrans où il se présente.
struct FeaturesIntroStepView: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingMikaSpeechPage(text: i18n.t("ios.onb9.features"), mood: .wave)
    }
}

/// **« Lina, je tiens à ce que tu essaies ton plan gratuitement. »** Entre la révélation du
/// plan et la chronologie de l'essai, qui dit comment ça marche (dates, rappel, annulation).
struct FreeTrialIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var text: String {
        let name = model.displayName.nilIfBlank ?? OnboardingPreferences.displayName
        if let name {
            return i18n.t("ios.onb9.trial.intro", ["name": name])
        }
        return i18n.t("ios.onb9.trial.introNoName")
    }

    var body: some View {
        OnboardingMikaSpeechPage(text: text, mood: .wink, icon: .crown)
    }
}

// MARK: - Ce que ça change, concrètement

/// **Trois moments de la semaine d'un élève, avec Micabo** (`socialProof`, lot 9).
///
/// L'écran de preuve d'avant répétait l'étude déjà citée sur la question d'essai, et ses
/// chiffres (« 45 000 élèves », « 4,8 », « n°1 ») et ses avis signés n'étaient sourcés par
/// rien. Il revient sans étude, sans chiffre et sans avis inventé : ce que l'app fait
/// vraiment, dit dans la semaine de l'élève — son cours en photo, la veille d'un examen dans
/// une de ses matières, une question tard le soir. Une carte, trois lignes séparées.
struct SocialProofStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    private struct Moment: Identifiable {
        let id: String
        let icon: MicaboIcon
        let title: String
        let body: String
    }

    /// Une de ses matières, dans sa langue : la première de la liste, pour qu'elle ne change
    /// pas d'un passage à l'autre.
    private var subject: String? {
        model.subjects.sorted().first.map { SubjectDisplay.subject($0, locale: i18n.locale) }
    }

    private var moments: [Moment] {
        [
            Moment(id: "photo", icon: .photo, title: i18n.t("ios.onb9.proof.photo.title"), body: i18n.t("ios.onb9.proof.photo.body")),
            Moment(
                id: "test",
                icon: .quiz,
                title: subject.map { i18n.t("ios.onb9.proof.test.title", ["subject": $0]) } ?? i18n.t("ios.onb9.proof.test.titleAny"),
                body: i18n.t("ios.onb9.proof.test.body")
            ),
            Moment(id: "night", icon: .lightbulb, title: i18n.t("ios.onb9.proof.night.title"), body: i18n.t("ios.onb9.proof.night.body")),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    // Le titre sur toute la largeur : à côté de Mika, « Concrètement » se
                    // coupait en deux en très grand texte.
                    OnboardingAccentText(template: i18n.t("ios.onb9.proof.title"), size: 28, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onboardingAppear(index: 0)

                    // Mika passe la tête par-dessus la carte, au bord droit : le haut de la carte
                    // coupe son buste (la règle de mise en scène).
                    MikaPeek(mood: .wink, width: MikaPeek.card, reactsToTap: true, animates: !still)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, MicaboSpacing.lg)
                        .padding(.bottom, -2)
                        .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        ForEach(Array(moments.enumerated()), id: \.element.id) { index, moment in
                            if index > 0 {
                                MicaboHairline(inset: 66)
                            }
                            row(moment)
                                .onboardingAppear(index: index + 1)
                        }
                    }
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
                    .micaboElevation(.card)
                    .padding(.top, -MicaboSpacing.md)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar { model.advance() }
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }

    private func row(_ moment: Moment) -> some View {
        HStack(alignment: .top, spacing: 14) {
            MicaboIconView(icon: moment.icon, size: 36)
                .frame(width: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(moment.title)
                    .font(MicaboFont.ui(17, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(moment.body)
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .accessibilityElement(children: .combine)
    }
}
