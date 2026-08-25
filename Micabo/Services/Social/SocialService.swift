import Foundation
import Observation

/// L'annuaire, les amitiés et la bibliothèque, en un seul objet.
///
/// Les trois sont la même chose vue sous trois angles : qui je connais décide de ce que je
/// vois. Les séparer aurait obligé chaque écran à recoller le graphe des amitiés sur une liste
/// de cours, et deux écrans qui recollent le même graphe finissent par ne pas être d'accord.
///
/// **Rien n'est mis en cache sur l'appareil, et c'est un choix.** Les cours de quelqu'un
/// d'autre ne sont pas les siens : ils changent sans qu'on le sache, ils peuvent redevenir
/// privés, et un ami peut se retirer. Une copie locale les figerait — donc mentirait — alors
/// que la bibliothèque est un écran qu'on ouvre, pas une donnée dont on dépend. Ce qui entre
/// vraiment dans l'app, c'est le cours qu'on reprend, et celui-là devient le nôtre.
@Observable
@MainActor
final class SocialService {
    /// Où l'on en est avec quelqu'un. C'est cet état, et lui seul, qui décide du bouton
    /// affiché en face d'un nom.
    enum Relation: Equatable {
        case unknown
        /// J'ai demandé, la personne n'a pas répondu.
        case requested
        /// La personne a demandé, c'est à moi de répondre.
        case awaitingMe
        case friends
        case me
    }

    /// Quelqu'un, tel que l'app le montre : un nom, une école, et où l'on en est avec lui.
    struct Person: Identifiable, Hashable {
        let id: UUID
        let username: String
        let institutionName: String?
        var relation: Relation

        var handle: String { Username.display(username) }
    }

    private(set) var username: String?
    private(set) var friends: [Person] = []
    private(set) var incoming: [Person] = []
    private(set) var outgoing: [Person] = []
    private(set) var isLoading = false
    private(set) var failure: String?

    /// Ce que la pastille de l'onglet Profil annonce : des demandes à traiter.
    var pendingCount: Int { incoming.count }

    var isReady: Bool { auth.isSignedIn && AppConfig.isConfigured }

    private let auth: AuthController
    private let database: SupabaseDatabase

    init(auth: AuthController) {
        self.auth = auth
        database = SupabaseDatabase(accessToken: { await auth.validAccessToken() })
    }

    // MARK: - Chargement

    /// Relit le nom d'utilisateur et les amitiés. Deux requêtes, et une troisième pour mettre
    /// des noms sur les identifiants : l'annuaire est une table à part, donc pas de jointure.
    func refresh() async {
        guard isReady, let me = auth.user?.id else {
            reset()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let mine = try await database.rows(
                DirectoryRecord.self,
                from: CloudTable.directory,
                filters: [URLQueryItem(name: "id", value: "eq.\(me.uuidString.lowercased())")],
                limit: 1
            )
            username = mine.first?.username

            let links = try await database.rows(
                FriendshipRecord.self,
                from: CloudTable.friendships
            )
            let people = try await directory(for: links.map { $0.other(than: me) })

            friends = links.filter(\.isAccepted).compactMap { link in
                person(people[link.other(than: me)], relation: .friends)
            }
            incoming = links.filter { !$0.isAccepted && $0.addressee_id == me }.compactMap { link in
                person(people[link.requester_id], relation: .awaitingMe)
            }
            outgoing = links.filter { !$0.isAccepted && $0.requester_id == me }.compactMap { link in
                person(people[link.addressee_id], relation: .requested)
            }
            failure = nil
        } catch {
            failure = describe(error)
        }
    }

    private func reset() {
        username = nil
        friends = []
        incoming = []
        outgoing = []
        failure = nil
    }

    // MARK: - Nom d'utilisateur

    /// Écrit le nom d'utilisateur, et dit ce qui l'a empêché.
    ///
    /// Le nom part **seul**, sans le reste du profil : la synchro envoie le profil entier à
    /// chaque passage, et si le nom voyageait avec, un appareil dont la copie locale est en
    /// retard écraserait le nom qu'on vient de changer sur l'autre.
    @discardableResult
    func setUsername(_ raw: String) async -> Bool {
        guard let me = auth.user?.id else {
            failure = "Il faut un compte pour choisir un nom d'utilisateur."
            return false
        }

        switch Username.validate(raw) {
        case .failure(let problem):
            failure = problem.errorDescription
            return false

        case .success(let candidate):
            guard candidate != username else {
                failure = nil
                return true
            }

            isLoading = true
            defer { isLoading = false }

            do {
                try await database.patch(
                    UsernameRecord(username: candidate),
                    in: CloudTable.profiles,
                    matching: [URLQueryItem(name: "id", value: "eq.\(me.uuidString.lowercased())")]
                )
                username = candidate
                failure = nil
                return true
            } catch let error as SupabaseDatabase.Failure where error.isDuplicate {
                failure = "\(Username.display(candidate)) est déjà pris."
                return false
            } catch {
                failure = describe(error)
                return false
            }
        }
    }

