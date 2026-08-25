import SwiftUI

/// Les amis : les demandes reçues d'abord, puis la liste, puis de quoi en ajouter.
///
/// L'ordre est l'ordre de l'urgence. Une demande reçue est la seule chose de cet écran qui
/// attend quelque chose de l'utilisateur : elle passe donc devant, et elle disparaît dès qu'on
/// y a répondu. Chercher quelqu'un vient en dernier, parce que c'est l'action qu'on fait une
/// fois puis plus jamais.
///
/// Les camarades de son établissement sont proposés sans rien taper. C'est tout l'intérêt
/// d'avoir demandé l'école à l'inscription : on ne connaît pas le nom d'utilisateur de ses
/// camarades, et leur demander de se l'échanger en cours serait absurde.
struct FriendsView: View {
    @Environment(SocialService.self) private var social
    @Environment(\.dismiss) private var dismiss

    var onOpen: (SocialService.Person) -> Void

    @State private var search = ""
    @State private var results: [SocialService.Person] = []
    @State private var schoolmates: [SocialService.Person] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                header

                if let failure = social.failure {
                    notice(failure)
                }

                if !social.incoming.isEmpty {
                    section("Demandes reçues", people: social.incoming)
                }

                searchField

                if !results.isEmpty {
                    section("Résultats", people: results)
                } else if !schoolmates.isEmpty, search.isEmpty {
                    section(schoolmatesCaption, people: schoolmates)
                }

                if !social.friends.isEmpty {
                    section("Tes amis", people: social.friends)
                } else if search.isEmpty, results.isEmpty {
                    emptyState
                }

                if !social.outgoing.isEmpty {
                    section("Demandes envoyées", people: social.outgoing)
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
            await social.refresh()
            schoolmates = await social.schoolmates()
        }
    }

    private var header: some View {
        MicaboScreenHeader(
            title: "Amis",
            eyebrow: headerEyebrow,
            back: MicaboHeaderBack.back { dismiss() }
        )
        .padding(.top, MicaboSpacing.xs)
    }

    private var headerEyebrow: String {
        if let username = social.username { return Username.display(username) }
        return "Ton compte"
    }

    private var schoolmatesCaption: String {
        guard let school = OnboardingPreferences.institutionName?.nilIfBlank else { return "Ton école" }
        return "À \(school)"
    }

    // MARK: - Recherche

    private var searchField: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Ajouter quelqu'un")

            HStack(spacing: 9) {
                Text("@")
                    .font(MicaboFont.hanken(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)

                TextField("nom d'utilisateur", text: $search)
                    .font(MicaboFont.body)
                    .foregroundStyle(MicaboColor.ink)
                    .tint(MicaboColor.accent)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: search) { _, new in scheduleSearch(new) }

                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MicaboColor.progress)
                }
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .micaboGroup(radius: MicaboRadius.lg)

            MicaboSectionFootnote(
                text: "Un nom d'utilisateur, pas une adresse : c'est ce qui permet de s'ajouter sans échanger son courriel."
            )
        }
    }

    /// La recherche part au bout d'un tiers de seconde sans frappe. Une requête par caractère
    /// donnerait dix requêtes pour un nom, et la neuvième arriverait après la dixième.
    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()

        let needle = query.trimmingCharacters(in: .whitespaces)
        guard needle.count >= 2 else {
            results = []
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            let found = await social.search(needle)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }

    // MARK: - Sections

    /// Les rangées relisent leur relation **au moment de l'affichage**, et pas celle que la
    /// requête a rapportée.
    ///
    /// Les résultats de recherche et les camarades sont des valeurs figées : après avoir envoyé
    /// une demande, leur `relation` disait encore « inconnu », le bouton disait encore
    /// « Ajouter », et un second appui créait un doublon que la base refusait. Elle est donc
    /// recalculée ici, à partir de ce que le service vient de relire.
    private func section(_ caption: String, people: [SocialService.Person]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: caption)

            VStack(spacing: 0) {
                ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                    FriendRow(person: refreshed(person)) {
                        onOpen(person)
                    }

                    if index < people.count - 1 {
                        MicaboHairline(inset: 16)
                    }
                }
            }
            .micaboGroup()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: MicaboSpacing.sm) {
            Text("Personne pour l'instant")
                .font(MicaboFont.cardTitle)
                .foregroundStyle(MicaboColor.ink)

            Text("Un ami voit les cours que tu laisses en « Mes amis », et tu vois les siens. C'est aussi ce qui remonte ses cours dans ta bibliothèque, même s'il a changé d'école.")
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(MicaboSpacing.md)
        .micaboGroup()
    }

    private func refreshed(_ person: SocialService.Person) -> SocialService.Person {
        var updated = person
        updated.relation = social.relation(with: person.id)
        return updated
    }

    private func notice(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.caption)
            .foregroundStyle(MicaboColor.negative)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Une rangée d'annuaire : le nom, l'école, et **l'action qui correspond à l'état**.
///
/// C'est le seul endroit de l'app où un bouton change de sens selon la ligne, et c'est
/// justifié : « Ajouter », « Accepter », « Annuler » et « Retirer » sont quatre actions
/// différentes sur la même relation, et les afficher toutes les quatre demanderait de lire
/// avant de comprendre.
private struct FriendRow: View {
    let person: SocialService.Person
    var onOpen: () -> Void

    @Environment(SocialService.self) private var social

    var body: some View {
        HStack(spacing: 13) {
            Button(action: open) {
                HStack(spacing: 13) {
                    initial

                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.handle)
                            .font(MicaboFont.rowTitle)
                            .foregroundStyle(MicaboColor.ink)
                            .lineLimit(1)

                        if let school = person.institutionName?.nilIfBlank {
                            Text(school)
                                .font(MicaboFont.rowSubtitle)
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false))
            .disabled(person.relation != .friends)

            action
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 16)
    }

    private var initial: some View {
        Text(person.username.first.map { String($0).uppercased() } ?? "?")
            .font(MicaboFont.hanken(15, weight: .semibold))
            .foregroundStyle(MicaboColor.accent)
            .frame(width: 38, height: 38)
            .background(MicaboColor.accentSoft, in: Circle())
    }

    @ViewBuilder
    private var action: some View {
        switch person.relation {
        case .unknown:
            compact("Ajouter", isProminent: true) {
                Task { await social.request(person) }
            }

        case .awaitingMe:
            HStack(spacing: 6) {
                compact("Accepter", isProminent: true) {
                    Task { await social.accept(person) }
                }
                compact("Refuser", isProminent: false) {
                    Task { await social.remove(person) }
                }
            }

        case .requested:
            compact("Annuler", isProminent: false) {
                Task { await social.remove(person) }
            }

        case .friends:
            Menu {
                Button("Voir ses cours", systemImage: "books.vertical", action: open)
                Button("Retirer de mes amis", systemImage: "person.badge.minus", role: .destructive) {
                    Task { await social.remove(person) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .frame(width: 30, height: 30)
            }

        case .me:
            Text("Toi")
                .font(MicaboFont.micro)
                .foregroundStyle(MicaboColor.inkTertiary)
        }
    }

    private func compact(_ title: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(isProminent ? MicaboColor.onInk : MicaboColor.inkSecondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 12)
                .background(
                    isProminent ? MicaboColor.ink : MicaboColor.surfaceMuted,
                    in: Capsule()
                )
        }
        .buttonStyle(MicaboPressableButtonStyle(dimming: false))
        .disabled(social.isLoading)
    }

    private func open() {
        guard person.relation == .friends else { return }
        onOpen()
    }
}
