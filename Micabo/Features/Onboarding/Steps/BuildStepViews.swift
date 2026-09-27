import Combine
import SwiftUI

// MARK: - « Merci de nous faire confiance. »

/// Un écran pour une phrase, entre la dernière question et le calcul. Il gagne sa place
/// parce qu'il change de registre : jusqu'ici on demandait, à partir d'ici on rend. C'est
/// l'écran « thank you for trusting us » de Cal AI, et il fait exactement ça.
struct ThanksStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var subtitle: String {
        if let name = model.displayName.nilIfBlank {
            return i18n.t("ios.build.thanks.subNamed", ["name": name])
        }
        return i18n.t("ios.build.thanks.sub")
    }

    var body: some View {
        OnboardingProofPage(
            headline: i18n.t("ios.build.thanks.title"),
            caption: subtitle
        ) {
            Image(systemName: "checkmark")
                .font(.system(size: 44, weight: .bold))
                .foregroundStyle(OnboardingPalette.white)
                .frame(width: 112, height: 112)
                .background(OnboardingPalette.ink, in: Circle())
                .accessibilityHidden(true)
        } onContinue: {
            model.advance()
        }
    }
}

// MARK: - « 67 %, on prépare ton plan »

/// **Le calcul du plan.** Un pourcentage en très grand qui compte, une barre fine dessous,
/// et une liste de quatre lignes qui se cochent. Purement visuel — les réponses sont déjà
/// enregistrées — mais il ne doit jamais laisser croire que l'app a gelé.
///
/// **Il dure cinq secondes**, et c'est un plancher, pas une approximation. Un écran qui
/// annonce qu'il construit un plan puis disparaît en une seconde n'a rien construit.
///
/// **La fin ne se saute pas d'elle-même** : c'est l'élève qui appuie.
struct BuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Durée du chargement, en secondes. Verrouillée par un test.
    static let duration = 5.0

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

/// **Quatre cartes, quatre chiffres qui appartiennent à l'élève** : les cartes par jour,
/// ses matières, les jours avant le jour J, la moyenne visée. C'est l'écran « your custom
/// plan is ready » de Cal AI, avec ses anneaux remplacés par ce que Micabo sait.
struct PlanReadyStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var target: String {
        DesiredGradeScale.for(model.country).label(for: model.targetScore ?? TargetScore.max)
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.build.ready.title"),
            subtitle: i18n.t("ios.build.ready.sub"),
            contentSpacing: MicaboSpacing.lg
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    tile(value: "\(model.cardsPerDay)", label: i18n.t("ios.build.ready.cards"), accent: true)
                    tile(value: "\(model.subjects.count)", label: i18n.t("ios.build.ready.subjects", ["count": "\(model.subjects.count)"]))
                }
                HStack(spacing: 12) {
                    tile(value: "J-\(model.daysToExam)", label: i18n.t("ios.build.ready.exam"))
                    tile(value: target, label: i18n.t("ios.build.ready.target"))
                }
            }
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.build.ready.cta")) {
                model.advance()
            }
        }
    }

    private func tile(value: String, label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(MicaboFont.ui(40, weight: .bold))
                .foregroundStyle(accent ? OnboardingPalette.white : OnboardingPalette.ink)
                .tracking(-1.5)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(label)
                .font(MicaboFont.ui(13, weight: .medium))
                .foregroundStyle(accent ? OnboardingPalette.white.opacity(0.75) : OnboardingPalette.gray)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
        .background(
            accent ? OnboardingPalette.accent : OnboardingPalette.card,
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}
