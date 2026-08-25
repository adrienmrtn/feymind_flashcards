import SwiftData
import SwiftUI

/// Créer un **paquet de cartes**, sans document et sans fiche.
///
/// Tout partait d'un import, donc d'une fiche, et on ne pouvait pas simplement se faire un
/// paquet de vocabulaire, de dates ou de formules. C'est pourtant la moitié de ce qu'on
/// révise : des choses qu'on a déjà comprises et qu'il faut retenir. Un paquet n'a donc rien
/// à analyser, et cet écran ne demande que ce qui est nécessaire pour en ouvrir un.
///
/// Le texte est facultatif, et c'est tout l'écran : **collé**, Micabo en tire les premières
/// cartes ; **vide**, le paquet démarre nu et se remplit à la main. Les deux mènent au même
/// endroit, l'écran des cartes, où l'on ajoute, corrige et génère à volonté.
struct CreateDeckView: View {
    var onCreated: (Course) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.aiService) private var aiService
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var subject = ""
    @State private var pastedText = ""
    /// Qui pourra retrouver le paquet. Même réglage retenu qu'à l'import.
    @AppStorage(CourseVisibility.importKey) private var visibility = CourseVisibility.standard
    @State private var isWorking = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case title
        case subject
    }

    /// En dessous, il n'y a pas de quoi écrire une carte : le bouton propose alors un paquet
    /// vide plutôt que de lancer une génération qui échouera.
    private static let minimumMaterial = 40

    private var hasMaterial: Bool {
        pastedText.trimmingCharacters(in: .whitespacesAndNewlines).count >= Self.minimumMaterial
    }

    private var canCreate: Bool {
        title.nilIfBlank != nil
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                        MicaboScreenHeader(
                            title: "Un paquet de cartes",
                            eyebrow: "Sans cours",
                            back: MicaboHeaderBack.close { dismiss() }
                        )
                        .padding(.top, MicaboSpacing.xs)

                        nameSection
                        materialSection
                        visibilitySection
                    }
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, MicaboSpacing.xs)
                    .padding(.bottom, MicaboLayout.bottomBarClearance)
                }
                .scrollIndicators(.hidden)
                .micaboScreenBackground()
                .scrollDismissesKeyboard(.interactively)

                MicaboBottomBar {
                    VStack(spacing: 2) {
                        Button {
                            Task { await create(generating: hasMaterial) }
                        } label: {
                            HStack(spacing: MicaboSpacing.xs) {
                                Image(systemName: hasMaterial ? "sparkles" : "plus")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(hasMaterial ? "Écrire les cartes" : "Créer le paquet")
                            }
                        }
                        .buttonStyle(MicaboPrimaryButtonStyle(tint: canCreate ? MicaboColor.ink : MicaboColor.strokeStrong))
                        .disabled(!canCreate || isWorking)

                        // Coller du texte n'oblige pas à laisser le modèle écrire : on peut
                        // le garder comme matière et écrire ses cartes soi-même.
                        if hasMaterial {
                            Button("Créer sans générer") {
                                Task { await create(generating: false) }
                            }
                            .buttonStyle(MicaboQuietButtonStyle())
                            .disabled(!canCreate || isWorking)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if isWorking {
                    GenerationOverlay(
                        title: "Écriture des cartes",
                        steps: ["Lecture de tes notes", "Choix des notions", "Rédaction", "Vérification"]
                    )
                }
            }
            .alert("Oups", isPresented: .constant(errorMessage != nil)) {
                Button("Fermer", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .interactiveDismissDisabled(isWorking)
        .onAppear { focus = .title }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Nom du paquet")

            VStack(spacing: 0) {
                field(
                    emoji: "🃏",
                    background: MicaboColor.tilePastels[1],
                    placeholder: "Vocabulaire allemand, dates de la Révolution…",
                    text: $title,
                    field: .title
                )

                MicaboHairline(inset: 71)

                // La matière n'est pas décorative : c'est elle qui dit au modèle s'il écrit
                // pour un cours de droit ou de médecine, et elle range le paquet dans les
                // filtres de la liste.
                field(
                    emoji: "🏷️",
                    background: MicaboColor.tilePastels[4],
                    placeholder: "Matière, facultatif",
                    text: $subject,
                    field: .subject
                )
            }
            .micaboGroup()
        }
    }

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "De quoi partir, si tu veux")

            TextEditor(text: $pastedText)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(14)
                .micaboGroup()
                .overlay(alignment: .topLeading) {
                    if pastedText.isEmpty {
                        Text("Colle une liste, un lexique, tes notes… Micabo en tire des cartes. Laisse vide pour partir d'un paquet nu.")
                            .font(MicaboFont.body)
                            .foregroundStyle(MicaboColor.inkTertiary)
                            .padding(.horizontal, 19)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    /// Un paquet n'a pas de fiche, donc pas d'écran où l'on pourrait le refermer plus tard :
    /// c'est ici ou jamais.
    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            MicaboSectionCaption(text: "Qui peut le retrouver")

            HStack(spacing: MicaboSpacing.xs) {
                ForEach(CourseVisibility.allCases) { value in
                    MicaboSelectChip(title: value.title, isSelected: value == visibility) {
                        withAnimation(.easeOut(duration: 0.2)) { visibility = value }
                    }
                }
            }
        }
    }

    private func field(
        emoji: String,
        background: Color,
        placeholder: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        HStack(spacing: 13) {
            MicaboTile(glyph: .emoji(emoji), background: background)

            TextField(placeholder, text: text)
                .font(MicaboFont.rowTitle)
                .foregroundStyle(MicaboColor.ink)
                .tint(MicaboColor.accent)
                .submitLabel(.done)
                .focused($focus, equals: field)

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, MicaboSpacing.md)
    }

    // MARK: - Création

    @MainActor
    private func create(generating: Bool) async {
        guard !isWorking, let name = title.nilIfBlank else { return }
        isWorking = true
        defer { isWorking = false }

        let course: Course
        do {
            course = try CourseRepository.makeDeck(
                title: name,
                subject: subject.nilIfBlank,
                rawText: pastedText,
                visibility: visibility,
                in: modelContext
            )
        } catch {
            errorMessage = "Le paquet n'a pas pu être créé. Réessaie dans un instant."
            return
        }

        // Le paquet existe, quoi qu'il arrive ensuite : une génération qui échoue ne doit pas
        // faire perdre le nom et le texte qu'on vient de saisir.
        if generating {
            do {
                try await CardGeneration.run(for: course, using: aiService, in: modelContext)
            } catch {
                onCreated(course)
                return
            }
        }

        onCreated(course)
    }
}
