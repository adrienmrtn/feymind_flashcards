import Network
import Observation
import SwiftData
import SwiftUI

/// **La leçon que la Home écrit** (lot 10, HOME.md § 1).
///
/// L'écriture d'une leçon ne vit plus dans un écran plein qui cache l'app : une fois les deux
/// questions posées (`LessonCreationFlow`), la Home reprend la main et dit « J'écris ta
/// leçon… », la jauge à la place de l'action. Cet objet porte ce travail : il vit autant que la
/// Home, donc l'élève peut lancer une séance, scanner un exercice ou changer d'onglet pendant
/// que sa leçon s'écrit.
///
/// - `phase` : rien, en attente du réseau, en cours, en panne (`LessonGenerationPhase`).
/// - `stage` : l'étape du **vrai** travail (`LessonBuilder.Stage`) — la jauge n'a pas d'horloge.
/// - Une leçon arrivée, ou un refus du serveur qui se règle en passant à Pro, se signalent par
///   un compteur (`deliveries`, `refusals`) que la Home observe : ni drapeau à remettre à faux,
///   ni délai.
///
/// Hors ligne, la demande attend (`waiting`) et part dès que le réseau revient
/// (`networkReturned`). « Réessayer » reprend la même réservation (`LessonComposer.lessonID`) :
/// la leçon offerte ne se consomme pas deux fois.
@MainActor
@Observable
final class LessonGeneration {
    private(set) var phase: LessonGenerationPhase = .idle
    private(set) var stage: LessonBuilder.Stage?
    /// Ce que la leçon raconte : le sujet tapé, ou le nom du support. Il s'affiche sur la Home
    /// et ne part nulle part ailleurs.
    private(set) var subject: String?
    private(set) var hasSupports = false

    /// Une leçon est arrivée : la Home la prend (`takeDelivered`) et l'ouvre.
    private(set) var deliveries = 0
    /// Le serveur a refusé une leçon qui s'ouvre avec Pro : la Home prend le paywall
    /// (`takeRefusal`).
    private(set) var refusals = 0

    @ObservationIgnored private var delivered: Course?
    @ObservationIgnored private var refusal: PaywallTrigger?
    @ObservationIgnored private var request: Request?
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Le rang de l'écriture en cours : une écriture abandonnée ne parle plus pour la suivante.
    @ObservationIgnored private var runs = 0

    /// Tout ce qu'il faut pour écrire, et pour réessayer.
    private struct Request {
        let composer: LessonComposer
        let builder: LessonBuilder
        let context: ModelContext
        var examDate: Date?
        var sendsAsFreeLesson: Bool
    }

    /// Vrai tant qu'une leçon s'écrit, attend le réseau ou attend qu'on réessaie : la barre de
    /// saisie patiente.
    var isBusy: Bool { phase != .idle }

    /// Vrai quand la panne affichée est un refus qui s'ouvre avec Pro : un abonnement pris
    /// relance l'écriture.
    private(set) var wasRefused = false

    // MARK: Lancer

    /// Lance l'écriture de ce que le compositeur a préparé. Hors ligne, la demande attend.
    func start(
        composer: LessonComposer,
        builder: LessonBuilder,
        context: ModelContext,
        examDate: Date?,
        sendsAsFreeLesson: Bool,
        online: Bool
    ) {
        // Un double appui ne lance pas deux écritures.
        guard phase != .running else { return }
        request = Request(
            composer: composer,
            builder: builder,
            context: context,
            examDate: examDate,
            sendsAsFreeLesson: sendsAsFreeLesson
        )
        let ready = composer.readySupports
        hasSupports = !ready.isEmpty
        let typed = composer.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        subject = typed.nilIfBlank ?? (ready.count == 1 ? ready[0].title.nilIfBlank : nil)
        if online {
            run()
        } else {
            wasRefused = false
            stage = nil
            phase = .waiting
        }
    }

    /// « Réessayer » : la même demande, la même réservation.
    func retry() {
        guard request != nil, phase != .running else { return }
        run()
    }

