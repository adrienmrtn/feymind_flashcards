import SwiftUI

/// **Les six façons de réviser une leçon**, dans l'ordre de la grille : Notes, Quiz, Cartes,
/// puis Mika, Carte mentale, Fiche PDF — deux rangées de trois. « Écouter » et « À voix haute »
/// ont été retirés au lot 11, à la demande de l'utilisateur.
///
/// Elles vivaient à trois endroits — une barre en bas (Notes, Quiz, Flashcards), une rangée
/// « Réviser autrement » sous le bouton, l'avatar de Mika en haut — et l'élève ne savait plus où
/// chercher. Elles sont maintenant des tuiles égales, au même endroit, sous **le** bouton qui
/// dit quoi faire maintenant.
enum LessonTool: String, CaseIterable, Identifiable {
    case notes
    case quiz
    case cards
    case mika
    case mindMap
    case sheet

    var id: String { rawValue }

    /// Le nom de l'outil : le même partout dans l'app (`MicaboName`).
    var name: MicaboName {
        switch self {
        case .notes: .notes
        case .quiz: .quiz
        case .cards: .cards
        case .mika: .mika
        case .mindMap: .mindMap
        case .sheet: .sheet
        }
    }

    /// Le mode de révision derrière la tuile, pour ceux qui ont une porte
    /// (`RevisionModeAllowance`). Notes, Quiz, Cartes et Mika s'ouvrent toujours d'ici : leur
    /// propre porte, quand ils en ont une, est dans leur écran.
    var revision: RevisionMode? {
        switch self {
        case .mindMap: .mindMap
        case .sheet: .export
        case .notes, .quiz, .cards, .mika: nil
        }
    }

    /// L'icône de la tuile, dans la famille plate de l'app quand elle y est.
    var icon: MicaboIcon? {
        switch self {
        case .notes: .notes
        case .quiz: .quiz
        case .cards: .cards
        case .mika: .mika
        case .sheet: .pdf
        case .mindMap: nil
        }
    }

    /// Le pictogramme de l'outil qui n'a pas d'icône dans la famille.
    var symbol: String {
        switch self {
        case .mindMap: "point.3.filled.connected.trianglepath.dotted"
        default: icon?.symbol ?? "square.grid.2x2.fill"
        }
    }

    /// La couleur de l'idée, pour un pictogramme hors famille.
    var tint: Color {
        switch self {
        case .mindMap: V3Color.green
        default: V3Color.accent
        }
    }

    /// Ce que la tuile fait, pour VoiceOver : la phrase du mode quand il en a une.
    var hintKey: String? {
        revision?.hintKey
    }

    /// Les rangées de la grille : trois tuiles par ligne, deux en très grand texte.
    static func rows(columns: Int) -> [[LessonTool]] {
        let size = max(1, columns)
        return stride(from: 0, to: allCases.count, by: size).map { start in
            Array(allCases[start..<min(start + size, allCases.count)])
        }
    }
}

/// **La grille « Réviser »** : six tuiles égales, une icône et un nom. La tuile Cartes porte le
/// nombre de cartes à revoir ; une tuile dans Pro, et fermée, porte la pastille « PRO ».
struct LessonToolGrid: View {
    /// Les cartes à revoir aujourd'hui, sur la tuile Cartes.
    var dueCount = 0
    var isPro = true
    let onSelect: (LessonTool) -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Trois par ligne (deux rangées égales) ; deux quand le texte est grand, pour qu'aucun nom
    /// ne se coupe.
    private var columns: Int { typeSize >= .xLarge ? 2 : 3 }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(LessonTool.rows(columns: columns).enumerated()), id: \.offset) { _, row in
                // Les tuiles d'une rangée ont la hauteur de la plus haute.
                HStack(spacing: 10) {
                    ForEach(row) { tool in
                        LessonToolTile(
                            tool: tool,
                            dueCount: tool == .cards ? dueCount : 0,
                            showsPro: showsPro(tool)
                        ) {
                            onSelect(tool)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func showsPro(_ tool: LessonTool) -> Bool {
        guard let mode = tool.revision else { return false }
        return RevisionModeAllowance.showsProBadge(mode, isPro: isPro)
    }
}

/// Une tuile de la grille : l'icône, le nom dessous, et sa pastille quand elle en a une.
struct LessonToolTile: View {
    let tool: LessonTool
    var dueCount = 0
    var showsPro = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                LessonToolIcon(tool: tool)
                Text(tool.name.text())
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .v3Card(radius: V3Metric.radiusInner)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .overlay(alignment: .topTrailing) { badge }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tool.name.text()))
        .accessibilityValue(Text(accessibilityValue))
        .accessibilityHint(Text(tool.hintKey.map { L10n.t($0, locale: .resolved()) } ?? ""))
        .accessibilityAddTraits(.isButton)
    }

    /// Le nombre de cartes à revoir, ou « PRO ». Jamais les deux : Cartes n'est pas dans Pro.
    @ViewBuilder
    private var badge: some View {
        if dueCount > 0 {
            Text("\(dueCount)")
                .font(V3Font.caption)
                .monospacedDigit()
                .foregroundStyle(V3Color.onAccent)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(V3Color.accent, in: Capsule())
                .padding(.top, -7)
                .padding(.trailing, -5)
                .accessibilityHidden(true)
        } else if showsPro {
            ProBadge()
                .padding(.top, -7)
                .padding(.trailing, -5)
                .accessibilityHidden(true)
        }
    }

    private var accessibilityValue: String {
        if dueCount > 0 {
            return L10n.t("ios.home10.due", locale: .resolved(), vars: ["count": String(dueCount)])
        }
        return showsPro ? "Pro" : ""
    }
}

/// L'icône d'un outil : celle de la famille plate de l'app (`MicaboIconView`), ou son
/// pictogramme dans la couleur de son idée.
struct LessonToolIcon: View {
    let tool: LessonTool
    var size: CGFloat = 30

    var body: some View {
        if let icon = tool.icon {
            MicaboIconView(icon: icon, size: size)
        } else {
            Image(systemName: tool.symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size * 0.62, weight: .semibold))
                .foregroundStyle(tool.tint)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}
