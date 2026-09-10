import SwiftUI

/// **Corriger une formule sans savoir écrire du LaTeX.**
///
/// C'est `FormulaEditor.tsx` du site, sur le téléphone. Trois choses rendent le champ
/// utilisable par quelqu'un qui n'a jamais vu de LaTeX : l'aperçu est composé pendant qu'on
/// tape ; les constructions - fraction, puissance, racine, somme - s'insèrent au bouton, avec
/// des cases `□` qu'on remplit ; et une formule qui ne se compose pas le dit, au lieu de
/// laisser croire que c'est normal. Le LaTeX reste visible pour qui le connaît.
struct FormulaEditorSheet: View {
    let initial: SheetFormulaDraft
    /// Absent quand la formule vient d'être posée : annuler suffit à ne rien laisser.
    var onDelete: (() -> Void)?
    var onApply: (SheetFormulaDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(UiLocaleStore.self) private var i18n: UiLocaleStore?
    @State private var latex: String
    @State private var caption: String
    @State private var isInline: Bool
    @FocusState private var latexFocused: Bool

    /// La case à remplir d'un gabarit. Elle ne survit pas à l'enregistrement.
    static let slot = "□"

    private struct Insert: Identifiable {
        let label: String
        let latex: String
        var id: String { label }
    }

    private static let shapes: [Insert] = [
        Insert(label: "a/b", latex: "\\frac{\(slot)}{\(slot)}"),
        Insert(label: "x²", latex: "\(slot)^{\(slot)}"),
        Insert(label: "xᵢ", latex: "\(slot)_{\(slot)}"),
        Insert(label: "√", latex: "\\sqrt{\(slot)}"),
        Insert(label: "Σ", latex: "\\sum_{\(slot)}^{\(slot)} \(slot)"),
        Insert(label: "∫", latex: "\\int_{\(slot)}^{\(slot)} \(slot)"),
        Insert(label: "( )", latex: "\\left( \(slot) \\right)"),
        Insert(label: "|x|", latex: "\\left| \(slot) \\right|")
    ]

    private static let symbols: [Insert] = [
        Insert(label: "×", latex: "\\times "), Insert(label: "÷", latex: "\\div "),
        Insert(label: "±", latex: "\\pm "), Insert(label: "≤", latex: "\\leq "),
        Insert(label: "≥", latex: "\\geq "), Insert(label: "≠", latex: "\\neq "),
        Insert(label: "≈", latex: "\\approx "), Insert(label: "→", latex: "\\rightarrow "),
        Insert(label: "∞", latex: "\\infty "), Insert(label: "π", latex: "\\pi "),
        Insert(label: "α", latex: "\\alpha "), Insert(label: "β", latex: "\\beta "),
        Insert(label: "θ", latex: "\\theta "), Insert(label: "λ", latex: "\\lambda "),
        Insert(label: "Δ", latex: "\\Delta "), Insert(label: "∂", latex: "\\partial ")
    ]

    init(initial: SheetFormulaDraft, onDelete: (() -> Void)? = nil, onApply: @escaping (SheetFormulaDraft) -> Void) {
        self.initial = initial
        self.onDelete = onDelete
        self.onApply = onApply
        _latex = State(initialValue: initial.latex)
        _caption = State(initialValue: initial.caption)
        _isInline = State(initialValue: initial.isInline)
    }

    private func t(_ key: String) -> String {
        i18n?.t(key) ?? L10n.t(key, locale: .resolved())
    }

    private var trimmed: String { latex.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var filled: Bool { !latex.contains(Self.slot) }
    private var composes: Bool { trimmed.isEmpty || !MathTypesetter.isAvailable || MathTypesetter.canTypeset(trimmed) }
    private var ready: Bool { !trimmed.isEmpty && filled && composes }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MicaboSpacing.md) {
                    Text(t("app.formula.lead"))
                        .font(MicaboFont.hanken(13, weight: .regular))
                        .foregroundStyle(MicaboColor.inkTertiary)
                        .fixedSize(horizontal: false, vertical: true)

                    preview
                    placement
                    palette(Self.shapes)
                    palette(Self.symbols)

                    VStack(alignment: .leading, spacing: 6) {
                        MicaboSectionCaption(text: t("app.formula.source"))
                        TextEditor(text: $latex)
                            .font(.system(size: 15, design: .monospaced))
                            .foregroundStyle(MicaboColor.ink)
                            .tint(MicaboColor.accent)
                            .scrollContentBackground(.hidden)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($latexFocused)
                            .padding(MicaboSpacing.sm)
                            .frame(minHeight: 84, alignment: .topLeading)
                            .micaboGroup(radius: MicaboRadius.lg)
                        if !filled {
                            warning(t("app.formula.slots"))
                        } else if !composes {
                            warning(t("app.formula.broken"))
                        }
                    }

                    // Une légende sous une formule prise dans une phrase n'aurait nulle part où
                    // se poser : c'est la phrase elle-même qui dit ce que les symboles veulent dire.
                    if !isInline {
                        VStack(alignment: .leading, spacing: 6) {
                            MicaboSectionCaption(text: t("app.formula.caption"))
                            TextField(t("app.formula.captionPlaceholder"), text: $caption)
                                .font(MicaboFont.body)
                                .padding(MicaboSpacing.sm)
                                .micaboGroup(radius: MicaboRadius.lg)
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label(t("app.formula.remove"), systemImage: "trash")
                                .font(MicaboFont.hanken(14, weight: .medium))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(MicaboSecondaryButtonStyle())
                        .tint(MicaboColor.negative)
                        .padding(.top, MicaboSpacing.xs)
                    }
                }
                .padding(.horizontal, MicaboSpacing.screen)
                .padding(.top, MicaboSpacing.sm)
                .padding(.bottom, MicaboSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .micaboScreenBackground()
            .navigationTitle(t("app.formula.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("app.common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("app.formula.apply")) {
                        Haptics.success()
                        onApply(SheetFormulaDraft(latex: trimmed, caption: isInline ? "" : caption.trimmingCharacters(in: .whitespacesAndNewlines), isInline: isInline))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!ready)
                }
            }
            .onAppear { latexFocused = true }
        }
    }

