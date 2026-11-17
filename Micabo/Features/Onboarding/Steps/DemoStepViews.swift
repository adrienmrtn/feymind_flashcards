import SwiftUI

// Les démonstrations jouables du parcours (lot 12, réécrites au lot 15) : la leçon (toutes les
// sources convergent vers une leçon), le scanner (un exercice de maths de sa classe), sa
// semaine au calendrier, une séance de concentration. Chacune **se joue** : le bouton du pied
// joue la démonstration tant qu'elle ne l'a pas été, puis devient « Continuer »
// (`OnbDemoStage`). Pas de bulle (lot 15) : un titre, le morceau d'app en grand au centre
// optique, le bouton.
//
// Rien n'attend : chaque étape répond à un appui, et l'animation est celle de l'état qui
// change. Rien n'est inventé : la matière, le sujet, l'examen, le temps viennent des
// réponses ; les contenus sont des exemples de son niveau, écrits d'avance et vérifiés.

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

    /// **Le titre de la leçon de la démo** (lot 16 : aucun titre de leçon inventé) : sa
    /// matière la plus dure, sinon « Ta première leçon ».
    static func lessonTitle(for model: OnboardingModel, locale: UiLocale) -> String {
        subject(for: model, locale: locale) ?? L10n.t("ios.onb11.plan.lesson", locale: locale)
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

/// **« Tes cours deviennent des leçons. »** (lot 15, demande du fondateur : « tout ce que tu as
/// → une leçon ».) En haut, les quatre façons d'apporter un cours (PDF, cours enregistré,
/// photo, texte) ; « Transformer en leçon » : des traits partent de chacune et convergent
/// vers **une seule leçon**, sur le sujet du fil (sa matière la plus dure, à son niveau), avec
/// ce qu'elle contient. Ni question ni chemin : c'est le récit final qui les montre.
struct LessonDemoStepView: View {
    /// Pour les rendus : la démonstration déjà jouée.
    var previewPlayed = false

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    @State private var played = false

    private var isPlayed: Bool { played || previewPlayed }

    var body: some View {
        OnbDemoStage(
            title: i18n.t("ios.onb14.lesson.title"),
            playLabel: i18n.t("ios.onb12.lesson.play"),
            isPlayed: isPlayed,
            onPlay: play
        ) {
            VStack(spacing: 0) {
                sources
                OnbFunnel(count: OnbSource.allCases.count, isOn: isPlayed)
                    .frame(height: compact ? 40 : 60)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityHidden(true)
                ZStack {
                    if isPlayed {
                        lesson.transition(.onbPop)
                    } else {
                        slot.transition(.opacity)
                    }
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

    /// Les quatre sources, une tuile et son nom.
    private var sources: some View {
        let tile: CGFloat = compact ? 50 : 58
        return HStack(alignment: .top, spacing: 6) {
            ForEach(OnbSource.allCases) { source in
                VStack(spacing: 8) {
                    MicaboIconView(icon: source.kind.icon, size: tile * 0.58 * 1.35, tint: source.tone)
                        .frame(width: tile, height: tile)
                        .background(V3Color.wash(of: source.tone), in: RoundedRectangle(cornerRadius: V3Metric.radiusTile, style: .continuous))
                    Text(source.title(locale: i18n.locale))
                        .font(.system(.subheadline, design: .default, weight: .semibold))
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .combine)
    }

    /// La place de la leçon, avant : un cadre en pointillés.
    private var slot: some View {
        Image(systemName: "sparkles")
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(V3Color.ink3)
            .frame(maxWidth: .infinity, minHeight: compact ? 150 : 190)
            .overlay(
                RoundedRectangle(cornerRadius: V3Metric.radiusCard, style: .continuous)
                    .strokeBorder(V3Color.line, style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
            )
            .accessibilityHidden(true)
    }

    /// **La leçon qui en sort** : son sujet, et ce qu'elle contient.
    private var lesson: some View {
        let rows: [(MicaboIcon, Color, String)] = [
            (.notes, V3Color.iconBlue, i18n.t("ios.onb11.lesson.notes")),
            (.quiz, V3Color.iconGreen, i18n.t("ios.onb11.lesson.quiz")),
            (.cards, V3Color.iconLilac, i18n.t("ios.onb16.lesson.cards")),
        ]
        return VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            HStack(spacing: 10) {
                OnbIcon(icon: .book, size: 26)
                Text(OnbDemo.lessonTitle(for: model, locale: i18n.locale))
                    .font(V3Font.heading(26))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 12) {
                    MicaboIconView(icon: row.0, size: 22 * 1.35, tint: row.1)
                        .frame(width: 40, height: 40)
                        .background(V3Color.wash(of: row.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(row.2)
                        .font(OnbType.label)
                        .foregroundStyle(V3Color.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(selected: true)
        .accessibilityElement(children: .combine)
    }
}

/// **Les traits qui convergent** : de chaque source vers le milieu de la leçon. Pointillés et
/// discrets avant ; pleins, en bleu, une fois la leçon faite.
struct OnbFunnel: View {
    let count: Int
    let isOn: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            Path { path in
                for index in 0 ..< count {
                    let x = width * (CGFloat(index) * 2 + 1) / CGFloat(count * 2)
                    path.move(to: CGPoint(x: x, y: 4))
                    path.addQuadCurve(
                        to: CGPoint(x: width / 2, y: height - 2),
                        control: CGPoint(x: x, y: height * 0.75)
                    )
                }
            }
            .stroke(
                isOn ? V3Color.accent : V3Color.line,
                style: StrokeStyle(lineWidth: isOn ? 3 : 2, lineCap: .round, dash: isOn ? [] : [3, 6])
            )
        }
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

/// **L'exercice du scanner, à son niveau** (lot 15) : un vrai exercice de maths, avec les
/// vraies étapes, calculs vérifiés.
///
/// - collège : Pythagore — un triangle rectangle en A, AB = 6, AC = 8 ; BC² = 6² + 8² =
///   36 + 64 = 100, donc BC = 10 cm ;
/// - lycée : le second degré — x² − 4x + 3 = 0 ; Δ = 16 − 12 = 4 ; x = (4 ± 2) / 2, donc
///   x = 1 ou x = 3 ;
/// - supérieur : une intégrale — ∫₀¹ 2x dx ; une primitive de 2x est x² ; F(1) − F(0) = 1.
enum OnbScanExercise: CaseIterable {
    case pythagoras
    case quadratic
    case integral

    /// L'exercice d'une hauteur d'exemple (`FirstLessonStepView.band`).
    static func forBand(_ band: String) -> OnbScanExercise {
        switch band {
        case "lower": .pythagoras
        case "higher": .integral
        default: .quadratic
        }
    }

    /// L'énoncé écrit ; Pythagore se dessine.
    var problem: String? {
        switch self {
        case .pythagoras: nil
        case .quadratic: "x² − 4x + 3 = 0"
        case .integral: "∫₀¹ 2x dx"
        }
    }

    /// Les deux étapes : leur nom (une clé) et leur calcul.
    var steps: [(key: String, formula: String)] {
        switch self {
        case .pythagoras:
            [("ios.onb15.scan.pyth.1", "BC² = 6² + 8²"), ("ios.onb15.scan.pyth.2", "BC² = 36 + 64 = 100")]
        case .quadratic:
            [("ios.onb15.scan.quad.1", "Δ = 16 − 12 = 4"), ("ios.onb15.scan.quad.2", "x = (4 ± 2) / 2")]
        case .integral:
            [("ios.onb15.scan.int.1", "F(x) = x²"), ("ios.onb15.scan.int.2", "F(1) − F(0) = 1 − 0")]
        }
    }

    /// Le résultat. « x = 1 ou x = 3 » a son « ou » dans chaque langue.
    func result(locale: UiLocale) -> String {
        switch self {
        case .pythagoras: "BC = 10 cm"
        case .quadratic: L10n.t("ios.onb10.story.result", locale: locale)
        case .integral: "∫₀¹ 2x dx = 1"
        }
    }
}

/// **« Un exo qui bloque ? Prends-le en photo. »** On prend la photo : le cadre passe au vert,
/// l'exercice est reconnu ; puis chaque appui dévoile l'étape suivante, son nom et son calcul,
/// jusqu'au résultat. On apprend la méthode, pas seulement la réponse.
struct ScanDemoStepView: View {
    /// Pour les rendus : l'étape à montrer (0 : la visée, 3 : le résultat).
    var previewStage: Int?
    /// Pour les rendus : l'exercice à montrer, sans passer par la classe.
    var previewExercise: OnbScanExercise?

    @Environment(OnboardingModel.self) private var model
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @Environment(\.onbCompact) private var compact

    @State private var stage = 0

    /// 0 : la visée ; 1 : la photo prise, la première étape ; 2 : la deuxième ; 3 : le résultat.
    private var current: Int { previewStage ?? stage }

    private var exercise: OnbScanExercise {
        previewExercise ?? .forBand(FirstLessonStepView.band(for: model.tier))
    }

    private var playLabel: String {
        switch current {
        case 0: i18n.t("ios.onb12.scan.play")
        case 1, 2: i18n.t("ios.onb12.scan.next")
        default: i18n.t("common.continue")
        }
    }

    var body: some View {
        OnbDemoStage(
            title: i18n.t("ios.onb16.scan.title"),
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
            if let problem = exercise.problem {
                Text(verbatim: problem)
                    .font(V3Font.display(44))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else {
                OnbRightTriangle()
                    .frame(width: 250, height: compact && captured ? 120 : 160)
            }
            if captured {
                Label(i18n.t("ios.onb12.scan.recognized"), systemImage: "checkmark.circle.fill")
                    .font(OnbType.label)
                    .foregroundStyle(V3Color.green)
                    .transition(.onbPop)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity)
        .padding(.vertical, captured ? 22 : (compact ? 44 : 70))
        .padding(.horizontal, 20)
        .overlay {
            StoryViewfinder(arm: 28, radius: 12)
                .stroke(captured ? V3Color.green : V3Color.pink, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .padding(10)
        }
        .v3Card()
        .contentShape(Rectangle())
        .onTapGesture { if current == 0 { next() } }
        .accessibilityElement(children: .combine)
    }

    private var steps: some View {
        OnbPanel(padding: 18) {
            ForEach(Array(exercise.steps.prefix(min(current, 2)).enumerated()), id: \.offset) { index, step in
                self.step(index + 1, i18n.t(step.key), step.formula)
                    .transition(.onbPop)
            }
            if current >= 3 {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(V3Color.green)
                    Text(exercise.result(locale: i18n.locale))
                        .font(V3Font.display(34))
                        .foregroundStyle(V3Color.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .environment(\.layoutDirection, .leftToRight)
                .transition(.onbPop)
            }
        }
    }

    private func step(_ number: Int, _ label: String, _ formula: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(verbatim: "\(number)")
                .font(OnbType.label)
                .monospacedDigit()
                .foregroundStyle(V3Color.onAccent)
                .frame(width: 30, height: 30)
                .background(V3Color.accent, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(OnbType.label)
                    .foregroundStyle(V3Color.accentBright)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: formula)
                    .font(V3Font.display(30))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .environment(\.layoutDirection, .leftToRight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// **Le triangle de l'exercice de Pythagore** : rectangle en A, AB = 6, AC = 8, BC à trouver.
struct OnbRightTriangle: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let a = CGPoint(x: w * 0.14, y: h * 0.82)
            let b = CGPoint(x: w * 0.14, y: h * 0.12)
            let c = CGPoint(x: w * 0.86, y: h * 0.82)
            ZStack {
                Path { path in
                    path.move(to: a)
                    path.addLine(to: b)
                    path.addLine(to: c)
                    path.closeSubpath()
                }
                .stroke(V3Color.ink, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
                Path { path in
                    path.move(to: CGPoint(x: a.x, y: a.y - 18))
                    path.addLine(to: CGPoint(x: a.x + 18, y: a.y - 18))
                    path.addLine(to: CGPoint(x: a.x + 18, y: a.y))
                }
                .stroke(V3Color.ink2, lineWidth: 2.5)
                label("A", at: CGPoint(x: a.x - 16, y: a.y + 10), color: V3Color.ink2, size: 20)
                label("B", at: CGPoint(x: b.x - 16, y: b.y), color: V3Color.ink2, size: 20)
                label("C", at: CGPoint(x: c.x + 14, y: c.y + 10), color: V3Color.ink2, size: 20)
                label("6", at: CGPoint(x: a.x - 18, y: (a.y + b.y) / 2), color: V3Color.ink, size: 28)
                label("8", at: CGPoint(x: (a.x + c.x) / 2, y: a.y + 20), color: V3Color.ink, size: 28)
                label("?", at: CGPoint(x: (b.x + c.x) / 2 + 14, y: (b.y + c.y) / 2 - 16), color: V3Color.accentBright, size: 32)
            }
        }
        .accessibilityHidden(true)
    }

    private func label(_ text: String, at point: CGPoint, color: Color, size: CGFloat) -> some View {
        Text(verbatim: text)
            .font(V3Font.display(size))
            .foregroundStyle(color)
            .position(point)
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

    var body: some View {
        // Lot 15 : le titre ne dit plus « je », la démo n'a plus de bulle.
        OnbDemoStage(
            title: i18n.t("ios.onb15.plan.title", ["min": "\(model.minutesPerDay)"]),
            playLabel: i18n.t("ios.onb12.plan.play"),
            isPlayed: isPlayed,
            onPlay: { pick(1) }
        ) {
            OnbPanel(padding: 16) {
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

    /// Les sept jours qui commencent aujourd'hui, à toucher.
    private var week: some View {
        let days = Self.week(from: now, examDate: model.datedExam?.date, locale: i18n.locale)
        return HStack(spacing: 4) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, item in
                Button {
                    pick(index)
                } label: {
                    VStack(spacing: 6) {
                        Text(item.letter)
                            .font(OnbType.mention)
                            .foregroundStyle(index == selected ? V3Color.accentBright : V3Color.ink2)
                        Text(verbatim: "\(item.number)")
                            .font(.system(.title3, design: .default, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(index == selected ? V3Color.onAccent : V3Color.ink)
                            .frame(width: 42, height: 42)
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
        return HStack(spacing: 12) {
            OnbIcon(icon: kind.0, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(subject)
                    .font(V3Font.heading(26))
                    .foregroundStyle(V3Color.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)
                Text(kind.1)
                    .font(OnbType.detail)
                    .foregroundStyle(V3Color.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Une séance, une heure au plus (lot 16).
            Text(i18n.t("ios.quiz.time.short", ["n": "\(RevisionPlanner.sessionLength(dailyMinutes: model.minutesPerDay))"]))
                .font(OnbType.label)
                .foregroundStyle(V3Color.accentBright)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(V3Color.accentWash, in: Capsule())
        }
        .padding(16)
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

/// **« Tu peux aussi travailler en sessions qui te rapportent de l'XP. »** (lot 12, lot 16) Une séance de concentration à sa durée,
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

    /// **La séance de la démo** (lot 16) : la durée d'une séance de son plan (une heure au plus,
    /// `RevisionPlanner.sessionLengths`), et au moins un bloc de 25 minutes, celui qui rapporte
    /// de l'XP dans l'app : une séance plus courte n'en rapporterait pas.
    static func demoMinutes(dailyMinutes: Int) -> Int {
        let session = RevisionPlanner.sessionLengths(dailyMinutes: dailyMinutes).first ?? XPRules.focusMinutes
        return max(XPRules.focusMinutes, min(FocusPlan.maxMinutes, session))
    }

    /// **L'XP de cette séance, celle de l'app** : `XPRules.focusSession` par bloc de 25 minutes
    /// de travail terminé (`FocusPhases.xp`). Aucun chiffre écrit à la main.
    static func demoXP(dailyMinutes: Int) -> Int {
        FocusPhases.xp(forWorkSeconds: TimeInterval(demoMinutes(dailyMinutes: dailyMinutes) * 60))
    }

    private var minutes: Int { Self.demoMinutes(dailyMinutes: model.minutesPerDay) }

    var body: some View {
        OnbDemoStage(
            // Lot 16 : « Tu peux aussi travailler en sessions qui te rapportent de l'XP. »
            title: i18n.t("ios.onb16.focus.title"),
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
                        Text(verbatim: isDone ? "0:00" : "\(minutes):00")
                            .font(V3Font.display(56))
                            .monospacedDigit()
                            .foregroundStyle(V3Color.ink)
                            .contentTransition(.numericText(countsDown: true))
                            .environment(\.layoutDirection, .leftToRight)
                        if let subject = OnbDemo.subject(for: model, locale: i18n.locale) {
                            Text(subject)
                                .font(OnbType.label)
                                .foregroundStyle(V3Color.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
                .frame(width: compact ? 190 : 240, height: compact ? 190 : 240)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)

                if isDone {
                    // La fin de la séance : l'XP qu'elle rapporte dans l'app.
                    HStack(spacing: 10) {
                        Label(i18n.t("ios.onb12.focus.finished"), systemImage: "checkmark.circle.fill")
                            .font(OnbType.label)
                            .foregroundStyle(V3Color.green)
                        OnbXPPill(points: Self.demoXP(dailyMinutes: model.minutesPerDay))
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.onbPop)
                } else {
                    Label(i18n.t("ios.onb12.focus.fast"), systemImage: "hare.fill")
                        .font(OnbType.mention)
                        .foregroundStyle(V3Color.ink3)
                        .frame(maxWidth: .infinity)
                }
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
