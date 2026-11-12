import Combine
import SwiftUI

// MARK: - Mika prépare le plan

/// **« Je prépare ton plan… »** Le seul chargement du parcours, et sa seule horloge.
///
/// Mika écrit ; le pourcentage monte ; la liste se coche ligne à ligne, et chaque ligne est
/// une réponse de l'élève (sa classe, ses matières, son examen et sa date, son temps par jour
/// et l'heure, sa première leçon : `OnboardingModel.planLines`). Une information absente
/// retire sa ligne. À cent pour cent, l'écran avance seul, vers le plan révélé.
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
    private static let tick = 1.0 / 30.0
    private static let clock = Timer.publish(every: tick, on: .main, in: .common).autoconnect()

    @State private var elapsed = 0.0
    @State private var didAdvance = false

    /// De 0 à 1. La course part vite et se pose : c'est un travail qui s'achève.
    private var progress: Double {
        if let previewProgress { return previewProgress }
        let time = min(1, elapsed / Self.duration)
        return 1 - (1 - time) * (1 - time)
    }

    private var lines: [String] {
        model.planLines(locale: i18n.locale)
    }

    /// Le nombre de lignes cochées : elles se partagent la course, la dernière à cent.
    private var checked: Int {
        Self.checkedCount(progress: progress, lines: lines.count)
    }

    static func checkedCount(progress: Double, lines: Int) -> Int {
        guard lines > 0 else { return 0 }
        return min(lines, Int((progress * Double(lines) + 0.0001).rounded(.down)))
    }

    var body: some View {
        V3Screen {
            Spacer(minLength: 16)
                .layoutPriority(-1)

            OnbHeroMika(mood: .write, max: 170)

            VStack(spacing: 6) {
                Text(i18n.t("ios.onb10.build.title"))
                    .font(V3Font.h1)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.percent(Int((progress * 100).rounded()), locale: i18n.locale))
                    .font(V3Font.display(52))
                    .foregroundStyle(V3Color.ink2)
                    .monospacedDigit()
                V3ProgressBar(value: progress)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .accessibilityElement(children: .combine)

            checklist
                .padding(.top, OnbLayout.titleGap)

            Spacer(minLength: 16)
                .layoutPriority(-1)
        }
        .onReceive(Self.clock) { _ in
            advanceClock()
        }
        .onChange(of: checked) { previous, next in
            guard next > previous, previewProgress == nil, !still else { return }
            Haptics.soft()
        }
    }

    /// La liste, dans une carte : cochée, en cours (un anneau), à venir.
    private var checklist: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .center, spacing: 12) {
                    mark(index)
                    Text(line)
                        .font(V3Font.body)
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

    /// L'horloge : elle avance tant que l'écran est celui du parcours, puis passe la main.
    private func advanceClock() {
        guard previewProgress == nil, !still, !didAdvance, model.step == .planBuilding else { return }
        elapsed += Self.tick
        if elapsed >= Self.duration + Self.hold {
            Haptics.success()
            didAdvance = model.advance()
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
        V3Screen {
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
