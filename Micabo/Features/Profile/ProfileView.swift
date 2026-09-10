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

    @Query private var courses: [Course]
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
        let mostReviewed: [(front: String, passes: Int)]
        /// La maîtrise, la même que la page Progrès du site : la moyenne des solidités.
        let masteryPercent: Int
        let byCourse: [CourseMastery]
        let weak: [ExamReadiness.WeakCard]
        /// Réponses sues du premier coup, sur tous les passages.
        let accuracyPercent: Int

        init(snapshot: ProfileSnapshot) {
            courseCount = snapshot.courseCount
            cardCount = snapshot.cardCount
            hasReviews = !snapshot.reviewDates.isEmpty
            streak = StudyStats.streak(reviewDates: snapshot.reviewDates)
            bestStreak = StudyStats.bestStreak(reviewDates: snapshot.reviewDates)
            knowledge = StudyStats.knowledgeDistribution(from: snapshot.knowledge)
            mostReviewed = snapshot.mostReviewed
            masteryPercent = snapshot.masteryPercent
            byCourse = snapshot.byCourse
            weak = snapshot.weak
            accuracyPercent = snapshot.accuracyPercent
            ReviewStreakStore.remember(streak: streak, best: bestStreak)
        }

        static let empty = Metrics(
            courseCount: 0,
            cardCount: 0,
            hasReviews: false,
            streak: 0,
            bestStreak: 0,
            knowledge: [],
            mostReviewed: [],
            masteryPercent: 0,
            byCourse: [],
            weak: [],
            accuracyPercent: 0
        )

        private init(
            courseCount: Int,
            cardCount: Int,
            hasReviews: Bool,
            streak: Int,
            bestStreak: Int,
            knowledge: [(level: StudyStats.KnowledgeLevel, count: Int)],
            mostReviewed: [(front: String, passes: Int)],
            masteryPercent: Int,
            byCourse: [CourseMastery],
            weak: [ExamReadiness.WeakCard],
            accuracyPercent: Int
        ) {
            self.courseCount = courseCount
            self.cardCount = cardCount
            self.hasReviews = hasReviews
            self.streak = streak
            self.bestStreak = bestStreak
            self.knowledge = knowledge
            self.mostReviewed = mostReviewed
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
        let mostReviewed: [(front: String, passes: Int)]
        let masteryPercent: Int
        let byCourse: [CourseMastery]
        let weak: [ExamReadiness.WeakCard]
        let accuracyPercent: Int

        static func load(courses: [Course], in context: ModelContext) -> ProfileSnapshot {
            let cards = (try? context.fetch(FetchDescriptor<Flashcard>())) ?? []
            let logs = (try? context.fetch(FetchDescriptor<ReviewLog>())) ?? []
            let now = Date()
            let usable = cards.filter { !$0.isSuspended }

            // Deux lectures de table, puis tout se range en mémoire : ni `course.cards` sur
            // chaque cours ni `card.logs` sur chaque carte, qui rouvrent une requête à chaque
            // fois et faisaient attendre le Profil dès qu'on avait plusieurs cours.
            var cardsByCourse: [UUID: [Flashcard]] = [:]
            for card in usable {
                guard let courseID = card.course?.id else { continue }
                cardsByCourse[courseID, default: []].append(card)
            }
            let logsByCard = ExamReadiness.group(logs)

            let byCourse: [CourseMastery] = courses.compactMap { course in
                guard let own = cardsByCourse[course.id], !own.isEmpty else { return nil }
                return CourseMastery(
                    id: course.id,
                    title: course.title,
                    emoji: course.emoji,
                    percent: ExamReadiness.masteryPercent(of: own, logs: logsByCard, now: now),
                    cards: own.count
                )
            }
            .sorted { $0.percent == $1.percent ? $0.title < $1.title : $0.percent > $1.percent }
            let again = logs.filter { $0.rating == .again }.count
            let frontByID = Dictionary(cards.map { ($0.id, $0.front) }, uniquingKeysWith: { first, _ in first })
            var counts: [UUID: (front: String, passes: Int)] = [:]
            for (cardID, own) in logsByCard {
                guard let front = frontByID[cardID] else { continue }
                counts[cardID] = (front: front, passes: own.count)
            }
            let top = counts.values
                .sorted { $0.passes == $1.passes ? $0.front < $1.front : $0.passes > $1.passes }
                .prefix(5)
            return ProfileSnapshot(
                courseCount: courses.count,
                cardCount: cards.count,
                reviewDates: logs.map(\.reviewedAt),
                knowledge: cards.map { ($0.state, $0.intervalDays) },
                mostReviewed: Array(top),
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
                    knowledgeChart(metrics)
                    weakPanel(metrics)
                    mostReviewed(metrics)
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
            .task(id: "\(router?.selection == .profile)-\(sync?.epoch ?? 0)-\(courses.count)") {
                // Le `TabView` peut garder un onglet visité : le classement et les
                // totaux ne se relisent que lorsque Profil est réellement actif.
                guard router?.selection == .profile else { return }
                let snapshot = ProfileSnapshot.load(courses: courses, in: modelContext)
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
                CourseSheetView(course: course)
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
    private var header: some View {
        MicaboScreenHeader(title: i18n?.t("nav.profile") ?? "Profil") {
            Button {
                showSettings = true
            } label: {
                MicaboTile(glyph: .emoji("⚙️"), background: MicaboColor.tilePastels[0], size: 44)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(i18n?.t("nav.settings") ?? "Réglages")
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
        if auth.isSignedIn { return i18n?.t("app.profile.signedIn") ?? "Compte connecté" }
        return i18n?.t("app.profile.offline") ?? "Sans compte · tout reste sur cet appareil"
    }

    // MARK: - Le panneau du haut

    /// La série, et la courbe qui la porte. Les deux disent la même chose à deux échelles :
    /// séparées en deux blocs, elles se répétaient ; ensemble, la seconde explique la
    /// première.
    private func streakPanel(_ metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(identityLabel)
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !metrics.hasReviews {
                firstReviewInvitation
            } else {
                streakReadout(metrics)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private func streakReadout(_ metrics: Metrics) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 9) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(metrics.streak > 0 ? MicaboColor.caution : MicaboColor.inkTertiary)

            Text("\(metrics.streak)")
                .font(MicaboFont.number(46))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.display)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(metrics.streak)))
                .animation(.easeOut(duration: 0.3), value: metrics.streak)

            Text(streakCaption(metrics))
                .font(MicaboFont.hanken(14, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 3)
        }
    }

    /// Le record ne s'affiche que s'il dépasse la série en cours : le répéter à l'identique
    /// juste à côté n'apprendrait rien, et une série qui *est* le record se lit déjà comme
    /// telle.
    private func streakCaption(_ metrics: Metrics) -> String {
        let unit = metrics.streak == 1
            ? (i18n?.t("app.profile.streakUnitOne") ?? "jour de série")
            : (i18n?.t("app.profile.streakUnitMany") ?? "jours de série")
        guard metrics.bestStreak > metrics.streak else { return unit }
        return "\(unit) \(i18n?.t("app.profile.streak.record", ["record": "\(metrics.bestStreak)"]) ?? "· record \(metrics.bestStreak)")"
    }

    private var firstReviewInvitation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(i18n?.t("app.profile.noReviews") ?? "Aucune révision")
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)

            Text(i18n?.t("app.profile.streak.empty") ?? "Ta première carte notée lance la série.")
                .font(MicaboFont.hanken(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Le volume

    /// Le nombre de cartes, et le nombre de cours. Les révisions n'y figurent plus :
    /// elles se lisent déjà dans la série, et dans les cartes les plus passées.
    private func totalsStrip(_ metrics: Metrics) -> some View {
        HStack(spacing: 0) {
            total(
                "\(metrics.cardCount)",
                i18n?.t("app.profile.mastery.centerLabel", ["count": "\(metrics.cardCount)"])
                    ?? (metrics.cardCount == 1 ? "carte" : "cartes")
            )
            columnDivider
            total(
                "\(metrics.courseCount)",
                i18n?.t("ios.courseUnit", ["count": "\(metrics.courseCount)"]) ?? "cours"
            )
            // La justesse, comme sur la page Progrès du site : ce qu'on a su du premier coup.
            if metrics.hasReviews {
                columnDivider
                total(
                    "\(metrics.accuracyPercent) %",
                    i18n?.t("app.home.stats.accuracy") ?? "Justesse"
                )
            }
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .micaboGroup(radius: MicaboRadius.md)
    }

    // MARK: - La maîtrise

    /// **Ce qu'on sait, en un chiffre, puis cours par cours** - la page Progrès du site.
    /// La moyenne des solidités, pas la part de cartes acquises : une carte à mi-chemin
    /// compte pour la moitié, sinon la barre reste à zéro deux semaines puis saute.
    private func masteryPanel(_ metrics: Metrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(i18n?.t("app.home.mastery.title") ?? "Maîtrise")
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            if metrics.cardCount == 0 {
                Text(i18n?.t("app.home.mastery.empty") ?? "Importe un cours pour commencer à mesurer.")
                    .font(MicaboFont.hanken(13.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(metrics.masteryPercent)")
                            .font(MicaboFont.number(34, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                            .monospacedDigit()
                        Text("%")
                            .font(MicaboFont.hanken(16, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                    }
                    Text(i18n?.t("app.home.mastery.of", ["count": "\(metrics.cardCount)"]) ?? "sur \(metrics.cardCount) cartes")
                        .font(MicaboFont.hanken(12.5, weight: .medium))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                masteryBar(metrics.masteryPercent, height: 8)

                if !metrics.byCourse.isEmpty {
                    Text(i18n?.t("app.home.mastery.byCourse") ?? "Par cours")
                        .font(MicaboFont.hanken(12, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .padding(.top, 4)

                    VStack(spacing: 10) {
                        ForEach(metrics.byCourse) { entry in
                            HStack(spacing: 10) {
                                Text(entry.emoji)
                                    .font(.system(size: 15))
                                Text(entry.title)
                                    .font(MicaboFont.hanken(13.5, weight: .medium))
                                    .foregroundStyle(MicaboColor.ink)
                                    .lineLimit(1)
                                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                                masteryBar(entry.percent, height: 6)
                                    .frame(width: 64)
                                Text("\(entry.percent) %")
                                    .font(MicaboFont.number(12.5, weight: .semibold))
                                    .foregroundStyle(MicaboColor.inkSecondary)
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private func masteryBar(_ percent: Int, height: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(MicaboColor.surfaceMuted)
                Capsule()
                    .fill(MicaboColor.accent)
                    .frame(width: proxy.size.width * CGFloat(max(2, min(100, percent))) / 100)
            }
        }
        .frame(height: height)
    }

    /// **Ce qui résiste** : les cartes les plus ratées, celles qui passent en premier dans
    /// les sessions. Absent tant que rien ne résiste - une section vide qui dit « rien »
    /// n'apprend rien.
    @ViewBuilder
    private func weakPanel(_ metrics: Metrics) -> some View {
        if !metrics.weak.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(i18n?.t("app.home.weak.title") ?? "Ce qui résiste")
                    .font(MicaboFont.hanken(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(i18n?.t("app.home.weak.lead") ?? "Tes cartes les plus ratées. Elles passent en premier.")
                    .font(MicaboFont.hanken(13, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 0) {
                    ForEach(Array(metrics.weak.enumerated()), id: \.element.id) { index, card in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(FormulaRenderer.stripped(card.front))
                                    .font(MicaboFont.hanken(14, weight: .medium))
                                    .foregroundStyle(MicaboColor.ink)
                                    .lineLimit(2)
                                Text(i18n?.t("app.home.weak.line", ["again": "\(card.againCount)", "reviews": "\(card.reviews)"])
                                    ?? "Ratée \(card.againCount) fois sur \(card.reviews) passages")
                                    .font(MicaboFont.hanken(12.5, weight: .regular))
                                    .foregroundStyle(MicaboColor.inkTertiary)
                            }
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                            if card.isStubborn {
                                MicaboBadge(text: i18n?.t("app.plan.sheet.stubborn") ?? "À revoir", tone: .warm)
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

    private func knowledgeChart(_ metrics: Metrics) -> some View {
        let buckets = metrics.knowledge
        let peak = max(buckets.map(\.count).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text(i18n?.t("app.profile.mastery.label") ?? "Niveau de connaissance")
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            if metrics.cardCount == 0 {
                Text(i18n?.t("app.profile.mastery.empty") ?? "Tes cartes se rangeront ici dès que tu commences à réviser.")
                    .font(MicaboFont.hanken(13.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(buckets, id: \.level) { bucket in
                        VStack(spacing: 6) {
                            Text("\(bucket.count)")
                                .font(MicaboFont.number(13, weight: .semibold))
                                .foregroundStyle(MicaboColor.ink)
                                .monospacedDigit()

                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(knowledgeColor(bucket.level, empty: bucket.count == 0))
                                .frame(height: max(bucket.count > 0 ? 8 : 4, CGFloat(bucket.count) / CGFloat(peak) * 88))

                            Text(bucket.level.label(locale: i18n?.locale ?? .resolved()))
                                .font(MicaboFont.hanken(10.5, weight: .medium))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }
                .frame(height: 132, alignment: .bottom)
                .accessibilityElement()
                .accessibilityLabel(buckets.map {
                    i18n?.t("app.profile.mastery.sliceAria", [
                        "count": "\($0.count)",
                        "label": $0.level.label(locale: i18n?.locale ?? .resolved())
                    ]) ?? "\($0.count) \($0.level.label)"
                }.joined(separator: ", "))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
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

    private func mostReviewed(_ metrics: Metrics) -> some View {
        let top = metrics.mostReviewed

        return VStack(alignment: .leading, spacing: 12) {
            Text(i18n?.t("app.profile.topCards.label") ?? "Cartes les plus passées")
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            if top.isEmpty {
                Text(i18n?.t("app.profile.topCards.empty") ?? "Note tes premières cartes pour voir celles que tu revois le plus.")
                    .font(MicaboFont.hanken(13.5, weight: .regular))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(top.enumerated()), id: \.offset) { index, entry in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(MicaboFont.number(13, weight: .medium))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .monospacedDigit()
                                .frame(width: 18, alignment: .leading)

                            Text(FormulaRenderer.stripped(entry.front))
                                .font(MicaboFont.hanken(14.5, weight: .medium))
                                .foregroundStyle(MicaboColor.ink)
                                .lineLimit(2)
                                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                            Spacer(minLength: 8)

                            Text(i18n?.t("app.profile.passes", ["count": "\(entry.passes)"])
                                ?? "\(entry.passes) passage\(entry.passes > 1 ? "s" : "")")
                                .font(MicaboFont.hanken(12.5, weight: .medium))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 12)

                        if index < top.count - 1 {
                            MicaboHairline()
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private func total(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(MicaboFont.number(21))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MicaboFont.hanken(11.5, weight: .medium))
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
                Text(i18n?.t("ios.weekRanking") ?? "Classement de la semaine")
                    .font(MicaboFont.hanken(12, weight: .semibold))
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

                Text(i18n?.t("ios.weekRankingHint") ?? "cartes passées depuis lundi")
                    .font(MicaboFont.hanken(12, weight: .regular))
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
                    .font(MicaboFont.hanken(14.5, weight: .medium))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                if row.isMe {
                    Text(i18n?.t("ios.youLower") ?? "toi")
                        .font(MicaboFont.hanken(12, weight: .regular))
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
        let who = row.isMe ? (i18n?.t("ios.youLower") ?? "toi") : row.handle
        let cards = MicaboCopy.cards(row.passes)
        return i18n?.t("ios.rankingAria", [
            "rank": "\(rank)",
            "who": who,
            "cards": cards
        ]) ?? "\(rank). \(who), \(cards)"
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
                    title: i18n?.t("nav.friends") ?? "Amis",
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
        guard auth.isSignedIn else { return i18n?.t("app.friends.needAccount") ?? "Il faut un compte pour ajouter quelqu'un" }
        if !social.friends.isEmpty {
            return i18n?.t("app.friends.friendCount", ["count": "\(social.friends.count)"])
                ?? (social.friends.count == 1 ? "1 ami" : "\(social.friends.count) amis")
        }
        return i18n?.t("app.friends.findClassmates") ?? "Retrouve les cours de tes camarades"
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
