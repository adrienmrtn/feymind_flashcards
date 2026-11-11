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

    /// Vrai quand la pastille « Pro » se montre sur la tuile : le mode est fermé, ou le sera
    /// après la séance offerte.
    static func showsProBadge(_ mode: RevisionMode, isPro: Bool) -> Bool {
        !isPro && (mode == .voice || mode == .export)
    }

    static func voiceSessionsUsed(defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: voiceSessionsKey)
    }

    /// Une séance à voix haute a vraiment commencé : sa première carte est notée.
    static func noteVoiceSession(defaults: UserDefaults = .standard) {
        defaults.set(voiceSessionsUsed(defaults: defaults) + 1, forKey: voiceSessionsKey)
    }
}

/// **La rangée des modes de révision**, sous l'en-tête d'une leçon : quatre tuiles égales,
/// chacune son icône sur sa pastille et son nom. Une pastille « Pro » sur ce qui est dans Pro.
struct RevisionModesRow: View {
    var isPro = true
    let onSelect: (RevisionMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("ios.sup.modes.title", locale: .resolved()))
                .font(MicaboFont.ui(13, weight: .heavy))
                .foregroundStyle(MicaboColor.inkSecondary)
                .textCase(.uppercase)
                .tracking(0.6)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 10) {
                ForEach(RevisionMode.allCases) { mode in
                    RevisionModeTile(mode: mode, showsPro: RevisionModeAllowance.showsProBadge(mode, isPro: isPro)) {
                        onSelect(mode)
                    }
                }
            }
        }
        .padding(.horizontal, MicaboSpacing.screen)
    }
}

/// Une tuile de mode : la pastille carrée et son icône, le nom dessous.
struct RevisionModeTile: View {
    let mode: RevisionMode
    var showsPro = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: mode.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(mode.tone.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 62)
                    .background(mode.tone.pale, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(mode.tone.vivid.opacity(0.25), lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        if showsPro {
                            ProBadge()
                                .offset(x: 4, y: -6)
                        }
                    }
                Text(L10n.t(mode.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(13, weight: .heavy))
                    .foregroundStyle(MicaboColor.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(MicaboPressableButtonStyle(feedback: .soft))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L10n.t(mode.titleKey, locale: .resolved())))
        .accessibilityHint(Text(L10n.t(mode.hintKey, locale: .resolved())))
        .accessibilityAddTraits(.isButton)
    }
}

/// La petite pastille « Pro », dans le jaune du crayon.
struct ProBadge: View {
    var body: some View {
        Text(verbatim: "PRO")
            .font(MicaboFont.ui(10, weight: .black))
            .tracking(0.5)
            .foregroundStyle(MicaboBrand.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(MicaboBrand.pencil, in: Capsule())
            .accessibilityLabel(Text(verbatim: "Pro"))
    }
}

/// L'en-tête commun des écrans de mode : la croix, le titre, et ce que le mode fait.
struct RevisionModeHeader: View {
    let mode: RevisionMode
    let lessonTitle: String
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: mode.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(mode.tone.ink)
                .frame(width: 42, height: 42)
                .background(mode.tone.pale, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.t(mode.titleKey, locale: .resolved()))
                    .font(MicaboFont.ui(20, weight: .black))
                    .foregroundStyle(MicaboColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(lessonTitle)
                    .font(MicaboFont.ui(14, weight: .semibold))
                    .foregroundStyle(MicaboColor.inkSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
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
        .padding(.horizontal, MicaboSpacing.screen)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}
