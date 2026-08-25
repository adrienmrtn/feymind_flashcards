import SwiftData
import SwiftUI
import UIKit

/// **Le mouvement d'une session.**
///
/// Les courbes sont courtes et ne rebondissent pas, comme celles du parcours d'accueil : un
/// ressort dépasse sa cible puis revient, et sur un geste qu'on répète cinquante fois de
/// suite, ce retour se sent comme un retard. La note enchaînait sur un ressort de 400 ms —
/// c'est-à-dire qu'on voyait la carte suivante s'installer pendant presque une demi-seconde
/// après avoir appuyé.
enum StudyMotion {
    /// Passage à la carte suivante, après une note. C'est le geste le plus répété de l'app :
    /// il doit être fini avant qu'on ait relevé le doigt.
    static let next = Animation.timingCurve(0.3, 0, 0.2, 1, duration: 0.22)
    /// Retournement de la carte. Un peu plus long : il y a quelque chose à lire au bout.
    static let reveal = Animation.timingCurve(0.25, 0.8, 0.25, 1, duration: 0.3)
}

/// Une session de révision : la file du jour, carte après carte.
///
/// Trois états cohabitent avant la pile de cartes : la proposition de reprise d'une
/// session interrompue, l'écran « rien à réviser » avec la prochaine échéance, et
/// l'entraînement libre, annoncé explicitement pour qu'on ne le confonde pas avec une
/// vraie session.
struct StudyView: View {
    let source: StudySource
    var mode: StudyMode = .scheduled
    var isEmbedded: Bool = false

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var session = StudySession()
    @State private var didStart = false
    @State private var showHint = false
    /// Proposition choisie sur un QCM, remise à zéro à chaque carte.
    @State private var selectedChoice: Int?
    @State private var editingCard: Flashcard?
    /// Session retrouvée au lancement : on ne démarre rien avant que l'utilisateur choisisse.
    @State private var resumable: StudySessionSnapshot?

