import SwiftUI

/// **La ligue de la semaine** (`docs/refonte-knowunity.md` § 3) : le trophée, le nom de la
/// ligue, ce qui manque pour la suivante et quand la semaine se termine ; puis le classement de
/// l'élève et de ses amis (`friends_league()`), sa ligne en évidence.
///
/// Sans compte, sans ami, ou quand la fonction ne répond pas (pas encore déployée), il ne reste
/// que la ligne de l'élève, avec son XP locale, et deux boutons : « Ajouter des amis » (l'écran
/// Amis) et « Inviter des amis » (un lien vers le site).
struct LeagueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SocialService.self) private var social: SocialService?
    @Environment(AuthController.self) private var auth: AuthController?
    @Environment(XPStore.self) private var injected: XPStore?

    @State private var path = NavigationPath()
    @State private var records: [FriendsLeague.Record] = []
    @State private var loading = true
    @State private var showsSettings = false

    private var xp: XPStore { injected ?? .shared }

    static let inviteURL = URL(string: "https://micabo.app")!

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 22) {
                    topBar
                    hero
                    ranking
                    actions
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
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
            .navigationDestination(for: SharedCourseRoute.self) { route in
                SharedCourseView(route: route) { adopted in
                    path.append(adopted)
                }
            }
            .navigationDestination(for: Course.self) { course in
                LessonPathView(course: course)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showsSettings) {
            SettingsView()
                .presentationCornerRadius(MicaboRadius.sheet)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
        .presentationBackground(MicaboColor.canvas)
    }

    // MARK: L'en-tête

    private var topBar: some View {
        HStack {
            Text(L10n.t("ios.kx.league.title", locale: .resolved()))
                .font(MicaboFont.ui(22, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            MicaboCircleButton(
                systemImage: "xmark",
                style: .light,
                size: 36,
                accessibilityTitle: L10n.t("lesson.circle.close", locale: .resolved())
            ) {
                dismiss()
            }
        }
    }

    private var hero: some View {
        let week = xp.week
        let league = xp.league
        let next = XPMath.nextLeague(for: week)
        return VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LessonTone.yellow.pale)
                    .frame(width: 112, height: 112)
                MicaboIconView(icon: .trophy, size: 82)
            }
            Text(L10n.t("ios.kx.league.name", locale: .resolved(), vars: ["name": league.name]))
                .font(MicaboFont.display(30))
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Text(league.emoji)
                Image(systemName: "bolt.fill")
                    .foregroundStyle(LessonTone.yellow.ink)
                Text(L10n.t("ios.kx.league.weekXP", locale: .resolved(), vars: ["xp": "\(week)"]))
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
            }
            .font(MicaboFont.ui(17, weight: .heavy))

            if let next {
                progressBar(week: week, from: league.floor, to: next.league.floor)
                    .padding(.top, 4)
                Text(L10n.t("ios.kx.league.toNext", locale: .resolved(), vars: ["n": "\(next.missing)", "next": next.league.name]))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(L10n.t("ios.kx.league.top", locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            Label(L10n.t("ios.kx.league.endsIn", locale: .resolved(), vars: ["n": "\(xp.daysLeftInWeek)"]), systemImage: "clock.fill")
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(MicaboColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(MicaboColor.stroke, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func progressBar(week: Int, from floor: Int, to target: Int) -> some View {
        let ratio = target > floor ? Double(week - floor) / Double(target - floor) : 1
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(MicaboColor.track)
                Capsule()
                    .fill(LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, proxy.size.width * min(1, max(0, ratio))))
            }
        }
        .frame(height: 10)
        .padding(.horizontal, 24)
        .accessibilityHidden(true)
    }

    // MARK: Le classement

    private var rows: [FriendsLeague.Row] {
        FriendsLeague.rows(from: records, me: auth?.user?.id, myName: myName, myXP: xp.week)
    }

    private var myName: String {
        if let name = OnboardingPreferences.displayName?.nilIfBlank { return name }
        if let username = social?.username, !username.isEmpty { return Username.display(username) }
        return L10n.t("ios.kx.league.you", locale: .resolved())
    }

    private var ranking: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rankingRow(row, rank: index + 1)
            }
            if loading {
                ProgressView()
                    .padding(.top, 4)
            }
        }
    }

    private func rankingRow(_ row: FriendsLeague.Row, rank: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(MicaboFont.number(15))
                .foregroundStyle(rank <= 3 ? LessonTone.yellow.ink : MicaboColor.inkTertiary)
                .monospacedDigit()
                .frame(width: 24)
            Text(row.initial)
                .font(MicaboFont.ui(16, weight: .heavy))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 38, height: 38)
                .background(MicaboColor.pastel(forName: row.name), in: Circle())
            HStack(spacing: 6) {
                Text(row.name)
                    .font(MicaboFont.ui(16, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                if row.isMe && row.name != L10n.t("ios.kx.league.you", locale: .resolved()) {
                    Text(L10n.t("ios.kx.league.you", locale: .resolved()))
                        .font(MicaboFont.ui(12, weight: .heavy))
                        .foregroundStyle(MicaboColor.accent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(MicaboColor.accentSoft, in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.t("ios.kx.xp.amount", locale: .resolved(), vars: ["n": "\(row.xp)"]))
                .font(MicaboFont.number(16))
                .foregroundStyle(MicaboColor.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(row.isMe ? MicaboColor.accentSoft : MicaboColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(row.isMe ? MicaboColor.accent.opacity(0.5) : MicaboColor.stroke, lineWidth: row.isMe ? 1.5 : 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t("ios.kx.league.rowA11y", locale: .resolved(), vars: [
            "rank": "\(rank)",
            "who": row.name,
            "xp": "\(row.xp)",
        ])))
    }

    // MARK: Les amis

    @ViewBuilder
    private var actions: some View {
        let alone = rows.count <= 1
        VStack(spacing: 12) {
            if alone, !loading {
                Text(L10n.t("ios.kx.league.alone", locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: addFriends) {
                    Label(L10n.t("ios.kx.league.addFriends", locale: .resolved()), systemImage: "person.badge.plus")
                }
                .buttonStyle(LessonPrimaryButtonStyle())
            }
            ShareLink(
                item: Self.inviteURL,
                message: Text(L10n.t("ios.kx.league.inviteMessage", locale: .resolved()))
            ) {
                Label(L10n.t("ios.kx.league.invite", locale: .resolved()), systemImage: "square.and.arrow.up")
            }
            .buttonStyle(MicaboSecondaryButtonStyle())
        }
        .padding(.top, 4)
    }

    private func addFriends() {
        let signedIn = auth?.isSignedIn ?? false
        guard signedIn || (social?.hasDebugFakes ?? false) else {
            showsSettings = true
            return
        }
        path.append(FriendsRoute())
    }

    private func load() async {
        defer { loading = false }
        guard let social, social.isReady else { return }
        do {
            records = try await social.friendsLeague()
        } catch {
            // La fonction n'est peut-être pas encore déployée : la ligne de l'élève suffit.
            records = []
        }
    }
}
