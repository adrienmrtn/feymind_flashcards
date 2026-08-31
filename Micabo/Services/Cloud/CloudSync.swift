import Foundation
import Observation
import SwiftData

/// La synchronisation des cours entre l'appareil et Supabase.
///
/// **SwiftData reste la source de vérité de l'affichage.** L'app lit et écrit en local, comme
/// avant, et n'attend jamais le réseau pour afficher une fiche : c'est ce qui lui permet de
/// s'ouvrir dans un métro. Le cloud est une copie, tenue à jour en arrière-plan.
///
/// La stratégie est celle du **dernier qui écrit gagne**, arbitrée par `updated_at`. C'est le
/// bon compromis ici et il faut dire pourquoi : les données de Micabo sont personnelles et
/// modifiées à un seul endroit à la fois. Deux appareils qui révisent la même carte dans la
/// même minute sont un cas de figure théorique ; deux appareils dont l'un est resté trois
/// jours hors ligne est le cas réel, et l'horodatage le tranche correctement.
///
/// Un identifiant local devient la clé primaire distante, ce qui évite toute table de
/// correspondance : renvoyer deux fois le même cours le met à jour au lieu de le dupliquer.
@Observable
@MainActor
final class CloudSync {
    enum State: Equatable {
        case idle
        case syncing
        case done(Date)
        case failed(String)
    }

    private(set) var state: State = .idle
    /// Incrémenté à chaque aller-retour réussi. Les écrans s'en servent pour
    /// savoir qu'il faut relire leurs totaux, sans s'abonner à chaque ligne écrite.
    private(set) var epoch = 0

    private let database: SupabaseDatabase
    private let auth: AuthController
    /// Date du dernier aller-retour réussi. Sert dans les deux sens : on ne redescend **et**
    /// on ne remonte que ce qui a changé depuis. Avant ce second usage, chaque lancement
    /// réencodait puis renvoyait tous les cours, toutes les cartes et tout l'historique sur
    /// l'acteur principal. Le réseau n'était pas ce qui figeait l'interface : préparer son
    /// énorme charge utile locale l'était.
    private var lastSyncedAt: Date? {
        get { UserDefaults.standard.object(forKey: Self.watermarkKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Self.watermarkKey) }
    }

    private static let watermarkKey = "micabo.cloud.lastPulledAt"

    init(auth: AuthController) {
        self.auth = auth
        database = SupabaseDatabase(accessToken: { await auth.validAccessToken() })
    }

