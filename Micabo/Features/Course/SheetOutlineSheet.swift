import SwiftUI

/// **Le plan de la fiche, et un moyen d'y sauter.**
///
/// Une fiche annoncée « 17 min de lecture » s'ouvrait au milieu de son premier paragraphe :
/// rien ne disait combien de parties elle contenait, où elles commençaient, ni comment
/// revenir à celle qu'on avait laissée la veille. Pour remonter en haut d'un cours, il
/// fallait faire défiler tout le cours.
///
/// Le sommaire tient dans une feuille et pas dans un tiroir latéral : on l'ouvre d'un pouce,
/// on touche une partie, elle se déplie et l'écran s'y rend. La partie qu'on est en train de
/// lire y est marquée, parce que la première question qu'on se pose en ouvrant un plan est
/// « où suis-je ».
struct SheetOutlineSheet: View {
    let chapters: [SheetChapter]
    /// Le rang du chapitre qu'on lit, dans `chapters`.
    let current: Int
    let tint: Color
    var onPick: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Ce qui se liste : les parties. L'entrée en matière n'en est pas une, et le bouton
    /// « revenir en haut » y ramène mieux qu'une ligne de sommaire sans titre.
    private var parts: [SheetChapter] {
        chapters.filter { $0.title != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(parts.enumerated()), id: \.element.id) { entry in
                        row(chapter: entry.element, number: entry.offset + 1)

                        if entry.offset < parts.count - 1 {
                            Rectangle()
                                .fill(MicaboColor.hairline)
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.vertical, MicaboSpacing.xs)
            }
            .scrollIndicators(.hidden)
            .micaboScreenBackground()
            .navigationTitle(i18n.t("ios.sheetOutline"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(i18n.t("app.a11y.close")) { dismiss() }
                        .font(MicaboFont.ui(15, weight: .semibold))
                }
            }
        }
    }

    private func row(chapter: SheetChapter, number: Int) -> some View {
        Button {
            Haptics.selection()
            onPick(chapter.index)
            dismiss()
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: MicaboSpacing.sm) {
                Text("\(number)")
                    .font(MicaboFont.ui(13, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(chapter.index == current ? tint.readableInk() : MicaboColor.inkTertiary)
                    .frame(width: 20, alignment: .trailing)

                Text(chapter.title ?? "")
                    .font(MicaboFont.ui(16, weight: chapter.index == current ? .bold : .medium))
                    .foregroundStyle(chapter.index == current ? MicaboColor.ink : MicaboColor.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Le repère de la partie courante : un point, pas un fond coloré. Une rangée
                // teintée sur toute sa largeur se lit comme une sélection en cours, alors
                // qu'il s'agit seulement de dire où l'on en est.
                Circle()
                    .fill(chapter.index == current ? tint : .clear)
                    .frame(width: 6, height: 6)
            }
            .padding(.vertical, MicaboSpacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityAddTraits(chapter.index == current ? [.isButton, .isSelected] : .isButton)
    }
}
