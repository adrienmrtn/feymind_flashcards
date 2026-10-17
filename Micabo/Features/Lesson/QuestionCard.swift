import SwiftUI

/// Ce que l'élève a répondu à une question.
struct QuizAnswer: Equatable {
    var right: Bool
    /// Pour un QCM, un vrai/faux ou une phrase à trou : le rang choisi, dans l'ordre affiché.
    var picked: Int?
}

/// **Une question, quelle que soit sa forme** : QCM, vrai/faux, phrase à trou, remise en
/// ordre, association. Voir `QuizKind`.
///
/// Les propositions se mélangent à l'affichage, selon `shuffleSeed` : une question qui revient
/// ne présente pas sa bonne réponse au même rang, et l'élève apprend la réponse, pas sa place.
/// La même graine redonne le même ordre : une question relue se relit pareil.
struct QuestionCard: View {
    let question: QuizQuestion
    let tone: LessonTone
    var answered: QuizAnswer?
    var shuffleSeed: UInt64 = 0
    /// Faux dans un quiz : le retour passe dans le panneau du bas, à la Duolingo.
    var showsFeedback = true
    /// Faux dans un examen blanc : la réponse choisie se surligne, sans dire si elle est
    /// juste. Le corrigé vient à la fin de l'épreuve.
    var reveals = true
    let onAnswer: (QuizAnswer) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            kindLabel
            switch question.kind {
            case .choice:
                prompt(question.prompt)
                ChoiceList(question: question, tone: tone, answered: answered, seed: shuffleSeed, reveals: reveals, onAnswer: onAnswer)
            case .gap:
                GapSentence(question: question, tone: tone, answered: reveals ? answered : nil, order: ChoiceList.order(of: question, seed: shuffleSeed))
                ChoiceList(question: question, tone: tone, answered: answered, seed: shuffleSeed, compact: true, reveals: reveals, onAnswer: onAnswer)
            case .truefalse:
                prompt(question.prompt)
                TrueFalseButtons(question: question, answered: answered, reveals: reveals, onAnswer: onAnswer)
            case .order:
                prompt(question.prompt)
                OrderBuilder(question: question, tone: tone, answered: answered, seed: shuffleSeed, reveals: reveals, onAnswer: onAnswer)
            case .match:
                prompt(question.prompt)
                MatchBoard(question: question, tone: tone, answered: answered, seed: shuffleSeed, reveals: reveals, onAnswer: onAnswer)
            }

