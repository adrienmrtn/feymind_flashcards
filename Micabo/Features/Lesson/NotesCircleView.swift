import SwiftData
import SwiftUI

/// **Un cercle Notes** : le titre du thème et son icône, les notes, une barre fine en haut qui
/// avance au défilement, et la question de fin. Il se coche quand on a lu jusqu'en bas **et**
/// répondu, bien ou mal.
struct NotesCircleView: View {
    let session: LessonSession
    let chapter: Chapter
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var readProgress: Double = 0
    @State private var readToEnd = false
    @State private var answer: Int?

    private static let space = "lessonNotesScroll"
    private var tone: LessonTone { session.course.tone }
    private var question: QuizQuestion? { chapter.quiz?.final }

    private var canFinish: Bool {
        readToEnd && (question == nil || answer != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            CircleTopBar(progress: readProgress, tone: tone, label: nil) { leave() }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ThemeHeader(chapter: chapter)
                    ThemeBody(chapter: chapter, tone: tone)
                    if let question {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(L10n.t("lesson.notes.question", locale: .resolved()))
                                .font(MicaboFont.small)
                                .tracking(MicaboTracking.caps)
                                .textCase(.uppercase)
                                .foregroundStyle(MicaboColor.inkSecondary)
                            QuestionCard(question: question, tone: tone, answered: answer) { choice in
                                answer = choice
                                let right = choice == question.answer
                                right ? Haptics.success() : Haptics.warning()
                                session.answered(question, right: right, in: modelContext)
                            }
                        }
                        .padding(.top, 10)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .micaboScrollProbes(space: Self.space)
            }
            .micaboScrollGeometry(space: Self.space) { geometry in
                let progress = geometry.progress
                if abs(progress - readProgress) > 0.01 { readProgress = progress }
                if progress > 0.96, !readToEnd { readToEnd = true }
            }

            bottomBar
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if !canFinish {
                Text(question == nil || answer != nil
                    ? L10n.t("lesson.notes.readToEnd", locale: .resolved())
                    : L10n.t("lesson.notes.answerToFinish", locale: .resolved()))
                    .font(MicaboFont.ui(14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
            }
            Button(L10n.t("lesson.circle.next", locale: .resolved())) {
                onDone()
            }
            .buttonStyle(LessonPrimaryButtonStyle(enabled: canFinish))
            .disabled(!canFinish)
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(MicaboColor.canvas)
    }

    private func leave() {
        // L'anneau du cercle en cours dit où on s'est arrêté.
        session.setInCircle(readProgress * (answer == nil ? 0.9 : 1), in: modelContext)
        dismiss()
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
