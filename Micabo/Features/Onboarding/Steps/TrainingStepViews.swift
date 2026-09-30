import SwiftUI

// MARK: - « Envie de t'entraîner sur quelques cartes ? »

/// **La proposition, avant les cartes.** Trois cartes en éventail, la question, « oui »
/// en toutes lettres, et « passer » en haut à droite pour qui ne veut pas : on ne fait pas
/// passer un test à quelqu'un qui ne l'a pas demandé.
struct TrainPromptStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb.train.title"),
            subtitle: i18n.t("ios.onb.train.sub"),
            scrolls: false,
            expandsContent: true,
            skip: OnboardingSkip(action: { model.jump(to: .socialProof) })
        ) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                TrainingFan()
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } footer: {
            OnboardingContinueButton(title: i18n.t("ios.onb.train.yes")) {
                model.advance()
            }
        }
    }
}

/// Trois cartes en éventail, une par format, qui se posent l'une après l'autre.
private struct TrainingFan: View {
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var isLanded = false

    private var labels: [(String, String)] {
        [
            ("rectangle.on.rectangle.angled", CardKind.basic.label(locale: i18n.locale)),
            ("list.bullet", CardKind.choice.label(locale: i18n.locale)),
            ("ellipsis.rectangle", CardKind.cloze.label(locale: i18n.locale)),
        ]
    }

    var body: some View {
        ZStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, item in
                let angle = Double(index - 1) * 9
                VStack(spacing: 14) {
                    Image(systemName: item.0)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.accent)
                    Text(item.1)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(OnboardingPalette.ink)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 168, height: 208)
                .background(OnboardingPalette.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(OnboardingPalette.cardStrong, lineWidth: 1)
                }
                .shadow(color: OnboardingPalette.ink.opacity(0.1), radius: 18, y: 10)
                .rotationEffect(.degrees(isLanded ? angle : 0), anchor: .bottom)
                .offset(x: isLanded ? CGFloat(index - 1) * 58 : 0, y: isLanded ? abs(CGFloat(index - 1)) * 10 : 24)
                .opacity(isLanded ? 1 : 0)
                .zIndex(index == 1 ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 260)
        .onAppear {
            withAnimation(.easeOut(duration: 0.55).delay(OnboardingMotion.slideDuration)) { isLanded = true }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Les trois cartes

/// **Une carte à retourner, un QCM, un texte à trou.** Du cours de l'élève quand il a
/// déposé le sien, du jeu embarqué sinon — avec, dans ce cas, le schéma sur la première.
///
/// **Rien n'est noté, rien n'est enregistré.** Une carte lue passe à la suivante, quelle
/// que soit la réponse ; la répétition espacée ne commence qu'après le parcours, sur les
/// vraies sessions. C'est une démonstration du geste — lire, retourner, répondre —, pas un
/// examen.
struct TrainCardsStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var cards: [TrainingCard] = []
    @State private var index = 0
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)

            ZStack {
                if cards.indices.contains(index) {
                    TrainingCardView(card: cards[index]) {
                        next()
                    }
                    .id(index)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(OnboardingMotion.slide, value: index)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.md)
            .padding(.bottom, MicaboSpacing.sm)
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear(perform: load)
    }

    /// Le compteur, les points, et « passer ».
    private var header: some View {
        HStack(spacing: 12) {
            Text("\(min(index + 1, max(1, cards.count))) / \(max(1, cards.count))")
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(OnboardingPalette.gray)
                .monospacedDigit()
                .frame(width: 44, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(0..<max(1, cards.count), id: \.self) { rank in
                    Capsule()
                        .fill(rank <= index ? OnboardingPalette.ink : OnboardingPalette.cardStrong)
                        .frame(height: 4)
                        .animation(OnboardingMotion.select, value: index)
                }
            }

            Button {
                model.jump(to: .socialProof)
            } label: {
                Text(i18n.t("common.skip"))
                    .font(MicaboFont.ui(13.5, weight: .semibold))
                    .foregroundStyle(OnboardingPalette.gray)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(OnboardingPalette.card, in: Capsule())
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        }
        .frame(height: 40)
    }

    private func load() {
        guard cards.isEmpty else { return }
        if model.isDemoCourse, let demo = model.demoCourse {
            cards = demo.trainingCards.map { TrainingCard($0) }
        } else if let course = model.builtCourse {
            cards = TrainingCard.pick(from: course.orderedCards)
        }
        // Sans carte à montrer, il n'y a rien à faire ici : on passe au bravo, qui reste
        // vrai — le cours, lui, existe.
        if cards.isEmpty {
            DispatchQueue.main.async { model.advance() }
        }
    }

    private func next() {
        guard !didFinish else { return }
        if index + 1 < cards.count {
            index += 1
            Haptics.tick()
        } else {
            didFinish = true
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                model.advance()
            }
        }
    }
}

