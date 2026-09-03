import SwiftUI

/// Le profil d'un ami : son nom, son école, et **ses cours**.
///
/// Il n'y a ni statistiques, ni série, ni nombre de cartes révisées, et c'est un choix. Ce
/// qu'on vient chercher chez un ami, c'est un cours qu'on n'a pas eu le temps de ficher ;
/// afficher son rythme de révision en ferait un classement, et un classement dans une app de
/// révision fait décrocher ceux qui en ont le plus besoin.
///
/// Ce qui s'affiche ici est décidé par le serveur : la liste contient ce que cet ami laisse
/// voir, et rien d'autre. Un cours passé en privé disparaît de cet écran au rechargement
/// suivant, sans que l'app ait à le savoir.
struct FriendProfileView: View {
    let person: SocialService.Person

    @Environment(SocialService.self) private var social
    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    var onOpen: (SharedCourseRecord, SocialService.Person) -> Void

    @State private var courses: [SharedCourseRecord] = []
    @State private var cardCounts: [UUID: Int] = [:]
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header
                identity

                if isLoading {
                    loading
                } else if courses.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .task {
            let found = await social.courses(of: person)
            courses = found
            cardCounts = await social.cardCounts(of: found.map(\.id))
            isLoading = false
        }
    }

    private var header: some View {
        MicaboScreenHeader(
            title: person.handle,
            eyebrow: person.institutionName?.nilIfBlank ?? (i18n?.t("ios.friend") ?? "Ami"),
            back: MicaboHeaderBack.back { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
    }

    /// Ce que ce profil a à dire de plus que son en-tête : le compte de ses cours partagés.
    ///
    /// La pastille d'initiale qui vivait ici est partie — un rond coloré avec une lettre
    /// dedans est une photo de profil qui n'existe pas — et le nom avec elle : l'en-tête le
    /// porte déjà en grand, deux centimètres plus haut. Ne reste que la ligne qui compte.
    private var identity: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MicaboColor.accent)

            Text(countLabel)
                .font(MicaboFont.bodyEmphasis)
                .foregroundStyle(MicaboColor.ink)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private var countLabel: String {
        if isLoading { return i18n?.t("app.friends.loadingCourses") ?? "On regarde ses cours…" }
        if courses.isEmpty { return i18n?.t("ios.noSharedCourses") ?? "Aucun cours partagé" }
        return i18n?.t("ios.sharedCount", ["courses": MicaboCopy.courses(courses.count)])
            ?? (MicaboCopy.courses(courses.count) + " partagés")
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: i18n?.t("app.friends.theirCourses") ?? "Ses cours")

            MicaboRowGroup(rows: courses.map { course in
                MicaboRow(
                    tile: MicaboTile(
                        glyph: .emoji(course.emoji?.nilIfBlank ?? "📘"),
                        background: tint(for: course).lightened(by: 0.8),
                        tint: tint(for: course).darkened(by: 0.25)
                    ),
                    title: course.title,
                    subtitle: friendSubtitle(for: course),
                    accessory: .chevron
                ) {
                    onOpen(course, person)
                }
            })
        }
    }

    private func friendSubtitle(for course: SharedCourseRecord) -> String {
        var parts: [String] = []
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        if let count = cardCounts[course.id], count > 0 {
            parts.append(MicaboCopy.cards(count))
        }
        parts.append(MicaboCopy.audience(of: course))
        return parts.isEmpty ? (i18n?.t("ios.sharedCourse") ?? "Cours partagé") : parts.joined(separator: " · ")
    }

    private func tint(for course: SharedCourseRecord) -> Color {
        guard let hex = course.accent_hex?.nilIfBlank else { return MicaboColor.courseAccents[0] }
        return Color(hexString: hex)
    }

    private var loading: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(MicaboColor.progress)
            Text(i18n?.t("app.friends.loadingCourses") ?? "On regarde ses cours…")
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            Text(i18n?.t("app.friends.nothingToSee") ?? "Rien à voir pour l'instant")
                .font(MicaboFont.cardTitle)
                .foregroundStyle(MicaboColor.ink)

            Text(i18n?.t("app.friends.noShared", ["handle": person.handle]) ?? "\(person.handle) n'a pas de cours partagé.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }
}
