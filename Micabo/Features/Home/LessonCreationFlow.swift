import SwiftData
import SwiftUI

/// **Créer une leçon, après l'envoi** (`docs/refonte-parcours.md` § 4) : « As-tu un examen ? »,
/// « Quelle date ? » si oui, puis l'écran de génération, relié au vrai travail de
/// `LessonBuilder`. La leçon s'ouvre dès que son plan est là et que son premier thème est écrit.
///
/// **La leçon verrouillée.** Un élève sans abonnement dont la leçon offerte a servi, et qui a
/// déposé des supports, ne tombe plus sur le paywall au moment d'envoyer : il répond aux mêmes
/// questions, voit ce que Mika a lu (`LockedLessonPreview`), puis le paywall `lessonReady`
/// s'ouvre au moment de débloquer la leçon. Abonné, la génération part aussitôt avec les mêmes
/// supports ; rien n'est demandé au serveur avant, qui refuserait.
struct LessonCreationFlow: View {
    let composer: LessonComposer
    /// **La leçon offerte, depuis un import** (`docs/refonte-knowunity.md` § 7) : la demande
    /// part avec `onboarding: true`, que `begin_lesson` accepte pour la leçon offerte.
    var sendsAsFreeLesson = false
    let onCreated: (Course) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(LessonBuilder.self) private var builder
    /// Optionnel, comme dans Home : sans lui, la demande part et le serveur tient la porte.
    @Environment(ProAccess.self) private var pro: ProAccess?
    /// Les cours de l'élève : ce sont eux qui disent si la leçon offerte a servi.
    @Query private var courses: [Course]

    private enum Step: Equatable {
        case exam
        case date
        /// Ce que Mika a lu, sous cadenas, et le paywall par-dessus.
        case locked
        case generating
    }

    @State private var step: Step = .exam
    @State private var examDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var stage: LessonBuilder.Stage?
    @State private var failure: String?
    @State private var paywall: PaywallTrigger?

    private var hasSupports: Bool { !composer.readySupports.isEmpty }

    var body: some View {
        ZStack {
            MicaboColor.canvas.ignoresSafeArea()
            switch step {
            case .exam: examQuestion.transition(.push(from: .trailing))
            case .date: dateQuestion.transition(.push(from: .trailing))
            case .locked: lockedPreview.transition(.opacity)
            case .generating: generating.transition(.opacity)
            }
        }
        .animation(MicaboMotion.gentle, value: step)
        .micaboPaywall($paywall, onSubscribed: subscribed)
    }

    // MARK: La leçon verrouillée

    private var lockedPreview: some View {
        LockedLessonPreview(
            summary: readSummary,
            onUnlock: { paywall = .lessonReady },
            onClose: close,
            onRevealed: {
                guard step == .locked, paywall == nil else { return }
                paywall = .lessonReady
            }
        )
    }

    private var readSummary: LessonReadSummary {
        LessonReadSummary(documents: composer.readySupports.compactMap(\.document))
    }

