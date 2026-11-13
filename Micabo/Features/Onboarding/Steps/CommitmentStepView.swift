import SwiftUI

/// **« On s'engage ensemble ? »** (lot 12) Le temps fort du parcours : un geste qu'on tient.
///
/// En haut, les deux promesses, écrites avec ses réponses : la sienne (« Moi, Lina, je révise
/// 15 min par jour, d'ici le 15 juin ») et celle de Mika (« je prépare chaque séance et je te
/// fais signe à 18 h »). Au centre, **un grand sceau, Mika dedans** : on pose le doigt et on
/// le tient. L'anneau se remplit sous le doigt et s'épaissit, un halo grandit, la vibration
/// monte d'un cran à chaque dixième, Mika se concentre. Tenu jusqu'au bout : c'est signé — Mika
/// explose de joie, des confettis, une vibration de réussite, et la carte des promesses se
/// signe. Lâché trop tôt : l'anneau redescend en douceur, et un mot encourage à recommencer.
///
/// **Accessible** : avec VoiceOver ou « Réduire les animations », un simple appui (ou l'action
/// VoiceOver) suffit à s'engager. L'horloge ne tourne que le temps que le doigt est posé : c'est
/// l'anneau qui suit le doigt, pas une mise en scène.
struct CommitmentStepView: View {
    /// Pour les rendus : l'engagement déjà pris.
    var previewCommitted = false
    /// Pour les rendus : le doigt posé depuis cette part de l'appui (de 0 à 1).
    var previewHold: Double?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.onbCompact) private var compact

    /// L'instant où le doigt s'est posé ; `nil` quand il n'y est pas.
    @State private var pressedAt: Date?
    /// L'anneau quand le doigt n'est pas posé : il redescend d'ici en douceur.
    @State private var resting: Double = 0
    /// Lâché trop tôt : Mika encourage à recommencer.
    @State private var encourages = false
    /// Vrai le temps que l'engagement vienne d'être pris sur cet écran : la fête.
    @State private var celebrates = false

    /// La durée de l'appui.
    static let holdSeconds = 1.6
    /// Le pas de l'anneau sous le doigt : trente images par seconde.
    private static let tick = 1.0 / 30.0

    private var isCommitted: Bool { model.hasCommitted || previewCommitted }

    private var title: String {
        if isCommitted {
            guard let name = model.displayName.nilIfBlank else { return i18n.t("ios.onb12.commit.doneNoName") }
            return i18n.t("ios.onb12.commit.done", ["name": name])
        }
        return i18n.t("ios.onb12.commit.title")
    }

    /// La promesse de l'élève, écrite avec ses réponses.
    static func studentPromise(for model: OnboardingModel, locale: UiLocale) -> String {
        let minutes = "\(model.minutesPerDay)"
        let name = model.displayName.nilIfBlank
        if let exam = model.datedExam {
            let date = OnbWords.day(exam.date, locale: locale)
            if let name {
                return L10n.t("ios.onb12.commit.me", locale: locale, vars: ["name": name, "min": minutes, "date": date])
            }
            return L10n.t("ios.onb12.commit.meNoName", locale: locale, vars: ["min": minutes, "date": date])
        }
        if let name {
            return L10n.t("ios.onb12.commit.meAny", locale: locale, vars: ["name": name, "min": minutes])
        }
        return L10n.t("ios.onb12.commit.meAnyNoName", locale: locale, vars: ["min": minutes])
    }

    /// L'avancée de l'appui, de 0 à 1, à un instant.
    static func hold(since start: Date, at now: Date) -> Double {
        min(1, max(0, now.timeIntervalSince(start) / holdSeconds))
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle)
                .padding(.top, OnbLayout.titleTop)
                .contentTransition(.opacity)

            contract
                .padding(.top, OnbLayout.answersGap)

            sealArea
                .padding(.top, compact ? 12 : 26)
                .frame(maxWidth: .infinity)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: isCommitted) {
                model.advance()
            }
        }
        .overlay {
            OnbConfetti(isOn: celebrates)
        }
    }

    // MARK: Les promesses

    private var contract: some View {
        VStack(alignment: .leading, spacing: 14) {
            promise(icon: .profile, tone: V3Color.iconBlue, text: Self.studentPromise(for: model, locale: i18n.locale))
            promise(icon: .mika, tone: V3Color.iconLilac, text: i18n.t("ios.onb12.commit.mika", [
                "hour": OnbWords.hour(model.reminderHour, locale: i18n.locale),
            ]))
            if isCommitted {
                // La signature : la carte se signe quand l'engagement est pris.
                Label(i18n.t("ios.onb12.commit.signedOn", ["date": OnbWords.day(Date(), locale: i18n.locale)]), systemImage: "checkmark.seal.fill")
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.green)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(selected: isCommitted, tone: isCommitted ? V3Color.green : nil)
    }

    private func promise(icon: MicaboIcon, tone: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MicaboIconView(icon: icon, size: 24 * 1.35, tint: tone)
                .frame(width: 30, height: 30)
            Text(text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Le sceau

    private var sealSize: CGFloat { compact ? 172 : 224 }

    private var sealArea: some View {
        VStack(spacing: 14) {
            Group {
                if let start = pressedAt, !isCommitted {
                    // Le doigt est posé : l'anneau suit le temps, trente fois par seconde.
                    TimelineView(.periodic(from: start, by: Self.tick)) { context in
                        let held = Self.hold(since: start, at: context.date)
                        seal(held, pressing: true)
                            .onChange(of: Int(held * 10)) { _, step in
                                Haptics.ramp(Double(step) / 10)
                            }
                            .onChange(of: held >= 1) { _, done in
                                if done { commit() }
                            }
                    }
                } else {
                    seal(isCommitted ? 1 : (previewHold ?? resting), pressing: previewHold != nil)
                }
            }
            .frame(width: sealSize * 1.25, height: sealSize * 1.25)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press() }
                    .onEnded { _ in release() }
            )
            .accessibilityElement()
            .accessibilityLabel(Text(i18n.t("ios.onb12.commit.hold")))
            .accessibilityValue(Text(isCommitted ? i18n.t("ios.onb12.commit.signed") : ""))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { commit() }

            Text(caption)
                .font(V3Font.label)
                .foregroundStyle(isCommitted ? V3Color.green : (encourages ? V3Color.yellowInk : V3Color.ink2))
                .multilineTextAlignment(.center)
                .contentTransition(.opacity)
                .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: caption)
        }
    }

    private var caption: String {
        if isCommitted { return i18n.t("ios.onb12.commit.signed") }
        if pressedAt != nil || previewHold != nil { return i18n.t("ios.onb12.commit.holding") }
        if encourages { return i18n.t("ios.onb12.commit.again") }
        return i18n.t(reduceMotion || voiceOver ? "ios.onb12.commit.tap" : "ios.onb12.commit.hold")
    }

    /// Le sceau à une avancée donnée : le halo, l'anneau qui s'épaissit, Mika au centre.
    private func seal(_ progress: Double, pressing: Bool) -> some View {
        let p = CGFloat(progress)
        let tone = isCommitted ? V3Color.green : V3Color.accent
        let mood: MikaMood = isCommitted ? .celebrate : (pressing ? .think : (encourages ? .wink : .idle))
        return ZStack {
            Circle()
                .fill(tone.opacity(0.10 + 0.22 * Double(p)))
                .frame(width: sealSize * (1 + 0.2 * p), height: sealSize * (1 + 0.2 * p))
            Circle()
                .fill(V3Color.surface)
                .frame(width: sealSize, height: sealSize)
            Circle()
                .stroke(V3Color.line, lineWidth: 12)
                .frame(width: sealSize - 12, height: sealSize - 12)
            Circle()
                .trim(from: 0, to: p)
                .stroke(tone, style: StrokeStyle(lineWidth: 12 + 10 * p, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: sealSize - 12, height: sealSize - 12)
            MikaMascot(mood: mood, size: sealSize * 0.56)
                .accessibilityHidden(true)
        }
    }

    // MARK: Le geste

    /// Le doigt se pose. Avec VoiceOver ou « Réduire les animations », un appui suffit.
    private func press() {
        guard !isCommitted, pressedAt == nil else { return }
        if reduceMotion || voiceOver {
            commit()
            return
        }
        encourages = false
        resting = 0
        Haptics.light()
        pressedAt = Date()
    }

    /// Le doigt se lève avant la fin : l'anneau redescend en douceur, Mika encourage.
    private func release() {
        guard let start = pressedAt, !isCommitted else { return }
        let held = Self.hold(since: start, at: Date())
        pressedAt = nil
        guard held < 1 else {
            commit()
            return
        }
        resting = held
        Haptics.soft()
        withAnimation(MicaboMotion.resolved(MicaboMotion.gentle, reduceMotion: reduceMotion)) {
            resting = 0
            encourages = held > 0.05
        }
    }

    private func commit() {
        guard !isCommitted else { return }
        pressedAt = nil
        Haptics.success()
        withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: reduceMotion)) {
            model.hasCommitted = true
            resting = 1
            encourages = false
        }
        celebrates = true
    }
}
