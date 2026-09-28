import Combine
import SwiftUI

// MARK: - « Merci de nous faire confiance. »

/// Un écran pour une phrase, entre la dernière question et le calcul. Il gagne sa place
/// parce qu'il change de registre : jusqu'ici on demandait, à partir d'ici on rend.
///
/// **La phrase se lit, lentement, et il n'y a pas de bouton.** Les mots passent à l'encre
/// l'un après l'autre ; une fois la phrase lue, une ligne grise dit qu'on peut toucher.
/// L'appui surligne « confiance », et la page suivante arrive dans la foulée : c'est un
/// merci qu'on lit, pas un écran qu'on passe.
struct ThanksStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isArmed = false
    @State private var didTap = false

    private var subtitle: String {
        if let name = model.displayName.nilIfBlank {
            return i18n.t("ios.build.thanks.subNamed", ["name": name])
        }
        return i18n.t("ios.build.thanks.sub")
    }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingChrome(showsBack: false)

            VStack(spacing: 0) {
                Spacer(minLength: MicaboSpacing.lg)

                Image(systemName: "checkmark")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(OnboardingPalette.white)
                    .frame(width: 88, height: 88)
                    .background(OnboardingPalette.ink, in: Circle())
                    .accessibilityHidden(true)
                    .onboardingAppear(index: 1)

                OnboardingReadingText(
                    template: i18n.t("ios.build.thanks.title"),
                    size: 34,
                    wordDelay: 0.26,
                    startDelay: 0.7,
                    highlightsOnFinish: false,
                    isHighlighted: didTap,
                    onFinish: { isArmed = true },
                    onHighlighted: { model.advance() }
                )
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xl)

                Text(subtitle)
                    .font(MicaboFont.ui(15, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, MicaboSpacing.xl)
                    .padding(.top, MicaboSpacing.md)
                    .opacity(isArmed ? 1 : 0)
                    .animation(.easeOut(duration: 0.4), value: isArmed)

                Spacer(minLength: MicaboSpacing.lg)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(i18n.t("ios.proof.tap"))
                .font(MicaboFont.ui(14, weight: .medium))
                .foregroundStyle(OnboardingPalette.grayLight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .opacity(isArmed && !didTap ? 1 : 0)
                .animation(.easeOut(duration: 0.4), value: isArmed)
                .animation(.easeOut(duration: 0.2), value: didTap)
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isArmed, !didTap else { return }
            didTap = true
            Haptics.light()
        }
    }
}

// MARK: - « 67 %, on prépare ton plan »

/// **Le calcul du plan.** Un pourcentage en très grand qui compte, une barre fine dessous,
/// et une liste de quatre lignes qui se cochent. Purement visuel — les réponses sont déjà
/// enregistrées — mais il ne doit jamais laisser croire que l'app a gelé.
///
/// **Il dure huit secondes**, et c'est un plancher, pas une approximation. Un écran qui
/// annonce qu'il construit un plan puis disparaît en une seconde n'a rien construit ; à
/// cinq secondes, il avait encore l'air d'une animation.
///
/// **La fin ne se saute pas d'elle-même** : c'est l'élève qui appuie.
struct BuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Durée du chargement, en secondes. Verrouillée par un test.
    static let duration = 8.0

    private var steps: [String] {
        (1...4).map { i18n.t("ios.build.step\($0)") }
    }

    @State private var elapsed = 0.0
    @State private var completed = 0
    @State private var didRing = false

    private static let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// **Le chargement ne monte pas au métronome.** Une barre parfaitement linéaire se lit
    /// comme une animation, pas comme un travail.
    private static let curve: [(at: Double, reached: Double)] = [
        (0.00, 0.00), (0.08, 0.21), (0.22, 0.27), (0.36, 0.55), (0.48, 0.61),
        (0.64, 0.83), (0.82, 0.88), (0.94, 0.98), (1.00, 1.00),
    ]

    private var progress: Double {
        let time = min(1, elapsed / Self.duration)
        var previous = Self.curve[0]
        for point in Self.curve.dropFirst() {
            if time <= point.at {
                let span = point.at - previous.at
                let ratio = span > 0 ? (time - previous.at) / span : 1
                return previous.reached + (point.reached - previous.reached) * ratio
            }
            previous = point
        }
        return 1
    }

    private var isDone: Bool { completed >= steps.count }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 28) {
                Spacer(minLength: 0)

                Text("\(Int(progress * 100)) %")
                    .font(MicaboFont.ui(88, weight: .bold))
                    .foregroundStyle(OnboardingPalette.ink)
                    .tracking(-4)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                Text(isDone ? i18n.t("ios.build.done") : i18n.t("ios.build.title"))
                    .font(OnboardingPalette.title(26))
                    .foregroundStyle(OnboardingPalette.ink)
                    .tracking(-0.6)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 40)
                    .animation(OnboardingMotion.enter, value: isDone)

                MicaboProgressBar(progress: progress, tint: OnboardingPalette.accent, track: OnboardingPalette.card)
                    .frame(height: 6)
                    .padding(.horizontal, MicaboSpacing.xl)

                checklist
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, MicaboSpacing.screen)

            MicaboBottomBar(background: OnboardingPalette.white) {
                OnboardingContinueButton(
                    isEnabled: isDone,
                    isLoading: !isDone,
                    loadingTitle: i18n.t("ios.build.busy")
                ) {
                    model.advance()
                }
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onReceive(Self.ticker) { _ in tick() }
    }

    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(index < completed ? OnboardingPalette.ink : OnboardingPalette.card)
                        if index < completed {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(OnboardingPalette.white)
                        }
                    }
                    .frame(width: 24, height: 24)
                    .animation(OnboardingMotion.select, value: completed)

                    Text(step)
                        .font(MicaboFont.ui(15, weight: index <= completed ? .medium : .regular))
                        .foregroundStyle(index <= completed ? OnboardingPalette.ink : OnboardingPalette.grayLight)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MicaboSpacing.md)
    }

    private func tick() {
        guard elapsed < Self.duration else { return }
        elapsed = min(Self.duration, elapsed + 1.0 / 30.0)

        let reached = min(steps.count, Int(progress * Double(steps.count)))
        if reached > completed {
            completed = reached
            Haptics.tick()
        }

        if elapsed >= Self.duration, !didRing {
            didRing = true
            completed = steps.count
            Haptics.success()
        }
    }
}

