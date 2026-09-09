import SwiftUI

/// **Un bloc de fiche qu'on corrige, sur le téléphone.**
///
/// Le site modifie la fiche **en place**, dans la page, comme un traitement de texte. Le
/// téléphone ne peut pas faire ça : un paragraphe y est composé dans un `UITextView` en
/// lecture, pour la sélection et « Expliquer », et le rendre modifiable ferait perdre les deux.
/// On modifie donc **bloc par bloc**, dans une feuille : on touche un paragraphe, il s'ouvre,
/// on le corrige, on enregistre. C'est le geste des notes du téléphone, et il tient dans le
/// pouce.
///
/// Le texte est le balisage brut - `**gras**`, `==surligné==` - avec un aperçu composé
/// dessous. Une barre de boutons qui poserait les marques autour de la sélection demanderait
/// UIKit ; l'aperçu, lui, dit tout de suite si la marque est bien fermée, et une marque
/// ouverte ne casse rien : elle reste un caractère comme un autre.
///
/// **Seule la partie lisible se modifie.** Les blocs derrière le mur d'abonnement ne sont pas
/// affichés, donc pas ouverts, donc jamais perdus : le parent les recolle derrière ce qui a
/// été écrit.
struct SheetBlockEditorSheet: View {
    let initial: SheetBlock
    /// Vrai pour un bloc qui n'existe pas encore : la feuille dit « Ajouter » et n'offre pas
    /// de supprimer ce qui n'est pas là.
    var isNew: Bool = false
    var onSave: (SheetBlock) -> Void
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?

    @State private var kind: Kind
    @State private var text: String
    @State private var latex: String
    @State private var caption: String
    @State private var confirmDelete = false

    /// Les quatre formes d'un bloc, telles qu'on les choisit. Une liste se tape **une entrée
    /// par ligne** : c'est ce que tout le monde fait déjà dans une note.
    enum Kind: String, CaseIterable, Identifiable {
        case heading1, heading2, paragraph, bullets, numbers, formula
        var id: String { rawValue }
    }

    init(
        initial: SheetBlock,
        isNew: Bool = false,
        onSave: @escaping (SheetBlock) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.initial = initial
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete

        switch initial {
        case .heading(let level, let value):
            _kind = State(initialValue: level == 1 ? .heading1 : .heading2)
            _text = State(initialValue: value)
            _latex = State(initialValue: "")
            _caption = State(initialValue: "")
        case .paragraph(let value):
            _kind = State(initialValue: .paragraph)
            _text = State(initialValue: value)
            _latex = State(initialValue: "")
            _caption = State(initialValue: "")
        case .list(let ordered, let items):
            _kind = State(initialValue: ordered ? .numbers : .bullets)
            _text = State(initialValue: items.joined(separator: "\n"))
            _latex = State(initialValue: "")
            _caption = State(initialValue: "")
        case .formula(let value, let legend):
            _kind = State(initialValue: .formula)
            _text = State(initialValue: "")
            _latex = State(initialValue: value)
            _caption = State(initialValue: legend ?? "")
        }
    }

    private func t(_ key: String) -> String {
        i18n?.t(key) ?? L10n.t(key, locale: .fr)
    }

    /// Le bloc tel qu'il serait enregistré, ou `nil` s'il est vide : on n'enregistre pas du
    /// blanc, on le supprime.
    private var draft: SheetBlock? {
        switch kind {
        case .heading1, .heading2:
            guard let value = text.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else { return nil }
            return .heading(level: kind == .heading1 ? 1 : 2, text: value)
        case .paragraph:
            guard let value = text.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else { return nil }
            return .paragraph(text: value)
        case .bullets, .numbers:
            let items = text
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            guard !items.isEmpty else { return nil }
            return .list(ordered: kind == .numbers, items: items)
        case .formula:
            guard let value = latex.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank else { return nil }
            return .formula(latex: value, caption: caption.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.lg) {
                    kindPicker
                    fields
                    preview
                    if !isNew, onDelete != nil {
                        deleteButton
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.md)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .micaboScreenBackground()
            .navigationTitle(isNew ? t("ios.sheetEdit.addTitle") : t("ios.sheetEdit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("app.common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? t("ios.sheetEdit.add") : t("app.common.save")) {
                        guard let draft else { return }
                        Haptics.success()
                        onSave(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draft == nil)
                }
            }
            .confirmationDialog(t("ios.sheetEdit.deleteQ"), isPresented: $confirmDelete, titleVisibility: .visible) {
                Button(t("app.common.delete"), role: .destructive) {
                    onDelete?()
                    dismiss()
                }
                Button(t("app.common.cancel"), role: .cancel) {}
            }
        }
    }

    // MARK: - La forme

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicaboSectionCaption(text: t("ios.sheetEdit.kind"))
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    ForEach(Kind.allCases) { option in
                        Button {
                            Haptics.selection()
                            kind = option
                        } label: {
                            Text(t("ios.sheetEdit.kind.\(option.rawValue)"))
                                .font(MicaboFont.hanken(13, weight: .medium))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .foregroundStyle(kind == option ? MicaboColor.accent : MicaboColor.ink)
                                .background(
                                    kind == option ? MicaboColor.accentSoft : MicaboColor.surfaceMuted,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                        .accessibilityAddTraits(kind == option ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Le texte

    @ViewBuilder
    private var fields: some View {
        if kind == .formula {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: t("ios.sheetEdit.latex"))
                editor($latex, minHeight: 80, monospaced: true)
                MicaboSectionCaption(text: t("ios.sheetEdit.caption"))
                editor($caption, minHeight: 52)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(
                    text: kind == .bullets || kind == .numbers ? t("ios.sheetEdit.itemsHint") : t("ios.sheetEdit.text")
                )
                editor($text, minHeight: kind == .paragraph ? 150 : 90)
                legend
            }
        }
    }

    private func editor(_ binding: Binding<String>, minHeight: CGFloat, monospaced: Bool = false) -> some View {
        TextEditor(text: binding)
            .font(monospaced ? .system(size: 15, design: .monospaced) : MicaboFont.body)
            .foregroundStyle(MicaboColor.ink)
            .tint(MicaboColor.accent)
            .scrollContentBackground(.hidden)
            .padding(MicaboSpacing.sm)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .micaboGroup(radius: MicaboRadius.lg)
    }

    /// Les marques qu'on peut écrire, montrées **telles qu'elles se tapent**. On les copie du
    /// regard ; il n'y a rien à apprendre.
    private var legend: some View {
        Text(t("ios.sheetEdit.legend"))
            .font(MicaboFont.micro)
            .foregroundStyle(MicaboColor.inkTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - L'aperçu

    /// Le bloc composé, tel qu'il s'affichera dans la fiche. C'est lui qui dit si une marque
    /// est bien fermée, avant d'enregistrer.
    @ViewBuilder
    private var preview: some View {
        if let draft {
            VStack(alignment: .leading, spacing: 8) {
                MicaboSectionCaption(text: t("ios.sheetEdit.preview"))
                SheetBlockView(block: draft, tint: MicaboColor.accent)
                    .padding(MicaboSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
            }
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmDelete = true
        } label: {
            Label(t("ios.sheetEdit.delete"), systemImage: "trash")
                .font(MicaboFont.hanken(14, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MicaboSecondaryButtonStyle())
        .tint(MicaboColor.negative)
    }
}
