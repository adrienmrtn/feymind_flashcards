import SwiftData
import SwiftUI
import UIKit

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

    @State private var session = StudySession()
    @State private var didStart = false
    @State private var showHint = false
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
                    .font(MicaboFont.hanken(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .monospacedDigit()

                if session.canUndo {
                    MicaboCircleButton(
                        systemImage: "arrow.uturn.backward",
                        size: 32,
                        accessibilityTitle: "Annuler la dernière note"
                    ) {
                        Haptics.rigid()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            session.undo()
                        }
                        showHint = false
                    }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.2), value: session.canUndo)

            if !session.mode.affectsSchedule {
                practiceBanner
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 8)
        .padding(.bottom, 18)
    }

    /// Dit noir sur blanc que rien ne sera enregistré.
    private var practiceBanner: some View {
        HStack(spacing: 7) {
            Image(systemName: "dumbbell")
                .font(.system(size: 12, weight: .semibold))
            Text("Entraînement libre · ton planning n'est pas modifié")
                .font(MicaboFont.hanken(12, weight: .semibold))
        }
        .foregroundStyle(MicaboColor.accent)
        .padding(.vertical, 8)
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity)
        .background(MicaboColor.accentSoft, in: Capsule())
    }

    // MARK: - Carte

    private var cardArea: some View {
        Group {
            if let card = session.current {
                StudyCardFace(
                    card: card,
                    showAnswer: session.isRevealed,
                    isHintVisible: showHint,
                    onToggleHint: toggleHint
                )
                .id(card.id)
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                        session.reveal()
                    }
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .frame(maxHeight: .infinity)
        .onChange(of: session.current?.id) { _, _ in
            showHint = false
        }
    }

    private func toggleHint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            showHint.toggle()
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

                GradeButtons { rating in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        session.answer(rating)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
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
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: session.isRevealed)
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

    /// Fermer en cours de route ne perd rien : l'état est déjà écrit après chaque note,
    /// et la reprise sera proposée au prochain lancement.
    private func finish() {
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

    var body: some View {
        VStack(alignment: showAnswer ? .leading : .center, spacing: 14) {
            if showAnswer {
                Text("RÉPONSE")
                    .font(MicaboFont.hanken(11, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(MicaboColor.accent)

                Text(card.front)
                    .font(MicaboFont.hanken(17, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                MicaboHairline()

                ScrollView {
                    Text(card.back)
                        .font(MicaboFont.hanken(15, weight: .regular))
                        .foregroundStyle(Color(hex: 0x4A463F))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Spacer(minLength: 0)

                if let subject = card.course?.subject?.nilIfBlank ?? card.course?.title {
                    Text(subject.uppercased())
                        .font(MicaboFont.hanken(11, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                Text(card.front)
                    .font(MicaboFont.hanken(24, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .tracking(-0.2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                if onToggleHint != nil {
                    hintArea
                }
            }
        }
        .padding(showAnswer ? 26 : 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: showAnswer ? .topLeading : .center)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.xxl, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
    }

    /// Ampoule au pied de la question : un appui donne un coup de pouce sans livrer la réponse.
    @ViewBuilder
    private var hintArea: some View {
        if isHintVisible {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MicaboColor.caution)

                Text(StudyHint.text(for: card))
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

/// Indice affiché pendant la révision. Les cartes écrites par l'IA en portent souvent un ;
/// pour les autres, on en dérive un de la réponse plutôt que de laisser l'ampoule vide.
enum StudyHint {
    static func text(for card: Flashcard) -> String {
        if let written = card.hint?.nilIfBlank {
            return written
        }
        return derived(from: card.back)
    }

    static func derived(from answer: String) -> String {
        let words = answer
            .split(whereSeparator: { $0 == " " || $0.isNewline })
            .map(String.init)

        guard let first = words.first else {
            return "Pas d'indice pour cette carte."
        }

        guard words.count > 2 else {
            return "La réponse commence par « \(first) »."
        }

        let shown = max(1, min(3, words.count / 4))
        let start = words.prefix(shown).joined(separator: " ")
        return "Commence par « \(start)… », \(words.count) mots en tout."
    }
}

// MARK: - Boutons de maîtrise (grille 2×2 de la maquette)

struct GradeButtons: View {
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
                    Text(rating.label)
                        .font(MicaboFont.hanken(14, weight: .semibold))
                        .foregroundStyle(tint(for: rating))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(softTint(for: rating), in: RoundedRectangle(cornerRadius: MicaboRadius.button, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func tint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: Color(hex: 0xB5573C)
        case .hard: MicaboColor.caution
        case .good: MicaboColor.positive
        case .easy: MicaboColor.info
        }
    }

    private func softTint(for rating: ReviewRating) -> Color {
        switch rating {
        case .again: MicaboColor.negativeSoft
        case .hard: MicaboColor.cautionSoft
        case .good: MicaboColor.positiveSoft
        case .easy: MicaboColor.infoSoft
        }
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

                Text("Les notes déjà données sont enregistrées. Tu peux continuer la file où tu l'as laissée, ou repartir de la première carte du jour.")
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

private struct CompletionView: View {
    let session: StudySession
    let isEmbedded: Bool
    var onFinish: () -> Void

    private var isPractice: Bool {
        !session.mode.affectsSchedule
    }

    var body: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: session.answeredCount > 0 ? "trophy" : "moon.zzz")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(MicaboColor.caution)
                .frame(width: 78, height: 78)
                .background(MicaboColor.cautionSoft, in: Circle())
                .padding(.bottom, 8)

            Text(title)
                .font(MicaboFont.hanken(24, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .tracking(-0.2)

            Text(detail)
                .font(MicaboFont.body)
                .foregroundStyle(MicaboColor.inkTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, MicaboSpacing.lg)
                .padding(.bottom, 20)

            if session.answeredCount > 0 {
                HStack(spacing: 10) {
                    stat("\(session.goodCount)", "acquises", MicaboColor.positive)
                    stat("\(session.againCount)", "à revoir", MicaboColor.caution)
                    stat("\(Int(session.accuracy * 100)) %", "réussite", MicaboColor.accent)
                }
                .padding(.horizontal, MicaboSpacing.screen)
            }

            Spacer()

            Button(isEmbedded ? "Recharger la session" : "Terminer", action: onFinish)
                .buttonStyle(MicaboPrimaryButtonStyle())
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, MicaboSpacing.lg)
        }
    }

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(MicaboFont.hanken(22, weight: .bold))
                .foregroundStyle(tint)
            Text(label)
                .font(MicaboFont.hanken(10, weight: .medium))
                .foregroundStyle(MicaboColor.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .micaboGroup(radius: MicaboRadius.button)
    }

    private var title: String {
        guard session.answeredCount > 0 else { return "Rien à réviser" }
        return isPractice ? "Entraînement terminé" : "Session terminée"
    }

    private var detail: String {
        guard session.answeredCount > 0 else {
            return "Reviens plus tard, ou prends de l'avance depuis un cours."
        }
        let volume = "\(MicaboCopy.cards(session.answeredCount)) revues en \(durationLabel)"
        return isPractice ? "\(volume). Ton planning n'a pas bougé." : "\(volume)."
    }

    private var durationLabel: String {
        let minutes = Int(session.elapsed / 60)
        return minutes < 1 ? "< 1 min" : "\(minutes) min"
    }
}