    /// Le réseau est revenu : une demande qui attendait part.
    func networkReturned() {
        guard phase == .waiting else { return }
        run()
    }

    /// Abandonne la leçon en cours, en attente ou en panne. Ce que l'élève avait préparé reste
    /// dans la barre : il peut le reprendre.
    func cancel() {
        task?.cancel()
        task = nil
        runs += 1
        request = nil
        wasRefused = false
        stage = nil
        subject = nil
        phase = .idle
    }

    // MARK: Ce que la Home prend

    /// La leçon arrivée, une fois.
    func takeDelivered() -> Course? {
        defer { delivered = nil }
        return delivered
    }

    /// Le paywall d'un refus, une fois.
    func takeRefusal() -> PaywallTrigger? {
        defer { refusal = nil }
        return refusal
    }

    // MARK: Le travail

    private func run() {
        guard let request else { return }
        wasRefused = false
        stage = nil
        phase = .running

        var prepared = request.composer.creation(examDate: request.examDate)
        prepared.lessonID = request.composer.reserveLessonID(for: prepared.source)
        prepared.onboarding = request.sendsAsFreeLesson && prepared.source.isImport
        let creation = prepared
        // Des valeurs fixes et des tailles : ni le sujet tapé ni le contenu du cours.
        let properties: [String: AnalyticsValue] = [
            "source": .text(creation.source.rawValue),
            "chars": .number(Double(creation.text.count)),
            "exam": .flag(request.examDate != nil),
            "lesson": .flag(true),
        ]
        Analytics.track(.courseGenerationStarted, properties)

        task?.cancel()
        runs += 1
        let run = runs
        task = Task { [weak self] in
            do {
                let course = try await request.builder.create(creation, in: request.context) { reached in
                    // Une écriture abandonnée puis relancée : l'ancienne ne déplace plus la jauge.
                    guard let self, self.runs == run else { return }
                    self.stage = reached
                }
                // La leçon existe sous cet identifiant, abandonnée entre-temps ou non : la
                // prochaine demande en prend un neuf, et elle rapporte son XP.
                request.composer.lessonDelivered()
                XPStore.shared.award(.lessonCreated)
                guard !Task.isCancelled else { return }
                Haptics.success()
                Analytics.track(.courseImported, properties)
                self?.finish(with: course)
            } catch _ where Task.isCancelled {
                // Abandonnée par l'élève : ni vibration, ni message, ni échec compté.
                return
            } catch let error as LessonServiceError where error.opensPaywall {
                self?.refuse(error)
            } catch {
                Haptics.warning()
                Analytics.track(.courseGenerationFailed, properties)
                self?.fail((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
            }
        }
    }

    private func finish(with course: Course) {
        task = nil
        request = nil
        stage = nil
        subject = nil
        phase = .idle
        delivered = course
        deliveries += 1
    }

    private func refuse(_ error: LessonServiceError) {
        task = nil
        wasRefused = true
        phase = .failed(error.errorDescription ?? "")
        refusal = error == .importPro ? .generateCourse : .secondCourse
        refusals += 1
    }

    private func fail(_ message: String) {
        task = nil
        phase = .failed(message)
    }
}

// MARK: - Le réseau

/// **Le réseau est-il là ?** La Home le lit pour ne pas lancer une écriture qui attendrait sans
/// fin : hors ligne, la demande patiente et Mika le dit ; elle part quand le réseau revient.
///
/// L'observateur du système (`NWPathMonitor`) prévient à chaque changement ; rien n'est écrit
/// quand rien ne change, pour ne redessiner personne.
@MainActor
@Observable
final class HomeConnectivity {
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    @ObservationIgnored private var started = false

    /// Commence à écouter, une fois. À appeler quand la Home apparaît.
    func start() {
        guard !started else { return }
        started = true
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status != .unsatisfied
            Task { @MainActor [weak self] in
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
            }
        }
        monitor.start(queue: DispatchQueue(label: "micabo.home.connectivity"))
    }

    deinit {
        monitor.cancel()
    }
}