    private var totalLabel: String {
        let answered = session.answeredCount
        let total = max(session.initialCount, 1)
        let current = session.isFinished ? total : min(answered + 1, total)
        return "\(current)/\(total)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let resumable {
                ResumePromptView(
                    snapshot: resumable,
                    canClose: !isEmbedded,
                    onResume: { resume(resumable) },
                    onRestart: restart,
                    onClose: { dismiss() }
                )
            } else if session.isEmpty {
                NothingDueView(
                    nextDueLabel: nextDueLabel,
                    canPractice: !practiceCards.isEmpty,
                    onPractice: startPractice,
                    onClose: finish
                )
            } else if session.isFinished {
                CompletionView(session: session, isEmbedded: isEmbedded) {
                    finish()
                }
            } else {
                headerBar
                cardArea
                controls
            }
        }
        .micaboScreenBackground()
        .onAppear(perform: prepare)
        // Les notes s'écrivent par paquets pour que l'appui reste instantané : quitter l'app
        // au milieu d'un paquet doit donc le poser sur le disque avant de partir.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.flush() }
        }
        .sheet(item: $editingCard) { card in
            FlashcardEditorSheet(card: card)
                .onDisappear { session.cardWasEdited() }
        }
    }

    // MARK: - En-tête (X · barre · 4/12 · annuler)

    private var headerBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                if !isEmbedded {
                    MicaboCircleButton(systemImage: "xmark", size: 32, accessibilityTitle: "Fermer") {
                        finish()
                    }
                }

                MicaboProgressBar(progress: session.progress)
                    .frame(height: 5)

                Text(totalLabel)
                    .font(MicaboFont.number(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .monospacedDigit()

                if session.canUndo {
                    MicaboCircleButton(
                        systemImage: "arrow.uturn.backward",
                        size: 32,
                        accessibilityTitle: "Annuler la dernière note"
                    ) {
                        Haptics.rigid()
                        withAnimation(StudyMotion.next) {
                            session.undo()
                        }
                        showHint = false
                        selectedChoice = nil
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: session.canUndo)

            if !session.mode.affectsSchedule {
                practiceBanner
            } else if session.isCurrentUnderExamDeadline {
                examBanner
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    /// Dit noir sur blanc que rien ne sera enregistré.
    private var practiceBanner: some View {
        banner(
            systemImage: "dumbbell",
            text: "Entraînement libre · ton planning n'est pas modifié",
            tint: MicaboColor.accent,
            background: MicaboColor.accentSoft
        )
    }

    /// Dit pourquoi les intervalles annoncés sous les boutons sont plus courts que d'habitude.
    /// Sans ce bandeau, l'utilisateur croirait le planificateur cassé.
    private var examBanner: some View {
        banner(
            systemImage: "calendar.badge.clock",
            text: "Mode examen · aucune carte ne repart au delà du jour J",
            tint: MicaboColor.caution,
            background: MicaboColor.cautionSoft
        )
    }

    private func banner(systemImage: String, text: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(MicaboFont.hanken(12, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity)
        .background(background, in: Capsule())
    }

    // MARK: - Carte

    private var cardArea: some View {
        Group {
            if let card = session.current {
                StudyCardFace(
                    card: card,
                    showAnswer: session.isRevealed,
                    isHintVisible: showHint,
                    onToggleHint: toggleHint,
                    selectedChoice: selectedChoice,
                    onSelectChoice: selectChoice
                )
                .id(card.id)
                // La sortante s'efface en reculant, l'entrante arrive du bas : sans
                // transition déclarée, le changement d'identité ne donnait qu'un fondu, et un
                // fondu ne dit pas qu'on a avancé d'une carte.
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 16)),
                        removal: .opacity.combined(with: .scale(scale: 0.97))
                    )
                )
                .onTapGesture {
                    withAnimation(StudyMotion.reveal) {
                        session.reveal()
                    }
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .frame(maxHeight: .infinity)
        .onChange(of: session.current?.id) { _, _ in
            showHint = false
            selectedChoice = nil
        }
    }

    private func toggleHint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            showHint.toggle()
        }
    }

    /// Répondre à un QCM retourne la carte : le choix vaut la réponse, on ne redemande
    /// pas un appui pour la même chose. La notation, elle, reste à l'utilisateur.
    private func selectChoice(_ index: Int) {
        guard let card = session.current, !session.isRevealed else { return }
        selectedChoice = index

        if index == card.correctChoiceIndex {
            Haptics.success()
        } else {
            Haptics.warning()
        }

        withAnimation(StudyMotion.reveal) {
            session.reveal()
        }
    }

    // MARK: - Commandes

    @ViewBuilder
    private var controls: some View {
        VStack(spacing: 14) {
            if session.isRevealed {
                Text("Comment as-tu répondu ?")
                    .font(MicaboFont.hanken(11, weight: .medium))
                    .foregroundStyle(MicaboColor.inkTertiary)

                GradeButtons(intervals: session.previewLabels) { rating in
                    withAnimation(StudyMotion.next) {
                        session.answer(rating)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(StudyMotion.reveal) {
                        session.reveal()
                    }
                } label: {
                    Text("Afficher la réponse")
                }
                .buttonStyle(MicaboPrimaryButtonStyle())
            }

            cardActions
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 20)
        .padding(.bottom, 24)
        .animation(StudyMotion.reveal, value: session.isRevealed)
    }

    /// Corriger, passer ou écarter une carte sans quitter la session. Ces actions restent
    /// à portée avant comme après la réponse : c'est souvent en lisant le verso qu'on
    /// s'aperçoit qu'une carte est fausse.
    private var cardActions: some View {
        HStack(spacing: 20) {
            if !session.isRevealed {
                quietAction("Passer", systemImage: "arrow.right.to.line") {
                    withAnimation { session.skip() }
                }
            }

            quietAction("Modifier", systemImage: "pencil") {
                guard let card = session.current else { return }
                Haptics.light()
                editingCard = card
            }

            quietAction("Mettre de côté", systemImage: "tray.and.arrow.down") {
                Haptics.warning()
                withAnimation { session.setAsideCurrent() }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func quietAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(MicaboFont.hanken(13, weight: .medium))
            }
            .foregroundStyle(MicaboColor.inkTertiary)
        }
        .buttonStyle(MicaboPressableButtonStyle())
    }

    // MARK: - Démarrage, reprise, sortie

    /// Au premier affichage : soit on propose de reprendre, soit on démarre.
    private func prepare() {
        guard !didStart, resumable == nil else { return }

        if mode.affectsSchedule,
           let key = source.persistenceKey,
           let snapshot = StudySessionStore.load(for: key) {
            resumable = snapshot
            return
        }

        start()
    }

    private func start() {
        guard !didStart else { return }
        didStart = true
        session.start(
            with: resolveCards(),
            context: modelContext,
            mode: mode,
            sourceKey: source.persistenceKey
        )
    }

    private func resume(_ snapshot: StudySessionSnapshot) {
        resumable = nil
        didStart = true
        session.resume(snapshot, cards: resolveCards(), context: modelContext)
    }

    private func restart() {
        StudySessionStore.clear()
        resumable = nil
        start()
    }

    /// L'entraînement libre repart de zéro sur les mêmes cartes.
    private func startPractice() {
        session = StudySession()
        didStart = true
        session.start(
            with: practiceCards,
            context: modelContext,
            mode: .practice,
            sourceKey: nil
        )
    }

    private func resolveCards() -> [Flashcard] {
        switch source {
        case .course(let course): course.cards
        case .allDue: CourseRepository.allCards(in: modelContext)
        case .cards(let cards): cards
        }
    }

    /// Cartes disponibles pour un entraînement libre depuis l'écran « rien à réviser ».
    private var practiceCards: [Flashcard] {
        resolveCards().filter { !$0.isSuspended }
    }

    /// Prochaine échéance annoncée quand il n'y a rien à réviser.
    private var nextDueLabel: String? {
        let upcoming = practiceCards
            .map(\.dueDate)
            .filter { $0 > Date() }
            .min()
        guard let upcoming else { return nil }
        return SM2Scheduler.format(delay: upcoming.timeIntervalSinceNow)
    }

    /// Fermer en cours de route ne perd rien : la file est écrite après chaque note, et le
    /// planning est écrit ici, à l'instant où plus personne n'attend une carte.
    private func finish() {
        session.flush()

        if isEmbedded {
            session = StudySession()
            didStart = false
            prepare()
        } else {
            dismiss()
        }
    }
}

// MARK: - Carte

struct StudyCardFace: View {
    let card: Flashcard
    let showAnswer: Bool
    var isHintVisible: Bool = false
    var onToggleHint: (() -> Void)?
    var selectedChoice: Int?
    var onSelectChoice: ((Int) -> Void)?

    var body: some View {
        VStack(alignment: showAnswer ? .leading : .center, spacing: 14) {
            if showAnswer {
                Text("RÉPONSE")
                    .font(MicaboFont.hanken(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MicaboColor.accent)

                FormulaText(source: card.front, size: 17, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)

                MicaboHairline()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if card.isOcclusion {
                            OcclusionFigure(card: card, isRevealed: true)
                        }

                        if card.format == .choice {
                            ChoiceList(card: card, selected: selectedChoice, isRevealed: true)
                        }

                        FormulaText(
                            source: card.back,
                            size: 15,
                            color: Color(hex: 0x4A463F)
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)

                        if card.hasAudio {
                            CardAudioButton(card: card)
                        }
                    }
                }
            } else {
                Spacer(minLength: 0)

                if let label = frontEyebrow {
                    Text(label.uppercased())
                        .font(MicaboFont.hanken(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                if card.isOcclusion {
                    OcclusionFigure(card: card, isRevealed: false)
                }

                FormulaText(
                    source: card.front,
                    size: frontSize,
                    weight: .semibold,
                    alignment: card.format == .choice ? .leading : .center
                )
                .tracking(-0.2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: card.format == .choice ? .leading : .center)

                if card.format == .choice {
                    ChoiceList(
                        card: card,
                        selected: selectedChoice,
                        isRevealed: false,
                        onSelect: onSelectChoice
                    )
                }

                if card.hasAudio {
                    CardAudioButton(card: card)
                }

                Spacer(minLength: 0)

                if let hint = card.hint?.nilIfBlank, onToggleHint != nil {
                    hintArea(hint)
                }
            }
        }
        .padding(showAnswer ? 26 : 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showAnswer ? .topLeading : .center)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    /// Le sens de révision compte en langues, et le format compte partout : on annonce
    /// ce qui est demandé avant de le demander.
    private var frontEyebrow: String? {
        if card.isReversed {
            return "Sens inverse"
        }
        switch card.format {
        case .cloze, .choice:
            return card.format.label
        case .basic, .occlusion:
            return card.course?.subject?.nilIfBlank ?? card.course?.title
        }
    }

    /// Une question à trou ou à propositions se lit sur plusieurs lignes : elle ne peut
    /// pas garder le corps d'une question d'une ligne.
    private var frontSize: CGFloat {
        switch card.format {
        case .occlusion: 18
        case .choice: 19
        case .cloze: 22
        case .basic: 24
        }
    }

    /// Ampoule au pied de la question : un appui donne un coup de pouce sans livrer la réponse.
    @ViewBuilder
    private func hintArea(_ hint: String) -> some View {
        if isHintVisible {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.caution)

                Text(hint)
                    .font(MicaboFont.hanken(13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x4A463F))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(MicaboColor.cautionSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
            .transition(.opacity)
        } else {
            Button {
                onToggleHint?()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Indice")
                        .font(MicaboFont.hanken(13, weight: .semibold))
                }
                .foregroundStyle(MicaboColor.inkSecondary)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(MicaboColor.surfaceMuted, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Afficher un indice")
        }
    }
}

// MARK: - Propositions d'un QCM

/// Les propositions d'un QCM. Avant la réponse, ce sont des boutons ; après, la bonne
/// est marquée et l'erreur éventuelle aussi, pour qu'on voie ce qu'on avait choisi.
private struct ChoiceList: View {
    let card: Flashcard
    var selected: Int?
    var isRevealed: Bool
    var onSelect: ((Int) -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(card.choices.enumerated()), id: \.offset) { index, choice in
                if isRevealed || onSelect == nil {
                    row(index: index, choice: choice)
                } else {
                    Button {
                        onSelect?(index)
                    } label: {
                        row(index: index, choice: choice)
                    }
                    .buttonStyle(MicaboPressableButtonStyle(dimming: false))
                }
            }
        }
    }

    private func row(index: Int, choice: String) -> some View {
        let style = state(for: index)

        return HStack(alignment: .top, spacing: 10) {
            Text(letter(index))
                .font(MicaboFont.hanken(12, weight: .bold))
                .foregroundStyle(style.markForeground)
                .frame(width: 22, height: 22)
                .background(style.markBackground, in: Circle())

            FormulaText(source: choice, size: 15, weight: .medium, color: style.text)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let symbol = style.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(style.markBackground)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.background, in: RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MicaboRadius.sm, style: .continuous)
                .strokeBorder(style.border, lineWidth: 1)
        }
    }

    private func letter(_ index: Int) -> String {
        let letters = Array("ABCDEFGH")
        return index < letters.count ? String(letters[index]) : "\(index + 1)"
    }

    /// Quatre situations seulement : à choisir, choisie, juste, fausse.
    private enum ChoiceState {
        case pending
        case picked
        case correct
        case wrong
        case dismissed

        var background: Color {
            switch self {
            case .pending: MicaboColor.canvas
            case .picked: MicaboColor.accentSoft
            case .correct: MicaboColor.positiveSoft
            case .wrong: MicaboColor.negativeSoft
            case .dismissed: MicaboColor.canvas
            }
        }

        var border: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.stroke
            case .picked: MicaboColor.accent
            case .correct: MicaboColor.positive
            case .wrong: MicaboColor.negative
            }
        }

        var text: Color {
            self == .dismissed ? MicaboColor.inkTertiary : MicaboColor.ink
        }

        var markBackground: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.surfaceMuted
            case .picked: MicaboColor.accent
            case .correct: MicaboColor.positive
            case .wrong: MicaboColor.negative
            }
        }

        var markForeground: Color {
            switch self {
            case .pending, .dismissed: MicaboColor.inkSecondary
            case .picked, .correct, .wrong: MicaboColor.onInk
            }
        }

        var symbol: String? {
            switch self {
            case .correct: "checkmark.circle.fill"
            case .wrong: "xmark.circle.fill"
            case .pending, .picked, .dismissed: nil
            }
        }
    }

    private func state(for index: Int) -> ChoiceState {
        guard isRevealed else {
            return selected == index ? .picked : .pending
        }
        if index == card.correctChoiceIndex {
            return .correct
        }
        return selected == index ? .wrong : .dismissed
    }
}

