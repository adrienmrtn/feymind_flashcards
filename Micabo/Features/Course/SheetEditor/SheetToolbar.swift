import SwiftUI

/// **La barre d'outils de la fiche, au-dessus du clavier.**
///
/// C'est la barre du site, à l'identique : le style du bloc, gras, italique, barré, les cinq
/// surligneurs, la taille du passage, la formule, et « Expliquer ». Elle défile à l'horizontale
/// parce qu'un iPhone n'a pas la largeur d'un écran, et elle finit sur le bouton qui range le
/// clavier - ce que tout accessoire de clavier doit offrir.
struct SheetToolbar: View {
    @ObservedObject var state: SheetEditorState
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    static let height: CGFloat = 52

    private var locale: UiLocale { i18n?.locale ?? .resolved() }

    private func t(_ key: String) -> String {
        L10n.t(key, locale: locale)
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    styleMenu
                    divider
                    tool(t("app.sheet.bold"), active: state.isBold) { state.actions?.toggleBold() } label: {
                        Text("B").font(.system(size: 16, weight: .bold))
                    }
                    tool(t("app.sheet.italic"), active: state.isItalic) { state.actions?.toggleItalic() } label: {
                        Text("I").font(.system(size: 16, weight: .medium, design: .serif)).italic()
                    }
                    tool(t("app.sheet.strike"), active: state.isStruck) { state.actions?.toggleStrike() } label: {
                        Text("S").font(.system(size: 16, weight: .medium)).strikethrough()
                    }
                    divider
                    ForEach(SheetHighlight.allCases, id: \.self) { color in
                        highlightDot(color)
                    }
                    divider
                    sizeButton(.petit, label: 11)
                    sizeButton(nil, label: 13)
                    sizeButton(.grand, label: 15)
                    divider
                    tool(t("app.formula.add"), active: false) { state.actions?.requestFormula() } label: {
                        Text("∑").font(.system(size: 17, weight: .medium, design: .serif))
                    }
                    tool(t("ios.explanation"), active: false, enabled: state.canExplain) { state.actions?.explainSelection() } label: {
                        Image(systemName: "sparkles").font(.system(size: 15, weight: .semibold))
                    }
                    divider
                    tool(t("ios.sheet.undo"), active: false, enabled: state.canUndo) { state.actions?.undo() } label: {
                        Image(systemName: "arrow.uturn.backward").font(.system(size: 14, weight: .semibold))
                    }
                    tool(t("ios.sheet.redo"), active: false, enabled: state.canRedo) { state.actions?.redo() } label: {
                        Image(systemName: "arrow.uturn.forward").font(.system(size: 14, weight: .semibold))
                    }
                }
                .padding(.horizontal, 8)
            }
            .scrollIndicators(.hidden)

            Button {
                state.actions?.dismissKeyboard()
            } label: {
                Image(systemName: "keyboard.chevron.compact.down")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MicaboColor.ink)
                    .frame(width: 44, height: 40)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(t("ios.sheet.hideKeyboard"))
            .padding(.trailing, 6)
        }
        .frame(height: Self.height)
        .background(MicaboColor.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(MicaboColor.hairline).frame(height: 1)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(MicaboColor.hairline)
            .frame(width: 1, height: 20)
            .padding(.horizontal, 4)
    }

    /// Le style du bloc courant. Un menu, comme la liste déroulante du site.
    private var styleMenu: some View {
        Menu {
            ForEach([SheetParagraphKind.heading1, .heading2, .paragraph, .bullet, .number], id: \.self) { kind in
                Button {
                    Haptics.selection()
                    state.actions?.setKind(kind)
                } label: {
                    if kind == state.kind || (state.kind == .formula && kind == .paragraph) {
                        Label(kind.title(locale: locale), systemImage: "checkmark")
                    } else {
                        Text(kind.title(locale: locale))
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(state.kind.title(locale: locale))
                    .font(MicaboFont.hanken(13.5, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(MicaboColor.ink)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .accessibilityLabel(t("app.sheet.style"))
    }

    private func tool<Label: View>(
        _ title: String,
        active: Bool,
        enabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            label()
                .foregroundStyle(active ? MicaboColor.accent : MicaboColor.ink)
                .frame(width: 36, height: 34)
                .background(active ? MicaboColor.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(title)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func highlightDot(_ color: SheetHighlight) -> some View {
        Button {
            Haptics.selection()
            state.actions?.highlight(color)
        } label: {
            Circle()
                .fill(MicaboColor.sheetHighlight(color))
                .frame(width: 22, height: 22)
                .overlay {
                    Circle().strokeBorder(MicaboColor.strokeStrong, lineWidth: 1)
                }
                .overlay {
                    if state.highlight == color {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(MicaboColor.ink)
                    }
                }
                .frame(width: 32, height: 34)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t("app.sheet.hl.\(color.rawValue)"))
        .accessibilityAddTraits(state.highlight == color ? .isSelected : [])
    }

    /// Les trois A : plus petit, la taille du bloc, plus gros. Le A du milieu retire la marque.
    private func sizeButton(_ size: SheetTextSize?, label: CGFloat) -> some View {
        let key = size.map { "app.sheet.size.\($0.rawValue)" } ?? "app.sheet.size.normal"
        let active = size != nil && state.size == size
        return tool(t(key), active: active) { state.actions?.resize(size) } label: {
            Text("A").font(.system(size: label, weight: .semibold))
        }
    }
}
