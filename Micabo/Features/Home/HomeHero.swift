import SwiftUI

// MARK: - La rangée du haut

/// **La rangée du haut, sur le ciel** : l'initiale de l'élève (le Profil), « ✦ Pro » pour qui
/// n'est pas abonné, puis l'XP de la semaine et la série.
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
            XPPill(action: onLeague)
            HomeStreakPill(preview: streakPreview, action: onStreak)
        }
    }
}

/// **L'initiale de l'élève**, dans un rond du dégradé de Micabo. Un appui ouvre le Profil
/// quand la barre d'onglets est là pour y aller.
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
        .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 1.5))
        .shadow(color: HomePalette.glowViolet.opacity(0.45), radius: 8, y: 3)
    }
}

/// **La série, sur le ciel** : la même pastille que `StreakPill` — allumée quand aujourd'hui
/// est fait, grise sinon, relue au retour dans l'app —, en verre, et la flamme qui vacille
/// tant qu'elle brûle.
struct HomeStreakPill: View {
    /// Une série donnée d'avance (rendus) ; sinon, celle du registre.
    var preview: StudyStreak.Status?
    let action: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.homeStill) private var still

    @State private var status = StudyStreak.status()
    @State private var flicker = false

    var body: some View {
        let shown = preview ?? status
        let lit = shown.studiedToday
        Button(action: action) {
            HStack(spacing: 3) {
                MicaboIconView(icon: .flame, size: 26)
                    .saturation(lit ? 1 : 0)
                    .opacity(lit ? 1 : 0.55)
                    .scaleEffect(x: flicker ? 0.94 : 1.04, y: flicker ? 1.08 : 0.97, anchor: .bottom)
                    .rotationEffect(.degrees(flicker ? 2.5 : -2.5), anchor: .bottom)
                Text("\(shown.current)")
                    .font(MicaboFont.number(18))
                    .foregroundStyle(lit ? Color(hex: 0xFFB59F) : HomePalette.heroInkSecondary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown.current)))
            }
            .padding(.leading, 7)
            .padding(.trailing, 12)
            .frame(height: 40)
            .homeGlass(Capsule(), fill: lit ? MicaboColor.flame.opacity(0.2) : HomePalette.glass)
        }
        .buttonStyle(HomePressStyle(scale: 0.92))
        .accessibilityLabel(Text(L10n.t("ios.streak.pillA11y", locale: .resolved(), vars: ["count": "\(shown.current)"])))
        .onAppear {
            refresh()
            startFlicker(lit: lit)
        }
        .onChange(of: lit) { _, lit in startFlicker(lit: lit) }
        .onReceive(NotificationCenter.default.publisher(for: .micaboStreakDidChange)) { _ in refresh() }
        // Au retour dans l'app : minuit a pu passer, et la pastille doit se griser.
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
        withAnimation(.easeInOut(duration: 0.42).repeatForever(autoreverses: true)) {
            flicker = true
        }
    }
}

// MARK: - Mika et sa bulle

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

/// **Mika en grand, et sa bulle** : il flotte doucement, salue en arrivant puis de temps en
/// temps, réfléchit pendant qu'un support se lit. La bulle s'écrit lettre après lettre ; un
/// appui dessus fait passer à la phrase suivante.
struct HomeMikaStage: View {
    let lines: [String]
    var isThinking = false
    let motion: HomeMotion

    static let mikaSize: CGFloat = 152

    @State private var index = 0
    @State private var mood: MikaMood = .wave
    @State private var bob = false

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            MikaMascot(
                mood: isThinking ? .think : mood,
                size: Self.mikaSize,
                reactsToTap: true,
                frozenAt: motion.still ? 0.55 : nil,
                // Sur le ciel sombre de Home, le corps noir se perdrait : Mika sort de sa
                // pastille bleue, comme sur l'icône.
                frame: .circle
            )
            .offset(y: bob ? -6 : 4)
            .frame(width: Self.mikaSize, height: Self.mikaSize)

            Button(action: nextLine) {
                HomeSpeechBubble(text: line, motion: motion)
            }
            .buttonStyle(HomePressStyle(scale: 0.97, feedback: .selection))
            .accessibilityLabel(Text(line))
            .accessibilityHint(Text(L10n.t("ios.home2.bubbleHint", locale: .resolved())))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 18)
        }
        .onAppear {
            guard motion.ambient else { return }
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) { bob = true }
        }
        .task {
            // Coucou en arrivant, puis le repos ; un nouveau coucou de temps en temps.
            guard !motion.still else { return }
            try? await Task.sleep(for: .seconds(2.4))
            mood = .idle
            guard motion.ambient else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(11))
                guard !Task.isCancelled else { return }
                mood = .wave
                try? await Task.sleep(for: .seconds(2.2))
                mood = .idle
            }
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

/// **La bulle de Mika** : blanche sur le ciel, sa pointe tournée vers lui. Le texte complet
/// est posé, invisible, sous celui qui s'écrit : la bulle a sa taille finale dès la première
/// lettre et ne pousse rien pendant la frappe.
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
        .foregroundStyle(Color(hex: 0x161933))
        .multilineTextAlignment(.leading)
        .lineSpacing(1)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                HomeBubbleTail()
                    .fill(Color.white)
                    .frame(width: 18, height: 16)
                    .offset(x: -9, y: -14)
            }
            .compositingGroup()
            .shadow(color: HomePalette.glowViolet.opacity(0.45), radius: 16, y: 6)
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

/// La pointe de la bulle, vers Mika, en bas à gauche.
struct HomeBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.maxX * 0.55, y: rect.maxY * 0.7))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.92), control: CGPoint(x: rect.maxX * 0.6, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
