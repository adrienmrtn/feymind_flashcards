import SwiftUI

// MARK: - La question d'essai

/// **Une vraie question de parcours, sur sa matière, avant le plan et l'offre** (lot 7).
///
/// Jusqu'ici, le parcours *disait* ce que fait Mika ; ici l'élève le *fait* : Mika lui pose
/// une question comme celles de ses parcours, dans une matière qu'il a cochée, trois réponses
/// à toucher. Il répond, la bonne s'allume en vert (et la sienne en rouge s'il s'est trompé),
/// Mika réagit dans sa bulle, et **la recherche dit pourquoi ça marche** — une semaine après,
/// on retient 80 % d'un cours en se testant, contre 36 % en le relisant (Karpicke & Roediger,
/// Science, 2008). C'est la seule étude citée du parcours, et elle tombe au moment où elle se
/// comprend : l'élève vient de se tester.
///
/// **Rien ne part au serveur.** Les questions sont écrites d'avance dans les 26 langues
/// (`SampleCard`), avec des réponses qui se lisent partout (« π × r² », « H₂O », « 1989 »). Elles
/// valent du collège à l'université : c'est une démonstration de la mécanique, pas un test de
/// niveau.
///
/// Le rond ne s'allume qu'une fois la réponse donnée : c'est un petit oui, facile, avant les
/// écrans qui engagent (le plan, l'essai).
struct SampleCardStepView: View {
    /// Une réponse déjà donnée, pour les rendus.
    var previewAnswer: Int?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var answer: Int?

    private var chosen: Int? { answer ?? previewAnswer }

    private var pick: SampleCard.Pick {
        SampleCard.pick(for: model.subjects)
    }

    private var reaction: String? {
        guard let chosen else { return nil }
        return i18n.t(pick.card.isRight(chosen) ? "ios.onb7.card.right" : "ios.onb7.card.wrong")
    }

