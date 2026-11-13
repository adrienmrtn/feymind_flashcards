import SwiftUI

// Les démonstrations jouables du parcours (lot 12). Chacune répond à un blocage, sur la
// matière que l'élève vient de dire la plus dure, et **se joue** : on transforme le cours, on
// retourne la carte, on prend la photo, on choisit sa question, on rend sa copie, on touche
// un jour, on lance une séance. Le bouton du pied joue la démonstration tant qu'elle ne l'a pas
// été, puis devient « Continuer » (`OnbDemoStage`).
//
// Rien n'attend : chaque étape répond à un appui, et l'animation est celle de l'état qui
// change. Rien n'est inventé : la matière, le sujet, l'examen, le temps viennent des
// réponses ; les contenus sont des exemples de son niveau, écrits d'avance.

// MARK: - Ce que les démos disent de l'élève

enum OnbDemo {
    /// **La famille de la matière des démos** : celle de sa matière la plus dure quand elle a
    /// une question d'exemple, sinon celle de la question d'essai.
    static func family(for model: OnboardingModel) -> SampleCard {
        SampleCard.pick(for: model.demoSubjects).card
    }

    /// **La matière des démos**, dans la langue de l'app : la plus dure, sinon celle de la
    /// question d'essai quand l'élève l'a cochée. Aucune : rien, la phrase se dit sans.
    static func subject(for model: OnboardingModel, locale: UiLocale) -> String? {
        if let focus = model.focusSubject {
            return SubjectDisplay.subject(focus, locale: locale)
        }
        let pick = SampleCard.pick(for: model.subjects)
        guard model.subjects.contains(pick.subject) else { return nil }
        return SubjectDisplay.subject(pick.subject, locale: locale)
    }

    /// **Le sujet des démos** : l'exemple de sa matière et de son niveau, le même que celui
    /// que propose la première leçon.
    static func topic(for model: OnboardingModel, locale: UiLocale) -> String {
        FirstLessonStepView.exampleTopic(for: model, locale: locale)
    }

    /// Le même sujet au milieu d'une phrase : « les fonctions affines ». Les langues qui ne
    /// mettent pas de majuscule aux noms communs la retirent.
    static func topicInSentence(for model: OnboardingModel, locale: UiLocale) -> String {
        let text = Self.topic(for: model, locale: locale)
        guard [UiLocale.fr, .es, .en].contains(locale), let first = text.first else { return text }
        return first.lowercased() + text.dropFirst()
    }

    /// L'étiquette d'une démo : le blocage qu'elle soigne, s'il a été coché, sinon son outil.
    static func eyebrow(worry: StudyWorry, tool: String, model: OnboardingModel, locale: UiLocale) -> String {
        guard model.worries.contains(worry) else { return tool }
        return L10n.t("ios.onb10.solutions.quote", locale: locale, vars: ["worry": worry.title(locale: locale)])
    }

    /// Les matières des séances de la semaine : la plus dure d'abord, puis les autres.
    static func sessionSubjects(for model: OnboardingModel, locale: UiLocale) -> [String] {
        var ordered = model.subjects.sorted()
        if let hardest = model.hardestSubject, let index = ordered.firstIndex(of: hardest) {
            ordered.remove(at: index)
            ordered.insert(hardest, at: 0)
        }
        return ordered.map { SubjectDisplay.subject($0, locale: locale) }
    }
}

/// **Un fait qui pop** : un élément qui arrive d'un ressort quand la démonstration avance.
private extension AnyTransition {
    static var onbPop: AnyTransition {
        .asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity)
    }
}

/// La courbe d'un pas de démonstration : le ressort des réussites, un fondu si le mouvement
/// est réduit.
private func onbPlay(_ change: () -> Void) {
    withAnimation(MicaboMotion.resolved(MicaboMotion.celebrate, reduceMotion: UIAccessibility.isReduceMotionEnabled)) {
        change()
    }
}

// MARK: - La leçon

/// **« Ton cours de {matière} devient une leçon. »** On touche « Transformer » : la photo du
/// cours se change en leçon de l'app, sur un sujet de son niveau, avec ses trois façons de
/// travailler.
struct LessonDemoStepView: View {
    /// Pour les rendus : la démonstration déjà jouée.
    var previewPlayed = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    @State private var played = false

    private var isPlayed: Bool { played || previewPlayed }