    /// Abonné depuis l'aperçu, ou depuis le paywall d'un refus du serveur : la génération
    /// part tout de suite, avec les mêmes supports et la même date d'examen.
    private func subscribed() {
        guard step == .locked || failure != nil else { return }
        // Le temps que la feuille du paywall descende : la génération se lit sans elle.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            start(examDate: pendingExamDate)
        }
    }

    // MARK: Les deux questions

    private var examQuestion: some View {
        VStack(spacing: 0) {
            closeBar
            Spacer()
            MikaMascot(mood: .wink, size: 120)
            Text(L10n.t("lesson.create.examQuestion", locale: .resolved()))
                .font(MicaboFont.title)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 20)
                .padding(.horizontal, 32)
            Spacer()
            VStack(spacing: 12) {
                Button(L10n.t("lesson.create.examYes", locale: .resolved())) {
                    step = .date
                }
                .buttonStyle(LessonPrimaryButtonStyle())
                Button(L10n.t("lesson.create.examNo", locale: .resolved())) {
                    start(examDate: nil)
                }
                .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 16)
        }
    }

    private var dateQuestion: some View {
        VStack(spacing: 0) {
            closeBar
            Text(L10n.t("lesson.create.dateQuestion", locale: .resolved()))
                .font(MicaboFont.title)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)
            DatePicker(
                "",
                selection: $examDate,
                in: Self.tomorrow...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(MicaboColor.accent)
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, 12)
            Spacer()
            Button(L10n.t("lesson.create.continue", locale: .resolved())) {
                start(examDate: Calendar.current.startOfDay(for: examDate))
            }
            .buttonStyle(LessonPrimaryButtonStyle())
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 16)
        }
    }

    private static var tomorrow: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
    }

    private var closeBar: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: La génération

    private var generating: some View {
        VStack(spacing: 0) {
            // **La croix reste là pendant la génération**, pas seulement après un échec. Hors
            // ligne, la requête attendait le réseau sans fin et l'écran n'offrait aucune sortie :
            // il fallait tuer l'app. Fermer ici abandonne l'attente (voir `close`).
            closeBar
            Spacer()
            MikaMascot(mood: failure == nil ? .write : .sad, size: 150)
            Text(failure == nil
                ? L10n.t("lesson.create.generatingTitle", locale: .resolved())
                : L10n.t("lesson.create.failedTitle", locale: .resolved()))
                .font(MicaboFont.title)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .padding(.horizontal, 32)

            if let failure {
                Text(failure)
                    .font(MicaboFont.ui(16, weight: .medium))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 32)
            } else {
                GenerationSteps(current: stage, hasSupports: hasSupports)
                    .padding(.top, 28)
                    .padding(.horizontal, 40)
            }
            Spacer()
            if failure != nil {
                VStack(spacing: 12) {
                    Button(L10n.t("lesson.path.retry", locale: .resolved())) {
                        start(examDate: pendingExamDate)
                    }
                    .buttonStyle(LessonPrimaryButtonStyle())
                    Button(L10n.t("lesson.create.cancel", locale: .resolved()), action: close)
                        .buttonStyle(MicaboSecondaryButtonStyle())
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.bottom, 16)
            }
        }
    }

    @State private var pendingExamDate: Date?
    // L'identifiant de la leçon n'est plus ici : un `@State` renaissait à chaque ouverture de
    // l'écran, et un écran refermé pendant la génération puis rouvert réservait une seconde
    // leçon. Le compositeur le garde jusqu'à l'arrivée de la leçon (`LessonComposer.lessonID`).
    /// La génération en vol, gardée pour pouvoir l'abandonner quand l'élève ferme l'écran.
    @State private var generation: Task<Void, Never>?

    /// Ferme l'écran, en abandonnant la génération en cours. Sans l'annulation, une leçon
    /// arrivée après la fermeture rouvrait un écran que l'élève venait de quitter.
    private func close() {
        generation?.cancel()
        generation = nil
        onCancel()
    }

    private func start(examDate: Date?) {
        // Un double appui sur « Non » lançait deux générations : une seule à la fois, sauf
        // pour réessayer après un échec.
        guard step != .generating || failure != nil else { return }
        pendingExamDate = examDate
        failure = nil
        stage = nil
        // La leçon offerte a servi et des supports sont lus : l'aperçu verrouillé, pas le
        // serveur, qui refuserait (`LessonAllowance.sendRoute`).
        if LessonAllowance.sendRoute(isPro: pro?.isPro ?? true, source: composer.source, courses: courses) == .lockedPreview {
            if step != .locked {
                let summary = readSummary
                Analytics.track(.lessonLockedPreview, [
                    "source": .text(composer.source.rawValue),
                    "supports": .number(Double(summary.supports)),
                    "pages": .number(Double(summary.pages)),
                    "words": .number(Double(summary.words)),
                    "exam": .flag(examDate != nil),
                ])
            }
            step = .locked
            return
        }
        step = .generating
        var request = composer.creation(examDate: examDate)
        request.lessonID = composer.reserveLessonID(for: request.source)
        request.onboarding = sendsAsFreeLesson && request.source.isImport
        let properties: [String: AnalyticsValue] = [
            "source": .text(request.source.rawValue),
            "chars": .number(Double(request.text.count)),
            "exam": .flag(examDate != nil),
            "lesson": .flag(true),
        ]
        Analytics.track(.courseGenerationStarted, properties)
        generation?.cancel()
        generation = Task {
            do {
                let course = try await builder.create(request, in: modelContext) { stage in
                    withAnimation(MicaboMotion.standard) { self.stage = stage }
                }
                // La leçon existe sous cet identifiant, écran fermé ou non : la prochaine
                // demande en prend un neuf.
                composer.lessonDelivered()
                // Fermé pendant l'attente : la leçon reste dans la liste, mais on ne rouvre
                // pas un écran que l'élève a quitté.
                // Une leçon créée et livrée rapporte son XP, écran fermé ou non.
                XPStore.shared.award(.lessonCreated)
                guard !Task.isCancelled else { return }
                Haptics.success()
                Analytics.track(.courseImported, properties)
                onCreated(course)
            } catch _ where Task.isCancelled {
                // Abandonné par la croix : ni haptique, ni message, ni échec compté.
                return
            } catch let error as LessonServiceError where error.opensPaywall {
                failure = error.errorDescription
                paywall = error == .importPro ? .generateCourse : .secondCourse
            } catch {
                Haptics.warning()
                Analytics.track(.courseGenerationFailed, properties)
                failure = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

/// Les quatre étapes de la génération, cochées au rythme du vrai travail.
struct GenerationSteps: View {
    let current: LessonBuilder.Stage?
    let hasSupports: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(LessonBuilder.Stage.allCases, id: \.self) { stage in
                row(stage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ stage: LessonBuilder.Stage) -> some View {
        let done = current.map { stage < $0 } ?? false
        let active = current == stage || (current == nil && stage == .reading)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? MicaboColor.correct : active ? MicaboColor.accentSoft : MicaboColor.surfaceSunken)
                    .frame(width: 30, height: 30)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(MicaboColor.onInk)
                } else if active {
                    ProgressView()
                        .controlSize(.small)
                        .tint(MicaboColor.accent)
                }
            }
            Text(L10n.t(Self.key(for: stage, hasSupports: hasSupports), locale: .resolved()))
                .font(MicaboFont.ui(17, weight: active ? .heavy : .bold))
                .foregroundStyle(done || active ? MicaboColor.ink : MicaboColor.inkTertiary)
        }
        .animation(MicaboMotion.standard, value: done)
    }

    static func key(for stage: LessonBuilder.Stage, hasSupports: Bool) -> String {
        switch stage {
        case .reading: hasSupports ? "lesson.create.stageReading" : "lesson.create.stageTopic"
        case .cutting: "lesson.create.stageCutting"
        case .writing: "lesson.create.stageWriting"
        case .questions: "lesson.create.stageQuestions"
        }
    }
}
