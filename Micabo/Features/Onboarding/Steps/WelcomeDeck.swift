import Combine
import SwiftUI

/// Paquet de cartes de l'écran d'accueil. Isolé de `WelcomeStepView` pour que le
/// compilateur type-checke l'accroche et le paquet chacun de leur côté.
struct WelcomeDeck: View {
    /// Face d'une carte. **Dans** le paquet, comme `CardFace` : un `private` imbriqué
    /// n'est lisible que par les types du même parent. La laisser à côté, c'est
    /// l'erreur « Face is inaccessible » que Xcode a levée.
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

    private struct Item: Identifiable {
        let id = UUID()
        let subject: String
        let tint: Color
        let face: Face
    }

    private let items: [Item] = WelcomeDeck.makeItems()

    @State private var top = 0
    @State private var hasAppeared = false

    private let timer = Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()

    var body: some View {
        stack
            .opacity(hasAppeared ? 1 : 0)
            .onAppear(perform: appear)
            .onReceive(timer) { _ in advance() }
    }

    private var stack: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                card(item, depth: depth(of: index))
            }
        }
    }

    private func card(_ item: Item, depth: Int) -> some View {
        CardFace(subject: item.subject, tint: item.tint, face: item.face)
            .scaleEffect(scale(for: depth))
            .offset(y: offset(for: depth))
            .rotationEffect(.degrees(rotation(for: depth)))
            .opacity(opacity(for: depth))
            .zIndex(Double(items.count - depth))
    }

    private func depth(of index: Int) -> Int {
        (index - top + items.count) % items.count
    }

    private func scale(for depth: Int) -> CGFloat {
        1 - CGFloat(depth) * 0.05
    }

    private func offset(for depth: Int) -> CGFloat {
        CGFloat(depth) * 15 - (hasAppeared ? 0 : 26)
    }

    private func rotation(for depth: Int) -> Double {
        switch depth {
        case 0: -1
        case 1: 1.6
        case 2: -2.2
        default: 2.8
        }
    }

    private func opacity(for depth: Int) -> Double {
        depth >= 3 ? 0 : 1 - Double(depth) * 0.14
    }

    private func appear() {
        withAnimation(OnboardingMotion.shift.delay(0.08)) {
            hasAppeared = true
        }
    }

    private func advance() {
        withAnimation(OnboardingMotion.shift) {
            top = (top + 1) % items.count
        }
        Haptics.tick()
    }

    private static func makeItems() -> [Item] {
        [
            Item(
                subject: "Histoire",
                tint: Color(hex: 0x1E3A8A),
                face: .question("Quelle année marque la chute du mur de Berlin ?")
            ),
            Item(
                subject: "Biologie",
                tint: Color(hex: 0x0F766E),
                face: .choice(
                    question: "Où se déroule le cycle de Calvin ?",
                    options: ["Dans le stroma", "Dans les thylakoïdes", "Dans le noyau"],
                    answer: 0
                )
            ),
            Item(
                subject: "Maths",
                tint: MicaboColor.accent,
                face: .gap(before: "La dérivée de ln(x) vaut", after: "sur son intervalle.", answer: "1/x")
            ),
            Item(
                subject: "Espagnol",
                tint: Color(hex: 0x7C3AED),
                face: .question("Comment dit-on « apprendre par cœur » ?")
            )
        ]
    }

    private struct CardFace: View {
        let subject: String
        let tint: Color
        let face: Face

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
            // L'ombre était réglée pour un fond noir, où il fallait presque un tiers de noir
            // pour qu'un blanc se décolle. Sur la sauge, la même ombre salit le fond autour
            // du paquet : le contraste des deux surfaces fait déjà le travail, l'ombre n'a
            // plus qu'à donner l'épaisseur du papier.
            .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 9)
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
                questionBlock(question)
            case .choice(let question, let options, let answer):
                choiceBlock(question: question, options: options, answer: answer)
            case .gap(let before, let after, let answer):
                gapBlock(before: before, after: after, answer: answer)
            }
        }

        private func questionBlock(_ question: String) -> Text {
            Text(question)
                .font(MicaboFont.hanken(19, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.3)
        }

        private func choiceBlock(question: String, options: [String], answer: Int) -> some View {
            VStack(alignment: .leading, spacing: 8) {
                Text(question)
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        choiceRow(option, isAnswer: index == answer)
                    }
                }
            }
        }

        private func gapBlock(before: String, after: String, answer: String) -> some View {
            VStack(alignment: .leading, spacing: 10) {
                Text(gapSentence(before: before, after: after))
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                Text(answer)
                    .font(.system(size: 13, weight: .semibold, design: .serif).italic())
                    .foregroundStyle(tint)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 9)
                    .background(tint.opacity(0.1), in: Capsule())
            }
        }

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
}
