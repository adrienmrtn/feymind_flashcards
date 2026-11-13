import SwiftUI

// MARK: - Les entrées

/// **Tout ce que l'app sait faire à partir d'un support ou d'une question**, rangé en trois
/// groupes (lot 12) : les sources, s'entraîner, comprendre. Chaque entrée mène à une fonction
/// qui existe déjà ; une entrée qui ne marcherait pas ici (le quiz sans leçon, l'examen blanc
/// sans leçons) n'est pas montrée.
///
/// Les noms partent tels quels dans `tool_picked` : des valeurs fixes.
enum ToolItem: String, CaseIterable, Identifiable {
    // Les sources
    case camera
    case photos
    case files
    case youtube
    case audio
    case allSources = "all_sources"
    // S'entraîner
    case focus
    case flashcards
    case vocabulary
    case quiz
    case mock
    case plan
    // Comprendre
    case explain
    case summary
    case translate
    case solve

    var id: String { rawValue }

    /// Le mode de la caméra qu'ouvre l'entrée, quand c'en est un.
    var scanMode: ScanMode? {
        switch self {
        case .flashcards: .flashcards
        case .vocabulary: .vocabulary
        case .explain: .explain
        case .summary: .summary
        case .translate: .translate
        case .solve: .solve
        default: nil
        }
    }

    func title(locale: UiLocale = .resolved()) -> String {
        if let mode = scanMode { return mode.title(locale: locale) }
        return L10n.t("ios.scan12.tool.\(rawValue)", locale: locale)
    }

    var symbol: String {
        switch self {
        case .camera: "camera.fill"
        case .photos: "photo.on.rectangle.angled"
        case .files: "doc.fill"
        case .youtube: "play.rectangle.fill"
        case .audio: "waveform"
        case .allSources: "square.grid.2x2.fill"
        case .focus: "timer"
        case .quiz: "checklist"
        case .mock: "graduationcap.fill"
        case .plan: "calendar.badge.clock"
        default: scanMode?.symbol ?? "sparkles"
        }
    }

    var tone: Color {
        switch self {
        case .camera: V3Color.iconPink
        case .photos: V3Color.iconBlue
        case .files: V3Color.iconLilac
        case .youtube: V3Color.iconRed
        case .audio: V3Color.iconGreen
        case .allSources: V3Color.iconYellow
        case .focus: V3Color.iconOrange
        case .quiz: V3Color.iconGreen
        case .mock: V3Color.iconYellow
        case .plan: V3Color.iconBlue
        default: scanMode?.tone ?? V3Color.iconBlue
        }
    }
}

/// D'où la feuille est ouverte.
enum ToolsContext: String {
    /// Le « + » de la Home : les sources y font une leçon.
    case home
    /// Le « + » d'une conversation : les sources y joignent des photos, les gestes y répondent.
    case chat
}

/// Ce qui décide qu'une entrée marche ici.
struct ToolsAvailability: Equatable {
    /// Une leçon ouverte récemment (le quiz éclair), ou la leçon de la conversation.
    var hasLesson = false
    /// Au moins une leçon (l'examen blanc).
    var hasLessons = false
    /// La barre de la Home a encore de la place pour un support.
    var canImport = true
}

/// Un groupe de la feuille.
struct ToolGroup: Equatable, Identifiable {
    enum Kind: String {
        case sources
        case practice
        case understand
    }

    let kind: Kind
    let items: [ToolItem]
    var id: String { kind.rawValue }

    func title(locale: UiLocale = .resolved()) -> String {
        L10n.t("ios.scan12.tools.\(kind.rawValue)", locale: locale)
    }

    /// **Les trois groupes**, selon l'endroit et ce qui marche. Une fonction pure : elle se teste.
    static func groups(context: ToolsContext, availability: ToolsAvailability) -> [ToolGroup] {
        var sources: [ToolItem]
        var practice: [ToolItem] = [.focus, .flashcards, .vocabulary]
        switch context {
        case .home:
            sources = [.camera]
            if availability.canImport { sources += [.photos, .files, .youtube, .audio, .allSources] }
            if availability.hasLesson { practice.append(.quiz) }
            if availability.hasLessons { practice.append(.mock) }
            practice.append(.plan)
        case .chat:
            sources = [.camera, .photos, .files]
            if availability.hasLesson { practice.append(.quiz) }
        }
        return [
            ToolGroup(kind: .sources, items: sources),
            ToolGroup(kind: .understand, items: [.explain, .summary, .translate, .solve]),
            ToolGroup(kind: .practice, items: practice),
        ]
    }
}

// MARK: - La feuille

/// **La feuille « Outils »**, ouverte par le « + » de la Home et du chat : un titre, les
/// sources en tuiles, puis « Comprendre » et « S'entraîner » en pastilles. Une entrée referme
/// la feuille ; ce qu'elle ouvre s'ouvre ensuite (deux feuilles ne se présentent pas ensemble).
struct ToolsSheet: View {
    let context: ToolsContext
    var availability = ToolsAvailability()
    let onPick: (ToolItem) -> Void

    @Environment(\.homeStill) private var still

    private var groups: [ToolGroup] { ToolGroup.groups(context: context, availability: availability) }

    var body: some View {
        Group {
            if still {
                content
            } else {
                ScrollView { content }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(V3Color.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(V3Metric.radiusSheet)
        .onAppear { Analytics.track(.toolsOpened, ["context": .text(context.rawValue)]) }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(L10n.t("ios.scan12.tools.title", locale: .resolved()))
                .font(V3Font.h2)
                .foregroundStyle(V3Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    if group.kind != .sources {
                        Text(group.title())
                            .font(V3Font.eyebrow)
                            .foregroundStyle(V3Color.ink3)
                            .textCase(.uppercase)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if group.kind == .sources {
                        tiles(group.items)
                    } else {
                        MicaboFlowLayout(spacing: 8, lineSpacing: 10) {
                            ForEach(group.items) { item in
                                V3Chip(item.title(), systemImage: item.symbol, tone: item.tone) { pick(item) }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, V3Metric.screenMargin)
        .padding(.top, 28)
        .padding(.bottom, 24)
    }

    /// Les sources, trois par rangée : l'icône sur sa pastille, le nom dessous.
    private func tiles(_ items: [ToolItem]) -> some View {
        let rows = stride(from: 0, to: items.count, by: 3).map { Array(items[$0..<min($0 + 3, items.count)]) }
        return VStack(spacing: 10) {
            ForEach(rows.indices, id: \.self) { index in
                HStack(spacing: 10) {
                    ForEach(rows[index]) { item in
                        tile(item)
                    }
                    ForEach(0..<(3 - rows[index].count), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tile(_ item: ToolItem) -> some View {
        Button { pick(item) } label: {
            VStack(spacing: 8) {
                Image(systemName: item.symbol)
                    .font(V3Font.text(.title3, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(item.tone)
                    .frame(width: 46, height: 46)
                    .background(item.tone.opacity(0.16), in: Circle())
                Text(item.title())
                    .font(V3Font.label)
                    .foregroundStyle(V3Color.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .v3Card(radius: V3Metric.radiusCard)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.title()))
        .accessibilityAddTraits(.isButton)
    }

    private func pick(_ item: ToolItem) {
        Analytics.track(.toolPicked, ["tool": .text(item.rawValue), "context": .text(context.rawValue)])
        onPick(item)
    }
}
