import SwiftUI

// MARK: - Mika prépare le plan

/// **« Je prépare ton plan… »** Le seul chargement du parcours, et sa seule horloge.
///
/// Mika écrit ; le pourcentage monte ; la liste se coche ligne à ligne, et chaque ligne est
/// une réponse de l'élève (sa classe, ses matières, son examen et sa date, son temps par jour
/// et l'heure, sa première leçon : `OnboardingModel.planLines`). Une information absente
/// retire sa ligne. À cent pour cent, l'écran avance seul, vers le plan révélé.
///
/// **L'horloge ne redessine que ce qui bouge** : le pourcentage, la jauge et la liste vivent
/// dans une vue à part, sous une `TimelineView` périodique. Mika et le titre ne sont pas relus
/// trente fois par seconde.
struct PlanBuildingStepView: View {
    /// Pour les rendus : l'avancement à montrer, figé.
    var previewProgress: Double?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    /// La durée du chargement, en secondes.
    static let duration = 4.4
    /// Ce qu'on laisse lire « 100 % » avant d'avancer.
    static let hold = 0.4
    /// Le pas de l'horloge : trente images par seconde suffisent à un pourcentage.
    private static let tick = 1.0 / 30.0

    /// L'instant où le chargement a commencé.
    @State private var start = Date()
    @State private var didAdvance = false

    /// De 0 à 1, d'après le temps écoulé. La course part vite et se pose : c'est un travail
    /// qui s'achève.
    static func progress(elapsed: TimeInterval) -> Double {
        let time = min(1, max(0, elapsed / duration))
        return 1 - (1 - time) * (1 - time)
    }

    /// Le nombre de lignes cochées : elles se partagent la course, la dernière à cent.
    static func checkedCount(progress: Double, lines: Int) -> Int {
        guard lines > 0 else { return 0 }
        return min(lines, Int((progress * Double(lines) + 0.0001).rounded(.down)))
    }

    private var lines: [String] {
        model.planLines(locale: i18n.locale)
    }

    var body: some View {
        OnbScreen {
            Spacer(minLength: 16)
                .layoutPriority(-1)

            OnbHeroMika(mood: .write, max: 170)

            Text(i18n.t("ios.onb10.build.title"))
                .font(V3Font.h1)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .accessibilityAddTraits(.isHeader)

            if let frozen = previewProgress ?? (still ? 1 : nil) {
                PlanBuildingProgress(progress: frozen, lines: lines, isLive: false)
            } else {
                TimelineView(.periodic(from: start, by: Self.tick)) { context in
                    let elapsed = context.date.timeIntervalSince(start)
                    PlanBuildingProgress(progress: Self.progress(elapsed: elapsed), lines: lines, isLive: true)
                        .onChange(of: elapsed >= Self.duration + Self.hold) { _, isOver in
                            guard isOver else { return }
                            finish()
                        }
                }
            }

            Spacer(minLength: 16)
                .layoutPriority(-1)
        }
    }

    /// Le chargement est fini : le parcours passe au plan révélé, une fois.
    private func finish() {
        guard !didAdvance, model.step == .planBuilding else { return }
        didAdvance = true
        Haptics.success()
        model.advance()
    }
}

/// **Ce qui bouge pendant le chargement** : le pourcentage, la jauge, et la liste qui se coche.
private struct PlanBuildingProgress: View {
    let progress: Double
    let lines: [String]
    /// Faux dans un rendu : pas de retour haptique.
    let isLive: Bool

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var checked: Int {
        PlanBuildingStepView.checkedCount(progress: progress, lines: lines.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.percent(Int((progress * 100).rounded()), locale: i18n.locale))
                .font(V3Font.display(52))
                .foregroundStyle(V3Color.ink2)
                .monospacedDigit()
                .padding(.top, 6)
            V3ProgressBar(value: progress)
                .padding(.top, 8)

            checklist
                .padding(.top, OnbLayout.titleGap)
        }
        .frame(maxWidth: .infinity)
        .onChange(of: checked) { previous, next in
            guard isLive, next > previous else { return }
            Haptics.soft()
        }
    }

    /// La liste, dans une carte : cochée, en cours (un anneau), à venir.
    private var checklist: some View {
        VStack(alignment: .leading, spacing: 15) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .center, spacing: 12) {
                    mark(index)
                    Text(line)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(index <= checked ? V3Color.ink : V3Color.ink3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card()
    }

    @ViewBuilder
    private func mark(_ index: Int) -> some View {
        if index < checked {
            Image(systemName: "checkmark.circle.fill")
                .font(V3Font.title)
                .foregroundStyle(V3Color.green)
        } else if index == checked {
            Image(systemName: "circle")
                .font(V3Font.title)
                .foregroundStyle(V3Color.accent)
        } else {
            Image(systemName: "circle.fill")
                .font(V3Font.title)
                .foregroundStyle(V3Color.line)
        }
    }
}

// MARK: - Le plan révélé

/// **« {prénom}, ton plan est prêt »** : le moment où le parcours rend ce qu'il a demandé.
///
/// Mika en fête, des confettis une fois, et la carte du plan : chaque ligne vient d'une
/// réponse (l'examen et son jour, les matières, le temps par jour et l'heure, l'objectif dans
/// le barème de l'élève, la première leçon). Une réponse absente retire sa ligne au lieu d'en
/// inventer une. Le compte se propose en quittant cet écran.
///
/// Le nom de l'étape reste `profileSummary` : sa courbe dans les statistiques continue.
struct ProfileSummaryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    private var title: String {
        guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb10.plan.titleNoName") }
        return i18n.t("ios.onb10.plan.title", ["name": name])
    }

    private var rows: [OnboardingPlanRow] {
        model.planSummary(locale: i18n.locale)
    }

    var body: some View {
        OnbScreen {
            Spacer(minLength: 12)
                .layoutPriority(-1)

            OnbHeroMika(mood: .celebrate)

            OnbTitle(title, size: OnbLayout.display, alignment: .center)
                .padding(.top, 10)

            summary
                .padding(.top, OnbLayout.titleGap)

            Spacer(minLength: 12)
                .layoutPriority(-1)
        } footer: {
            V3Button(i18n.t("ios.deckBuild.seePlan")) {
                model.advance()
            }
        }
        .overlay {
            // Les confettis tombent une fois ; « Réduire les animations » les retire.
            if !still {
                ConfettiView(colors: [V3Color.accent, V3Color.yellow, V3Color.green, V3Color.pink])
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    /// La carte du plan : un libellé à gauche, sa valeur à droite, un filet entre deux lignes.
    private var summary: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(V3Color.line)
                        .frame(height: 1.5)
                }
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(row.label)
                        .font(V3Font.body)
                        .foregroundStyle(V3Color.ink2)
                        .fixedSize()
                    Text(row.value)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(row.isAccent ? V3Color.green : V3Color.ink)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 13)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .v3Card()
    }
}
