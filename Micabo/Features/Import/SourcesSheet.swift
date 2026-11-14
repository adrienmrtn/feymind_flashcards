import SwiftUI

// MARK: - La feuille du « + »

/// **La feuille du « + » : tout ce qu'on peut donner à Mika** (`docs/supports.md`).
///
/// En tête, Mika posé au bas de sa carte et ce qu'il attend ; la leçon offerte rappelée tant
/// qu'elle reste. Puis la grille des neuf supports qui écrivent une leçon, trois par rangée,
/// chacun avec son icône sur sa pastille de couleur : les documents (PDF ou Word, diapos,
/// photos, notes manuscrites), le web (une page, une vidéo YouTube), le son (un cours
/// enregistré en direct, un fichier audio) et le texte collé. À part, sous la grille, les
/// flashcards déjà faites (Anki, Quizlet), qui deviennent un deck sans génération.
///
/// Aucune tuile ne porte de couronne : lire un support se fait sur l'appareil, et la porte du
/// gratuit vient au moment d'écrire la leçon (`LessonAllowance.locksImport`, `sendRoute`).
/// Une tuile referme la feuille ; le support s'ouvre ensuite (`HomeView.openPendingImport`).
///
/// **Lot 13 — c'est la feuille « Nouvelle leçon »**, l'entrée de la fonction principale : un
/// sujet qu'on tape (« Écrire ma leçon », le bouton de la feuille), ou un cours qu'on donne
/// (les tuiles). En tête, ce que la leçon devient : un parcours (thèmes, notes, quiz, cartes,
/// examen blanc). Les supports les plus courants d'abord : photo, PDF, YouTube, audio.
struct HomeSourcesSheet: View {
    let isPro: Bool
    var freeLessonLeft = false
    /// Faux quand la barre porte déjà ses cinq supports : seules les flashcards restent ouvertes.
    var enabled = true
    /// Lot 13 — le sujet déjà tapé, repris s'il n'a pas abouti.
    var topic = ""
    /// Lot 13 — « Écrire ma leçon » sur le sujet tapé. `nil` : la feuille n'a pas de champ.
    var onTopic: ((String) -> Void)?
    let onPick: (LessonComposer.Kind) -> Void

    @Environment(\.homeStill) private var still
    @State private var typed: String?
    @FocusState private var topicFocused: Bool

    /// Les neuf supports d'une leçon, trois par rangée : les plus courants d'abord.
    static let grid: [[LessonComposer.Kind]] = [
        [.photo, .pdf, .youtube],
        [.audio, .handwriting, .text],
        [.slides, .web, .lecture],
    ]

