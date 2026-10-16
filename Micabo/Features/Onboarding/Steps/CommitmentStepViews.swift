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

// MARK: - L'engagement

/// **« Prends un engagement envers le toi de dans un an. »**
///
/// Trois lignes, tirées des réponses — le temps, l'heure, ne pas lâcher —, et un bouton qu'on
/// **maintient** : trois secondes. Tant que le doigt reste posé, un trou noir s'ouvre depuis le
/// bouton et avale la page — un disque d'encre au cœur violet, cerclé d'un anneau de lumière
/// qui tourne de plus en plus vite —, les vibrations se resserrent, le texte passe au blanc.
/// Lâcher avant la fin, et tout se referme. Au bout, la page est entièrement noire : c'est
/// signé, et la suivante sort de ce noir.
struct CommitmentStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let holdDuration = 3.0

    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var didCommit = false
    @State private var spin = false
    @State private var holdTask: Task<Void, Never>?

    /// Le texte passe au blanc quand le noir l'a rejoint.
    private var isDark: Bool { progress > 0.42 }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height - 92)
            let reach = hypot(size.width, size.height) * 2.3

            ZStack {
                OnboardingPalette.white.ignoresSafeArea()

                hole(diameter: max(1, reach * progress))
                    .position(center)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    OnboardingCenteredScroll {
                        VStack(spacing: 26) {
                            OnboardingAccentText(
                                template: i18n.t("ios.commit.title"),
                                size: 30,
                                alignment: .center,
                                color: isDark ? .white : OnboardingPalette.ink
                            )
                            .onboardingAppear(index: 1)

                            VStack(spacing: 12) {
                                ForEach(Array(promises.enumerated()), id: \.offset) { index, line in
                                    promise(line, index: index)
                                }
                            }
                            .onboardingAppear(index: 2)
                        }
                        .padding(.horizontal, MicaboSpacing.screen)
                        .padding(.vertical, MicaboSpacing.md)
                    }

                    holdButton
                        .padding(.horizontal, MicaboSpacing.screen)
                        .padding(.bottom, 28)
                        .onboardingAppear(index: 3)
                }
                .onboardingChromeInset()
                .animation(.easeInOut(duration: 0.35), value: isDark)
            }
        }
        .environment(\.onboardingSurface, .canvas)
        .onDisappear { holdTask?.cancel() }
    }

    private var promises: [String] {
        var lines: [String] = []
        lines.append(i18n.t("ios.commit.line1", ["n": "\(model.dailyMinutes ?? 10)"]))
        if let hour = model.studyHour {
            lines.append(i18n.t("ios.commit.line2", ["hour": ProfileSummaryStepView.hourText(hour, locale: i18n.locale)]))
        }
        lines.append(i18n.t("ios.commit.line3"))
        return lines
    }

    private func promise(_ text: String, index: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(MicaboFont.number(16))
                .foregroundStyle(isDark ? OnboardingPalette.ink : MicaboColor.onInk)
                .frame(width: 32, height: 32)
                .background(isDark ? Color.white : MicaboColor.accent, in: Circle())
            Text(text)
                .font(MicaboFont.ui(16.5, weight: .bold))
                .foregroundStyle(isDark ? Color.white : MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            isDark ? Color.white.opacity(0.1) : MicaboColor.surface,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isDark ? Color.white.opacity(0.18) : MicaboColor.stroke, lineWidth: 1.5)
        )
    }

    // MARK: Le trou noir

    /// Le disque d'encre, son cœur violet, et l'anneau de lumière qui tourne sur son bord.
    private func hole(diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x05050A), Color(hex: 0x0B0B14), MicaboColor.keyword.opacity(0.85), MicaboColor.accent.opacity(0.35), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [MicaboColor.accent, MicaboColor.keyword, .white.opacity(0.9), MicaboColor.accent.opacity(0.2), MicaboColor.accent],
                        center: .center
                    ),
                    lineWidth: max(2, diameter * 0.035)
                )
                .padding(diameter * 0.14)
                .blur(radius: max(1, diameter * 0.02))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .opacity(progress < 0.98 ? 1 : 0)
        }
        .frame(width: diameter, height: diameter)
    }

    // MARK: Le bouton qu'on maintient

    private var holdButton: some View {
        ZStack {
            Capsule().fill(isDark ? Color.white : OnboardingPalette.ink)
            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(colors: OnboardingPalette.mikaGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
            }
            .clipShape(Capsule())
            HStack(spacing: 8) {
                Image(systemName: didCommit ? "checkmark" : "hand.point.up.left.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(didCommit ? i18n.t("ios.commit.done") : (isHolding ? i18n.t("ios.commit.holding") : i18n.t("ios.commit.hold")))
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(isDark && progress < 0.5 ? OnboardingPalette.ink : (isDark ? Color.white : MicaboColor.onInk))
        }
        .frame(height: 62)
        .scaleEffect(isHolding ? 0.96 : 1)
        .animation(OnboardingMotion.tap, value: isHolding)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in if !isHolding, !didCommit { begin() } }
                .onEnded { _ in release() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(i18n.t("ios.commit.hold"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
    }

    /// **Trois secondes, et les coups se resserrent** : un toutes les trois dixièmes au début,
    /// de plus en plus vite et de plus en plus fort vers la fin.
    private func begin() {
        isHolding = true
        Haptics.light()
        if !reduceMotion {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { spin = true }
        }
        withAnimation(.easeIn(duration: Self.holdDuration)) { progress = 1 }
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            var elapsed = 0.0
            while elapsed < Self.holdDuration {
                let gap = max(0.07, 0.32 - elapsed * 0.085)
                try? await Task.sleep(for: .seconds(gap))
                guard !Task.isCancelled else { return }
                elapsed += gap
                if elapsed > Self.holdDuration * 0.66 { Haptics.medium() } else { Haptics.tick() }
            }
            commit()
        }
    }

    private func release() {
        guard isHolding, !didCommit else { return }
        isHolding = false
        holdTask?.cancel()
        spin = false
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) { progress = 0 }
    }

    private func commit() {
        guard !didCommit else { return }
        didCommit = true
        isHolding = false
        holdTask?.cancel()
        withAnimation(.easeOut(duration: 0.4)) { progress = 1 }
        Haptics.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            model.advance()
        }
    }
}

// MARK: - L'essai offert

/// **« Nous tenons à ce que tu essaies ton parcours avec Mika gratuitement. »** La page sort du
/// noir de l'engagement : elle s'ouvre en encre, puis l'ivoire revient pendant que Mika arrive
/// et que la phrase se lit. Ensuite, comment marche l'essai.
struct FreeTrialIntroStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onboardingStill) private var still

    @State private var veil = 1.0
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

            Color(hex: 0x05050A)
                .ignoresSafeArea()
                .opacity(still ? 0 : veil)
                .allowsHitTesting(false)
        }
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).delay(0.25)) { veil = 0 }
            withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.6)) { mikaShown = true }
        }
    }
}