// MARK: - Boutons de maîtrise (grille 2×2 de la maquette)

/// Les quatre notes, en grille 2×2, **avec le délai que chacune programme**.
///
/// Le délai manquait, et c'était le principal reproche fait à la session : on répondait « à
/// revoir » sans savoir si la carte revenait dans dix minutes ou le mois prochain, donc sans
/// pouvoir arbitrer entre « difficile » et « correct ». Anki l'affiche depuis toujours, et
/// pour la même raison : c'est le seul retour qu'une note donne sur ce qu'elle vient de faire.
/// Les libellés viennent du planificateur lui-même, date d'examen comprise, et non d'une
/// table de correspondance qui vieillirait à côté de lui.
struct GradeButtons: View {
    /// Délai programmé par chaque note. Vide en entraînement libre, où rien ne bouge : les
    /// boutons se contentent alors de leur libellé.
    var intervals: [ReviewRating: String] = [:]
    var onSelect: (ReviewRating) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
            spacing: 9
        ) {
            ForEach(ReviewRating.allCases) { rating in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onSelect(rating)
                } label: {
                    VStack(spacing: 2) {
                        Text(rating.label)
                            .font(MicaboFont.hanken(14, weight: .semibold))

                        if let interval = intervals[rating] {
                            Text(interval)
                                .font(MicaboFont.number(11, weight: .semibold))
                                .monospacedDigit()
                                .opacity(0.7)
                        }
                    }
                    .foregroundStyle(tint(for: rating))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, intervals[rating] == nil ? 15 : 11)
                    .background(softTint(for: rating), in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: rating))
            }
        }
    }

    /// Le lecteur d'écran annonce la note et son délai d'une seule voix : deux éléments
    /// séparés feraient lire « à revoir », puis « 10 min », sans dire que l'un est l'autre.
    private func accessibilityLabel(for rating: ReviewRating) -> String {
        guard let interval = intervals[rating] else { return rating.label }
        return "\(rating.label), revient dans \(interval)"
    }

    /// La couleur d'une note. Elle est publiée parce que le bilan de fin de session s'en
    /// sert : on doit y relire son propre geste, et deux échelles de couleurs pour les mêmes
    /// quatre notes finiraient par ne plus se répondre.
    static func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: Color(hex: 0xB5573C)
        case .hard: MicaboColor.caution
        case .good: MicaboColor.positive
        case .easy: MicaboColor.info
        }
    }

    static func softTint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: MicaboColor.negativeSoft
        case .hard: MicaboColor.cautionSoft
        case .good: MicaboColor.positiveSoft
        case .easy: MicaboColor.infoSoft
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        Self.tint(for: rating)
    }

    private func softTint(for rating: ReviewRating) -> Color {
        Self.softTint(for: rating)
    }
}

