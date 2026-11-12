import SwiftUI

// MARK: - Mika pose la question

/// **Mika pose la question** : en demi (`MikaPeek`), il dépasse de sa ligne au bord gauche de
/// la page, et sa bulle à côté de lui, dont le texte s'écrit lettre après lettre.
///
/// C'est l'en-tête de toutes les questions du parcours, au même endroit sur chaque écran : la
/// même place pour Mika, la même bulle, puis les réponses dessous et le rond en bas. Il vit
/// sur le papier de l'app — crème le jour, graphite la nuit, où une lueur discrète le détache
/// —, pas dans une scène bleue.
///
/// **Il réagit.** Une réponse donnée sur cette page le fait sourire ; quand l'écran a une
/// réaction à dire (« Bac : encore 7 mois. On a le temps de bien faire 💪 »), la bulle la
/// tape à la place de la question. La bulle garde la hauteur de la plus longue des deux :
/// rien ne saute sous le doigt quand elle change.
///
/// Le seul Mika de l'écran : il est sur sa ligne quand la page arrive (un fondu, sur place),
/// puis sourit à chaque réponse — un petit écrasement, jamais un saut.
struct OnboardingMikaPrompt: View {
    /// La question ; un passage entre `**` prend le bleu de l'app.
    let question: String
    /// Ce que Mika répond à la réponse donnée, quand l'écran en a une.
    var reaction: String?
    var mood: MikaMood = .idle
    /// Le nombre de réponses données sur la page : chacune le fait sourire.
    var cheers: Int = 0

    @Environment(\.onboardingStill) private var still
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var typed = 0
    @State private var showsReaction = false
    @State private var shownMood: MikaMood?
    @State private var typing: Task<Void, Never>?
    @State private var settle: Task<Void, Never>?

    /// La largeur de Mika en demi : la taille de tous les Mika posés sur une ligne.
    static let mikaSize: CGFloat = MikaPeek.line
    /// Ce qui dépasse de la ligne.
    static var mikaHeight: CGFloat { MikaPeek.height(for: mikaSize) }

    @ScaledMetric(relativeTo: .title3) private var textSize: CGFloat = 20

    /// Posé par les rendus : la réaction s'affiche sans attendre une réponse.
    @Environment(\.onboardingShowsReaction) private var forcesReaction

    private var current: String {
        showsReaction || forcesReaction ? (reaction ?? question) : question
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 2) {
                MikaPeek(
                    mood: shownMood ?? mood,
                    width: Self.mikaSize,
                    reactsToTap: true,
                    animates: !still
                )
                .accessibilityHidden(true)

                bubble
                    .padding(.bottom, 12)
                    .padding(.leading, 4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // **La ligne d'où Mika dépasse** : elle coupe son corps (la règle de mise en scène).
            // Elle sépare aussi la question des réponses.
            Capsule()
                .fill(MicaboColor.stroke)
                .frame(height: 2)
        }
        .onAppear(perform: start)
        .onDisappear {
            typing?.cancel()
            settle?.cancel()
        }
        .onChange(of: cheers) { _, _ in react() }
        .onChange(of: reaction) { _, newValue in
            guard showsReaction, newValue != nil else { return }
            type(from: 0)
        }
    }

    // MARK: La bulle

    private var bubble: some View {
        ZStack(alignment: .topLeading) {
            // La plus longue des deux phrases tient la place, invisible : la bulle ne change
            // pas de taille quand Mika passe de la question à sa réaction.
            line(question, revealed: nil).hidden()
            if let reaction {
                line(reaction, revealed: nil).hidden()
            }
            line(current, revealed: still || reduceMotion ? nil : typed)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
        .overlay(alignment: .bottomLeading) {
            OnboardingBubbleTail()
                .offset(x: -9, y: -14)
                .flipsForRightToLeftLayoutDirection(true)
        }
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.plain(current))
        .accessibilityAddTraits(.isHeader)
    }

