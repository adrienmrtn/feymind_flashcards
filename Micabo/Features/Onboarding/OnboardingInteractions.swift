import SwiftUI

// MARK: - Le titre qui se lit

/// **Un titre qui se lit sous les yeux.** Les mots sont posés d'un bloc en gris clair, puis
/// passent à l'encre l'un après l'autre, au rythme d'une lecture, avec un coup léger par
/// mot : le regard suit, et la phrase se lit en entier au lieu d'être survolée.
///
/// Les mots entre astérisques doubles (`**réaliste**`) sont ceux qu'on veut retenir : une
/// fois la phrase lue, un surligneur violet passe dessous, de gauche à droite. Le parent
/// peut aussi tenir le surlignage pour lui (`highlightsOnFinish: false`) et le déclencher
/// quand il veut, sur un appui par exemple.
struct OnboardingReadingText: View {
    let template: String
    var size: CGFloat = 34
    var alignment: HorizontalAlignment = .center
    /// Le temps entre deux mots. Dix-huit centièmes : une lecture posée, pas une dictée.
    var wordDelay: Double = 0.18
    var startDelay: Double = 0.45
    var hapticsPerWord: Bool = true
    /// Surligne les mots marqués dès la lecture finie. Sinon, c'est `isHighlighted`.
    var highlightsOnFinish: Bool = true
    var isHighlighted: Bool = false
    /// Appelé une fois le dernier mot lu.
    var onFinish: () -> Void = {}
    /// Appelé une fois le surligneur passé.
    var onHighlighted: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var read = 0
    @State private var highlighted = false
    @State private var didStart = false

    private struct Word: Identifiable {
        let id: Int
        let text: String
        let isMarked: Bool
        /// Le rang parmi les mots marqués : le surligneur les prend dans l'ordre.
        let markedRank: Int
    }

    private var words: [Word] {
        var result: [Word] = []
        var marked = 0
        for (index, segment) in template.components(separatedBy: "**").enumerated() {
            let isMarked = index % 2 == 1
            var pieces = segment.split(whereSeparator: \.isWhitespace).map(String.init)
            // Une ponctuation collée au mot marqué (« **confiance**. ») reste collée à lui
            // au lieu de devenir un mot à part, posé après un espace.
            if index > 0, let first = segment.first, !first.isWhitespace, !pieces.isEmpty, let last = result.last {
                result[result.count - 1] = Word(id: last.id, text: last.text + pieces.removeFirst(), isMarked: last.isMarked, markedRank: last.markedRank)
            }
            for piece in pieces {
                let rank = isMarked ? marked : -1
                if isMarked { marked += 1 }
                result.append(Word(id: result.count, text: piece, isMarked: isMarked, markedRank: rank))
            }
        }
        return result
    }

    var body: some View {
        MicaboFlowLayout(spacing: size * 0.26, lineSpacing: size * 0.1, alignment: alignment) {
            ForEach(words) { word in
                self.word(word)
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(template.replacingOccurrences(of: "**", with: ""))
        .task { await run() }
        .onChange(of: isHighlighted) { _, value in
            guard value, !highlighted else { return }
            highlight()
        }
    }

    /// Deux textes superposés, le gris dessous et l'encre dessus : c'est l'opacité de
    /// l'encre qui s'anime, et elle s'anime toujours — la couleur d'un texte, pas
    /// forcément.
    private func word(_ word: Word) -> some View {
        let isRead = word.id < read
        let isLit = highlighted && word.isMarked

        return ZStack {
            Text(word.text)
                .foregroundStyle(OnboardingPalette.grayLight)

            Text(word.text)
                .foregroundStyle(isLit ? OnboardingPalette.accent : OnboardingPalette.ink)
                .opacity(isRead ? 1 : 0)
                .animation(.easeOut(duration: 0.3), value: isRead)
                .animation(.easeOut(duration: 0.3), value: isLit)
        }
        .font(OnboardingPalette.title(size))
        .tracking(-0.9)
        .background {
            if word.isMarked {
                RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                    .fill(OnboardingPalette.accent.opacity(0.16))
                    .padding(.horizontal, -size * 0.12)
                    .padding(.vertical, -size * 0.02)
                    .scaleEffect(x: highlighted ? 1 : 0.001, y: 1, anchor: .leading)
                    .animation(
                        .easeOut(duration: 0.45).delay(Double(word.markedRank) * 0.12),
                        value: highlighted
                    )
            }
        }
    }

    @MainActor
    private func run() async {
        guard !didStart else { return }
        didStart = true

        if reduceMotion {
            read = words.count
            onFinish()
            if highlightsOnFinish || isHighlighted { highlighted = true; onHighlighted() }
            return
        }

        let count = words.count
        try? await Task.sleep(for: .seconds(startDelay))
        for index in 1...Swift.max(1, count) {
            guard !Task.isCancelled else { return }
            read = index
            if hapticsPerWord { Haptics.soft() }
            try? await Task.sleep(for: .seconds(wordDelay))
        }
        guard !Task.isCancelled else { return }
        onFinish()
        if highlightsOnFinish || isHighlighted {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            highlight()
        }
    }

    private func highlight() {
        guard !highlighted else { return }
        highlighted = true
        Haptics.light()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            onHighlighted()
        }
    }
}

// MARK: - Le bouton qu'on tient

/// **Un bouton qui se tient appuyé.** Pendant qu'on le tient, un violet le remplit de
/// gauche à droite ; lâché avant la fin, il se vide ; tenu jusqu'au bout, il valide, avec
/// un coup net. Une seconde et demie : assez pour que ce soit un engagement, pas une
/// épreuve.
///
/// Il remplace le bouton noir sur la seule question où l'on veut que la réponse coûte un
/// geste : le temps par jour. « Tu es sûr ? » est une question qu'on pose en le tenant.
struct OnboardingHoldButton: View {
    var title: String
    var isEnabled: Bool = true
    var duration: Double = 1.4
    var onComplete: () -> Void

