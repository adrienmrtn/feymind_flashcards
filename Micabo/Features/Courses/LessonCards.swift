import SwiftUI

/// **Une leçon dans l'onglet Leçons** (`docs/refonte-parcours.md` § 15, lot 6) : une carte
/// horizontale. L'icône sur le ton de la leçon, le titre, où on en est sur le chemin, et deux
/// pastilles quand elles disent quelque chose : les cartes à réviser, l'examen qui approche.
struct LessonCard: View {
    let course: Course
    /// Les flashcards dues aujourd'hui.
    var dueCount = 0
    /// Les jours avant l'examen le plus proche.
    var examDays: Int?
    let action: () -> Void

    var body: some View {
        let summary = LessonCardSummary(course: course)
        Button(action: action) {
            HStack(spacing: 14) {
                MicaboIconView(icon: course.icon, size: 40)
                    .frame(width: 60, height: 60)
                    .background(course.tone.pale, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(course.title)
                        .font(MicaboFont.label)
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(summary.caption)
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(MicaboColor.track)
                            Capsule()
                                .fill(course.tone.vivid)
                                .frame(width: proxy.size.width * CGFloat(summary.percent) / 100)
                        }
                    }
                    .frame(height: 5)
                }

                VStack(alignment: .trailing, spacing: 6) {
                    if dueCount > 0 {
                        pill(
                            L10n.t("lesson.lessons.due", locale: .resolved(), vars: ["count": String(dueCount)]),
                            foreground: MicaboColor.onInk,
                            background: MicaboColor.accent
                        )
                    }
                    if let examDays, examDays >= 0 {
                        pill(
                            examDays == 0
                                ? L10n.t("app.exams.countdown.today", locale: .resolved())
                                : L10n.t("lesson.lessons.examDays", locale: .resolved(), vars: ["days": String(examDays)]),
                            foreground: course.tone.ink,
                            background: course.tone.pale
                        )
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .micaboElevation(.row)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(MicaboFont.ui(12, weight: .heavy))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
    }
}

/// Ce qu'une carte de leçon dit de son chemin. Lu une fois par carte : le plan et la
/// progression sont du JSON à décoder.
struct LessonCardSummary: Equatable {
    var percent: Int
    var caption: String

    init(course: Course, locale: UiLocale = .resolved()) {
        guard course.isLesson else {
            percent = 0
            caption = L10n.t("lesson.lessons.toOpen", locale: locale)
            return
        }
        let circles = course.pathSteps().compactMap(\.circle)
        let done = course.progress.done
        let doneCount = circles.filter { done.contains($0.id) }.count
        percent = circles.isEmpty ? 0 : Int((Double(doneCount) / Double(circles.count) * 100).rounded())
        if course.isLearned {
            caption = L10n.t("lesson.lessons.finished", locale: locale)
        } else if let current = PathLayout.current(in: circles, done: done) {
            caption = L10n.t("lesson.lessons.circle", locale: locale, vars: [
                "n": String(current.number),
                "total": String(circles.count),
            ])
        } else {
            caption = L10n.t("lesson.lessons.finished", locale: locale)
        }
    }
}

/// Un dossier : son icône, son nom, le nombre de leçons qu'il range.
struct LessonFolderCard: View {
    let name: String
    let count: Int
    var isTargeted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                MicaboIconView(icon: .folder, size: 40)
                    .frame(width: 60, height: 60)
                    .background(MicaboColor.surfaceSunken, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(MicaboFont.label)
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(1)
                    Text(L10n.t("lesson.lessons.folderCount", locale: .resolved(), vars: ["count": String(count)]))
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isTargeted ? MicaboColor.accent : .clear, lineWidth: 2)
            )
            .micaboElevation(.row)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }
}

/// « Nouvelle leçon » : la dernière rangée, qui ramène à la barre de Home.
struct NewLessonRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MicaboColor.accent)
                    .frame(width: 60, height: 60)
                    .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                Text(L10n.t("lesson.lessons.new", locale: .resolved()))
                    .font(MicaboFont.label)
                    .foregroundStyle(MicaboColor.accent)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(MicaboColor.stroke, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }
}
