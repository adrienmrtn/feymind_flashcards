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
/// précisément ce qu'on ne veut plus. Le cadeau, lui, se présente en pop-up sur le premier
/// chapitre du premier deck importé : c'est là qu'il a un sens.
///
/// Le `ZStack` ne prend **aucun appui** hors de la languette : une surface pleine qui
/// avale les doigts rendrait l'app inerte.
///
/// **Elle n'ouvre plus rien d'elle-même.** L'offre se présentait ici à chaque lancement,
/// une seconde et demie après la première image — et cette feuille, posée depuis la
/// racine, refermait ce qui était déjà ouvert au-dessus des onglets : l'import du premier
/// deck, qui s'ouvre tout seul après le parcours, se faisait couper sous les doigts. Le
/// cadeau se présente désormais à l'ouverture du premier chapitre du premier deck importé,
/// depuis cette page-là (`ChapterSheetView`), et l'abonnement reste trouvable sans rien
/// chercher par la rangée des Réglages.
struct DiscountBadgeHost: View {
    /// Air à laisser sous la languette. La barre d'onglets n'est pas toujours là.
    var bottomInset: CGFloat

    @AppStorage(DiscountOffer.Key.startedAt) private var startedAtStamp: Double = 0
    @AppStorage(DiscountOffer.Key.seen) private var seen = false

    @Environment(ProAccess.self) private var pro: ProAccess?
    @Environment(CloudSync.self) private var sync: CloudSync?
    @Environment(\.modelContext) private var modelContext

    /// **Le nombre de cours, compté et non observé.**
    ///
    /// Cette vue est montée en permanence par-dessus les onglets (`RootTabView`), donc tout ce
    /// qu'elle observe vit tant que l'app vit. Elle tenait ici un `@Query` sur `Course` — la
    /// table entière, trente kilo-octets de texte par ligne, rematérialisée sur l'acteur
    /// principal à chaque écriture SwiftData — pour en tirer un entier et le comparer à un.
    ///
    /// Le compte se relit donc quand il a pu changer : un cours créé ou supprimé
    /// (`CourseLedger`), une descente de synchro (`CloudSync.epoch`). Entre les deux, rien
    /// n'est lu.
    ///
    /// Il est gardé d'un lancement à l'autre, et ce n'est pas de l'optimisation : la première
    /// image se peint avant toute lecture de base. Un compte qui partirait de zéro rendrait
    /// `shows` faux à la première passe, et la languette **arriverait en fondu** à chaque
    /// ouverture chez quelqu'un qui a déjà des cours — `.animation(_:value:)` est posée juste
    /// en dessous. La valeur d'hier est juste, et la lecture qui suit la corrige.
    @AppStorage(DiscountOffer.Key.ownedCourses) private var ownedCourses = 0

    @State private var presentation: DiscountPresentation?

    private var startedAt: Date? {
        startedAtStamp > 0 ? Date(timeIntervalSince1970: startedAtStamp) : nil
    }

    /// Ce qui fait recompter. Le tampon des cours couvre l'import, la reprise et la
    /// suppression ; l'époque de synchro couvre ce qui descend du serveur.
    private var countKey: String {
        "\(CourseLedger.shared.stamp)-\(sync?.epoch ?? 0)"
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
        // Le compte n'est réécrit que s'il a changé : `@AppStorage` écrit dans les réglages et
        // invalide la vue à chaque affectation, même quand la valeur est la même.
        .task(id: countKey) {
            let count = CourseRepository.ownedCount(in: modelContext)
            if count != ownedCourses { ownedCourses = count }
        }
    }
}