// MARK: - Reprise d'une session interrompue

/// Proposée au lancement quand une session a été laissée en cours. On ne reprend jamais
/// dans le dos de l'utilisateur : il choisit de continuer ou de repartir de zéro.
private struct ResumePromptView: View {
    let snapshot: StudySessionSnapshot
    var canClose: Bool
    var onResume: () -> Void
    var onRestart: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if canClose {
                MicaboCircleButton(systemImage: "xmark", size: 32, accessibilityTitle: "Fermer", action: onClose)
                    .padding(.horizontal, MicaboSpacing.screen)
                    .padding(.top, 8)
            }

            Spacer(minLength: MicaboSpacing.lg)

            VStack(alignment: .leading, spacing: 12) {
                MicaboEyebrow(text: "Session interrompue")

                Text("Tu en étais à la carte \(snapshot.position) sur \(max(snapshot.initialCount, snapshot.position)).")
                    .font(MicaboFont.hanken(28, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: MicaboSpacing.lg)

            MicaboBottomBar {
                VStack(spacing: 2) {
                    Button("Reprendre", action: onResume)
                        .buttonStyle(MicaboPrimaryButtonStyle())

                    Button("Recommencer", action: onRestart)
                        .buttonStyle(MicaboQuietButtonStyle())
                }
            }
        }
    }
}