    /// Efface le repère de synchro. À appeler à la déconnexion : le compte suivant ne doit pas
    /// hériter du repère du précédent, sinon il ne recevrait que les cours modifiés depuis.
    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.watermarkKey)
        CloudTombstones.removeAll()
        state = .idle
    }

    /// Une session Supabase, c'est le compte.
    ///
    /// On recopie le profil s'il y en a un, et on ouvre l'app. On ne décide
    /// plus qu'un utilisateur authentifié « n'existe pas » faute d'avoir fini
    /// l'accueil : c'est ce tri qui recréait un parcours.
    func recognizeExistingAccount() async -> Bool {
        guard auth.isSignedIn, AppConfig.isConfigured else { return false }
        guard auth.user?.id != nil else { return false }

        let profile = try? await database.fetch(ProfileRecord.self, from: CloudTable.profiles).first
        profile?.applyToLocalPreferences()
        OnboardingPreferences.markCompleted()
        return true
    }

    /// Un aller-retour complet : on descend ce qui a changé, on remonte ce qu'on a.
    ///
    /// L'ordre compte. Descendre d'abord évite d'écraser une modification faite ailleurs avec
    /// une version locale plus vieille ; remonter ensuite publie ce que cet appareil a de neuf.
    func sync(context: ModelContext) async {
        guard auth.isSignedIn, AppConfig.isConfigured else { return }
        guard state != .syncing else { return }

        state = .syncing
        let since = lastSyncedAt
        // Le nouveau repère est pris **avant** les requêtes. Si une carte est notée pendant
        // qu'un envoi réseau est suspendu, sa date sera postérieure à ce repère et le passage
        // suivant la reprendra. Prendre `Date()` à la fin pourrait sauter définitivement cette
        // écriture concurrente.
        let checkpoint = Date()
        // La date Postgres et celle du téléphone ne sont pas exactement la même horloge.
        // Relire cinq minutes de recouvrement rend un léger décalage inoffensif ; les
        // identifiants et `updated_at` rendent cette relecture idempotente.
        let pullSince = since?.addingTimeInterval(-5 * 60)
        do {
            try await pull(context: context, since: pullSince)
            try await push(context: context, since: since)
            lastSyncedAt = checkpoint
            epoch += 1
            state = .done(Date())
        } catch {
            // Une panne de synchro ne casse rien : les données locales sont intactes et le
            // prochain passage renverra tout. On la garde visible dans les réglages, sans
            // interrompre ce que l'utilisateur faisait.
            state = .failed((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    // MARK: - Montée

    private func push(context: ModelContext, since: Date?) async throws {
        guard let userID = auth.user?.id else { throw SupabaseDatabase.Failure.notSignedIn }

        try await database.upsert(
            [ProfileRecord.fromLocalPreferences(userID: userID, displayName: auth.user?.displayName)],
            into: CloudTable.profiles
        )

        await flushTombstones()

        let courses = try fetchChangedCourses(in: context, since: since)
            .filter {
                !CloudTombstones.contains(CloudTable.courses, id: $0.id)
            }
        try await database.upsert(courses.map { record(for: $0, userID: userID) }, into: CloudTable.courses)

        // Les cartes changent indépendamment de leur cours : noter une carte ne touche pas
        // `Course.updatedAt`. Il faut donc les lire directement, pas seulement sous les cours
        // retenus ci-dessus.
        let cards = try fetchChangedCards(in: context, since: since)
            .filter {
                !CloudTombstones.contains(CloudTable.flashcards, id: $0.id)
            }
        try await database.upsert(cards.map { record(for: $0, userID: userID) }, into: CloudTable.flashcards)

        // L'historique est en ajout seul. Renvoyer les milliers d'anciennes lignes à chaque
        // ouverture ne les dupliquait pas, mais faisait encoder et transférer tout le passé
        // pour rien.
        let logs = try fetchChangedLogs(in: context, since: since)
        try await database.upsert(logs.map { record(for: $0, userID: userID) }, into: CloudTable.reviewLogs)

        let exams = try fetchChangedExams(in: context, since: since)
            .filter {
                !CloudTombstones.contains(CloudTable.exams, id: $0.id)
            }
        try await database.upsert(exams.map { record(for: $0, userID: userID) }, into: CloudTable.exams)
    }

    /// Les prédicats sont posés **dans SQLite**, pas après un `fetch` complet. C'est ce qui
    /// évite de matérialiser des milliers de modèles sur l'acteur principal juste pour les
    /// jeter aussitôt.
    private func fetchChangedCourses(in context: ModelContext, since: Date?) throws -> [Course] {
        guard let since else { return try context.fetch(FetchDescriptor<Course>()) }
        let descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.updatedAt > since })
        return try context.fetch(descriptor)
    }

    private func fetchChangedCards(in context: ModelContext, since: Date?) throws -> [Flashcard] {
        guard let since else { return try context.fetch(FetchDescriptor<Flashcard>()) }
        let descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.updatedAt > since })
        return try context.fetch(descriptor)
    }

    private func fetchChangedLogs(in context: ModelContext, since: Date?) throws -> [ReviewLog] {
        guard let since else { return try context.fetch(FetchDescriptor<ReviewLog>()) }
        let descriptor = FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.reviewedAt > since })
        return try context.fetch(descriptor)
    }

    private func fetchChangedExams(in context: ModelContext, since: Date?) throws -> [Exam] {
        guard let since else { return try context.fetch(FetchDescriptor<Exam>()) }
        let descriptor = FetchDescriptor<Exam>(predicate: #Predicate { $0.updatedAt > since })
        return try context.fetch(descriptor)
    }

    /// Pose `deleted_at` sur ce qu'on a effacé ici. L'échec n'arrête pas la synchro : on
    /// réessaiera au prochain passage, et le tombstone local empêche déjà la résurrection.
    private func flushTombstones() async {
        let now = Date()
        let patch = TombstonePatch(deleted_at: now, updated_at: now)
        for (table, ids) in CloudTombstones.all() {
            for id in ids {
                try? await database.patch(
                    patch,
                    in: table,
                    matching: [URLQueryItem(name: "id", value: "eq.\(id.uuidString.lowercased())")]
                )
            }
        }
    }

    // MARK: - Descente

    /// Fait descendre ce qui a changé côté serveur depuis le dernier passage.
    ///
    /// Une ligne plus récente que la version locale l'écrase ; une ligne inconnue crée l'objet.
    /// Un `deleted_at` renseigné supprime en local : c'est la seule façon qu'un appareil a
    /// d'apprendre qu'un cours a disparu ailleurs, puisqu'une ligne effacée ne lui apprendrait
    /// rien.
    private func pull(context: ModelContext, since: Date?) async throws {
        guard let userID = auth.user?.id else { throw SupabaseDatabase.Failure.notSignedIn }
        let mine = URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString.lowercased())")

        // **Le filtre est indispensable depuis que la bibliothèque existe.**
        //
        // Cette requête n'en avait pas : elle s'appuyait sur le cloisonnement, qui ne rendait
        // que ses propres lignes. Ouvrir la bibliothèque a ajouté une seconde politique de
        // lecture sur `courses`, et deux politiques se cumulent : la même requête rendait donc
        // aussi les cours de ses camarades, que la boucle plus bas insérait dans « Mes cours ».
        //
        // Le second effet était pire que le premier. La montée renvoie chaque cours local avec
        // son identifiant et **son** `user_id` : réécrire ainsi la ligne d'un camarade est
        // refusé par la politique d'écriture, la synchro échouait, le repère n'avançait pas, et
        // les mêmes lignes revenaient à chaque lancement.
        let remoteCourses = try await database.fetch(
            CourseRecord.self,
            from: CloudTable.courses,
            updatedSince: since,
            filters: [mine]
        )
        let localCourses = try keyedCourses(
            in: context,
            matching: remoteCourses.map(\.id),
            loadAll: since == nil
        )

        for remote in remoteCourses {
            if CloudTombstones.contains(CloudTable.courses, id: remote.id) {
                if let local = localCourses[remote.id] { context.delete(local) }
                continue
            }
            guard let local = localCourses[remote.id] else {
                if remote.deleted_at == nil { context.insert(make(from: remote)) }
                continue
            }
            if let deleted = remote.deleted_at, deleted > local.updatedAt {
                CloudTombstones.mark(CloudTable.courses, id: remote.id)
                for card in local.cards {
                    CloudTombstones.mark(CloudTable.flashcards, id: card.id)
                }
                context.delete(local)
            } else if remote.updated_at > local.updatedAt {
                apply(remote, to: local)
            }
        }

        // Les cartes n'ont qu'une politique de lecture, la sienne, mais le filtre est posé de la
        // même façon : une synchro qui dépend d'un cloisonnement pour ne pas ramasser les
        // lignes des autres est une synchro qu'une politique ajoutée un jour recasse.
        let remoteCards = try await database.fetch(
            FlashcardRecord.self,
            from: CloudTable.flashcards,
            updatedSince: since,
            filters: [mine]
        )
        let coursesByID = try keyedCourses(
            in: context,
            matching: remoteCards.compactMap(\.course_id),
            loadAll: since == nil
        )
        let localCards = try keyedCards(
            in: context,
            matching: remoteCards.map(\.id),
            loadAll: since == nil
        )

        for remote in remoteCards {
            if CloudTombstones.contains(CloudTable.flashcards, id: remote.id) {
                if let local = localCards[remote.id] { context.delete(local) }
                continue
            }
            guard let local = localCards[remote.id] else {
                guard remote.deleted_at == nil else { continue }
                let card = Flashcard(front: remote.front, back: remote.back, hint: remote.hint)
                card.id = remote.id
                apply(remote, to: card)
                card.course = remote.course_id.flatMap { coursesByID[$0] }
                context.insert(card)
                continue
            }
            if let deleted = remote.deleted_at, deleted > local.updatedAt {
                CloudTombstones.mark(CloudTable.flashcards, id: remote.id)
                context.delete(local)
            } else if remote.updated_at > local.updatedAt {
                apply(remote, to: local)
            }
        }

        let remoteExams = try await database.fetch(
            ExamRecord.self,
            from: CloudTable.exams,
            updatedSince: since,
            filters: [mine]
        )
        let localExams = try keyedExams(
            in: context,
            matching: remoteExams.map(\.id),
            loadAll: since == nil
        )

        for remote in remoteExams {
            if CloudTombstones.contains(CloudTable.exams, id: remote.id) {
                if let local = localExams[remote.id] { context.delete(local) }
                continue
            }
            guard let local = localExams[remote.id] else {
                if remote.deleted_at == nil { context.insert(make(from: remote)) }
                continue
            }
            if let deleted = remote.deleted_at, deleted > local.updatedAt {
                CloudTombstones.mark(CloudTable.exams, id: remote.id)
                context.delete(local)
            } else if remote.updated_at > local.updatedAt {
                apply(remote, to: local)
            }
        }

        // Pas d'`updated_at` : on filtre sur le fait daté. Un journal déjà présent
        // (même identifiant) n'est pas réécrit — c'est un ajout seul.
        var logCursor = since
        var remoteLogs: [ReviewLogRecord] = []
        while true {
            let batch = try await database.fetch(
                ReviewLogRecord.self,
                from: CloudTable.reviewLogs,
                updatedSince: logCursor,
                sinceColumn: "reviewed_at",
                filters: [mine]
            )
            remoteLogs.append(contentsOf: batch)
            guard let last = batch.last, batch.count == 1_000, remoteLogs.count < 10_000 else { break }
            logCursor = last.reviewed_at
        }
        let cardsForLogs = try keyedCards(
            in: context,
            matching: remoteLogs.compactMap(\.card_id),
            loadAll: since == nil
        )
        // Une lecture de la table des journaux, pas `card.logs` sur chaque carte :
        // cette relation rouvrait tout l'historique, une carte après l'autre.
        let knownLogIDs = try existingLogIDs(
            in: context,
            among: remoteLogs.map(\.id),
            loadAll: since == nil
        )
        for remote in remoteLogs {
            guard !knownLogIDs.contains(remote.id),
                  let cardID = remote.card_id,
                  let card = cardsForLogs[cardID]
            else { continue }
            let log = ReviewLog(
                reviewedAt: remote.reviewed_at,
                rating: ReviewRating(rawValue: remote.rating) ?? .good,
                stateBefore: CardState(rawValue: remote.state_before) ?? .new,
                previousIntervalDays: remote.previous_interval_days,
                newIntervalDays: remote.new_interval_days,
                easeAfter: remote.ease_after
            )
            log.id = remote.id
            log.card = card
            context.insert(log)
        }

        // Une écriture locale ratée doit faire échouer le passage. Avancer le repère après
        // un `try?` aurait fait croire que les lignes téléchargées étaient persistées et le
        // passage suivant ne les aurait plus demandées.
        try context.save()

        // Le profil descend en dernier : il touche les réglages, pas la base, et il n'a pas à
        // faire échouer la synchro des cours s'il manque.
        if let userID = auth.user?.id,
           let profile = try? await database.fetch(ProfileRecord.self, from: CloudTable.profiles).first,
           profile.id == userID {
            profile.applyToLocalPreferences()
        }
    }

    private func keyedCourses(in context: ModelContext, matching ids: [UUID], loadAll: Bool) throws -> [UUID: Course] {
        if loadAll || ids.count > 80 {
            return Dictionary(
                try context.fetch(FetchDescriptor<Course>()).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        var result: [UUID: Course] = [:]
        for id in Set(ids) {
            let target = id
            var descriptor = FetchDescriptor<Course>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let row = try context.fetch(descriptor).first { result[id] = row }
        }
        return result
    }

    private func keyedCards(in context: ModelContext, matching ids: [UUID], loadAll: Bool) throws -> [UUID: Flashcard] {
        if loadAll || ids.count > 80 {
            return Dictionary(
                try context.fetch(FetchDescriptor<Flashcard>()).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        var result: [UUID: Flashcard] = [:]
        for id in Set(ids) {
            let target = id
            var descriptor = FetchDescriptor<Flashcard>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let row = try context.fetch(descriptor).first { result[id] = row }
        }
        return result
    }

    private func keyedExams(in context: ModelContext, matching ids: [UUID], loadAll: Bool) throws -> [UUID: Exam] {
        if loadAll || ids.count > 80 {
            return Dictionary(
                try context.fetch(FetchDescriptor<Exam>()).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }
        var result: [UUID: Exam] = [:]
        for id in Set(ids) {
            let target = id
            var descriptor = FetchDescriptor<Exam>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if let row = try context.fetch(descriptor).first { result[id] = row }
        }
        return result
    }

    private func existingLogIDs(in context: ModelContext, among ids: [UUID], loadAll: Bool) throws -> Set<UUID> {
        if ids.isEmpty { return [] }
        if loadAll {
            return Set(try context.fetch(FetchDescriptor<ReviewLog>()).map(\.id))
        }
        var known: Set<UUID> = []
        for id in Set(ids) {
            let target = id
            var descriptor = FetchDescriptor<ReviewLog>(predicate: #Predicate { $0.id == target })
            descriptor.fetchLimit = 1
            if try context.fetch(descriptor).first != nil { known.insert(id) }
        }
        return known
    }

    // MARK: - Traductions

    private func record(for course: Course, userID: UUID) -> CourseRecord {
        CourseRecord(
            id: course.id,
            user_id: userID,
            title: course.title,
            subject: course.subject,
            summary: course.summary,
            emoji: course.emoji,
            accent_hex: course.accentHex,
            source: course.source.rawValue,
            source_file_name: course.sourceFileName,
            fingerprint: course.fingerprint,
            raw_text: course.rawText,
            sheet: JSONCodable(data: course.sheetData),
            context_text: course.contextText,
            is_from_library: course.isFromLibrary,
            visibility: course.visibilityRaw,
            created_at: course.createdAt,
            updated_at: course.updatedAt,
            deleted_at: nil
        )
    }

    private func make(from remote: CourseRecord) -> Course {
        let course = Course(
            id: remote.id,
            title: remote.title,
            // La matière est décapitalisée à la descente comme à l'import : une ligne écrite
            // par une version qui criait encore ne doit pas rapporter ses capitales ici.
            subject: remote.subject.map(TextSanitizer.subject),
            summary: remote.summary,
            emoji: remote.emoji ?? CourseEmoji.fallback,
            accentHex: remote.accent_hex ?? "2F4858",
            source: CourseSource(rawValue: remote.source) ?? .text,
            sourceFileName: remote.source_file_name,
            rawText: remote.raw_text,
            contextText: remote.context_text,
            coverImageData: nil,
            isFromLibrary: remote.is_from_library
        )
        apply(remote, to: course)
        return course
    }

    private func apply(_ remote: CourseRecord, to course: Course) {
        course.title = remote.title
        course.subject = remote.subject.map(TextSanitizer.subject)
        course.summary = remote.summary
        if let emoji = remote.emoji { course.emoji = emoji }
        if let accent = remote.accent_hex { course.accentHex = accent }
        course.source = CourseSource(rawValue: remote.source) ?? course.source
        course.sourceFileName = remote.source_file_name
        course.fingerprint = remote.fingerprint
        course.rawText = remote.raw_text
        course.sheetData = remote.sheet?.data
        course.contextText = remote.context_text
        course.isFromLibrary = remote.is_from_library
        // Une valeur inconnue d'une version plus ancienne du serveur ne change rien : le
        // cours garde la visibilité qu'il avait plutôt que de retomber sur « public », ce qui
        // serait le pire des replis possibles pour un réglage de partage.
        if CourseVisibility(rawValue: remote.visibility) != nil {
            course.visibilityRaw = remote.visibility
        }
        course.createdAt = remote.created_at
        course.updatedAt = remote.updated_at
        if let views = remote.view_count { course.viewCount = views }
        if let adopts = remote.adopt_count { course.adoptCount = adopts }
    }

    private func record(for card: Flashcard, userID: UUID) -> FlashcardRecord {
        FlashcardRecord(
            id: card.id,
            user_id: userID,
            course_id: card.course?.id,
            front: card.front,
            back: card.back,
            hint: card.hint,
            position: card.position,
            kind: card.kind.rawValue,
            choices: card.choices,
            correct_choice_index: card.correctChoiceIndex,
            mask_x: card.maskX,
            mask_y: card.maskY,
            mask_width: card.maskWidth,
            mask_height: card.maskHeight,
            group_id: card.groupID,
            is_reversed: card.isReversed,
            is_suspended: card.isSuspended,
            state: card.state.rawValue,
            due_date: card.dueDate,
            interval_days: card.intervalDays,
            ease_factor: card.easeFactor,
            repetitions: card.repetitions,
            lapses: card.lapses,
            step_index: card.stepIndex,
            last_reviewed_at: card.lastReviewedAt,
            created_at: card.createdAt,
            updated_at: card.updatedAt,
            deleted_at: nil,
            image_path: CloudImage.dataURL(from: card.imageData)
        )
    }

    private func apply(_ remote: FlashcardRecord, to card: Flashcard) {
        card.front = remote.front
        card.back = remote.back
        card.hint = remote.hint
        card.position = remote.position
        card.kind = CardKind(rawValue: remote.kind) ?? .basic
        card.choices = remote.choices
        card.correctChoiceIndex = remote.correct_choice_index
        card.maskX = remote.mask_x
        card.maskY = remote.mask_y
        card.maskWidth = remote.mask_width
        card.maskHeight = remote.mask_height
        card.groupID = remote.group_id
        card.isReversed = remote.is_reversed
        card.isSuspended = remote.is_suspended
        card.state = CardState(rawValue: remote.state) ?? .new
        card.dueDate = remote.due_date
        card.intervalDays = remote.interval_days
        card.easeFactor = remote.ease_factor
        card.repetitions = remote.repetitions
        card.lapses = remote.lapses
        card.stepIndex = remote.step_index
        card.lastReviewedAt = remote.last_reviewed_at
        card.createdAt = remote.created_at
        card.updatedAt = remote.updated_at
        // Une ligne sans image ne doit pas effacer le schéma encore local : le web
        // n'écrit `image_path` que pour les occlusions, et une carte revue ici
        // avant la synchro garderait sinon une zone masquée sans dessin.
        if let image = CloudImage.data(from: remote.image_path) {
            card.imageData = image
        }
    }

    private func record(for log: ReviewLog, userID: UUID) -> ReviewLogRecord {
        ReviewLogRecord(
            id: log.id,
            user_id: userID,
            card_id: log.card?.id,
            reviewed_at: log.reviewedAt,
            rating: log.ratingRaw,
            state_before: log.stateBeforeRaw,
            previous_interval_days: log.previousIntervalDays,
            new_interval_days: log.newIntervalDays,
            ease_after: log.easeAfter
        )
    }

    private func record(for exam: Exam, userID: UUID) -> ExamRecord {
        ExamRecord(
            id: exam.id,
            user_id: userID,
            name: exam.name,
            exam_date: exam.date,
            intensity: exam.intensityRaw,
            target_score: exam.targetScore,
            course_ids: exam.courseIDs,
            is_planned: exam.isPlanned,
            planned_at: exam.plannedAt,
            created_at: exam.createdAt,
            updated_at: exam.updatedAt,
            deleted_at: nil,
            schedule_backup: JSONCodable(data: exam.scheduleBackup)
        )
    }

    private func make(from remote: ExamRecord) -> Exam {
        let exam = Exam(
            id: remote.id,
            name: remote.name,
            date: remote.exam_date,
            courseIDs: remote.course_ids,
            intensity: ExamIntensity(rawValue: remote.intensity) ?? .standard,
            targetScore: remote.target_score
        )
        apply(remote, to: exam)
        return exam
    }

    private func apply(_ remote: ExamRecord, to exam: Exam) {
        exam.name = remote.name
        exam.date = remote.exam_date
        exam.intensityRaw = remote.intensity
        if let score = remote.target_score { exam.targetScore = score }
        exam.courseIDs = remote.course_ids
        exam.isPlanned = remote.is_planned
        exam.plannedAt = remote.planned_at
        exam.createdAt = remote.created_at
        exam.updatedAt = remote.updated_at
        // Le web peut mettre à jour un examen sans renvoyer la photographie : on
        // ne l'efface que lorsqu'elle arrive vraiment, ou qu'elle est nulle après
        // un déplanification écrite (`schedule_backup: null` n'est pas encodé ici
        // — une absence de colonne laisse la copie locale).
        if let backup = remote.schedule_backup?.data {
            exam.scheduleBackup = backup
        }
    }
}
