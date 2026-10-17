import SwiftData
import SwiftUI

/// **Home** (`docs/refonte-parcours.md` § 3) : la série en haut à droite, la grande question
/// au centre, la barre « comme une IA » avec Mika perché dessus — c'est elle qu'on voit
/// d'abord —, les cinq supports en petit dessous, trois petits chiffres mesurés, et
/// « Reprendre ».
///
/// **Un appui à côté du champ range le clavier.** Le titre, la rangée du haut, les chiffres et
/// tout le vide entre les blocs le rendent ; les boutons gardent leur appui, parce qu'un geste
/// posé sur un parent passe après ceux de ses enfants. Le geste n'est jamais posé sur la barre
/// elle-même : un appui dans le champ doit l'ouvrir, pas le refermer aussitôt.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Query(sort: \Course.createdAt, order: .reverse) private var courses: [Course]

    @State private var path = NavigationPath()
    @State private var composer = LessonComposer()
    @State private var importRequest: LessonComposer.Kind?
    @State private var creating = false
    @State private var paywall: PaywallTrigger?
    @State private var showsStreak = false
    @FocusState private var focused: Bool

    private var isPro: Bool { pro?.isPro ?? true }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    header
                    HomeComposerBar(
                        composer: composer,
                        focused: $focused,
                        isPro: isPro,
                        isThinking: composer.isReading,
                        onImport: tapImport,
                        onSend: send
                    )
                    .padding(.top, HomePerch.height)
                    HomeStatsRow(stats: HomeStats(courses: courses))
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissKeyboard)
                    if let resume = ResumeTarget.pick(from: courses) {
                        ResumeCard(course: resume.0, target: resume.1) {
                            path.append(resume.0)
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Le vide entre les blocs et autour d'eux : rien n'y est touchable, l'appui
                // tombe sur ce fond.
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(perform: dismissKeyboard)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .background(MicaboColor.canvas.ignoresSafeArea())
            .tabBarClearance()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Course.self) { course in
                LessonPathView(course: course)
            }
            .lessonImportPickers(composer, request: $importRequest)
            .fullScreenCover(isPresented: $creating) {
                LessonCreationFlow(composer: composer) { course in
                    creating = false
                    composer.reset()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { path.append(course) }
                } onCancel: {
                    creating = false
                }
            }
            .micaboPaywall($paywall)
            .sheet(isPresented: $showsStreak) {
                StreakSheet(onStudy: study)
            }
            // Le journal des cartes rejoint la série une fois : un ancien compte retrouve la
            // sienne dans la pastille dès l'ouverture.
            .task { StudyStreak.adoptReviewHistoryIfNeeded(in: modelContext) }
        }
        .reportsNavigationDepth(for: .today, depth: path.count)
        .returnsHome(path: $path)
    }

    /// **La rangée du haut et la question**, centrées l'une sur l'autre. La série se pose à
    /// droite, sur sa propre ligne : elle ne pousse ni le titre ni Mika.
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer(minLength: 0)
                StreakPill {
                    dismissKeyboard()
                    showsStreak = true
                }
            }
            HomeTitle()
                .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismissKeyboard)
    }

    private func dismissKeyboard() {
        focused = false
    }

    /// « Faire une leçon », depuis la feuille de la série : la leçon en cours s'il y en a une,
    /// sinon la barre, prête à écrire.
    private func study() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if let resume = ResumeTarget.pick(from: courses) {
                path.append(resume.0)
            } else {
                focused = true
            }
        }
    }

    /// PDF, Photo, Audio et YouTube sont Pro ; un texte collé est la leçon offerte.
    private func tapImport(_ kind: LessonComposer.Kind) {
        if kind != .text && !isPro {
            focused = false
            paywall = .generateCourse
            return
        }
        importRequest = kind
    }

    private func send() {
        guard composer.canSend else { return }
        if let trigger = LessonAllowance.gate(isPro: isPro, source: composer.source, courses: courses) {
            focused = false
            paywall = trigger
            return
        }
        focused = false
        creating = true
    }
}

