import SwiftUI

/// Démonstration, 3 sur 3 : la fiche se décompose en cartes, puis on en révise une.
///
/// L'écran s'ouvre sur **la fiche de l'écran précédent**, au même endroit et à la même
/// taille : c'est ce qui fait comprendre d'où viennent les cartes. Elle se défait ensuite en
/// trois cartes qui s'ouvrent en éventail, une par format, puis la première passe devant et
/// devient jouable.
///
/// Deux phrases d'explication au maximum sur tout l'écran : la répétition espacée a déjà eu
/// son écran, ici on révise.
struct DemoReviewStepView: View {
    @Environment(OnboardingModel.self) private var model

    private enum Phase {
        /// La fiche, telle qu'on l'a laissée.
        case sheet
        /// Elle s'ouvre en trois cartes.
        case fan
        /// La première carte passe devant, à portée de doigt.
        case play
    }

    private enum Verdict {
        case again
        case known

        var interval: String {
            switch self {
            case .again: "dans 10 minutes"
            case .known: "dans 3 jours"
            }
        }

        var tint: Color {
            switch self {
            case .again: MicaboColor.caution
            case .known: MicaboColor.positive
            }
        }
    }

    @State private var phase: Phase = .sheet
    @State private var isFlipped = false
    @State private var verdict: Verdict?
    @State private var didStart = false

    private var cards: [OnboardingDemo.Card] { OnboardingDemo.cards }
    private var card: OnboardingDemo.Card { cards[0] }

    var body: some View {
        OnboardingScaffold(
            eyebrow: "Comment ça marche · 3 sur 3",
            title: phase == .play ? "À toi de jouer." : "Ta fiche devient des cartes.",
            subtitle: phase == .play ? "Appuie sur la carte, puis dis si tu savais." : nil,
            titleSize: 30,
            contentSpacing: MicaboSpacing.lg,
            scrolls: false
        ) {
            VStack(spacing: 18) {
                stage
                controls
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .animation(OnboardingMotion.shift, value: phase)
        .onAppear(perform: run)
    }

    // MARK: - La scène

    private var stage: some View {
        ZStack {
            DemoSheetPage()
                .frame(width: 232)
                .opacity(phase == .sheet ? 1 : 0)
                .scaleEffect(phase == .sheet ? 1 : 0.9)
                .shadow(color: Color.black.opacity(0.08), radius: 18, x: 0, y: 10)

            fan
                .opacity(phase == .fan ? 1 : 0)

            playCard
                .opacity(phase == .play ? 1 : 0)
        }
        .frame(height: 210)
    }

    /// Les trois formats ouverts en éventail. Chacun porte son étiquette : c'est là qu'on
    /// voit que Micabo ne fait pas que du recto verso.
    private var fan: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, entry in
                DemoMiniCard(card: entry, isCompact: true)
                    .frame(width: 150)
                    .rotationEffect(.degrees(fanRotation(index)))
                    .offset(x: fanOffset(index), y: CGFloat(abs(index - 1)) * 8)
                    .zIndex(index == 1 ? 3 : Double(2 - index))
            }
        }
    }

    private func fanRotation(_ index: Int) -> Double {
        [-9, 0, 9][min(index, 2)]
    }

    private func fanOffset(_ index: Int) -> CGFloat {
        [-64, 0, 64][min(index, 2)]
    }

    /// La carte jouable, et les deux autres qui dépassent derrière : on voit qu'il y en a
    /// d'autres sans les lire.
    private var playCard: some View {
        ZStack {
            ForEach(Array(cards.dropFirst().enumerated()), id: \.element.id) { index, _ in
                RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                    .fill(MicaboColor.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                            .strokeBorder(MicaboColor.stroke, lineWidth: 1)
                    }
                    .frame(height: 172)
                    .scaleEffect(1 - CGFloat(index + 1) * 0.04)
                    .offset(y: CGFloat(index + 1) * 11)
                    .opacity(0.65)
            }

            FlipCard(front: card.front, back: card.back, isFlipped: isFlipped)
                .onTapGesture(perform: flip)
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(isFlipped ? card.back : card.front)
                .accessibilityHint(isFlipped ? "" : "Appuie pour voir la réponse")
        }
    }

    // MARK: - Commandes

    @ViewBuilder
    private var controls: some View {
        if let verdict {
            pill(
                systemImage: "clock.arrow.circlepath",
                text: "Elle revient \(verdict.interval)",
                tint: verdict.tint,
                background: verdict.tint.opacity(0.12)
            )
            .transition(.opacity)
        } else if isFlipped {
            HStack(spacing: 10) {
                verdictButton(.again, title: "À revoir", systemImage: "arrow.counterclockwise")
                verdictButton(.known, title: "Je savais", systemImage: "checkmark")
            }
            .transition(.opacity)
        } else if phase == .play {
            pill(
                systemImage: "hand.tap.fill",
                text: "Appuie sur la carte",
                tint: MicaboColor.ink,
                background: MicaboColor.surfaceMuted
            )
            .transition(.opacity)
        }
    }

    private func pill(systemImage: String, text: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(MicaboFont.hanken(13, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.vertical, 9)
        .padding(.horizontal, 14)
        .background(background, in: Capsule())
        .frame(maxWidth: .infinity)
    }

    private func verdictButton(_ value: Verdict, title: String, systemImage: String) -> some View {
        Button {
            choose(value)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(MicaboFont.hanken(14, weight: .semibold))
            }
            .foregroundStyle(value.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(value.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    // MARK: - Déroulé

    /// La fiche se défait en un peu plus d'une seconde, puis la main est rendue.
    private func run() {
        guard !didStart else { return }
        didStart = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(OnboardingMotion.shift) { phase = .fan }
            Haptics.tick()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(OnboardingMotion.shift) { phase = .play }
            Haptics.light()
        }
    }

    /// La note vaut validation : on laisse voir la prochaine échéance, puis on enchaîne.
    private func choose(_ value: Verdict) {
        guard verdict == nil else { return }
        Haptics.success()
        withAnimation(OnboardingMotion.shift) {
            verdict = value
        }

        // Résolu maintenant : lire l'environnement depuis un bloc différé n'est pas sûr.
        let flow = model
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            flow.advance()
        }
    }

    private func flip() {
        guard phase == .play, !isFlipped else { return }
        Haptics.rigid()
        withAnimation(OnboardingMotion.shift) {
            isFlipped = true
        }
    }
}

/// Carte qui pivote sur son axe vertical. Une ligne au recto, une ligne au verso.
private struct FlipCard: View {
    let front: String
    let back: String
    let isFlipped: Bool

    var body: some View {
        ZStack {
            face(label: OnboardingDemo.subject, text: front, isAnswer: false)
                .opacity(isFlipped ? 0 : 1)

            face(label: "Réponse", text: back, isAnswer: true)
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }

    private func face(label: String, text: String, isAnswer: Bool) -> some View {
        VStack(spacing: 12) {
            Text(label.uppercased())
                .font(MicaboFont.eyebrow)
                .tracking(MicaboTracking.caps)
                .foregroundStyle(isAnswer ? MicaboColor.accent : MicaboColor.inkTertiary)

            Text(text)
                .font(MicaboFont.hanken(isAnswer ? 22 : 20, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .frame(height: 172)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 15, x: 0, y: 8)
    }
}
