import SwiftUI

// MARK: - La question d'essai

/// **Une vraie question, sur sa matière** : « À toi ! Une question comme dans tes leçons. »
///
/// Jusqu'ici, le parcours *disait* ce que fait l'app ; ici l'élève le *fait* : une question
/// comme celles de ses leçons, dans une matière qu'il a cochée, trois réponses à toucher. Il
/// répond, la bonne s'allume en vert (et la sienne en rouge s'il s'est trompé), Mika réagit
/// dans sa bulle, et **la recherche dit pourquoi ça marche** : une semaine après, on retient
/// 80 % d'un cours en se testant, contre 36 % en le relisant (Karpicke & Roediger, Science,
/// 2008). C'est la seule étude citée du parcours, et elle tombe au moment où elle se comprend.
///
/// **Rien ne part au serveur.** Les questions sont écrites d'avance dans toutes les langues
/// (`SampleCard`), avec des réponses qui se lisent partout (« π × r² », « H₂O », « 1989 »).
/// Le bouton s'allume une fois la réponse donnée.
struct SampleCardStepView: View {
    /// Une réponse déjà donnée, pour les rendus.
    var previewAnswer: Int?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var answer: Int?
    /// L'XP réellement gagnée par la bonne réponse : rien tant qu'elle n'est pas donnée.
    @State private var earned: Int?

    private var chosen: Int? {
        answer ?? previewAnswer
    }

    private var pick: SampleCard.Pick {
        SampleCard.pick(for: model.demoSubjects)
    }

    /// Ce que Mika dit : la consigne, puis sa réaction à la réponse.
    private var say: OnbSay {
        guard let chosen else { return OnbSay(i18n.t("ios.onb12.card.say"), mood: .wink) }
        return pick.card.isRight(chosen)
            ? OnbSay(i18n.t("ios.onb10.card.right"), mood: .celebrate)
            : OnbSay(i18n.t("ios.onb10.card.wrong"), mood: .happy)
    }

    /// Le gain montré : celui crédité, ou, dans un rendu, celui d'une bonne réponse.
    private var shownPoints: Int? {
        if let earned { return earned }
        return previewAnswer.map(pick.card.isRight) == true ? XPReason.correctAnswer.points : nil
    }

    var body: some View {
        OnbQuestion(i18n.t("ios.onb12.q.card"), say: say) {
            VStack(alignment: .leading, spacing: 14) {
                // Le gain d'XP se pose par-dessus la ligne de la matière : rien ne bouge dessous.
                subjectPill
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .trailing) {
                        if let points = shownPoints {
                            OnbXPPill(points: points)
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        }
                    }

                Text(i18n.t(pick.card.questionKey))
                    .font(V3Font.h2)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: OnbLayout.rowGap) {
                    ForEach(pick.card.displayOrder, id: \.self) { option in
                        answerRow(option)
                    }
                }

                if chosen != nil {
                    proof
                        .transition(.opacity)
                }
            }
            .animation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: UIAccessibility.isReduceMotionEnabled), value: chosen)
        } footer: {
            V3Button(i18n.t("common.continue"), isEnabled: chosen != nil) {
                model.advance()
            }
        }
        .overlay {
            OnbConfetti(isOn: answer.map(pick.card.isRight) == true)
        }
    }

    /// La matière de la question : une de celles que l'élève a cochées.
    private var subjectPill: some View {
        Text(SubjectDisplay.subject(pick.subject, locale: i18n.locale))
            .font(V3Font.caption)
            .foregroundStyle(V3Color.accent)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(V3Color.accentWash, in: Capsule())
    }

    // MARK: Les réponses

    private enum Look: Equatable {
        case open
        case right
        case wrong
        case dimmed
    }

    private func look(of option: Int) -> Look {
        guard let chosen else { return .open }
        if pick.card.isRight(option) { return .right }
        return option == chosen ? .wrong : .dimmed
    }

    /// Une réponse : elle s'allume en vert quand c'est la bonne, en rouge quand c'est celle,
    /// fausse, qu'on a touchée. Les autres s'effacent à moitié.
    private func answerRow(_ option: Int) -> some View {
        let state = look(of: option)
        return Button {
            choose(option)
        } label: {
            HStack(spacing: 12) {
                Text(pick.card.option(option, locale: i18n.locale))
                    .font(V3Font.bodyStrong)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if state == .right {
                    Image(systemName: "checkmark.circle.fill")
                        .font(V3Font.title)
                        .foregroundStyle(V3Color.green)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .font(V3Font.title)
                        .foregroundStyle(V3Color.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .v3Card(tone: Self.tone(of: state))
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
        .disabled(chosen != nil)
        .accessibilityAddTraits(state == .right || state == .wrong ? [.isSelected] : [])
    }

    private static func tone(of look: Look) -> Color? {
        switch look {
        case .right: V3Color.green
        case .wrong: V3Color.red
        default: nil
        }
    }

    private func choose(_ option: Int) {
        guard chosen == nil else { return }
        answer = option
        let right = pick.card.isRight(option)
        if right {
            Haptics.success()
            // **L'XP est réelle** : la bonne réponse est créditée comme dans une leçon, et la
            // pastille montre ce qui a été ajouté au total du jour.
            let award = XPStore.shared.award(.correctAnswer, celebrates: false)
            earned = award.added > 0 ? award.added : nil
        } else {
            Haptics.warning()
        }
        Analytics.track(.onboardingAnswer, [
            "field": "sampleCard",
            "value": .text(right ? "right" : "wrong"),
        ])
    }

    // MARK: La preuve

    /// **Pourquoi se tester**, une fois, sourcé.
    private var proof: some View {
        HStack(alignment: .top, spacing: 10) {
            OnbIcon(icon: .diploma, size: 24)

            VStack(alignment: .leading, spacing: 4) {
                OnbPhrase.marked(
                    i18n.t("ios.onb7.card.proof", [
                        "testing": L10n.percent(SampleCard.retainedByTesting, locale: i18n.locale),
                        "reread": L10n.percent(SampleCard.retainedByRereading, locale: i18n.locale),
                    ]),
                    keyword: V3Color.ink
                )
                .font(V3Font.support)
                .foregroundStyle(V3Color.ink2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Text(i18n.t("ios.journey.source"))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink3)
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
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

    /// **La seule étude du parcours** : ce qu'il reste d'un cours une semaine après, en se
    /// testant et en le relisant, en pourcentage. Karpicke & Roediger, Science, 2008.
    static let retainedByTesting = 80
    static let retainedByRereading = 36

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

    /// La question. Celle d'histoire est la question du mur de Berlin, déjà écrite dans
    /// toutes les langues.
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
    /// comme de la culture générale, jamais comme une matière qu'il n'a pas choisie.
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