// MARK: - La question

/// **« Qu'est-ce que tu veux apprendre aujourd'hui ? »**, en grand, le mot « apprendre » dans
/// une couleur qui ressort. Le mot est marqué `**…**` dans le catalogue, dans chaque langue.
///
/// **Centrée, sur toute la largeur de la barre.** Calée à gauche, avec Mika perché à droite
/// en dessous, la question avait l'air poussée de côté : deux lignes de longueurs inégales
/// contre un bord, un personnage contre l'autre, et un grand vide entre les deux. Centrée,
/// elle tombe dans l'axe de Mika et de la barre, et l'écran se lit de haut en bas sur une
/// seule ligne.
struct HomeTitle: View {
    var body: some View {
        Self.text(L10n.t("lesson.home.title", locale: .resolved()))
            .font(MicaboFont.display(34))
            .tracking(MicaboTracking.tight)
            .foregroundStyle(MicaboColor.ink)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    /// Le texte, le mot marqué en dégradé bleu-violet.
    static func text(_ source: String) -> Text {
        let parts = source.components(separatedBy: "**")
        var out = Text("")
        for (index, part) in parts.enumerated() where !part.isEmpty {
            if index % 2 == 1 {
                out = out + Text(part).foregroundStyle(
                    LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .leading, endPoint: .trailing)
                )
            } else {
                out = out + Text(part)
            }
        }
        return out
    }
}

/// **Mika, perché sur la barre** : ses pattes et son ombre posées sur le bord haut, au milieu,
/// sous la question. Il fait coucou, puis attend ; il réfléchit pendant qu'un support se lit.
struct HomePerch: View {
    var isThinking = false

    static let size: CGFloat = 96
    /// La place qu'il prend au-dessus de la barre : sa taille, moins ce qui se pose dessus.
    static let height: CGFloat = size - sink
    /// Ce qui descend sous le bord : les pattes et l'ombre, pour qu'il soit assis, pas posé à
    /// côté.
    static let sink: CGFloat = 10

    @State private var mood: MikaMood = .wave

    var body: some View {
        MikaMascot(mood: isThinking ? .think : mood, size: Self.size, reactsToTap: true)
            .frame(width: Self.size, height: Self.size)
            .task {
                try? await Task.sleep(for: .seconds(2.4))
                mood = .idle
            }
    }
}

// MARK: - La barre