            if showsFeedback, reveals, let answered {
                QuestionFeedback(question: question, right: answered.right)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(duration: 0.35), value: answered)
    }

    /// Ce qu'on attend de l'élève, en petit, au-dessus : « Vrai ou faux ? », « Remets dans
    /// l'ordre »…
    private var kindLabel: some View {
        Text(L10n.t(Self.labelKey(question.kind), locale: .resolved()))
            .font(MicaboFont.ui(13, weight: .heavy))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(tone.ink)
    }

    static func labelKey(_ kind: QuizKind) -> String {
        switch kind {
        case .choice: "lesson.question.kind.choice"
        case .truefalse: "lesson.question.kind.truefalse"
        case .gap: "lesson.question.kind.gap"
        case .order: "lesson.question.kind.order"
        case .match: "lesson.question.kind.match"
        }
    }

    private func prompt(_ text: String) -> some View {
        KeywordText(text, size: 22, weight: .heavy)
            .font(MicaboFont.ui(22, weight: .heavy))
            .foregroundStyle(MicaboColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Le retour

/// Juste ou faux, Mika réagit, et la phrase qui explique.
struct QuestionFeedback: View {
    let question: QuizQuestion
    let right: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MikaMascot(mood: right ? .happy : .sad, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(right
                    ? L10n.t("lesson.question.right", locale: .resolved())
                    : L10n.t("lesson.question.wrong", locale: .resolved()))
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(right ? MicaboColor.correctInk : MicaboColor.wrongInk)
                if !right, question.kind == .order || question.kind == .match {
                    KeywordText(question.answerText, size: 15, weight: .bold, tintsKeywords: false)
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !question.why.isEmpty {
                    KeywordText(question.why, size: 15, weight: .medium)
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(right ? MicaboColor.correctSoft : MicaboColor.wrongSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - QCM et phrase à trou

/// **Les propositions**, mélangées. La bonne passe au vert, une mauvaise au rouge.
struct ChoiceList: View {
    let question: QuizQuestion
    let tone: LessonTone
    let answered: QuizAnswer?
    let seed: UInt64
    var compact = false
    var reveals = true
    let onAnswer: (QuizAnswer) -> Void

    /// L'ordre d'affichage : `order[i]` est le rang, dans `choices`, de la proposition montrée
    /// en `i`.
    static func order(of question: QuizQuestion, seed: UInt64) -> [Int] {
        guard seed != 0 else { return Array(question.choices.indices) }
        var generator = SeededGenerator(seed: seed ^ LessonPicking.seed(question.id))
        return Array(question.choices.indices).shuffled(using: &generator)
    }

    var body: some View {
        let order = Self.order(of: question, seed: seed)
        let layout = compact
            ? AnyLayout(MicaboFlowLayout(spacing: 10, lineSpacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))
        layout {
            ForEach(Array(order.enumerated()), id: \.offset) { shown, original in
                Button {
                    guard answered == nil else { return }
                    onAnswer(QuizAnswer(right: original == question.answer, picked: shown))
                } label: {
                    HStack(spacing: 12) {
                        KeywordText(question.choices[original], size: compact ? 18 : 17, weight: .bold, tintsKeywords: false)
                            .font(MicaboFont.ui(compact ? 18 : 17, weight: .bold))
                            .foregroundStyle(foreground(shown: shown, original: original))
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        if !compact { Spacer(minLength: 0) }
                        if let symbol = symbol(shown: shown, original: original) {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .black))
                                .foregroundStyle(foreground(shown: shown, original: original))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, compact ? 12 : 15)
                    .frame(maxWidth: compact ? nil : .infinity, alignment: .leading)
                    .background(background(shown: shown, original: original), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(border(shown: shown, original: original), lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(answered == nil ? MicaboColor.stroke : .clear)
                            .offset(y: 3)
                    )
                    .scaleEffect(isPicked(shown) ? 1.02 : 1)
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                .disabled(answered != nil)
                .modifier(Shake(amount: reveals && isPicked(shown) && answered?.right == false ? 1 : 0))
                .animation(.linear(duration: 0.4), value: answered)
            }
        }
    }

    private func isPicked(_ shown: Int) -> Bool { answered?.picked == shown }

    private func background(shown: Int, original: Int) -> Color {
        guard answered != nil else { return MicaboColor.surface }
        guard reveals else { return isPicked(shown) ? MicaboColor.accentSoft : MicaboColor.surface }
        if original == question.answer { return MicaboColor.correct }
        if isPicked(shown) { return MicaboColor.wrong }
        return MicaboColor.surface
    }

    private func foreground(shown: Int, original: Int) -> Color {
        guard answered != nil else { return MicaboColor.ink }
        guard reveals else { return isPicked(shown) ? MicaboColor.accent : MicaboColor.inkSecondary }
        if original == question.answer || isPicked(shown) { return MicaboColor.onInk }
        return MicaboColor.inkTertiary
    }

    private func border(shown: Int, original: Int) -> Color {
        guard answered != nil else { return MicaboColor.stroke }
        guard reveals else { return isPicked(shown) ? MicaboColor.accent : MicaboColor.stroke }
        return .clear
    }

    private func symbol(shown: Int, original: Int) -> String? {
        guard answered != nil else { return nil }
        guard reveals else { return isPicked(shown) ? "circle.inset.filled" : nil }
        if original == question.answer { return "checkmark" }
        if isPicked(shown) { return "xmark" }
        return nil
    }
}

/// **La phrase à trou** : le trou en pointillés tant qu'on n'a pas répondu, puis le bon mot,
/// en vert, à sa place.
struct GapSentence: View {
    let question: QuizQuestion
    let tone: LessonTone
    let answered: QuizAnswer?
    let order: [Int]

    var body: some View {
        let parts = question.prompt.components(separatedBy: ClozeGap.marker)
        let word = question.choices.indices.contains(question.answer) ? question.choices[question.answer] : ""
        let filled = answered != nil
        var text = KeywordText.attributed(parts.first ?? "", size: 22, weight: .heavy)
        var blank = AttributedString(filled ? " \(KeywordText.plain(word)) " : " ________ ")
        blank.foregroundColor = filled ? MicaboColor.correctInk : tone.ink
        blank.backgroundColor = filled ? MicaboColor.correctSoft : tone.pale
        text.append(blank)
        if parts.count > 1 {
            text.append(KeywordText.attributed(parts.dropFirst().joined(separator: ClozeGap.marker), size: 22, weight: .heavy))
        }
        return Text(text)
            .font(MicaboFont.ui(22, weight: .heavy))
            .foregroundStyle(MicaboColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.spring(duration: 0.4), value: filled)
    }
}

// MARK: - Vrai ou faux

/// Deux grands boutons côte à côte, dans l'ordre « vrai, faux » : on ne mélange pas ce que
/// tout le monde attend à sa place.
struct TrueFalseButtons: View {
    let question: QuizQuestion
    let answered: QuizAnswer?
    var reveals = true
    let onAnswer: (QuizAnswer) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Array(question.choices.prefix(2).enumerated()), id: \.offset) { index, label in
                Button {
                    guard answered == nil else { return }
                    onAnswer(QuizAnswer(right: index == question.answer, picked: index))
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: index == 0 ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 34, weight: .bold))
                        Text(label)
                            .font(MicaboFont.ui(19, weight: .heavy))
                    }
                    .foregroundStyle(foreground(index))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .background(background(index), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(answered == nil ? MicaboColor.stroke : .clear, lineWidth: 2))
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(answered == nil ? MicaboColor.stroke : .clear)
                            .offset(y: 4)
                    )
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                .disabled(answered != nil)
                .modifier(Shake(amount: reveals && answered?.picked == index && answered?.right == false ? 1 : 0))
                .animation(.linear(duration: 0.4), value: answered)
            }
        }
    }

    private func background(_ index: Int) -> Color {
        guard let answered else { return MicaboColor.surface }
        guard reveals else { return answered.picked == index ? MicaboColor.accentSoft : MicaboColor.surface }
        if index == question.answer { return MicaboColor.correct }
        if answered.picked == index { return MicaboColor.wrong }
        return MicaboColor.surface
    }

    private func foreground(_ index: Int) -> Color {
        guard let answered else { return index == 0 ? MicaboColor.correctInk : MicaboColor.wrongInk }
        guard reveals else { return answered.picked == index ? MicaboColor.accent : MicaboColor.inkTertiary }
        if index == question.answer || answered.picked == index { return MicaboColor.onInk }
        return MicaboColor.inkTertiary
    }
}

// MARK: - Remettre dans l'ordre

/// **Remettre dans l'ordre** : on touche les éléments dans l'ordre voulu ; ils montent dans
/// la réponse, numérotés. Un appui sur un élément placé le renvoie. « Valider » quand tout est
/// placé ; on voit ensuite chaque place, juste ou fausse.
struct OrderBuilder: View {
    let question: QuizQuestion
    let tone: LessonTone
    let answered: QuizAnswer?
    let seed: UInt64
    var reveals = true
    let onAnswer: (QuizAnswer) -> Void

    @State private var placed: [Int] = []
    @Namespace private var namespace

    /// Le mélange de départ, jamais dans le bon ordre.
    private var pool: [Int] {
        var generator = SeededGenerator(seed: seed == 0 ? 7 : seed)
        var order = Array(question.choices.indices).shuffled(using: &generator)
        if order == Array(question.choices.indices), order.count > 1 { order.swapAt(0, 1) }
        return order
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 8) {
                ForEach(Array(placed.enumerated()), id: \.element) { position, item in
                    Button {
                        guard answered == nil else { return }
                        Haptics.selection()
                        withAnimation(.spring(duration: 0.35)) { placed.removeAll { $0 == item } }
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(position + 1)")
                                .font(MicaboFont.number(17))
                                .foregroundStyle(MicaboColor.onInk)
                                .frame(width: 30, height: 30)
                                .background(numberColor(position: position, item: item), in: Circle())
                            KeywordText(question.choices[item], size: 17, weight: .bold, tintsKeywords: false)
                                .font(MicaboFont.ui(17, weight: .bold))
                                .foregroundStyle(MicaboColor.ink)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(rowBorder(position: position, item: item), lineWidth: 2))
                        .matchedGeometryEffect(id: item, in: namespace)
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                    .disabled(answered != nil)
                }
                ForEach(placed.count..<question.choices.count, id: \.self) { slot in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(MicaboColor.stroke, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        .frame(height: 54)
                        .overlay(alignment: .leading) {
                            Text("\(slot + 1)")
                                .font(MicaboFont.number(17))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .padding(.leading, 22)
                        }
                }
            }

            if answered == nil {
                MicaboFlowLayout(spacing: 10, lineSpacing: 10) {
                    ForEach(pool.filter { !placed.contains($0) }, id: \.self) { item in
                        Button {
                            Haptics.selection()
                            withAnimation(.spring(duration: 0.35)) { placed.append(item) }
                        } label: {
                            KeywordText(question.choices[item], size: 16, weight: .bold, tintsKeywords: false)
                                .font(MicaboFont.ui(16, weight: .bold))
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(MicaboColor.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 11)
                                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 2))
                                .matchedGeometryEffect(id: item, in: namespace)
                        }
                        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                    }
                }

                Button(L10n.t("lesson.question.check", locale: .resolved())) {
                    onAnswer(QuizAnswer(right: placed == Array(question.choices.indices), picked: nil))
                }
                .buttonStyle(LessonPrimaryButtonStyle(enabled: placed.count == question.choices.count))
                .disabled(placed.count != question.choices.count)
            }
        }
        .onAppear {
            // Relue après coup, la question montre l'ordre juste.
            if answered != nil, placed.isEmpty, reveals { placed = Array(question.choices.indices) }
        }
    }

    private func numberColor(position: Int, item: Int) -> Color {
        guard answered != nil, reveals else { return tone.vivid }
        return item == position ? MicaboColor.correct : MicaboColor.wrong
    }

    private func rowBorder(position: Int, item: Int) -> Color {
        guard answered != nil else { return MicaboColor.stroke }
        guard reveals else { return MicaboColor.accent }
        return item == position ? MicaboColor.correct : MicaboColor.wrong
    }
}