// MARK: - Rien à réviser

/// Ce qui manquait : quand la file du jour est vide, on le dit, on félicite sobrement et
/// on annonce la prochaine échéance — au lieu de basculer en douce sur d'autres cartes.
private struct NothingDueView: View {
    let nextDueLabel: String?
    var canPractice: Bool
    var onPractice: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                MicaboCircleButton(systemImage: "xmark", size: 32, accessibilityTitle: "Fermer", action: onClose)
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 8)

            Spacer(minLength: MicaboSpacing.lg)

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "checkmark")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(MicaboColor.positive)
                    .frame(width: 68, height: 68)
                    .background(MicaboColor.positiveSoft, in: Circle())

                Text("Tout est à jour.")
                    .font(MicaboFont.hanken(28, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.6)

                Text(detail)
                    .font(MicaboFont.body)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, MicaboSpacing.screen)

            Spacer(minLength: MicaboSpacing.lg)

            MicaboBottomBar {
                VStack(spacing: 2) {
                    if canPractice {
                        Button("Entraînement libre", action: onPractice)
                            .buttonStyle(MicaboSecondaryButtonStyle())
                    }

                    Button("Fermer", action: onClose)
                        .buttonStyle(MicaboQuietButtonStyle())
                }
            }
        }
    }

    private var detail: String {
        guard let nextDueLabel else {
            return "Aucune carte ne t'attend. Importe un cours pour en créer de nouvelles."
        }
        return "Aucune carte à réviser pour l'instant. La prochaine revient dans \(nextDueLabel)."
    }
}

