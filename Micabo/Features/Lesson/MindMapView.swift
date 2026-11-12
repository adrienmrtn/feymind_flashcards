import SwiftUI

/// **La carte mentale d'une leçon** (`docs/supports.md`) : la leçon en tête, ses thèmes en
/// branches, et sous chaque thème ses notions et leurs détails. Une liste repliable plutôt
/// qu'un plan à faire glisser : elle se lit d'un pouce, garde la taille du texte choisie
/// dans les Réglages et se lit aussi de droite à gauche. Chaque branche a sa couleur.
struct MindMapView: View {
    let root: MindMapNode
    var icon: MicaboIcon = .book
    /// La couleur de la leçon, pour l'en-tête : la même que sur sa tuile.
    var tone: LessonTone?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.homeStill) private var still
    @State private var expanded: Set<String>

    init(course: Course) {
        self.init(root: MindMap.build(LessonDigest(course: course)), icon: course.icon)
        tone = course.tone
    }

    /// `expanded` : les thèmes ouverts à l'arrivée. Par défaut, le premier.
    init(root: MindMapNode, icon: MicaboIcon = .book, expanded: Set<String>? = nil) {
        self.root = root
        self.icon = icon
        _expanded = State(initialValue: expanded ?? Set(root.children.prefix(1).map(\.id)))
    }

    private var allOpen: Bool { expanded.count == root.children.count }

    var body: some View {
        VStack(spacing: 0) {
            RevisionModeHeader(mode: .mindMap, lessonTitle: root.title, tone: tone) { dismiss() }
            if still {
                content
            } else {
                ScrollView { content }
                    .scrollIndicators(.hidden)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
    }

    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(L10n.t("ios.sup.mind.count", locale: .resolved(), vars: [
                    "themes": String(root.children.count),
                    "notions": String(root.children.reduce(0) { $0 + $1.children.count }),
                ]))
                .font(MicaboFont.ui(13, weight: .bold))
                .foregroundStyle(MicaboColor.inkSecondary)
                Spacer(minLength: 8)
                Button {
                    withAnimation(LearnMotion.standard) {
                        expanded = allOpen ? [] : Set(root.children.map(\.id))
                    }
                } label: {
                    Text(L10n.t(allOpen ? "ios.sup.mind.collapse" : "ios.sup.mind.expand", locale: .resolved()))
                        .font(MicaboFont.ui(14, weight: .heavy))
                        .foregroundStyle(MicaboColor.accentInk)
                }
                .buttonStyle(MicaboPressableButtonStyle())
            }
            .padding(.bottom, 14)

            rootNode

            ForEach(Array(root.children.enumerated()), id: \.element.id) { index, theme in
                MindMapBranch(
                    theme: theme,
                    number: index + 1,
                    tone: Self.tone(at: index),
                    isLast: index == root.children.count - 1,
                    isOpen: expanded.contains(theme.id)
                ) {
                    withAnimation(LearnMotion.standard) {
                        if expanded.contains(theme.id) {
                            expanded.remove(theme.id)
                        } else {
                            expanded.insert(theme.id)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 6)
        .padding(.bottom, 32)
    }

    private var rootNode: some View {
        HStack(spacing: 12) {
            MicaboIconView(icon: icon, size: 36)
            Text(root.title)
                .font(MicaboFont.ui(19, weight: .black))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(MicaboStage.buttonFill, in: RoundedRectangle(cornerRadius: MicaboRadius.card, style: .continuous))
        .accessibilityAddTraits(.isHeader)
    }

    /// Les branches tournent dans les tons de l'app.
    static func tone(at index: Int) -> LessonTone {
        let tones: [LessonTone] = [.blue, .mint, .yellow, .pink, .lilac]
        return tones[index % tones.count]
    }
}

/// Une branche : le trait qui descend de la leçon, la pastille du thème, et ses notions.
struct MindMapBranch: View {
    let theme: MindMapNode
    let number: Int
    let tone: LessonTone
    let isLast: Bool
    let isOpen: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    Text(verbatim: String(number))
                        .font(MicaboFont.ui(14, weight: .black))
                        .foregroundStyle(tone.ink)
                        .frame(width: 30, height: 30)
                        .background(MicaboColor.surface, in: Circle())
                    Text(theme.title)
                        .font(MicaboFont.ui(16, weight: .heavy))
                        .foregroundStyle(MicaboColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if !theme.children.isEmpty {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(tone.ink)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(tone.pale, in: RoundedRectangle(cornerRadius: MicaboRadius.lg, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(MicaboPressableButtonStyle())
            .accessibilityValue(Text(L10n.t(isOpen ? "ios.sup.mind.open" : "ios.sup.mind.closed", locale: .resolved())))

            if isOpen {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(theme.children) { notion in
                        MindMapNotion(notion: notion, tone: tone)
                    }
                }
                .padding(.leading, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 16)
        .padding(.leading, 30)
        // Le tronc, posé derrière : il descend jusqu'à la branche suivante et s'arrête à la
        // dernière ; un petit trait le relie à la pastille du thème.
        .background(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(MicaboColor.strokeStrong)
                    .frame(width: 2)
                    .frame(maxHeight: isLast ? 40 : .infinity, alignment: .top)
                    .padding(.leading, 11)
                Rectangle()
                    .fill(MicaboColor.strokeStrong)
                    .frame(width: 19, height: 2)
                    .padding(.leading, 11)
                    .padding(.top, 39)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityHidden(true)
        }
    }
}

/// Une notion : un trait de la couleur du thème, son nom, et ses détails en dessous.
struct MindMapNotion: View {
    let notion: MindMapNode
    let tone: LessonTone

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Capsule()
                .fill(tone.vivid)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(notion.title)
                    .font(MicaboFont.ui(15, weight: .bold))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(notion.children) { detail in
                    Text(detail.title)
                        .font(MicaboFont.ui(13, weight: .medium))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 2)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: MicaboRadius.tile, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: 1))
    }
}
