import SwiftUI

// MARK: - La rangée du haut

/// **La rangée du haut, sur la page** : l'initiale de l'élève (le Profil), « ✦ Pro » pour qui
/// n'est pas abonné, puis une seule pastille pour la série et l'XP de la semaine.
struct HomeTopBar: View {
    let name: String?
    let isPro: Bool
    var onProfile: (() -> Void)?
    let onPro: () -> Void
    let onLeague: () -> Void
    let onStreak: () -> Void
    var streakPreview: StudyStreak.Status?

    var body: some View {
        HStack(spacing: 8) {
            HomeAvatar(name: name, action: onProfile)
            if !isPro {
                ProPill(action: onPro)
            }
            Spacer(minLength: 0)
            HomeProgressPill(streakPreview: streakPreview, onStreak: onStreak, onLeague: onLeague)
        }
    }
}

/// **L'initiale de l'élève**, dans un rond bleu Micabo. Un appui ouvre le Profil quand la
/// barre d'onglets est là pour y aller.
struct HomeAvatar: View {
    let name: String?
    var action: (() -> Void)?

    var body: some View {
        if let action {
            Button(action: action) { face }
                .buttonStyle(HomePressStyle(scale: 0.9))
                .accessibilityLabel(Text(L10n.t("ios.home2.profileA11y", locale: .resolved())))
        } else {
            face.accessibilityHidden(true)
        }
    }

    private var face: some View {
        ZStack {
            Circle().fill(HomePalette.brand)
            if let initial = name?.nilIfBlank?.first {
                Text(String(initial).uppercased())
                    .font(MicaboFont.ui(18, weight: .black))
                    .foregroundStyle(Color.white)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: 40, height: 40)
    }
}

/// **« ✦ Pro »**, pour qui n'est pas abonné : la pilule bleue de la marque, qui ouvre le
/// paywall (déclencheur `upgrade`). Une hauteur **minimale** : avec les grandes tailles de
/// texte, le libellé grandit au lieu d'être coupé.
struct ProPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text("✦")
                    .font(.system(size: 13, weight: .black))
                Text(L10n.t("ios.kx.pro.pill", locale: .resolved()))
                    .font(MicaboFont.ui(16, weight: .heavy))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .frame(minHeight: 40)
            .background(HomePalette.brand, in: Capsule())
            .fixedSize()
        }
        .buttonStyle(HomePressStyle(scale: 0.92))
        .accessibilityLabel(Text(L10n.t("ios.kx.pro.a11y", locale: .resolved())))
    }
}

/// **La série et l'XP, dans une seule pastille** : la flamme et ses jours (la feuille de la
/// série), puis l'éclair et l'XP de la semaine (la ligue). Deux appuis distincts, une seule
/// forme : la rangée du haut reste calme.
///
/// La flamme est allumée quand aujourd'hui est fait, grise sinon, et relue au retour dans
/// l'app (minuit a pu passer). L'XP roule de zéro à la première apparition de la session.
struct HomeProgressPill: View {
    /// Une série donnée d'avance (rendus) ; sinon, celle du registre.
    var streakPreview: StudyStreak.Status?
    let onStreak: () -> Void
    let onLeague: () -> Void

