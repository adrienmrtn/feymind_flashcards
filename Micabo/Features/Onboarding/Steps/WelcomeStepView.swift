import Combine
import SwiftUI

/// Écran 1 : accroche. Un petit paquet de cartes se rebat tout seul derrière le titre.
struct WelcomeStepView: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: MicaboSpacing.lg)

            WelcomeDeck()
                .frame(height: 230)
                .padding(.horizontal, MicaboSpacing.xl)

            Spacer(minLength: MicaboSpacing.lg)

            VStack(alignment: .leading, spacing: 12) {
                Text("Bienvenue sur Micabo")
                    .font(MicaboFont.hanken(13, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MicaboColor.accent)
                    .onboardingAppear(index: 0, stagger: 0.12)

                Text("Apprends tout,\nplus vite.")
                    .font(MicaboFont.hanken(38, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-1)
                    .lineSpacing(-2)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 1, stagger: 0.12)

                Text("Tes cours deviennent des cartes, et Micabo te les repose pile au moment où tu allais les oublier.")
                    .font(MicaboFont.hanken(15, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingAppear(index: 2, stagger: 0.12)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.lg)

            MicaboBottomBar {
                OnboardingContinueButton(title: "Commencer") {
                    model.advance()
                }
                .onboardingAppear(index: 3, stagger: 0.12)
            }
        }
    }
}

/// Paquet de cartes qui se rebat en boucle.
private struct WelcomeDeck: View {
    private struct DeckCard: Identifiable {
        let id = UUID()
        let subject: String
        let question: String
        let tint: Color
    }

    private let cards: [DeckCard] = [
        DeckCard(subject: "Histoire", question: "Quelle année marque la chute du mur de Berlin ?", tint: Color(hex: 0x47665A)),
        DeckCard(subject: "Biologie", question: "Où se déroule le cycle de Calvin ?", tint: Color(hex: 0x5B5BD6)),
        DeckCard(subject: "Espagnol", question: "Comment dit-on « apprendre par cœur » ?", tint: Color(hex: 0x8C6A3F)),
        DeckCard(subject: "Maths", question: "Que vaut la dérivée de ln(x) ?", tint: Color(hex: 0x6E5566))
    ]

    @State private var top = 0
    @State private var hasAppeared = false

    private let timer = Timer.publish(every: 2.4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                let depth = (index - top + cards.count) % cards.count
                WelcomeCard(subject: card.subject, question: card.question, tint: card.tint)
                    .scaleEffect(1 - CGFloat(depth) * 0.055)
                    .offset(y: CGFloat(depth) * 16 - (hasAppeared ? 0 : 40))
                    .rotationEffect(.degrees(rotation(for: depth)))
                    .opacity(depth >= 3 ? 0 : 1 - Double(depth) * 0.12)
                    .zIndex(Double(cards.count - depth))
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.spring(response: 0.62, dampingFraction: 0.78)) {
                top = (top + 1) % cards.count
            }
            Haptics.tick()
        }
    }

    private func rotation(for depth: Int) -> Double {
        switch depth {
        case 0: -1.2
        case 1: 1.8
        case 2: -2.4
        default: 3
        }
    }
}

private struct WelcomeCard: View {
    let subject: String
    let question: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                Text(subject.uppercased())
                    .font(MicaboFont.hanken(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MicaboColor.inkTertiary)
            }

            Text(question)
                .font(MicaboFont.hanken(19, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 11, weight: .medium))
                Text("Appuie pour retourner")
                    .font(MicaboFont.hanken(11, weight: .medium))
            }
            .foregroundStyle(MicaboColor.inkTertiary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 168)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.xl, style: .continuous)
                .strokeBorder(MicaboColor.stroke, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 8)
    }
}