    @Environment(\.onboardingSurface) private var surface

    @State private var progress: CGFloat = 0
    @State private var isPressing = false
    @State private var didComplete = false
    @State private var timer: Task<Void, Never>?

    var body: some View {
        ZStack {
            Capsule()
                .fill(isEnabled ? surface.buttonTint : surface.disabledButtonTint)

            GeometryReader { proxy in
                Capsule()
                    .fill(OnboardingPalette.accent)
                    .frame(width: Swift.max(0, proxy.size.width * progress))
            }
            .clipShape(Capsule())

            Text(title)
                .font(OnboardingPalette.button)
                .foregroundStyle(surface.buttonForeground)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .contentShape(Capsule())
        .scaleEffect(isPressing ? 0.97 : 1)
        .animation(OnboardingMotion.tap, value: isPressing)
        .animation(OnboardingMotion.select, value: isEnabled)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    guard isEnabled, !isPressing, !didComplete else { return }
                    begin()
                }
                .onEnded { _ in release() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if isEnabled { complete() } }
        .onDisappear { timer?.cancel() }
    }

    private func begin() {
        isPressing = true
        Haptics.light()
        withAnimation(.linear(duration: duration)) { progress = 1 }
        timer?.cancel()
        timer = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            complete()
        }
    }

    private func release() {
        guard isPressing, !didComplete else { return }
        isPressing = false
        timer?.cancel()
        withAnimation(.easeOut(duration: 0.3)) { progress = 0 }
    }

    private func complete() {
        guard !didComplete else { return }
        didComplete = true
        isPressing = false
        progress = 1
        Haptics.success()
        onComplete()
    }
}

// MARK: - Le compteur d'aéroport

/// **Des chiffres qui roulent, colonne par colonne**, comme un tableau d'affichage de gare.
/// Chaque colonne est une bande de dix chiffres qui se décale vers le haut ; quand la
/// valeur change vite, la bande file, et quand elle ralentit, chaque chiffre se pose.
///
/// La vitesse vient d'ailleurs : la vue montre la valeur qu'on lui donne, et c'est le
/// parent qui la fait monter en freinant.
struct OnboardingDigitRoller: View {
    let value: Int
    /// Le nombre de colonnes, fixé par la valeur d'arrivée pour que rien ne bouge en largeur.
    let digits: Int
    var size: CGFloat = 76
    var tint: Color = OnboardingPalette.ink

    private var columns: [Int] {
        let text = String(Swift.max(0, value))
        let padded = String(repeating: "0", count: Swift.max(0, digits - text.count)) + text
        return padded.compactMap { Int(String($0)) }
    }

    private var leadingZeros: Int {
        var count = 0
        for digit in columns {
            if digit == 0 { count += 1 } else { break }
        }
        return Swift.min(count, columns.count - 1)
    }

    var body: some View {
        let cell = size * 1.12
        HStack(spacing: size * 0.02) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, digit in
                VStack(spacing: 0) {
                    ForEach(0..<10, id: \.self) { number in
                        Text("\(number)")
                            .font(MicaboFont.ui(size, weight: .bold))
                            .tracking(-size * 0.04)
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .frame(height: cell)
                    }
                }
                .offset(y: -CGFloat(digit) * cell)
                .frame(height: cell, alignment: .top)
                .clipped()
                .animation(.easeOut(duration: 0.14), value: digit)
                .opacity(index < leadingZeros ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: leadingZeros)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(value)")
    }
}

// MARK: - La signature

/// **Un tableau blanc qui suit le doigt.** Le trait est en encre, arrondi, et il se dessine
/// au fur et à mesure ; rien n'en est gardé, ni sur l'appareil, ni ailleurs : la signature
/// n'est pas une donnée, c'est un geste.
struct OnboardingSignaturePad: View {
    @Binding var strokes: [[CGPoint]]
    var placeholder: String

    @State private var current: [CGPoint] = []

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OnboardingPalette.white)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(OnboardingPalette.cardStrong, lineWidth: 1.5)

            // La ligne de signature, et la croix qui dit où signer.
            VStack {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 10) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(OnboardingPalette.grayLight)
                    Rectangle()
                        .fill(OnboardingPalette.cardStrong)
                        .frame(height: 1.5)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
            }

            if strokes.isEmpty, current.isEmpty {
                Text(placeholder)
                    .font(MicaboFont.ui(15, weight: .medium))
                    .foregroundStyle(OnboardingPalette.grayLight)
                    .transition(.opacity)
            }

            Canvas { context, _ in
                for stroke in strokes + [current] {
                    context.stroke(
                        Self.path(for: stroke),
                        with: .color(OnboardingPalette.ink),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .frame(height: 230)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .animation(OnboardingMotion.enter, value: strokes.isEmpty && current.isEmpty)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if current.isEmpty { Haptics.soft() }
                    current.append(value.location)
                }
                .onEnded { _ in
                    if !current.isEmpty { strokes.append(current) }
                    current = []
                }
        )
        .accessibilityElement()
        .accessibilityLabel(placeholder)
    }

    /// Le trait passe par les milieux des segments : c'est ce qui arrondit une suite de
    /// points en une courbe, sans que le doigt ait à être précis.
    private static func path(for points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count > 1 else {
            path.addLine(to: first)
            return path
        }
        for index in 1..<points.count {
            let previous = points[index - 1]
            let point = points[index]
            let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            path.addQuadCurve(to: middle, control: previous)
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }
}
