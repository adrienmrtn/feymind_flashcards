import SwiftUI

// **Le bas de la Home, fixé au-dessus des onglets** (lot 10, HOME.md § 1.6) : la rangée de
// puces d'outils qui défile sur une ligne — « Focus » d'abord —, puis la barre de saisie : le
// rond « + » (la feuille des sources), et la pilule « Un sujet, une question… » avec l'appareil
// photo (le scanner). Taper un sujet et l'envoyer crée la leçon : la flèche d'envoi prend la
// place de l'appareil photo dès qu'il y a quelque chose à envoyer.
//
// Le bloc suit le clavier d'un seul tenant (il est posé dans la zone sûre du bas) : il monte
// avec lui, il ne saute pas.

// MARK: - Les puces d'outils

extension HomeShortcut {
    /// L'icône de la famille plate de l'app, quand l'outil y a la sienne : deux tons, dans la
    /// couleur de son idée.
    var icon: MicaboIcon? {
        switch self {
        case .scan, .photo: .photo
        case .quiz: .quiz
        case .cards: .cards
        case .writing: .quill
        case .mock: .diploma
        case .pdf: .pdf
        case .focus, .importSource, .youtube: nil
        }
    }

    /// Le pictogramme des outils hors famille. « Focus » porte le minuteur de son onglet.
    var symbol: String {
        switch self {
        case .focus: "timer"
        case .importSource: "square.and.arrow.down.fill"
        case .youtube: "play.rectangle.fill"
        default: icon?.symbol ?? "square.grid.2x2.fill"
        }
    }

    /// La couleur d'un pictogramme hors famille : orange pour le temps, lilas pour ce qui
    /// entre dans l'app, rouge pour ce qui se repère de loin.
    var tone: Color? {
        switch self {
        case .focus: V3Color.iconOrange
        case .importSource: V3Color.iconLilac
        case .youtube: V3Color.iconRed
        default: nil
        }
    }
}

/// Une puce d'outil : son icône deux tons et son mot (`V3Chip`).
struct HomeShortcutChip: View {
    let shortcut: HomeShortcut
    var dueCount = 0
    let action: () -> Void

    var body: some View {
        chip
            .accessibilityLabel(Text(shortcut.spokenTitle(dueCount: dueCount)))
    }

    @ViewBuilder
    private var chip: some View {
        let title = shortcut.title(dueCount: dueCount)
        if let icon = shortcut.icon {
            V3Chip(title, icon: icon, tone: shortcut.tone, action: action)
        } else {
            V3Chip(title, systemImage: shortcut.symbol, tone: shortcut.tone, action: action)
        }
    }
}

// MARK: - Le bloc du bas

/// **Les puces d'outils et la barre de saisie.** Les supports déposés (un PDF, des photos)
/// s'alignent au-dessus en pastilles, avec leur lecture en cours ou leur échec.
///
/// Pendant qu'une leçon s'écrit (`isBusy`), la barre patiente : on ne prépare pas une seconde
/// leçon par-dessus la première. Les outils, eux, restent ouverts.
///
/// **Une frappe ne redessine que la barre** : le champ vit dans sa propre vue
/// (`HomeInputBar`), seule à lire ce que l'élève tape. Les puces, elles, ne relisent rien.
struct HomeDock: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    let shortcuts: [HomeShortcut]
    var dueCount = 0
    var isBusy = false
    let actions: HomeActions

    /// La hauteur de la barre de saisie et de son rond « + » (`mock13/home.html`).
    static let barHeight: CGFloat = 52
    /// Le rond de la flèche d'envoi, dans la barre.
    static let sendSize: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !composer.supports.isEmpty {
                HomeSupportsRow(composer: composer)
            }
            HomeScrollingRow(height: V3Metric.chipHeight) {
                HStack(spacing: 8) {
                    ForEach(shortcuts) { shortcut in
                        HomeShortcutChip(shortcut: shortcut, dueCount: dueCount) {
                            actions.shortcut(shortcut)
                        }
                    }
                }
            }
            HomeInputBar(
                composer: composer,
                focused: focused,
                isBusy: isBusy,
                onSources: actions.sources,
                onScan: actions.scan,
                onSend: actions.send
            )
            .padding(.horizontal, V3Metric.screenMargin)
        }
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V3Color.bg)
    }
}

/// **Une rangée qui défile sur une ligne**, d'un bord de l'écran à l'autre. Les rendus ne
/// dessinent pas ce qui défile (`homeStill`) : ils posent la même rangée, coupée au bord.
struct HomeScrollingRow<Row: View>: View {
    let height: CGFloat
    @ViewBuilder let row: () -> Row

    @Environment(\.homeStill) private var still

    var body: some View {
        if still {
            Color.clear
                .frame(height: height)
                .overlay(alignment: .leading) {
                    row()
                        .fixedSize()
                        .padding(.leading, V3Metric.screenMargin)
                }
                .clipped()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                row()
                    .padding(.horizontal, V3Metric.screenMargin)
            }
        }
    }
}

/// Les supports déposés dans la barre, et la raison du dernier qui n'a pas pu se lire.
struct HomeSupportsRow: View {
    let composer: LessonComposer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeScrollingRow(height: V3Metric.chipHeight) {
                HStack(spacing: 8) {
                    ForEach(composer.supports) { support in
                        SupportChip(support: support) {
                            composer.remove(support.id)
                        }
                    }
                }
            }
            if let failure = composer.supports.compactMap(\.failure).last {
                Text(failure)
                    .font(V3Font.caption)
                    .foregroundStyle(V3Color.redInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, V3Metric.screenMargin)
            }
        }
    }
}