    var body: some View {
        OnboardingScaffold(
            title: i18n.t("ios.onb7.card.ask"),
            reaction: reaction
        ) {
            VStack(alignment: .leading, spacing: 14) {
                subjectChip

                Text(i18n.t(pick.card.questionKey))
                    .font(MicaboFont.ui(21, weight: .heavy))
                    .tracking(-0.3)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 2)

                VStack(spacing: 10) {
                    ForEach(Array(pick.card.displayOrder.enumerated()), id: \.element) { rank, option in
                        SampleCardOption(
                            title: pick.card.option(option, locale: i18n.locale),
                            state: state(of: option),
                            rank: rank
                        ) {
                            choose(option)
                        }
                    }
                }

                if chosen != nil {
                    proof
                        .transition(.opacity.combined(with: .offset(y: 6)))
                }
            }
            .animation(MicaboMotion.standard, value: chosen)
        } footer: {
            OnboardingArrowButton(isEnabled: chosen != nil) { model.advance() }
        }
    }

    private var subjectChip: some View {
        HStack(spacing: 6) {
            Text(pick.emoji)
                .font(.system(size: 14))
            Text(SubjectDisplay.subject(pick.subject, locale: i18n.locale))
                .font(MicaboFont.ui(13.5, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .foregroundStyle(MicaboColor.accentInk)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(MicaboColor.accentSoft, in: Capsule())
    }

    /// **Pourquoi se tester**, une fois, sourcé.
    private var proof: some View {
        HStack(alignment: .top, spacing: 10) {
            MicaboIconView(icon: .diploma, size: 22)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                OnboardingAccentText(
                    template: i18n.t("ios.onb7.card.proof", [
                        "testing": L10n.percent(OnboardingProofFigures.retainedByTesting, locale: i18n.locale),
                        "reread": L10n.percent(OnboardingProofFigures.retainedByRereading, locale: i18n.locale),
                    ]),
                    size: 15,
                    alignment: .leading,
                    color: MicaboColor.inkSecondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(i18n.t("ios.journey.source"))
                    .font(MicaboFont.ui(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    private func state(of option: Int) -> SampleCardOption.Look {
        guard let chosen else { return .open }
        if pick.card.isRight(option) { return .right }
        return option == chosen ? .wrong : .dimmed
    }

    private func choose(_ option: Int) {
        guard chosen == nil else { return }
        answer = option
        let right = pick.card.isRight(option)
        if right { Haptics.success() } else { Haptics.warning() }
        Analytics.track(.onboardingAnswer, [
            "field": "sampleCard",
            "value": .text(right ? "right" : "wrong"),
        ])
    }
}

// MARK: - Une réponse

/// Une réponse de la question d'essai : la rangée du parcours, qui s'allume en vert quand
/// c'est la bonne et en rouge quand c'est celle, fausse, qu'on a touchée. Les autres
/// s'effacent à moitié.
private struct SampleCardOption: View {
    enum Look: Equatable {
        case open
        case right
        case wrong
        case dimmed
    }

    let title: String
    let state: Look
    var rank: Int
    var action: () -> Void

    @Environment(\.onboardingCheer) private var cheer

    var body: some View {
        Button {
            guard state == .open else { return }
            action()
            cheer()
        } label: {
            HStack(spacing: 12) {
                Text(title)
                    .font(MicaboFont.ui(18, weight: .bold))
                    .foregroundStyle(ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MicaboSpacing.xs)
                mark
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(stroke, lineWidth: state == .open || state == .dimmed ? 1.5 : 2)
            )
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .disabled(state != .open)
        .animation(OnboardingMotion.select, value: state)
        .accessibilityAddTraits(state == .right || state == .wrong ? [.isSelected] : [])
    }

    private var ink: Color {
        switch state {
        case .right: MicaboColor.correctInk
        case .wrong: MicaboColor.wrongInk
        default: MicaboColor.ink
        }
    }

    private var fill: Color {
        switch state {
        case .right: MicaboColor.correctSoft
        case .wrong: MicaboColor.wrongSoft
        default: MicaboColor.surface
        }
    }

    private var stroke: Color {
        switch state {
        case .right: MicaboColor.correct
        case .wrong: MicaboColor.wrong
        default: MicaboColor.stroke
        }
    }

    @ViewBuilder
    private var mark: some View {
        switch state {
        case .right:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MicaboColor.correct)
        case .wrong:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(MicaboColor.wrong)
        default:
            Circle()
                .strokeBorder(MicaboColor.strokeStrong, lineWidth: 2)
                .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Les questions

/// **Les questions d'essai, une par grande famille de matières.** La réponse juste est
/// toujours la première des options ; l'ordre d'affichage la place ailleurs.
///
/// Les réponses chiffrées ou symboliques ne se traduisent pas (« π × r² », « H₂O », « 46 »,
/// « 1989 ») ; seules celles de philosophie (des noms propres) ont leur clé, pour leur
/// écriture dans chaque alphabet.
enum SampleCard: String, CaseIterable {
    case math
    case chemistry
    case biology
    case history
    case philosophy

    /// La matière du catalogue qui porte la question quand l'élève n'en a coché aucune qui
    /// lui corresponde.
    var catalogSubject: String {
        switch self {
        case .math: "Mathématiques"
        case .chemistry: "Chimie"
        case .biology: "SVT"
        case .history: "Histoire"
        case .philosophy: "Philosophie"
        }
    }

    /// La question. Celle d'histoire est la question du mur de Berlin que l'app pose déjà dans
    /// ses 26 langues.
    var questionKey: String {
        self == .history ? "ios.onb.mika.design.question" : "ios.onb7.card.\(rawValue).q"
    }

    /// Les options, la juste en premier.
    private var options: [String] {
        switch self {
        case .math: ["π × r²", "2 × π × r", "π × r"]
        case .chemistry: ["H₂O", "CO₂", "H₂O₂"]
        case .biology: ["46", "23", "48"]
        case .history: ["1989", "1961", "1991"]
        case .philosophy: ["ios.onb7.card.philosophy.a1", "ios.onb7.card.philosophy.a2", "ios.onb7.card.philosophy.a3"]
        }
    }

    /// L'ordre dans lequel les trois options s'affichent : la bonne n'est jamais en tête.
    var displayOrder: [Int] {
        switch self {
        case .math, .history: [1, 0, 2]
        case .chemistry, .philosophy: [2, 0, 1]
        case .biology: [1, 2, 0]
        }
    }

    func isRight(_ option: Int) -> Bool { option == 0 }

    func option(_ index: Int, locale: UiLocale) -> String {
        let value = options[index]
        return value.hasPrefix("ios.") ? L10n.t(value, locale: locale) : value
    }

    /// La question d'une matière, d'après l'emoji que l'app lui donne (`CourseEmoji`) : la
    /// même table que les cours importés, qui connaît les noms dans les langues des systèmes
    /// scolaires décrits.
    static func card(forEmoji emoji: String) -> SampleCard? {
        switch emoji {
        case "📐", "📊": .math
        case "🧪", "⚛️", "🔬", "🔭": .chemistry
        case "🧬", "🌿", "🫀", "🩺", "💊", "🥗", "🦴", "🏥": .biology
        case "🏛️", "🗺️", "🌍", "🗳️": .history
        case "🤔", "👥", "🧠": .philosophy
        default: nil
        }
    }

    struct Pick: Equatable {
        let card: SampleCard
        /// La matière affichée sur la pastille : celle de l'élève, ou celle du catalogue.
        let subject: String
        let emoji: String
    }

    /// **La question d'une matière que l'élève a cochée**, dans l'ordre alphabétique pour que
    /// le choix ne change pas d'un affichage à l'autre. Aucune ne correspond (des langues
    /// vivantes, une matière que la table ne connaît pas) : la question d'histoire, présentée
    /// comme de la culture générale — jamais une matière qu'il n'a pas choisie.
    static func pick(for subjects: Set<String>) -> Pick {
        for subject in subjects.sorted() {
            let emoji = SubjectCatalog.emoji(for: subject)
            if let card = card(forEmoji: emoji) {
                return Pick(card: card, subject: subject, emoji: emoji)
            }
        }
        let general = "Culture générale"
        return Pick(card: .history, subject: general, emoji: SubjectCatalog.emoji(for: general))
    }
}
