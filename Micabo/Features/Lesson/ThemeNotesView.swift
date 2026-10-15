import SwiftUI

/// **Les notes d'un thème**, mises en page comme le brief les décrit (`docs/refonte-parcours.md`
/// § 6) : « En une phrase » dans la couleur de la leçon, des blocs courts, les blocs spéciaux
/// quand le contenu le demande, « À retenir » dans la couleur de la leçon.
///
/// Trois couleurs et pas plus : la couleur de la leçon pour les encadrés et les puces, le
/// violet pour les mots-clés, le vert et le rouge pour les réponses — et rien d'autre.
struct ThemeNotesView: View {
    let notes: ThemeNotes
    let tone: LessonTone

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ToneBox(label: L10n.t("lesson.notes.oneLiner", locale: .resolved()), tone: tone) {
                KeywordText(notes.oneLiner)
                    .font(MicaboFont.ui(18, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
            }

            ForEach(Array(notes.blocks.enumerated()), id: \.offset) { _, block in
                NoteBlockView(block: block, tone: tone)
            }

            if !notes.takeaways.isEmpty {
                ToneBox(label: L10n.t("lesson.notes.takeaways", locale: .resolved()), tone: tone) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(notes.takeaways.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(tone.ink)
                                KeywordText(line)
                                    .font(MicaboFont.notes)
                                    .foregroundStyle(MicaboColor.ink)
                            }
                        }
                    }
                }
            }
        }
    }
}

/// Un encadré dans la couleur de la leçon, avec son petit titre en capitales.
struct ToneBox<Content: View>: View {
    let label: String
    let tone: LessonTone
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(tone.ink)
            content
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Un bloc des notes.
struct NoteBlockView: View {
    let block: NoteBlock
    let tone: LessonTone

    @State private var definitionOpen = false

    var body: some View {
        switch block {
        case .subtitle(let text):
            HStack(spacing: 10) {
                Capsule().fill(tone.vivid).frame(width: 4, height: 20)
                Text(text)
                    .font(MicaboFont.subtitle)
                    .foregroundStyle(MicaboColor.ink)
            }
            .padding(.top, 6)

        case .paragraph(let text):
            KeywordText(text)
                .font(MicaboFont.notes)
                .foregroundStyle(MicaboColor.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

        case .list(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(tone.vivid)
                            .frame(width: 7, height: 7)
                            .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
                        KeywordText(item)
                            .font(MicaboFont.notes)
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

        case .definition(let term, let text):
            definition(term: term, text: text)

        case .dates(let items):
            DatesTimeline(items: items, tone: tone)

        case .formula(let latex, let caption):
            VStack(spacing: 8) {
                MathFormula(latex: latex, fontSize: 20, color: MicaboColor.ink)
                    .frame(maxWidth: .infinity)
                if let caption {
                    KeywordText(caption)
                        .font(MicaboFont.ui(15, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))

        case .example(let text):
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("lesson.notes.example", locale: .resolved()))
                    .font(MicaboFont.small)
                    .tracking(MicaboTracking.caps)
                    .textCase(.uppercase)
                    .foregroundStyle(MicaboColor.inkSecondary)
                KeywordText(text)
                    .font(MicaboFont.notes)
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    /// Une définition : le terme en violet, replié ; un appui l'ouvre.
    private func definition(term: String, text: String) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3)) { definitionOpen.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(L10n.t("lesson.notes.definition", locale: .resolved()))
                        .font(MicaboFont.small)
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(MicaboColor.inkSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MicaboColor.keyword)
                        .rotationEffect(.degrees(definitionOpen ? 180 : 0))
                }
                Text(term)
                    .font(MicaboFont.ui(19, weight: .heavy))
                    .foregroundStyle(MicaboColor.keyword)
                    .multilineTextAlignment(.leading)
                if definitionOpen {
                    KeywordText(text)
                        .font(MicaboFont.notes)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(MicaboColor.keyword.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}

/// Les dates clés, sur une frise qu'on fait glisser.
struct DatesTimeline: View {
    let items: [NoteBlock.DateItem]
    let tone: LessonTone

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            Circle().fill(tone.vivid).frame(width: 14, height: 14)
                            Rectangle()
                                .fill(index == items.count - 1 ? Color.clear : tone.vivid.opacity(0.5))
                                .frame(height: 3)
                        }
                        Text(item.date)
                            .font(MicaboFont.ui(17, weight: .heavy))
                            .foregroundStyle(tone.ink)
                        KeywordText(item.text)
                            .font(MicaboFont.ui(15, weight: .medium))
                            .foregroundStyle(MicaboColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: 130, alignment: .leading)
                    }
                    .frame(width: 150, alignment: .leading)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }
}

/// **Un texte des notes** : les mots-clés (`**mot**`) en gras violet, les formules en ligne
/// (`$…$`) en italique sans leurs dollars.
struct KeywordText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(Self.attributed(source))
    }