// MARK: - La barre de saisie

/// **La barre de saisie** : le rond « + » (la feuille des sources) et la pilule « Un sujet, une
/// question… ». À droite du champ, l'appareil photo (le scanner) — ou la flèche d'envoi dès
/// qu'il y a quelque chose à envoyer. Pas de micro.
struct HomeInputBar: View {
    let composer: LessonComposer
    var focused: FocusState<Bool>.Binding
    var isBusy = false
    let onSources: () -> Void
    let onScan: () -> Void
    let onSend: () -> Void

    @Environment(\.homeStill) private var still

    var body: some View {
        @Bindable var composer = composer
        HStack(alignment: .bottom, spacing: 10) {
            Button(action: onSources) {
                Image(systemName: "plus")
                    .font(V3Font.text(.title3, weight: .bold))
                    .foregroundStyle(V3Color.ink)
                    .frame(width: HomeDock.barHeight, height: HomeDock.barHeight)
                    .background(V3Color.surface, in: Circle())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
            .disabled(!composer.hasRoom || isBusy)
            .opacity(composer.hasRoom && !isBusy ? 1 : 0.45)
            .accessibilityLabel(Text(L10n.t("ios.home2.addSource", locale: .resolved())))

            HStack(alignment: .bottom, spacing: 8) {
                field(draft: $composer.draft)
                trailing
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .frame(minHeight: HomeDock.barHeight)
            .background(V3Color.surface, in: RoundedRectangle(cornerRadius: HomeDock.barHeight / 2, style: .continuous))
            .opacity(isBusy ? 0.55 : 1)
        }
    }

    private var placeholder: String {
        composer.supports.isEmpty
            ? L10n.t("ios.home10.bar.placeholder", locale: .resolved())
            : L10n.t("lesson.home.placeholderWithSupports", locale: .resolved())
    }

    @ViewBuilder
    private func field(draft: Binding<String>) -> some View {
        Group {
            if still || isBusy {
                // Posé, ou en attente : le texte seul, sans champ.
                let showsDraft = !isBusy && !draft.wrappedValue.isEmpty
                Text(showsDraft ? draft.wrappedValue : placeholder)
                    .foregroundStyle(showsDraft ? V3Color.ink : V3Color.ink3)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField(
                    text: draft,
                    prompt: Text(placeholder).foregroundStyle(V3Color.ink3),
                    axis: .vertical
                ) {
                    Text(placeholder)
                }
                .foregroundStyle(V3Color.ink)
                .tint(V3Color.accent)
                .lineLimit(1...4)
                .focused(focused)
                .submitLabel(.send)
                .onSubmit(onSend)
            }
        }
        .font(V3Font.text(.body, weight: .medium))
        .padding(.vertical, 14)
    }

    /// À droite du champ : l'appareil photo (le scanner), ou la flèche d'envoi dès qu'il y a
    /// quelque chose à envoyer.
    @ViewBuilder
    private var trailing: some View {
        if composer.canSend && !isBusy {
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(V3Font.text(.body, weight: .heavy))
                    .foregroundStyle(V3Color.ctaInk)
                    .frame(width: HomeDock.sendSize, height: HomeDock.sendSize)
                    .background(V3Color.cta, in: Circle())
                    .frame(height: HomeDock.barHeight)
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .medium))
            .accessibilityLabel(Text(L10n.t("lesson.home.send", locale: .resolved())))
        } else {
            Button(action: onScan) {
                Image(systemName: "camera")
                    .font(V3Font.text(.title3, weight: .semibold))
                    .foregroundStyle(V3Color.ink)
                    .frame(width: HomeDock.sendSize, height: HomeDock.barHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MicaboPressableButtonStyle(feedback: .light))
            .disabled(isBusy)
            .accessibilityLabel(Text(MicaboName.scan.text()))
        }
    }
}

private extension LessonComposer.Support {
    var failure: String? {
        if case .failed(let message) = state { return message }
        return nil
    }
}

/// Un support déposé : son icône, son nom, et où en est sa lecture.
struct SupportChip: View {
    let support: LessonComposer.Support
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                if support.state == .reading {
                    ProgressView().controlSize(.small)
                } else {
                    MicaboIconView(icon: support.kind.icon, size: 22)
                }
            }
            .frame(width: 24, height: 24)
            Text(support.title)
                .font(V3Font.label)
                .foregroundStyle(isFailed ? V3Color.redInk : V3Color.ink)
                .lineLimit(1)
                .frame(maxWidth: 150, alignment: .leading)
            Button(action: onRemove) {
                Image(systemName: isFailed ? "exclamationmark.circle.fill" : "xmark.circle.fill")
                    .font(V3Font.text(.body, weight: .semibold))
                    .foregroundStyle(isFailed ? V3Color.red : V3Color.ink3)
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityLabel(Text(L10n.t("lesson.home.removeSupport", locale: .resolved())))
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .frame(minHeight: V3Metric.chipHeight)
        .v3Card(tone: isFailed ? V3Color.redWash : nil, radius: V3Metric.chipHeight / 2)
    }

    private var isFailed: Bool {
        if case .failed = support.state { return true }
        return false
    }
}
