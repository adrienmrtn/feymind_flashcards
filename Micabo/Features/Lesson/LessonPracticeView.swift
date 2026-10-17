import SwiftData
import SwiftUI

/// **L'entraînement d'une leçon**, depuis la barre du bas : dix questions sur toute la leçon,
/// puis, quand on veut continuer, « Générer de nouvelles questions » : Mika en écrit un lot
/// neuf, loin de celles déjà posées, surtout là où l'élève se trompe. Le lot rejoint la leçon :
/// il ressort dans les quiz suivants.
///
/// Sans abonnement, un lot est offert ; le suivant ouvre le paywall. Le serveur tient la même
/// porte (`begin_extra`) : ce que l'app retient ici évite seulement un appel pour rien.
struct LessonPracticeView: View {
    let session: LessonSession

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LessonBuilder.self) private var builder
    @Environment(ProAccess.self) private var pro: ProAccess?

    private enum Phase: Equatable {
        case quiz
        case writing
        case failed(String)
    }

    @State private var phase: Phase = .quiz
    @State private var round = 0
    @State private var questions: [QuizQuestion]
    /// Le nombre de questions du dernier lot écrit, pour le dire.
    @State private var freshCount = 0
    @State private var paywall: PaywallTrigger?

    init(session: LessonSession, attempt: Int) {
        self.session = session
        _questions = State(initialValue: session.fullQuiz(attempt: attempt))
    }

    var body: some View {
        Group {
            switch phase {
            case .quiz:
                LessonQuizView(
                    session: session,
                    questions: questions,
                    title: L10n.t("lesson.practice.title", locale: .resolved()),
                    circleID: nil,
                    onClose: { dismiss() },
                    onMore: generate
                )
                .id(round)
                .overlay(alignment: .top) {
                    if freshCount > 0 {
                        Label(L10n.t("lesson.practice.newBadge", locale: .resolved(), vars: ["count": String(freshCount)]), systemImage: "sparkles")
                            .font(MicaboFont.ui(13, weight: .heavy))
                            .foregroundStyle(session.course.tone.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(session.course.tone.pale, in: Capsule())
                            .padding(.top, 54)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
            case .writing:
                writing
            case .failed(let message):
                failed(message)
            }
        }
        .animation(.spring(duration: 0.45), value: phase)
        .background(MicaboColor.canvas.ignoresSafeArea())
        .micaboPaywall($paywall)
    }

    // MARK: Écrire un lot

    private func generate() {
        let isPro = pro?.isPro == true
        if !isPro && PracticeAllowance.freeBatchUsed {
            paywall = .practice
            return
        }
        phase = .writing
        Task {
            do {
                let fresh = try await builder.practice(session.course, in: modelContext)
                if !isPro { PracticeAllowance.freeBatchUsed = true }
                session.reload()
                guard !fresh.isEmpty else {
                    phase = .failed(L10n.t("lesson.practice.failed", locale: .resolved()))
                    return
                }
                questions = LessonPicking.progressive(fresh)
                freshCount = fresh.count
                round += 1
                phase = .quiz
                Haptics.success()
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { freshCount = 0 } }
            } catch let error as LessonServiceError where error.opensPaywall {
                PracticeAllowance.freeBatchUsed = true
                phase = .quiz
                paywall = .practice
            } catch {
                phase = .failed((error as? LocalizedError)?.errorDescription ?? L10n.t("lesson.practice.failed", locale: .resolved()))
            }
        }
    }

    private var writing: some View {
        VStack(spacing: 20) {
            Spacer()
            MikaMascot(mood: .think, size: 170)
            Text(L10n.t("lesson.practice.writing", locale: .resolved()))
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Text(L10n.t("lesson.practice.writingSub", locale: .resolved()))
                .font(MicaboFont.ui(16, weight: .medium))
                .foregroundStyle(MicaboColor.inkSecondary)
                .multilineTextAlignment(.center)
            ProgressView()
                .tint(session.course.tone.vivid)
                .padding(.top, 6)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 18) {
            Spacer()
            MikaMascot(mood: .sad, size: 150)
            Text(message)
                .font(MicaboFont.subtitle)
                .foregroundStyle(MicaboColor.ink)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button(L10n.t("lesson.practice.retry", locale: .resolved()), action: generate)
                    .buttonStyle(LessonPrimaryButtonStyle())
                Button(L10n.t("lesson.practice.back", locale: .resolved())) { dismiss() }
                    .buttonStyle(MicaboSecondaryButtonStyle())
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }
}

/// Le lot de nouvelles questions offert, une fois. Le serveur tient la même règle.
enum PracticeAllowance {
    private static let key = "micabo.practice.freeBatchUsed"

    static var freeBatchUsed: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