/// Une carte d'entraînement, quelle que soit sa source.
struct TrainingCard: Identifiable {
    enum Kind {
        case basic
        case choice
        case cloze
    }

    let id = UUID()
    let kind: Kind
    let front: String
    let back: String
    var choices: [String] = []
    var answerIndex: Int = 0
    var figure: DemoFigure? = nil

    init(_ demo: DemoCard) {
        switch demo.kind {
        case .basic: kind = .basic
        case .choice: kind = .choice
        case .cloze: kind = .cloze
        }
        front = demo.front
        back = demo.back
        choices = demo.choices
        answerIndex = demo.answerIndex
        figure = demo.figure
    }

    init(_ card: Flashcard) {
        switch card.format {
        case .choice: kind = .choice
        case .cloze: kind = .cloze
        case .basic, .occlusion: kind = .basic
        }
        front = card.front
        back = card.back
        choices = card.choices
        answerIndex = card.correctChoiceIndex
    }

    /// **Une de chaque**, dans l'ordre : recto verso, QCM, texte à trou. Un format que le
    /// deck n'a pas est remplacé par une autre recto verso, pour qu'il y ait toujours trois
    /// cartes — et jamais deux fois la même.
    static func pick(from cards: [Flashcard]) -> [TrainingCard] {
        var used: Set<UUID> = []
        var out: [TrainingCard] = []

        for wanted in [CardKind.basic, .choice, .cloze] {
            let found = cards.first { $0.format == wanted && !used.contains($0.id) }
                ?? cards.first { $0.format == .basic && !used.contains($0.id) }
                ?? cards.first { !used.contains($0.id) }
            guard let found else { continue }
            used.insert(found.id)
            out.append(TrainingCard(found))
        }
        return out
    }
}

// MARK: - La carte

/// **La face d'une carte d'entraînement, et ce qu'on fait avec.** Une recto verso se
/// retourne au toucher ; un QCM se répond en touchant une proposition ; un texte à trou
/// se révèle au toucher. Dans les trois cas, un bouton « suivant » arrive une fois la
/// réponse vue.
private struct TrainingCardView: View {
    let card: TrainingCard
    var onNext: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isRevealed = false
    @State private var picked: Int?

