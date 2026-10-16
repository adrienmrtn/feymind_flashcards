import Combine
import SwiftUI

// MARK: - Mika calcule le parcours

/// **Après la preuve sociale, Mika se met au travail** : il relit les réponses, règle le niveau
/// sur l'année déclarée, cale le rythme du jour. Le même écran que le chargement du début — le
/// blob, le pourcentage, la grille de points —, avec ses propres phrases, et le rond n'arrive
/// qu'à cent pour cent : personne ne doit sauter le moment où son parcours se construit.
struct PlanBuildingStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    static let duration = 5.0

    @State private var elapsed = 0.0
    @State private var hasLanded = false
    @State private var didFinish = false
    @State private var showsAction = false

    private static let ticker = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    /// Deux ralentissements, comme un vrai calcul qui bute un peu.
    private var progress: Double {
        let time = min(1, elapsed / Self.duration)
        let eased = time < 0.5 ? 2 * time * time : 1 - pow(-2 * time + 2, 2) / 2
        return min(1, eased)
    }

    private var stepLabel: String {
        let index = min(3, Int(progress * 4))
        return i18n.t("ios.plan.step\(index + 1)")
    }

    var body: some View {
        VStack(spacing: 0) {
            MikaLoadingView(
                progress: progress,
                title: i18n.t("ios.plan.title"),
                subtitle: i18n.t("ios.plan.role"),
                stepLabel: stepLabel,
                isDone: didFinish
            )

            OnboardingArrowBar { model.advance() }
                .opacity(showsAction ? 1 : 0)
                .allowsHitTesting(showsAction)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + OnboardingMotion.slideDuration + 0.05) {
                hasLanded = true
            }
        }
        .onReceive(Self.ticker) { _ in
            guard hasLanded, !didFinish else { return }
            elapsed = min(Self.duration, elapsed + 1.0 / 30.0)
            if elapsed >= Self.duration {
                didFinish = true
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeOut(duration: 0.35)) { showsAction = true }
                }
            }
        }
    }
}

// MARK: - Le profil