    // MARK: - Trouver quelqu'un

    /// Cherche dans l'annuaire par nom d'utilisateur.
    ///
    /// L'annuaire ne porte que le nom et l'établissement : chercher quelqu'un ne renseigne
    /// donc sur rien d'autre, et c'est exactement pour ça que cette table existe.
    func search(_ query: String) async -> [Person] {
        let needle = Username.normalize(query)
        guard isReady, needle.count >= 2, let me = auth.user?.id else { return [] }

        do {
            let found = try await database.rows(
                DirectoryRecord.self,
                from: CloudTable.directory,
                filters: [URLQueryItem(name: "username", value: "ilike.*\(needle)*")],
                order: "username.asc",
                limit: 25
            )
            return found.map { entry in
                Person(
                    id: entry.id,
                    username: entry.username,
                    institutionName: entry.institution_name,
                    relation: entry.id == me ? .me : relation(with: entry.id)
                )
            }
        } catch {
            failure = describe(error)
            return []
        }
    }

    /// Les camarades du même établissement, pour n'avoir rien à taper.
    func schoolmates() async -> [Person] {
        guard isReady, let me = auth.user?.id,
              let institution = OnboardingPreferences.institutionId?.nilIfBlank else { return [] }

        do {
            let found = try await database.rows(
                DirectoryRecord.self,
                from: CloudTable.directory,
                filters: [URLQueryItem(name: "institution_id", value: "eq.\(institution)")],
                order: "username.asc",
                limit: 50
            )
            return found
                .filter { $0.id != me }
                .map { entry in
                    Person(
                        id: entry.id,
                        username: entry.username,
                        institutionName: entry.institution_name,
                        relation: relation(with: entry.id)
                    )
                }
        } catch {
            failure = describe(error)
            return []
        }
    }

    /// Où l'on en est avec quelqu'un, d'après ce qui est déjà chargé.
    func relation(with id: UUID) -> Relation {
        if id == auth.user?.id { return .me }
        if friends.contains(where: { $0.id == id }) { return .friends }
        if incoming.contains(where: { $0.id == id }) { return .awaitingMe }
        if outgoing.contains(where: { $0.id == id }) { return .requested }
        return .unknown
    }

    // MARK: - Demander, accepter, retirer

    /// Envoie une demande. Si la personne en a déjà envoyé une, on l'accepte plutôt que d'en
    /// créer une seconde : deux personnes d'accord ne doivent pas rester en attente l'une de
    /// l'autre.
    func request(_ person: Person) async {
        guard let me = auth.user?.id, person.id != me else { return }

        if incoming.contains(where: { $0.id == person.id }) {
            await accept(person)
            return
        }

        await perform {
            try await self.database.insert(
                [FriendshipRecord(
                    requester_id: me,
                    addressee_id: person.id,
                    status: FriendshipRecord.pending,
                    created_at: nil,
                    responded_at: nil
                )],
                into: CloudTable.friendships
            )
        }
    }

    /// Accepter n'appartient qu'au destinataire, et la base le vérifie : la politique
    /// d'écriture n'autorise le passage à « accepted » que sur une ligne dont on est le
    /// destinataire.
    func accept(_ person: Person) async {
        guard let me = auth.user?.id else { return }

        await perform {
            try await self.database.patch(
                FriendshipResponse(status: FriendshipRecord.accepted, responded_at: Date()),
                in: CloudTable.friendships,
                matching: [
                    URLQueryItem(name: "requester_id", value: "eq.\(person.id.uuidString.lowercased())"),
                    URLQueryItem(name: "addressee_id", value: "eq.\(me.uuidString.lowercased())")
                ]
            )
        }
    }

    /// Refuser une demande, annuler la sienne, se retirer d'une amitié : la même ligne
    /// s'efface, et les deux côtés en ont le droit. Une amitié retirée n'est pas un état, c'est
    /// une absence.
    func remove(_ person: Person) async {
        guard let me = auth.user?.id else { return }

        let mine = me.uuidString.lowercased()
        let theirs = person.id.uuidString.lowercased()

        await perform {
            try await self.database.remove(
                from: CloudTable.friendships,
                matching: [
                    URLQueryItem(
                        name: "or",
                        value: "(and(requester_id.eq.\(mine),addressee_id.eq.\(theirs)),"
                            + "and(requester_id.eq.\(theirs),addressee_id.eq.\(mine)))"
                    )
                ]
            )
        }
    }

