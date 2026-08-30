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
    @Environment(AuthController.self) private var auth
    @Environment(SocialService.self) private var social

    @Query private var courses: [Course]
    @Query private var cards: [Flashcard]
    @Query private var logs: [ReviewLog]

    @State private var showSettings = false
    @State private var path = NavigationPath()

    private var reviewDates: [Date] { logs.map(\.reviewedAt) }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    header
                    streakPanel
                    totalsStrip
                    knowledgeChart
                    mostReviewed
                    weekRanking
                    friendsRow
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.xs)
                .padding(.bottom, MicaboSpacing.md)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            // Le Profil n'ancre rien en bas, mais sa dernière rangée se lisait à travers le
            // verre de la barre : la réserve n'est pas réservée aux pages qui ont un bouton.
            .tabBarClearance()
            .task {
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
        MicaboScreenHeader(title: "Profil") {
            Button {
                showSettings = true
            } label: {
                MicaboTile(glyph: .emoji("⚙️"), background: MicaboColor.tilePastels[0], size: 44)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel("Réglages")
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
        if auth.isSignedIn { return "Compte connecté" }
        return "Sans compte · tout reste sur cet appareil"
    }

    // MARK: - Le panneau du haut

    /// La série, et la courbe qui la porte. Les deux disent la même chose à deux échelles :
    /// séparées en deux blocs, elles se répétaient ; ensemble, la seconde explique la
    /// première.
    private var streakPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(identityLabel)
                .font(MicaboFont.hanken(13, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
                .truncationMode(.middle)

            if logs.isEmpty {
                firstReviewInvitation
            } else {
                streakReadout
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private var streak: Int {
        StudyStats.streak(reviewDates: reviewDates)
    }

    private var bestStreak: Int {
        StudyStats.bestStreak(reviewDates: reviewDates)
    }

    private var streakReadout: some View {
        HStack(alignment: .lastTextBaseline, spacing: 9) {
            Image(systemName: "flame.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(streak > 0 ? MicaboColor.caution : MicaboColor.inkTertiary)

            Text("\(streak)")
                .font(MicaboFont.number(46))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.display)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(streak)))
                .animation(.easeOut(duration: 0.3), value: streak)

            Text(streakCaption)
                .font(MicaboFont.hanken(14, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.bottom, 3)

            Spacer(minLength: 0)
        }
    }

    /// Le record ne s'affiche que s'il dépasse la série en cours : le répéter à l'identique
    /// juste à côté n'apprendrait rien, et une série qui *est* le record se lit déjà comme
    /// telle.
    private var streakCaption: String {
        let unit = streak == 1 ? "jour de série" : "jours de série"
        guard bestStreak > streak else { return unit }
        return "\(unit) · record \(bestStreak)"
    }

    private var firstReviewInvitation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Aucune révision")
                .font(MicaboFont.hanken(19, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(MicaboTracking.tight)

            Text("Ta première carte notée lance la série, et remplit cette courbe.")
                .font(MicaboFont.hanken(13.5, weight: .regular))
                .foregroundStyle(MicaboColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Le volume

    /// Le nombre de cartes, et le nombre de cours. Les révisions n'y figurent plus :
    /// elles se lisent déjà dans la série, et dans les cartes les plus passées.
    private var totalsStrip: some View {
        HStack(spacing: 0) {
            total("\(cards.count)", cards.count == 1 ? "carte" : "cartes")
            columnDivider
            total("\(courses.count)", courses.count == 1 ? "cours" : "cours")
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .micaboGroup(radius: MicaboRadius.md)
    }

    // MARK: - La maîtrise

    private var knowledgeChart: some View {
        let buckets = StudyStats.knowledgeDistribution(cards: cards)
        let peak = max(buckets.map(\.count).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Niveau de connaissance")
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            if cards.isEmpty {
                Text("Tes cartes se rangeront ici : nouvelles, en cours, en révision, parfaitement maîtrisées.")
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

                            Text(bucket.level.label)
                                .font(MicaboFont.hanken(10.5, weight: .medium))
                                .foregroundStyle(MicaboColor.inkTertiary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 132, alignment: .bottom)
                .accessibilityElement()
                .accessibilityLabel(buckets.map { "\($0.count) \($0.level.label)" }.joined(separator: ", "))
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

    private var mostReviewed: some View {
        let top = StudyStats.mostReviewed(from: logs)

        return VStack(alignment: .leading, spacing: 12) {
            Text("Cartes les plus passées")
                .font(MicaboFont.hanken(12, weight: .semibold))
                .foregroundStyle(MicaboColor.inkTertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            if top.isEmpty {
                Text("Note tes premières cartes pour voir celles que tu revois le plus.")
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

                            Spacer(minLength: 8)

                            Text("\(entry.passes) passage\(entry.passes > 1 ? "s" : "")")
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
                Text("Classement de la semaine")
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

                Text("cartes passées depuis lundi")
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

                if row.isMe {
                    Text("toi")
                        .font(MicaboFont.hanken(12, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }
            }

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
        let who = row.isMe ? "toi" : row.handle
        let cards = row.passes == 1 ? "1 carte" : "\(row.passes) cartes"
        return "\(rank). \(who), \(cards)"
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
                    title: "Amis",
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
        guard auth.isSignedIn else { return "Il faut un compte pour ajouter quelqu'un" }
        if !social.friends.isEmpty {
            return social.friends.count == 1 ? "1 ami" : "\(social.friends.count) amis"
        }
        return "Retrouve les cours de tes camarades"
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
