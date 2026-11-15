import SwiftUI

/// **« Lina, tu t'engages ? »** (lot 12, réécrit au lot 15) Le temps fort du parcours : un geste
/// qu'on tient.
///
/// Au centre, sa promesse, écrite avec ses réponses (« Moi, Lina, je révise 45 min par jour,
/// d'ici le 15 juin. »), et Mika. **Le bouton du pied est le bouton à maintenir**, au même
/// endroit que sur tous les écrans : on pose le doigt, il se remplit de gauche à droite en
/// 1,5 s, la vibration monte d'un cran toutes les 0,15 s, le texte guide (« Maintiens pour
/// t'engager » → « Encore un peu… »). Lâché trop tôt : il se vide en douceur, « Presque ! Tiens
/// jusqu'au bout ». Tenu jusqu'au bout : vibration de réussite, confettis, Mika fête, « C'est
/// signé ! », et l'écran suivant arrive tout seul.
///
/// **Pourquoi le maintien ne marchait pas (build 182)** : le sceau était un
/// `Group { if doigt posé { TimelineView { … } } else { … } }` qui portait le geste. Un `Group`
/// applique ses modificateurs à chacun de ses enfants : au toucher, la branche changeait, la vue
/// qui portait le geste disparaissait, le geste était annulé, `@GestureState` repassait à faux
/// et le relâchement était lu à 0 %. Le maintien ne pouvait jamais aller au bout (et le sceau
/// était en plus dans le défilement de la page).
///
/// **Ce qui le rend sûr** : une seule vue, d'identité stable, hors du défilement ;
/// `onLongPressGesture(minimumDuration:maximumDistance:perform:onPressingChanged:)`, où le
/// système chronomètre lui-même le maintien : `perform` n'est appelé qu'après 1,5 s de doigt
/// posé, jamais sur un appui bref. Le remplissage est une animation linéaire de la même durée,
/// qui redescend au lâcher. Le test d'interface `CommitmentHoldUITests` le vérifie sur un vrai
/// geste (un appui de 0,3 s ne signe rien ; un maintien de 2 s mène à l'écran suivant).
///
/// **Accessible** : avec VoiceOver, l'action du bouton engage directement.
struct CommitmentStepView: View {
    /// Pour les rendus : l'engagement déjà pris (le bouton signé, vert).
    var previewCommitted = false
    /// Pour les rendus : le doigt posé depuis cette part du maintien (de 0 à 1).
    var previewHold: Double?
    /// Pour les rendus : lâché trop tôt.
    var previewEarly = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onbCompact) private var compact

    /// La part remplie du bouton, de 0 à 1.
    @State private var fill: Double = 0
    /// Le maintien en cours (l'instant où le doigt s'est posé).
    @State private var hold = CommitHold()
    /// Lâché trop tôt : le texte encourage à recommencer.
    @State private var encourages = false
    /// Vrai une fois l'engagement pris sur cet écran : la fête, puis l'écran suivant.
    @State private var signedHere = false

    /// La durée du maintien.
    static let holdSeconds = CommitHold.duration
    /// Un cran de vibration tous les combien, doigt posé.
    static let rampStep = 0.15

    private var isCommitted: Bool { model.hasCommitted || previewCommitted }
    private var isPressing: Bool { hold.pressedAt != nil || previewHold != nil }

    private var title: String {
        let name = model.displayName.nilIfBlank
        if isCommitted {
            guard let name else { return i18n.t("ios.onb12.commit.doneNoName") }
            return i18n.t("ios.onb12.commit.done", ["name": name])
        }
        guard let name else { return i18n.t("ios.onb15.commit.titleNoName") }
        return i18n.t("ios.onb15.commit.title", ["name": name])
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

    /// L'avancée du maintien, de 0 à 1, à un instant.
    static func hold(since start: Date, at now: Date) -> Double {
        CommitHold.progress(since: start, at: now)
    }

    var body: some View {
        OnbScreen {
            OnbTitle(title, size: OnbLayout.questionTitle, keyword: isCommitted ? V3Color.green : V3Color.accentBright)
                .padding(.top, OnbLayout.titleTop)
                .contentTransition(.opacity)

            OnbCentered {
                VStack(spacing: compact ? 14 : 24) {
                    Text(Self.studentPromise(for: model, locale: i18n.locale))
                        .font(.system(.title2, design: .default, weight: .medium))
                        .lineSpacing(OnbType.bodySpacing)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 330)
                    MikaMascot(mood: mood, size: compact ? 130 : 180)
                        .frame(width: compact ? 130 : 180, height: compact ? 130 : 180)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity)
            }
        } footer: {
            if isCommitted && !signedHere && !previewCommitted {
                // Revenu sur un engagement déjà pris : un simple « Continuer ».
                V3Button(i18n.t("common.continue")) {
                    model.advance()
                }
            } else {
                holdButton
            }
        }
        .overlay {
            OnbConfetti(isOn: signedHere)
        }
    }

    private var mood: MikaMood {
        if isCommitted { return .celebrate }
        if isPressing { return .think }
        return encourages || previewEarly ? .wink : .idle
    }

    // MARK: Le bouton à maintenir

    /// La part remplie à montrer.
    private var shownFill: Double {
        if isCommitted { return 1 }
        if let previewHold { return previewHold }
        if previewEarly { return 0.18 }
        return fill
    }

    private var label: String {
        if isCommitted { return i18n.t("ios.onb15.commit.signed") }
        if isPressing { return i18n.t("ios.onb15.commit.holding") }
        if encourages || previewEarly { return i18n.t("ios.onb15.commit.again") }
        return i18n.t("ios.onb12.commit.hold")
    }

    private var holdButton: some View {
        let tone = isCommitted ? V3Color.green : V3Color.accent
        return GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                // Le fond, et le libellé dans la couleur du bouton principal.
                Capsule()
                    .fill(V3Color.ink)
                holdLabel(color: V3Color.bg)
                    .frame(width: width)
                // Le remplissage, et le même libellé en blanc, découpé à sa largeur : le texte
                // reste lisible des deux côtés du bord.
                ZStack(alignment: .leading) {
                    tone
                    holdLabel(color: .white)
                        .frame(width: width)
                }
                .frame(width: width * shownFill, alignment: .leading)
                .clipped()
            }
            .clipShape(Capsule())
        }
        .frame(height: 64)
        .background { hapticRamp }
        .contentShape(Capsule())
        .onLongPressGesture(
            minimumDuration: Self.holdSeconds,
            maximumDistance: 60,
            perform: commit,
            onPressingChanged: pressingChanged
        )
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { commit() }
        .accessibilityIdentifier("onboarding.commitment.hold")
    }

    /// **La vibration qui monte**, un cran toutes les 0,15 s, le temps que le doigt est posé.
    /// L'horloge n'existe que pendant le maintien, et elle ne porte pas le geste : elle peut
    /// apparaître et disparaître sans rien annuler.
    @ViewBuilder
    private var hapticRamp: some View {
        if let start = hold.pressedAt, !isCommitted {
            TimelineView(.periodic(from: start, by: Self.rampStep)) { context in
                let level = min(10, Int(context.date.timeIntervalSince(start) / Self.rampStep))
                Color.clear
                    .onChange(of: level) { _, step in
                        Haptics.ramp(Double(step) / 10)
                    }
            }
            .accessibilityHidden(true)
        }
    }

    private func holdLabel(color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isCommitted ? "checkmark.seal.fill" : "hand.point.up.left.fill")
                .font(.system(size: 22, weight: .bold))
            Text(label)
                .font(V3Font.button)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 20)
        .frame(maxHeight: .infinity)
        .environment(\.layoutDirection, i18n.locale.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    // MARK: Le geste

    /// Le doigt se pose, ou se lève.
    private func pressingChanged(_ pressing: Bool) {
        guard !isCommitted else { return }
        if pressing { press() } else { release() }
    }

    /// Le doigt se pose : le bouton se remplit, au rythme du maintien, et la vibration monte.
    private func press() {
        let now = Date()
        hold.press(at: now)
        encourages = false
        Haptics.light()
        let remaining = Self.holdSeconds * (1 - fill)
        withAnimation(.linear(duration: max(0.05, remaining))) {
            fill = 1
        }
    }

    /// Le doigt se lève avant la fin : rien n'est signé ; le bouton se vide en douceur.
    private func release() {
        let now = Date()
        // Le maintien complet (1,5 s ou plus) : c'est `commit`, appelé par le geste réussi, qui
        // conclut — le système peut lever le doigt « logique » juste avant de l'appeler. Lâché
        // ne serait-ce qu'un instant avant, le bouton se vide.
        guard hold.progress(at: now) < 1 else { return }
        let held = hold.progress(at: now)
        hold.cancel()
        Haptics.soft()
        withAnimation(MicaboMotion.resolved(.easeOut(duration: 0.35), reduceMotion: reduceMotion)) {
            fill = 0
            encourages = held > 0.05
        }
    }

    /// **Engagé** : seulement après le maintien complet (ou l'action de VoiceOver).
    private func commit() {
        guard !isCommitted else { return }
        hold.cancel()
        Haptics.success()
        signedHere = true
        // La fête se joue (Mika, les confettis, le bouton qui passe au vert), puis l'écran
        // suivant arrive à la fin de son ressort : « à 100 %, célébration et passage à la
        // suite » (lot 15). Pas de minuterie : c'est la fin de l'animation qui avance.
        withAnimation(Self.celebration(reduceMotion: reduceMotion), completionCriteria: .logicallyComplete) {
            model.hasCommitted = true
            fill = 1
            encourages = false
        } completion: {
            guard model.step == .commitment else { return }
            model.advance()
        }
    }

    /// Le ressort de la fête : celui des réussites, assez long pour qu'elle se voie.
    static func celebration(reduceMotion: Bool) -> Animation {
        reduceMotion ? MicaboMotion.reduced : .spring(duration: 0.9, bounce: 0.3)
    }
}