    @Environment(XPStore.self) private var injected: XPStore?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.homeStill) private var still

    @State private var status = StudyStreak.status()
    @State private var flicker = false
    /// Le compteur n'a roulé qu'une fois par lancement : revenir sur Home ne le remet pas à zéro.
    private static var hasRolled = false
    @State private var rolling = false

    private var xp: XPStore { injected ?? .shared }

    var body: some View {
        let shown = streakPreview ?? status
        let lit = shown.studiedToday
        let week = xp.week
        let points = rolling ? 0 : week
        HStack(spacing: 0) {
            Button(action: onStreak) {
                HStack(spacing: 3) {
                    MicaboIconView(icon: .flame, size: 22)
                        .saturation(lit ? 1 : 0)
                        .opacity(lit ? 1 : 0.5)
                        .scaleEffect(x: flicker ? 0.95 : 1.03, y: flicker ? 1.06 : 0.98, anchor: .bottom)
                    Text("\(shown.current)")
                        .font(MicaboFont.number(17))
                        .foregroundStyle(lit ? MicaboColor.flameInk : HomePalette.inkTertiary)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(shown.current)))
                }
                .padding(.leading, 10)
                .padding(.trailing, 9)
                .frame(minHeight: 40)
            }
            .buttonStyle(HomePressStyle(scale: 0.92))
            .accessibilityLabel(Text(L10n.t("ios.streak.pillA11y", locale: .resolved(), vars: ["count": "\(shown.current)"])))

            Rectangle()
                .fill(HomePalette.cardStroke)
                .frame(width: 1, height: 18)

            Button(action: onLeague) {
                HStack(spacing: 3) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(HomePalette.bolt)
                    Text("\(points)")
                        .font(MicaboFont.number(17))
                        .foregroundStyle(HomePalette.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(points)))
                }
                .padding(.leading, 9)
                .padding(.trailing, 12)
                .frame(minHeight: 40)
            }
            .buttonStyle(HomePressStyle(scale: 0.92))
            .accessibilityLabel(Text(L10n.t("ios.kx.xp.pillA11y", locale: .resolved(), vars: ["xp": "\(week)", "league": xp.league.name])))
        }
        .background(HomePalette.card, in: Capsule())
        .overlay(Capsule().strokeBorder(HomePalette.cardStroke, lineWidth: 1))
        .fixedSize()
        .animation(.spring(duration: 0.4), value: week)
        .onAppear {
            refresh()
            startFlicker(lit: lit)
            guard !Self.hasRolled, !still, !reduceMotion, week > 0 else { return }
            Self.hasRolled = true
            rolling = true
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85).delay(0.45)) {
                rolling = false
            }
        }
        .onChange(of: lit) { _, lit in startFlicker(lit: lit) }
        .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
    }

    private func refresh() {
        let next = StudyStreak.status()
        guard next != status else { return }
        withAnimation(.spring(duration: 0.4)) { status = next }
    }

    private func startFlicker(lit: Bool) {
        guard lit, !reduceMotion, !still else {
            flicker = false
            return
        }
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            flicker = true
        }
    }
}

// MARK: - Ce que Mika dit

/// **Ce que Mika dit en arrivant** : bonjour selon l'heure, avec le prénom donné au parcours
/// d'accueil, puis trois phrases qui tournent quand on touche la bulle.
enum HomeGreeting {
    enum Moment: String {
        case morning
        case day
        case evening
        case night
    }

    static func moment(hour: Int) -> Moment {
        switch hour {
        case 5..<12: .morning
        case 12..<18: .day
        case 18..<23: .evening
        default: .night
        }
    }

    /// Le prénom : le premier mot de ce que l'élève a donné, rien s'il n'a rien donné.
    static func firstName(_ raw: String?) -> String? {
        guard let raw = raw?.nilIfBlank else { return nil }
        return raw.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    /// Les quatre phrases de la bulle, dans l'ordre où elles passent.
    static func lines(name: String?, moment: Moment, dueCount: Int, locale: UiLocale = .resolved()) -> [String] {
        let hello: String
        if let name {
            hello = L10n.t("ios.home2.hello.\(moment.rawValue)", locale: locale, vars: ["name": name])
        } else {
            hello = L10n.t("ios.home2.helloAnon.\(moment.rawValue)", locale: locale)
        }
        let imports = L10n.t("ios.home2.line.import", locale: locale)
        let goal = L10n.t("ios.home2.line.goal", locale: locale, vars: ["goal": "\(XPRules.dailyGoal)"])
        if dueCount > 0 {
            return [hello, L10n.t("ios.home2.line.due", locale: locale), goal, imports]
        }
        return [hello, imports, goal, L10n.t("ios.home2.line.streak", locale: locale)]
    }
}

// MARK: - La scène

/// **La scène de Home** : la carte bleue de la marque. En haut, la bulle de Mika ; à droite,
/// Mika en buste, qui sort de derrière la barre — elle cache la coupe de son corps, comme le
/// bord bas de l'icône ; en bas, la barre, comme une conversation.
///
/// Mika salue en arrivant, puis se repose ; il fait coucou de temps en temps, réfléchit
/// pendant qu'un support se lit, et sourit quand on touche la bulle.
struct HomeHeroCard: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let lines: [String]
    let motion: HomeMotion
    let onSend: () -> Void
    let onSources: () -> Void
    let onDismissKeyboard: () -> Void