    private var kindLabel: String {
        switch card.kind {
        case .basic: CardKind.basic.label(locale: i18n.locale)
        case .choice: CardKind.choice.label(locale: i18n.locale)
        case .cloze: CardKind.cloze.label(locale: i18n.locale)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            face
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
    }

    // MARK: La face

    @ViewBuilder
    private var face: some View {
        switch card.kind {
        case .basic: flippingFace
        case .choice: choiceFace
        case .cloze: clozeFace
        }
    }

    /// La recto verso : la question, la figure, puis, au toucher, la réponse. Le
    /// retournement est une rotation sur l'axe vertical ; avec le mouvement réduit, un fondu.
    private var flippingFace: some View {
        ZStack {
            surface {
                VStack(spacing: 18) {
                    Spacer(minLength: 0)
                    eyebrow(kindLabel)
                    FormulaText(source: card.front, size: 22, weight: .semibold, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let figure = card.figure {
                        DemoFigureView(figure: figure, tint: OnboardingPalette.accent)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
            }
            .opacity(isRevealed ? 0 : 1)
            .rotation3DEffect(.degrees(isRevealed && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            surface {
                VStack(alignment: .leading, spacing: 14) {
                    eyebrow(i18n.t("app.session.answerEyebrow"), color: OnboardingPalette.accent)
                    FormulaText(source: card.front, size: 16, weight: .semibold)
                        .fixedSize(horizontal: false, vertical: true)
                    MicaboHairline()
                    ScrollView {
                        FormulaText(source: card.back, size: 16, color: MicaboColor.inkBody, family: .reading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .opacity(isRevealed ? 1 : 0)
            .rotation3DEffect(.degrees(isRevealed || reduceMotion ? 0 : -180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.easeInOut(duration: 0.45), value: isRevealed)
        .contentShape(RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
        .onTapGesture { reveal() }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(i18n.t("ios.onb.train.reveal"))
    }

    /// Le QCM : la question, les propositions ; toucher l'une colore la bonne et la fausse.
    private var choiceFace: some View {
        surface {
            VStack(alignment: .leading, spacing: 16) {
                eyebrow(kindLabel)
                FormulaText(source: card.front, size: 19, weight: .semibold, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 8) {
                    ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            pick(index)
                        } label: {
                            choiceRow(index: index, choice: choice)
                        }
                        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .none))
                        .disabled(isRevealed)
                    }
                }

                if isRevealed {
                    FormulaText(source: card.back, size: 14.5, color: MicaboColor.inkBody, family: .reading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .animation(OnboardingMotion.shift, value: isRevealed)
        }
    }

    private func choiceRow(index: Int, choice: String) -> some View {
        let state = choiceState(index)
        return HStack(alignment: .top, spacing: 10) {
            Text(String(Array("ABCDEFGH")[min(index, 7)]))
                .font(MicaboFont.ui(12, weight: .bold))
                .foregroundStyle(state.markInk)
                .frame(width: 22, height: 22)
                .background(state.mark, in: Circle())

            FormulaText(source: choice, size: 15, weight: .medium, color: state.text, family: .reading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let symbol = state.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.mark)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(state.background, in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous)
                .strokeBorder(state.border, lineWidth: 1)
        }
        .animation(OnboardingMotion.select, value: isRevealed)
    }

    private enum ChoiceState {
        case pending, correct, wrong, dismissed

        var background: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.canvas
            case .correct: MicaboColor.positiveSoft
            case .wrong: MicaboColor.negativeSoft
            }
        }
        var border: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.stroke
            case .correct: MicaboColor.positive
            case .wrong: MicaboColor.negative
            }
        }
        var mark: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.surfaceMuted
            case .correct: MicaboColor.positive
            case .wrong: MicaboColor.negative
            }
        }
        var markInk: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.inkSecondary
            case .correct, .wrong: MicaboColor.onInk
            }
        }
        var text: Color { self == .dismissed ? MicaboColor.inkTertiary : MicaboColor.ink }
        var symbol: String? {
            switch self {
            case .correct: "checkmark.circle.fill"
            case .wrong: "xmark.circle.fill"
            case .pending, .dismissed: nil
            }
        }
    }

    private func choiceState(_ index: Int) -> ChoiceState {
        guard isRevealed else { return .pending }
        if index == card.answerIndex { return .correct }
        return picked == index ? .wrong : .dismissed
    }

    /// Le texte à trou : la phrase avec son blanc en pastille ; au toucher, le mot prend sa
    /// place, en violet.
    private var clozeFace: some View {
        surface {
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                eyebrow(kindLabel)
                clozeText
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
        .onTapGesture { reveal() }
        .animation(OnboardingMotion.shift, value: isRevealed)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(i18n.t("ios.onb.train.reveal"))
    }

    private var clozeText: some View {
        let parts = card.front.components(separatedBy: ClozeGap.marker)
        var text = Text("")
        for (index, part) in parts.enumerated() {
            if index > 0 {
                let filler = isRevealed ? " \(card.back) " : " ……… "
                text = text + Text(filler)
                    .font(MicaboFont.ui(22, weight: .bold))
                    .foregroundStyle(OnboardingPalette.accent)
            }
            text = text + Text(part)
                .font(MicaboFont.ui(22, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
        }
        return text
            .multilineTextAlignment(.center)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Le pied

    /// Avant la réponse, une ligne grise qui dit quoi faire ; après, le bouton. Sur la
    /// recto verso, deux boutons — « je savais », « pas encore » — qui font la même chose :
    /// c'est le geste qu'on montre, pas une note qu'on prend.
    @ViewBuilder
    private var footer: some View {
        if !isRevealed {
            Text(card.kind == .choice ? "" : i18n.t("ios.onb.train.reveal"))
                .font(MicaboFont.ui(13.5, weight: .medium))
                .foregroundStyle(OnboardingPalette.grayLight)
                .frame(height: 56)
        } else if card.kind == .basic {
            HStack(spacing: 10) {
                pill(i18n.t("ios.onb.train.missed"), fill: OnboardingPalette.card, ink: OnboardingPalette.ink)
                pill(i18n.t("ios.onb.train.knew"), fill: OnboardingPalette.ink, ink: OnboardingPalette.white)
            }
            .transition(.opacity)
        } else {
            OnboardingContinueButton(title: i18n.t("ios.onb.train.next"), action: onNext)
                .transition(.opacity)
        }
    }

    private func pill(_ title: String, fill: Color, ink: Color) -> some View {
        Button(action: onNext) {
            Text(title)
                .font(OnboardingPalette.button)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: true, feedback: .medium))
    }

    // MARK: Les briques

    private func surface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(26)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous)
                    .strokeBorder(OnboardingPalette.cardStrong, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 8)
    }

    private func eyebrow(_ text: String, color: Color = OnboardingPalette.grayLight) -> some View {
        Text(text.uppercased())
            .font(MicaboFont.ui(11, weight: .semibold))
            .tracking(1.4)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: card.kind == .basic || card.kind == .cloze ? .center : .leading)
    }

    private func reveal() {
        guard !isRevealed else { return }
        Haptics.light()
        withAnimation(OnboardingMotion.shift) { isRevealed = true }
    }

    private func pick(_ index: Int) {
        guard !isRevealed else { return }
        picked = index
        if index == card.answerIndex {
            Haptics.success()
        } else {
            Haptics.warning()
        }
        withAnimation(OnboardingMotion.shift) { isRevealed = true }
    }
}

// MARK: - « Bien joué »

/// **Une coche, le prénom, une phrase.** Le seul écran du parcours qui félicite, et il
/// félicite quelque chose de vrai : l'élève vient de se tester, ce que la plupart ne font
/// jamais.
struct WellDoneStepView: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var hasLanded = false

    private var name: String {
        model.displayName.nilIfBlank ?? OnboardingPreferences.displayName ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(OnboardingPalette.white)
                    .frame(width: 96, height: 96)
                    .background(OnboardingPalette.ink, in: Circle())
                    .scaleEffect(hasLanded ? 1 : 0.6)
                    .opacity(hasLanded ? 1 : 0)
                    .accessibilityHidden(true)

                Text(i18n.t("ios.onb.wellDone.title", ["name": name]))
                    .font(OnboardingPalette.title(34))
                    .tracking(-0.9)
                    .foregroundStyle(OnboardingPalette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 28)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .onboardingAppear(index: 3)

                Text(i18n.t("ios.onb.wellDone.sub"))
                    .font(MicaboFont.ui(16, weight: .regular))
                    .foregroundStyle(OnboardingPalette.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                    .padding(.horizontal, MicaboSpacing.xl)
                    .onboardingAppear(index: 5)

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OnboardingArrowBar {
                model.advance()
            }
            .onboardingAppear(index: 7)
        }
        .background(OnboardingPalette.white.ignoresSafeArea())
        .environment(\.onboardingSurface, .canvas)
        .onAppear {
            withAnimation(.timingCurve(0.2, 0.9, 0.3, 1.1, duration: 0.5).delay(0.15)) { hasLanded = true }
            // La coche se pose d'un coup sec ; le bravo, la double vibration du système,
            // vient une fois qu'elle est là.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { Haptics.rigid() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { Haptics.success() }
        }
    }
}