    /// La phrase, ses passages marqués en bleu, et ce qui n'est pas encore écrit transparent :
    /// la mise en page est celle de la phrase entière dès la première lettre, et les lignes ne
    /// se recomposent pas pendant qu'elle s'écrit.
    private func line(_ template: String, revealed: Int?) -> some View {
        Text(Self.attributed(template, revealed: revealed))
            .font(MicaboFont.ui(min(textSize, 30), weight: .heavy))
            .tracking(-0.3)
            .lineSpacing(1)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func plain(_ template: String) -> String {
        template.replacingOccurrences(of: "**", with: "")
    }

    static func attributed(_ template: String, revealed: Int?) -> AttributedString {
        var result = AttributedString()
        var written = 0
        for (index, part) in template.components(separatedBy: "**").enumerated() {
            let isAccent = index % 2 == 1
            for character in part {
                var piece = AttributedString(String(character))
                let shown = revealed.map { written < $0 } ?? true
                piece.foregroundColor = shown ? (isAccent ? MicaboColor.accent : MicaboColor.ink) : .clear
                result += piece
                written += 1
            }
        }
        return result
    }

    // MARK: Le temps

    private func start() {
        guard typed == 0 else { return }
        if still || reduceMotion {
            typed = Self.plain(current).count
            return
        }
        // La page glisse d'abord : la bulle commence à s'écrire une fois posée.
        type(from: 0, after: OnboardingMotion.slideDuration)
    }

    private func type(from start: Int, after delay: Double = 0.05) {
        typing?.cancel()
        let total = Self.plain(current).count
        guard !(still || reduceMotion) else {
            typed = total
            return
        }
        typed = start
        typing = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            while !Task.isCancelled, typed < total {
                // Deux lettres par pas : une phrase de soixante signes s'écrit en une seconde.
                typed = min(total, typed + 2)
                try? await Task.sleep(for: .milliseconds(34))
            }
        }
    }

    private func react() {
        settle?.cancel()
        shownMood = .happy
        if reaction != nil {
            showsReaction = true
            type(from: 0)
        }
        settle = Task { @MainActor in
            // Le saut dure 1,6 s : il retombe avant de changer d'humeur.
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            shownMood = reaction != nil ? .happy : nil
        }
    }
}

private struct OnboardingShowsReactionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// **La réaction de Mika, d'emblée** : pour les rendus de la CI, qui ne répondent à rien.
    var onboardingShowsReaction: Bool {
        get { self[OnboardingShowsReactionKey.self] }
        set { self[OnboardingShowsReactionKey.self] = newValue }
    }
}

/// La queue de la bulle, vers Mika : un triangle bordé du même filet que la bulle.
struct OnboardingBubbleTail: View {
    var body: some View {
        ZStack {
            Tail()
                .fill(MicaboColor.stroke)
                .frame(width: 12, height: 20)
            Tail()
                .fill(MicaboColor.surface)
                .frame(width: 10, height: 16)
                .offset(x: 2)
        }
        .frame(width: 12, height: 20)
        .accessibilityHidden(true)
    }

    private struct Tail: Shape {
        func path(in rect: CGRect) -> Path {
            Path { path in
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                path.closeSubpath()
            }
        }
    }
}

// MARK: - Une phrase de Mika, seule

/// **Mika parle, sans poser de question** : la bienvenue, l'introduction d'un écran. Le même
/// Mika en demi que sur les questions, qui dépasse de sa ligne, et sa bulle au-dessus de lui.
struct OnboardingMikaSays: View {
    let text: String
    var mood: MikaMood = .wave
    var size: CGFloat = MikaPeek.hero

    @Environment(\.onboardingStill) private var still

    var body: some View {
        VStack(spacing: 6) {
            MicaboSpeechBubble(text: OnboardingMikaPrompt.plain(text), tail: .bottom)
                .padding(.horizontal, MicaboSpacing.screen)
            VStack(spacing: 0) {
                MikaPeek(mood: mood, width: size, reactsToTap: true, animates: !still)
                Capsule()
                    .fill(MicaboColor.stroke)
                    .frame(width: size * 1.5, height: 2)
            }
        }
    }
}
