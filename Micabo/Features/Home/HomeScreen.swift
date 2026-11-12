import SwiftUI

// **La Home, telle qu'elle se dessine** (lot 10, HOME.md § 1, maquette `mock13/home.png`).
//
// Elle ne défile pas. De haut en bas : l'en-tête (« Passer en PRO », l'XP, la série) ; la
// pastille jaune de l'examen ; Mika ; **une** phrase tirée du plan du jour, son mot-clé en bleu
// clair ; **une** action en pilule. Les puces d'outils et la barre de saisie sont fixées en
// bas, au-dessus des onglets (`HomeDock`).
//
// Rien ici ne lit la base ni ne navigue : `HomeView` donne les valeurs (`HomeBoard`) et les
// gestes (`HomeActions`), les rendus de la CI dessinent les mêmes vues avec des gestes vides.

// MARK: - Les gestes

/// Les gestes de la Home, pour que l'écran se dessine sans rien savoir de la navigation.
struct HomeActions {
    /// « Passer en PRO » : le paywall.
    var pro: () -> Void = {}
    /// L'XP : la ligue.
    var league: () -> Void = {}
    /// La série : sa feuille.
    var streak: () -> Void = {}
    /// La pastille de l'examen : le Calendrier, ou l'ajout d'un examen.
    var exam: () -> Void = {}
    /// **L'**action de la Home.
    var perform: (HomeAction) -> Void = { _ in }
    /// L'issue discrète sous l'action : « Annuler », « Plus tard ».
    var leave: (HomeExit) -> Void = { _ in }
    /// Une puce d'outil.
    var shortcut: (HomeShortcut) -> Void = { _ in }
    /// Le « + » : la feuille des sources.
    var sources: () -> Void = {}
    /// L'appareil photo de la barre : le scanner.
    var scan: () -> Void = {}
    /// Envoyer le sujet tapé : la leçon se crée.
    var send: () -> Void = {}
    var dismissKeyboard: () -> Void = {}
}

/// Ce que l'en-tête montre à gauche.
enum HomeProEntry: Equatable {
    /// « Passer en [PRO] » : ouvre le paywall.
    case upgrade
    /// Une offre court : la pastille de l'offre (`DiscountChip`) prend la place.
    case offer
    /// Abonné : la seule pastille « PRO », qui ne se touche pas.
    case member

    static func resolve(isPro: Bool, offerIsLive: Bool) -> HomeProEntry {
        if isPro { return .member }
        return offerIsLive ? .offer : .upgrade
    }
}

// MARK: - L'écran

/// **Toute la Home au-dessus de sa barre de saisie** : l'en-tête, puis la scène — la pastille
/// de l'examen, Mika, la phrase, l'action.
///
/// **Mika rétrécit avant que quoi que ce soit ne soit coupé** : la scène se pose avec Mika à
/// 180 pt, puis 150, puis 120 si la place manque (un petit écran, un très grand texte, une
/// phrase sur trois lignes) ; quand le clavier monte, il ne reste que la phrase et son action ;
/// et si même cela ne tient pas, la scène défile. Le choix se fait à la mise en page, sans
/// mesure ni minuterie.
struct HomeScreen: View {
    let board: HomeBoard
    let exam: HomeExamPill
    let entry: HomeProEntry
    /// L'XP de la semaine, celle de la ligue.
    let xp: Int
    var league = ""
    let streak: StudyStreak.Status
    /// Mika a déjà fait coucou depuis le lancement : il ne le refait pas à chaque retour.
    var greeted = false
    /// Les rendus : les secondes qui restent sur l'offre, pour dessiner sa pastille sans horloge.
    var offerRemaining: Int?
    var onGreeted: () -> Void = {}
    let actions: HomeActions

    /// L'air entre l'en-tête et la pastille de l'examen, au plus.
    static let topGap: CGFloat = 56
    /// Les tailles de Mika essayées, de la plus grande à la plus petite.
    static let mikaSizes: [CGFloat] = [180, 150, 120]

    private var mood: MikaMood {
        board.phrase.mood == .wave && greeted ? .idle : board.phrase.mood
    }

    var body: some View {
        VStack(spacing: 0) {
            HomeHeader(
                entry: entry,
                xp: xp,
                league: league,
                streak: streak,
                offerRemaining: offerRemaining,
                onPro: actions.pro,
                onLeague: actions.league,
                onStreak: actions.streak
            )
            .padding(.top, 8)

            Spacer(minLength: 8)
                .frame(maxHeight: Self.topGap)

            ViewThatFits(in: .vertical) {
                stage(Self.mikaSizes[0])
                stage(Self.mikaSizes[1])
                stage(Self.mikaSizes[2])
                stage(nil)
                ScrollView {
                    stage(nil)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.hidden)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Le vide autour de la scène : rien n'y est touchable, l'appui range le clavier.
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: actions.dismissKeyboard)
        }
    }

    private func stage(_ mikaSize: CGFloat?) -> some View {
        HomeStage(
            board: board,
            exam: exam,
            mikaSize: mikaSize,
            mood: mood,
            onGreeted: onGreeted,
            actions: actions
        )
    }
}

// MARK: - L'en-tête

