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
/// dessous donne les totaux d'un coup d'œil, en une seule surface au lieu de quatre. Reste
/// une rangée, celle des amis, qui n'est pas un chiffre mais une porte.
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

    /// Quinze jours et non quatorze : deux semaines pleines, plus aujourd'hui. Une fenêtre
    /// paire fait commencer la courbe un jour de semaine différent de celui où elle finit, et
    /// on ne compare alors pas des semaines entre elles.
    private static let activityDays = 15

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    header
                    streakPanel
                    totalsStrip
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
            .toolbar(.hidden, for: .navigationBar)
            .reportsNavigationDepth(for: .profile, depth: path.count)
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
                Haptics.light()
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

            activityChart
                .padding(.top, 4)
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

    // MARK: - La courbe

    private var activityChart: some View {
        let counts = StudyStats.dailyCounts(reviewDates: reviewDates, days: Self.activityDays)
        let maximum = max(counts.max() ?? 1, 1)
        let total = counts.reduce(0, +)

        return VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(barColor(count: count, isToday: index == counts.count - 1))
                        .frame(height: max(4, CGFloat(count) / CGFloat(maximum) * 58))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 58, alignment: .bottom)
            .accessibilityElement()
            .accessibilityLabel("\(total) révisions sur les \(Self.activityDays) derniers jours")

            HStack(spacing: 0) {
                // Ce que la courbe compte, ce sont des **révisions** et non des cartes : la
                // même carte revue trois fois compte trois fois, et le lexique de l'app
                // distingue les deux.
                Text(total == 0 ? "Quinze derniers jours" : "\(total) révision\(total > 1 ? "s" : "") sur quinze jours")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)

                Spacer(minLength: MicaboSpacing.xs)

                Text("aujourd'hui")
                    .font(MicaboFont.hanken(12, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary.opacity(0.7))
            }
        }
    }

    private func barColor(count: Int, isToday: Bool) -> Color {
        if count == 0 { return MicaboColor.surfaceMuted }
        // Une colonne d'histogramme est une surface, pas un filet : c'est le vert du logo
        // qui la remplit, et celui du jour est le plus franc de la rangée.
        if isToday { return MicaboColor.accentVivid }
        return MicaboColor.accentVivid.opacity(0.4)
    }

    // MARK: - La bande de chiffres

    /// **Trois totaux dans une seule surface**, séparés par des filets, et non trois cartes.
    ///
    /// Quatre tuiles blanches en grille donnaient quatre objets à peser, alors qu'il n'y a
    /// qu'une information : où en est la collection. Une bande se lit d'un seul balayage, et
    /// la série n'y figure plus — elle est le sujet du panneau du dessus, elle n'a pas à être
    /// aussi une case de tableau.
    private var totalsStrip: some View {
        HStack(spacing: 0) {
            total(formattedCount(logs.count), logs.count == 1 ? "révision" : "révisions")
            columnDivider
            total("\(courses.count)", courses.count == 1 ? "cours" : "cours")
            columnDivider
            total("\(cards.count)", cards.count == 1 ? "carte" : "cartes")
        }
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity)
        .micaboGroup(radius: MicaboRadius.md)
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

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
                    Haptics.light()
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
