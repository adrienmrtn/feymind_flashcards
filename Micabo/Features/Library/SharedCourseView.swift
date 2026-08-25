import SwiftData
import SwiftUI

/// Le chemin vers un cours partagé, poussé dans la pile de l'onglet Cours.
///
/// Il porte le cours et son auteur plutôt qu'un identifiant : la ligne est déjà chargée quand
/// on appuie dessus, et la relire depuis le serveur donnerait un écran blanc le temps d'un
/// aller-retour pour afficher ce qu'on a sous les yeux.
struct SharedCourseRoute: Hashable {
    let course: SharedCourseRecord
    let author: SocialService.Person?

    static func == (lhs: SharedCourseRoute, rhs: SharedCourseRoute) -> Bool {
        lhs.course.id == rhs.course.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(course.id)
    }
}

/// La fiche de quelqu'un d'autre, en lecture, avec un bouton pour la reprendre.
///
/// C'est **la même mise en page** que sa propre fiche : les mêmes blocs, la même typographie,
/// le même surlignage. Un cours repris ne doit pas se lire différemment de ses cours, sinon on
/// hésite à le reprendre.
///
/// Deux choses manquent, et les deux volontairement. On ne sélectionne pas un passage pour le
/// faire expliquer : c'est une action qui dépense un appel au modèle, et elle a sa place sur un
/// cours qu'on a décidé de réviser. Et il n'y a pas de cartes : celles de l'auteur ne sont pas
/// transportées, parce que son état de répétition espacée dit exactement ce qu'il sait mal.
struct SharedCourseView: View {
    let route: SharedCourseRoute

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Appelé avec le cours créé localement, pour que l'appelant l'ouvre.
    var onAdopted: (Course) -> Void

    @State private var sheet: CourseSheet?
    @State private var existing: Course?
    @State private var failure: String?

    private var course: SharedCourseRecord { route.course }

    private var tint: Color {
        guard let hex = course.accent_hex?.nilIfBlank else { return MicaboColor.courseAccents[0] }
        return Color(hexString: hex)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                lead
                content
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xs)
            .padding(.bottom, MicaboLayout.bottomBarClearance)
        }
        .scrollIndicators(.hidden)
        .micaboScreenBackground()
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .enablesSwipeBack()
        .overlay(alignment: .bottom) { bottomBar }
        .task {
            sheet = CourseSheet.decode(from: course.sheet?.data)
            existing = CourseRepository.adopted(course, in: modelContext)
        }
        .alert("Oups", isPresented: .constant(failure != nil)) {
            Button("Fermer", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    // MARK: - En-tête

    private var header: some View {
        MicaboScreenHeader(
            title: course.title,
            eyebrow: eyebrow,
            tile: MicaboTile(
                glyph: .emoji(course.emoji?.nilIfBlank ?? "📘"),
                background: tint.lightened(by: 0.8),
                tint: tint.darkened(by: 0.25),
                size: 52
            ),
            back: MicaboHeaderBack.back { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
    }

    /// D'où vient le cours, et de qui. C'est la première chose à dire sur une fiche qu'on n'a
    /// pas écrite.
    private var eyebrow: String {
        var parts: [String] = []
        if let author = route.author { parts.append(author.handle) }
        if let subject = course.subject?.nilIfBlank { parts.append(subject) }
        if let sheet { parts.append("\(sheet.readingMinutes) min de lecture") }
        return parts.isEmpty ? "Cours partagé" : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var lead: some View {
        if let summary = course.summary.nilIfBlank {
            SheetInlineText(markup: summary, style: .lead)
                .padding(.top, MicaboSpacing.md)
        }

        if let author = route.author, author.relation != .friends, author.relation != .me {
            MicaboBadge(text: "De ton école", tone: .neutral)
                .padding(.top, MicaboSpacing.sm)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let sheet, !sheet.blocks.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(sheet.blocks.enumerated()), id: \.offset) { index, block in
                    SheetBlockView(block: block, tint: tint)
                        .padding(.top, index == 0 ? MicaboSpacing.md : SheetBlockView.spacing(before: block))
                }
            }
            .padding(.bottom, MicaboSpacing.xs)
        } else {
            noSheet
        }
    }

    /// Un cours partagé sans fiche : un paquet de cartes, ou un import fait avant la fiche. Le
    /// texte source est là, et c'est lui qu'on reprend.
    private var noSheet: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            Text("Ce cours n'a pas de fiche")
                .font(MicaboFont.cardTitle)
                .foregroundStyle(MicaboColor.ink)

            Text("Tu peux le reprendre quand même : son texte arrive avec, et Micabo t'en écrira la fiche.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MicaboSpacing.md)
        .micaboGroup()
        .padding(.top, MicaboSpacing.lg)
    }

    // MARK: - Reprendre

    private var bottomBar: some View {
        MicaboBottomBar {
            if let existing {
                Button {
                    Haptics.medium()
                    onAdopted(existing)
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Déjà dans tes cours")
                    }
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            } else {
                Button {
                    adopt()
                } label: {
                    HStack(spacing: MicaboSpacing.xs) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Ajouter à mes cours")
                    }
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }
        }
    }

    private func adopt() {
        do {
            let adopted = try CourseRepository.adopt(
                course,
                from: route.author?.username,
                in: modelContext
            )
            Haptics.success()
            onAdopted(adopted)
        } catch {
            failure = "Le cours n'a pas pu être ajouté. Réessaie dans un instant."
        }
    }
}