    static let mikaSize: CGFloat = 164
    /// Ce que la barre cache du buste : la coupe, et un peu de corps.
    static let mikaSink: CGFloat = 26

    @State private var index = 0
    @State private var mood: MikaMood = .wave
    @State private var bob = false

    var body: some View {
        VStack(spacing: 0) {
            stage
            HomeComposerBar(composer: composer, focused: focused, onSend: onSend, onSources: onSources)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            if !composer.hasRoom {
                Text(L10n.t("lesson.home.supportsFull", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboStage.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .background {
            ZStack {
                MicaboBrandBackdrop()
                // L'aplat lui-même ne se touche pas : un calque vide le fait, pour ranger le
                // clavier.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onDismissKeyboard)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: MicaboStage.heroRadius, style: .continuous))
        .shadow(color: MicaboBrand.blue.opacity(0.22), radius: 22, y: 12)
        .task {
            // Coucou en arrivant, puis le repos ; un nouveau coucou de temps en temps.
            guard !motion.still else { return }
            try? await Task.sleep(for: .seconds(2.6))
            mood = .idle
            guard motion.ambient else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(14))
                guard !Task.isCancelled else { return }
                mood = .wave
                try? await Task.sleep(for: .seconds(2.6))
                mood = .idle
            }
        }
        .onAppear {
            guard motion.ambient else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bob = true }
        }
    }

    /// La bulle à gauche, Mika à droite, posé sur le haut de la barre.
    private var stage: some View {
        HStack(alignment: .top, spacing: 0) {
            Button(action: nextLine) {
                HomeSpeechBubble(text: line, motion: motion)
            }
            .buttonStyle(HomePressStyle(scale: 0.97, feedback: .selection))
            .accessibilityLabel(Text(line))
            .accessibilityHint(Text(L10n.t("ios.home2.bubbleHint", locale: .resolved())))
            .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: Self.mikaSize - 42)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, minHeight: Self.mikaSize - Self.mikaSink + 8, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            MikaMascot(
                mood: composer.isReading ? .think : mood,
                size: Self.mikaSize,
                reactsToTap: true,
                frozenAt: motion.still ? 0.55 : nil,
                backdrop: .blue
            )
            .offset(x: 4, y: Self.mikaSink + (bob ? -3 : 2))
            // Le toucher fait aussi ranger le clavier : Mika est au-dessus de la barre, là où
            // l'on appuie pour sortir du champ.
            .simultaneousGesture(TapGesture().onEnded { onDismissKeyboard() })
        }
    }

    private var line: String {
        guard !lines.isEmpty else { return "" }
        return lines[index % lines.count]
    }

    private func nextLine() {
        guard lines.count > 1 else { return }
        index = (index + 1) % lines.count
        mood = .happy
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            if mood == .happy { mood = .idle }
        }
    }
}

/// **La bulle de Mika** : blanche sur le bleu, sa pointe tournée vers lui, en bas du côté de
/// Mika. Le texte complet est posé, invisible, sous celui qui s'écrit : la bulle a sa taille
/// finale dès la première lettre et ne pousse rien pendant la frappe.
struct HomeSpeechBubble: View {
    let text: String
    let motion: HomeMotion

    @State private var typed = 0

    var body: some View {
        let shown = motion.ambient ? String(text.prefix(typed)) : text
        ZStack(alignment: .topLeading) {
            Text(text).opacity(0)
            Text(shown)
        }
        .font(MicaboFont.ui(17, weight: .heavy))
        .foregroundStyle(HomePalette.bubbleInk)
        .multilineTextAlignment(.leading)
        .lineSpacing(1)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                HomeBubbleTail()
                    .fill(Color.white)
                    .frame(width: 18, height: 16)
                    .offset(x: 10, y: -10)
            }
            .flipsForRightToLeftLayoutDirection(true)
            .compositingGroup()
            .shadow(color: MicaboBrand.blue900.opacity(0.22), radius: 12, y: 6)
        }
        .task(id: text) {
            guard motion.ambient else { return }
            typed = 0
            let count = text.count
            for step in 1...max(1, count) {
                try? await Task.sleep(for: .milliseconds(22))
                guard !Task.isCancelled else { return }
                typed = step
            }
        }
    }
}

