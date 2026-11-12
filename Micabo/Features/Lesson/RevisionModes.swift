import SwiftUI

/// **Les modes de révision d'une leçon**, construits sur l'appareil à partir de ce qu'elle
/// contient déjà (`docs/supports.md`) : rien ne part au modèle.
enum RevisionMode: String, CaseIterable, Identifiable {
    /// La leçon lue à voix haute, chapitre par chapitre.
    case listen
    /// La carte pose la question, l'élève répond à voix haute.
    case voice
    /// Les thèmes et leurs notions, en arbre.
    case mindMap
    /// La fiche de la leçon, en PDF à partager.
    case export

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .listen: "ios.sup.modes.listen"
        case .voice: "ios.sup.modes.voice"
        case .mindMap: "ios.sup.modes.mindMap"
        case .export: "ios.sup.modes.export"
        }
    }

    var hintKey: String {
        switch self {
        case .listen: "ios.sup.modes.listenHint"
        case .voice: "ios.sup.modes.voiceHint"
        case .mindMap: "ios.sup.modes.mindMapHint"
        case .export: "ios.sup.modes.exportHint"
        }
    }

    var symbol: String {
        switch self {
        case .listen: "headphones"
        case .voice: "waveform.and.mic"
        case .mindMap: "point.3.connected.trianglepath.dotted"
        case .export: "doc.richtext.fill"
        }
    }

    var tone: LessonTone {
        switch self {
        case .listen: .blue
        case .voice: .pink
        case .mindMap: .mint
        case .export: .yellow
        }
    }
}

/// **Ce qui est gratuit, et ce qui est dans Pro** (`docs/supports.md` § « La porte »).
///
/// La règle suit celle de l'app : ce qui relit la leçon est à tous, ce qui la fait travailler
/// davantage a son essai offert puis passe dans Pro, comme Mika (une question) et l'examen
/// blanc (un). Aucun prix ne change.
///
/// - Écouter et la carte mentale : gratuits, toujours. Ils ne coûtent rien et donnent envie
///   de revenir.
/// - À voix haute : une séance offerte, puis Pro (`PaywallTrigger.voiceRecall`).
/// - La fiche en PDF : Pro (`PaywallTrigger.exportSheet`).
enum RevisionModeAllowance {
    static let freeVoiceSessions = 1
    static let voiceSessionsKey = "micabo.sup.voiceSessions"

    /// Le paywall à ouvrir avant le mode, ou `nil` s'il s'ouvre.
    static func gate(_ mode: RevisionMode, isPro: Bool, defaults: UserDefaults = .standard) -> PaywallTrigger? {
        guard !isPro else { return nil }
        switch mode {
        case .listen, .mindMap:
            return nil
        case .voice:
            return voiceSessionsUsed(defaults: defaults) >= freeVoiceSessions ? .voiceRecall : nil
        case .export:
            return .exportSheet
        }
    }

    /// Vrai quand la pastille « Pro » se montre sur la tuile : seulement quand le mode est
    /// fermé. À voix haute ne la porte pas tant que sa séance offerte reste.
    static func showsProBadge(_ mode: RevisionMode, isPro: Bool, defaults: UserDefaults = .standard) -> Bool {
        gate(mode, isPro: isPro, defaults: defaults) != nil
    }

    static func voiceSessionsUsed(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: voiceSessionsKey)
    }

    /// Une séance à voix haute a vraiment commencé : sa première carte est notée.
    static func noteVoiceSession(defaults: UserDefaults = .standard) {
        defaults.set(voiceSessionsUsed(defaults: defaults) + 1, forKey: voiceSessionsKey)
    }
}

/// La petite pastille « PRO », dans le jaune du crayon sur son lavis, comme « Passer en Pro » :
/// sur la tuile d'un outil qui est dans Pro et fermé (`LessonToolGrid`).
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "PRO")
            .font(V3Font.caption)
            .foregroundStyle(V3Color.yellow)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(V3Color.yellowWash, in: Capsule())
            .overlay(Capsule().strokeBorder(V3Color.yellow.opacity(0.35)))
            .accessibilityLabel(Text(verbatim: "Pro"))
    }
}

/// L'en-tête commun des écrans de mode : la croix, le titre, et ce que le mode fait.
///
/// La croix est à droite sur une feuille (écouter, la carte mentale, la fiche), comme toutes
/// les feuilles de l'app ; à gauche sur un parcours plein écran (à voix haute), comme le quiz,
/// les flashcards et l'examen blanc.
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
