import SwiftUI

/// **Les modes de révision d'une leçon**, construits sur l'appareil à partir de ce qu'elle
/// contient déjà (`docs/supports.md`) : rien ne part au modèle.
enum RevisionMode: String, CaseIterable, Identifiable {
    /// Les thèmes et leurs notions, en arbre.
    case mindMap
    /// La fiche de la leçon, en PDF à partager.
    case export

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .mindMap: "ios.sup.modes.mindMap"
        case .export: "ios.sup.modes.export"
        }
    }

    var hintKey: String {
        switch self {
        case .mindMap: "ios.sup.modes.mindMapHint"
        case .export: "ios.sup.modes.exportHint"
        }
    }

    var symbol: String {
        switch self {
        case .mindMap: "point.3.connected.trianglepath.dotted"
        case .export: "doc.richtext.fill"
        }
    }

    var tone: LessonTone {
        switch self {
        case .mindMap: .mint
        case .export: .yellow
        }
    }
}

/// **Ce qui est gratuit, et ce qui est dans Pro** (`docs/supports.md` § « La porte »).
///
/// La carte mentale est gratuite, toujours : elle relit la leçon et donne envie de revenir. La
/// fiche en PDF est dans Pro (`PaywallTrigger.exportSheet`). Aucun prix ne change.
/// (« Écouter » et « À voix haute » ont été retirés au lot 11.)
enum RevisionModeAllowance {
    /// Le paywall à ouvrir avant le mode, ou `nil` s'il s'ouvre.
    static func gate(_ mode: RevisionMode, isPro: Bool) -> PaywallTrigger? {
        guard !isPro else { return nil }
        switch mode {
        case .mindMap:
            return nil
        case .export:
            return .exportSheet
        }
    }

    /// Vrai quand la pastille « Pro » se montre sur la tuile : seulement quand le mode est fermé.
    static func showsProBadge(_ mode: RevisionMode, isPro: Bool) -> Bool {
        gate(mode, isPro: isPro) != nil
    }
}

/// La petite pastille « PRO » : la même que « Passer en PRO » sur la Home (`V3ProBadge`), en
/// capitales droites sur le jaune, à la taille d'un coin de tuile — sur un outil qui est dans
/// Pro et fermé (`LessonToolGrid`).
struct ProBadge: View {
    var body: some View {
        V3ProBadge(nil, size: 12)
            .accessibilityLabel(Text(verbatim: "Pro"))
    }
}

/// L'en-tête commun des écrans de mode : la croix, le titre, et ce que le mode fait.
///
/// La croix est à droite sur une feuille (la carte mentale, la fiche), comme toutes les feuilles
/// de l'app ; à gauche sur un parcours plein écran, comme le quiz, les flashcards et l'examen
/// blanc.
struct RevisionModeHeader: View {
    let mode: RevisionMode
    let lessonTitle: String
    /// La couleur de la leçon ouverte : la même que sur sa tuile. Sans elle, celle du mode.
    var tone: LessonTone?
    /// Vrai pour un parcours plein écran : la croix passe en tête.
    var closesLeading = false
    let onClose: () -> Void

    var body: some View {
        let tone = self.tone ?? mode.tone
        HStack(alignment: .center, spacing: 12) {
            if closesLeading {
                closeButton
            }
            Image(systemName: mode.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tone.ink)
                .frame(width: 42, height: 42)
                .background(tone.pale, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t(mode.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(20, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lessonTitle)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if !closesLeading {
                closeButton
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MicaboColor.ink)
                .frame(width: 40, height: 40)
                .background(MicaboColor.surface, in: Circle())
        }
        .buttonStyle(MicaboPressableButtonStyle())
        .accessibilityLabel(Text(L10n.t("lesson.circle.close", locale: .resolved())))
    }
}