    // MARK: - Bibliothèque

    /// Les cours partagés qu'on a le droit de lire.
    ///
    /// Le filtre par visibilité est posé ici **en plus** du cloisonnement, et il ne sert à
    /// rien : c'est la base qui décide, et elle ne rendrait rien d'autre. Il est là pour que la
    /// requête dise ce qu'elle veut, et pour qu'une politique relâchée par erreur un jour ne se
    /// traduise pas immédiatement par des cours privés à l'écran.
    func library(search: String = "", subject: String? = nil, limit: Int = 60) async -> [SharedCourseRecord] {
        var filters = [URLQueryItem(name: "visibility", value: "neq.private")]

        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.count >= 2 {
            filters.append(
                URLQueryItem(name: "or", value: "(title.ilike.*\(needle)*,subject.ilike.*\(needle)*)")
            )
        }
        if let subject = subject?.nilIfBlank {
            filters.append(URLQueryItem(name: "subject", value: "eq.\(subject)"))
        }

        return await shared(filters: filters, limit: limit)
    }

    /// Les cours d'une personne, tels qu'elle nous les laisse voir. C'est la base qui trie :
    /// demander les cours de quelqu'un dont on n'est pas ami rend une liste vide.
    func courses(of person: Person, limit: Int = 60) async -> [SharedCourseRecord] {
        await shared(
            filters: [
                URLQueryItem(name: "user_id", value: "eq.\(person.id.uuidString.lowercased())"),
                URLQueryItem(name: "visibility", value: "neq.private")
            ],
            limit: limit
        )
    }

    private func shared(filters: [URLQueryItem], limit: Int) async -> [SharedCourseRecord] {
        guard isReady else { return [] }

        do {
            let courses = try await database.rows(
                SharedCourseRecord.self,
                from: CloudTable.courses,
                select: SharedCourseRecord.columns,
                filters: filters,
                order: "updated_at.desc",
                limit: limit
            )
            failure = nil
            return courses
        } catch {
            failure = describe(error)
            return []
        }
    }

    /// Les noms des auteurs d'une liste de cours, en une requête.
    ///
    /// L'annuaire est une table séparée de `courses` : il n'y a pas de clé étrangère entre les
    /// deux, donc pas de jointure possible côté serveur. C'est le prix de la décision de ne
    /// jamais exposer `profiles`, et il se paye en une requête de plus.
    func authors(of courses: [SharedCourseRecord]) async -> [UUID: Person] {
        let identifiers = Array(Set(courses.map(\.user_id)))
        guard !identifiers.isEmpty else { return [:] }

        do {
            let entries = try await directory(for: identifiers)
            return entries.mapValues { entry in
                Person(
                    id: entry.id,
                    username: entry.username,
                    institutionName: entry.institution_name,
                    relation: relation(with: entry.id)
                )
            }
        } catch {
            return [:]
        }
    }

    // MARK: - Rouages

    private func directory(for identifiers: [UUID]) async throws -> [UUID: DirectoryRecord] {
        let unique = Array(Set(identifiers))
        guard !unique.isEmpty else { return [:] }

        let list = unique.map { $0.uuidString.lowercased() }.joined(separator: ",")
        let entries = try await database.rows(
            DirectoryRecord.self,
            from: CloudTable.directory,
            filters: [URLQueryItem(name: "id", value: "in.(\(list))")],
            limit: max(unique.count, 1)
        )
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    private func person(_ entry: DirectoryRecord?, relation: Relation) -> Person? {
        guard let entry else { return nil }
        return Person(
            id: entry.id,
            username: entry.username,
            institutionName: entry.institution_name,
            relation: relation
        )
    }

    /// Une écriture, puis une relecture. Relire coûte une requête et évite de tenir un état
    /// local en parallèle de celui du serveur : les demandes d'amitié se comptent en dizaines,
    /// pas en milliers.
    private func perform(_ work: @escaping () async throws -> Void) async {
        isLoading = true
        do {
            try await work()
            failure = nil
        } catch let error as SupabaseDatabase.Failure where error.isDuplicate {
            failure = "Cette demande existe déjà."
        } catch {
            failure = describe(error)
        }
        isLoading = false
        await refresh()
    }

    private func describe(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

/// La réponse à une demande : seules ces deux colonnes changent, et la base n'accepte que le
/// passage à « accepted ».
private struct FriendshipResponse: Encodable {
    var status: String
    var responded_at: Date
}