// MARK: - Fin de session

/// Le bilan d'une session.
///
/// Trois chiffres tenaient lieu de bilan : « acquises », « à revoir », « réussite ». Le
/// premier rangeait « difficile » avec « facile », ce qui est précisément la distinction
/// qu'on vient de faire carte par carte ; le troisième était le premier moins le second en
/// pourcentage, donc la même information une troisième fois. Et rien ne disait ce qui compte
/// en refermant l'app : **est-ce que c'est fini ?**
///
/// L'écran répond dans cet ordre : ce qui a été appris, comment les notes se répartissent, et
/// quand la session revient.
///
/// **Il se construit sous les yeux.** C'est le seul écran de récompense de l'app, et il
/// s'affichait d'un bloc, chiffres finaux compris : le travail de vingt minutes apparaissait
/// comme une facture. Les nombres partent donc de zéro et montent, les barres de répartition
/// se remplissent en cascade, et le reste arrive derrière elles. Rien ne dure : un bilan qui
/// se fait attendre est un bilan qu'on quitte avant la fin, donc tout est posé en une seconde.
///
/// L'animation ne se rejoue pas. Un chiffre qui remonte à chaque retour sur l'écran cesse
/// d'être une récompense et devient un décor.
private struct CompletionView: View {
    let session: StudySession
    let isEmbedded: Bool
    var onFinish: () -> Void

    /// Passe à vrai une fois, à l'apparition. Chaque élément déclare son propre retard, ce qui
    /// évite une machine à états pour trois cents millisecondes de cascade.
    @State private var isRevealed = false

    private var isPractice: Bool {
        !session.mode.affectsSchedule
    }

    /// Ce que valent les chiffres tant que l'écran n'est pas arrivé : zéro, pour qu'ils aient
    /// quelque part à monter.
    private var factor: Double {
        isRevealed ? 1 : 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: MicaboSpacing.lg) {
                banner

                if session.answeredCount > 0 {
                    ratingBreakdown
                    tiles
                    if let comeback {
                        comebackNote(comeback)
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.xl)
            .padding(.bottom, MicaboSpacing.xxl)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MicaboBottomBar {
                Button(isEmbedded ? "Recharger la session" : "Terminer", action: onFinish)
                    .buttonStyle(MicaboPrimaryButtonStyle())
            }
            .opacity(isRevealed ? 1 : 0)
            .animation(.easeOut(duration: 0.3).delay(Timing.button), value: isRevealed)
        }
        .onAppear(perform: reveal)
    }

