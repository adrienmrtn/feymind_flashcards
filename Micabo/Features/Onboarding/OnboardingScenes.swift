import SwiftUI

/// **Les scènes animées du parcours d'accueil.**
///
/// Le parcours n'avait que des animations d'**entrée** : chaque écran posait ses blocs en
/// fondu, puis s'arrêtait net. Sept pages plus loin, l'étudiant a vu sept images fixes
/// séparées par sept fondus identiques, et l'app n'a rien montré d'elle-même. Une animation
/// d'entrée dit « la page est arrivée » ; elle ne dit rien de ce que la page raconte.
///
/// Ces scènes-là tournent en boucle pendant qu'on lit. Chacune met en mouvement **ce que son
/// écran affirme** — un document qui devient des cartes, une carte qu'on retourne, une
/// courbe d'oubli qu'on rattrape, un compte à rebours qui bat. C'est le seul genre
/// d'animation qui vaille la place qu'il prend : elle remplace une phrase.
///
/// **Toutes s'arrêtent quand le système demande moins de mouvement.** Une boucle infinie est
/// exactement ce que `Réduire les animations` vise ; la scène rend alors sa dernière image,
/// qui est composée pour se tenir seule.
enum OnboardingScene {
    /// La hauteur commune. Les scènes ne se ressemblent pas, mais elles occupent la même
    /// place : sans ça, le titre monterait et descendrait d'un écran d'intro à l'autre.
    static let height: CGFloat = 188
}

// MARK: - Le document qui devient des cartes

/// **Une feuille se transforme en paquet de cartes**, en boucle.
///
/// C'est la promesse de l'écran d'import, littéralement : le document entre par la gauche,
/// ses lignes se rassemblent, et trois cartes s'en détachent en éventail. Puis tout revient
/// et recommence.
struct OnboardingImportScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// De 0 (la feuille seule) à 1 (les trois cartes déployées).
    @State private var phase: Double = 0

    private static let lines: [CGFloat] = [1, 0.78, 0.92, 0.64, 0.84]

    var body: some View {
        ZStack {
            sheet
                .offset(x: -34 * phase, y: 6 * phase)
                .rotationEffect(.degrees(-7 * phase))
                .opacity(1 - 0.45 * phase)

            ForEach(0..<3, id: \.self) { index in
                card(index)
            }
        }
        .frame(height: OnboardingScene.height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear(perform: start)
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(Self.lines.enumerated()), id: \.offset) { _, width in
                Capsule()
                    .fill(MicaboColor.inkTertiary.opacity(0.35))
                    .frame(height: 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: width, anchor: .leading)
            }
        }
        .padding(16)
        .frame(width: 112, height: 138)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.06), radius: 10, y: 4)
    }

    /// Une carte du paquet. Elles sortent l'une après l'autre : le décalage sur la phase est
    /// ce qui fait l'éventail plutôt qu'un bloc qui glisse.
    private func card(_ index: Int) -> some View {
        let share = max(0, min(1, (phase - Double(index) * 0.16) / 0.68))
        let spread = 26.0 * Double(index) - 26.0

        return RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(MicaboColor.accentSoft)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(MicaboColor.accent.opacity(0.22), lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    Capsule().fill(MicaboColor.accent.opacity(0.55)).frame(width: 40, height: 5)
                    Capsule().fill(MicaboColor.accent.opacity(0.28)).frame(width: 56, height: 5)
                }
                .padding(14)
            }
            .frame(width: 96, height: 120)
            .shadow(color: MicaboColor.accent.opacity(0.14), radius: 9, y: 4)
            .offset(x: 38 + spread * share, y: -8 * share)
            .rotationEffect(.degrees(Double(index - 1) * 9 * share))
            .scaleEffect(0.86 + 0.14 * share)
            .opacity(share)
    }

    private func start() {
        guard !reduceMotion else {
            phase = 1
            return
        }
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            phase = 1
        }
    }
}

// MARK: - La carte qu'on retourne

