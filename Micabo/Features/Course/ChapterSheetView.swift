import SwiftData
import SwiftUI

/// **Un chapitre ouvert : ce qu'on lit, puis ce qu'on révise.**
///
/// La fiche entière reste lisible d'un bloc depuis l'écran du deck ; celui-ci ne montre
/// qu'une partie, et c'est ce qui permet de la réviser seule. Le contrôle de jeudi ne
/// porte que sur la guerre froide : faire repasser les huit autres chapitres du deck pour
/// atteindre celui-là est exactement ce qui fait renoncer.
///
/// Les blocs sont rendus par `SheetBlockView`, le même composant que la fiche complète.
/// Un second rendu pour le même format finirait par diverger du premier — un surligneur
/// qui ne se pose plus, une formule qui ne se compose plus — et personne ne le verrait
/// avant de comparer les deux écrans côte à côte.
struct ChapterSheetView: View {
    @Bindable var chapter: Chapter

    @Environment(\.modelContext) private var modelContext
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var blocks: [SheetBlock] = []
    @State private var studying = false
    @State private var dueCount = 0

    private var tint: Color {
        Color(hexString: chapter.course?.accentHex ?? "")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                caption

                if blocks.isEmpty {
                    Text(i18n.t("ios.deck.emptyChapter"))
                        .font(MicaboFont.ui(14, weight: .regular))
                        .foregroundStyle(MicaboColor.inkSecondary)
                } else {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        SheetBlockView(block: block, tint: tint)
                    }
                }
            }
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.top, MicaboSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .navigationTitle(chapter.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            reviewButton
        }
        .onAppear(perform: reload)
        .fullScreenCover(isPresented: $studying) {
            StudyView(source: .chapter(chapter), mode: .scheduled)
                .onDisappear(perform: reload)
        }
    }

    /// Le nombre de cartes, et combien sont dues. C'est ce qui dit s'il y a quelque chose à
    /// faire ici maintenant, avant même de lire le bouton.
    private var caption: some View {
        MicaboSectionCaption(
            text: i18n.t("ios.deck.cardCount", ["count": "\(chapter.cardCount)"])
        )
    }

    /// **Le bouton garde son nom.** « Réviser N cartes » est le même libellé que depuis
    /// l'onglet Réviser et depuis un deck : un bouton qui change de nom au milieu d'un
    /// parcours se lit comme une autre action.
    @ViewBuilder
    private var reviewButton: some View {
        if chapter.cardCount > 0 {
            Button {
                studying = true
            } label: {
                Text(
                    dueCount > 0
                        ? i18n.t("app.today.startCards", ["count": "\(dueCount)"])
                        : i18n.t("ios.deck.practiceChapter")
                )
            }
            .buttonStyle(MicaboPrimaryButtonStyle())
            .padding(.horizontal, MicaboSpacing.screen)
            .padding(.bottom, MicaboSpacing.sm)
        }
    }

    private func reload() {
        blocks = chapter.decodedSheet()?.blocks ?? []
        let now = Date()
        dueCount = chapter.orderedCards.reduce(0) { $0 + ($1.isDue(at: now) ? 1 : 0) }
    }
}
