import SwiftData
import SwiftUI

/// **La languette de l'offre, posée une fois pour toute l'app.**
///
/// Elle vit ici et pas dans chaque écran : le décompte des vingt-quatre heures ne doit pas
/// se remettre à zéro parce qu'on a changé d'onglet, et une pastille recopiée dans quatre
/// pages finirait par n'être à jour que dans trois.
///
/// Elle se colle au **bord droit**, à mi-hauteur, au-dessus de la barre et des boutons du
/// bas : une pastille dans le coin bas-droit recouvrait le bouton de session, et c'est
/// précisément ce qu'on ne veut plus. Le cadeau, lui, se présente en pop-up sur la fiche
/// du cours : c'est là qu'il a un sens.
///
/// Le `ZStack` ne prend **aucun appui** hors de la languette : une surface pleine qui
/// avale les doigts rendrait l'app inerte.
///
/// **C'est aussi d'ici que l'offre s'ouvre à chaque ouverture de l'app**, tant que personne
/// n'a pris d'abonnement : voir `offerAtLaunch()`. Le tarif réduit n'a jamais été vu par la
/// moitié de ceux à qui il était destiné - il fallait tomber sur un cadeau surgi une fois
/// sur une fiche - et App Review, qui n'importe pas de cours, ne le trouvait pas du tout.
struct DiscountBadgeHost: View {
    /// Air à laisser sous la languette. La barre d'onglets n'est pas toujours là.
    var bottomInset: CGFloat

    @AppStorage(DiscountOffer.Key.startedAt) private var startedAtStamp: Double = 0
    @AppStorage(DiscountOffer.Key.seen) private var seen = false

    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(\.scenePhase) private var scenePhase
    @Query private var courses: [Course]

    @State private var presentation: DiscountPresentation?
    /// L'instant où l'app est passée en arrière-plan. Revenir d'un basculement d'une seconde
    /// n'est pas une ouverture ; revenir une heure plus tard en est une.
    @State private var leftAt: Date?
    @State private var didOfferOnLaunch = false

    private var startedAt: Date? {
        startedAtStamp > 0 ? Date(timeIntervalSince1970: startedAtStamp) : nil
    }

    private var ownedCourses: Int {
        courses.filter { !$0.isFromLibrary }.count
    }

    private var shows: Bool {
        DiscountOffer.shouldShowBadge(
            isPro: pro?.isPro ?? true,
            courseCount: ownedCourses,
            seen: seen,
            startedAt: startedAt
        )
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .allowsHitTesting(false)

            if shows, let startedAt {
                DiscountBadge(startedAt: startedAt) {
                    presentation = .paywall
                }
                // Remonte la languette au-dessus de la barre et du bouton de session.
                .padding(.bottom, bottomInset + 72)
                .transition(.opacity.combined(with: .offset(x: 12)))
            }
        }
        .animation(OnboardingMotion.enter, value: shows)
        .micaboDiscountOffer($presentation)
        .task {
            guard !didOfferOnLaunch else { return }
            didOfferOnLaunch = true
            await offerAtLaunch()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background, .inactive:
                if leftAt == nil { leftAt = Date() }
            case .active:
                guard let left = leftAt else { return }
                leftAt = nil
                guard Date().timeIntervalSince(left) >= Self.awaySeconds else { return }
                Task { await offerAtLaunch() }
            @unknown default:
                break
            }
        }
    }

    /// **Le tarif réduit, à chaque ouverture, tant qu'on n'est pas abonné.**
    ///
    /// C'est la seule façon qu'une offre ait une chance d'être vue : un cadeau qui surgit une
    /// fois sur une fiche se manque, et une languette dans un coin se regarde sans se toucher.
    /// C'est aussi ce qui rend l'achat **trouvable sans rien chercher** — la remarque d'App
    /// Review, qui ouvrait l'app et ne voyait jamais l'abonnement à tarif réduit.
    ///
    /// L'attente n'est pas décorative : l'app vient de se peindre, et une carte qui arrive
    /// pendant que la première image se pose donne deux animations concurrentes.
    @MainActor
    private func offerAtLaunch() async {
        guard !(pro?.isPro ?? true) else { return }
        try? await Task.sleep(for: .milliseconds(1400))
        guard !Task.isCancelled, presentation == nil, !(pro?.isPro ?? true) else { return }
        presentation = .paywall
    }

    /// Au-delà, revenir dans l'app est une ouverture. En deçà, c'est un aller-retour vers
    /// l'appareil photo ou une notification, et interrompre ça serait de la nuisance.
    private static let awaySeconds: TimeInterval = 20 * 60
}
