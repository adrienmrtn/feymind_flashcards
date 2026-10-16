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

/// **« Voici ce qui va changer pour toi »** : les réponses deviennent des bénéfices. En tête,
/// la moyenne d'aujourd'hui et celle visée, côte à côte ; dessous, trois ou quatre cartes qui
/// disent ce que l'élève gagne — sa crainte principale d'abord, réglée, puis des cours faits
/// sur ses matières, les examens blancs, le rythme du jour. Chaque carte vient d'une réponse ;
/// aucune n'est inventée, et une réponse absente retire sa carte au lieu de la laisser vide.
struct ProfileSummaryStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private var name: String {
        model.displayName.nilIfBlank ?? OnboardingPreferences.displayName ?? ""
    }

    private var scale: DesiredGradeScale { DesiredGradeScale.for(model.country) }

    var body: some View {
        VStack(spacing: 0) {
            OnboardingCenteredScroll {
                VStack(spacing: 20) {
                    OnboardingAccentText(
                        template: name.isEmpty ? i18n.t("ios.profileCard.titleNoName") : i18n.t("ios.profileCard.title", ["name": name]),
                        size: 28,
                        alignment: .center
                    )
                    .onboardingAppear(index: 1)

                    if let current = model.currentScore, let target = model.targetScore {
                        goal(current: current, target: target)
                            .onboardingAppear(index: 2)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(benefits.enumerated()), id: \.offset) { index, benefit in
                            BenefitCard(benefit: benefit)
                                .onboardingAppear(index: 3 + index)
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.md)
            }

            OnboardingArrowBar { model.advance() }
                .onboardingAppear(index: 7)
        }
        .onboardingChromeInset()
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
    }

    // MARK: L'objectif

    /// Aujourd'hui → l'objectif, en grand : la seule promesse chiffrée de la page.
    private func goal(current: Int, target: Int) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(i18n.t("ios.profileCard.goal.now"))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                Text(grade(current))
                    .font(MicaboFont.ui(30, weight: .heavy))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)

            Image(systemName: "arrow.right")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 44, height: 44)
                .background(MicaboColor.accentSoft, in: Circle())

            VStack(spacing: 6) {
                Text(i18n.t("ios.profileCard.goal.target"))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                MikaGradientText(text: grade(target), size: 34, weight: .heavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .micaboElevation(.card)
        .accessibilityElement(children: .combine)
    }

    // MARK: Les bénéfices

    struct Benefit {
        let icon: MicaboIcon
        let title: String
        let body: String
    }

    /// La crainte principale d'abord, réglée ; puis les cours sur mesure, les examens (ou la
    /// mémoire, si les examens étaient déjà la crainte), et le rythme. Quatre cartes au plus.
    private var benefits: [Benefit] {
        let locale = i18n.locale
        var result: [Benefit] = []
        let worry = model.leadWorry
        if let worry {
            result.append(Benefit(
                icon: Self.icon(for: worry),
                title: i18n.t("ios.profileCard.worry.\(worry.rawValue).title"),
                body: i18n.t("ios.profileCard.worry.\(worry.rawValue).body")
            ))
        }

        let subjects = model.subjects.sorted().map { SubjectDisplay.subject($0, locale: locale) }
        let shown = subjects.prefix(2).joined(separator: ", ")
        let list = subjects.count > 2 ? i18n.t("ios.profileCard.more", ["list": shown, "n": "\(subjects.count - 2)"]) : shown
        result.append(Benefit(
            icon: .lessons,
            title: i18n.t("ios.profileCard.courses.title"),
            body: subjects.isEmpty ? i18n.t("ios.profileCard.courses.bodyAny") : i18n.t("ios.profileCard.courses.body", ["subjects": list])
        ))

        if worry == .examStress {
            result.append(Benefit(
                icon: .brain,
                title: i18n.t("ios.profileCard.worry.forgetting.title"),
                body: i18n.t("ios.profileCard.worry.forgetting.body")
            ))
        } else {
            result.append(Benefit(icon: .exam, title: i18n.t("ios.profileCard.exams.title"), body: i18n.t("ios.profileCard.exams.body")))
        }

        if let minutes = model.dailyMinutes {
            let body = model.studyHour.map { i18n.t("ios.profileCard.rhythm.body", ["hour": Self.hourText($0, locale: locale)]) }
                ?? i18n.t("ios.profileCard.rhythm.bodyAny")
            result.append(Benefit(icon: .alarm, title: i18n.t("ios.profileCard.rhythm.title", ["n": "\(minutes)"]), body: body))
        }
        return Array(result.prefix(4))
    }

    private static func icon(for worry: StudyWorry) -> MicaboIcon {
        switch worry {
        case .examStress: .trophy
        case .hardLessons: .lightbulb
        case .homework: .hourglass
        case .forgetting: .brain
        case .noStart: .flag
        case .motivation: .flame
        }
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

/// Une carte de bénéfice : l'icône dans sa pastille, le gain en gras, une ligne qui dit comment.
private struct BenefitCard: View {
    let benefit: ProfileSummaryStepView.Benefit

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            MicaboIconView(icon: benefit.icon, size: 30)
                .frame(width: 50, height: 50)
                .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(benefit.title)
                    .font(MicaboFont.ui(16.5, weight: .heavy))
                    .tracking(-0.2)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(benefit.body)
                    .font(MicaboFont.ui(14, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .accessibilityElement(children: .combine)
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