// MARK: - Associer

/// **Associer** : un terme à gauche, puis sa définition à droite. Chaque paire prend sa
/// couleur. Quand tout est associé, la réponse tombe : chaque paire juste en vert, chaque
/// fausse en rouge, et le corrigé dans le retour.
struct MatchBoard: View {
    let question: QuizQuestion
    let tone: LessonTone
    let answered: QuizAnswer?
    let seed: UInt64
    var reveals = true
    let onAnswer: (QuizAnswer) -> Void

    /// Terme (rang dans `choices`) → définition (rang dans `matches`).
    @State private var pairs: [Int: Int] = [:]
    @State private var selectedLeft: Int?

    private static let pairColors: [Color] = LessonTone.allCases.map(\.vivid)

    private var rightOrder: [Int] {
        var generator = SeededGenerator(seed: (seed == 0 ? 11 : seed) &+ 3)
        var order = Array(question.matches.indices).shuffled(using: &generator)
        if order == Array(question.matches.indices), order.count > 1 { order.swapAt(0, 1) }
        return order
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                ForEach(Array(question.choices.indices), id: \.self) { left in
                    tile(question.choices[left], color: color(left: left), selected: selectedLeft == left, verdict: verdict(left: left)) {
                        guard answered == nil else { return }
                        Haptics.selection()
                        if pairs[left] != nil {
                            pairs[left] = nil
                        }
                        selectedLeft = selectedLeft == left ? nil : left
                    }
                }
            }
            VStack(spacing: 10) {
                ForEach(rightOrder, id: \.self) { right in
                    let owner = pairs.first { $0.value == right }?.key
                    tile(question.matches[right], color: owner.map(color(left:)) ?? nil, selected: false, verdict: owner.flatMap(verdict(left:))) {
                        guard answered == nil, let left = selectedLeft else { return }
                        Haptics.selection()
                        withAnimation(.spring(duration: 0.3)) {
                            if let owner { pairs[owner] = nil }
                            pairs[left] = right
                            selectedLeft = nil
                        }
                        if pairs.count == question.choices.count {
                            let right = pairs.allSatisfy { $0.key == $0.value }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onAnswer(QuizAnswer(right: right, picked: nil))
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if answered != nil, pairs.isEmpty, reveals {
                pairs = Dictionary(uniqueKeysWithValues: question.choices.indices.map { ($0, $0) })
            }
        }
    }

    private func color(left: Int) -> Color? {
        guard pairs[left] != nil || selectedLeft == left else { return nil }
        return Self.pairColors[left % Self.pairColors.count]
    }

    /// Après la réponse : la paire est-elle juste ?
    private func verdict(left: Int) -> Bool? {
        guard answered != nil, reveals, let right = pairs[left] else { return nil }
        return right == left
    }

    private func tile(_ text: String, color: Color?, selected: Bool, verdict: Bool?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            KeywordText(text, size: 15, weight: .bold, tintsKeywords: false)
                .font(MicaboFont.ui(15, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(fill(color: color, verdict: verdict), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(stroke(color: color, selected: selected, verdict: verdict), lineWidth: selected ? 3 : 2)
                )
                .scaleEffect(selected ? 1.03 : 1)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
        .disabled(answered != nil)
        .animation(.spring(duration: 0.25), value: selected)
    }

    private func fill(color: Color?, verdict: Bool?) -> Color {
        if let verdict { return verdict ? MicaboColor.correctSoft : MicaboColor.wrongSoft }
        return color.map { $0.opacity(0.16) } ?? MicaboColor.surface
    }

    private func stroke(color: Color?, selected: Bool, verdict: Bool?) -> Color {
        if let verdict { return verdict ? MicaboColor.correct : MicaboColor.wrong }
        return color ?? MicaboColor.stroke
    }
}
