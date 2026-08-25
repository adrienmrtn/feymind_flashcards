import SwiftData
import SwiftUI

/// Profil, statistiques et réglages.
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
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    header
                    identityCard
                    statsGrid
                    activityCard
                    optionsSection
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

    /// Un seul accès aux réglages, et c'est celui du coin.
    ///
    /// Il y en avait deux : la roue crantée en haut à droite, et une rangée « Réglages » dans
    /// le bloc « Compte », juste en dessous. Deux chemins vers le même écran font douter de
    /// leur différence. Reste celui qu'on cherche d'instinct, en haut à droite, mais avec la
    /// tuile pastel de la rangée : une roue crantée grise en glyphe système était le seul
    /// endroit de l'app où une icône n'avait pas sa pastille.
    private var header: some View {
        MicaboScreenHeader(title: "Profil", eyebrow: streakLabel) {
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

    private var streakLabel: String {
        let streak = StudyStats.streak(reviewDates: reviewDates)
        guard streak > 0 else { return "Aucune série en cours" }
        return "Série de \(streak) jour\(streak > 1 ? "s" : "")"
    }

    private var initial: String {
        let label = auth.user?.label ?? "Étudiant"
        return label.first.map { String($0).uppercased() } ?? "É"
    }

    /// Le nom d'utilisateur passe devant l'adresse : c'est lui qu'on dicte à un camarade, et
    /// une adresse électronique affichée en grand sur un écran qu'on montre n'a rien à y faire.
    private var identitySubtitle: String {
        if let username = social.username { return Username.display(username) }
        if let email = auth.user?.email?.nilIfBlank { return email }
        if auth.isSignedIn { return "Connecté" }
        return "Sans compte · tout reste sur cet appareil"
    }

    /// La carte d'identité, qui dit maintenant quelque chose de vrai.
    ///
    /// Elle affichait « Étudiant » et « Tout reste sur cet appareil » pour tout le monde. La
    /// seconde phrase est devenue fausse le jour où les comptes sont arrivés, et la première
    /// n'a jamais rien dit : elle porte l'initiale, le nom et l'adresse de qui est connecté, et
    /// reste franche quand personne ne l'est.
    private var identityCard: some View {
        HStack(spacing: 14) {
            Text(initial)
                .font(MicaboFont.hanken(21, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)
                .frame(width: 54, height: 54)
                .background(MicaboColor.accentSoft, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(auth.user?.label ?? "Étudiant")
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                Text(identitySubtitle)
                    .font(MicaboFont.rowSubtitle)
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .micaboGroup()
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "Statistiques")

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                statTile("\(StudyStats.streak(reviewDates: reviewDates))", "jours de série")
                statTile(formattedCount(logs.count), "révisions")
                statTile("\(courses.count)", "cours")
                statTile("\(cards.count)", "cartes")
            }
        }
    }

    private func formattedCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func statTile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(MicaboFont.number(26))
                .foregroundStyle(MicaboColor.ink)
            Text(label)
                .font(MicaboFont.hanken(12, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 15)
        .micaboGroup(radius: MicaboRadius.md)
    }

    private var activityCard: some View {
        let counts = StudyStats.dailyCounts(reviewDates: reviewDates, days: 14)
        let maximum = max(counts.max() ?? 1, 1)
        let total = counts.reduce(0, +)

        return VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: "14 derniers jours")

            VStack(alignment: .leading, spacing: 16) {
                Text("\(total) révision\(total > 1 ? "s" : "")")
                    .font(MicaboFont.number(20))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.tight)

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                        let isToday = index == counts.count - 1
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barColor(count: count, isToday: isToday))
                            .frame(height: max(4, CGFloat(count) / CGFloat(maximum) * 56))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 56, alignment: .bottom)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .micaboGroup()
        }
    }

    private func barColor(count: Int, isToday: Bool) -> Color {
        if count == 0 { return MicaboColor.surfaceMuted }
        // Une colonne d'histogramme est une surface, pas un filet : c'est le vert du logo
        // qui la remplit, et celui du jour est le plus franc de la rangée.
        if isToday { return MicaboColor.accentVivid }
        return MicaboColor.accentVivid.opacity(0.4)
    }

    /// « Amis » n'est plus une promesse. La rangée dit ce qu'on y trouve et, quand quelqu'un
    /// attend une réponse, elle le compte : une demande d'amitié qui dort dans un écran qu'on
    /// n'ouvre pas est une demande refusée en silence.
    private var optionsSection: some View {
        MicaboSettingsSection(
            caption: "Compte",
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