    private var title: String {
        guard let subject = OnbDemo.subject(for: model, locale: i18n.locale) else {
            return i18n.t("ios.onb12.lesson.titleAny")
        }
        return i18n.t("ios.onb12.lesson.title", ["subject": subject])
    }

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .hardLessons, tool: i18n.t("ios.onb12.lesson.tool"), model: model, locale: i18n.locale),
            title: title,
            say: isPlayed
                ? OnbSay(i18n.t("ios.onb12.lesson.done"), mood: .proud)
                : OnbSay(i18n.t("ios.onb12.lesson.say"), mood: .write),
            playLabel: i18n.t("ios.onb12.lesson.play"),
            isPlayed: isPlayed,
            onPlay: play
        ) {
            ZStack {
                if isPlayed {
                    lesson.transition(.onbPop)
                } else {
                    photo.transition(.opacity)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { play() }
        }
    }

    private func play() {
        guard !isPlayed else { return }
        Haptics.success()
        onbPlay { played = true }
    }

    /// La page de cours prise en photo : le sujet écrit en haut, des lignes de texte, le cadre
    /// de visée.
    private var photo: some View {
        OnbPanel(padding: 18) {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(V3Color.accentBright)
                Text(i18n.t("ios.onb10.story.photo"))
                    .foregroundStyle(V3Color.ink)
            }
            .font(V3Font.label)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(V3Color.soft, in: Capsule())

            VStack(alignment: .leading, spacing: 10) {
                Text(OnbDemo.topic(for: model, locale: i18n.locale))
                    .font(V3Font.heading(22))
                    .foregroundStyle(V3Color.ink2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(0 ..< (compact ? 5 : 8), id: \.self) { index in
                    Capsule()
                        .fill(V3Color.line)
                        .frame(height: 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, CGFloat([0, 40, 12, 70, 24, 0, 56, 90][index % 8]))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
            .overlay {
                StoryViewfinder()
                    .stroke(V3Color.pink, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .padding(6)
            }
        }
    }

    /// La leçon qui en sort : la matière, le sujet, la jauge à zéro, ses trois façons de
    /// travailler.
    private var lesson: some View {
        OnbPanel(padding: 18) {
            if let subject = OnbDemo.subject(for: model, locale: i18n.locale) {
                StoryTag(text: subject, tone: V3Color.accentBright)
            }
            Text(OnbDemo.topic(for: model, locale: i18n.locale))
                .font(V3Font.heading(28))
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            V3ProgressBar(value: 0.08)
                .padding(.bottom, 4)
            mode(.notes, i18n.t("ios.onb11.lesson.notes"), tone: V3Color.iconBlue)
            mode(.quiz, i18n.t("ios.onb11.lesson.quiz"), tone: V3Color.iconPink)
            mode(.cards, i18n.t("ios.onb11.lesson.cards"), tone: V3Color.iconGreen)
        }
    }

    private func mode(_ icon: MicaboIcon, _ text: String, tone: Color) -> some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: icon, size: 26 * 1.35, tint: tone)
                .frame(width: 40, height: 40)
                .background(V3Color.wash(of: tone), in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
            Text(text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(V3Color.ink3)
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(10)
        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
    }
}

// MARK: - Les cartes

/// **Une carte à retourner** (lot 12), sur sa matière : la question, puis la réponse. L'élève
/// dit s'il savait ; Mika dit quand il la lui remontrera — juste avant de l'oublier.
struct CardsDemoStepView: View {
    /// Pour les rendus : la carte déjà retournée, et la réponse donnée.
    var previewFlipped = false
    var previewKnew: Bool?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onbCompact) private var compact

    @State private var flipped = false
    @State private var knew: Bool?

    private var isFlipped: Bool { flipped || previewFlipped }
    private var answer: Bool? { knew ?? previewKnew }

    private var family: SampleCard { OnbDemo.family(for: model) }

    private var say: OnbSay {
        switch answer {
        case true?: OnbSay(i18n.t("ios.onb12.cards.knew"), mood: .happy)
        case false?: OnbSay(i18n.t("ios.onb12.cards.again"), mood: .wink)
        case nil: OnbSay(i18n.t(isFlipped ? "ios.onb12.cards.rate" : "ios.onb12.cards.say"), mood: isFlipped ? .look : .think)
        }
    }

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .forgetting, tool: i18n.t("ios.onb12.cards.tool"), model: model, locale: i18n.locale),
            title: i18n.t("ios.onb12.cards.title"),
            say: say,
            playLabel: i18n.t("ios.onb12.cards.play"),
            isPlayed: isFlipped,
            onPlay: flip
        ) {
            VStack(spacing: 12) {
                ZStack {
                    face(back: false)
                        .opacity(isFlipped ? 0 : 1)
                    face(back: true)
                        .opacity(isFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
                .rotation3DEffect(.degrees(isFlipped && !reduceMotion ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                .contentShape(Rectangle())
                .onTapGesture { flip() }

                if isFlipped {
                    HStack(spacing: 10) {
                        rate(knew: false)
                        rate(knew: true)
                    }
                    .transition(.onbPop)
                }
            }
        }
    }

    /// Une face de la carte : la matière et la question, ou la réponse.
    private func face(back: Bool) -> some View {
        VStack(spacing: 14) {
            if let subject = OnbDemo.subject(for: model, locale: i18n.locale) {
                StoryTag(text: subject, tone: back ? V3Color.green : V3Color.accentBright)
            }
            Spacer(minLength: 0)
            Text(back ? family.demoCardAnswer(locale: i18n.locale) : family.demoCardQuestion(locale: i18n.locale))
                .font(V3Font.heading(back ? 34 : 28))
                .foregroundStyle(back ? V3Color.green : V3Color.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if !back {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                    Text(i18n.t("ios.onb12.cards.tap"))
                }
                .font(V3Font.caption)
                .foregroundStyle(V3Color.ink3)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: compact ? 180 : 290)
        .v3Card(tone: back ? V3Color.green : nil)
    }

    private func rate(knew value: Bool) -> some View {
        Button {
            guard answer == nil else { return }
            if value { Haptics.success() } else { Haptics.soft() }
            onbPlay { knew = value }
        } label: {
            Text(i18n.t(value ? "ios.onb12.cards.yes" : "ios.onb12.cards.no"))
                .font(V3Font.buttonSecondary)
                .foregroundStyle(value ? V3Color.green : V3Color.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(V3TileButtonStyle(selected: answer == value, tone: value ? V3Color.green : nil, radius: V3Metric.radiusInner, feedback: .none))
        .opacity(answer != nil && answer != value ? 0.45 : 1)
    }

    private func flip() {
        guard !isFlipped else { return }
        Haptics.soft()
        withAnimation(MicaboMotion.resolved(MicaboMotion.gentle, reduceMotion: reduceMotion)) { flipped = true }
    }
}

extension SampleCard {
    /// **La carte de la démonstration** : une autre question que celle de l'essai, de la même
    /// famille. Ses réponses courtes se lisent partout ; celles qui ont des mots ont leur clé.
    func demoCardQuestion(locale: UiLocale) -> String {
        switch self {
        case .math: L10n.t("ios.onb12.card.math.q", locale: locale)
        case .chemistry: L10n.t("ios.onb12.card.chemistry.q", locale: locale)
        case .biology: L10n.t("ios.onb12.card.biology.q", locale: locale)
        case .history: L10n.t("ios.onb12.card.history.q", locale: locale)
        case .philosophy: L10n.t("ios.onb12.card.philosophy.q", locale: locale)
        }
    }

    func demoCardAnswer(locale: UiLocale) -> String {
        switch self {
        case .math: "2x"
        case .chemistry: "Na"
        case .biology: L10n.t("ios.onb12.card.biology.a", locale: locale)
        case .history: "1939"
        case .philosophy: L10n.t("ios.onb12.card.philosophy.a", locale: locale)
        }
    }
}

// MARK: - Le scanner

/// **« Un exo qui bloque ? Une photo, et je te guide. »** On prend la photo : le cadre passe au
/// vert, l'exercice est reconnu ; puis chaque appui dévoile l'étape suivante, jusqu'au
/// résultat. On apprend la méthode, pas seulement la réponse.
struct ScanDemoStepView: View {
    /// Pour les rendus : l'étape à montrer (0 : la visée, 3 : le résultat).
    var previewStage: Int?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var stage = 0

    /// 0 : la visée ; 1 : la photo prise, la première étape ; 2 : la deuxième ; 3 : le résultat.
    private var current: Int { previewStage ?? stage }

    private var playLabel: String {
        switch current {
        case 0: i18n.t("ios.onb12.scan.play")
        case 1, 2: i18n.t("ios.onb12.scan.next")
        default: i18n.t("common.continue")
        }
    }

    private var say: OnbSay {
        switch current {
        case 0: OnbSay(i18n.t("ios.onb12.scan.say"), mood: .look)
        case 1, 2: OnbSay(i18n.t("ios.onb12.scan.step"), mood: .think)
        default: OnbSay(i18n.t("ios.onb11.scan.hint"), mood: .proud)
        }
    }

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .homework, tool: i18n.t("ios.onb12.scan.tool"), model: model, locale: i18n.locale),
            title: i18n.t("ios.onb12.scan.title"),
            say: say,
            playLabel: playLabel,
            isPlayed: current >= 3,
            onPlay: next
        ) {
            VStack(spacing: 12) {
                viewfinder
                if current >= 1 {
                    steps.transition(.onbPop)
                }
            }
        }
    }

    private func next() {
        guard current < 3 else { return }
        if current == 2 { Haptics.success() } else { Haptics.medium() }
        onbPlay { stage = current + 1 }
    }

    private var captured: Bool { current >= 1 }

    private var viewfinder: some View {
        VStack(spacing: 10) {
            Text(verbatim: "2x² − 8x + 6 = 0")
                .font(V3Font.display(36))
                .foregroundStyle(V3Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .environment(\.layoutDirection, .leftToRight)
            if captured {
                Label(i18n.t("ios.onb12.scan.recognized"), systemImage: "checkmark.circle.fill")
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.green)
                    .transition(.onbPop)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, captured ? 26 : 64)
        .padding(.horizontal, 20)
        .overlay {
            StoryViewfinder(arm: 26, radius: 12)
                .stroke(captured ? V3Color.green : V3Color.pink, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .padding(8)
        }
        .v3Card()
        .contentShape(Rectangle())
        .onTapGesture { if current == 0 { next() } }
    }

    private var steps: some View {
        OnbPanel(padding: 18) {
            step(1, i18n.t("ios.onb10.story.step1"))
            if current >= 2 {
                step(2, i18n.t("ios.onb10.story.step2")).transition(.onbPop)
            }
            if current >= 3 {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(V3Font.title)
                        .foregroundStyle(V3Color.green)
                        .frame(width: 28)
                    Text(i18n.t("ios.onb10.story.result"))
                        .font(V3Font.heading(26))
                        .foregroundStyle(V3Color.green)
                        .environment(\.layoutDirection, .leftToRight)
                }
                .transition(.onbPop)
            }
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(verbatim: "\(number)")
                .font(V3Font.label)
                .monospacedDigit()
                .foregroundStyle(V3Color.onAccent)
                .frame(width: 28, height: 28)
                .background(V3Color.accent, in: Circle())
            Text(text)
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Le chat avec Mika

/// **« Un truc pas clair ? Demande-moi, même à 23 h. »** Mika ouvre la conversation sur sa
/// matière ; l'élève choisit une des trois questions, et Mika répond comme il le fait dans
/// l'app.
struct ChatDemoStepView: View {
    /// Pour les rendus : la question déjà choisie.
    var previewAsked: Int?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var asked: Int?

    private var chosen: Int? { asked ?? previewAsked }

    private var topic: String { OnbDemo.topicInSentence(for: model, locale: i18n.locale) }

    private func question(_ index: Int) -> String {
        switch index {
        case 0: i18n.t("ios.onb12.chat.q1", ["topic": topic])
        case 1: i18n.t("ios.onb12.chat.q2")
        default: i18n.t("ios.onb12.chat.q3", ["topic": topic])
        }
    }

    private func answer(_ index: Int) -> String {
        switch index {
        case 0: i18n.t("ios.onb12.chat.a1", ["topic": topic])
        case 1: i18n.t("ios.onb12.chat.a2")
        default: i18n.t("ios.onb12.chat.a3", ["topic": topic])
        }
    }

    private var greeting: String {
        guard let subject = OnbDemo.subject(for: model, locale: i18n.locale) else { return i18n.t("ios.onb12.chat.helloAny") }
        return i18n.t("ios.onb12.chat.hello", ["subject": subject])
    }

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .hardLessons, tool: i18n.t("ios.onb12.chat.tool"), model: model, locale: i18n.locale),
            title: i18n.t("ios.onb12.chat.title"),
            say: chosen == nil
                ? OnbSay(i18n.t("ios.onb12.chat.say"), mood: .wink)
                : OnbSay(i18n.t("ios.onb12.chat.done"), mood: .happy),
            playLabel: i18n.t("ios.onb12.chat.play"),
            isPlayed: chosen != nil,
            onPlay: { ask(0) }
        ) {
            OnbPanel(padding: 16) {
                mika(greeting)
                if let chosen {
                    student(question(chosen))
                        .transition(.onbPop)
                    mika(answer(chosen))
                        .transition(.onbPop)
                } else {
                    VStack(alignment: .trailing, spacing: 8) {
                        ForEach(0 ..< 3, id: \.self) { index in
                            Button {
                                ask(index)
                            } label: {
                                Text(question(index))
                                    .font(V3Font.label)
                                    .foregroundStyle(V3Color.accentBright)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(V3Color.accentWash, in: Capsule())
                                    .overlay(Capsule().strokeBorder(V3Color.accent.opacity(0.6), lineWidth: V3Metric.border))
                            }
                            .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
                }
            }
        }
    }

    private func ask(_ index: Int) {
        guard chosen == nil else { return }
        Haptics.medium()
        onbPlay { asked = index }
    }

    private func mika(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            MikaAvatar(size: 32)
            Text(text)
                .font(V3Font.body)
                .foregroundStyle(V3Color.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
        }
        .padding(.trailing, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func student(_ text: String) -> some View {
        Text(text)
            .font(V3Font.bodyStrong)
            .foregroundStyle(V3Color.onAccent)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(V3Color.accent, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
            .padding(.leading, 40)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

// MARK: - L'examen blanc

/// **« Le jour J, tu l'auras déjà fait. »** (lot 12) Une copie d'examen blanc sur sa matière ;
/// on la rend, et la correction tombe : ce qui est juste, ce qui est à revoir, un corrigé
/// pas à pas. Le stress recule quand l'épreuve n'est plus une première fois.
struct ExamDemoStepView: View {
    var previewPlayed = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var played = false

    private var isPlayed: Bool { played || previewPlayed }

    /// Le corrigé de l'exemple : deux exercices justes sur trois.
    static let marks = [true, true, false]

    private var sheetTitle: String {
        let subject = OnbDemo.subject(for: model, locale: i18n.locale) ?? i18n.t("ios.onb12.exam.general")
        if let exam = model.examName(locale: i18n.locale) {
            return i18n.t("ios.onb12.exam.sheet", ["exam": exam, "subject": subject])
        }
        return i18n.t("ios.onb12.exam.sheetAny", ["subject": subject])
    }

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .examStress, tool: i18n.t("ios.onb12.exam.tool"), model: model, locale: i18n.locale),
            title: i18n.t("ios.onb12.exam.title"),
            say: isPlayed
                ? OnbSay(i18n.t("ios.onb12.exam.done"), mood: .happy)
                : OnbSay(i18n.t("ios.onb12.exam.say"), mood: .idle),
            playLabel: i18n.t("ios.onb12.exam.play"),
            isPlayed: isPlayed,
            onPlay: play
        ) {
            OnbPanel(padding: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text(sheetTitle)
                        .font(V3Font.heading(22))
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "timer")
                        .font(V3Font.label)
                        .foregroundStyle(V3Color.ink3)
                }
                ForEach(0 ..< Self.marks.count, id: \.self) { index in
                    exercise(index)
                }
                if isPlayed {
                    HStack(spacing: 10) {
                        Text(i18n.t("ios.onb12.exam.score", ["n": "2", "total": "3"]))
                            .font(V3Font.heading(40))
                            .foregroundStyle(V3Color.ink)
                        Text(i18n.t("ios.onb12.exam.corrected"))
                            .font(V3Font.support)
                            .foregroundStyle(V3Color.ink2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    .transition(.onbPop)
                }
            }
        }
    }

    private func play() {
        guard !isPlayed else { return }
        Haptics.success()
        onbPlay { played = true }
    }

    private func exercise(_ index: Int) -> some View {
        let right = Self.marks[index]
        return HStack(spacing: 12) {
            Text(i18n.t("ios.onb12.exam.ex", ["n": "\(index + 1)"]))
                .font(V3Font.bodyStrong)
                .foregroundStyle(V3Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isPlayed {
                Label(
                    i18n.t(right ? "ios.onb12.exam.right" : "ios.onb12.exam.review"),
                    systemImage: right ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill"
                )
                .font(V3Font.label)
                .foregroundStyle(right ? V3Color.green : V3Color.yellowInk)
                .transition(.onbPop)
            } else {
                Capsule()
                    .fill(V3Color.line)
                    .frame(width: 70, height: 10)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 62)
        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
    }
}

// MARK: - Le calendrier

/// **« {min} min par jour : je range tout dans ton calendrier. »** Juste après le temps choisi :
/// son examen et le temps qu'il reste, la semaine qui commence aujourd'hui, et la séance du
/// jour qu'on touche (sa matière, une façon de travailler, sa durée).
struct PlanDemoStepView: View {
    var now = Date()
    /// Pour les rendus : un jour déjà touché.
    var previewDay: Int?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var day: Int?

    private var selected: Int { day ?? previewDay ?? 0 }
    private var isPlayed: Bool { day != nil || previewDay != nil }

    private var say: OnbSay {
        guard isPlayed else { return OnbSay(i18n.t("ios.onb12.plan.say"), mood: .idle) }
        if let exam = model.examName(locale: i18n.locale) {
            return OnbSay(i18n.t("ios.onb12.plan.done", ["exam": exam]), mood: .happy)
        }
        return OnbSay(i18n.t("ios.onb12.plan.doneAny"), mood: .happy)
    }

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .noStart, tool: i18n.t("ios.onb12.plan.tool"), model: model, locale: i18n.locale),
            title: i18n.t("ios.onb11.plan.ask", ["min": "\(model.minutesPerDay)"]),
            say: say,
            playLabel: i18n.t("ios.onb12.plan.play"),
            isPlayed: isPlayed,
            onPlay: { pick(1) }
        ) {
            OnbPanel(padding: 16) {
                header
                week
                session
                    .id(selected)
                    .transition(.onbPop)
            }
        }
    }

    private func pick(_ index: Int) {
        guard index != day else { return }
        Haptics.selection()
        onbPlay { day = index }
    }

    /// Le prochain examen et le temps qu'il reste ; sans examen daté, « Ta semaine ».
    @ViewBuilder
    private var header: some View {
        if let exam = model.datedExam, let days = model.examDaysLeft(now: now) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(i18n.t("ios.cal.nextExam"))
                        .font(V3Font.caption)
                        .foregroundStyle(V3Color.ink2)
                    Text(exam.choice.title(locale: i18n.locale))
                        .font(V3Font.heading(24))
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(OnbWords.duration(days: days, locale: i18n.locale))
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.yellowInk)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(V3Color.yellowWash, in: Capsule())
            }
        } else {
            Text(i18n.t("ios.onb11.plan.week"))
                .font(V3Font.heading(24))
                .foregroundStyle(V3Color.ink)
        }
    }

    /// Les sept jours qui commencent aujourd'hui, à toucher.
    private var week: some View {
        let days = Self.week(from: now, examDate: model.datedExam?.date, locale: i18n.locale)
        return HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, item in
                Button {
                    pick(index)
                } label: {
                    VStack(spacing: 4) {
                        Text(item.letter)
                            .font(V3Font.caption)
                            .foregroundStyle(index == selected ? V3Color.accentBright : V3Color.ink3)
                        Text(verbatim: "\(item.number)")
                            .font(V3Font.label)
                            .monospacedDigit()
                            .foregroundStyle(index == selected ? V3Color.onAccent : V3Color.ink)
                            .frame(width: 36, height: 36)
                            .background(index == selected ? V3Color.accent : V3Color.soft, in: Circle())
                        Circle()
                            .fill(item.hasEvent ? V3Color.yellow : V3Color.accentBright)
                            .frame(width: 6, height: 6)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .none))
            }
        }
        .environment(\.layoutDirection, i18n.locale.isRightToLeft ? .rightToLeft : .leftToRight)
    }

    /// La séance du jour touché : sa matière (la plus dure d'abord), une façon de travailler,
    /// sa durée, et son minuteur.
    private var session: some View {
        let subjects = OnbDemo.sessionSubjects(for: model, locale: i18n.locale)
        let subject = subjects.isEmpty ? i18n.t("ios.onb11.plan.lesson") : subjects[selected % subjects.count]
        let kinds: [(MicaboIcon, String)] = [
            (.notes, i18n.t("ios.onb12.plan.kind.lesson")),
            (.quiz, i18n.t("ios.onb12.plan.kind.quiz")),
            (.cards, i18n.t("ios.onb12.plan.kind.cards")),
        ]
        let kind = kinds[selected % kinds.count]
        let date = Calendar.current.date(byAdding: .day, value: selected, to: now) ?? now
        return HStack(spacing: 12) {
            OnbIcon(icon: kind.0, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(selected == 0 ? i18n.t("ios.onb12.plan.today") : Self.weekday(date, locale: i18n.locale))
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink2)
                Text(subject)
                    .font(V3Font.heading(22))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(kind.1)
                    .font(V3Font.support)
                    .foregroundStyle(V3Color.ink2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(i18n.t("ios.quiz.time.short", ["n": "\(model.minutesPerDay)"]))
                .font(V3Font.label)
                .foregroundStyle(V3Color.accentBright)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(V3Color.accentWash, in: Capsule())
        }
        .padding(14)
        .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
    }

    /// « lundi », « Montag » : le jour d'une séance.
    static func weekday(_ date: Date, locale: UiLocale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    /// **La semaine qui commence aujourd'hui** : sept jours, l'examen marqué s'il tombe dedans.
    static func week(from start: Date, examDate: Date?, locale: UiLocale, calendar: Calendar = .current) -> [V3WeekDay] {
        let formatter = DateFormatter()
        formatter.locale = locale.foundation
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let isExam = examDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
            return V3WeekDay(
                letter: formatter.string(from: date),
                number: calendar.component(.day, from: date),
                isDone: false,
                isToday: offset == 0,
                hasEvent: isExam
            )
        }
    }
}

// MARK: - La concentration

/// **« Téléphone posé, minuteur lancé. »** (lot 12) Une séance de concentration à sa durée,
/// sur sa matière la plus dure. On la lance : l'anneau se remplit (en accéléré, et c'est
/// écrit), puis la séance est finie.
struct FocusDemoStepView: View {
    var previewDone = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.onbCompact) private var compact

    @State private var fill: Double = 0
    @State private var started = false
    @State private var done = false

    private var isDone: Bool { done || previewDone }

    /// La durée de l'anneau accéléré, en secondes.
    static let fastSeconds = 1.8

    var body: some View {
        OnbDemoStage(
            eyebrow: OnbDemo.eyebrow(worry: .motivation, tool: i18n.t("ios.onb12.focus.tool"), model: model, locale: i18n.locale),
            title: i18n.t("ios.onb12.focus.title"),
            say: isDone
                ? OnbSay(i18n.t("ios.onb12.focus.done"), mood: .celebrate)
                : OnbSay(i18n.t("ios.onb12.focus.say", ["min": "\(model.minutesPerDay)"]), mood: started ? .think : .idle),
            playLabel: i18n.t("ios.onb12.focus.play"),
            isPlayed: isDone,
            onPlay: start
        ) {
            OnbPanel(padding: 18) {
                ZStack {
                    Circle()
                        .stroke(V3Color.line, lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: isDone ? 1 : fill)
                        .stroke(isDone ? V3Color.green : V3Color.accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(verbatim: isDone ? "0:00" : "\(model.minutesPerDay):00")
                            .font(V3Font.display(46))
                            .monospacedDigit()
                            .foregroundStyle(V3Color.ink)
                            .contentTransition(.numericText(countsDown: true))
                            .environment(\.layoutDirection, .leftToRight)
                        if let subject = OnbDemo.subject(for: model, locale: i18n.locale) {
                            Text(subject)
                                .font(V3Font.label)
                                .foregroundStyle(V3Color.ink2)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(width: compact ? 170 : 210, height: compact ? 170 : 210)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                Label(i18n.t(isDone ? "ios.onb12.focus.finished" : "ios.onb12.focus.fast"), systemImage: isDone ? "checkmark.circle.fill" : "hare.fill")
                    .font(V3Font.caption)
                    .foregroundStyle(isDone ? V3Color.green : V3Color.ink3)
                    .frame(maxWidth: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture { start() }
        }
    }

    private func start() {
        guard !started, !isDone else { return }
        started = true
        Haptics.medium()
        let curve = reduceMotion ? MicaboMotion.reduced : MicaboMotion.fill(seconds: Self.fastSeconds)
        withAnimation(curve, completionCriteria: .logicallyComplete) {
            fill = 1
        } completion: {
            Haptics.success()
            onbPlay { done = true }
        }
    }
}