// MARK: - « Ton plan est prêt. »

/// **Une coche noire, une phrase, et une carte de quatre lignes** : le rythme, les
/// matières, le temps par jour, l'objectif. Chaque ligne porte une icône, un libellé gris et sa
/// valeur en gras à droite. C'est l'écran « your custom plan is ready » de Cal AI, réduit
/// à ce que Micabo sait, et lisible en deux secondes.
struct PlanReadyStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var target: String {
        DesiredGradeScale.for(model.country).label(for: model.targetScore ?? TargetScore.max)
    }

    private var subjectsText: String {
        let names = model.subjects.sorted().map { SubjectDisplay.subject($0, locale: i18n.locale) }
        switch names.count {
        case 0: return "—"
        case 1, 2: return names.joined(separator: ", ")
        default: return i18n.t("ios.build.ready.subjectsMore", ["first": names[0], "n": "\(names.count - 1)"])
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            chrome

            ScrollView {
                VStack(spacing: 0) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(OnboardingPalette.white)
                        .frame(width: 72, height: 72)
                        .background(OnboardingPalette.ink, in: Circle())
                        .padding(.top, MicaboSpacing.xl)
                        .onboardingAppear(index: 0)

                    Text(i18n.t("ios.build.ready.title"))
                        .font(OnboardingPalette.title(34))
                        .foregroundStyle(OnboardingPalette.ink)
                        .tracking(-0.9)
                        .multilineTextAlignment(.center)
                        .padding(.top, 22)
                        .onboardingAppear(index: 1)

                    Text(i18n.t("ios.build.ready.sub"))
                        .font(MicaboFont.ui(15, weight: .regular))
                        .foregroundStyle(OnboardingPalette.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .onboardingAppear(index: 2)

                    VStack(spacing: 0) {
                        row(icon: "rectangle.stack.fill", label: i18n.t("ios.build.ready.cards"), value: i18n.t("ios.build.ready.cardsValue", ["n": "\(model.cardsPerDay)"]), rank: 0)
                        divider
                        row(icon: "books.vertical.fill", label: i18n.t("ios.build.ready.subjectsLabel"), value: subjectsText, rank: 1)
                        divider
                        row(icon: "clock.fill", label: i18n.t("ios.build.ready.time"), value: i18n.t("ios.build.ready.timeValue", ["n": "\(model.minutesPerDay)"]), rank: 2)
                        divider
                        row(icon: "target", label: i18n.t("ios.build.ready.target"), value: target, rank: 3, accent: true)
                    }
                    .padding(.vertical, 6)
                    .background(OnboardingPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.top, 30)
                    .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.lg)
            }
            .scrollIndicators(.hidden)

            MicaboBottomBar(background: OnboardingPalette.white) {
                OnboardingContinueButton(title: i18n.t("ios.build.ready.cta")) {
                    model.advance()
                }
                .onboardingAppear(index: 4)
            }
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }

    private var chrome: some View {
        OnboardingChrome(showsBack: false)
    }

    private var divider: some View {
        Rectangle()
            .fill(OnboardingPalette.cardStrong)
            .frame(height: 1)
            .padding(.leading, 62)
    }

    private func row(icon: String, label: String, value: String, rank: Int, accent: Bool = false) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent ? OnboardingPalette.white : OnboardingPalette.ink)
                .frame(width: 34, height: 34)
                .background(accent ? OnboardingPalette.accent : OnboardingPalette.white, in: Circle())

            Text(label)
                .font(MicaboFont.ui(15, weight: .medium))
                .foregroundStyle(OnboardingPalette.gray)

            Spacer(minLength: 12)

            Text(value)
                .font(MicaboFont.ui(17, weight: .bold))
                .foregroundStyle(accent ? OnboardingPalette.accent : OnboardingPalette.ink)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }
}
