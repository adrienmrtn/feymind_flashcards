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
    @Environment(\.layoutDirection) private var layoutDirection

    @State private var page = 0
    /// Le plus loin qu'on soit allé : on ne glisse pas au-delà sans avoir lu.
    @State private var furthest = 0
    @State private var answer: QuizAnswer?
    @State private var forward = true

    private var tone: LessonTone { session.course.tone }
    private var question: QuizQuestion? { chapter.quiz?.final }
    private var pages: [NotesPage] { NotesPage.pages(for: chapter, hasQuestion: question != nil) }

    var body: some View {
        let pages = self.pages
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
            // **Le glissé tourne la page, et seulement lui.** La page ne suit pas le doigt : elle
            // tourne quand le geste est fini, marges fixes, sans flotter. Un geste de travers ou
            // un défilement vertical ne la tourne pas : voir `NotesSwipe`.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .global)
                    .onEnded { value in
                        switch NotesSwipe.direction(
                            of: value.translation,
                            predicted: value.predictedEndTranslation,
                            rightToLeft: layoutDirection == .rightToLeft
                        ) {
                        case .forward: advanceIfAllowed()
                        case .back: back()
                        case nil: break
                        }
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

    /// Le glissé vers l'avant fait ce que fait « Continuer », sauf finir l'étape : la question
    /// de fin attend sa réponse, et la dernière page se quitte avec son bouton.
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

/// **Le glissé qui tourne une page de notes, et ceux qui ne la tournent pas.**
///
/// Le balayage avait été retiré parce qu'il tournait la page au moindre geste de travers :
/// cinquante points, et un geste à peine plus horizontal que vertical, suffisaient. Il revient
/// plus exigeant : le geste doit être nettement horizontal (`slant` fois plus large que haut),
/// et assez long, ou lancé assez vite. Un défilement vertical qui dérive un peu ne tourne rien.
///
/// Le geste est lu en coordonnées d'écran : en arabe ou en hébreu, la page suivante arrive par
/// la gauche, comme le reste de l'app, et c'est un glissé vers la droite qui l'amène.
enum NotesSwipe {
    enum Direction: Equatable { case forward, back }

    /// La longueur d'un glissé qui tourne la page.
    static let distance: CGFloat = 70
    /// La longueur où le geste, lancé, serait arrivé : un geste court mais vif tourne aussi.
    static let flick: CGFloat = 160
    /// De combien le geste doit être plus large que haut.
    static let slant: CGFloat = 2.2

    static func direction(of translation: CGSize, predicted: CGSize, rightToLeft: Bool = false) -> Direction? {
        let dx = translation.width
        guard abs(dx) > slant * abs(translation.height) else { return nil }
        let long = abs(dx) >= distance
        let flung = abs(dx) >= distance / 2 && abs(predicted.width) >= flick && predicted.width.sign == dx.sign
        guard long || flung else { return nil }
        let towardStart = rightToLeft ? dx < 0 : dx > 0
        return towardStart ? .back : .forward
    }
}

/// Un écran des notes.
enum NotesPage: Equatable {
    /// L'icône, le titre du thème et son idée en une phrase.
    case opening
    /// Des blocs des notes : un sous-titre et le bloc qu'il ouvre, ou un bloc seul ; un
    /// encadré qui suit un bloc reste avec lui, et un bloc seul partage son écran.
    case blocks(Range<Int>)
    case takeaways
    /// Un ancien chapitre : toute sa fiche d'un coup.
    case legacy
    case question

    /// Ce qu'un écran porte sans qu'il faille faire défiler, en mots pondérés (`weight`).
    static let screenWeight = 150
    /// En deçà, un bloc seul laisse l'écran à moitié vide : il accueille le suivant.
    static let thinWeight = 120

    static func pages(for chapter: Chapter, hasQuestion: Bool) -> [NotesPage] {
        var pages: [NotesPage] = []
        if let notes = chapter.notes {
            pages.append(.opening)
            pages += screens(of: notes.blocks).map { .blocks($0) }
            if !notes.takeaways.isEmpty { pages.append(.takeaways) }
        } else {
            pages.append(.legacy)
        }
        if hasQuestion { pages.append(.question) }
        return pages
    }

    /// **Les écrans des notes.** Un bloc par écran faisait des pages d'un paragraphe sur un
    /// fond vide, qui se lisaient comme un mur de texte sans rien autour. Un écran qui n'a
    /// qu'un bloc (le sous-titre qui l'ouvre ne compte pas) accueille donc le suivant, avec
    /// son sous-titre et son encadré, tant que le tout tient sans défiler. Et un bloc resté
    /// seul (le dernier du thème, ou trop long pour accueillir la suite) rejoint l'écran
    /// d'avant s'il y tient.
    ///
    /// Un encadré en tête de thème garde son écran : il annonce ce qui suit, il ne commente
    /// rien, et le noyer dans le bloc suivant lui ôterait sa raison d'être.
    static func screens(of blocks: [NoteBlock]) -> [Range<Int>] {
        var screens: [Range<Int>] = []
        var index = 0
        while index < blocks.count {
            var end = screenEnd(in: blocks, from: index)
            if isThin(blocks[index..<end]), end < blocks.count {
                let next = screenEnd(in: blocks, from: end)
                if weight(blocks[index..<next]) <= screenWeight { end = next }
            }
            screens.append(index..<end)
            index = end
        }

        var packed: [Range<Int>] = []
        for screen in screens {
            if let last = packed.last, isThin(blocks[screen]),
               weight(blocks[last.lowerBound..<screen.upperBound]) <= screenWeight {
                packed[packed.count - 1] = last.lowerBound..<screen.upperBound
            } else {
                packed.append(screen)
            }
        }
        return packed
    }

    /// Un seul bloc à lire, et assez court pour laisser de la place.
    private static func isThin(_ screen: ArraySlice<NoteBlock>) -> Bool {
        let content = screen.filter { !isSubtitle($0) }
        guard content.count == 1, let block = content.first else { return false }
        if case .callout = block { return false }
        return weight([block][...]) < thinWeight
    }

    /// La place qu'un écran demande : ses mots, et le cadre de ce qui se dessine en encadré.
    static func weight(_ blocks: ArraySlice<NoteBlock>) -> Int {
        blocks.reduce(0) { total, block in
            let frame: Int
            switch block {
            case .subtitle: frame = 6
            case .paragraph: frame = 0
            case .list(let items), .steps(let items): frame = 4 * items.count
            case .table(_, let rows): frame = 18 + 6 * rows.count
            case .dates(let items): frame = 18 + 4 * items.count
            default: frame = 18
            }
            return total + block.wordCount + frame
        }
    }

    private static func isSubtitle(_ block: NoteBlock) -> Bool {
        if case .subtitle = block { return true }
        return false
    }

    /// La fin d'un écran ouvert à `index` : le bloc, celui qu'ouvre un sous-titre, et
    /// l'encadré qui les commente.
    private static func screenEnd(in blocks: [NoteBlock], from index: Int) -> Int {
        var end = index + 1
        if case .subtitle = blocks[index], end < blocks.count { end += 1 }
        // Un encadré (le piège, l'astuce) commente le bloc qui le précède : il reste sur
        // son écran, au lieu d'arriver seul, détaché de ce qu'il explique.
        if end < blocks.count, case .callout = blocks[end], !blocks[end - 1].isBoxed {
            end += 1
        }
        return end
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
                            MicaboIconView(icon: chapter.icon, size: 84)
                                .reveal(0)
                            Text(chapter.title)
                                .font(MicaboFont.display(30))
                                .foregroundStyle(MicaboColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                                .reveal(1)
                            ToneBox(label: L10n.t("lesson.notes.oneLiner", locale: .resolved()), tone: tone) {
                                KeywordText(notes.oneLiner, size: 20, weight: .bold)
                                    .font(MicaboFont.ui(20, weight: .bold))
                                    .foregroundStyle(MicaboColor.ink)
                            }
                            .reveal(2)
                        }
                        .padding(.top, 20)
                    }
                case .blocks(let range):
                    if let notes = chapter.notes {
                        // Un seul air en tête d'écran, puis le rythme des notes entre les blocs :
                        // posé sur chaque bloc, l'espace du haut s'ajoutait à celui de la pile.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(range.enumerated()), id: \.offset) { offset, index in
                                if notes.blocks.indices.contains(index) {
                                    let block = notes.blocks[index]
                                    let previous: NoteBlock? = offset > 0 && notes.blocks.indices.contains(index - 1) ? notes.blocks[index - 1] : nil
                                    NoteBlockView(block: block, tone: tone)
                                        .padding(.top, NoteRhythm.spacing(before: block, after: previous))
                                        .reveal(offset)
                                }
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
                                    KeywordText(line, size: 19, weight: .semibold)
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
            // La page a exactement la largeur de l'écran : un bloc trop large (un tableau,
            // une formule) défile dans son cadre, la page ne bouge jamais de gauche à droite.
            .containerRelativeFrame(.horizontal)
        }
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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

/// **Les notes entières du cours**, sur un seul document : la leçon, son sommaire (un appui
/// mène au thème), puis chaque thème, numéroté, avec ses notes complètes. Pour relire avant
/// un contrôle, d'une traite.
struct LessonNotesReader: View {
    let session: LessonSession

    @Environment(\.dismiss) private var dismiss

    private var course: Course { session.course }
    private var tone: LessonTone { course.tone }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        cover
                        summary(proxy)
                        ForEach(Array(course.orderedChapters.enumerated()), id: \.element.id) { index, chapter in
                            section(chapter, number: index + 1)
                                .id(chapter.id)
                        }
                        if let takeaways = session.plan?.takeaways, !takeaways.isEmpty {
                            ToneBox(label: L10n.t("lesson.conclusion.title", locale: .resolved()), tone: tone) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(Array(takeaways.enumerated()), id: \.offset) { _, line in
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
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                    .containerRelativeFrame(.horizontal)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            }
            .background(MicaboColor.canvas.ignoresSafeArea())
            .lessonClock(session, activity: .notes)
            .navigationTitle(L10n.t("lesson.notes.full", locale: .resolved()))
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

    private var cover: some View {
        HStack(spacing: 16) {
            MicaboIconView(icon: course.icon, size: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(MicaboFont.display(26))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let subject = course.subject?.nilIfBlank {
                    Text(subject)
                        .font(MicaboFont.ui(15, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            }
        }
    }

    private func summary(_ proxy: ScrollViewProxy) -> some View {
        let themes = course.pathThemes(plan: session.plan)
        return VStack(alignment: .leading, spacing: 4) {
            Text(L10n.t("lesson.notes.summary", locale: .resolved()))
                .font(MicaboFont.small)
                .tracking(MicaboTracking.caps)
                .textCase(.uppercase)
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.bottom, 6)
            ForEach(Array(course.orderedChapters.enumerated()), id: \.element.id) { index, chapter in
                Button {
                    Haptics.light()
                    withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(chapter.id, anchor: .top) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: PathSymbol.resolved(themes.indices.contains(index) ? themes[index].symbol : PathSymbol.fallback))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(tone.ink)
                            .frame(width: 34, height: 34)
                            .background(tone.pale, in: Circle())
                        Text("\(index + 1). \(chapter.title)")
                            .font(MicaboFont.ui(17, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MicaboColor.inkTertiary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
        }
        .padding(16)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .micaboElevation(.row)
    }

    private func section(_ chapter: Chapter, number: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                MicaboIconView(icon: chapter.icon, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("lesson.notes.themeNumber", locale: .resolved(), vars: ["n": String(number)]))
                        .font(MicaboFont.ui(13, weight: .heavy))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(tone.ink)
                    Text(chapter.title)
                        .font(MicaboFont.title)
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if chapter.status == .pending {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.t("lesson.notes.writing", locale: .resolved()))
                        .font(MicaboFont.ui(15, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
            } else {
                ThemeBody(chapter: chapter, tone: tone)
            }
            Rectangle().fill(MicaboColor.hairline).frame(height: 1).padding(.top, 8)
        }
    }
}
