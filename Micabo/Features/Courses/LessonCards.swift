import SwiftUI

/// **Une leçon dans l'onglet Leçons** (lot 10, HOME.md § 4) : une carte. L'icône de sa matière,
/// le titre, où on en est sur le chemin (« Étape 3 sur 7 », ou « Terminée »), la jauge, et deux
/// pastilles quand elles disent quelque chose : les cartes à revoir, l'examen qui approche.
struct LessonCard: View {
    let course: Course
    /// Les cartes dues aujourd'hui.
    var dueCount = 0
    /// Les jours avant l'examen le plus proche.
    var examDays: Int?
    /// Le menu « ⋯ » : renommer, déplacer, supprimer. Sans eux, pas de menu.
    var onRename: (() -> Void)?
    var onMove: (() -> Void)?
    var onDelete: (() -> Void)?
    let action: () -> Void

    private var hasMenu: Bool { onRename != nil || onMove != nil || onDelete != nil }

    var body: some View {
        let summary = LessonCardSummary(course: course)
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                LessonIconTile(icon: course.icon, tone: course.tone)

                VStack(alignment: .leading, spacing: 6) {
                    // Quatre lignes au plus : un titre long en très grand texte sur un iPhone SE
                    // se lit en entier.
                    Text(course.title)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(summary.caption)
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    V3ProgressBar(value: Double(summary.percent) / 100)
                        .padding(.top, 2)
                    if dueCount > 0 || (examDays ?? -1) >= 0 {
                        HStack(spacing: 6) {
                            if dueCount > 0 {
                                LessonPill(
                                    text: L10n.t("ios.home10.lessons.due", locale: .resolved(), vars: ["count": String(dueCount)]),
                                    foreground: V3Color.onAccent,
                                    background: V3Color.accent
                                )
                            }
                            if let examDays, examDays >= 0 {
                                LessonPill(
                                    text: ExamCountdown.label(daysLeft: examDays),
                                    foreground: V3Color.yellowInk,
                                    background: V3Color.yellowWash
                                )
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: hasMenu ? 30 : 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card()
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityElement(children: .combine)
        .overlay(alignment: .topTrailing) {
            if hasMenu {
                Menu {
                    if let onRename {
                        Button(action: onRename) {
                            Label(L10n.t("lesson.menu.rename", locale: .resolved()), systemImage: "pencil")
                        }
                    }
                    if let onMove {
                        Button(action: onMove) {
                            Label(L10n.t("app.folders.moveTo", locale: .resolved()), systemImage: "folder")
                        }
                    }
                    if let onDelete {
                        Button(role: .destructive, action: onDelete) {
                            Label(L10n.t("lesson.menu.delete", locale: .resolved()), systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(V3Color.ink3)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, 4)
                .padding(.top, 4)
                .accessibilityLabel(Text(L10n.t("lesson.menu.more", locale: .resolved())))
            }
        }
    }
}

/// L'icône d'une leçon ou d'un dossier, dans sa couleur, sur un carré de la surface haute.
struct LessonIconTile: View {
    let icon: MicaboIcon
    var tone: LessonTone?
    var side: CGFloat = 52

    var body: some View {
        MicaboIconView(icon: icon, size: side * 0.62, tone: tone)
            .frame(width: side, height: side)
            .background(V3Color.soft, in: RoundedRectangle(cornerRadius: MicaboRadius.md, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Une pastille d'une carte de leçon : « 8 à revoir », « J-12 ».
struct LessonPill: View {
    let text: String
    let foreground: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(V3Font.caption)
            .monospacedDigit()
            .foregroundStyle(foreground)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
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
            caption = L10n.t("ios.home10.lessons.finished", locale: locale)
        } else if let current = PathLayout.current(in: circles, done: done) {
            // « Étape », comme sur le chemin : l'élève ne voit nulle part ailleurs le mot « cercle ».
            caption = L10n.t("ios.pol.learn.stepOf", locale: locale, vars: [
                "n": String(current.number),
                "total": String(circles.count),
            ])
        } else {
            caption = L10n.t("ios.home10.lessons.finished", locale: locale)
        }
    }
}

/// Un dossier : son icône, son nom, le nombre de leçons qu'il range. Un cours qu'on glisse
/// au-dessus de lui le marque du filet d'accent.
struct LessonFolderCard: View {
    let name: String
    let count: Int
    var isTargeted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                LessonIconTile(icon: .folder)
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(V3Font.bodyStrong)
                        .foregroundStyle(V3Color.ink)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t("lesson.lessons.folderCount", locale: .resolved(), vars: ["count": String(count)]))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(V3Color.ink3)
                    .accessibilityHidden(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .v3Card(selected: isTargeted)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }
}

/// **Un écran vide de l'onglet Leçons** : Mika, une phrase, et au plus une ligne et un bouton.
/// La bibliothèque vide est un de ses moments : il y est en grand, avec « Créer une leçon ».
struct LessonsEmptyState: View {
    let mood: MikaMood
    var mikaSize: CGFloat = 130
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            MikaMascot(mood: mood, size: mikaSize)
                .accessibilityHidden(true)
            Text(title)
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 16)
            if let message {
                Text(message)
                    .font(V3Font.body)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }
            if let actionTitle, let action {
                V3Button(actionTitle, systemImage: "plus", action: action)
                    .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