    /// Les retards de la cascade, en un endroit : c'est ce qui permet de la relire comme une
    /// partition plutôt que de chasser des nombres dans six modificateurs.
    private enum Timing {
        static let badge = 0.05
        static let title = 0.18
        static let bars = 0.3
        static let barStagger = 0.07
        static let numbers = 0.34
        static let comeback = 0.6
        static let button = 0.66
        /// Durée de la montée des nombres. Assez longue pour qu'on la voie compter, assez
        /// courte pour ne pas faire attendre un total qu'on connaît déjà.
        static let count = 0.85
    }

    private func reveal() {
        guard !isRevealed else { return }
        isRevealed = true

        guard session.answeredCount > 0 else { return }
        Haptics.success()
        // Le même geste que la projection du parcours d'accueil : les impulsions suivent la
        // montée des chiffres, et le compteur se sent autant qu'il se voit.
        Haptics.burst(count: 14, over: Timing.count, intensity: 0.3)
    }

    // MARK: - En-tête

    private var banner: some View {
        VStack(spacing: 10) {
            Image(systemName: session.answeredCount > 0 ? "checkmark" : "moon.zzz")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(MicaboColor.positive)
                .frame(width: 74, height: 74)
                .background(MicaboColor.positiveSoft, in: Circle())
                // La pastille arrive en grandissant, et le glyphe rebondit une fois : c'est
                // le seul rebond de l'app, et il est celui du système, sur un symbole.
                .scaleEffect(isRevealed ? 1 : 0.86)
                .opacity(isRevealed ? 1 : 0)
                .symbolEffect(.bounce, value: isRevealed)
                .animation(.easeOut(duration: 0.32).delay(Timing.badge), value: isRevealed)

            VStack(spacing: 10) {
                Text(title)
                    .font(MicaboFont.hanken(26, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(MicaboTracking.tight)
                    .multilineTextAlignment(.center)

                Text(detail)
                    .font(MicaboFont.body)
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .rise(isRevealed, delay: Timing.title)
        }
    }

    /// La répartition des notes, une ligne par note.
    ///
    /// Les quatre couleurs sont celles des boutons qu'on vient d'appuyer : on relit son
    /// propre geste, et « difficile » ne se confond plus avec « facile ». Une note jamais
    /// donnée n'a pas de ligne : une liste de zéros ne dit rien.
    @ViewBuilder
    private var ratingBreakdown: some View {
        let given = ReviewRating.allCases.filter { session.count(of: $0) > 0 }
        if !given.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: "Tes réponses")

                VStack(spacing: 11) {
                    ForEach(Array(given.enumerated()), id: \.element) { index, rating in
                        ratingRow(rating, index: index)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .micaboGroup()
            }
            .rise(isRevealed, delay: Timing.bars)
        }
    }

    /// Une note, son compte et sa part. La barre se remplit depuis la gauche, chaque ligne un
    /// cran après la précédente : c'est ce qui fait lire une répartition plutôt que quatre
    /// barres déjà là.
    private func ratingRow(_ rating: ReviewRating, index: Int) -> some View {
        let count = session.count(of: rating)
        let share = Double(count) / Double(max(session.answeredCount, 1))
        let delay = Timing.bars + Double(index) * Timing.barStagger

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.xs) {
                Text(rating.label)
                    .font(MicaboFont.hanken(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)

                Spacer(minLength: 0)

                CountingText(
                    value: Double(count) * factor,
                    font: MicaboFont.number(14),
                    color: GradeButtons.tint(for: rating)
                )
                .animation(.easeOut(duration: Timing.count).delay(delay), value: factor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MicaboColor.surfaceMuted)
                    Capsule()
                        .fill(GradeButtons.tint(for: rating))
                        .frame(width: max(6, proxy.size.width * share) * factor)
                        .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.55).delay(delay), value: factor)
                }
            }
            .frame(height: 7)
        }
        .accessibilityElement()
        .accessibilityLabel("\(rating.label) : \(count) sur \(session.answeredCount)")
    }

    /// Ce que la session a produit, et ce qu'elle a coûté.
    private var tiles: some View {
        HStack(spacing: 10) {
            if !isPractice {
                tile("apprises", MicaboColor.positive) {
                    counter(Double(session.graduatedCount), color: MicaboColor.positive)
                }
            }

            tile("de réussite", MicaboColor.accent) {
                // Le pourcentage monte comme les autres, et son signe reste collé au nombre :
                // un « % » qui s'éloigne pendant que le chiffre grandit se lit comme un défaut
                // d'alignement.
                HStack(spacing: 1) {
                    counter(session.accuracy * 100, color: MicaboColor.accent)
                    Text("%")
                        .font(MicaboFont.number(21))
                        .foregroundStyle(MicaboColor.accent)
                }
            }

            tile("de révision", MicaboColor.inkSecondary) {
                // La durée ne compte pas : « 12 min » qui monterait de zéro se lirait comme un
                // chronomètre qui tourne encore, et « < 1 min » n'a pas de nombre à monter.
                Text(durationLabel)
                    .font(MicaboFont.number(21))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .monospacedDigit()
            }
        }
        .rise(isRevealed, delay: Timing.numbers)
    }

    private func counter(_ value: Double, color: Color) -> some View {
        CountingText(value: value * factor, font: MicaboFont.number(21), color: color)
            .animation(.easeOut(duration: Timing.count).delay(Timing.numbers), value: factor)
    }

    private func tile<Value: View>(
        _ label: String,
        _ tint: Color,
        @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(spacing: 4) {
            value()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(MicaboFont.hanken(11, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 6)
        .micaboGroup(radius: MicaboRadius.button)
    }

    /// Quand ça revient. C'est la question qu'on se pose en refermant l'app, et l'écran
    /// annonçait « Session terminée » sans y répondre : trois cartes qui repassent dans dix
    /// minutes ne terminent pas une session de la même façon que tout ce qui repart à
    /// quatre jours.
    private func comebackNote(_ delay: TimeInterval) -> some View {
        let today = session.returningToday()

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MicaboColor.accent)

            Text(comebackText(delay: delay, today: today))
                .font(MicaboFont.hanken(13, weight: .regular))
                .foregroundStyle(MicaboColor.inkSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MicaboColor.accentSoft, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
        .rise(isRevealed, delay: Timing.comeback)
    }

    private func comebackText(delay: TimeInterval, today: Int) -> String {
        let next = "La prochaine carte revient dans \(SM2Scheduler.format(delay: delay))."
        guard today > 0 else { return next + " Rien d'autre avant demain." }
        return next + " \(MicaboCopy.cards(today)) repassent aujourd'hui."
    }

    private var comeback: TimeInterval? {
        guard session.answeredCount > 0 else { return nil }
        return session.nextReturn()
    }

    private var title: String {
        guard session.answeredCount > 0 else { return "Rien à réviser" }
        if isPractice { return "Entraînement terminé" }
        return session.againCount == 0 ? "Sans faute." : "Session terminée"
    }

    private var detail: String {
        guard session.answeredCount > 0 else {
            return "Reviens plus tard, ou prends de l'avance depuis un cours."
        }
        let volume = "\(MicaboCopy.cards(session.answeredCount)) revues"
        return isPractice ? "\(volume). Ton planning n'a pas bougé." : "\(volume)."
    }

    private var durationLabel: String {
        let minutes = Int(session.elapsed / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}

private extension View {
    /// Arrive en montant de dix points, après son retard. Le même geste que l'entrée en
    /// cascade du parcours d'accueil : douze points de montée et un fondu suffisent à faire
    /// arriver un élément, et un flou de mise au point coûterait une passe de rendu par image
    /// pour rendre le texte illisible pendant sa propre apparition.
    func rise(_ isRevealed: Bool, delay: Double) -> some View {
        opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed ? 0 : 10)
            .animation(.timingCurve(0.2, 0.7, 0.2, 1, duration: 0.42).delay(delay), value: isRevealed)
    }
}
