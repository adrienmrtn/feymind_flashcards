import SwiftData
import SwiftUI

/// **Une étape Notes, en écrans courts** : l'idée du thème, puis un écran par bloc, « À
/// retenir », et la question de fin. Les segments du haut se remplissent à mesure ; on avance
/// avec « Continuer » ou d'un glissé, on revient d'un glissé. L'étape se coche quand on a
/// répondu, bien ou mal.
///
/// Un ancien chapitre, sans notes au format de la refonte, se lit en un seul écran.
struct NotesCircleView: View {
    let session: LessonSession
    let chapter: Chapter
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var page = 0
    /// Le plus loin qu'on soit allé : on ne glisse pas au-delà sans avoir lu.
    @State private var furthest = 0
    @State private var answer: QuizAnswer?
    @State private var forward = true

    private var tone: LessonTone { session.course.tone }
    private var question: QuizQuestion? { chapter.quiz?.final }
    private var pages: [NotesPage] { NotesPage.pages(for: chapter, hasQuestion: question != nil) }

    var body: some View {
        let pages = pages
        let current = pages.indices.contains(page) ? pages[page] : .question
        VStack(spacing: 0) {
            NotesSegments(count: pages.count, page: page, tone: tone, onClose: leave, onBack: page > 0 ? back : nil)

            ZStack {
                NotesPageView(page: current, chapter: chapter, tone: tone, question: question, answer: answer) { result in
                    answered(result)
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < -50 { advanceIfAllowed() }
                        if value.translation.width > 50, page > 0 { back() }
                    }
            )

            bottomBar(current: current, isLast: page == pages.count - 1)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func bottomBar(current: NotesPage, isLast: Bool) -> some View {
        let waiting = current == .question && answer == nil
        VStack(spacing: 8) {
            if waiting {
                Text(L10n.t("lesson.notes.answerToFinish", locale: .resolved()))
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            Button(isLast
                ? L10n.t("lesson.notes.finishStep", locale: .resolved())
                : L10n.t("lesson.quiz.continue", locale: .resolved())) {
                if isLast { onDone() } else { next() }
            }
            .buttonStyle(LessonPrimaryButtonStyle(enabled: !waiting))
            .disabled(waiting)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(MicaboColor.canvas)
    }

    private func next() {
        guard page + 1 < pages.count else { return }
        Haptics.light()
        forward = true
        withAnimation(.spring(duration: 0.42, bounce: 0.15)) {
            page += 1
            furthest = max(furthest, page)
        }
    }

    private func advanceIfAllowed() {
        let current = pages.indices.contains(page) ? pages[page] : .question
        guard current != .question || answer != nil else { return }
        next()
    }

    private func back() {
        guard page > 0 else { return }
        Haptics.light()
        forward = false
        withAnimation(.spring(duration: 0.42, bounce: 0.15)) { page -= 1 }
    }

    private func answered(_ result: QuizAnswer) {
        guard let question else { return }
        answer = result
        result.right ? Haptics.success() : Haptics.warning()
        session.answered(question, right: result.right, in: modelContext)
    }

    private func leave() {
        // L'anneau de l'étape en cours dit où on s'est arrêté.
        let read = Double(furthest + 1) / Double(max(1, pages.count))
        session.setInCircle(read * (answer == nil ? 0.9 : 1), in: modelContext)
        dismiss()
    }
}

/// Un écran des notes.
enum NotesPage: Equatable {
    /// L'icône, le titre du thème et son idée en une phrase.
    case opening
    /// Des blocs des notes : un sous-titre et le bloc qu'il ouvre, ou un bloc seul.
    case blocks(Range<Int>)
    case takeaways
    /// Un ancien chapitre : toute sa fiche d'un coup.
    case legacy
    case question

    static func pages(for chapter: Chapter, hasQuestion: Bool) -> [NotesPage] {
        var pages: [NotesPage] = []
        if let notes = chapter.notes {
            pages.append(.opening)
            var index = 0
            while index < notes.blocks.count {
                var end = index + 1
                if case .subtitle = notes.blocks[index], end < notes.blocks.count { end += 1 }
                pages.append(.blocks(index..<end))
                index = end
            }
            if !notes.takeaways.isEmpty { pages.append(.takeaways) }
        } else {
            pages.append(.legacy)
        }
        if hasQuestion { pages.append(.question) }
        return pages
    }
}

/// **Les segments du haut**, un par écran : ceux qu'on a passés sont pleins, celui qu'on lit
/// se remplit en arrivant.
struct NotesSegments: View {
    let count: Int
    let page: Int
    let tone: LessonTone
    let onClose: () -> Void
    var onBack: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))

            HStack(spacing: 5) {
                ForEach(0..<max(1, count), id: \.self) { index in
                    NotesSegment(filled: index <= page, tone: tone)
                }
            }
            .frame(height: 8)

            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .frame(width: 32, height: 36)
                }
                .buttonStyle(MicaboPressableButtonStyle())
                .accessibilityLabel(Text(L10n.t("lesson.notes.back", locale: .resolved())))
                .transition(.opacity)
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .animation(.easeOut(duration: 0.2), value: onBack == nil)
    }
}

private struct NotesSegment: View {
    let filled: Bool
    let tone: LessonTone

    @State private var fill: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(MicaboColor.track)
                Capsule().fill(tone.vivid).frame(width: proxy.size.width * fill)
            }
        }
        .onAppear { fill = filled ? 1 : 0 }
        .onChange(of: filled) { _, value in
            withAnimation(.easeOut(duration: value ? 0.45 : 0.2)) { fill = value ? 1 : 0 }
        }
    }
}