/// **« Voici ton profil »** : tout ce qu'on vient de dire à Mika, relu en une carte — le pays,
/// le niveau, les matières, la moyenne et l'objectif, le temps et l'heure —, puis ce que Mika va
/// en faire. C'est le moment où les questions deviennent un plan : chaque ligne vient d'une
/// réponse, aucune n'est inventée.
struct ProfileSummaryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var shown = false

    private var name: String {
        model.displayName.nilIfBlank ?? OnboardingPreferences.displayName ?? ""
    }

    private var scale: DesiredGradeScale { DesiredGradeScale.for(model.country) }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(spacing: 22) {
                    MikaMascot(mood: .happy, size: 96, reactsToTap: true)
                        .scaleEffect(shown || still ? 1 : 0.4)
                        .opacity(shown || still ? 1 : 0)
                        .accessibilityHidden(true)

                    OnboardingAccentText(
                        template: name.isEmpty ? i18n.t("ios.profileCard.titleNoName") : i18n.t("ios.profileCard.title", ["name": name]),
                        size: 28,
                        alignment: .center
                    )
                    .onboardingAppear(index: 1)

                    card
                        .onboardingAppear(index: 2)

                    helps
                        .onboardingAppear(index: 3)
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar { model.advance() }
                .onboardingAppear(index: 4)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.1)) { shown = true }
        }
    }

    // MARK: La carte

    private var card: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle().fill(MicaboColor.stroke).frame(height: 1).padding(.leading, 56)
                }
                HStack(spacing: 12) {
                    MicaboIconView(icon: row.icon, size: 34)
                    Text(row.label)
                        .font(MicaboFont.ui(14, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Text(row.value)
                        .font(MicaboFont.ui(15, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                .padding(.vertical, 11)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
    }

    private struct Row {
        let icon: MicaboIcon
        let label: String
        let value: String
    }

    /// Les lignes de la carte, dans l'ordre du parcours. Une réponse absente (un écran sauté)
    /// ne laisse pas de ligne vide : la ligne disparaît.
    private var rows: [Row] {
        var result: [Row] = []
        let locale = i18n.locale
        let country: String = {
            if model.country == .other, let custom = model.customCountry { return "\(custom.flag) \(custom.name)" }
            return "\(model.country.flag) \(model.country.localizedName(locale: locale))"
        }()
        result.append(Row(icon: .globe, label: i18n.t("ios.profileCard.country"), value: country))

        if let level = model.year?.title ?? model.track?.title ?? model.stage?.localizedTitle {
            result.append(Row(icon: .diploma, label: i18n.t("ios.profileCard.level"), value: level))
        }

        let subjects = model.subjects.sorted().map { SubjectDisplay.subject($0, locale: locale) }
        if !subjects.isEmpty {
            let shown = subjects.prefix(2).joined(separator: ", ")
            let value = subjects.count > 2
                ? i18n.t("ios.profileCard.more", ["list": shown, "n": "\(subjects.count - 2)"])
                : shown
            result.append(Row(icon: .book, label: i18n.t("ios.profileCard.subjects"), value: value))
        }

        if let current = model.currentScore {
            var value = grade(current)
            if let target = model.targetScore { value += " → " + grade(target) }
            result.append(Row(icon: .trophy, label: i18n.t("ios.profileCard.average"), value: value))
        }

        if let minutes = model.dailyMinutes {
            result.append(Row(icon: .hourglass, label: i18n.t("ios.profileCard.daily"), value: i18n.t("ios.quiz.time.short", ["n": "\(minutes)"])))
        }

        if let hour = model.studyHour {
            result.append(Row(icon: .alarm, label: i18n.t("ios.profileCard.hour"), value: Self.hourText(hour, locale: locale)))
        }
        return result
    }

    // MARK: Ce que Mika va faire

    private var helps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n.t("ios.profileCard.helpTitle"))
                .font(MicaboFont.ui(17, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
            ForEach(Array(helpLines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(MicaboColor.onInk, MicaboColor.correct)
                    Text(line)
                        .font(MicaboFont.ui(15.5, weight: .semibold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    /// L'objectif chiffré d'abord, puis les objectifs cochés, puis le rythme : trois ou quatre
    /// lignes, pas un catalogue.
    private var helpLines: [String] {
        var lines: [String] = []
        if let current = model.currentScore, let target = model.targetScore {
            lines.append(i18n.t("ios.profileCard.help.target", ["current": grade(current), "target": grade(target)]))
        }
        let goals = LearningGoal.allCases.filter { model.goals.contains($0) }.prefix(2)
        lines += goals.map { $0.title(locale: i18n.locale) }
        if let worry = model.leadWorry {
            lines.append(i18n.t("ios.profileCard.help.worry", ["worry": worry.title(locale: i18n.locale)]))
        }
        if let minutes = model.dailyMinutes {
            lines.append(i18n.t("ios.profileCard.help.daily", ["n": "\(minutes)"]))
        }
        if lines.isEmpty { lines.append(i18n.t("ios.profileCard.help.default")) }
        return lines
    }

    private func grade(_ score: Int) -> String {
        if score <= DesiredGradeScale.belowScore {
            return i18n.t("ios.averageBelow", ["grade": scale.choices.first?.label ?? ""])
        }
        return scale.label(for: score)
    }

    static func hourText(_ hour: Int, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("j")
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - L'essai offert

/// **« Nous tenons à ce que tu essaies ton parcours avec Mika gratuitement. »** Mika arrive
/// couronné pendant que la phrase se lit. Ensuite, comment marche l'essai.
struct FreeTrialIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var mikaShown = false
    @State private var isReady = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                OnboardingCenteredScroll {
                    VStack(spacing: 26) {
                        ZStack {
                            Circle()
                                .fill(RadialGradient(colors: [MicaboColor.correct.opacity(0.22), MicaboColor.correct.opacity(0)], center: .center, startRadius: 4, endRadius: 120))
                                .frame(width: 240, height: 240)
                            MikaMascot(mood: .celebrate, size: 150, reactsToTap: true)
                            MicaboIconView(icon: .crown, size: 54)
                                .rotationEffect(.degrees(14))
                                .offset(x: 64, y: -66)
                        }
                        .frame(height: 200)
                        .scaleEffect(mikaShown || still ? 1 : 0.4)
                        .opacity(mikaShown || still ? 1 : 0)
                        .accessibilityHidden(true)

                        OnboardingReadingText(
                            template: i18n.t("ios.freeTrial.title"),
                            size: 29,
                            wordDelay: 0.14,
                            startDelay: 0.9,
                            highlightsOnFinish: true,
                            onFinish: { withAnimation(.easeOut(duration: 0.35)) { isReady = true } }
                        )
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.vertical, MicaboSpacing.md)
                }

                OnboardingArrowBar { model.advance() }
                    .opacity(isReady || still ? 1 : 0)
                    .allowsHitTesting(isReady)
            }
            .onboardingChromeInset()
            .background(OnboardingPalette.white.ignoresSafeArea())
        }
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.2)) { mikaShown = true }
        }
    }
}