// MARK: - Le maintien

/// **La logique du maintien**, sans écran (lot 14) : seul un doigt tenu `duration` secondes
/// engage. Un appui bref, un geste annulé, ou une horloge qui tourne sans doigt ne valident
/// jamais.
struct CommitHold: Equatable {
    /// La durée à tenir.
    static let duration: TimeInterval = 1.5

    /// L'instant où le doigt s'est posé ; `nil` quand il n'y est pas.
    private(set) var pressedAt: Date?

    /// L'avancée d'un maintien commencé à `start`, de 0 à 1.
    static func progress(since start: Date, at now: Date) -> Double {
        min(1, max(0, now.timeIntervalSince(start) / duration))
    }

    /// L'avancée du maintien en cours, 0 sans doigt.
    func progress(at now: Date) -> Double {
        pressedAt.map { Self.progress(since: $0, at: now) } ?? 0
    }

    /// Le doigt se pose. Un second appui pendant le maintien ne le relance pas.
    mutating func press(at now: Date) {
        guard pressedAt == nil else { return }
        pressedAt = now
    }

    /// **L'horloge avance, le doigt toujours posé** : vrai quand le maintien est complet. Sans
    /// doigt, jamais.
    mutating func tick(at now: Date) -> Bool {
        guard progress(at: now) >= 1 else { return false }
        pressedAt = nil
        return true
    }

    /// **Le doigt se lève** : vrai seulement si le maintien était complet.
    mutating func release(at now: Date) -> Bool {
        let complete = progress(at: now) >= 1
        pressedAt = nil
        return complete
    }

    /// Le geste est annulé (le défilement l'a repris) : rien n'est signé.
    mutating func cancel() {
        pressedAt = nil
    }
}
