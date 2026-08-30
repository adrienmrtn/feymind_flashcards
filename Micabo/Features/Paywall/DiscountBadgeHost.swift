import SwiftData
import SwiftUI

/// **La pastille de l'offre, posée une fois pour toute l'app.**
///
/// Elle vit ici et pas dans chaque écran : le décompte des vingt-quatre heures ne doit pas
/// se remettre à zéro parce qu'on a changé d'onglet, et une pastille recopiée dans quatre
/// pages finirait par n'être à jour que dans trois.
///
/// Elle ne se montre qu'une fois la grande carte refermée — c'est `DiscountOffer.Key.seen`
/// qui bascule, et `@AppStorage` la fait apparaître sans qu'on la prévienne. Le cadeau,
/// lui, se présente sur la fiche du cours : c'est là qu'il a un sens.
struct DiscountBadgeHost: View {
    /// Air à laisser sous la pastille. La barre d'onglets n'est pas toujours là.
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
        ZStack(alignment: .bottomTrailing) {
            // Une surface transparente qui **ne prend pas les appuis**. Elle est là pour
            // que le plein écran de l'offre reste attaché à quelque chose quand la pastille
            // n'est pas affichée : un `fullScreenCover` posé sur une vue qui disparaît ne
            // s'ouvre plus.
            Color.clear
                .allowsHitTesting(false)

            if shows, let startedAt {
                DiscountBadge(startedAt: startedAt) {
                    presentation = .paywall
                }
                .padding(.trailing, MicaboSpacing.screen)
                .padding(.bottom, bottomInset)
                .transition(.opacity.combined(with: .offset(y: 10)))
            }
        }
        .animation(OnboardingMotion.enter, value: shows)
        .micaboDiscountOffer($presentation)
    }
}
