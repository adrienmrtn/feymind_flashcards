import SwiftData
import SwiftUI

/// Disponibilité de la bibliothèque partagée.
///
/// Elle attendait l'authentification, et c'était un drapeau figé à faux. Elle attend maintenant
/// ce qu'elle a toujours attendu, mais pour de vrai : un compte. Sans compte, il n'y a pas
/// d'`auth.uid()` dans la requête, donc rien à voir — et un onglet qui ne mène à rien est un
/// appui perdu, donc il n'apparaît pas.
enum LibraryAccess {
    static func isAvailable(signedIn: Bool) -> Bool {
        signedIn && AppConfig.isConfigured
    }
}

/// Bibliothèque des cours partagés, en sous-onglet de Cours.
///
/// **C'est le serveur qui décide de ce qui s'affiche ici, pas cet écran.** Le cloisonnement de
/// la base ne rend que les cours qu'on a le droit de lire : ceux de son établissement laissés
/// en public, et ceux de ses amis. Un bug d'affichage ne peut donc pas montrer un cours privé,
/// il peut seulement ne pas montrer un cours public — c'est le bon sens de l'erreur.
///
/// Rien n'est gardé sur l'appareil. Les cours de quelqu'un d'autre changent sans qu'on le
/// sache, peuvent redevenir privés, et un ami peut se retirer : une copie locale les figerait,
/// donc mentirait. Ce qui entre vraiment dans l'app, c'est le cours qu'on reprend.
struct LibraryView: View {
    @Environment(SocialService.self) private var social
    @Environment(AuthController.self) private var auth

    /// Ouvre le lecteur d'un cours partagé. La destination vit dans la pile de l'onglet Cours :
    /// reprendre un cours doit atterrir dans « Mes cours », pas dans une feuille modale qu'on
    /// referme sur rien.
    var onOpen: (SharedCourseRecord, SocialService.Person?) -> Void

    @State private var courses: [SharedCourseRecord] = []
    @State private var authors: [UUID: SocialService.Person] = [:]
    @State private var search = ""
    @State private var subject: String?
    @State private var isLoading = false
    @State private var didLoad = false

    private var subjects: [String] {
        Array(Set(courses.compactMap { $0.subject?.nilIfBlank })).sorted()
    }

    private var visible: [SharedCourseRecord] {
        guard let subject else { return courses }
        return courses.filter { $0.subject?.nilIfBlank == subject }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.md) {
            searchField

            if !subjects.isEmpty {
                subjectFilter
            }

            if isLoading, courses.isEmpty {
                loading
            } else if visible.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await load()
        }
    }

    // MARK: - Recherche

    private var searchField: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)

            TextField("Un cours, une matière…", text: $search)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .onSubmit { Task { await load() } }

            if !search.isEmpty {
                Button {
                    search = ""
                    Task { await load() }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .micaboGroup(radius: MicaboRadius.lg)
    }

    private var subjectFilter: some View {
        MicaboFlowLayout(spacing: MicaboSpacing.xs, lineSpacing: MicaboSpacing.xs) {
            MicaboSelectChip(title: "Toutes", isSelected: subject == nil) {
                Haptics.selection()
                subject = nil
            }

            ForEach(subjects, id: \.self) { value in
                MicaboSelectChip(title: value, isSelected: subject == value) {
                    Haptics.selection()
                    subject = subject == value ? nil : value
                }
            }
        }
    }

    // MARK: - Liste

    private var list: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: heading)

            MicaboRowGroup(rows: visible.map { course in
                MicaboRow(
                    tile: MicaboTile(
                        glyph: .emoji(course.emoji?.nilIfBlank ?? "📘"),
                        background: tint(for: course).lightened(by: 0.8),
                        tint: tint(for: course).darkened(by: 0.25)
                    ),
                    title: course.title,
                    subtitle: subtitle(for: course),
                    accessory: .chevron
                ) {
                    Haptics.light()
                    onOpen(course, authors[course.user_id])
                }
            })
        }
    }

    private var heading: String {
        let count = visible.count
        return count == 1 ? "1 cours partagé" : "\(count) cours partagés"
    }

    /// Qui l'a écrit, et de quoi il parle. L'auteur passe devant la matière : dans une
    /// bibliothèque d'école, on reprend d'abord le cours de quelqu'un qu'on connaît.
    private func subtitle(for course: SharedCourseRecord) -> String {
        var parts: [String] = []
        if let author = authors[course.user_id] {
            parts.append(author.relation == .friends ? "\(author.handle) · ami" : author.handle)
        }
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        return parts.isEmpty ? "Cours partagé" : parts.joined(separator: " · ")
    }

    private func tint(for course: SharedCourseRecord) -> Color {
        guard let hex = course.accent_hex?.nilIfBlank else { return MicaboColor.courseAccents[0] }
        return Color(hexString: hex)
    }

    // MARK: - États

    private var loading: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(MicaboColor.progress)
            Text("On regarde ce que ton école a partagé…")
                .font(MicaboFont.caption)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, MicaboSpacing.lg)
    }

    /// Vide, et la raison compte : une bibliothèque sans établissement déclaré est vide parce
    /// qu'on ne sait pas dans quelle école chercher, pas parce que personne n'a rien partagé.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            Text(emptyTitle)
                .font(MicaboFont.cardTitle)
                .foregroundStyle(MicaboColor.ink)

            Text(emptyDetail)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }

    private var emptyTitle: String {
        if OnboardingPreferences.institutionName?.nilIfBlank == nil { return "Ton école n'est pas renseignée" }
        if !search.isEmpty { return "Aucun cours pour cette recherche" }
        return "Rien de partagé pour l'instant"
    }

    private var emptyDetail: String {
        if OnboardingPreferences.institutionName?.nilIfBlank == nil {
            return "La bibliothèque montre les cours de ton établissement. Renseigne-le dans les réglages pour retrouver ceux de tes camarades."
        }
        if !search.isEmpty {
            return "Essaie un autre mot, ou regarde la liste entière."
        }
        return "Personne de \(OnboardingPreferences.institutionName ?? "ton école") n'a encore partagé de cours. Les tiens sont publics par défaut : ce sera peut-être toi le premier."
    }

    // MARK: - Chargement

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        let found = await social.library(search: search)
        courses = found
        authors = await social.authors(of: found)
    }
}