/// **Une carte qui se retourne**, question d'un côté, réponse de l'autre.
///
/// C'est le geste central de l'app, et il n'était montré nulle part avant la première
/// session. Le retournement est un vrai `rotation3DEffect` : la carte tourne sur son axe
/// vertical, et la face arrière n'apparaît qu'une fois passé le quart de tour — sans ça, on
/// lirait la réponse à l'envers pendant une demi-seconde.
struct OnboardingFlipScene: View {
    var question: String
    var answer: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flipped = false

    private var angle: Double { flipped ? 180 : 0 }

    var body: some View {
        ZStack {
            face(text: question, tone: .question)
                .opacity(flipped ? 0 : 1)

            face(text: answer, tone: .answer)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(flipped ? 1 : 0)
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.42)
        .frame(height: OnboardingScene.height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear(perform: start)
    }

    private enum Tone { case question, answer }

    private func face(text: String, tone: Tone) -> some View {
        VStack(spacing: 12) {
            Text(tone == .question ? "?" : "✓")
                .font(MicaboFont.ui(26, weight: .heavy))
                .foregroundStyle(tone == .question ? MicaboColor.accent : MicaboColor.positive)
                .frame(width: 42, height: 42)
                .background(
                    tone == .question ? MicaboColor.accentSoft : MicaboColor.positiveSoft,
                    in: Circle()
                )

            Text(text)
                .font(MicaboFont.ui(16, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(22)
        .frame(width: 244, height: 158)
        .background(MicaboColor.canvas, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: MicaboColor.ink.opacity(0.07), radius: 14, y: 6)
    }

    /// Le retournement marque un temps sur chaque face : une carte qui tourne sans arrêt ne
    /// se lit pas, et c'est justement ce qu'on veut montrer — qu'on a le temps de chercher.
    private func start() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1900))
                withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: 0.7)) { flipped.toggle() }
            }
        }
    }
}

// MARK: - Le compte à rebours qui bat

/// **Un anneau qui se remplit et un chiffre qui descend.**
///
/// L'écran des dates montrait une carte figée. Ce qu'elle affirme — « la date change le
/// rythme » — est un mouvement : l'anneau se remplit à mesure que l'échéance approche, le
/// chiffre descend, et la flamme bat. Trois choses qui bougent ensemble et qui disent la
/// même chose.
struct OnboardingCountdownScene: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var fill: CGFloat = 0.08
    @State private var days = 24
    @State private var beat = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(MicaboColor.track, lineWidth: 13)

            Circle()
                .trim(from: 0, to: fill)
                .stroke(
                    AngularGradient(
                        colors: [MicaboColor.accent, MicaboColor.flame],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 13, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("J-\(days)")
                    .font(MicaboFont.ui(34, weight: .heavy))
                    .tracking(-1.2)
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))

                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MicaboColor.flame)
                        .scaleEffect(beat ? 1.22 : 1)

                    Text("\(cardsPerDay)")
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
        }
        .frame(width: 152, height: 152)
        .frame(height: OnboardingScene.height)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
        .onAppear(perform: start)
    }

    /// Le rythme que cette date impose. Il monte quand l'échéance approche, ce qui est
    /// exactement la règle du produit — la même que `DeckPace`, en plus simple.
    private var cardsPerDay: Int {
        max(4, Int((120.0 / Double(max(1, days))).rounded()))
    }

    private func start() {
        guard !reduceMotion else {
            fill = 0.72
            days = 7
            return
        }

        withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: true)) {
            beat = true
        }

        Task { @MainActor in
            while !Task.isCancelled {
                for step in stride(from: 24, through: 4, by: -4) {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        days = step
                        fill = CGFloat(1 - Double(step) / 26.0)
                    }
                    try? await Task.sleep(for: .milliseconds(620))
                }
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.easeInOut(duration: 0.5)) {
                    days = 24
                    fill = 0.08
                }
                try? await Task.sleep(for: .milliseconds(700))
            }
        }
    }
}
