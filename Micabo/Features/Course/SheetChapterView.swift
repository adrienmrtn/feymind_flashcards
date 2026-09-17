import SwiftUI

/// **Un chapitre de la fiche, avec son en-tête et son texte.**
///
/// L'en-tête n'est pas une décoration : c'est le seul endroit d'où l'on peut replier une
/// partie, et c'est ce qui transforme un ruban de texte de dix-sept minutes en un plan qu'on
/// parcourt. Replié, il porte le titre ; déplié, il ne porte plus que son numéro et son
/// chevron, **parce que le titre est dans le texte juste en dessous**.
///
/// Ce choix-là mérite son paragraphe. Le titre aurait pu vivre dans l'en-tête en toutes
/// circonstances, comme chez les applications concurrentes : c'est plus simple à écrire, et
/// ça évite qu'il paraisse se déplacer. Mais la fiche est **un document qu'on écrit**, sans
/// bouton Modifier, et un titre monté dans un en-tête d'accordéon serait devenu la seule
/// ligne de la page qu'on ne peut plus corriger. Il reste donc un bloc comme les autres, et
/// l'en-tête ne le répète que lorsqu'il est caché. Quand on est descendu dans un chapitre et
/// que son titre est passé en haut de l'écran, c'est l'en-tête collant de `CourseSheetView`
/// qui le rappelle.
struct SheetChapterView: View {
    let chapter: SheetChapter
    /// Le rang affiché, à partir de 1, et compté **parmi les chapitres titrés** : ce qui
    /// précède la première partie n'est pas le chapitre zéro, c'est l'entrée en matière.
    let number: Int
    let revision: Date
    let tint: Color
    let isCollapsed: Bool
    @ObservedObject var state: SheetEditorState
    var onToggle: () -> Void
    var onSave: ([SheetBlock]) -> Void
    var onExplain: (String) -> Void
    var onFormula: (SheetFormulaTarget) -> Void

    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    /// Le chapitre d'entrée en matière n'a ni titre, ni en-tête, ni chevron : on ne replie
    /// pas les deux phrases par lesquelles une fiche commence.
    private var isPreamble: Bool { chapter.title == nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = chapter.title {
                header(title: title)
            }

            if isPreamble || !isCollapsed {
                SheetEditorView(
                    blocks: chapter.blocks,
                    revision: revision,
                    tint: tint,
                    state: state,
                    onSave: onSave,
                    onExplain: onExplain,
                    onFormula: onFormula
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - L'en-tête

    private func header(title: String) -> some View {
        Button {
            Haptics.selection()
            onToggle()
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: MicaboSpacing.xs) {
                    badge
                    Spacer(minLength: MicaboSpacing.xs)
                    Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkTertiary)
                }

                if isCollapsed {
                    Text(title)
                        .font(MicaboFont.ui(SheetTypography.headingLarge, weight: .bold))
                        .kerning(MicaboTracking.tight)
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, MicaboSpacing.lg)
            .padding(.bottom, isCollapsed ? MicaboSpacing.lg : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .none))
        .accessibilityLabel(title)
        .accessibilityHint(i18n.t(isCollapsed ? "ios.expandChapter" : "ios.collapseChapter"))
    }

    /// « Chap. 2 » : le repère qu'on cherche quand on revient sur une fiche commencée hier.
    /// Il porte la teinte du cours, comme la capsule des titres de partie.
    private var badge: some View {
        Text(i18n.t("ios.chapterShort", ["number": "\(number)"]))
            .font(MicaboFont.ui(12.5, weight: .bold))
            .foregroundStyle(tint.readableInk())
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }
}