    static func attributed(_ source: String) -> AttributedString {
        var result = AttributedString()
        for (index, part) in source.components(separatedBy: "**").enumerated() where !part.isEmpty {
            let isKeyword = index % 2 == 1
            for (formulaIndex, piece) in part.components(separatedBy: "$").enumerated() where !piece.isEmpty {
                var chunk = AttributedString(piece)
                if isKeyword {
                    chunk.font = MicaboFont.keyword
                    chunk.foregroundColor = MicaboColor.keyword
                } else if formulaIndex % 2 == 1 {
                    chunk.font = MicaboFont.ui(17, weight: .medium).italic()
                }
                result += chunk
            }
        }
        return result
    }
}

// MARK: - La question de fin

/// **Un QCM** : quatre propositions ; la bonne passe au vert, une mauvaise au rouge avec la
/// phrase qui explique. Mika réagit.
struct QuestionCard: View {
    let question: QuizQuestion
    let tone: LessonTone
    /// Le choix déjà fait, quand la carte est relue.
    var answered: Int?
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(question.prompt)
                .font(MicaboFont.ui(20, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        guard answered == nil else { return }
                        onAnswer(index)
                    } label: {
                        HStack(spacing: 12) {
                            Text(choice)
                                .font(MicaboFont.ui(17, weight: .bold))
                                .foregroundStyle(foreground(for: index))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if let symbol = symbol(for: index) {
                                Image(systemName: symbol)
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(foreground(for: index))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(background(for: index), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(border(for: index), lineWidth: 2)
                        )
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
                    .disabled(answered != nil)
                }
            }

            if let answered {
                feedback(right: answered == question.answer)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(duration: 0.35), value: answered)
    }

    private func feedback(right: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            MikaMascot(mood: right ? .happy : .sad, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(right
                    ? L10n.t("lesson.question.right", locale: .resolved())
                    : L10n.t("lesson.question.wrong", locale: .resolved()))
                    .font(MicaboFont.ui(18, weight: .heavy))
                    .foregroundStyle(right ? MicaboColor.correctInk : MicaboColor.wrongInk)
                if !question.why.isEmpty, !right || question.why.count < 160 {
                    Text(question.why)
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

    private func isRight(_ index: Int) -> Bool { index == question.answer }

    private func background(for index: Int) -> Color {
        guard let answered else { return MicaboColor.surface }
        if isRight(index) { return MicaboColor.correct }
        if index == answered { return MicaboColor.wrong }
        return MicaboColor.surface
    }

    private func foreground(for index: Int) -> Color {
        guard let answered else { return MicaboColor.ink }
        if isRight(index) || index == answered { return MicaboColor.onInk }
        return MicaboColor.inkTertiary
    }

    private func border(for index: Int) -> Color {
        answered == nil ? MicaboColor.stroke : .clear
    }

    private func symbol(for index: Int) -> String? {
        guard let answered else { return nil }
        if isRight(index) { return "checkmark" }
        if index == answered { return "xmark" }
        return nil
    }
}