/// La pointe de la bulle, vers Mika, en bas à droite.
struct HomeBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.maxX * 0.45, y: rect.maxY * 0.7))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY * 0.92), control: CGPoint(x: rect.maxX * 0.4, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - La barre

/// **La barre, comme une conversation** : les supports déposés en pastilles au-dessus, puis
/// une seule ligne — le « + » qui ouvre tous les supports, le champ, la flèche d'envoi.
///
/// Ce qui compte n'a pas bougé : les pastilles, le texte d'échec, le plafond de supports,
/// `canSend`, le focus ; la porte du gratuit reste dans `HomeView.send()` et `tapImport`.
struct HomeComposerBar: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let onSend: () -> Void
    /// Le « + » : la feuille des supports.
    let onSources: () -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        @Bindable var composer = composer
        let isFocused = focused.wrappedValue
        VStack(alignment: .leading, spacing: 8) {
            if !composer.supports.isEmpty {
                supportsRow
                if let failure = composer.supports.compactMap(\.failure).last {
                    Text(failure)
                        .font(MicaboFont.ui(13, weight: .bold))
                        .foregroundStyle(MicaboColor.wrongInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                plusButton
                field(draft: $composer.draft)
                sendButton
            }
        }
        .padding(8)
        .background(HomePalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(MicaboBrand.blue200.opacity(isFocused ? 1 : 0), lineWidth: 2)
        )
        .shadow(color: MicaboBrand.blue900.opacity(0.18), radius: 14, y: 6)
        .animation(.easeOut(duration: 0.2), value: isFocused)
        .animation(.spring(duration: 0.3), value: composer.supports.count)
    }

    private var placeholder: String {
        composer.supports.isEmpty
            ? L10n.t("lesson.home.placeholder", locale: .resolved())
            : L10n.t("lesson.home.placeholderWithSupports", locale: .resolved())
    }

    @ViewBuilder
    private var supportsRow: some View {
        let chips = HStack(spacing: 8) {
            ForEach(composer.supports) { support in
                SupportChip(support: support) {
                    withAnimation(.spring(duration: 0.3)) { composer.remove(support.id) }
                }
            }
        }
        if still {
            // Les rendus ne dessinent pas ce qui défile : la même rangée, coupée au bord.
            Color.clear
                .frame(height: 38)
                .overlay(alignment: .leading) { chips.fixedSize() }
                .clipped()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                chips.padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func field(draft: Binding<String>) -> some View {
        Group {
            if still {
                Text(draft.wrappedValue.isEmpty ? placeholder : draft.wrappedValue)
                    .foregroundStyle(draft.wrappedValue.isEmpty ? HomePalette.inkTertiary : HomePalette.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(
                    text: draft,
                    prompt: Text(placeholder).foregroundStyle(HomePalette.inkTertiary),
                    axis: .vertical
                ) {
                    Text(placeholder)
                }
                .foregroundStyle(HomePalette.ink)
                .tint(MicaboColor.accent)
                .lineLimit(1...5)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit(onSend)
            }
        }
        .font(MicaboFont.ui(17, weight: .semibold))
        .padding(.vertical, 9)
        .frame(minHeight: 42, alignment: .leading)
    }

    private var plusButton: some View {
        Button(action: onSources) {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(MicaboColor.accentInk)
                .frame(width: 42, height: 42)
                .background(MicaboColor.accentSoft, in: Circle())
        }
        .buttonStyle(HomePressStyle(scale: 0.88, feedback: .soft))
        .disabled(!composer.hasRoom)
        .opacity(composer.hasRoom ? 1 : 0.45)
        .accessibilityLabel(Text(L10n.t("ios.home2.addSource", locale: .resolved())))
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(composer.canSend ? Color.white : HomePalette.inkTertiary)
                .frame(width: 42, height: 42)
                .background {
                    if composer.canSend {
                        Circle().fill(HomePalette.brand)
                    } else {
                        Circle().fill(HomePalette.track)
                    }
                }
                .scaleEffect(composer.canSend ? 1 : 0.94)
                .animation(.spring(response: 0.35, dampingFraction: 0.6), value: composer.canSend)
        }
        .buttonStyle(HomePressStyle(scale: 0.88, feedback: .medium))
        .disabled(!composer.canSend)
        .accessibilityLabel(Text(L10n.t("lesson.home.send", locale: .resolved())))
    }
}

private extension LessonComposer.Support {
    var failure: String? {
        if case .failed(let message) = state { return message }
        return nil
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
