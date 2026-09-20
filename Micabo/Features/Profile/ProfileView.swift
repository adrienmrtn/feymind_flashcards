import SwiftData
import SwiftUI

/// **Le Profil, en tableau de bord.**
///
/// Il empilait cinq blocs blancs, chacun sous son intitulé en capitales grises : une carte
/// d'identité, une grille de quatre tuiles, une carte d'activité, une section de réglages
/// d'une seule rangée. Chaque bloc était défendable seul, et l'ensemble ne disait rien : cinq
/// objets de même poids, à lire de haut en bas, sans qu'aucun ne soit le sujet de l'écran.
/// C'est la mise en page d'un formulaire, pas celle d'un tableau de bord.
///
/// L'écran a maintenant **un sujet et deux compléments**. Le panneau du haut porte la série
/// et la courbe des quinze derniers jours : c'est ce qu'on vient regarder, et les deux
/// disent la même chose à deux échelles, donc ils vont ensemble. La bande de chiffres en
/// dessous donne les totaux d'un coup d'œil, en une seule surface au lieu de quatre. Le
/// classement de la semaine pose le volume contre les amis. Reste une rangée, celle des
/// amis, qui n'est pas un chiffre mais une porte.
///
/// **Il n'y a plus de pastille d'initiale.** Un rond coloré avec une lettre dedans est une
/// photo de profil qui n'existe pas : ça occupe la place d'une identité sans en porter une,
/// et ça donne à l'écran l'air d'un gabarit rempli à la va-vite. Le nom d'utilisateur suffit
/// à dire qui l'on est, et il se lit mieux sur une ligne que dans un rond.
struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(AuthController.self) private var auth
    @Environment(SocialService.self) private var social
    @Environment(TabRouter.self) private var router: TabRouter?

    @Environment(CloudSync.self) private var sync: CloudSync?

    @State private var showSettings = false
    @State private var path = NavigationPath()
    @State private var metrics = Metrics.empty

    /// Les statistiques sont calculées une seule fois par rendu. Avant, `streak`,
    /// `bestStreak`, la répartition et les cartes les plus passées reparcouraient le même
    /// historique depuis plusieurs sous-vues pendant l'ouverture du Profil.
    private struct Metrics {
        let courseCount: Int
        let cardCount: Int
        let hasReviews: Bool
        let streak: Int
        let bestStreak: Int
        let knowledge: [(level: StudyStats.KnowledgeLevel, count: Int)]
        /// La maîtrise, la même que la page Progrès du site : la moyenne des solidités.
        let masteryPercent: Int
        let byCourse: [CourseMastery]
        let weak: [ExamReadiness.WeakCard]
        /// Réponses sues du premier coup, sur tous les passages.
        let accuracyPercent: Int
        /// Cartes revues par jour sur les quinze derniers jours, du plus ancien à
        /// aujourd'hui. Le dernier bâton est toujours le jour en cours, même s'il est à zéro :
        /// un graphe qui s'arrêterait à la dernière journée travaillée laisserait croire
        /// qu'on a révisé aujourd'hui.
        let recentDays: [Int]
        /// Total de passages, tous jours confondus.
        let reviewCount: Int

        init(snapshot: ProfileSnapshot) {
            courseCount = snapshot.courseCount
            cardCount = snapshot.cardCount
            hasReviews = !snapshot.reviewDates.isEmpty
            streak = StudyStats.streak(reviewDates: snapshot.reviewDates)
            bestStreak = StudyStats.bestStreak(reviewDates: snapshot.reviewDates)
            knowledge = StudyStats.knowledgeDistribution(from: snapshot.knowledge)
            masteryPercent = snapshot.masteryPercent
            byCourse = snapshot.byCourse
            weak = snapshot.weak
            accuracyPercent = snapshot.accuracyPercent
            recentDays = Metrics.daily(from: snapshot.reviewDates)
            reviewCount = snapshot.reviewDates.count
            ReviewStreakStore.remember(streak: streak, best: bestStreak)
        }

        static let empty = Metrics(
            courseCount: 0,
            cardCount: 0,
            hasReviews: false,
            streak: 0,
            bestStreak: 0,
            knowledge: [],
            masteryPercent: 0,
            byCourse: [],
            weak: [],
            accuracyPercent: 0,
            recentDays: Array(repeating: 0, count: Metrics.window),
            reviewCount: 0
        )

    /// Quinze jours : assez pour voir une habitude, assez peu pour que chaque bâton reste
    /// visible sur la largeur d'un téléphone.
    static let window = 15

    /// Compte les passages par jour sur la fenêtre, en remplissant les jours vides.
    static func daily(
        from dates: [Date],
        calendar: Calendar = MicaboCalendar.shared,
        now: Date = Date()
    ) -> [Int] {
        let today = calendar.startOfDay(for: now)
        var counts: [Date: Int] = [:]
        for date in dates {
            let day = calendar.startOfDay(for: date)
            guard let gap = calendar.dateComponents([.day], from: day, to: today).day,
                  gap >= 0, gap < window
            else { continue }
            counts[day, default: 0] += 1
        }
        return (0..<window).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return counts[day] ?? 0
        }
    }

        private init(
            courseCount: Int,
            cardCount: Int,
            hasReviews: Bool,
            streak: Int,
            bestStreak: Int,
            knowledge: [(level: StudyStats.KnowledgeLevel, count: Int)],
            masteryPercent: Int,
            byCourse: [CourseMastery],
            weak: [ExamReadiness.WeakCard],
            accuracyPercent: Int,
            recentDays: [Int],
            reviewCount: Int
        ) {
            self.recentDays = recentDays
            self.reviewCount = reviewCount
            self.courseCount = courseCount
            self.cardCount = cardCount
            self.hasReviews = hasReviews
            self.streak = streak
            self.bestStreak = bestStreak
            self.knowledge = knowledge
            self.masteryPercent = masteryPercent
            self.byCourse = byCourse
            self.weak = weak
            self.accuracyPercent = accuracyPercent
        }
    }

    /// La maîtrise d'un cours, déjà aplatie : un titre, un emoji, un chiffre.
    struct CourseMastery: Identifiable, Sendable {
        let id: UUID
        let title: String
        let emoji: String
        let percent: Int
        let cards: Int
    }

    /// Ce qu'il faut du profil, déjà aplati : le calcul des totaux peut quitter le
    /// thread principal sans emporter des modèles SwiftData.
    private struct ProfileSnapshot: Sendable {
        let courseCount: Int
        let cardCount: Int
        let reviewDates: [Date]
        let knowledge: [(state: CardState, intervalDays: Double)]
        let masteryPercent: Int
        let byCourse: [CourseMastery]
        let weak: [ExamReadiness.WeakCard]
        let accuracyPercent: Int

        static func load(in context: ModelContext) -> ProfileSnapshot {
            let cards = (try? context.fetch(FetchDescriptor<Flashcard>())) ?? []
            let logs = (try? context.fetch(FetchDescriptor<ReviewLog>())) ?? []
            // Le nombre de cours est un `COUNT` : il ne matérialise aucune ligne. C'est le
            // seul endroit du Profil qui parle des cours **sans** carte, d'où la lecture
            // séparée — la boucle ci-dessous, elle, ne voit que les cours qui en ont.
            let courseCount = (try? context.fetchCount(FetchDescriptor<Course>())) ?? 0
            let now = Date()
            let usable = cards.filter { !$0.isSuspended }

            // Deux lectures de table, puis tout se range en mémoire : ni `course.cards` sur
            // chaque cours ni `card.logs` sur chaque carte, qui rouvrent une requête à chaque
            // fois et faisaient attendre le Profil dès qu'on avait plusieurs cours.
            //
            // Le titre et l'emoji se prennent au passage, sur la première carte qui désigne
            // le cours.
            //
            // **Ce que ça économise, et ce que ça n'économise pas.** Toucher `card.course`
            // faulte la ligne entière — Core Data ne faulte pas par attribut — donc chaque
            // cours ayant au moins une carte active est bel et bien matérialisé, texte
            // compris. Le gain n'est pas là. Il est dans la **fréquence** : le `@Query` qui
            // vivait en tête de ce fichier rematérialisait **toute** la table à **chaque**
            // écriture SwiftData, y compris pendant une session, y compris quand le Profil
            // n'était pas regardé. Cette lecture-ci ne se fait que lorsque le Profil est
            // actif et qu'une de ses clés a bougé, et elle ne touche que les cours qui ont
            // des cartes.
            var cardsByCourse: [UUID: [Flashcard]] = [:]
            var courseOrder: [(id: UUID, title: String, emoji: String)] = []
            for card in usable {
                guard let course = card.course else { continue }
                // Le test précède l'ajout : avec `default:`, la clé existerait déjà et le
                // titre ne serait jamais capté.
                if cardsByCourse[course.id] == nil {
                    courseOrder.append((id: course.id, title: course.title, emoji: course.emoji))
                }
                cardsByCourse[course.id, default: []].append(card)
            }
            let logsByCard = ExamReadiness.group(logs)

            let byCourse: [CourseMastery] = courseOrder.compactMap { entry -> CourseMastery? in
                guard let own = cardsByCourse[entry.id], !own.isEmpty else { return nil }
                return CourseMastery(
                    id: entry.id,
                    title: entry.title,
                    emoji: entry.emoji,
                    percent: ExamReadiness.masteryPercent(of: own, logs: logsByCard, now: now),
                    cards: own.count
                )
            }
            .sorted { $0.percent == $1.percent ? $0.title < $1.title : $0.percent > $1.percent }
            let again = logs.filter { $0.rating == .again }.count
            return ProfileSnapshot(
                courseCount: courseCount,
                cardCount: cards.count,
                reviewDates: logs.map(\.reviewedAt),
                knowledge: cards.map { ($0.state, $0.intervalDays) },
                masteryPercent: ExamReadiness.masteryPercent(of: usable, logs: logsByCard, now: now),
                byCourse: byCourse,
                weak: ExamReadiness.weakCards(in: usable, logs: logsByCard, now: now, limit: 5),
                accuracyPercent: logs.isEmpty ? 0 : Int((Double(logs.count - again) / Double(logs.count) * 100).rounded())
            )
        }
    }

    var body: some View {
        profile(metrics)
    }

    private func profile(_ metrics: Metrics) -> some View {
        NavigationStack(path: $path) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    header
                    streakPanel(metrics)
                    totalsStrip(metrics)
                    masteryPanel(metrics)
                    activityPanel(metrics)
                    weakPanel(metrics)
                    weekRanking
                    friendsRow
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .micaboScreenBackground()
            // Le Profil n'ancre rien en bas : sans `tabBarClearance`, sa dernière
            // rangée se colle à la barre.
            .tabBarClearance()
            // `CourseLedger.stamp` remplace le `courses.count` qui vivait ici : il dit la
            // même chose — la liste des cours a bougé — sans tenir la table pour le dire.
            .task(id: "\(router?.selection == .profile)-\(sync?.epoch ?? 0)-\(CourseLedger.shared.stamp)") {
                // Le `TabView` peut garder un onglet visité : le classement et les
                // totaux ne se relisent que lorsque Profil est réellement actif.
                guard router?.selection == .profile else { return }
                let snapshot = ProfileSnapshot.load(in: modelContext)
                self.metrics = await Task.detached(priority: .utility) {
                    Metrics(snapshot: snapshot)
                }.value
                await social.refreshWeekRanking()
            }
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .profile, depth: path.count)
            .returnsHome(path: $path)
            .navigationDestination(for: FriendsRoute.self) { _ in
                FriendsView { person in
                    path.append(person)
                }
            }
            .navigationDestination(for: SocialService.Person.self) { person in
                FriendProfileView(person: person) { course, author in
                    path.append(SharedCourseRoute(course: course, author: author))
                }
            }
            // Reprendre le cours d'un ami depuis son profil : la fiche reprise s'ouvre là où
            // on était, dans la pile du Profil. On y arrive par le même écran que depuis la
            // bibliothèque, parce que c'est le même geste.
            .navigationDestination(for: SharedCourseRoute.self) { route in
                SharedCourseView(route: route) { adopted in
                    path.append(adopted)
                }
            }
            .navigationDestination(for: Course.self) { course in
                DeckView(course: course)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationCornerRadius(MicaboRadius.sheet)
            }
        }
    }

    // MARK: - En-tête

    /// Un seul accès aux réglages, et c'est celui du coin.
    ///
    /// Il y en avait deux : la roue crantée en haut à droite, et une rangée « Réglages » dans
    /// le bloc « Compte », juste en dessous. Deux chemins vers le même écran font douter de
    /// leur différence. Reste celui qu'on cherche d'instinct, en haut à droite, mais avec la
    /// tuile pastel de la rangée : une roue crantée grise en glyphe système était le seul
    /// endroit de l'app où une icône n'avait pas sa pastille.
    /// **« Ta progression », et qui l'on est en dessous.**
    ///
    /// Le titre de l'onglet disait « Profil », qui est le nom d'un écran de réglages. Cette
    /// page-ci ne montre pas un profil : elle montre ce qu'on a appris. Le nom et le niveau
    /// passent en sous-titre, là où ils informent sans occuper une ligne à eux.
    ///
    /// Les réglages reculent dans une pastille à filet. C'était une tuile pastel de
    /// quarante-quatre points, c'est-à-dire la même forme qu'un deck : elle attirait autant
    /// l'œil qu'une matière.
    private var header: some View {
        MicaboPageHeading(title: i18n.t("ios.profile.title"), subtitle: identityLabel) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 38, height: 38)
                    .overlay(Circle().strokeBorder(MicaboColor.stroke, lineWidth: 1))
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .light))
            .accessibilityLabel(i18n.t("nav.settings"))
        }
        .padding(.top, MicaboSpacing.xs)
    }

    /// **Qui l'on est**, sur une ligne, en tête du panneau.
    ///
    /// Le nom d'utilisateur passe devant l'adresse : c'est lui qu'on dicte à un camarade, et
    /// une adresse électronique affichée sur un écran qu'on montre n'a rien à y faire. Il ne
    /// va pas dans le sur-titre de l'en-tête, qui met ce qu'il reçoit en capitales : un nom
    /// d'utilisateur n'est pas un intitulé de section, et « @MARIE-DUPONT » ne se lit pas.
    private var identityLabel: String {
        if let username = social.username { return Username.display(username) }
        if let name = auth.user?.label.nilIfBlank { return name }
        if auth.isSignedIn { return i18n.t("app.profile.signedIn") }
        return i18n.t("app.profile.offline")
    }

    // MARK: - Le panneau du haut

    /// **La série, en carte chaude.**
    ///
    /// C'est la seule carte de l'app qui ne soit ni blanche ni violette. Une série n'est pas
    /// un compte de cartes, c'est une habitude, et elle se mesure au **record personnel**
    /// plutôt qu'à un objectif qu'on aurait fixé pour l'étudiant : « ton record est de 18,
    /// encore six jours et tu le bats » est une phrase qu'on peut se dire, « objectif 30 »
    /// n'en est pas une.
    ///
    /// Le nom de l'étudiant a quitté ce panneau : il est passé en sous-titre de l'en-tête,
    /// où il informe sans prendre une ligne dans une carte qui parle d'autre chose.
    @ViewBuilder
    private func streakPanel(_ metrics: Metrics) -> some View {
        if !metrics.hasReviews {
            MicaboOutlineCard { firstReviewInvitation }
        } else {
            MicaboStreakCard(
                days: metrics.streak,
                best: max(metrics.bestStreak, metrics.streak),
                title: i18n.t("ios.profile.streakDays", ["count": "\(metrics.streak)"]),
                note: streakNote(metrics)
            )
        }
    }

    /// Ce que la série raconte, selon la distance au record.
    ///
    /// Trois phrases et pas une seule : « ton record est de 18 » n'a rien à dire à qui vient
    /// de le battre, et « encore six jours » n'a pas de sens le premier jour.
    private func streakNote(_ metrics: Metrics) -> String {
        let best = max(metrics.bestStreak, metrics.streak)
        if metrics.streak >= best, best > 1 {
            return i18n.t("ios.profile.streakBest", ["best": "\(best)"])
        }
        let gap = best - metrics.streak
        guard gap > 0 else { return i18n.t("ios.profile.streakStart") }
        return i18n.t("ios.profile.streakToBeat", ["best": "\(best)", "days": "\(gap)"])
    }


    /// Le record ne s'affiche que s'il dépasse la série en cours : le répéter à l'identique
    /// juste à côté n'apprendrait rien, et une série qui *est* le record se lit déjà comme
    /// telle.
    private func streakCaption(_ metrics: Metrics) -> String {
        let unit = metrics.streak == 1
            ? i18n.t("app.profile.streakUnitOne")
            : i18n.t("app.profile.streakUnitMany")
        guard metrics.bestStreak > metrics.streak else { return unit }
        return "\(unit) \(i18n.t("app.profile.streak.record", ["record": "\(metrics.bestStreak)"]))"
    }

    private var firstReviewInvitation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(i18n.t("app.profile.noReviews"))
                .font(MicaboFont.ui(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)

            Text(i18n.t("app.profile.streak.empty"))
                .font(MicaboFont.ui(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Le volume

    /// Le nombre de cartes, et le nombre de cours. Les révisions n'y figurent plus :
    /// elles se lisent déjà dans la série, et dans les cartes les plus passées.
    /// **Trois chiffres, trois encadrés.**
    ///
    /// C'était une seule carte coupée par des filets verticaux, ce qui fait lire un tableau.
    /// Trois encadrés séparés se comptent d'un regard, et chacun peut porter une unité
    /// différente sans que la ligne de base ne se décale.
    private func totalsStrip(_ metrics: Metrics) -> some View {
        HStack(spacing: 9) {
            MicaboStatBox(
                value: "\(metrics.reviewCount)",
                label: i18n.t("ios.profile.reviewedCards")
            )
            MicaboStatBox(
                value: i18n.t("ios.profile.hours", ["hours": "\(estimatedHours(metrics))"]),
                label: i18n.t("ios.profile.ofRevision")
            )
            MicaboStatBox(
                value: "\(metrics.courseCount)",
                label: i18n.t("ios.profile.activeDecks")
            )
        }
    }

    /// Le temps passé, estimé sur le rythme de lecture des cartes plutôt que chronométré.
    ///
    /// L'app ne mesure pas la durée d'une session — elle enregistre des passages, pas des
    /// minutes — et poser un chronomètre pour ce seul chiffre ferait payer une écriture à
    /// chaque carte. `LearningProjection.cardsPerMinute` est la constante que tout le reste
    /// de l'app utilise déjà pour convertir des cartes en temps.
    private func estimatedHours(_ metrics: Metrics) -> Int {
        max(1, Int((Double(metrics.reviewCount) / LearningProjection.cardsPerMinute / 60).rounded()))
    }


    // MARK: - La maîtrise

    /// **Ce qu'on sait, en un chiffre, puis cours par cours** - la page Progrès du site.
    /// La moyenne des solidités, pas la part de cartes acquises : une carte à mi-chemin
    /// compte pour la moitié, sinon la barre reste à zéro deux semaines puis saute.
    /// **« Ce que tu sais », deck par deck.**
    ///
    /// Le grand pourcentage global a disparu : une moyenne sur quatre matières ne dit rien
    /// qu'on puisse utiliser — on ne révise pas « son profil », on révise un deck. Les
    /// rangées portent la barre sous le titre, parce que le sujet de la ligne n'est pas le
    /// deck mais sa progression.
    @ViewBuilder
    private func masteryPanel(_ metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MicaboSectionHeading(
                title: i18n.t("ios.profile.whatYouKnow"),
                subtitle: i18n.t("ios.profile.perDeck")
            ) {
                MicaboSeeAllLink(title: i18n.t("ios.profile.seeAll")) {
                    router?.selection = .decks
                }
            }

            if metrics.byCourse.isEmpty {
                Text(i18n.t("app.home.mastery.empty"))
                    .font(MicaboFont.ui(13.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, MicaboSpacing.xs)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(metrics.byCourse.prefix(5).enumerated()), id: \.element.id) { index, deck in
                        MicaboMasteryRow(
                            emoji: deck.emoji,
                            pastel: MicaboColor.pastel(for: deck.id),
                            title: deck.title,
                            percent: deck.percent
                        ) {
                            router?.selection = .decks
                        }

                        if index < min(5, metrics.byCourse.count) - 1 {
                            MicaboHairline(onCanvas: true)
                        }
                    }
                }
            }
        }
    }

    /// **Les quinze derniers jours**, en bâtons.
    ///
    /// Tous dans le violet pâle sauf le dernier, qui est aujourd'hui. C'est la seule chose
    /// que ce graphe dit vraiment — est-ce que j'ai travaillé aujourd'hui, et comment ça se
    /// compare — et une échelle chiffrée ne l'aurait pas rendue plus lisible.
    @ViewBuilder
    private func activityPanel(_ metrics: Metrics) -> some View {
        if metrics.hasReviews {
            VStack(alignment: .leading, spacing: 12) {
                MicaboSectionHeading(
                    title: i18n.t("ios.profile.lastDays", ["count": "\(Metrics.window)"]),
                    subtitle: i18n.t("ios.profile.averagePerDay", ["count": "\(dailyAverage(metrics))"])
                )

                MicaboActivityBars(values: metrics.recentDays)
            }
        }
    }

    private func dailyAverage(_ metrics: Metrics) -> Int {
        let worked = metrics.recentDays.filter { $0 > 0 }
        guard !worked.isEmpty else { return 0 }
        return worked.reduce(0, +) / worked.count
    }


    /// **Ce qui résiste** : les cartes les plus ratées, celles qui passent en premier dans
    /// les sessions. Absent tant que rien ne résiste - une section vide qui dit « rien »
    /// n'apprend rien.
    @ViewBuilder
    private func weakPanel(_ metrics: Metrics) -> some View {
        if !metrics.weak.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(i18n.t("app.home.weak.title"))
                    .font(MicaboFont.ui(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(i18n.t("app.home.weak.lead"))
                    .font(MicaboFont.ui(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(Array(metrics.weak.enumerated()), id: \.element.id) { index, card in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(FormulaRenderer.stripped(card.front))
                                    .font(MicaboFont.ui(14, weight: .medium))
                                    .foregroundStyle(MicaboColor.ink)
                                    .lineLimit(2)
                                Text(i18n.t("app.home.weak.line", ["again": "\(card.againCount)", "reviews": "\(card.reviews)"]))
                                    .font(MicaboFont.ui(12.5, weight: .regular))
                                    .foregroundStyle(MicaboColor.inkTertiary)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                            if card.isStubborn {
                                MicaboBadge(text: i18n.t("app.plan.sheet.stubborn"), tone: .warm)
                            }
                        }
                        .padding(.vertical, 11)

                        if index < metrics.weak.count - 1 {
                            MicaboHairline()
                        }
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }


    private func knowledgeColor(_ level: StudyStats.KnowledgeLevel, empty: Bool) -> Color {
        if empty { return MicaboColor.surfaceMuted }
        switch level {
        case .new: return MicaboColor.inkTertiary.opacity(0.45)
        case .learning: return MicaboColor.accent
        case .review: return MicaboColor.caution
        case .mastered: return MicaboColor.ink
        }
    }

    // MARK: - Les plus passées
    private func total(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(MicaboFont.number(21))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MicaboFont.ui(11.5, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(MicaboColor.hairline)
            .frame(width: 1, height: 30)
    }

    // MARK: - Classement

    /// Cartes passées depuis lundi, soi et le cercle. Absent s'il n'y a personne
    /// à comparer : un podium d'une seule personne n'est pas un classement.
    @ViewBuilder
    private var weekRanking: some View {
        let rows = social.weekRanking
        if WeekReviewRanking.isVisible(rows) {
            VStack(alignment: .leading, spacing: 12) {
                Text(i18n.t("ios.weekRanking"))
                    .font(MicaboFont.ui(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        rankingLine(row, rank: index + 1)

                        if index < rows.count - 1 {
                            MicaboHairline()
                        }
                    }
                }

                Text(i18n.t("ios.weekRankingHint"))
                    .font(MicaboFont.ui(12, weight: .regular))
                    .foregroundStyle(MicaboColor.inkTertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }

    @ViewBuilder
    private func rankingLine(_ row: WeekReviewRanking.Row, rank: Int) -> some View {
        if row.isMe {
            rankingContent(row, rank: rank)
        } else {
            Button {
                path.append(person(for: row))
            } label: {
                rankingContent(row, rank: rank)
            }
            .buttonStyle(MicaboPressableButtonStyle(dimming: true))
        }
    }

    private func rankingContent(_ row: WeekReviewRanking.Row, rank: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(rank)")
                .font(MicaboFont.number(13, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .monospacedDigit()
                .frame(width: 18, alignment: .leading)

            HStack(spacing: 6) {
                Text(row.handle)
                    .font(MicaboFont.ui(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if row.isMe {
                    Text(i18n.t("ios.youLower"))
                        .font(MicaboFont.ui(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            Text("\(row.passes)")
                .font(MicaboFont.number(14, weight: .semibold))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rankingLabel(row, rank: rank))
        .accessibilityAddTraits(row.isMe ? [] : .isButton)
    }

    private func rankingLabel(_ row: WeekReviewRanking.Row, rank: Int) -> String {
        let who = row.isMe ? i18n.t("ios.youLower") : row.handle
        let cards = MicaboCopy.cards(row.passes)
        return i18n.t("ios.rankingAria", [
            "rank": "\(rank)",
            "who": who,
            "cards": cards
        ])
    }

    private func person(for row: WeekReviewRanking.Row) -> SocialService.Person {
        if let known = social.friends.first(where: { $0.id == row.id }) {
            return known
        }
        return SocialService.Person(
            id: row.id,
            username: row.username ?? "",
            institutionName: nil,
            relation: .friends
        )
    }

    // MARK: - Amis

    /// « Amis » n'est plus une promesse. La rangée dit ce qu'on y trouve et, quand quelqu'un
    /// attend une réponse, elle le compte : une demande d'amitié qui dort dans un écran qu'on
    /// n'ouvre pas est une demande refusée en silence.
    ///
    /// Elle n'a plus d'intitulé « COMPTE » au-dessus d'elle : un intitulé de section pour une
    /// rangée unique annonce une liste qui n'existe pas.
    private var friendsRow: some View {
        MicaboRowGroup(
            rows: [
                MicaboRow(
                    tile: MicaboTile(glyph: .emoji("👋"), background: MicaboColor.tilePastels[2]),
                    title: i18n.t("nav.friends"),
                    subtitle: friendsSubtitle,
                    accessory: friendsAccessory
                ) {
                    guard auth.isSignedIn else {
                        showSettings = true
                        return
                    }
                    path.append(FriendsRoute())
                }
            ]
        )
    }

    private var friendsSubtitle: String {
        guard auth.isSignedIn else { return i18n.t("app.friends.needAccount") }
        if !social.friends.isEmpty {
            return i18n.t("app.friends.friendCount", ["count": "\(social.friends.count)"])
        }
        return i18n.t("app.friends.findClassmates")
    }

    private var friendsAccessory: MicaboRowAccessory {
        guard auth.isSignedIn else { return .chevron }
        let pending = social.pendingCount
        guard pending > 0 else { return .chevron }
        return .badge("\(pending)", .accent)
    }
}

/// La destination « Amis ». Un type vide plutôt qu'une chaîne : deux destinations différentes
/// ne doivent pas pouvoir se confondre dans le même chemin de navigation.
struct FriendsRoute: Hashable {}
