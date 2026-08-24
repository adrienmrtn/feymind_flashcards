import Combine
import SwiftUI

/// Écran 1 : l'accroche. Un paquet de cartes se rebat tout seul, et rien d'autre.
///
/// Le paragraphe d'explication qui vivait ici est parti. Sur le premier écran d'une app,
/// personne ne lit trois lignes sur le fonctionnement d'un algorithme : on regarde. Les
/// cartes disent déjà ce que fait Micabo, et **elles montrent les trois formats** — recto
/// verso, QCM, texte à trou — ce qu'aucune phrase ne faisait.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model

    private let surface = OnboardingStep.welcome.surface

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.md)

            WelcomeDeck()
                .frame(height: 250)
                .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)

            VStack(alignment: .leading, spacing: 10) {
                Text("MICABO")
                    .font(MicaboFont.hanken(11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(surface.eyebrow)
                    .onboardingAppear(index: 0, stagger: 0.1)

                Text("Apprends tout,\nplus vite.")
                    .font(MicaboFont.hanken(40, weight: .bold))
                    .foregroundStyle(surface.title)
                    .tracking(-1.2)
                    .lineSpacing(-3)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1, stagger: 0.1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.lg)

            MicaboBottomBar(background: surface.background) {
                OnboardingContinueButton(title: "Commencer") {
                    model.advance()
                }
                .onboardingAppear(index: 2, stagger: 0.1)
            }
        }
        .background(surface.background.ignoresSafeArea(edges: .bottom))
        .environment(\.onboardingSurface, surface)
    }
}

// MARK: - Le paquet

/// Paquet de cartes qui se rebat en boucle, un format après l'autre.
private struct WelcomeDeck: View {
    private enum Face {
        case question(String)
        case choice(question: String, options: [String], answer: Int)
        case gap(before: String, after: String, answer: String)

        var badge: String {
            switch self {
            case .question: "Recto verso"
            case .choice: "QCM"
            case .gap: "Texte à trou"
            }
        }

        var symbol: String {
            switch self {
            case .question: "rectangle.on.rectangle.angled"
            case .choice: "list.bullet"
            case .gap: "ellipsis.rectangle"
            }
        }
    }

    private struct DeckCard: Identifiable {
        let id = UUID()
        let subject: String
        let tint: Color
        let face: Face
    }

    /// Quatre cartes, trois formats, quatre matières. Elles ne sont pas là pour être lues
    /// en entier : elles sont là pour qu'on reconnaisse un QCM et un texte à trou.
    private let cards: [DeckCard] = [
        DeckCard(
            subject: "Histoire",
            tint: Color(hex: 0x8C6A3F),
            face: .question("Quelle année marque la chute du mur de Berlin ?")
        ),
        DeckCard(
            subject: "Biologie",
            tint: Color(hex: 0x47665A),
            face: .choice(
                question: "Où se déroule le cycle de Calvin ?",
                options: ["Dans le stroma", "Dans les thylakoïdes", "Dans le noyau"],
                answer: 0
            )
        ),
        DeckCard(
            subject: "Maths",
            tint: Color(hex: 0x5B5BD6),
            face: .gap(before: "La dérivée de ln(x) vaut", after: "sur son intervalle.", answer: "1/x")
        ),
        DeckCard(
            subject: "Espagnol",
            tint: Color(hex: 0x6E5566),
            face: .question("Comment dit-on « apprendre par cœur » ?")
        )
    ]

    @State private var top = 0
    @State private var hasAppeared = false

    private let timer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let depth = (index - top + cards.count) % cards.count
                WelcomeCard(subject: card.subject, tint: card.tint, face: card.face)
                    .scaleEffect(1 - CGFloat(depth) * 0.05)
                    .offset(y: CGFloat(depth) * 15 - (hasAppeared ? 0 : 26))
                    .rotationEffect(.degrees(rotation(for: depth)))
                    .opacity(depth >= 3 ? 0 : 1 - Double(depth) * 0.14)
                    .zIndex(Double(cards.count - depth))
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            // Une courbe qui s'arrête net, pas un ressort : le paquet se pose, il ne
            // rebondit pas sur l'écran d'accueil.
            withAnimation(OnboardingMotion.shift.delay(0.08)) {
                hasAppeared = true
            }
        }
        .onReceive(timer) { _ in
            withAnimation(OnboardingMotion.shift) {
                top = (top + 1) % cards.count
            }
            Haptics.tick()
        }
    }

    private func rotation(for depth: Int) -> Double {
        switch depth {
        case 0: -1
        case 1: 1.6
        case 2: -2.2
        default: 2.8
        }
    }
}

private struct WelcomeCard: View {
    let subject: String
    let tint: Color
    let face: WelcomeDeck.Face

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 182)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
        .shadow(color: Color.black.opacity(0.32), radius: 20, x: 0, y: 12)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: face.symbol)
                .font(.system(size: 9, weight: .semibold))
            Text(face.badge.uppercased())
                .font(MicaboFont.hanken(9.5, weight: .bold))
                .tracking(1.1)

            Spacer(minLength: MicaboSpacing.xs)

            Text(subject.uppercased())
                .font(MicaboFont.hanken(9.5, weight: .semibold))
                .tracking(1.1)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .foregroundStyle(tint)
    }

    @ViewBuilder
    private var content: some View {
        switch face {
        case .question(let question):
            Text(question)
                .font(MicaboFont.hanken(19, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
                .fixedSize(horizontal: false, vertical: true)

        case .choice(let question, let options, let answer):
            VStack(alignment: .leading, spacing: 8) {
                Text(question)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        choiceRow(option, isAnswer: index == answer)
                    }
                }
            }

        case .gap(let before, let after, let answer):
            VStack(alignment: .leading, spacing: 10) {
                Text(gapSentence(before: before, after: after))
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(answer)
                    .font(.system(size: 13, weight: .semibold, design: .serif).italic())
                    .foregroundStyle(tint)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(tint.opacity(0.1), in: Capsule())
            }
        }
    }

    /// Le blanc est la graphie du texte à trou de toute l'app, `ClozeGap.marker`, et il
    /// porte la couleur de la matière pour qu'on le repère avant d'avoir lu la phrase.
    private func gapSentence(before: String, after: String) -> AttributedString {
        var sentence = AttributedString(before + " ")
        var gap = AttributedString(ClozeGap.marker)
        gap.foregroundColor = tint
        sentence += gap
        sentence += AttributedString(" " + after)
        return sentence
    }

    private func choiceRow(_ option: String, isAnswer: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .strokeBorder(isAnswer ? tint : MicaboColor.strokeStrong, lineWidth: isAnswer ? 3.5 : 1.5)
                .frame(width: 10, height: 10)

            Text(option)
                .font(MicaboFont.hanken(12.5, weight: isAnswer ? .semibold : .regular))
                .foregroundStyle(isAnswer ? MicaboColor.ink : MicaboColor.inkSecondary)
                .lineLimit(1)
        }
    }
}
