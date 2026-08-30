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
struct DiscountBadgeHost: View {
    /// Air à laisser sous la languette. La barre d'onglets n'est pas toujours là.
    var bottomInset: CGFloat

    @AppStorage(DiscountOffer.Key.startedAt) private var startedAtStamp: Double = 0
    @AppStorage(DiscountOffer.Key.seen) private var seen = false

    @Environment(ProAccess.self) private var pro: ProAccess?
    @Query private var courses: [Course]

    @State private var presentation: DiscountPresentation?

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
    }
}
