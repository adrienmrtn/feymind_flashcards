import SwiftData
import SwiftUI

/// **Créer une leçon, après l'envoi** (`docs/refonte-parcours.md` § 4) : « As-tu un examen ? »,
/// « Quelle date ? » si oui, puis l'écran de génération, relié au vrai travail de
/// `LessonBuilder`. La leçon s'ouvre dès que son plan est là et que son premier thème est écrit.
struct LessonCreationFlow: View {
    let composer: LessonComposer
    let onCreated: (Course) -> Void
    let onCancel: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(LessonBuilder.self) private var builder

    private enum Step: Equatable {
        case exam
        case date
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
            case .generating: generating.transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.4), value: step)
        .micaboPaywall($paywall)
    }

    // MARK: Les deux questions

    private var examQuestion: some View {
        VStack(spacing: 0) {
            closeBar
            Spacer()
            MikaMascot(mood: .think, size: 150)
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
            MikaMascot(mood: failure == nil ? .think : .sad, size: 170)
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
    /// L'identifiant de la leçon, gardé d'un essai à l'autre. Le serveur réserve la leçon sous
    /// cet identifiant (`begin_lesson`) : « Réessayer » avec un identifiant neuf la comptait
    /// comme une seconde leçon, et un élève sans abonnement dont le premier plan avait échoué
    /// tombait sur le paywall.
    @State private var lessonID = UUID()
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
        pendingExamDate = examDate
        failure = nil
        stage = nil
        step = .generating
        var request = composer.creation(examDate: examDate)
        request.lessonID = lessonID
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
                    withAnimation(.spring(duration: 0.35)) { self.stage = stage }
                }
                // Fermé pendant l'attente : la leçon reste dans la liste, mais on ne rouvre
                // pas un écran que l'élève a quitté.
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
        .animation(.spring(duration: 0.35), value: done)
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