/// La barre « comme une IA » : les supports déposés en pastilles au-dessus, le champ, la
/// flèche d'envoi, et les cinq imports dessous.
struct HomeComposerBar: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let isPro: Bool
    var isThinking = false
    let onImport: (LessonComposer.Kind) -> Void
    let onSend: () -> Void

    var body: some View {
        @Bindable var composer = composer
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                if !composer.supports.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(composer.supports) { support in
                                SupportChip(support: support) {
                                    withAnimation(.spring(duration: 0.3)) { composer.remove(support.id) }
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .scrollClipDisabled()
                    if let failure = composer.supports.compactMap(\.failure).last {
                        Text(failure)
                            .font(MicaboFont.ui(13, weight: .bold))
                            .foregroundStyle(MicaboColor.wrongInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(alignment: .bottom, spacing: 10) {
                    TextField(
                        composer.supports.isEmpty
                            ? L10n.t("lesson.home.placeholder", locale: .resolved())
                            : L10n.t("lesson.home.placeholderWithSupports", locale: .resolved()),
                        text: $composer.draft,
                        axis: .vertical
                    )
                    .font(MicaboFont.ui(20, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(3...6)
                    .focused(focused)
                    .submitLabel(.send)
                    .onSubmit(onSend)
                    .padding(.vertical, 10)

                    Button(action: onSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .frame(width: 52, height: 52)
                            .background {
                                if composer.canSend {
                                    Circle().fill(LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .topLeading, endPoint: .bottomTrailing))
                                } else {
                                    Circle().fill(MicaboColor.inkTertiary)
                                }
                            }
                            .shadow(color: MicaboColor.accent.opacity(composer.canSend ? 0.35 : 0), radius: 10, y: 5)
                    }
                    .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
                    .disabled(!composer.canSend)
                    .accessibilityLabel(Text(L10n.t("lesson.home.send", locale: .resolved())))
                }
            }
            // **La barre est ce qui ressort le plus** : haute, bordée du dégradé de l'app, avec
            // un halo bleu qui s'allume quand on écrit.
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.vertical, 12)
            .frame(minHeight: 132, alignment: .bottom)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [MicaboColor.accent, MicaboColor.keyword], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: focused.wrappedValue ? 3 : 2
                    )
            )
            .shadow(color: MicaboColor.accent.opacity(focused.wrappedValue ? 0.3 : 0.18), radius: focused.wrappedValue ? 22 : 16, y: 8)
            .animation(.easeOut(duration: 0.25), value: focused.wrappedValue)
            .overlay(alignment: .top) {
                HomePerch(isThinking: isThinking)
                    .offset(y: -HomePerch.height)
                    // Le toucher le fait sauter de joie, et range aussi le clavier : il est
                    // au-dessus de la barre, là où l'on appuie pour sortir du champ.
                    .simultaneousGesture(TapGesture().onEnded { focused.wrappedValue = false })
            }
            .animation(.spring(duration: 0.3), value: composer.supports.count)

            ImportGrid(isPro: isPro, enabled: composer.hasRoom, onImport: onImport)

            if !composer.hasRoom {
                Text(L10n.t("lesson.home.supportsFull", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private extension LessonComposer.Support {
    var failure: String? {
        if case .failed(let message) = state { return message }
        return nil
    }
}

/// **Les cinq supports, en petit, sous la barre** : une ligne de pastilles, l'icône 3D et
/// son nom. La barre reste ce qu'on voit d'abord ; un support Pro porte sa petite couronne
/// pour qui n'est pas abonné.
struct ImportGrid: View {
    let isPro: Bool
    var enabled = true
    let onImport: (LessonComposer.Kind) -> Void

    private static let kinds: [LessonComposer.Kind] = [.pdf, .photo, .audio, .youtube, .text]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.kinds, id: \.self) { kind in
                ImportChip(kind: kind, locked: kind != .text && !isPro, enabled: enabled) { onImport(kind) }
            }
        }
    }
}

/// Une pastille d'import : l'icône 3D, le nom dessous, en petit.
struct ImportChip: View {
    let kind: LessonComposer.Kind
    var locked = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                MicaboIconView(icon: kind.icon, size: 30, dimmed: !enabled)
                Text(L10n.t(kind.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .heavy))
                    .foregroundStyle(enabled ? MicaboColor.inkSecondary : MicaboColor.inkTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(MicaboColor.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(LessonTone.yellow.ink)
                        .padding(4)
                        .background(LessonTone.yellow.pale, in: Circle())
                        .offset(x: 3, y: -3)
                        .accessibilityLabel(Text("Pro"))
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(!enabled)
    }
}

/// Une tuile d'import : son icône 3D, son nom, et pour les grandes, ce qu'on y met.
struct ImportButton: View {
    enum Size {
        case large
        case medium
    }

    let kind: LessonComposer.Kind
    var size: Size = .medium
    var locked = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: size == .large ? .leading : .center, spacing: size == .large ? 10 : 8) {
                MicaboIconView(icon: kind.icon, size: size == .large ? 58 : 46, dimmed: !enabled)
                VStack(alignment: size == .large ? .leading : .center, spacing: 2) {
                    Text(L10n.t(kind.titleKey, locale: .resolved()))
                        .font(MicaboFont.ui(size == .large ? 19 : 16, weight: .heavy))
                        .foregroundStyle(enabled ? MicaboColor.ink : MicaboColor.inkTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if size == .large {
                        Text(L10n.t(kind.titleKey + "Sub", locale: .resolved()))
                            .font(MicaboFont.ui(13, weight: .semibold))
                            .foregroundStyle(MicaboColor.inkSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(size == .large ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: size == .large ? 150 : 112, alignment: size == .large ? .topLeading : .center)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1.5))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(MicaboColor.stroke)
                    .offset(y: 4)
            )
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(LessonTone.yellow.ink)
                        .padding(6)
                        .background(LessonTone.yellow.pale, in: Circle())
                        .padding(10)
                        .accessibilityLabel(Text("Pro"))
                }
            }
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(!enabled)
    }
}

/// Un support déposé : son icône, son nom, et où en est sa lecture.
struct SupportChip: View {
    let support: LessonComposer.Support
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if support.state == .reading {
                    ProgressView().controlSize(.small)
                } else {
                    MicaboIconView(icon: support.kind.icon, size: 22)
                }
            }
            .frame(width: 24, height: 24)
            Text(support.title)
                .font(MicaboFont.ui(14, weight: .bold))
                .foregroundStyle(isFailed ? MicaboColor.wrongInk : MicaboColor.ink)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: isFailed ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isFailed ? MicaboColor.wrong : MicaboColor.inkTertiary)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.home.removeSupport", locale: .resolved())))
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .background(isFailed ? MicaboColor.wrongSoft : MicaboColor.canvas, in: Capsule())
        .overlay(Capsule().strokeBorder(isFailed ? MicaboColor.wrong.opacity(0.4) : MicaboColor.stroke, lineWidth: 1))
        .transition(.scale.combined(with: .opacity))
    }

    private var isFailed: Bool {
        if case .failed = support.state { return true }
        return false
    }
}