/// **L'en-tête, une ligne sans fond** : à gauche « Passer en [PRO] » (ou la pastille de
/// l'offre, ou « PRO » seul pour un abonné) ; à droite l'XP de la semaine et son éclair bleu
/// (la ligue), la série et sa flamme (sa feuille). Ni avatar, ni cloche, ni anneau : le Profil
/// est un onglet.
///
/// La flamme est orange quand aujourd'hui est fait, grise sinon : la série tient encore, mais
/// elle attend.
struct HomeHeader: View {
    let entry: HomeProEntry
    let xp: Int
    var league = ""
    let streak: StudyStreak.Status
    var offerRemaining: Int?
    let onPro: () -> Void
    let onLeague: () -> Void
    let onStreak: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            proEntry
            Spacer(minLength: 8)
            figure(
                xp,
                symbol: "bolt.fill",
                tone: V3Color.iconBlue,
                label: L10n.t("ios.kx.xp.pillA11y", locale: .resolved(), vars: ["xp": "\(xp)", "league": league]),
                action: onLeague
            )
            figure(
                streak.current,
                symbol: "flame.fill",
                tone: streak.studiedToday ? V3Color.orange : V3Color.ink3,
                label: L10n.t("ios.streak.pillA11y", locale: .resolved(), vars: ["count": "\(streak.current)"]),
                action: onStreak
            )
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(minHeight: V3Metric.topBarHeight)
    }

    @ViewBuilder
    private var proEntry: some View {
        switch entry {
        case .member:
            V3ProBadge()
                .accessibilityLabel(Text(L10n.t("ios.pol.home.proActiveA11y", locale: .resolved())))
        case .offer:
            if let offerRemaining {
                DiscountChipLabel(percent: DiscountOffer.savingsPercent, remaining: offerRemaining)
            } else {
                DiscountChip()
            }
        case .upgrade:
            Button(action: onPro) {
                // Dans une langue longue ou en très grand texte, la pastille seule.
                ViewThatFits(in: .horizontal) {
                    V3ProBadge(L10n.t("ios.home10.pro.prefix", locale: .resolved()))
                    V3ProBadge()
                }
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
            .accessibilityLabel(Text(L10n.t("ios.kx.pro.a11y", locale: .resolved())))
        }
    }

    /// Un chiffre et son pictogramme, dans la couleur de son idée.
    private func figure(_ value: Int, symbol: String, tone: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(verbatim: "\(value)")
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                Image(systemName: symbol)
                    .imageScale(.small)
            }
            .font(V3Font.figure)
            .foregroundStyle(tone)
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: V3Metric.topBarHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
        .accessibilityLabel(Text(label))
    }
}

// MARK: - La scène

/// **La scène** : la pastille de l'examen, Mika, la phrase et son action. Sans taille de Mika
/// (`mikaSize` à `nil`), il ne reste que la phrase et l'action : c'est ce qu'on voit quand le
/// clavier est monté.
struct HomeStage: View {
    let board: HomeBoard
    let exam: HomeExamPill
    let mikaSize: CGFloat?
    let mood: MikaMood
    var onGreeted: () -> Void = {}
    let actions: HomeActions

    var body: some View {
        VStack(spacing: 0) {
            if let mikaSize {
                Button(action: actions.exam) {
                    ExamPillLabel(text: exam.text, isInvitation: !exam.hasExam)
                }
                .buttonStyle(MicaboPressableButtonStyle(feedback: .light))

                MikaMascot(mood: mood, size: mikaSize, onDone: onGreeted)
                    .accessibilityHidden(true)
                    .padding(.top, 22)
            }

            // Deux lignes, le mot-clé en bleu clair ; une langue longue en prend une troisième,
            // et c'est Mika qui lui laisse la place.
            V3Title(board.phrase.marked, size: 32, alignment: .center)
                .padding(.top, mikaSize == nil ? 0 : 10)

            HomeActionArea(board: board, actions: actions)
                .padding(.top, 16)
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .frame(maxWidth: .infinity)
    }
}

/// **Sous la phrase** : l'action en pilule — une seule —, ou la jauge pendant qu'une leçon
/// s'écrit. Une ligne de soutien quand elle dit quelque chose (l'étape de l'écriture, la panne,
/// ce qui a été lu), et l'issue discrète (« Annuler », « Plus tard »).
struct HomeActionArea: View {
    let board: HomeBoard
    let actions: HomeActions

    /// La jauge de l'écriture ne s'étire pas d'un bord à l'autre.
    static let gaugeWidth: CGFloat = 220

    var body: some View {
        VStack(spacing: 10) {
            if let progress = board.progress {
                V3ProgressBar(value: progress)
                    .frame(maxWidth: Self.gaugeWidth)
            }
            if let caption = board.caption {
                Text(caption)
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action = board.action {
                V3Chip(action.title, systemImage: action.symbol, tone: Self.tone(of: action.kind)) {
                    actions.perform(action)
                }
            }
            if let exit = board.exit {
                Button(exit.title) {
                    actions.leave(exit)
                }
                .buttonStyle(V3ButtonStyle(kind: .ghost, fullWidth: false))
            }
        }
    }

    /// La couleur du pictogramme : celle de l'idée.
    static func tone(of kind: HomeAction.Kind) -> Color {
        switch kind {
        case .session, .lesson, .more, .create, .retry: V3Color.iconBlue
        case .cards: V3Color.iconGreen
        case .first, .unlock: V3Color.iconYellow
        }
    }
}