/// **Le contenu d'un écran**, qui se remplit en arrivant : chaque élément glisse en place, un
/// peu après le précédent.
struct NotesPageView: View {
    let page: NotesPage
    let chapter: Chapter
    let tone: LessonTone
    let question: QuizQuestion?
    let answer: QuizAnswer?
    let onAnswer: (QuizAnswer) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch page {
                case .opening:
                    if let notes = chapter.notes {
                        VStack(alignment: .leading, spacing: 18) {
                            MicaboIconView(icon: chapter.icon, size: 96)
                                .reveal(0)
                            Text(chapter.title)
                                .font(MicaboFont.display(30))
                                .foregroundStyle(MicaboColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .reveal(1)
                            ToneBox(label: L10n.t("lesson.notes.oneLiner", locale: .resolved()), tone: tone) {
                                KeywordText(notes.oneLiner)
                                    .font(MicaboFont.ui(20, weight: .bold))
                                    .foregroundStyle(MicaboColor.ink)
                            }
                            .reveal(2)
                        }
                        .padding(.top, 20)
                    }
                case .blocks(let range):
                    if let notes = chapter.notes {
                        ForEach(Array(range.enumerated()), id: \.offset) { offset, index in
                            if notes.blocks.indices.contains(index) {
                                NoteBlockView(block: notes.blocks[index], tone: tone)
                                    .reveal(offset)
                            }
                        }
                        .padding(.top, 24)
                    }
                case .takeaways:
                    if let notes = chapter.notes {
                        VStack(alignment: .leading, spacing: 16) {
                            MicaboIconView(icon: .star, size: 72).reveal(0)
                            Text(L10n.t("lesson.notes.takeaways", locale: .resolved()))
                                .font(MicaboFont.display(28))
                                .foregroundStyle(MicaboColor.ink)
                                .reveal(1)
                            ForEach(Array(notes.takeaways.enumerated()), id: \.offset) { index, line in
                                HStack(alignment: .firstTextBaseline, spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(tone.vivid)
                                    KeywordText(line)
                                        .font(MicaboFont.ui(19, weight: .semibold))
                                        .foregroundStyle(MicaboColor.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .micaboElevation(.row)
                                .reveal(index + 2)
                            }
                        }
                        .padding(.top, 16)
                    }
                case .legacy:
                    ThemeHeader(chapter: chapter)
                    ThemeBody(chapter: chapter, tone: tone)
                case .question:
                    if let question {
                        QuestionCard(question: question, tone: tone, answered: answer, shuffleSeed: LessonPicking.seed(question.id, "notes"), onAnswer: onAnswer)
                            .padding(.top, 16)
                            .reveal(0)
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }
}

/// Un élément qui glisse en place à l'arrivée de l'écran, après ceux qui le précèdent.
private struct Reveal: ViewModifier {
    let order: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 16)
            .onAppear {
                withAnimation(.spring(duration: 0.5, bounce: 0.2).delay(reduceMotion ? 0 : 0.08 + Double(order) * 0.09)) {
                    shown = true
                }
            }
    }
}

extension View {
    func reveal(_ order: Int) -> some View {
        modifier(Reveal(order: order))
    }
}

/// Le titre d'un thème, son icône à gauche.
struct ThemeHeader: View {
    let chapter: Chapter

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            MicaboIconView(icon: chapter.icon, size: 52)
            Text(chapter.title)
                .font(MicaboFont.title)
                .foregroundStyle(MicaboColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Les notes d'un thème : au format de la refonte, sinon la fiche d'un ancien chapitre, avec
/// la même typographie.
struct ThemeBody: View {
    let chapter: Chapter
    let tone: LessonTone

    var body: some View {
        if let notes = chapter.notes {
            ThemeNotesView(notes: notes, tone: tone)
        } else if let sheet = chapter.decodedSheet() {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(Self.blocks(of: sheet, title: chapter.title).enumerated()), id: \.offset) { index, block in
                    SheetBlockView(block: block, tint: tone.ink)
                        .padding(.top, index == 0 ? 0 : SheetBlockView.spacing(before: block))
                }
            }
        } else {
            Text(L10n.t("lesson.notes.empty", locale: .resolved()))
                .font(MicaboFont.notes)
                .foregroundStyle(MicaboColor.inkSecondary)
        }
    }

    /// Les blocs d'un ancien chapitre, sans le titre qui l'ouvre : il est déjà en tête d'écran.
    static func blocks(of sheet: CourseSheet, title: String) -> [SheetBlock] {
        var blocks = sheet.blocks
        if case .heading(_, let text) = blocks.first,
           text.trimmingCharacters(in: .whitespaces).lowercased() == title.trimmingCharacters(in: .whitespaces).lowercased() {
            blocks.removeFirst()
        }
        return blocks
    }
}

/// **Toutes les notes de la leçon d'un coup**, pour relire avant un contrôle : les mêmes blocs
/// que les cercles Notes, thème après thème.
struct LessonNotesReader: View {
    let session: LessonSession

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    ForEach(session.course.orderedChapters) { chapter in
                        VStack(alignment: .leading, spacing: 18) {
                            ThemeHeader(chapter: chapter)
                            if chapter.status == .pending {
                                HStack(spacing: 10) {
                                    ProgressView()
                                    Text(L10n.t("lesson.notes.writing", locale: .resolved()))
                                        .font(MicaboFont.ui(15, weight: .bold))
                                        .foregroundStyle(MicaboColor.inkSecondary)
                                }
                            } else {
                                ThemeBody(chapter: chapter, tone: session.course.tone)
                            }
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, 20)
            }
            .background(MicaboColor.canvas.ignoresSafeArea())
            .lessonClock(session, activity: .notes)
            .navigationTitle(L10n.t("lesson.nav.notes", locale: .resolved()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
                }
            }
        }
    }
}