    /// Un sujet d'au moins deux lettres, comme dans la barre (`LessonComposer.canSend`).
    static func canWrite(_ topic: String) -> Bool {
        topic.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var draft: Binding<String> {
        Binding(get: { typed ?? topic }, set: { typed = $0 })
    }

    var body: some View {
        Group {
            if still {
                content
            } else {
                ScrollView { content }
                    .scrollBounceBehavior(.basedOnSize)
            }
        }
        .background(MicaboColor.canvas.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(MicaboRadius.sheet)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            SourcesHeader(freeLessonLeft: freeLessonLeft)
            if let onTopic {
                topicCard(onTopic)
                Text(L10n.t("ios.core13.new.orSupport", locale: .resolved()))
                    .font(V3Font.eyebrow)
                    .foregroundStyle(V3Color.ink3)
                    .textCase(.uppercase)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 10) {
                ForEach(Array(Self.grid.enumerated()), id: \.offset) { _, row in
                    // Les tuiles d'une rangée ont la hauteur de la plus haute.
                    HStack(spacing: 10) {
                        ForEach(row) { kind in
                            SourceTile(kind: kind, enabled: enabled) { onPick(kind) }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !enabled {
                Text(L10n.t("ios.sup.sheet.full", locale: .resolved(), vars: ["n": String(LessonComposer.maximumSupports)]))
                    .font(MicaboFont.ui(13, weight: .bold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(L10n.t("ios.sup.sheet.decks", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
            SourceWideTile(kind: .flashcards) { onPick(.flashcards) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }
}

extension HomeSourcesSheet {
    /// **Un sujet, et le bouton de la feuille** : « Écrire ma leçon ». Pas de support à lire :
    /// Mika écrit la leçon d'après le programme de l'élève.
    @ViewBuilder
    fileprivate func topicCard(_ onTopic: @escaping (String) -> Void) -> some View {
        let value = draft.wrappedValue
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("ios.core13.new.topicLabel", locale: .resolved()))
                .font(V3Font.label)
                .foregroundStyle(V3Color.ink)
                .fixedSize(horizontal: false, vertical: true)
            Group {
                if still {
                    Text(value.isEmpty ? L10n.t("ios.core13.new.topicPlaceholder", locale: .resolved()) : value)
                        .foregroundStyle(value.isEmpty ? V3Color.ink3 : V3Color.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    TextField(
                        text: draft,
                        prompt: Text(L10n.t("ios.core13.new.topicPlaceholder", locale: .resolved())).foregroundStyle(V3Color.ink3),
                        axis: .vertical
                    ) {
                        Text(L10n.t("ios.core13.new.topicLabel", locale: .resolved()))
                    }
                    .lineLimit(1...3)
                    .foregroundStyle(V3Color.ink)
                    .tint(V3Color.accent)
                    .focused($topicFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        if Self.canWrite(draft.wrappedValue) { onTopic(draft.wrappedValue) }
                    }
                }
            }
            .font(V3Font.text(.body, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(V3Color.soft, in: RoundedRectangle(cornerRadius: V3Metric.radiusInner, style: .continuous))
            V3Button(
                L10n.t("ios.core13.cta.write", locale: .resolved()),
                systemImage: "sparkles",
                isEnabled: Self.canWrite(value)
            ) {
                onTopic(draft.wrappedValue)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .v3Card(radius: V3Metric.radiusCard)
    }
}

/// L'en-tête : Mika en demi au bas d'une carte claire, ce qu'il attend, et la leçon offerte.
/// Lot 13 : « Nouvelle leçon », et ce qu'elle devient — un parcours en cinq étapes.
private struct SourcesHeader: View {
    let freeLessonLeft: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            MikaPeek(mood: .happy, width: MikaPeek.card)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("lesson.lessons.new", locale: .resolved()))
                    .font(MicaboFont.ui(23, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(L10n.t("ios.core13.new.promise", locale: .resolved()))
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                LessonPathSteps()
                if freeLessonLeft {
                    Label {
                        Text(L10n.t("ios.sup.sheet.free", locale: .resolved()))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "gift.fill")
                    }
                    .font(MicaboFont.ui(13, weight: .heavy))
                    // Un cadeau : le jaune du crayon (la récompense), pas le vert (réussi).
                    .foregroundStyle(LessonTone.yellow.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LessonTone.yellow.pale, in: Capsule())
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 16)
            Spacer(minLength: 0)
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Mika vit sur le papier de l'app (la règle de `MikaMascot`) : la carte est celle des
        // tuiles, pas une scène bleue pour lui seul.
        .sourceCard()
        .clipShape(RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
    }
}

/// **Lot 13 — ce qu'une leçon devient**, en une ligne qui passe à la ligne : thèmes, notes,
/// quiz, cartes, examen blanc. Ce sont les vrais modes du chemin de la leçon, sous leurs noms
/// (`MicaboName`).
struct LessonPathSteps: View {
    var locale: UiLocale = .resolved()

    static func titles(locale: UiLocale) -> [String] {
        [
            L10n.t("ios.core13.path.themes", locale: locale),
            MicaboName.notes.text(locale: locale),
            MicaboName.quiz.text(locale: locale),
            MicaboName.cards.text(locale: locale),
            MicaboName.mock.text(locale: locale),
        ]
    }

    var body: some View {
        MicaboFlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(Array(Self.titles(locale: locale).enumerated()), id: \.offset) { _, title in
                Text(title)
                    .font(V3Font.text(.caption, weight: .bold))
                    .foregroundStyle(V3Color.accentInk)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(V3Color.accentWash, in: Capsule())
            }
        }
        .padding(.top, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(Self.titles(locale: locale).joined(separator: ", ")))
    }
}

/// Une tuile de la grille : l'icône sur sa pastille, le nom, ce qu'on y met.
struct SourceTile: View {
    let kind: LessonComposer.Kind
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                SourceIcon(kind: kind, size: 50)
                Text(L10n.t(kind.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(15, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.t(kind.subtitleKey, locale: .resolved()))
                    .font(MicaboFont.ui(12, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .sourceCard()
            .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .disabled(!enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t(kind.titleKey, locale: .resolved())))
        .accessibilityHint(Text(L10n.t(kind.subtitleKey, locale: .resolved())))
        .accessibilityAddTraits(.isButton)
    }
}

/// La tuile large : les flashcards déjà faites.
struct SourceWideTile: View {
    let kind: LessonComposer.Kind
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                SourceIcon(kind: kind, size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.t(kind.titleKey, locale: .resolved()))
                        .font(MicaboFont.ui(17, weight: .black))
                        .foregroundStyle(MicaboColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L10n.t(kind.subtitleKey, locale: .resolved()))
                        .font(MicaboFont.ui(13, weight: .semibold))
                        .foregroundStyle(MicaboColor.inkSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MicaboColor.inkTertiary)
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sourceCard()
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// L'icône d'un support sur sa pastille de couleur. Le micro d'un cours en direct se dessine
/// dans l'encre de sa pastille : il n'a pas d'icône 3D.
struct SourceIcon: View {
    let kind: LessonComposer.Kind
    var size: CGFloat = 50

    var body: some View {
        let tone = Self.tone(kind)
        Group {
            switch kind {
            case .lecture, .audio:
                Image(systemName: kind == .lecture ? "mic.fill" : "waveform")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(tone.ink)
            default:
                MicaboIconView(icon: kind.icon, size: size * 0.62)
            }
        }
        .frame(width: size, height: size)
        .background(tone.pale, in: Circle())
        .accessibilityHidden(true)
    }

    /// La pastille de chaque support : deux voisins n'ont jamais la même, ni en ligne ni en colonne.
    static func tone(_ kind: LessonComposer.Kind) -> LessonTone {
        switch kind {
        case .pdf, .audio: .blue
        case .slides, .youtube: .yellow
        case .photo, .lecture: .pink
        case .handwriting, .text: .lilac
        case .web, .flashcards: .mint
        }
    }
}

private extension View {
    /// La carte d'une tuile : la surface de l'app, un filet, une ombre douce.
    func sourceCard() -> some View {
        background(MicaboColor.surface, in: RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: MicaboRadius.wash, style: .continuous).strokeBorder(MicaboColor.stroke, lineWidth: MicaboSurface.border))
    }
}