// MARK: - Les chiffres

/// X h de révision · X leçons apprises · X flashcards apprises : trois petites pastilles de
/// la même taille, sous les imports. Elles disent où on en est sans prendre la place.
struct HomeStatsRow: View {
    let stats: HomeStats

    var body: some View {
        HStack(spacing: 8) {
            pill(stats.formattedTime(), L10n.t("lesson.home.statTime", locale: .resolved()), icon: .hourglass)
            pill(String(stats.learnedLessons), L10n.t("lesson.home.statLessons", locale: .resolved()), icon: .diploma)
            pill(String(stats.learnedCards), L10n.t("lesson.home.statCards", locale: .resolved()), icon: .cards)
        }
    }

    private func pill(_ value: String, _ label: String, icon: MicaboIcon) -> some View {
        HStack(spacing: 8) {
            MicaboIconView(icon: icon, size: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(MicaboFont.number(16))
                    .foregroundStyle(MicaboColor.ink)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(MicaboFont.ui(11, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 62, maxHeight: 62, alignment: .leading)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
    }
}

// MARK: - Reprendre

/// La dernière leçon ouverte : son anneau, son titre, le cercle où elle attend.
struct ResumeCard: View {
    let course: Course
    let target: ResumeTarget
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(MicaboColor.track, lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: max(0.02, CGFloat(target.percent) / 100))
                        .stroke(course.tone.vivid, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    MicaboIconView(icon: course.icon, size: 36)
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t("lesson.home.resume", locale: .resolved()))
                        .font(MicaboFont.small)
                        .tracking(MicaboTracking.caps)
                        .textCase(.uppercase)
                        .foregroundStyle(course.tone.ink)
                    Text(target.title)
                        .font(MicaboFont.label)
                        .foregroundStyle(MicaboColor.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(subtitle)
                        .font(MicaboFont.ui(14, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MicaboColor.onInk)
                    .frame(width: 40, height: 40)
                    .background(MicaboColor.ink, in: Circle())
            }
            .padding(16)
            .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .micaboElevation(.card)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
    }

    private var subtitle: String {
        guard let number = target.circleNumber, let title = target.circleTitle else {
            return L10n.t("lesson.home.resumeDone", locale: .resolved())
        }
        return L10n.t("lesson.home.resumeCircle", locale: .resolved(), vars: ["n": String(number), "title": title])
    }
}
