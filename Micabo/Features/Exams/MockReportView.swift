import SwiftUI

/// Le débriefing : **ce que la copie dit, pas seulement ce qu'elle vaut.**
///
/// Un score seul ne sert à rien. Ce qui sert est le motif - trois erreurs sur le même
/// chapitre, une notion comprise mais mal nommée - et c'est ce que le modèle est chargé de
/// lire. La liste question par question reste en dessous, dépliée : l'étudiant vient de passer
/// un quart d'heure dessus, il a le droit de voir sur quoi il s'est trompé.
///
/// L'ordre compte : la phrase d'abord, le score ensuite, le détail à la fin. Un grand chiffre
/// en tête d'écran est ce qu'on retient, et « 54 % » n'apprend rien à personne.
struct MockReportView: View {
    let session: MockSessionRecord
    let examName: String
    var onDone: () -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    private func t(_ key: String, _ vars: [String: String] = [:]) -> String {
        i18n?.t(key, vars) ?? L10n.t(key, locale: .resolved(), vars: vars)
    }

    private var score: Int { session.score }

    private var answerByID: [String: MockAnswer] {
        Dictionary(session.answers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var gradeByID: [String: MockGrade] {
        Dictionary(session.grades.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private var missedCount: Int {
        session.questions.filter { (gradeByID[$0.id]?.score ?? 0) < MockPaper.passMark }.count
    }

    private var tone: Color {
        score >= 75 ? MicaboColor.positive : score >= 50 ? MicaboColor.caution : MicaboColor.negative
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                headline
                if let debrief = session.debrief, !debrief.isEmpty {
                    debriefPanels(debrief)
                }
                detail
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.md)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .navigationTitle(examName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(t("app.mock.seeExam")) { onDone() }
                    .fontWeight(.semibold)
            }
        }
    }

    // MARK: - La phrase, puis le chiffre

    private var headline: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            Text(t("app.mock.doneEyebrow").uppercased())
                .font(MicaboFont.hanken(11.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(MicaboColor.inkTertiary)

            if let line = session.debrief?.headline.nilIfBlank {
                Text(line)
                    .font(MicaboFont.hanken(21, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(score)")
                        .font(MicaboFont.number(40, weight: .bold))
                        .monospacedDigit()
                    Text("%")
                        .font(MicaboFont.hanken(20, weight: .semibold))
                }
                .foregroundStyle(tone)

                Text(t("app.mock.outOf", [
                    "correct": "\(session.questions.count - missedCount)",
                    "total": "\(session.questions.count)",
                ]))
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
            }
        }
    }

    @ViewBuilder
    private func debriefPanels(_ debrief: MockDebrief) -> some View {
        if !debrief.strengths.isEmpty {
            panel(title: t("app.mock.strengths"), tint: MicaboColor.positive, items: debrief.strengths)
        }
        if !debrief.gaps.isEmpty {
            panel(title: t("app.mock.gaps"), tint: MicaboColor.caution, items: debrief.gaps)
        }
        if let advice = debrief.advice.nilIfBlank {
            VStack(alignment: .leading, spacing: 6) {
                Text(t("app.mock.advice"))
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
                Text(advice)
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(MicaboSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }

    private func panel(title: String, tint: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(title)
                    .font(MicaboFont.captionEmphasis)
                    .foregroundStyle(MicaboColor.ink)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    // MARK: - Question par question

    private var detail: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("app.mock.detail"))
            ForEach(Array(session.questions.enumerated()), id: \.element.id) { index, question in
                correction(question, position: index + 1)
            }
        }
    }

    private func correction(_ question: MockQuestion, position: Int) -> some View {
        let grade = gradeByID[question.id]
        let value = grade?.score ?? 0
        let good = value >= MockPaper.passMark
        let partial = value > 0 && !good
        let answer = answerByID[question.id]
        let said = MockPaper.said(question, answer: answer, blank: t("app.mock.blank"), yes: t("app.mock.true"), no: t("app.mock.false"))

        return VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.sm) {
                Text("\(position)")
                    .font(MicaboFont.number(12.5, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .frame(width: 18, alignment: .leading)
                Text(displayPrompt(question))
                    .font(MicaboFont.hanken(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: MicaboSpacing.xs)
                MicaboBadge(
                    text: question.isClosed ? (good ? t("app.mock.right") : t("app.mock.wrong")) : "\(value) %",
                    tone: good ? .positive : partial ? .warm : .neutral
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                line(label: t("app.mock.yourAnswer"), value: said, tint: good ? MicaboColor.ink : MicaboColor.negative)
                if !good, question.isClosed,
                   let expected = MockPaper.expected(question, yes: t("app.mock.true"), no: t("app.mock.false")) {
                    line(label: t("app.mock.rightAnswer"), value: expected, tint: MicaboColor.ink)
                }
            }
            .padding(.leading, 18 + MicaboSpacing.sm)

            if let comment = grade?.comment?.nilIfBlank {
                Text(comment)
                    .font(MicaboFont.caption)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
                    .padding(.leading, 18 + MicaboSpacing.sm)
            }
        }
        .padding(MicaboSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
        .overlay {
            if !good {
                RoundedRectangle(cornerRadius: MicaboRadius.group, style: .continuous)
                    .strokeBorder(MicaboColor.negative.opacity(0.3), lineWidth: 1)
            }
        }
    }

    private func line(label: String, value: String, tint: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
            Text(value)
                .font(MicaboFont.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func displayPrompt(_ question: MockQuestion) -> String {
        if case .gap = question {
            return question.prompt.replacingOccurrences(of: MockQuestion.gapMark, with: " ____ ")
        }
        return question.prompt
    }
}
