import SwiftData
import SwiftUI

/// **Créer une leçon, après l'envoi** (`docs/refonte-parcours.md` § 4) : « As-tu un examen ? »,
/// « Quelle date ? » si oui — deux questions, posées par Mika dans sa bulle, les réponses
/// ancrées en bas. Puis l'écran se referme et **la Home écrit la leçon** (`LessonGeneration`) :
/// « J'écris ta leçon… », la jauge à la place de l'action. L'élève n'attend plus devant un
/// écran plein qui cache l'app.
///
/// **La leçon verrouillée.** Un élève sans abonnement dont la leçon offerte a servi, et qui a
/// déposé des supports, ne tombe pas sur le paywall au moment d'envoyer : il répond aux mêmes
/// questions, voit ce que Mika a lu (`LockedLessonPreview`), puis le paywall `lessonReady`
/// s'ouvre au moment de débloquer la leçon. Abonné, l'écriture part aussitôt avec les mêmes
/// supports ; refermé sans abonnement, la Home garde la leçon en attente (« Débloquer ma
/// leçon »). Rien n'est demandé au serveur avant, qui refuserait.
struct LessonCreationFlow: View {
    let composer: LessonComposer
    /// Les questions sont répondues (et la leçon peut s'écrire) : la date d'examen, s'il y en a
    /// une. La Home referme l'écran et lance l'écriture.
    let onGenerate: (Date?) -> Void
    /// L'aperçu verrouillé est refermé sans abonnement : la Home garde la leçon en attente.
    let onLocked: (HomeLockedLesson) -> Void
    let onCancel: () -> Void

    /// Optionnel, comme dans Home : sans lui, la demande part et le serveur tient la porte.
    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Les cours de l'élève : ce sont eux qui disent si la leçon offerte a servi.
    @Query private var courses: [Course]

    private enum Step: Equatable {
        case exam
        case date
        /// Ce que Mika a lu, sous cadenas, et le paywall par-dessus.
        case locked
    }

    @State private var step: Step = .exam
    @State private var examDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    /// La date retenue au moment de passer à l'aperçu verrouillé : la leçon part avec elle.
    @State private var pendingExamDate: Date?
    @State private var paywall: PaywallTrigger?

    var body: some View {
        ZStack {
            V3Color.bg.ignoresSafeArea()
            switch step {
            case .exam: examQuestion.transition(.push(from: .trailing))
            case .date: dateQuestion.transition(.push(from: .trailing))
            case .locked: lockedPreview.transition(.opacity)
            }
        }
        .animation(MicaboMotion.resolved(MicaboMotion.standard, reduceMotion: reduceMotion), value: step)
        .micaboPaywall($paywall, onSubscribed: subscribed)
    }

    // MARK: Les deux questions

    private var examQuestion: some View {
        V3Screen(onBack: onCancel) {
            MikaAsk(L10n.t("lesson.create.examQuestion", locale: .resolved()), mood: .wink)
        } footer: {
            V3Button(L10n.t("lesson.create.examYes", locale: .resolved())) {
                step = .date
            }
            V3Button(L10n.t("lesson.create.examNo", locale: .resolved()), kind: .secondary) {
                answer(examDate: nil)
            }
        }
    }

    private var dateQuestion: some View {
        V3Screen(onBack: { step = .exam }) {
            MikaAsk(L10n.t("lesson.create.dateQuestion", locale: .resolved()), mood: .idle)
            DatePicker(
                "",
                selection: $examDate,
                in: Self.tomorrow...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .tint(V3Color.accent)
            .padding(.top, 12)
        } footer: {
            V3Button(L10n.t("lesson.create.continue", locale: .resolved())) {
                answer(examDate: Calendar.current.startOfDay(for: examDate))
            }
        }
    }

    private static var tomorrow: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
    }

    /// Les questions sont répondues. La leçon offerte a servi et des supports sont lus :
    /// l'aperçu verrouillé, pas le serveur, qui refuserait (`LessonAllowance.sendRoute`).
    /// Sinon, la Home écrit.
    private func answer(examDate: Date?) {
        pendingExamDate = examDate
        guard LessonAllowance.sendRoute(isPro: pro?.isPro ?? true, source: composer.source, courses: courses) == .lockedPreview else {
            onGenerate(examDate)
            return
        }
        let summary = readSummary
        // Des comptes et des valeurs fixes : rien de ce que l'élève a déposé.
        Analytics.track(.lessonLockedPreview, [
            "source": .text(composer.source.rawValue),
            "supports": .number(Double(summary.supports)),
            "pages": .number(Double(summary.pages)),
            "words": .number(Double(summary.words)),
            "exam": .flag(examDate != nil),
        ])
        step = .locked
    }

    // MARK: La leçon verrouillée

    private var lockedPreview: some View {
        LockedLessonPreview(
            summary: readSummary,
            onUnlock: { paywall = .lessonReady },
            onClose: {
                onLocked(HomeLockedLesson(summary: readSummary, examDate: pendingExamDate))
            },
            onRevealed: {
                guard step == .locked, paywall == nil else { return }
                paywall = .lessonReady
            }
        )
    }

    private var readSummary: LessonReadSummary {
        LessonReadSummary(documents: composer.readySupports.compactMap(\.document))
    }

    /// Abonné depuis l'aperçu : l'écriture part tout de suite, avec les mêmes supports et la
    /// même date d'examen. La Home referme cet écran et prend le relais.
    private func subscribed() {
        guard step == .locked else { return }
        onGenerate(pendingExamDate)
    }
}

/// Les quatre étapes de l'écriture d'une leçon, nommées au rythme du vrai travail : la Home
/// écrit celle qui est en cours sous sa jauge.
enum GenerationSteps {
    static func key(for stage: LessonBuilder.Stage, hasSupports: Bool) -> String {
        switch stage {
        case .reading: hasSupports ? "lesson.create.stageReading" : "lesson.create.stageTopic"
        case .cutting: "lesson.create.stageCutting"
        case .writing: "lesson.create.stageWriting"
        case .questions: "lesson.create.stageQuestions"
        }
    }
}