    /// L'aperçu compose dans le mode où la formule ira : une somme en ligne et une somme posée
    /// seule n'ont pas la même allure, et c'est justement ce qu'on choisit.
    private var preview: some View {
        Group {
            if trimmed.isEmpty {
                Text(t("app.formula.empty"))
                    .font(MicaboFont.hanken(13.5))
                    .foregroundStyle(MicaboColor.inkTertiary)
            } else {
                MathFormula(
                    latex: trimmed.replacingOccurrences(of: Self.slot, with: "\\square"),
                    fontSize: isInline ? SheetTypography.body * 1.1 : SheetTypography.formula,
                    isCentered: true,
                    isDisplayMode: !isInline
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .padding(.horizontal, MicaboSpacing.md)
        .padding(.vertical, MicaboSpacing.md)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
    }

    private var placement: some View {
        HStack(spacing: 4) {
            ForEach([true, false], id: \.self) { value in
                Button {
                    Haptics.selection()
                    isInline = value
                } label: {
                    Text(value ? t("app.formula.inline") : t("app.formula.block"))
                        .font(MicaboFont.hanken(13.5, weight: .medium))
                        .foregroundStyle(value == isInline ? MicaboColor.ink : MicaboColor.inkSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(value == isInline ? MicaboColor.surface : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityLabel(t("app.formula.placement"))
    }

    private func palette(_ entries: [Insert]) -> some View {
        MicaboFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(entries) { entry in
                Button {
                    Haptics.selection()
                    insert(entry.latex)
                } label: {
                    Text(entry.label)
                        .font(.system(size: 15, weight: .medium, design: .serif))
                        .foregroundStyle(MicaboColor.ink)
                        .frame(minWidth: 40)
                        .frame(height: 38)
                        .padding(.horizontal, 8)
                        .background(MicaboColor.surfaceMuted, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(MicaboPressableButtonStyle(dimming: false, feedback: .selection))
                .accessibilityLabel(entry.latex.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(MicaboFont.hanken(12.5, weight: .medium))
            .foregroundStyle(MicaboColor.caution)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Pose un gabarit à la fin de ce qui est écrit. Le téléphone ne rend pas la position du
    /// curseur d'un `TextEditor` ; la case `□` reste à remplir en la touchant.
    private func insert(_ snippet: String) {
        if !latex.isEmpty, !latex.hasSuffix(" "), !snippet.hasPrefix(" ") { latex += " " }
        latex += snippet
        latexFocused = true
    }
}
